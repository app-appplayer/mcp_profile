/// Appraisal Engine Port - Internal engine contract for metric computation.
///
/// See docs/03_DDD/core-engines.md §3.
///
/// Internal abstraction. External callers reach the same capability through
/// [mcp_bundle.MetricsPort] / [mcp_bundle.AppraisalPort] implemented by
/// `MetricsPortAdapter` / `AppraisalPortAdapter` in `src/adapters/`.
library;

import 'package:mcp_bundle/ports.dart' show Period;

import '../appraisal/appraisal_result.dart';
import '../appraisal/metric_definition.dart';
import '../runtime/runtime_context.dart';

/// Engine contract for appraisal metric computation.
abstract class AppraisalEnginePort {
  /// Compute metrics based on definitions and context.
  Future<Map<String, MetricComputeResult>> computeMetrics(
    List<AppraisalMetricDef> metrics,
    RuntimeProfileContext context,
  );

  /// Historical appraisal results.
  Future<List<AppraisalResult>> getHistory(
    String profileId,
    Period period,
  );

  /// Reduce compute results into a single aggregated score.
  Future<double> computeAggregate(
    Map<String, MetricComputeResult> metrics,
    AggregationConfig? config,
  );
}

/// Internal computation result carrier (pre-normalization output).
class MetricComputeResult {
  /// Metric identifier.
  final String metricId;

  /// Raw value before normalization (nullable on error).
  final double? rawValue;

  /// Normalized value (0.0-1.0 typically).
  final double normalizedValue;

  /// Source type for confidence attribution.
  final MetricSourceType sourceType;

  /// Confidence score (0.0-1.0).
  final double confidence;

  /// Error message if computation failed.
  final String? error;

  const MetricComputeResult({
    required this.metricId,
    this.rawValue,
    required this.normalizedValue,
    required this.sourceType,
    this.confidence = 1.0,
    this.error,
  });

  /// Check if this computation succeeded.
  bool get succeeded => error == null;

  /// Convert to [MetricResult] for the output pipeline.
  MetricResult toMetricResult() {
    return MetricResult(
      id: metricId,
      rawValue: rawValue,
      normalizedValue: normalizedValue,
      sourceType: sourceType,
      confidence: confidence,
    );
  }
}

/// Utility for converting compute results to output [MetricResult]s.
class MetricResultConverter {
  /// Convert compute results to output results with optional defaults.
  static ({
    Map<String, MetricResult> results,
    List<String> warnings,
  }) convertBatch(
    Map<String, MetricComputeResult> computeResults, {
    Map<String, double>? defaultValues,
    bool includeFailedWithDefault = true,
  }) {
    final results = <String, MetricResult>{};
    final warnings = <String>[];

    for (final entry in computeResults.entries) {
      final compute = entry.value;
      if (compute.succeeded) {
        results[entry.key] = compute.toMetricResult();
      } else {
        warnings.add('Metric ${entry.key} failed: ${compute.error}');
        if (includeFailedWithDefault &&
            defaultValues?.containsKey(entry.key) == true) {
          results[entry.key] = MetricResult(
            id: entry.key,
            rawValue: defaultValues![entry.key],
            normalizedValue: defaultValues[entry.key]!,
            sourceType: MetricSourceType.static_,
            confidence: 0.3,
          );
        }
      }
    }
    return (results: results, warnings: warnings);
  }
}

/// Stub engine port returning stable defaults (test/bootstrap use).
class StubAppraisalEnginePort implements AppraisalEnginePort {
  const StubAppraisalEnginePort();

  @override
  Future<Map<String, MetricComputeResult>> computeMetrics(
    List<AppraisalMetricDef> metrics,
    RuntimeProfileContext context,
  ) async {
    return {
      for (final m in metrics)
        m.id: MetricComputeResult(
          metricId: m.id,
          rawValue: m.defaultValue ?? 0.5,
          normalizedValue: m.defaultValue ?? 0.5,
          sourceType: MetricSourceType.static_,
          confidence: 0.5,
        ),
    };
  }

  @override
  Future<List<AppraisalResult>> getHistory(
    String profileId,
    Period period,
  ) async {
    return [];
  }

  @override
  Future<double> computeAggregate(
    Map<String, MetricComputeResult> metrics,
    AggregationConfig? config,
  ) async {
    if (metrics.isEmpty) return 0.5;
    return metrics.values
            .map((m) => m.normalizedValue)
            .reduce((a, b) => a + b) /
        metrics.length;
  }
}
