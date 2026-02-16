/// Appraisal Port - Interface for profile metric computation.
///
/// Provides methods for computing and aggregating metrics used in
/// profile appraisal and decision making.
library;

import 'fact_graph_port.dart';

/// Port for appraisal operations.
abstract class AppraisalPort {
  /// Compute metrics for an entity.
  Future<MetricComputeResult> computeMetrics({
    required String entityId,
    required List<MetricDefinition> metrics,
    Period? period,
  });

  /// Compute aggregate metrics across entities.
  Future<MetricComputeResult> computeAggregate({
    required List<String> entityIds,
    required AggregateMetricDefinition aggregateMetric,
    Period? period,
  });

  /// Get cached metric value.
  Future<MetricValue?> getCachedMetric({
    required String entityId,
    required String metricName,
    Duration? maxAge,
  });

  /// Invalidate cached metrics.
  Future<void> invalidateCache({
    String? entityId,
    String? metricName,
  });
}

/// Result of metric computation.
class MetricComputeResult {
  /// Computed metric values.
  final Map<String, MetricValue> values;

  /// Computation errors.
  final List<MetricError> errors;

  /// Overall confidence.
  final double confidence;

  /// Computation timestamp.
  final DateTime computedAt;

  /// Computation duration.
  final Duration duration;

  const MetricComputeResult({
    required this.values,
    this.errors = const [],
    required this.confidence,
    required this.computedAt,
    required this.duration,
  });

  /// Check if computation was successful.
  bool get isSuccess => errors.isEmpty;

  /// Get value by name.
  MetricValue? getValue(String name) => values[name];

  /// Create from JSON.
  factory MetricComputeResult.fromJson(Map<String, dynamic> json) {
    return MetricComputeResult(
      values: (json['values'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, MetricValue.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => MetricError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      computedAt: DateTime.parse(json['computedAt'] as String),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'values': values.map((k, v) => MapEntry(k, v.toJson())),
        if (errors.isNotEmpty) 'errors': errors.map((e) => e.toJson()).toList(),
        'confidence': confidence,
        'computedAt': computedAt.toIso8601String(),
        'durationMs': duration.inMilliseconds,
      };
}

/// Metric computation error.
class MetricError {
  /// Metric name.
  final String metricName;

  /// Error message.
  final String message;

  /// Error code.
  final String? code;

  /// Whether this is recoverable.
  final bool recoverable;

  const MetricError({
    required this.metricName,
    required this.message,
    this.code,
    this.recoverable = false,
  });

  /// Create from JSON.
  factory MetricError.fromJson(Map<String, dynamic> json) {
    return MetricError(
      metricName: json['metricName'] as String,
      message: json['message'] as String,
      code: json['code'] as String?,
      recoverable: json['recoverable'] as bool? ?? false,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'metricName': metricName,
        'message': message,
        if (code != null) 'code': code,
        'recoverable': recoverable,
      };
}

/// Definition of a metric to compute.
class MetricDefinition {
  /// Metric name.
  final String name;

  /// Metric type.
  final MetricType type;

  /// Source data type.
  final MetricSource source;

  /// Computation parameters.
  final Map<String, dynamic> parameters;

  /// Default value if computation fails.
  final dynamic defaultValue;

  /// Required fact types.
  final List<String>? requiredFactTypes;

  const MetricDefinition({
    required this.name,
    required this.type,
    required this.source,
    this.parameters = const {},
    this.defaultValue,
    this.requiredFactTypes,
  });

  /// Create from JSON.
  factory MetricDefinition.fromJson(Map<String, dynamic> json) {
    return MetricDefinition(
      name: json['name'] as String,
      type: MetricType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MetricType.gauge,
      ),
      source: MetricSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => MetricSource.factgraph,
      ),
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      defaultValue: json['defaultValue'],
      requiredFactTypes: (json['requiredFactTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'source': source.name,
        if (parameters.isNotEmpty) 'parameters': parameters,
        if (defaultValue != null) 'defaultValue': defaultValue,
        if (requiredFactTypes != null) 'requiredFactTypes': requiredFactTypes,
      };
}

/// Metric types.
enum MetricType {
  /// Point-in-time value.
  gauge,

  /// Cumulative counter.
  counter,

  /// Distribution/histogram.
  histogram,

  /// Summary statistics.
  summary,

  /// Boolean flag.
  flag,

  /// Categorical value.
  categorical,
}

/// Metric source types.
enum MetricSource {
  /// From fact graph queries.
  factgraph,

  /// Computed from other metrics.
  computed,

  /// From external system.
  external,

  /// Constant value.
  constant,
}

/// Aggregate metric definition.
class AggregateMetricDefinition {
  /// Metric name.
  final String name;

  /// Aggregation function.
  final AggregateFunction function;

  /// Source metric name.
  final String sourceMetric;

  /// Grouping keys.
  final List<String>? groupBy;

  /// Filter condition.
  final String? filter;

  const AggregateMetricDefinition({
    required this.name,
    required this.function,
    required this.sourceMetric,
    this.groupBy,
    this.filter,
  });

  /// Create from JSON.
  factory AggregateMetricDefinition.fromJson(Map<String, dynamic> json) {
    return AggregateMetricDefinition(
      name: json['name'] as String,
      function: AggregateFunction.values.firstWhere(
        (f) => f.name == json['function'],
        orElse: () => AggregateFunction.sum,
      ),
      sourceMetric: json['sourceMetric'] as String,
      groupBy: (json['groupBy'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      filter: json['filter'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'function': function.name,
        'sourceMetric': sourceMetric,
        if (groupBy != null) 'groupBy': groupBy,
        if (filter != null) 'filter': filter,
      };
}

/// Aggregate functions.
enum AggregateFunction {
  /// Sum of values.
  sum,

  /// Average of values.
  avg,

  /// Minimum value.
  min,

  /// Maximum value.
  max,

  /// Count of values.
  count,

  /// Median value.
  median,

  /// Standard deviation.
  stddev,

  /// Percentile value.
  percentile,
}

/// Empty implementation for testing.
class EmptyAppraisalPort implements AppraisalPort {
  const EmptyAppraisalPort();

  @override
  Future<MetricComputeResult> computeMetrics({
    required String entityId,
    required List<MetricDefinition> metrics,
    Period? period,
  }) async {
    return MetricComputeResult(
      values: {},
      confidence: 0,
      computedAt: DateTime.now(),
      duration: Duration.zero,
    );
  }

  @override
  Future<MetricComputeResult> computeAggregate({
    required List<String> entityIds,
    required AggregateMetricDefinition aggregateMetric,
    Period? period,
  }) async {
    return MetricComputeResult(
      values: {},
      confidence: 0,
      computedAt: DateTime.now(),
      duration: Duration.zero,
    );
  }

  @override
  Future<MetricValue?> getCachedMetric({
    required String entityId,
    required String metricName,
    Duration? maxAge,
  }) async =>
      null;

  @override
  Future<void> invalidateCache({
    String? entityId,
    String? metricName,
  }) async {}
}
