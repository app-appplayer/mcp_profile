/// Metric Source Types - Sources for computing appraisal metrics.
///
/// Defines the four source types as per spec/02-appraisal-metrics-schema.md:
/// - factgraph: Query FactGraph for facts/events
/// - computed: Compute from other metrics using expressions
/// - static: Fixed constant value
/// - llm_derived: LLM analysis (use sparingly for cost)
library;

import 'package:mcp_bundle/ports.dart';
import 'package:mcp_bundle/src/types/appraisal_result.dart'
    show MetricSourceType;

// MetricSourceType is now defined in mcp_bundle (Contract Layer).
export 'package:mcp_bundle/src/types/appraisal_result.dart'
    show MetricSourceType;

/// Definition of how to compute a metric value.
sealed class MetricSource {
  const MetricSource();

  /// Get source type.
  MetricSourceType get type;

  /// Create from JSON.
  factory MetricSource.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'factgraph' => FactGraphSource.fromJson(json),
      'computed' => ComputedSource.fromJson(json),
      'static' => StaticSource.fromJson(json),
      'llm_derived' => LlmDerivedSource.fromJson(json),
      _ => throw ArgumentError('Unknown metric source type: $type'),
    };
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson();
}

// =============================================================================
// FactGraph Source (§4.1)
// =============================================================================

/// Source that queries FactGraph for facts/events and computes metric.
class FactGraphSource extends MetricSource {
  /// Fact types to filter by.
  final List<String>? factTypes;

  /// Entity types to filter by.
  final List<String>? entityTypes;

  /// Time window for query.
  final Period? period;

  /// Additional filters.
  final Map<String, dynamic>? filters;

  /// Aggregation function.
  final FactAggregation aggregation;

  /// Field to aggregate (if applicable).
  final String? field;

  const FactGraphSource({
    this.factTypes,
    this.entityTypes,
    this.period,
    this.filters,
    this.aggregation = FactAggregation.count,
    this.field,
  });

  @override
  MetricSourceType get type => MetricSourceType.factgraph;

  factory FactGraphSource.fromJson(Map<String, dynamic> json) {
    final factQuery = json['factQuery'] as Map<String, dynamic>? ?? json;
    return FactGraphSource(
      factTypes: (factQuery['factTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      entityTypes: (factQuery['entityTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      period: factQuery['period'] != null
          ? Period.fromJson(factQuery['period'] as Map<String, dynamic>)
          : null,
      filters: factQuery['filters'] as Map<String, dynamic>?,
      aggregation: FactAggregation.values.firstWhere(
        (a) => a.name == (factQuery['aggregation'] as String? ?? 'count'),
        orElse: () => FactAggregation.count,
      ),
      field: factQuery['field'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'factgraph',
        'factQuery': {
          if (factTypes != null) 'factTypes': factTypes,
          if (entityTypes != null) 'entityTypes': entityTypes,
          if (period != null) 'period': period!.toJson(),
          if (filters != null) 'filters': filters,
          'aggregation': aggregation.name,
          if (field != null) 'field': field,
        },
      };
}

/// Aggregation functions for fact queries.
enum FactAggregation {
  /// Count of matching facts.
  count,

  /// Average of field values.
  avg,

  /// Maximum field value.
  max,

  /// Minimum field value.
  min,

  /// Sum of field values.
  sum,

  /// Whether any matching fact exists (returns 1.0 or 0.0).
  presence,
}

// =============================================================================
// Computed Source (§4.2)
// =============================================================================

/// Source that computes metric from other metrics using expression.
class ComputedSource extends MetricSource {
  /// Expression to evaluate.
  /// Variables: other metric IDs, avgConfidence, avgSourceReliability,
  /// factCount, evidenceCount, conflictCount.
  final String expression;

  const ComputedSource({required this.expression});

  @override
  MetricSourceType get type => MetricSourceType.computed;

  factory ComputedSource.fromJson(Map<String, dynamic> json) {
    return ComputedSource(
      expression: json['expression'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'computed',
        'expression': expression,
      };
}

// =============================================================================
// Static Source (§4.3)
// =============================================================================

/// Source with a fixed constant value.
class StaticSource extends MetricSource {
  /// Fixed value.
  final double value;

  const StaticSource({required this.value});

  @override
  MetricSourceType get type => MetricSourceType.static_;

  factory StaticSource.fromJson(Map<String, dynamic> json) {
    return StaticSource(
      value: (json['value'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'static',
        'value': value,
      };
}

// =============================================================================
// LLM-Derived Source (§4.4)
// =============================================================================

/// Source that uses LLM for complex analysis.
class LlmDerivedSource extends MetricSource {
  /// Analysis prompt.
  final String prompt;

  /// Output type.
  final LlmOutputType outputType;

  /// Category to value mapping (for categorical output).
  final Map<String, double>? categories;

  /// Specific model to use.
  final String? model;

  /// Cache key for result caching.
  final String? cacheKey;

  const LlmDerivedSource({
    required this.prompt,
    this.outputType = LlmOutputType.numeric,
    this.categories,
    this.model,
    this.cacheKey,
  });

  @override
  MetricSourceType get type => MetricSourceType.llmDerived;

  factory LlmDerivedSource.fromJson(Map<String, dynamic> json) {
    final llmConfig = json['llmConfig'] as Map<String, dynamic>? ?? json;
    return LlmDerivedSource(
      prompt: llmConfig['prompt'] as String,
      outputType: LlmOutputType.values.firstWhere(
        (t) => t.name == (llmConfig['outputType'] as String? ?? 'numeric'),
        orElse: () => LlmOutputType.numeric,
      ),
      categories: (llmConfig['categories'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      model: llmConfig['model'] as String?,
      cacheKey: llmConfig['cacheKey'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'llm_derived',
        'llmConfig': {
          'prompt': prompt,
          'outputType': outputType.name,
          if (categories != null) 'categories': categories,
          if (model != null) 'model': model,
          if (cacheKey != null) 'cacheKey': cacheKey,
        },
      };
}

/// LLM output types for llm_derived source.
enum LlmOutputType {
  /// Direct numeric output.
  numeric,

  /// Categorical output mapped to numeric values.
  categorical,
}
