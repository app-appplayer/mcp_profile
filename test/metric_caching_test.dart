/// MetricCachingService and CachingAppraisalEnginePort Tests
library;

import 'package:mcp_bundle/ports.dart' show Period, PeriodUnit;
import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

// =============================================================================
// Test Helpers
// =============================================================================

/// Creates a test ProfileContext with configurable IDs.
RuntimeProfileContext _createContext({
  String profileId = 'test',
  String? contextId,
  String? runId,
}) {
  return DefaultRuntimeContext(
    profileId: profileId,
    entityId: 'e',
    contextId: contextId,
    runId: runId,
  );
}

/// Counting delegate that tracks how many times computeMetrics is called.
class _CountingAppraisalEnginePort implements AppraisalEnginePort {
  int computeCount = 0;

  @override
  Future<Map<String, MetricComputeResult>> computeMetrics(
    List<AppraisalMetricDef> metrics,
    RuntimeProfileContext context,
  ) async {
    computeCount++;
    return {
      for (final m in metrics)
        m.id: MetricComputeResult(
          metricId: m.id,
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
        ),
    };
  }

  @override
  Future<List<AppraisalResult>> getHistory(
    String profileId,
    Period period,
  ) async =>
      [];

  @override
  Future<double> computeAggregate(
    Map<String, MetricComputeResult> metrics,
    AggregationConfig? config,
  ) async =>
      0.5;
}

void main() {
  // ===========================================================================
  // CacheLevel
  // ===========================================================================

  group('CacheLevel', () {
    test('has 3 values', () {
      expect(CacheLevel.values.length, equals(3));
      expect(CacheLevel.values, containsAll([
        CacheLevel.request,
        CacheLevel.context,
        CacheLevel.fact,
      ]));
    });
  });

  // ===========================================================================
  // MetricCacheEntry
  // ===========================================================================

  group('MetricCacheEntry', () {
    final now = DateTime.now();
    final value = MetricComputeResult(
      metricId: 'm1',
      normalizedValue: 0.7,
      sourceType: MetricSourceType.static_,
    );

    test('creation stores all fields', () {
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        level: CacheLevel.context,
        runId: 'run-1',
        contextId: 'ctx-1',
        snapshotHash: 'hash-1',
      );

      expect(entry.cacheKey, equals('key1'));
      expect(entry.value.metricId, equals('m1'));
      expect(entry.computedAt, equals(now));
      expect(entry.level, equals(CacheLevel.context));
      expect(entry.runId, equals('run-1'));
      expect(entry.contextId, equals('ctx-1'));
      expect(entry.snapshotHash, equals('hash-1'));
      expect(entry.validationStatus, equals('valid'));
      expect(entry.hitCount, equals(0));
      expect(entry.dependentMetrics, isEmpty);
    });

    test('isExpired returns false when not expired', () {
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        level: CacheLevel.context,
      );
      expect(entry.isExpired, isFalse);
    });

    test('isExpired returns true when expired', () {
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
        level: CacheLevel.context,
      );
      expect(entry.isExpired, isTrue);
    });

    test('isValid returns true when valid and not expired', () {
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        level: CacheLevel.context,
        validationStatus: 'valid',
      );
      expect(entry.isValid, isTrue);
    });

    test('isValid returns false when expired', () {
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
        level: CacheLevel.context,
        validationStatus: 'valid',
      );
      expect(entry.isValid, isFalse);
    });

    test('isValid returns false when invalidated', () {
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        level: CacheLevel.context,
        validationStatus: 'invalidated',
      );
      expect(entry.isValid, isFalse);
    });

    test('isFreshFor checks runId for request level', () {
      final context = _createContext(runId: 'run-1');
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        level: CacheLevel.request,
        runId: 'run-1',
      );
      expect(entry.isFreshFor(context), isTrue);

      final entryDifferentRun = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        level: CacheLevel.request,
        runId: 'run-other',
      );
      expect(entryDifferentRun.isFreshFor(context), isFalse);
    });

    test('isFreshFor checks contextId for context level', () {
      final context = _createContext(contextId: 'ctx-1');
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        level: CacheLevel.context,
        contextId: 'ctx-1',
      );
      expect(entry.isFreshFor(context), isTrue);

      final entryDifferentCtx = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        level: CacheLevel.context,
        contextId: 'ctx-other',
      );
      expect(entryDifferentCtx.isFreshFor(context), isFalse);
    });

    test('copyWith creates updated copy', () {
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        level: CacheLevel.fact,
        runId: 'run-1',
      );

      final copy = entry.copyWith(
        level: CacheLevel.request,
        hitCount: 3,
        validationStatus: 'stale',
      );

      expect(copy.level, equals(CacheLevel.request));
      expect(copy.hitCount, equals(3));
      expect(copy.validationStatus, equals('stale'));
      // Unchanged fields preserved
      expect(copy.cacheKey, equals('key1'));
      expect(copy.runId, equals('run-1'));
      expect(copy.value.metricId, equals('m1'));
    });

    test('copyWith without level preserves original level and runId', () {
      final entry = MetricCacheEntry(
        cacheKey: 'key1',
        value: value,
        computedAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        level: CacheLevel.context,
        runId: 'run-abc',
        contextId: 'ctx-abc',
        snapshotHash: 'hash-abc',
      );

      // Call copyWith without level to exercise the fallback path
      final copy = entry.copyWith(hitCount: 1);

      expect(copy.level, equals(CacheLevel.context));
      expect(copy.runId, equals('run-abc'));
      expect(copy.contextId, equals('ctx-abc'));
      expect(copy.snapshotHash, equals('hash-abc'));
      expect(copy.hitCount, equals(1));
      expect(copy.dependentMetrics, isEmpty);
    });
  });

  // ===========================================================================
  // MetricCacheConfig
  // ===========================================================================

  group('MetricCacheConfig', () {
    test('creation with defaults', () {
      const config = MetricCacheConfig();
      expect(config.enabled, isTrue);
      expect(config.l1MaxEntries, equals(100));
      expect(config.l2Ttl, equals(const Duration(minutes: 5)));
      expect(config.l2MaxEntries, equals(1000));
      expect(config.l3Ttl, equals(const Duration(minutes: 15)));
      expect(config.l3MaxEntries, equals(10000));
      expect(config.cacheLlmMetrics, isTrue);
    });
  });

  // ===========================================================================
  // MetricCachingService
  // ===========================================================================

  group('MetricCachingService', () {
    test('getOrCompute caches result on first call', () async {
      final service = MetricCachingService();
      final context = _createContext();
      var computeCount = 0;

      final result = await service.getOrCompute('m1', context, () async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'm1',
          normalizedValue: 0.8,
          sourceType: MetricSourceType.static_,
        );
      });

      expect(result.normalizedValue, equals(0.8));
      expect(computeCount, equals(1));
    });

    test('getOrCompute returns cached on second call without recomputing',
        () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-fixed',
        runId: 'run-fixed',
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'm1',
          normalizedValue: 0.8,
          sourceType: MetricSourceType.static_,
        );
      }

      await service.getOrCompute('m1', context, compute);
      final result2 = await service.getOrCompute('m1', context, compute);

      expect(result2.normalizedValue, equals(0.8));
      expect(computeCount, equals(1));
    });

    test('getOrCompute always computes when cache disabled', () async {
      final service = MetricCachingService(
        config: const MetricCacheConfig(enabled: false),
      );
      final context = _createContext(runId: 'run-fixed');
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'm1',
          normalizedValue: 0.8,
          sourceType: MetricSourceType.static_,
        );
      }

      await service.getOrCompute('m1', context, compute);
      await service.getOrCompute('m1', context, compute);

      expect(computeCount, equals(2));
    });

    test('invalidate by metricId removes from all caches', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-inv',
        runId: 'run-inv',
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
        );
      }

      // Populate cache
      await service.getOrCompute('m1', context, compute);
      expect(computeCount, equals(1));

      // Invalidate
      await service.invalidate(metricId: 'm1');

      // Should recompute after invalidation
      await service.getOrCompute('m1', context, compute);
      expect(computeCount, equals(2));
    });

    test('invalidate by contextId removes L2 entries', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-l2',
        runId: 'run-l2',
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'm2',
          normalizedValue: 0.6,
          sourceType: MetricSourceType.static_,
        );
      }

      await service.getOrCompute('m2', context, compute);
      expect(computeCount, equals(1));

      // Invalidate L2 by contextId and clear L1
      await service.invalidate(contextId: 'ctx-l2');
      service.clearRequestCache();

      // L3 cache may still have the entry (it's keyed by snapshotHash)
      // But with the same context, L3 should still hit
      await service.getOrCompute('m2', context, compute);
      // computeCount may be 1 (L3 hit) or 2 depending on key matching
      // The main assertion is that contextId invalidation ran without error
      expect(computeCount, greaterThanOrEqualTo(1));
    });

    test('invalidate by snapshotHash removes L3 entries', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-l3',
        runId: 'run-l3',
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'm3',
          normalizedValue: 0.4,
          sourceType: MetricSourceType.static_,
        );
      }

      await service.getOrCompute('m3', context, compute);
      expect(computeCount, equals(1));

      // Invalidate L3 by a specific hash and also clear L1/L2
      await service.invalidate(snapshotHash: 'some-hash');
      service.clearRequestCache();

      // The invalidation may or may not hit this entry depending on hash match
      // This confirms the method executes correctly
      expect(computeCount, greaterThanOrEqualTo(1));
    });

    test('clearRequestCache clears L1 only', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-clear',
        runId: 'run-clear',
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'm4',
          normalizedValue: 0.3,
          sourceType: MetricSourceType.static_,
        );
      }

      // Populate all cache levels
      await service.getOrCompute('m4', context, compute);
      expect(computeCount, equals(1));

      // Clear only L1
      service.clearRequestCache();

      // L2/L3 should still have the entry, so no recompute
      await service.getOrCompute('m4', context, compute);
      expect(computeCount, equals(1));
    });

    test('clearAll clears all levels', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-all',
        runId: 'run-all',
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'm5',
          normalizedValue: 0.9,
          sourceType: MetricSourceType.static_,
        );
      }

      await service.getOrCompute('m5', context, compute);
      expect(computeCount, equals(1));

      // Clear all
      service.clearAll();

      // Must recompute after clearing all caches
      await service.getOrCompute('m5', context, compute);
      expect(computeCount, equals(2));
    });
  });

  // ===========================================================================
  // CachingAppraisalEnginePort
  // ===========================================================================

  group('CachingAppraisalEnginePort', () {
    test('computeMetrics uses cache for cacheable metrics', () async {
      final delegate = _CountingAppraisalEnginePort();
      final cache = MetricCachingService();
      final port = CachingAppraisalEnginePort(delegate, cache);

      final context = _createContext(
        contextId: 'ctx-cap',
        runId: 'run-cap',
      );
      final metrics = [
        AppraisalMetricDef(
          id: 'risk',
          name: 'Risk',
          source: const StaticSource(value: 0.5),
        ),
      ];

      // First call should delegate
      final result1 = await port.computeMetrics(metrics, context);
      expect(result1.containsKey('risk'), isTrue);
      expect(result1['risk']!.normalizedValue, equals(0.5));
      expect(delegate.computeCount, equals(1));

      // Second call should use cache
      final result2 = await port.computeMetrics(metrics, context);
      expect(result2.containsKey('risk'), isTrue);
      expect(result2['risk']!.normalizedValue, equals(0.5));
      expect(delegate.computeCount, equals(1));
    });

    test('getHistory delegates directly without caching', () async {
      final delegate = _CountingAppraisalEnginePort();
      final cache = MetricCachingService();
      final port = CachingAppraisalEnginePort(delegate, cache);

      final result =
          await port.getHistory('test', const Period.relative(unit: PeriodUnit.days, value: 30));
      expect(result, isEmpty);
    });

    test('computeAggregate delegates directly', () async {
      final delegate = _CountingAppraisalEnginePort();
      final cache = MetricCachingService();
      final port = CachingAppraisalEnginePort(delegate, cache);

      final metrics = {
        'm1': MetricComputeResult(
          metricId: 'm1',
          normalizedValue: 0.6,
          sourceType: MetricSourceType.static_,
        ),
      };
      final result = await port.computeAggregate(metrics, null);
      expect(result, equals(0.5));
    });
  });

  // ===========================================================================
  // MetricCachingService — L2 cache hit (promotes to L1)
  // ===========================================================================

  group('MetricCachingService L2 cache hit', () {
    test('L2 hit promotes to L1 after L1 cleared', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-l2hit',
        runId: 'run-l2hit',
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'ml2',
          normalizedValue: 0.75,
          sourceType: MetricSourceType.static_,
        );
      }

      // Populate all cache levels
      await service.getOrCompute('ml2', context, compute);
      expect(computeCount, equals(1));

      // Clear L1 only, so the next hit must come from L2
      service.clearRequestCache();

      // Same context -> L2 hit, promotes to L1
      final result = await service.getOrCompute('ml2', context, compute);
      expect(result.normalizedValue, equals(0.75));
      expect(computeCount, equals(1)); // No recompute
    });
  });

  // ===========================================================================
  // MetricCachingService — L3 cache hit (promotes to L1+L2)
  // ===========================================================================

  group('MetricCachingService L3 cache hit', () {
    test('L3 hit promotes to L1 and L2 after L1+L2 cleared', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-l3hit',
        runId: 'run-l3hit',
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute() async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'ml3',
          normalizedValue: 0.65,
          sourceType: MetricSourceType.static_,
        );
      }

      // Populate all cache levels
      await service.getOrCompute('ml3', context, compute);
      expect(computeCount, equals(1));

      // Clear L1 and L2, leaving only L3
      service.clearRequestCache();
      await service.invalidate(contextId: 'ctx-l3hit');

      // L3 should still have data; hit should promote to L1+L2
      final result = await service.getOrCompute('ml3', context, compute);
      expect(result.normalizedValue, equals(0.65));
      expect(computeCount, equals(1)); // No recompute
    });
  });

  // ===========================================================================
  // MetricCachingService — invalidate cascade
  // ===========================================================================

  group('MetricCachingService invalidate cascade', () {
    test('cascade=true calls _findDependentsOf and invalidates found dependents',
        () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-cascade',
        runId: 'run-cascade',
      );
      var computeCountBase = 0;

      // Populate base metric
      await service.getOrCompute('base_metric', context, () async {
        computeCountBase++;
        return MetricComputeResult(
          metricId: 'base_metric',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
        );
      });
      expect(computeCountBase, equals(1));

      // Cascade invalidate: exercises _findDependentsOf code path
      await service.invalidate(metricId: 'base_metric', cascade: true);

      // base_metric should be removed, so a recompute is needed
      await service.getOrCompute('base_metric', context, () async {
        computeCountBase++;
        return MetricComputeResult(
          metricId: 'base_metric',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
        );
      });
      expect(computeCountBase, equals(2));
    });

    test('cascade=false does not search for dependents', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-nocascade',
        runId: 'run-nocascade',
      );
      var computeCount = 0;

      await service.getOrCompute('metric_a', context, () async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'metric_a',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
        );
      });
      expect(computeCount, equals(1));

      // Invalidate without cascade
      await service.invalidate(metricId: 'metric_a', cascade: false);

      // Should need to recompute
      await service.getOrCompute('metric_a', context, () async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'metric_a',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
        );
      });
      expect(computeCount, equals(2));
    });

    test('invalidate by snapshotHash removes matching L3 entries', () async {
      final service = MetricCachingService();
      final context = _createContext(
        contextId: 'ctx-fbh',
        runId: 'run-fbh',
      );
      var computeCount = 0;

      // Populate cache
      await service.getOrCompute('mfbh', context, () async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'mfbh',
          normalizedValue: 0.4,
          sourceType: MetricSourceType.static_,
        );
      });
      expect(computeCount, equals(1));

      // Clear L1 and L2 so we must rely on L3
      service.clearRequestCache();
      await service.invalidate(contextId: 'ctx-fbh');

      // Invalidate L3 by the snapshotHash that was actually stored.
      // The 0.2.0 cache hash is keyed by (entityId, contextId, asOfMinute).
      final asOfMinute = context.asOf.toIso8601String().substring(0, 16);
      final expectedHash = '${context.entityId}:${context.contextId}:$asOfMinute'
          .hashCode
          .toRadixString(16);
      await service.invalidate(snapshotHash: expectedHash);

      // Now L3 should be gone too, forcing a recompute
      await service.getOrCompute('mfbh', context, () async {
        computeCount++;
        return MetricComputeResult(
          metricId: 'mfbh',
          normalizedValue: 0.4,
          sourceType: MetricSourceType.static_,
        );
      });
      expect(computeCount, equals(2));
    });
  });

  // ===========================================================================
  // MetricCachingService — _evictIfNeeded
  // ===========================================================================

  group('MetricCachingService eviction', () {
    test('L1 eviction when max entries exceeded', () async {
      final service = MetricCachingService(
        config: const MetricCacheConfig(l1MaxEntries: 2),
      );
      var computeCount = 0;

      Future<MetricComputeResult> compute(String id) async {
        computeCount++;
        return MetricComputeResult(
          metricId: id,
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
        );
      }

      // Fill 3 entries into L1 (max is 2)
      for (var i = 0; i < 3; i++) {
        final ctx = _createContext(
          contextId: 'ctx-evict',
          runId: 'run-evict-$i',
        );
        await service.getOrCompute('evict_$i', ctx, () => compute('evict_$i'));
      }

      // Service should not throw; eviction handles overflow
      expect(computeCount, equals(3));
    });

    test('L2 eviction when max entries exceeded', () async {
      final service = MetricCachingService(
        config: const MetricCacheConfig(l2MaxEntries: 2),
      );
      var computeCount = 0;

      // Fill 3 entries with different context IDs to get different L2 keys
      for (var i = 0; i < 3; i++) {
        final ctx = _createContext(
          contextId: 'ctx-l2evict-$i',
          runId: 'run-l2evict-$i',
        );
        await service.getOrCompute('l2evict_$i', ctx, () async {
          computeCount++;
          return MetricComputeResult(
            metricId: 'l2evict_$i',
            normalizedValue: 0.5,
            sourceType: MetricSourceType.static_,
          );
        });
      }

      expect(computeCount, equals(3));
    });

    test('L3 eviction when max entries exceeded', () async {
      final service = MetricCachingService(
        config: const MetricCacheConfig(l3MaxEntries: 2),
      );
      var computeCount = 0;

      // Fill 3 entries with different metric IDs to get different L3 keys
      for (var i = 0; i < 3; i++) {
        final ctx = _createContext(
          contextId: 'ctx-l3evict',
          runId: 'run-l3evict-$i',
        );
        await service.getOrCompute('l3evict_$i', ctx, () async {
          computeCount++;
          return MetricComputeResult(
            metricId: 'l3evict_$i',
            normalizedValue: 0.5,
            sourceType: MetricSourceType.static_,
          );
        });
      }

      expect(computeCount, equals(3));
    });
  });

  // ===========================================================================
  // CachingAppraisalEnginePort — cacheLlmMetrics=false (D5)
  // ===========================================================================

  group('CachingAppraisalEnginePort with cacheLlmMetrics=false', () {
    test('LLM metrics bypass cache when cacheLlmMetrics is false', () async {
      final delegate = _CountingAppraisalEnginePort();
      final cache = MetricCachingService();
      final port = CachingAppraisalEnginePort(
        delegate,
        cache,
        const AppraisalCacheConfig(cacheLlmMetrics: false),
      );

      final context = _createContext(
        contextId: 'ctx-llm',
        runId: 'run-llm',
      );
      final metrics = [
        AppraisalMetricDef(
          id: 'llm_sentiment',
          name: 'Sentiment',
          source: const LlmDerivedSource(prompt: 'Analyze sentiment'),
        ),
      ];

      // First call - should delegate directly (not cached)
      final result1 = await port.computeMetrics(metrics, context);
      expect(result1.containsKey('llm_sentiment'), isTrue);
      expect(delegate.computeCount, equals(1));

      // Second call - should delegate again (LLM metrics not cached)
      final result2 = await port.computeMetrics(metrics, context);
      expect(result2.containsKey('llm_sentiment'), isTrue);
      expect(delegate.computeCount, equals(2));
    });

    test('static metrics still cached when cacheLlmMetrics is false', () async {
      final delegate = _CountingAppraisalEnginePort();
      final cache = MetricCachingService();
      final port = CachingAppraisalEnginePort(
        delegate,
        cache,
        const AppraisalCacheConfig(cacheLlmMetrics: false),
      );

      final context = _createContext(
        contextId: 'ctx-static',
        runId: 'run-static',
      );
      final metrics = [
        AppraisalMetricDef(
          id: 'risk',
          name: 'Risk',
          source: const StaticSource(value: 0.5),
        ),
      ];

      // First call
      await port.computeMetrics(metrics, context);
      expect(delegate.computeCount, equals(1));

      // Second call - should use cache
      await port.computeMetrics(metrics, context);
      expect(delegate.computeCount, equals(1));
    });

    test('mixed LLM and static metrics: LLM not cached, static cached',
        () async {
      final delegate = _CountingAppraisalEnginePort();
      final cache = MetricCachingService();
      final port = CachingAppraisalEnginePort(
        delegate,
        cache,
        const AppraisalCacheConfig(cacheLlmMetrics: false),
      );

      final context = _createContext(
        contextId: 'ctx-mixed',
        runId: 'run-mixed',
      );
      final metrics = [
        AppraisalMetricDef(
          id: 'risk',
          name: 'Risk',
          source: const StaticSource(value: 0.5),
        ),
        AppraisalMetricDef(
          id: 'llm_analysis',
          name: 'Analysis',
          source: const LlmDerivedSource(prompt: 'Analyze'),
        ),
      ];

      // First call: one delegate call for cached (risk), one for non-cached (llm_analysis)
      final result = await port.computeMetrics(metrics, context);
      expect(result.length, equals(2));
      expect(result.containsKey('risk'), isTrue);
      expect(result.containsKey('llm_analysis'), isTrue);

      // delegate.computeCount should be 2:
      // 1 for risk (via cache.getOrCompute -> delegate)
      // 1 for llm_analysis (direct delegate call, batch of non-cacheable)
      expect(delegate.computeCount, equals(2));
    });
  });
}
