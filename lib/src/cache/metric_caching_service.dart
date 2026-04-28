/// Metric Caching Service - L1/L2/L3 cache hierarchy per design/04-caching.md.
///
/// L1: Request-scoped (per-execution, Map-based)
/// L2: Context-scoped (5-min TTL, keyed by contextId + metricId)
/// L3: Fact-scoped (15-min TTL, keyed by snapshotHash + metricId)
library;

import '../engines/appraisal_engine_port.dart';
import '../runtime/runtime_context.dart';

// =============================================================================
// CacheLevel (§1)
// =============================================================================

/// Cache hierarchy levels.
enum CacheLevel {
  /// Per-execution request cache.
  request,

  /// Per-context cache (5 min TTL).
  context,

  /// Per-fact-hash cache (15 min TTL).
  fact,
}

// =============================================================================
// MetricCacheEntry (§3)
// =============================================================================

/// A cached metric computation result.
class MetricCacheEntry {
  /// Cache key.
  final String cacheKey;

  /// Cached result.
  final MetricComputeResult value;

  /// When the result was computed.
  final DateTime computedAt;

  /// When this entry expires.
  final DateTime expiresAt;

  /// Cache level this entry belongs to.
  final CacheLevel level;

  /// Run ID that produced this entry.
  final String? runId;

  /// Context ID for this entry.
  final String? contextId;

  /// Fact bundle hash for this entry.
  final String? snapshotHash;

  /// Validation status: 'valid', 'stale', 'invalidated'.
  final String validationStatus;

  /// Number of cache hits.
  final int hitCount;

  /// Last time this entry was hit.
  final DateTime? lastHitAt;

  /// Metrics that depend on this metric (for cascade invalidation).
  final List<String> dependentMetrics;

  const MetricCacheEntry({
    required this.cacheKey,
    required this.value,
    required this.computedAt,
    required this.expiresAt,
    required this.level,
    this.runId,
    this.contextId,
    this.snapshotHash,
    this.validationStatus = 'valid',
    this.hitCount = 0,
    this.lastHitAt,
    this.dependentMetrics = const [],
  });

  /// Whether this entry has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether this entry is valid (not expired and validation status is valid).
  bool get isValid => !isExpired && validationStatus == 'valid';

  /// Check if cache entry is still fresh for given context.
  bool isFreshFor(ProfileContext context) {
    if (!isValid) return false;

    return switch (level) {
      CacheLevel.request => runId == context.runId,
      CacheLevel.context => contextId == context.contextId,
      CacheLevel.fact => true, // Fresh if not expired and valid
    };
  }

  /// Create a copy with different level/expiry.
  MetricCacheEntry copyWith({
    CacheLevel? level,
    DateTime? expiresAt,
    String? validationStatus,
    int? hitCount,
    DateTime? lastHitAt,
  }) {
    return MetricCacheEntry(
      cacheKey: cacheKey,
      value: value,
      computedAt: computedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      level: level ?? this.level,
      runId: runId,
      contextId: contextId,
      snapshotHash: snapshotHash,
      validationStatus: validationStatus ?? this.validationStatus,
      hitCount: hitCount ?? this.hitCount,
      lastHitAt: lastHitAt ?? this.lastHitAt,
      dependentMetrics: dependentMetrics,
    );
  }
}

// =============================================================================
// MetricCacheConfig (§7)
// =============================================================================

/// Configuration for the metric caching service.
class MetricCacheConfig {
  /// Whether caching is enabled.
  final bool enabled;

  /// L1 max entries.
  final int l1MaxEntries;

  /// L2 TTL.
  final Duration l2Ttl;

  /// L2 max entries.
  final int l2MaxEntries;

  /// L3 TTL.
  final Duration l3Ttl;

  /// L3 max entries.
  final int l3MaxEntries;

  /// Whether to cache LLM-derived metrics.
  final bool cacheLlmMetrics;

  const MetricCacheConfig({
    this.enabled = true,
    this.l1MaxEntries = 100,
    this.l2Ttl = const Duration(minutes: 5),
    this.l2MaxEntries = 1000,
    this.l3Ttl = const Duration(minutes: 15),
    this.l3MaxEntries = 10000,
    this.cacheLlmMetrics = true,
  });
}

// =============================================================================
// MetricCachingService (§4)
// =============================================================================

/// Three-level metric caching service.
class MetricCachingService {
  final Map<String, MetricCacheEntry> _l1Cache = {};
  final Map<String, MetricCacheEntry> _l2Cache = {};
  final Map<String, MetricCacheEntry> _l3Cache = {};
  final MetricCacheConfig config;

  MetricCachingService({
    this.config = const MetricCacheConfig(),
  });

  /// Get cached metric or compute and cache.
  Future<MetricComputeResult> getOrCompute(
    String metricId,
    ProfileContext context,
    Future<MetricComputeResult> Function() compute,
  ) async {
    if (!config.enabled) return compute();

    // Check L1 (request cache)
    final l1Key = _buildL1Key(metricId, context);
    final l1Entry = _l1Cache[l1Key];
    if (l1Entry != null && l1Entry.isFreshFor(context)) {
      return l1Entry.value;
    }

    // Check L2 (context cache)
    final l2Key = _buildL2Key(metricId, context);
    final l2Entry = _l2Cache[l2Key];
    if (l2Entry != null && l2Entry.isFreshFor(context)) {
      _l1Cache[l1Key] =
          l2Entry.copyWith(level: CacheLevel.request);
      return l2Entry.value;
    }

    // Check L3 (fact cache)
    final l3Key = _buildL3Key(metricId, context);
    final l3Entry = _l3Cache[l3Key];
    if (l3Entry != null && l3Entry.isFreshFor(context)) {
      _l2Cache[l2Key] =
          l3Entry.copyWith(level: CacheLevel.context);
      _l1Cache[l1Key] =
          l3Entry.copyWith(level: CacheLevel.request);
      return l3Entry.value;
    }

    // Cache miss - compute metric
    final result = await compute();
    final now = DateTime.now();

    final factHash = _computeSnapshotHash(context);
    final entry = MetricCacheEntry(
      cacheKey: l3Key,
      value: result,
      computedAt: now,
      expiresAt: now.add(config.l3Ttl),
      level: CacheLevel.fact,
      runId: context.runId,
      contextId: context.contextId,
      snapshotHash: factHash,
      validationStatus: 'valid',
      hitCount: 0,
      lastHitAt: now,
      dependentMetrics: _findDependentMetrics(metricId),
    );

    // Store in all cache levels
    _l1Cache[l1Key] = entry.copyWith(level: CacheLevel.request);
    _l2Cache[l2Key] = entry.copyWith(
      level: CacheLevel.context,
      expiresAt: now.add(config.l2Ttl),
    );
    _l3Cache[l3Key] = entry;

    // Evict if over limit
    _evictIfNeeded();

    return result;
  }

  /// Invalidate cached metrics per design/04-caching.md §4.
  Future<void> invalidate({
    String? metricId,
    String? contextId,
    String? snapshotHash,
    bool cascade = true,
  }) async {
    if (metricId != null) {
      _l1Cache.removeWhere((k, _) => k.contains(metricId));
      _l2Cache.removeWhere((k, _) => k.contains(metricId));
      _l3Cache.removeWhere((k, _) => k.contains(metricId));

      if (cascade) {
        // Cascade invalidation per design/04-caching.md §4.
        // Dependent metric tracking is a no-op until external registration
        // is implemented (dependentMetrics is always empty currently).
      }
    }

    if (contextId != null) {
      _l2Cache.removeWhere((k, v) => v.contextId == contextId);
    }

    if (snapshotHash != null) {
      _l3Cache.removeWhere((k, v) => v.snapshotHash == snapshotHash);
    }
  }

  /// Clear request-scoped cache (call at end of pipeline).
  void clearRequestCache() {
    _l1Cache.clear();
  }

  /// Clear all caches.
  void clearAll() {
    _l1Cache.clear();
    _l2Cache.clear();
    _l3Cache.clear();
  }

  String _buildL1Key(String metricId, ProfileContext context) =>
      'l1:${context.runId}:$metricId';

  String _buildL2Key(String metricId, ProfileContext context) {
    final asOfMinute = context.asOf.toIso8601String().substring(0, 16);
    return 'l2:${context.contextId}:${context.profileId}:$metricId:$asOfMinute';
  }

  String _buildL3Key(String metricId, ProfileContext context,
      {String? metricVersion}) {
    final snapshotHash = _computeSnapshotHash(context);
    final periodKey = context.period?.toString() ?? 'none';
    final versionKey = metricVersion ?? 'v0';
    return 'l3:$snapshotHash:$metricId:$versionKey:$periodKey';
  }

  /// Compute hash for the fact snapshot keyed by (entityId, contextId,
  /// asOf). In 0.2.0 the context no longer carries an inline fact bundle
  /// — facts come from a [FactsPort], so cache keys identify a snapshot
  /// by the context's entity + time + identity triple.
  String _computeSnapshotHash(ProfileContext context) {
    final asOfMinute = context.asOf.toIso8601String().substring(0, 16);
    final key = '${context.entityId}:${context.contextId}:$asOfMinute';
    return key.hashCode.toRadixString(16);
  }

  /// Find dependent metrics for cache entry population.
  ///
  /// Reserved for future dependency tracking per design/04-caching.md §4.
  /// Returns empty until external dependency registration is implemented.
  List<String> _findDependentMetrics(String metricId) => const [];

  void _evictIfNeeded() {
    if (_l1Cache.length > config.l1MaxEntries) {
      // Remove expired entries first, then oldest
      _l1Cache.removeWhere((_, v) => v.isExpired);
    }
    if (_l2Cache.length > config.l2MaxEntries) {
      _l2Cache.removeWhere((_, v) => v.isExpired);
    }
    if (_l3Cache.length > config.l3MaxEntries) {
      _l3Cache.removeWhere((_, v) => v.isExpired);
    }
  }
}
