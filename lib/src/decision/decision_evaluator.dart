/// Decision Policy Evaluator - Evaluates policies against appraisal metrics.
///
/// Implements the policy evaluation flow per spec/03-decision-policy-schema.md §6.
library;

import 'dart:math' as math;

import '../appraisal/appraisal_result.dart';
import 'decision_guidance.dart';
import 'decision_policy.dart';
import 'policy_condition.dart';

// =============================================================================
// DecisionPolicyEvaluator (§6)
// =============================================================================

/// Evaluator that matches policies against appraisal results.
///
/// Evaluation flow per §6:
/// 1. Sort policies by priority (descending)
/// 2. For each policy, evaluate condition against metrics
/// 3. First matching policy provides guidance
/// 4. If no match, use defaultPolicy or default "proceed"
class DecisionPolicyEvaluator {
  const DecisionPolicyEvaluator();

  /// Evaluate policies against appraisal results.
  ///
  /// Respects policySection.conflictResolution per spec/03 §2:
  /// - firstMatch / highestPriority: first matching policy wins
  /// - mostRestrictive: most restrictive action wins
  /// - mostSpecific: most specific condition wins
  /// - merge: merge guidance from all matching policies
  DecisionResult evaluate({
    required DecisionPolicySection policySection,
    required AppraisalResult appraisalResult,
    required String profileId,
  }) {
    final evaluationPath = <String>[];
    final startTime = DateTime.now();

    // Extract metric values for condition evaluation
    final metricValues = <String, double>{};
    for (final entry in appraisalResult.metrics.entries) {
      metricValues[entry.key] = entry.value.normalizedValue;
    }
    final aggregatedScore = appraisalResult.aggregatedScore;

    // Sort policies by priority
    final sortedPolicies = policySection.sortedPolicies;

    final strategy = policySection.conflictResolution;

    // For first_match and highest_priority: return first match
    if (strategy == ConflictResolution.firstMatch ||
        strategy == ConflictResolution.highestPriority) {
      return _evaluateFirstMatch(
        sortedPolicies: sortedPolicies,
        policySection: policySection,
        metricValues: metricValues,
        aggregatedScore: aggregatedScore,
        evaluationPath: evaluationPath,
        startTime: startTime,
      );
    }

    // For other strategies: collect all matching policies
    final matchingPolicies = <DecisionPolicy>[];
    for (final policy in sortedPolicies) {
      evaluationPath.add(policy.id);
      if (policy.matches(metricValues, aggregatedScore)) {
        matchingPolicies.add(policy);
      }
    }

    if (matchingPolicies.isEmpty) {
      return _defaultResult(
        policySection: policySection,
        evaluationPath: evaluationPath,
        startTime: startTime,
      );
    }

    // Apply conflict resolution strategy
    final resolved = switch (strategy) {
      ConflictResolution.mostRestrictive =>
        _resolveMostRestrictive(matchingPolicies),
      ConflictResolution.mostSpecific =>
        _resolveMostSpecific(matchingPolicies),
      ConflictResolution.merge =>
        _resolveMerge(matchingPolicies),
      // firstMatch/highestPriority already handled above
      _ => matchingPolicies.first,
    };

    if (resolved is DecisionPolicy) {
      return DecisionResult(
        guidance: resolved.guidance,
        matchedPolicies: matchingPolicies,
        metadata: {
          'evaluatedAt': startTime.toIso8601String(),
          'policiesEvaluated': evaluationPath.length,
          'evaluationPath': evaluationPath,
        },
      );
    }

    // For merge strategy, resolved is a _MergedResult
    final merged = resolved as _MergedResult;
    return DecisionResult(
      guidance: merged.guidance,
      matchedPolicies: matchingPolicies,
      metadata: {
        'evaluatedAt': startTime.toIso8601String(),
        'policiesEvaluated': evaluationPath.length,
        'evaluationPath': evaluationPath,
        'mergedPolicyIds': merged.policyIds,
      },
    );
  }

  /// First-match evaluation (for firstMatch and highestPriority).
  DecisionResult _evaluateFirstMatch({
    required List<DecisionPolicy> sortedPolicies,
    required DecisionPolicySection policySection,
    required Map<String, double> metricValues,
    required double aggregatedScore,
    required List<String> evaluationPath,
    required DateTime startTime,
  }) {
    for (final policy in sortedPolicies) {
      evaluationPath.add(policy.id);
      if (policy.matches(metricValues, aggregatedScore)) {
        return DecisionResult(
          guidance: policy.guidance,
          matchedPolicies: [policy],
          metadata: {
            'evaluatedAt': startTime.toIso8601String(),
            'policiesEvaluated': evaluationPath.length,
            'evaluationPath': evaluationPath,
          },
        );
      }
    }

    return _defaultResult(
      policySection: policySection,
      evaluationPath: evaluationPath,
      startTime: startTime,
    );
  }

  /// Default result when no policy matches.
  DecisionResult _defaultResult({
    required DecisionPolicySection policySection,
    required List<String> evaluationPath,
    required DateTime startTime,
  }) {
    if (policySection.defaultPolicy != null) {
      final defaultPolicy =
          policySection.getPolicy(policySection.defaultPolicy!);
      if (defaultPolicy != null) {
        evaluationPath.add(defaultPolicy.id);
        return DecisionResult(
          guidance: defaultPolicy.guidance,
          matchedPolicies: [defaultPolicy],
          metadata: {
            'evaluatedAt': startTime.toIso8601String(),
            'policiesEvaluated': evaluationPath.length,
            'evaluationPath': evaluationPath,
            'source': 'defaultPolicy',
          },
        );
      }
    }

    return DecisionResult(
      guidance: DecisionGuidance.defaultProceed,
      metadata: {
        'evaluatedAt': startTime.toIso8601String(),
        'policiesEvaluated': evaluationPath.length,
        'evaluationPath': evaluationPath,
        'source': 'fallback',
      },
    );
  }

  /// Most restrictive: select the policy with the most restrictive action.
  /// Order: reject > escalate > hold > question > defer > proceedWithCaution > proceed
  DecisionPolicy _resolveMostRestrictive(List<DecisionPolicy> policies) {
    const actionOrder = [
      DecisionAction.reject,
      DecisionAction.escalate,
      DecisionAction.hold,
      DecisionAction.question,
      DecisionAction.defer,
      DecisionAction.proceedWithCaution,
      DecisionAction.proceed,
      DecisionAction.custom,
    ];

    return policies.reduce((a, b) {
      final aIndex = actionOrder.indexOf(a.guidance.action);
      final bIndex = actionOrder.indexOf(b.guidance.action);
      return aIndex <= bIndex ? a : b;
    });
  }

  /// Most specific: select the policy with the most specific condition.
  /// Specificity: composite > expression > threshold > always_true
  DecisionPolicy _resolveMostSpecific(List<DecisionPolicy> policies) {
    int specificity(PolicyCondition c) {
      return switch (c) {
        CompositeCondition() => 3,
        ExpressionCondition() => 2,
        ThresholdCondition() => 1,
        AlwaysTrueCondition() => 0,
      };
    }

    return policies.reduce((a, b) {
      final specA = specificity(a.condition);
      final specB = specificity(b.condition);
      if (specA != specB) return specA > specB ? a : b;
      // Equal specificity: higher priority wins
      return a.priority >= b.priority ? a : b;
    });
  }

  /// Merge: combine guidance from all matching policies.
  _MergedResult _resolveMerge(List<DecisionPolicy> policies) {
    // Use most restrictive action
    const actionOrder = [
      DecisionAction.reject,
      DecisionAction.escalate,
      DecisionAction.hold,
      DecisionAction.question,
      DecisionAction.defer,
      DecisionAction.proceedWithCaution,
      DecisionAction.proceed,
      DecisionAction.custom,
    ];

    var mostRestrictiveAction = DecisionAction.proceed;
    double? minConfidence;
    final allModifiers = <DecisionModifier>[];
    final explanations = <String>[];
    final policyIds = <String>[];

    for (final policy in policies) {
      policyIds.add(policy.id);

      final actionIndex = actionOrder.indexOf(policy.guidance.action);
      final currentIndex = actionOrder.indexOf(mostRestrictiveAction);
      if (actionIndex < currentIndex) {
        mostRestrictiveAction = policy.guidance.action;
      }

      if (policy.guidance.confidence != null) {
        minConfidence = minConfidence == null
            ? policy.guidance.confidence!
            : math.min(minConfidence, policy.guidance.confidence!);
      }

      allModifiers.addAll(policy.guidance.modifiers);

      if (policy.guidance.explanation != null) {
        explanations.add(policy.guidance.explanation!);
      }
    }

    // Deduplicate modifiers by type
    final uniqueModifiers = <ModifierType, DecisionModifier>{};
    for (final m in allModifiers) {
      uniqueModifiers.putIfAbsent(m.type, () => m);
    }

    return _MergedResult(
      policyIds: policyIds,
      guidance: DecisionGuidance(
        action: mostRestrictiveAction,
        confidence: minConfidence,
        explanation: explanations.isNotEmpty ? explanations.join('; ') : null,
        modifiers: uniqueModifiers.values.toList(),
      ),
    );
  }

  /// Evaluate a single policy condition.
  bool evaluateCondition({
    required PolicyCondition condition,
    required Map<String, double> metrics,
    required double aggregatedScore,
  }) {
    return condition.evaluate(metrics, aggregatedScore);
  }

  /// Find all matching policies (for debugging/analysis).
  List<DecisionPolicy> findAllMatching({
    required DecisionPolicySection policySection,
    required AppraisalResult appraisalResult,
  }) {
    final metricValues = <String, double>{};
    for (final entry in appraisalResult.metrics.entries) {
      metricValues[entry.key] = entry.value.normalizedValue;
    }
    final aggregatedScore = appraisalResult.aggregatedScore;

    return policySection.policies
        .where((p) => p.matches(metricValues, aggregatedScore))
        .toList();
  }

  /// Explain why a policy matched or didn't match.
  PolicyEvaluationExplanation explain({
    required DecisionPolicy policy,
    required AppraisalResult appraisalResult,
  }) {
    final metricValues = <String, double>{};
    for (final entry in appraisalResult.metrics.entries) {
      metricValues[entry.key] = entry.value.normalizedValue;
    }
    final aggregatedScore = appraisalResult.aggregatedScore;

    final matched = policy.matches(metricValues, aggregatedScore);
    final details = _explainCondition(policy.condition, metricValues, aggregatedScore);

    return PolicyEvaluationExplanation(
      policyId: policy.id,
      matched: matched,
      conditionDetails: details,
      metricValues: metricValues,
      aggregatedScore: aggregatedScore,
    );
  }

  /// Explain a condition evaluation.
  List<ConditionDetail> _explainCondition(
    PolicyCondition condition,
    Map<String, double> metrics,
    double aggregatedScore,
  ) {
    final details = <ConditionDetail>[];

    switch (condition) {
      case ThresholdCondition():
        final metricValue = condition.metric == 'aggregatedScore'
            ? aggregatedScore
            : metrics[condition.metric];
        details.add(ConditionDetail(
          type: 'threshold',
          description:
              '${condition.metric} ${condition.operator.toJsonString()} ${condition.value}',
          actualValue: metricValue,
          expectedValue: condition.value,
          matched: condition.evaluate(metrics, aggregatedScore),
        ));
      case ExpressionCondition():
        details.add(ConditionDetail(
          type: 'expression',
          description: condition.expression,
          matched: condition.evaluate(metrics, aggregatedScore),
        ));
      case CompositeCondition():
        if (condition.all != null) {
          for (final sub in condition.all!) {
            details.addAll(_explainCondition(sub, metrics, aggregatedScore));
          }
        }
        if (condition.any != null) {
          for (final sub in condition.any!) {
            details.addAll(_explainCondition(sub, metrics, aggregatedScore));
          }
        }
        if (condition.not != null) {
          details.addAll(_explainCondition(condition.not!, metrics, aggregatedScore));
        }
      case AlwaysTrueCondition():
        details.add(ConditionDetail(
          type: 'always_true',
          description: 'Always matches (default fallback)',
          matched: true,
        ));
    }

    return details;
  }
}

// =============================================================================
// Internal Types
// =============================================================================

/// Internal result type for merged policy resolution.
class _MergedResult {
  /// IDs of all merged policies.
  final List<String> policyIds;

  /// Combined guidance from all merged policies.
  final DecisionGuidance guidance;

  const _MergedResult({
    required this.policyIds,
    required this.guidance,
  });
}

// =============================================================================
// Explanation Types
// =============================================================================

/// Explanation of a policy evaluation.
class PolicyEvaluationExplanation {
  /// Policy ID.
  final String policyId;

  /// Whether the policy matched.
  final bool matched;

  /// Condition details.
  final List<ConditionDetail> conditionDetails;

  /// Metric values used.
  final Map<String, double> metricValues;

  /// Aggregated score used.
  final double aggregatedScore;

  const PolicyEvaluationExplanation({
    required this.policyId,
    required this.matched,
    required this.conditionDetails,
    required this.metricValues,
    required this.aggregatedScore,
  });
}

/// Detail about a single condition.
class ConditionDetail {
  /// Condition type.
  final String type;

  /// Human-readable description.
  final String description;

  /// Actual metric value (if applicable).
  final double? actualValue;

  /// Expected/threshold value (if applicable).
  final Object? expectedValue;

  /// Whether this condition matched.
  final bool matched;

  const ConditionDetail({
    required this.type,
    required this.description,
    this.actualValue,
    this.expectedValue,
    required this.matched,
  });
}
