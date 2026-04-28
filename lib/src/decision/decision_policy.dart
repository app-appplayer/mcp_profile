/// Decision Policy Types - Policy definitions and results.
///
/// As per spec/03-decision-policy-schema.md §2, §3, §8.
library;

import 'decision_guidance.dart';
import 'policy_condition.dart';

// =============================================================================
// DecisionPolicySection (§2)
// =============================================================================

/// Section containing decision policies.
class DecisionPolicySection {
  /// Policies in evaluation order (sorted by priority).
  final List<DecisionPolicy> policies;

  /// Default policy ID for fallback.
  final String? defaultPolicy;

  /// Conflict resolution strategy.
  final ConflictResolution conflictResolution;

  const DecisionPolicySection({
    required this.policies,
    this.defaultPolicy,
    this.conflictResolution = ConflictResolution.firstMatch,
  });

  /// Get policy by ID.
  DecisionPolicy? getPolicy(String id) {
    try {
      return policies.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get sorted policies by priority (higher first).
  List<DecisionPolicy> get sortedPolicies {
    final sorted = List<DecisionPolicy>.from(policies);
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
  }

  factory DecisionPolicySection.fromJson(Map<String, dynamic> json) {
    return DecisionPolicySection(
      policies: (json['policies'] as List<dynamic>)
          .map((e) => DecisionPolicy.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultPolicy: json['defaultPolicy'] as String?,
      conflictResolution: ConflictResolution.values.firstWhere(
        (c) =>
            c.toJsonName() ==
            (json['conflictResolution'] as String? ?? 'first_match'),
        orElse: () => ConflictResolution.firstMatch,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'policies': policies.map((p) => p.toJson()).toList(),
        if (defaultPolicy != null) 'defaultPolicy': defaultPolicy,
        'conflictResolution': conflictResolution.toJsonName(),
      };
}

/// Conflict resolution strategies.
enum ConflictResolution {
  /// First matching policy wins.
  firstMatch,

  /// Last matching policy wins.
  lastMatch,

  /// Highest priority policy wins.
  highestPriority,

  /// Most restrictive (least permissive) policy wins.
  mostRestrictive,

  /// Most specific condition wins.
  mostSpecific,

  /// All matching policies must agree (unanimous consent).
  unanimous,

  /// Majority of matching policies determines outcome.
  majority,

  /// Merge guidance from all matching policies.
  merge,

  /// Custom resolution via external handler.
  custom,
}

/// Alias for use in stacking/resolution contexts.
typedef ConflictResolutionStrategy = ConflictResolution;

extension ConflictResolutionExtension on ConflictResolution {
  String toJsonName() {
    return switch (this) {
      ConflictResolution.firstMatch => 'first_match',
      ConflictResolution.lastMatch => 'last_match',
      ConflictResolution.highestPriority => 'highest_priority',
      ConflictResolution.mostRestrictive => 'most_restrictive',
      ConflictResolution.mostSpecific => 'most_specific',
      ConflictResolution.unanimous => 'unanimous',
      ConflictResolution.majority => 'majority',
      ConflictResolution.merge => 'merge',
      ConflictResolution.custom => 'custom',
    };
  }
}

// =============================================================================
// DecisionPolicy (§3)
// =============================================================================

/// A single decision policy.
class DecisionPolicy implements Policy {
  // === REQUIRED ===

  /// Unique policy ID.
  final String id;

  /// Human-readable name.
  final String name;

  /// When this policy applies.
  final PolicyCondition condition;

  /// What to recommend when condition matches.
  final DecisionGuidance guidance;

  // === OPTIONAL ===

  /// Policy description.
  final String? description;

  /// Evaluation priority (higher first).
  final int priority;

  /// Whether policy is active.
  final bool enabled;

  /// Categorization tags.
  final List<String> tags;

  const DecisionPolicy({
    required this.id,
    required this.name,
    required this.condition,
    required this.guidance,
    this.description,
    this.priority = 0,
    this.enabled = true,
    this.tags = const [],
  });

  /// Create a copy with overridden fields.
  DecisionPolicy copyWith({
    String? id,
    String? name,
    PolicyCondition? condition,
    DecisionGuidance? guidance,
    String? description,
    int? priority,
    bool? enabled,
    List<String>? tags,
  }) {
    return DecisionPolicy(
      id: id ?? this.id,
      name: name ?? this.name,
      condition: condition ?? this.condition,
      guidance: guidance ?? this.guidance,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      tags: tags ?? this.tags,
    );
  }

  /// Evaluate this policy against metrics.
  bool matches(Map<String, double> metrics, double aggregatedScore) {
    if (!enabled) return false;
    return condition.evaluate(metrics, aggregatedScore);
  }

  factory DecisionPolicy.fromJson(Map<String, dynamic> json) {
    return DecisionPolicy(
      id: json['id'] as String,
      name: json['name'] as String,
      condition:
          PolicyCondition.fromJson(json['condition'] as Map<String, dynamic>),
      guidance:
          DecisionGuidance.fromJson(json['guidance'] as Map<String, dynamic>),
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
        'guidance': guidance.toJson(),
        if (description != null) 'description': description,
        'priority': priority,
        if (!enabled) 'enabled': enabled,
        if (tags.isNotEmpty) 'tags': tags,
      };
}

// =============================================================================
// DecisionResult (§8) - per design/02-ports.md §6
// =============================================================================

/// Decision result wrapper type per design/02-ports.md §6.
/// Wraps DecisionGuidance with evaluation metadata for downstream consumers.
class DecisionResult {
  /// Guidance from the evaluation.
  final DecisionGuidance guidance;

  /// All policies that matched during evaluation.
  final List<DecisionPolicy> matchedPolicies;

  /// Trace ID for evaluation tracking.
  final String? evaluationTraceId;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const DecisionResult({
    required this.guidance,
    this.matchedPolicies = const [],
    this.evaluationTraceId,
    this.metadata,
  });

  /// Whether this result allows proceeding.
  bool get allowsProceeding => guidance.action.allowsProceeding;

  /// Whether this result blocks proceeding.
  bool get blocksProceeding => guidance.action.blocksProceeding;

  /// Whether this result requires human intervention.
  bool get requiresHuman => guidance.action.requiresHuman ||
      guidance.requiresApproval;

  factory DecisionResult.fromJson(Map<String, dynamic> json) {
    return DecisionResult(
      guidance:
          DecisionGuidance.fromJson(json['guidance'] as Map<String, dynamic>),
      matchedPolicies: (json['matchedPolicies'] as List<dynamic>?)
              ?.map((e) => DecisionPolicy.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      evaluationTraceId: json['evaluationTraceId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'guidance': guidance.toJson(),
        if (matchedPolicies.isNotEmpty)
          'matchedPolicies': matchedPolicies.map((p) => p.toJson()).toList(),
        if (evaluationTraceId != null) 'evaluationTraceId': evaluationTraceId,
        if (metadata != null) 'metadata': metadata,
      };
}

// =============================================================================
// Standard Policies (§7)
// =============================================================================

/// Standard decision policies as per §7.
class StandardPolicies {
  /// Critical risk reject policy (§7.1).
  static DecisionPolicy criticalRiskReject({int priority = 100}) {
    return DecisionPolicy(
      id: 'critical_risk_reject',
      name: 'Reject on Critical Risk',
      condition: const ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
      ),
      guidance: const DecisionGuidance(
        action: DecisionAction.reject,
        confidence: 0.95,
        explanation: 'Risk level is critical and unacceptable',
      ),
      priority: priority,
    );
  }

  /// High risk escalate policy (§7.1).
  static DecisionPolicy highRiskEscalate({int priority = 90}) {
    return DecisionPolicy(
      id: 'high_risk_escalate',
      name: 'Escalate on High Risk',
      condition: const ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.7,
      ),
      guidance: DecisionGuidance(
        action: DecisionAction.escalate,
        confidence: 0.85,
        explanation: 'High risk requires expert review',
        modifiers: [
          DecisionModifier.requireApproval(approverRole: 'risk_officer'),
        ],
      ),
      priority: priority,
    );
  }

  /// Moderate risk caution policy (§7.1).
  static DecisionPolicy moderateRiskCaution({int priority = 50}) {
    return DecisionPolicy(
      id: 'moderate_risk_caution',
      name: 'Caution on Moderate Risk',
      condition: const ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.4,
      ),
      guidance: DecisionGuidance(
        action: DecisionAction.proceedWithCaution,
        explanation: 'Proceed carefully with enhanced monitoring',
        modifiers: [
          DecisionModifier.log(level: 'warning'),
        ],
      ),
      priority: priority,
    );
  }

  /// High uncertainty question policy (§7.2).
  static DecisionPolicy highUncertaintyQuestion({int priority = 80}) {
    return DecisionPolicy(
      id: 'high_uncertainty_question',
      name: 'Question When Very Uncertain',
      condition: const ThresholdCondition(
        metric: 'uncertainty',
        operator: ComparisonOperator.greaterThan,
        value: 0.7,
      ),
      guidance: DecisionGuidance(
        action: DecisionAction.question,
        explanation: 'Insufficient information to proceed',
        modifiers: [
          DecisionModifier.requireEvidence(minSources: 2),
        ],
      ),
      priority: priority,
    );
  }

  /// Get all standard risk-based policies.
  static List<DecisionPolicy> riskBasedPolicies() {
    return [
      criticalRiskReject(),
      highRiskEscalate(),
      moderateRiskCaution(),
    ];
  }

  /// Get all standard uncertainty-based policies.
  static List<DecisionPolicy> uncertaintyBasedPolicies() {
    return [
      highUncertaintyQuestion(),
    ];
  }

  /// Get all standard policies.
  static List<DecisionPolicy> all() {
    return [
      ...riskBasedPolicies(),
      ...uncertaintyBasedPolicies(),
    ];
  }
}
