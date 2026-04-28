/// Expression Policy Types - Policy definitions and results.
///
/// As per spec/04-expression-policy-schema.md §2, §3, §11.
library;

import '../decision/policy_condition.dart';
import 'expression_style.dart';

// =============================================================================
// ExpressionPolicySection (§2)
// =============================================================================

/// Section containing expression policies.
class ExpressionPolicySection {
  /// Policies in evaluation order.
  final List<ExpressionPolicy> policies;

  /// Default policy ID for fallback.
  final String? defaultPolicy;

  /// Global style overrides applied to all policies.
  final ExpressionStyle? globalOverrides;

  const ExpressionPolicySection({
    required this.policies,
    this.defaultPolicy,
    this.globalOverrides,
  });

  /// Get policy by ID.
  ExpressionPolicy? getPolicy(String id) {
    try {
      return policies.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get sorted policies by priority (higher first).
  List<ExpressionPolicy> get sortedPolicies {
    final sorted = List<ExpressionPolicy>.from(policies);
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
  }

  factory ExpressionPolicySection.fromJson(Map<String, dynamic> json) {
    return ExpressionPolicySection(
      policies: (json['policies'] as List<dynamic>)
          .map((e) => ExpressionPolicy.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultPolicy: json['defaultPolicy'] as String?,
      globalOverrides: json['globalOverrides'] != null
          ? ExpressionStyle.fromJson(
              json['globalOverrides'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'policies': policies.map((p) => p.toJson()).toList(),
        if (defaultPolicy != null) 'defaultPolicy': defaultPolicy,
        if (globalOverrides != null) 'globalOverrides': globalOverrides!.toJson(),
      };
}

// =============================================================================
// ExpressionPolicy (§3)
// =============================================================================

/// A single expression policy.
class ExpressionPolicy implements Policy {
  // === REQUIRED ===

  /// Unique policy ID.
  final String id;

  /// Human-readable name.
  final String name;

  /// When this policy applies.
  final PolicyCondition condition;

  /// How to express when condition matches.
  final ExpressionStyle style;

  // === OPTIONAL ===

  /// Policy description.
  final String? description;

  /// Evaluation priority (higher first).
  final int priority;

  /// Whether policy is active.
  final bool enabled;

  /// Categorization tags.
  final List<String> tags;

  const ExpressionPolicy({
    required this.id,
    required this.name,
    required this.condition,
    required this.style,
    this.description,
    this.priority = 0,
    this.enabled = true,
    this.tags = const [],
  });

  /// Evaluate this policy against metrics.
  bool matches(Map<String, double> metrics, double aggregatedScore) {
    if (!enabled) return false;
    return condition.evaluate(metrics, aggregatedScore);
  }

  factory ExpressionPolicy.fromJson(Map<String, dynamic> json) {
    return ExpressionPolicy(
      id: json['id'] as String,
      name: json['name'] as String,
      condition:
          PolicyCondition.fromJson(json['condition'] as Map<String, dynamic>),
      style: ExpressionStyle.fromJson(json['style'] as Map<String, dynamic>),
      description: json['description'] as String?,
      priority: json['priority'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'condition': condition.toJson(),
        'style': style.toJson(),
        if (description != null) 'description': description,
        'priority': priority,
        if (!enabled) 'enabled': enabled,
        if (tags.isNotEmpty) 'tags': tags,
      };
}

// =============================================================================
// ExpressionResult (§11)
// =============================================================================

/// Result of expression policy evaluation.
class ExpressionResult {
  /// Profile ID that was applied.
  final String profileId;

  /// Policy ID that matched.
  final String policyId;

  /// Appraisal result ID.
  final String appraisalId;

  /// Computed style.
  final ExpressionStyle style;

  /// Formatted content (if provided).
  final String? formattedContent;

  /// Evaluation metadata.
  final ExpressionResultMetadata metadata;

  const ExpressionResult({
    required this.profileId,
    required this.policyId,
    required this.appraisalId,
    required this.style,
    this.formattedContent,
    required this.metadata,
  });

  factory ExpressionResult.fromJson(Map<String, dynamic> json) {
    return ExpressionResult(
      profileId: json['profileId'] as String,
      policyId: json['policyId'] as String,
      appraisalId: json['appraisalId'] as String,
      style: ExpressionStyle.fromJson(json['style'] as Map<String, dynamic>),
      formattedContent: json['formattedContent'] as String?,
      metadata: ExpressionResultMetadata.fromJson(
          json['metadata'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'policyId': policyId,
        'appraisalId': appraisalId,
        'style': style.toJson(),
        if (formattedContent != null) 'formattedContent': formattedContent,
        'metadata': metadata.toJson(),
      };
}

/// Metadata about expression evaluation.
class ExpressionResultMetadata {
  /// When evaluation was performed.
  final DateTime evaluatedAt;

  /// Hedging information: either a bool (whether hedging was applied)
  /// or a List<String> of hedging phrases that were applied.
  final Object hedgingApplied;

  /// Audience adaptation used (if any).
  final String? audienceAdaptation;

  const ExpressionResultMetadata({
    required this.evaluatedAt,
    required this.hedgingApplied,
    this.audienceAdaptation,
  });

  /// Whether any hedging was applied.
  bool get hasHedging {
    final value = hedgingApplied;
    if (value is bool) return value;
    if (value is List) return value.isNotEmpty;
    return false;
  }

  /// Get hedging phrases if available.
  List<String> get hedgingPhrases {
    final value = hedgingApplied;
    if (value is List) return value.cast<String>();
    return const [];
  }

  factory ExpressionResultMetadata.fromJson(Map<String, dynamic> json) {
    final hedging = json['hedgingApplied'];
    final Object hedgingValue;
    if (hedging is List) {
      hedgingValue = hedging.cast<String>();
    } else {
      hedgingValue = hedging as bool? ?? false;
    }

    return ExpressionResultMetadata(
      evaluatedAt: DateTime.parse(json['evaluatedAt'] as String),
      hedgingApplied: hedgingValue,
      audienceAdaptation: json['audienceAdaptation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'hedgingApplied': hedgingApplied,
        if (audienceAdaptation != null) 'audienceAdaptation': audienceAdaptation,
      };
}

// =============================================================================
// Standard Expression Policies (§10)
// =============================================================================

/// Standard expression policies per §10.
class StandardExpressionPolicies {
  /// High uncertainty tentative (§10.1).
  static ExpressionPolicy highUncertaintyTentative({int priority = 90}) {
    return ExpressionPolicy(
      id: 'high_uncertainty_tentative',
      name: 'Highly Tentative',
      condition: const ThresholdCondition(
        metric: 'uncertainty',
        operator: ComparisonOperator.greaterThan,
        value: 0.7,
      ),
      style: const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.tentative,
          empathy: Empathy.moderate,
          directness: Directness.diplomatic,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
          includeEvidence: true,
          includeCaveats: true,
          includeAlternatives: true,
        ),
        hedging: HedgingConfig(
          level: HedgingLevel.strong,
          position: HedgingPosition.start,
        ),
      ),
      priority: priority,
    );
  }

  /// Moderate uncertainty balanced (§10.1).
  static ExpressionPolicy moderateUncertaintyBalanced({int priority = 50}) {
    return ExpressionPolicy(
      id: 'moderate_uncertainty_balanced',
      name: 'Balanced with Caveats',
      condition: const ThresholdCondition(
        metric: 'uncertainty',
        operator: ComparisonOperator.greaterThan,
        value: 0.4,
      ),
      style: const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.neutral,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.moderate,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.mixed,
          length: Length.standard,
          includeEvidence: true,
          includeCaveats: true,
          includeAlternatives: false,
        ),
        hedging: HedgingConfig(
          level: HedgingLevel.moderate,
          position: HedgingPosition.inline,
        ),
      ),
      priority: priority,
    );
  }

  /// Urgent concise (§10.2).
  static ExpressionPolicy urgentConcise({int priority = 100}) {
    return ExpressionPolicy(
      id: 'urgent_concise',
      name: 'Urgent Concise',
      condition: const ThresholdCondition(
        metric: 'urgency',
        operator: ComparisonOperator.greaterThan,
        value: 0.8,
      ),
      style: const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.neutral,
          confidence: ToneConfidence.assertive,
          empathy: Empathy.low,
          directness: Directness.direct,
        ),
        format: FormatConfig(
          structure: Structure.bullets,
          length: Length.concise,
          includeEvidence: false,
          includeCaveats: false,
          includeAlternatives: false,
          includeNextSteps: true,
          maxBullets: 5,
        ),
        hedging: HedgingConfig(level: HedgingLevel.none),
      ),
      priority: priority,
    );
  }

  /// High risk formal (§10.3).
  static ExpressionPolicy highRiskFormal({int priority = 80}) {
    return ExpressionPolicy(
      id: 'high_risk_formal',
      name: 'Formal Risk Communication',
      condition: const ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.6,
      ),
      style: const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.moderate,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.numbered,
          length: Length.detailed,
          includeEvidence: true,
          includeCaveats: true,
          includeAlternatives: true,
          includeNextSteps: true,
        ),
        hedging: HedgingConfig(level: HedgingLevel.light),
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.internal,
        ),
      ),
      priority: priority,
    );
  }

  /// Low trust qualified (§10.4).
  static ExpressionPolicy lowTrustQualified({int priority = 70}) {
    return ExpressionPolicy(
      id: 'low_trust_qualified',
      name: 'Qualified with Sources',
      condition: const ThresholdCondition(
        metric: 'trust',
        operator: ComparisonOperator.lessThan,
        value: 0.5,
      ),
      style: const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.tentative,
          empathy: Empathy.low,
          directness: Directness.diplomatic,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
          includeEvidence: true,
          includeCaveats: true,
          includeAlternatives: true,
        ),
        hedging: HedgingConfig(
          level: HedgingLevel.moderate,
          phrases: HedgingPhrases(
            qualifying: [
              'according to unverified sources',
              'based on preliminary data',
            ],
          ),
        ),
      ),
      priority: priority,
    );
  }

  /// Get all standard policies.
  static List<ExpressionPolicy> all() {
    return [
      urgentConcise(),
      highUncertaintyTentative(),
      highRiskFormal(),
      lowTrustQualified(),
      moderateUncertaintyBalanced(),
    ];
  }
}
