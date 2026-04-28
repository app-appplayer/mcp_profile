/// Appraisal Metric Definition - Schema for defining metrics.
///
/// As per spec/02-appraisal-metrics-schema.md §3.
library;

import 'metric_source.dart';
import 'normalization.dart';

// =============================================================================
// AppraisalMetricDef (§3)
// =============================================================================

/// Definition of an appraisal metric.
class AppraisalMetricDef {
  // === REQUIRED ===

  /// Unique metric ID.
  final String id;

  /// Human-readable name.
  final String name;

  /// How to compute the metric value.
  final MetricSource source;

  // === OPTIONAL ===

  /// Description of the metric.
  final String? description;

  /// Normalization to apply to raw value.
  final NormalizationConfig? normalization;

  /// Default value when computation fails or data unavailable.
  final double? defaultValue;

  /// Weight in aggregation (default: 1.0).
  final double weight;

  /// Whether to invert the normalized value (1 - value).
  final bool inverse;

  /// Categorization tags.
  final List<String> tags;

  const AppraisalMetricDef({
    required this.id,
    required this.name,
    required this.source,
    this.description,
    this.normalization,
    this.defaultValue,
    this.weight = 1.0,
    this.inverse = false,
    this.tags = const [],
  });

  factory AppraisalMetricDef.fromJson(Map<String, dynamic> json) {
    return AppraisalMetricDef(
      id: json['id'] as String,
      name: json['name'] as String,
      source: MetricSource.fromJson(json['source'] as Map<String, dynamic>),
      description: json['description'] as String?,
      normalization: json['normalization'] != null
          ? NormalizationConfig.fromJson(
              json['normalization'] as Map<String, dynamic>)
          : null,
      defaultValue: (json['defaultValue'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      inverse: json['inverse'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.toJson(),
        if (description != null) 'description': description,
        if (normalization != null) 'normalization': normalization!.toJson(),
        if (defaultValue != null) 'defaultValue': defaultValue,
        'weight': weight,
        if (inverse) 'inverse': inverse,
        if (tags.isNotEmpty) 'tags': tags,
      };
}

// =============================================================================
// AppraisalSection (§2)
// =============================================================================

/// Section defining metrics and their aggregation.
class AppraisalSection {
  /// Metrics in this section.
  final List<AppraisalMetricDef> metrics;

  /// Aggregation configuration.
  final AggregationConfig? aggregation;

  const AppraisalSection({
    required this.metrics,
    this.aggregation,
  });

  factory AppraisalSection.fromJson(Map<String, dynamic> json) {
    return AppraisalSection(
      metrics: (json['metrics'] as List<dynamic>)
          .map((e) => AppraisalMetricDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      aggregation: json['aggregation'] != null
          ? AggregationConfig.fromJson(
              json['aggregation'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'metrics': metrics.map((m) => m.toJson()).toList(),
        if (aggregation != null) 'aggregation': aggregation!.toJson(),
      };
}

// =============================================================================
// AggregationConfig (§2, §7)
// =============================================================================

/// Configuration for aggregating multiple metrics.
class AggregationConfig {
  /// Aggregation method.
  final AggregationMethod method;

  /// Override weights per metric (keyed by metric ID).
  final Map<String, double>? weights;

  /// Custom expression (for method = custom).
  final String? expression;

  const AggregationConfig({
    this.method = AggregationMethod.weightedAverage,
    this.weights,
    this.expression,
  });

  factory AggregationConfig.fromJson(Map<String, dynamic> json) {
    return AggregationConfig(
      method: AggregationMethod.values.firstWhere(
        (m) =>
            m.toJsonName() ==
            (json['method'] as String? ?? 'weighted_average'),
        orElse: () => AggregationMethod.weightedAverage,
      ),
      weights: (json['weights'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      expression: json['expression'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'method': method.toJsonName(),
        if (weights != null) 'weights': weights,
        if (expression != null) 'expression': expression,
      };
}

/// Aggregation methods (§7).
enum AggregationMethod {
  /// Weighted average: sum(metric * weight) / sum(weights).
  weightedAverage,

  /// Maximum of all metrics.
  max,

  /// Minimum of all metrics.
  min,

  /// Sum of all metrics (capped at 1.0).
  sum,

  /// Custom expression.
  custom,
}

extension AggregationMethodExtension on AggregationMethod {
  String toJsonName() {
    return switch (this) {
      AggregationMethod.weightedAverage => 'weighted_average',
      AggregationMethod.max => 'max',
      AggregationMethod.min => 'min',
      AggregationMethod.sum => 'sum',
      AggregationMethod.custom => 'custom',
    };
  }
}

// =============================================================================
// Standard Metrics (§6)
// =============================================================================

/// Standard metric definitions as per §6.
class StandardMetrics {
  /// Risk metric (§6.1): Potential negative impact.
  static AppraisalMetricDef risk({
    double weight = 0.35,
    double defaultValue = 0.3,
  }) {
    return AppraisalMetricDef(
      id: 'risk',
      name: 'Risk Level',
      description: 'Potential for negative outcomes',
      source: const FactGraphSource(
        factTypes: [
          'risk_indicator',
          'security_issue',
          'compliance_violation',
          'financial_impact'
        ],
        aggregation: FactAggregation.max,
        field: 'severity',
      ),
      normalization: const MinMaxNormalization(min: 0, max: 10),
      defaultValue: defaultValue,
      weight: weight,
    );
  }

  /// Uncertainty metric (§6.2): Lack of confidence in available data.
  static AppraisalMetricDef uncertainty({
    double weight = 0.25,
    double defaultValue = 0.5,
  }) {
    return AppraisalMetricDef(
      id: 'uncertainty',
      name: 'Uncertainty',
      description: 'Lack of confidence in available information',
      source: const ComputedSource(expression: '1 - avgConfidence'),
      defaultValue: defaultValue,
      weight: weight,
    );
  }

  /// Urgency metric (§6.3): Time sensitivity.
  static AppraisalMetricDef urgency({
    double weight = 0.2,
    double defaultValue = 0.3,
  }) {
    return AppraisalMetricDef(
      id: 'urgency',
      name: 'Urgency',
      description: 'Time sensitivity of the situation',
      source: const FactGraphSource(
        factTypes: ['deadline', 'sla', 'time_constraint'],
        aggregation: FactAggregation.max,
        field: 'urgency_score',
      ),
      normalization: const MinMaxNormalization(min: 0, max: 100),
      defaultValue: defaultValue,
      weight: weight,
    );
  }

  /// Trust metric (§6.4): Source reliability.
  static AppraisalMetricDef trust({
    double weight = 0.1,
    double defaultValue = 0.7,
  }) {
    return AppraisalMetricDef(
      id: 'trust',
      name: 'Source Trust',
      description: 'Reliability of information sources',
      source: const ComputedSource(expression: 'avgSourceReliability'),
      defaultValue: defaultValue,
      weight: weight,
    );
  }

  /// Sentiment metric (§6.5): Relationship/emotional context.
  static AppraisalMetricDef sentiment({
    double weight = 0.1,
    double defaultValue = 0.5,
  }) {
    return AppraisalMetricDef(
      id: 'sentiment',
      name: 'Sentiment',
      description: 'Relationship and emotional context',
      source: const FactGraphSource(
        factTypes: ['feedback', 'satisfaction_indicator', 'relationship_signal'],
        aggregation: FactAggregation.avg,
        field: 'sentiment_score',
      ),
      normalization: const MinMaxNormalization(min: -1, max: 1),
      defaultValue: defaultValue,
      weight: weight,
    );
  }

  /// Get all standard metrics with default configuration.
  static List<AppraisalMetricDef> all() {
    return [
      risk(),
      uncertainty(),
      urgency(),
      trust(),
      sentiment(),
    ];
  }
}
