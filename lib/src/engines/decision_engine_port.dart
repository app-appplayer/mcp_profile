/// Decision Engine Port - Internal engine contract for policy evaluation.
///
/// See docs/03_DDD/core-engines.md §4.
library;

import '../appraisal/appraisal_result.dart';
import '../decision/decision_guidance.dart';
import '../decision/decision_policy.dart';
import '../decision/policy_condition.dart';
import '../runtime/runtime_context.dart';

/// Engine contract for decision policy evaluation.
abstract class DecisionEnginePort {
  /// Evaluate policies and return guidance.
  Future<DecisionGuidance> evaluate(
    List<DecisionPolicy> policies,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  );

  /// Check if a specific condition matches.
  Future<bool> evaluateCondition(
    PolicyCondition condition,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  );

  /// Get all matching policies (for debugging/logging).
  Future<List<DecisionPolicy>> getMatchingPolicies(
    List<DecisionPolicy> policies,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  );
}

/// Default sequential evaluator backed by condition matching.
class DefaultDecisionEnginePort implements DecisionEnginePort {
  const DefaultDecisionEnginePort();

  @override
  Future<DecisionGuidance> evaluate(
    List<DecisionPolicy> policies,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  ) async {
    final sorted = [...policies]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    for (final policy in sorted) {
      if (!policy.enabled) continue;
      final matches =
          await evaluateCondition(policy.condition, appraisal, context);
      if (matches) {
        return policy.guidance;
      }
    }
    return DecisionGuidance.defaultProceed;
  }

  @override
  Future<bool> evaluateCondition(
    PolicyCondition condition,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  ) async {
    final metrics = <String, double>{};
    for (final entry in appraisal.metrics.entries) {
      metrics[entry.key] = entry.value.normalizedValue;
    }
    return condition.evaluate(metrics, appraisal.aggregatedScore);
  }

  @override
  Future<List<DecisionPolicy>> getMatchingPolicies(
    List<DecisionPolicy> policies,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  ) async {
    final matching = <DecisionPolicy>[];
    for (final policy in policies) {
      if (!policy.enabled) continue;
      final matches =
          await evaluateCondition(policy.condition, appraisal, context);
      if (matches) matching.add(policy);
    }
    return matching;
  }
}

/// Stub engine port that always returns defaultProceed.
class StubDecisionEnginePort implements DecisionEnginePort {
  const StubDecisionEnginePort();

  @override
  Future<DecisionGuidance> evaluate(
    List<DecisionPolicy> policies,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  ) async {
    return DecisionGuidance.defaultProceed;
  }

  @override
  Future<bool> evaluateCondition(
    PolicyCondition condition,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  ) async {
    return false;
  }

  @override
  Future<List<DecisionPolicy>> getMatchingPolicies(
    List<DecisionPolicy> policies,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  ) async {
    return [];
  }
}
