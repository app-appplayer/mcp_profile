/// Caching Appraisal Port - Cache-decorating wrapper per design/04-caching.md §5.
///
/// Wraps any AppraisalEnginePort with cache-first metric computation.
library;

import 'package:mcp_bundle/ports.dart' show Period;

import '../appraisal/appraisal_result.dart';
import '../appraisal/metric_definition.dart';
import '../engines/appraisal_engine_port.dart';
import '../runtime/runtime_context.dart';
import 'metric_caching_service.dart';

// =============================================================================
// AppraisalCacheConfig (§5)
// =============================================================================

/// Configuration for caching appraisal port behavior.
class AppraisalCacheConfig {
  /// Whether to cache LLM-derived metrics.
  final bool cacheLlmMetrics;

  const AppraisalCacheConfig({
    this.cacheLlmMetrics = true,
  });
}

// =============================================================================
// CachingAppraisalEnginePort (§5)
// =============================================================================

/// AppraisalEnginePort decorator that adds caching.
class CachingAppraisalEnginePort implements AppraisalEnginePort {
  final AppraisalEnginePort _delegate;
  final MetricCachingService _cache;
  final AppraisalCacheConfig _config;

  CachingAppraisalEnginePort(
    this._delegate,
    this._cache, [
    this._config = const AppraisalCacheConfig(),
  ]);

  @override
  Future<Map<String, MetricComputeResult>> computeMetrics(
    List<AppraisalMetricDef> metrics,
    ProfileContext context,
  ) async {
    final results = <String, MetricComputeResult>{};

    // Separate cacheable and non-cacheable metrics
    final cacheableMetrics = <AppraisalMetricDef>[];
    final nonCacheableMetrics = <AppraisalMetricDef>[];

    for (final metric in metrics) {
      if (_isCacheable(metric)) {
        cacheableMetrics.add(metric);
      } else {
        nonCacheableMetrics.add(metric);
      }
    }

    // Compute cacheable metrics with caching
    for (final metric in cacheableMetrics) {
      final result = await _cache.getOrCompute(
        metric.id,
        context,
        () async {
          final batchResult =
              await _delegate.computeMetrics([metric], context);
          return batchResult[metric.id]!;
        },
      );
      results[metric.id] = result;
    }

    // Compute non-cacheable metrics directly
    if (nonCacheableMetrics.isNotEmpty) {
      final directResults = await _delegate.computeMetrics(
        nonCacheableMetrics,
        context,
      );
      results.addAll(directResults);
    }

    return results;
  }

  @override
  Future<List<AppraisalResult>> getHistory(
    String profileId,
    Period period,
  ) async {
    // History queries are not cached
    return _delegate.getHistory(profileId, period);
  }

  @override
  Future<double> computeAggregate(
    Map<String, MetricComputeResult> metrics,
    AggregationConfig? config,
  ) async {
    // Aggregation is a pure computation
    return _delegate.computeAggregate(metrics, config);
  }

  bool _isCacheable(AppraisalMetricDef metric) {
    // Don't cache LLM metrics unless configured
    if (metric.source.type == MetricSourceType.llmDerived) {
      return _config.cacheLlmMetrics;
    }
    return true;
  }
}
