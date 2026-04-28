/// Parallel Policy Evaluator - Concurrent policy evaluation per design/06-concurrency.md §3.
///
/// Evaluates multiple policies concurrently with configurable batching,
/// short-circuit optimization, and conflict resolution.
library;

import '../appraisal/appraisal_result.dart';
import '../decision/decision_guidance.dart';
import '../decision/decision_policy.dart';
import '../decision/policy_condition.dart';
import '../expression/expression_policy.dart';
import '../expression/expression_style.dart';
import '../runtime/runtime_context.dart';

// =============================================================================
// ConcurrentEvaluationConfig (§2)
// =============================================================================

/// Configuration for concurrent policy evaluation.
class ConcurrentEvaluationConfig {
  /// Enable parallel policy evaluation.
  final bool parallelEvaluation;

  /// Maximum number of policies evaluated concurrently.
  final int maxParallelism;

  /// Timeout for individual policy evaluation.
  final Duration policyEvaluationTimeout;

  /// Strategy when multiple policies match.
  final ConflictResolution conflictResolution;

  /// Whether to continue evaluating after finding a match.
  final bool evaluateAll;

  /// Whether to fail on any policy evaluation error.
  final bool failOnError;

  /// Short-circuit optimization configuration.
  final ShortCircuitConfig shortCircuit;

  const ConcurrentEvaluationConfig({
    this.parallelEvaluation = true,
    this.maxParallelism = 4,
    this.policyEvaluationTimeout = const Duration(milliseconds: 1000),
    this.conflictResolution = ConflictResolution.highestPriority,
    this.evaluateAll = false,
    this.failOnError = false,
    this.shortCircuit = const ShortCircuitConfig(),
  });
}

/// Short-circuit optimization configuration.
class ShortCircuitConfig {
  /// Whether short-circuit is enabled.
  final bool enabled;

  /// Priority threshold for short-circuit.
  final int priorityThreshold;

  const ShortCircuitConfig({
    this.enabled = true,
    this.priorityThreshold = 80,
  });
}

// =============================================================================
// PolicyConditionEvaluator (§3)
// =============================================================================

/// Interface for evaluating policy conditions per §3.
///
/// Injected into [ParallelPolicyEvaluator] to decouple condition evaluation
/// from the evaluator itself.
abstract class PolicyConditionEvaluator {
  /// Evaluate a policy condition against appraisal results.
  Future<bool> evaluate(
    PolicyCondition condition,
    AppraisalResult appraisal,
    ProfileContext context,
  );
}

/// Default condition evaluator using PolicyCondition's built-in evaluate method.
class DefaultPolicyConditionEvaluator implements PolicyConditionEvaluator {
  const DefaultPolicyConditionEvaluator();

  @override
  Future<bool> evaluate(
    PolicyCondition condition,
    AppraisalResult appraisal,
    ProfileContext context,
  ) async {
    final metrics = <String, double>{};
    for (final entry in appraisal.metrics.entries) {
      metrics[entry.key] = entry.value.normalizedValue;
    }
    return condition.evaluate(metrics, appraisal.aggregatedScore);
  }
}

// =============================================================================
// PolicyMatch (§3)
// =============================================================================

/// A matching policy with evaluation metadata.
class PolicyMatch<P> {
  /// The matched policy.
  final P policy;

  /// ToneConfidenceof the match.
  final double confidence;

  /// Time taken to evaluate this policy.
  final Duration evaluationTime;

  const PolicyMatch({
    required this.policy,
    required this.confidence,
    required this.evaluationTime,
  });
}

// =============================================================================
// PolicyEvaluationResult (§3)
// =============================================================================

/// Result of parallel policy evaluation.
class PolicyEvaluationResult<P> {
  /// All policies that matched.
  final List<PolicyMatch<P>> matchingPolicies;

  /// The resolved policy after conflict resolution.
  final PolicyMatch<P>? resolvedPolicy;

  /// Errors during evaluation.
  final List<PolicyEvaluationError> evaluationErrors;

  /// Whether evaluation was short-circuited.
  final bool shortCircuited;

  /// Total number of policies evaluated.
  final int totalPoliciesEvaluated;

  /// Evaluation metadata.
  final PolicyEvaluationMetadata metadata;

  const PolicyEvaluationResult({
    required this.matchingPolicies,
    this.resolvedPolicy,
    this.evaluationErrors = const [],
    this.shortCircuited = false,
    required this.totalPoliciesEvaluated,
    required this.metadata,
  });
}

/// Error during policy evaluation.
class PolicyEvaluationError {
  /// Policy ID that caused the error.
  final String policyId;

  /// Error details.
  final Object? error;

  const PolicyEvaluationError({
    required this.policyId,
    this.error,
  });
}

/// Metadata about the evaluation process.
class PolicyEvaluationMetadata {
  /// Conflict resolution strategy used.
  final ConflictResolution strategy;

  /// Parallelism level used.
  final int parallelism;

  const PolicyEvaluationMetadata({
    required this.strategy,
    required this.parallelism,
  });
}

// =============================================================================
// ConditionEvaluationResult (§3)
// =============================================================================

/// Result of evaluating a single policy condition.
class ConditionEvaluationResult {
  /// Whether the condition matched.
  final bool matches;

  /// ToneConfidenceof the evaluation.
  final double confidence;

  /// Time taken to evaluate.
  final Duration evaluationTime;

  /// Whether an error occurred.
  final bool isError;

  /// Error details if isError.
  final Object? error;

  const ConditionEvaluationResult({
    required this.matches,
    this.confidence = 1.0,
    this.evaluationTime = Duration.zero,
    this.isError = false,
    this.error,
  });

  /// Create an error result per §3.
  factory ConditionEvaluationResult.error(Object error) {
    return ConditionEvaluationResult(
      matches: false,
      isError: true,
      error: error,
    );
  }
}

// =============================================================================
// PolicyEvaluationException
// =============================================================================

/// Exception thrown when policy evaluation fails with failOnError.
class PolicyEvaluationException implements Exception {
  /// Accumulated errors.
  final List<PolicyEvaluationError> errors;

  const PolicyEvaluationException(this.errors);

  @override
  String toString() =>
      'PolicyEvaluationException: ${errors.length} evaluation errors';
}

// =============================================================================
// ParallelPolicyEvaluator (§3)
// =============================================================================

/// Evaluates policies concurrently with configurable batching and
/// conflict resolution per design/06-concurrency.md §3.
class ParallelPolicyEvaluator {
  final ConcurrentEvaluationConfig config;
  final PolicyConditionEvaluator conditionEvaluator;

  const ParallelPolicyEvaluator(this.config, this.conditionEvaluator);

  /// Evaluate all policies concurrently and resolve conflicts per §3.
  ///
  /// Generic over [P extends Policy] to support both DecisionPolicy
  /// and ExpressionPolicy.
  Future<PolicyEvaluationResult<P>> evaluate<P extends Policy>(
    List<P> policies,
    AppraisalResult appraisal,
    ProfileContext context,
  ) async {
    // Sort by priority for short-circuit optimization
    final sortedPolicies = [...policies]
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final matchingPolicies = <PolicyMatch<P>>[];
    final evaluationErrors = <PolicyEvaluationError>[];
    var shortCircuited = false;

    // Evaluate in batches based on maxParallelism
    for (var i = 0;
        i < sortedPolicies.length && !shortCircuited;
        i += config.maxParallelism) {
      final batch =
          sortedPolicies.skip(i).take(config.maxParallelism).toList();

      // Evaluate batch in parallel
      final batchResults = await Future.wait(
        batch.map((policy) => _evaluatePolicy(policy, appraisal, context)),
        eagerError: false,
      );

      // Process batch results
      for (var j = 0; j < batch.length; j++) {
        final policy = batch[j];
        final result = batchResults[j];

        if (result.isError) {
          evaluationErrors.add(PolicyEvaluationError(
            policyId: policy.id,
            error: result.error,
          ));
          if (config.failOnError) {
            throw PolicyEvaluationException(evaluationErrors);
          }
          continue;
        }

        if (result.matches) {
          matchingPolicies.add(PolicyMatch(
            policy: policy,
            confidence: result.confidence,
            evaluationTime: result.evaluationTime,
          ));

          // Check for short-circuit
          if (config.shortCircuit.enabled &&
              policy.priority >= config.shortCircuit.priorityThreshold) {
            shortCircuited = true;
            break;
          }

          // If not evaluating all, stop after first match
          if (!config.evaluateAll) {
            shortCircuited = true;
            break;
          }
        }
      }
    }

    // Resolve conflicts if multiple policies match
    final resolvedPolicy = await _resolveConflicts(
      matchingPolicies,
      config.conflictResolution,
    );

    return PolicyEvaluationResult(
      matchingPolicies: matchingPolicies,
      resolvedPolicy: resolvedPolicy,
      evaluationErrors: evaluationErrors,
      shortCircuited: shortCircuited,
      totalPoliciesEvaluated: policies.length,
      metadata: PolicyEvaluationMetadata(
        strategy: config.conflictResolution,
        parallelism: config.maxParallelism,
      ),
    );
  }

  /// Evaluate a single policy condition per §3.
  Future<ConditionEvaluationResult> _evaluatePolicy<P extends Policy>(
    P policy,
    AppraisalResult appraisal,
    ProfileContext context,
  ) async {
    final startTime = DateTime.now();

    try {
      // Apply timeout to evaluation
      final matches = await conditionEvaluator
          .evaluate(policy.condition, appraisal, context)
          .timeout(config.policyEvaluationTimeout);

      return ConditionEvaluationResult(
        matches: matches,
        confidence: _calculateConfidence(appraisal),
        evaluationTime: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return ConditionEvaluationResult.error(e);
    }
  }

  /// Calculate confidence from appraisal metrics.
  double _calculateConfidence(AppraisalResult appraisal) {
    if (appraisal.metrics.isEmpty) return 0.5;
    return appraisal.metrics.values
            .map((m) => m.confidence)
            .reduce((a, b) => a + b) /
        appraisal.metrics.length;
  }

  // ---------------------------------------------------------------------------
  // Conflict Resolution (§4)
  // ---------------------------------------------------------------------------

  /// Resolve conflicts between multiple matching policies per §4.
  Future<PolicyMatch<P>?> _resolveConflicts<P extends Policy>(
    List<PolicyMatch<P>> matches,
    ConflictResolution strategy,
  ) async {
    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;

    return switch (strategy) {
      ConflictResolution.firstMatch => matches.first,
      ConflictResolution.lastMatch => matches.last,
      ConflictResolution.highestPriority =>
        matches.first, // Already sorted by priority
      ConflictResolution.mostRestrictive =>
        _resolveMostRestrictive(matches),
      ConflictResolution.mostSpecific =>
        matches.last, // Most specific = most specific scope
      ConflictResolution.unanimous => _resolveUnanimous(matches),
      ConflictResolution.majority => _resolveMajority(matches),
      ConflictResolution.merge => _mergePolicies(matches),
      ConflictResolution.custom =>
        matches.first, // Custom requires app-level implementation
    };
  }

  /// Most restrictive resolution for decision policies per §4.
  PolicyMatch<P> _resolveMostRestrictive<P extends Policy>(
    List<PolicyMatch<P>> matches,
  ) {
    if (P == DecisionPolicy) {
      return _resolveMostRestrictiveDecision(
        matches as List<PolicyMatch<DecisionPolicy>>,
      ) as PolicyMatch<P>;
    }
    // For non-decision policies, fall back to highest priority
    return matches.first;
  }

  PolicyMatch<DecisionPolicy> _resolveMostRestrictiveDecision(
    List<PolicyMatch<DecisionPolicy>> matches,
  ) {
    const actionOrder = [
      DecisionAction.reject,
      DecisionAction.escalate,
      DecisionAction.hold,
      DecisionAction.question,
      DecisionAction.defer,
      DecisionAction.custom,
      DecisionAction.proceedWithCaution,
      DecisionAction.proceed,
    ];

    return matches.reduce((mostRestrictive, current) {
      final currentIndex =
          actionOrder.indexOf(current.policy.guidance.action);
      final restrictiveIndex =
          actionOrder.indexOf(mostRestrictive.policy.guidance.action);
      return currentIndex < restrictiveIndex ? current : mostRestrictive;
    });
  }

  /// Unanimous resolution: all must agree per §4.
  PolicyMatch<P> _resolveUnanimous<P extends Policy>(
    List<PolicyMatch<P>> matches,
  ) {
    if (P == DecisionPolicy) {
      final decisionMatches = matches as List<PolicyMatch<DecisionPolicy>>;
      final firstAction = decisionMatches.first.policy.guidance.action;
      final unanimous = decisionMatches
          .every((m) => m.policy.guidance.action == firstAction);
      if (unanimous) return matches.first;
      return _resolveMostRestrictive(matches);
    }
    return matches.first;
  }

  /// Majority resolution: most common action wins per §4.
  PolicyMatch<P> _resolveMajority<P extends Policy>(
    List<PolicyMatch<P>> matches,
  ) {
    if (P == DecisionPolicy) {
      final decisionMatches = matches as List<PolicyMatch<DecisionPolicy>>;
      final actionCounts = <DecisionAction, int>{};
      for (final match in decisionMatches) {
        final action = match.policy.guidance.action;
        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
      }
      final majorityAction = actionCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      return decisionMatches.firstWhere(
        (m) => m.policy.guidance.action == majorityAction,
      ) as PolicyMatch<P>;
    }
    return matches.first;
  }

  /// Merge multiple matching policies per §4.
  PolicyMatch<P> _mergePolicies<P extends Policy>(
    List<PolicyMatch<P>> matches,
  ) {
    if (P == DecisionPolicy) {
      return _mergeDecisionPolicies(
        matches as List<PolicyMatch<DecisionPolicy>>,
      ) as PolicyMatch<P>;
    }
    // ExpressionPolicy merge (only DecisionPolicy and ExpressionPolicy
    // reach this point via evaluateDecisionPolicies/evaluateExpressionPolicies)
    return _mergeExpressionPolicies(
      matches as List<PolicyMatch<ExpressionPolicy>>,
    ) as PolicyMatch<P>;
  }

  /// Merge decision policies per §4.
  PolicyMatch<DecisionPolicy> _mergeDecisionPolicies(
    List<PolicyMatch<DecisionPolicy>> matches,
  ) {
    // Use most restrictive action
    final mostRestrictive = _resolveMostRestrictiveDecision(matches);
    final action = mostRestrictive.policy.guidance.action;

    // Combine all modifiers
    final modifiers = matches
        .expand((m) => m.policy.guidance.modifiers)
        .toList();

    final mergedPolicy = DecisionPolicy(
      id: 'merged:${matches.map((m) => m.policy.id).join('+')}',
      name: 'Merged Decision Policy',
      condition: matches.first.policy.condition,
      guidance: DecisionGuidance(
        action: action,
        explanation: 'Merged from ${matches.length} matching policies',
        modifiers: modifiers,
      ),
      priority: matches
          .map((m) => m.policy.priority)
          .reduce((a, b) => a > b ? a : b),
    );

    final avgConfidence =
        matches.map((m) => m.confidence).reduce((a, b) => a + b) /
            matches.length;
    final totalTime = matches
        .map((m) => m.evaluationTime)
        .reduce((a, b) => a + b);

    return PolicyMatch(
      policy: mergedPolicy,
      confidence: avgConfidence,
      evaluationTime: totalTime,
    );
  }

  /// Merge expression policies per §4.
  PolicyMatch<ExpressionPolicy> _mergeExpressionPolicies(
    List<PolicyMatch<ExpressionPolicy>> matches,
  ) {
    // Use highest-priority style as base
    final baseStyle = matches.first.policy.style;

    // Merge tone: use most formal/cautious per design doc
    final mergedTone = ToneConfig(
      formality:
          _mostFormal(matches.map((m) => m.policy.style.tone.formality)),
      confidence: _leastConfident(
          matches.map((m) => m.policy.style.tone.confidence)),
      empathy:
          _highestEmpathy(matches.map((m) => m.policy.style.tone.empathy)),
      directness: _averageDirectness(
          matches.map((m) => m.policy.style.tone.directness)),
    );

    // Merge format: any requiring caveats/evidence wins, shortest length
    final mergedFormat = FormatConfig(
      structure: baseStyle.format.structure,
      length:
          _shortestLength(matches.map((m) => m.policy.style.format.length)),
      includeEvidence:
          matches.any((m) => m.policy.style.format.includeEvidence),
      includeCaveats:
          matches.any((m) => m.policy.style.format.includeCaveats),
      includeAlternatives:
          matches.any((m) => m.policy.style.format.includeAlternatives),
    );

    // Merge hedging: use highest level, merge phrase maps
    final mergedPhrases = <String, List<String>>{};
    for (final m in matches) {
      final phrases = m.policy.style.hedging?.phrases;
      if (phrases != null) {
        _mergePhraseMap(
            mergedPhrases, phrases.highUncertainty, 'high_uncertainty');
        _mergePhraseMap(mergedPhrases, phrases.moderateUncertainty,
            'moderate_uncertainty');
        _mergePhraseMap(
            mergedPhrases, phrases.lowUncertainty, 'low_uncertainty');
        _mergePhraseMap(mergedPhrases, phrases.qualifying, 'qualifying');
        _mergePhraseMap(
            mergedPhrases, phrases.probabilistic, 'probabilistic');
      }
    }

    final mergedHedging = HedgingConfig(
      level: _highestHedgingLevel(
          matches.map((m) => m.policy.style.hedging?.level)),
      phrases: mergedPhrases.isNotEmpty
          ? HedgingPhrases(
              highUncertainty: mergedPhrases['high_uncertainty'],
              moderateUncertainty: mergedPhrases['moderate_uncertainty'],
              lowUncertainty: mergedPhrases['low_uncertainty'],
              qualifying: mergedPhrases['qualifying'],
              probabilistic: mergedPhrases['probabilistic'],
            )
          : null,
    );

    final mergedPolicy = ExpressionPolicy(
      id: 'merged:${matches.map((m) => m.policy.id).join('+')}',
      name: 'Merged Expression Policy',
      condition: matches.first.policy.condition,
      style: ExpressionStyle(
        tone: mergedTone,
        format: mergedFormat,
        hedging: mergedHedging,
      ),
      priority: matches
          .map((m) => m.policy.priority)
          .reduce((a, b) => a > b ? a : b),
    );

    final avgConfidence =
        matches.map((m) => m.confidence).reduce((a, b) => a + b) /
            matches.length;
    final totalTime = matches
        .map((m) => m.evaluationTime)
        .reduce((a, b) => a + b);

    return PolicyMatch(
      policy: mergedPolicy,
      confidence: avgConfidence,
      evaluationTime: totalTime,
    );
  }

  // ---------------------------------------------------------------------------
  // Merge Helpers
  // ---------------------------------------------------------------------------

  Formality _mostFormal(Iterable<Formality> values) {
    if (values.any((v) => v == Formality.formal)) return Formality.formal;
    if (values.any((v) => v == Formality.neutral)) return Formality.neutral;
    return Formality.casual;
  }

  ToneConfidence _leastConfident(Iterable<ToneConfidence> values) {
    if (values.any((v) => v == ToneConfidence.tentative)) {
      return ToneConfidence.tentative;
    }
    if (values.any((v) => v == ToneConfidence.moderate)) {
      return ToneConfidence.moderate;
    }
    return ToneConfidence.assertive;
  }

  Empathy _highestEmpathy(Iterable<Empathy> values) {
    if (values.any((v) => v == Empathy.high)) return Empathy.high;
    if (values.any((v) => v == Empathy.moderate)) return Empathy.moderate;
    return Empathy.low;
  }

  Directness _averageDirectness(Iterable<Directness> values) {
    if (values.isEmpty) return Directness.balanced;
    final ordinals = values.map((v) => v.index);
    final avg = ordinals.reduce((a, b) => a + b) / values.length;
    final rounded = avg.round();
    return Directness.values[rounded.clamp(0, Directness.values.length - 1)];
  }

  Length _shortestLength(Iterable<Length> values) {
    if (values.any((v) => v == Length.concise)) return Length.concise;
    if (values.any((v) => v == Length.standard)) return Length.standard;
    return Length.detailed;
  }

  HedgingLevel _highestHedgingLevel(Iterable<HedgingLevel?> values) {
    final nonNull = values.whereType<HedgingLevel>();
    if (nonNull.any((v) => v == HedgingLevel.strong)) {
      return HedgingLevel.strong;
    }
    if (nonNull.any((v) => v == HedgingLevel.moderate)) {
      return HedgingLevel.moderate;
    }
    if (nonNull.any((v) => v == HedgingLevel.light)) {
      return HedgingLevel.light;
    }
    return HedgingLevel.none;
  }

  void _mergePhraseMap(
    Map<String, List<String>> target,
    List<String>? phrases,
    String category,
  ) {
    if (phrases == null) return;
    target.putIfAbsent(category, () => []);
    for (final phrase in phrases) {
      if (!target[category]!.contains(phrase)) {
        target[category]!.add(phrase);
      }
    }
  }
}
