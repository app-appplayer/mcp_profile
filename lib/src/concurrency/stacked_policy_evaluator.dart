/// Stacked Policy Evaluator - Multi-profile evaluation per design/06-concurrency.md §5.
///
/// Evaluates policies across multiple stacked profiles concurrently,
/// adjusting priorities based on profile priority.
library;

import '../appraisal/appraisal_result.dart';
import '../bundle/profile_bundle_spec.dart';
import '../decision/decision_policy.dart';
import '../expression/expression_policy.dart';
import '../runtime/runtime_context.dart';
import 'parallel_policy_evaluator.dart';

// =============================================================================
// StackedEvaluationResult (§5)
// =============================================================================

/// Result of evaluating policies across multiple stacked profiles.
class StackedEvaluationResult<P> {
  /// All matched policies across all profiles.
  final List<PolicyMatch<P>> allMatches;

  /// Matches grouped by source profile ID.
  final Map<String, List<PolicyMatch<P>>> matchesByProfile;

  /// The resolved policy after cross-profile conflict resolution.
  final PolicyMatch<P>? resolvedPolicy;

  /// Whether conflict resolution was applied.
  final bool conflictResolutionApplied;

  /// Number of profiles evaluated.
  final int profilesEvaluated;

  /// Total policies evaluated across all profiles.
  final int policiesEvaluated;

  const StackedEvaluationResult({
    required this.allMatches,
    required this.matchesByProfile,
    this.resolvedPolicy,
    required this.conflictResolutionApplied,
    required this.profilesEvaluated,
    required this.policiesEvaluated,
  });
}

// =============================================================================
// StackedPolicyEvaluator (§5)
// =============================================================================

/// Evaluates policies across multiple stacked profiles concurrently per §5.
class StackedPolicyEvaluator {
  final ParallelPolicyEvaluator policyEvaluator;
  final ConcurrentEvaluationConfig config;

  const StackedPolicyEvaluator(this.policyEvaluator, this.config);

  /// Evaluate decision policies across stacked profiles per §5.
  Future<StackedEvaluationResult<DecisionPolicy>> evaluateDecisionPolicies(
    List<SpecProfileBundle> profiles,
    AppraisalResult appraisal,
    ProfileContext context,
  ) async {
    // Collect all policies from all profiles with adjusted priorities
    final allPolicies = <DecisionPolicy>[];
    final policyProfileMap = <String, String>{};

    for (final profile in profiles) {
      if (profile.decisionPolicies == null) continue;

      for (final policy in profile.decisionPolicies!.policies) {
        final profilePriority = profile.manifest.priority;
        final prefixedId = '${profile.manifest.id}:${policy.id}';
        final adjustedPolicy = policy.copyWith(
          id: prefixedId,
          priority: policy.priority + profilePriority * 10,
        );

        allPolicies.add(adjustedPolicy);
        policyProfileMap[prefixedId] = profile.manifest.id;
      }
    }

    // Evaluate all policies concurrently using generic evaluate<P>()
    final result = await policyEvaluator.evaluate<DecisionPolicy>(
      allPolicies,
      appraisal,
      context,
    );

    // Group matches by source profile
    final matchesByProfile = _groupByProfile(
      result.matchingPolicies,
      policyProfileMap,
    );

    return StackedEvaluationResult(
      allMatches: result.matchingPolicies,
      matchesByProfile: matchesByProfile,
      resolvedPolicy: result.resolvedPolicy,
      conflictResolutionApplied: result.matchingPolicies.length > 1,
      profilesEvaluated: profiles.length,
      policiesEvaluated: allPolicies.length,
    );
  }

  /// Evaluate expression policies across stacked profiles with style merging per §5.
  Future<StackedEvaluationResult<ExpressionPolicy>>
      evaluateExpressionPolicies(
    List<SpecProfileBundle> profiles,
    AppraisalResult appraisal,
    ProfileContext context,
  ) async {
    final allPolicies = <ExpressionPolicy>[];
    final policyProfileMap = <String, String>{};

    for (final profile in profiles) {
      if (profile.expressionPolicies == null) continue;

      for (final policy in profile.expressionPolicies!.policies) {
        final profilePriority = profile.manifest.priority;
        final prefixedId = '${profile.manifest.id}:${policy.id}';

        final adjustedPolicy = ExpressionPolicy(
          id: prefixedId,
          name: policy.name,
          condition: policy.condition,
          style: policy.style,
          description: policy.description,
          priority: policy.priority + profilePriority * 10,
          enabled: policy.enabled,
          tags: policy.tags,
        );

        allPolicies.add(adjustedPolicy);
        policyProfileMap[prefixedId] = profile.manifest.id;
      }
    }

    // Evaluate concurrently using generic evaluate<P>()
    final result = await policyEvaluator.evaluate<ExpressionPolicy>(
      allPolicies,
      appraisal,
      context,
    );

    // Group matches by source profile
    final matchesByProfile = _groupByProfile(
      result.matchingPolicies,
      policyProfileMap,
    );

    return StackedEvaluationResult(
      allMatches: result.matchingPolicies,
      matchesByProfile: matchesByProfile,
      resolvedPolicy: result.resolvedPolicy,
      conflictResolutionApplied: result.matchingPolicies.length > 1,
      profilesEvaluated: profiles.length,
      policiesEvaluated: allPolicies.length,
    );
  }

  /// Group matches by source profile ID.
  Map<String, List<PolicyMatch<P>>> _groupByProfile<P>(
    List<PolicyMatch<P>> matches,
    Map<String, String> policyProfileMap,
  ) {
    final result = <String, List<PolicyMatch<P>>>{};
    for (final match in matches) {
      final policyId = (match.policy as dynamic).id as String;
      final profileId =
          policyProfileMap[policyId] ?? policyId.split(':').first;
      result.putIfAbsent(profileId, () => []);
      result[profileId]!.add(match);
    }
    return result;
  }
}
