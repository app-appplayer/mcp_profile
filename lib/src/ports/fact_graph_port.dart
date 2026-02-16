/// FactGraph Port L1 - Minimal fact graph interface for profiles.
///
/// Provides read-only access to facts and metrics for profile evaluation.
/// This is the L1 (minimal) interface used by mcp_profile.
library;

/// FactGraph port for profile operations (L1 - read only).
abstract class FactGraphPortL1 {
  /// Query facts by entity and type.
  Future<List<Fact>> queryFacts({
    required String entityId,
    String? factType,
    Period? period,
    int? limit,
  });

  /// Get metric value for entity.
  Future<MetricValue?> getMetric({
    required String entityId,
    required String metricName,
    Period? period,
  });

  /// Get multiple metrics for entity.
  Future<Map<String, MetricValue>> getMetrics({
    required String entityId,
    required List<String> metricNames,
    Period? period,
  });

  /// Query summary for entity.
  Future<Summary?> getSummary({
    required String entityId,
    required String summaryType,
    Period? period,
  });

  /// Query patterns related to entity.
  Future<List<Pattern>> queryPatterns({
    required String entityId,
    String? patternType,
    int? limit,
  });

  /// Get context bundle for entity.
  Future<ContextBundle?> getContextBundle({
    required String entityId,
    required String bundleType,
    Period? period,
  });
}

/// A fact in the fact graph.
class Fact {
  /// Fact ID.
  final String id;

  /// Entity ID this fact belongs to.
  final String entityId;

  /// Fact type.
  final String type;

  /// Fact content.
  final Map<String, dynamic> content;

  /// Confidence score.
  final double confidence;

  /// Period when fact is valid.
  final Period? period;

  /// Evidence references.
  final List<String> evidenceRefs;

  /// Creation timestamp.
  final DateTime createdAt;

  const Fact({
    required this.id,
    required this.entityId,
    required this.type,
    required this.content,
    this.confidence = 1.0,
    this.period,
    this.evidenceRefs = const [],
    required this.createdAt,
  });

  /// Create from JSON.
  factory Fact.fromJson(Map<String, dynamic> json) {
    return Fact(
      id: json['id'] as String,
      entityId: json['entityId'] as String,
      type: json['type'] as String,
      content: json['content'] as Map<String, dynamic>? ?? {},
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      period: json['period'] != null
          ? Period.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      evidenceRefs: (json['evidenceRefs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'entityId': entityId,
        'type': type,
        'content': content,
        'confidence': confidence,
        if (period != null) 'period': period!.toJson(),
        if (evidenceRefs.isNotEmpty) 'evidenceRefs': evidenceRefs,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A metric value.
class MetricValue {
  /// Metric name.
  final String name;

  /// Metric value.
  final dynamic value;

  /// Value type.
  final String valueType;

  /// Confidence.
  final double confidence;

  /// Computation timestamp.
  final DateTime computedAt;

  /// Period for this value.
  final Period? period;

  const MetricValue({
    required this.name,
    required this.value,
    this.valueType = 'number',
    this.confidence = 1.0,
    required this.computedAt,
    this.period,
  });

  /// Create from JSON.
  factory MetricValue.fromJson(Map<String, dynamic> json) {
    return MetricValue(
      name: json['name'] as String,
      value: json['value'],
      valueType: json['valueType'] as String? ?? 'number',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      computedAt: DateTime.parse(json['computedAt'] as String),
      period: json['period'] != null
          ? Period.fromJson(json['period'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'valueType': valueType,
        'confidence': confidence,
        'computedAt': computedAt.toIso8601String(),
        if (period != null) 'period': period!.toJson(),
      };

  /// Get value as double.
  double? get asDouble {
    if (value is num) return (value as num).toDouble();
    return null;
  }

  /// Get value as int.
  int? get asInt {
    if (value is num) return (value as num).toInt();
    return null;
  }

  /// Get value as string.
  String? get asString {
    if (value == null) return null;
    return value.toString();
  }
}

/// A summary.
class Summary {
  /// Summary ID.
  final String id;

  /// Entity ID.
  final String entityId;

  /// Summary type.
  final String type;

  /// Summary content.
  final String content;

  /// Confidence score.
  final double confidence;

  /// Period covered.
  final Period? period;

  /// Source fact IDs.
  final List<String> sourceFactIds;

  /// Creation timestamp.
  final DateTime createdAt;

  const Summary({
    required this.id,
    required this.entityId,
    required this.type,
    required this.content,
    this.confidence = 1.0,
    this.period,
    this.sourceFactIds = const [],
    required this.createdAt,
  });

  /// Create from JSON.
  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      id: json['id'] as String,
      entityId: json['entityId'] as String,
      type: json['type'] as String,
      content: json['content'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      period: json['period'] != null
          ? Period.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      sourceFactIds: (json['sourceFactIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'entityId': entityId,
        'type': type,
        'content': content,
        'confidence': confidence,
        if (period != null) 'period': period!.toJson(),
        if (sourceFactIds.isNotEmpty) 'sourceFactIds': sourceFactIds,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A pattern detected in data.
class Pattern {
  /// Pattern ID.
  final String id;

  /// Pattern type.
  final String type;

  /// Pattern description.
  final String description;

  /// Confidence score.
  final double confidence;

  /// Pattern frequency.
  final int frequency;

  /// Related entity IDs.
  final List<String> entityIds;

  /// Pattern features.
  final Map<String, dynamic> features;

  /// Detection timestamp.
  final DateTime detectedAt;

  const Pattern({
    required this.id,
    required this.type,
    required this.description,
    this.confidence = 1.0,
    this.frequency = 1,
    this.entityIds = const [],
    this.features = const {},
    required this.detectedAt,
  });

  /// Create from JSON.
  factory Pattern.fromJson(Map<String, dynamic> json) {
    return Pattern(
      id: json['id'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      frequency: json['frequency'] as int? ?? 1,
      entityIds: (json['entityIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      features: json['features'] as Map<String, dynamic>? ?? {},
      detectedAt: DateTime.parse(json['detectedAt'] as String),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'description': description,
        'confidence': confidence,
        'frequency': frequency,
        if (entityIds.isNotEmpty) 'entityIds': entityIds,
        if (features.isNotEmpty) 'features': features,
        'detectedAt': detectedAt.toIso8601String(),
      };
}

/// A context bundle containing related facts.
class ContextBundle {
  /// Bundle ID.
  final String id;

  /// Bundle type.
  final String type;

  /// Primary entity ID.
  final String entityId;

  /// Facts in the bundle.
  final List<Fact> facts;

  /// Metrics in the bundle.
  final Map<String, MetricValue> metrics;

  /// Summaries in the bundle.
  final List<Summary> summaries;

  /// Period covered.
  final Period? period;

  /// Creation timestamp.
  final DateTime createdAt;

  const ContextBundle({
    required this.id,
    required this.type,
    required this.entityId,
    this.facts = const [],
    this.metrics = const {},
    this.summaries = const [],
    this.period,
    required this.createdAt,
  });

  /// Create from JSON.
  factory ContextBundle.fromJson(Map<String, dynamic> json) {
    return ContextBundle(
      id: json['id'] as String,
      type: json['type'] as String,
      entityId: json['entityId'] as String,
      facts: (json['facts'] as List<dynamic>?)
              ?.map((e) => Fact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metrics: (json['metrics'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, MetricValue.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
      summaries: (json['summaries'] as List<dynamic>?)
              ?.map((e) => Summary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      period: json['period'] != null
          ? Period.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'entityId': entityId,
        if (facts.isNotEmpty) 'facts': facts.map((f) => f.toJson()).toList(),
        if (metrics.isNotEmpty)
          'metrics': metrics.map((k, v) => MapEntry(k, v.toJson())),
        if (summaries.isNotEmpty)
          'summaries': summaries.map((s) => s.toJson()).toList(),
        if (period != null) 'period': period!.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Time period.
class Period {
  /// Start date.
  final DateTime start;

  /// End date.
  final DateTime end;

  const Period({
    required this.start,
    required this.end,
  });

  /// Create from JSON.
  factory Period.fromJson(Map<String, dynamic> json) {
    return Period(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  /// Duration of the period.
  Duration get duration => end.difference(start);

  /// Check if date is within period.
  bool contains(DateTime date) {
    return !date.isBefore(start) && !date.isAfter(end);
  }

  /// Create a period for last N days.
  factory Period.lastDays(int days) {
    final now = DateTime.now();
    return Period(
      start: now.subtract(Duration(days: days)),
      end: now,
    );
  }

  /// Create a period for last N hours.
  factory Period.lastHours(int hours) {
    final now = DateTime.now();
    return Period(
      start: now.subtract(Duration(hours: hours)),
      end: now,
    );
  }
}

/// Empty implementation for testing.
class EmptyFactGraphPortL1 implements FactGraphPortL1 {
  const EmptyFactGraphPortL1();

  @override
  Future<List<Fact>> queryFacts({
    required String entityId,
    String? factType,
    Period? period,
    int? limit,
  }) async =>
      [];

  @override
  Future<MetricValue?> getMetric({
    required String entityId,
    required String metricName,
    Period? period,
  }) async =>
      null;

  @override
  Future<Map<String, MetricValue>> getMetrics({
    required String entityId,
    required List<String> metricNames,
    Period? period,
  }) async =>
      {};

  @override
  Future<Summary?> getSummary({
    required String entityId,
    required String summaryType,
    Period? period,
  }) async =>
      null;

  @override
  Future<List<Pattern>> queryPatterns({
    required String entityId,
    String? patternType,
    int? limit,
  }) async =>
      [];

  @override
  Future<ContextBundle?> getContextBundle({
    required String entityId,
    required String bundleType,
    Period? period,
  }) async =>
      null;
}
