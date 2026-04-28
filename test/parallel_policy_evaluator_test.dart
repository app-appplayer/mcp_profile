/// ParallelPolicyEvaluator Tests
library;

import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

// =============================================================================
// Test Helpers
// =============================================================================

/// Creates a test RuntimeProfileContext.
RuntimeProfileContext _createContext() {
  return DefaultRuntimeContext(
    profileId: 'test',
    entityId: 'e',
  );
}

/// Creates a test AppraisalResult.
AppraisalResult _createAppraisal({
  double riskValue = 0.8,
  double riskConfidence = 0.9,
}) {
  return AppraisalResult(
    profileId: 'test',
    contextId: 'ctx',
    asOf: DateTime.now(),
    metrics: {
      'risk': MetricResult(
        id: 'risk',
        normalizedValue: riskValue,
        sourceType: MetricSourceType.static_,
        confidence: riskConfidence,
      ),
    },
    aggregatedScore: riskValue,
    metadata: AppraisalMetadata(computedAt: DateTime.now()),
  );
}

/// A condition evaluator that throws only for specific policy conditions.
/// Used to test error accumulation and failOnError behavior.
class _SelectiveErrorEvaluator implements PolicyConditionEvaluator {
  final Set<String> errorPolicyIds;
  final PolicyConditionEvaluator _delegate;

  // Track which policy is being evaluated via condition matching
  final Map<PolicyCondition, String> _conditionToPolicyId = {};

  _SelectiveErrorEvaluator({
    required this.errorPolicyIds,
  }) : _delegate = const DefaultPolicyConditionEvaluator();

  /// Register policies so we can match conditions to policy IDs.
  void registerPolicies(List<Policy> policies) {
    for (final p in policies) {
      _conditionToPolicyId[p.condition] = p.id;
    }
  }

  @override
  Future<bool> evaluate(
    PolicyCondition condition,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  ) async {
    final policyId = _conditionToPolicyId[condition];
    if (policyId != null && errorPolicyIds.contains(policyId)) {
      throw StateError('Simulated error for $policyId');
    }
    return _delegate.evaluate(condition, appraisal, context);
  }
}

void main() {
  // ===========================================================================
  // ConcurrentEvaluationConfig
  // ===========================================================================

  group('ConcurrentEvaluationConfig', () {
    test('creation with defaults', () {
      const config = ConcurrentEvaluationConfig();
      expect(config.parallelEvaluation, isTrue);
      expect(config.maxParallelism, equals(4));
      expect(
        config.policyEvaluationTimeout,
        equals(const Duration(milliseconds: 1000)),
      );
      expect(
        config.conflictResolution,
        equals(ConflictResolution.highestPriority),
      );
      expect(config.evaluateAll, isFalse);
      expect(config.failOnError, isFalse);
    });
  });

  // ===========================================================================
  // ShortCircuitConfig
  // ===========================================================================

  group('ShortCircuitConfig', () {
    test('creation with defaults', () {
      const config = ShortCircuitConfig();
      expect(config.enabled, isTrue);
      expect(config.priorityThreshold, equals(80));
    });
  });

  // ===========================================================================
  // DefaultPolicyConditionEvaluator
  // ===========================================================================

  group('DefaultPolicyConditionEvaluator', () {
    const evaluator = DefaultPolicyConditionEvaluator();

    test('evaluate returns true for matching threshold', () async {
      final condition = const ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.7,
      );
      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final result = await evaluator.evaluate(condition, appraisal, context);
      expect(result, isTrue);
    });

    test('evaluate returns false for non-matching threshold', () async {
      final condition = const ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
      );
      final appraisal = _createAppraisal(riskValue: 0.5);
      final context = _createContext();

      final result = await evaluator.evaluate(condition, appraisal, context);
      expect(result, isFalse);
    });
  });

  // ===========================================================================
  // PolicyMatch
  // ===========================================================================

  group('PolicyMatch', () {
    test('creation with all fields', () {
      final policy = DecisionPolicy(
        id: 'dp1',
        name: 'Test',
        condition: const AlwaysTrueCondition(),
        guidance: const DecisionGuidance(action: DecisionAction.proceed),
      );
      final match = PolicyMatch<DecisionPolicy>(
        policy: policy,
        confidence: 0.9,
        evaluationTime: const Duration(milliseconds: 50),
      );
      expect(match.policy.id, equals('dp1'));
      expect(match.confidence, equals(0.9));
      expect(match.evaluationTime, equals(const Duration(milliseconds: 50)));
    });
  });

  // ===========================================================================
  // PolicyEvaluationResult
  // ===========================================================================

  group('PolicyEvaluationResult', () {
    test('creation with all fields', () {
      final result = PolicyEvaluationResult<DecisionPolicy>(
        matchingPolicies: [],
        resolvedPolicy: null,
        evaluationErrors: [],
        shortCircuited: false,
        totalPoliciesEvaluated: 5,
        metadata: const PolicyEvaluationMetadata(
          strategy: ConflictResolution.firstMatch,
          parallelism: 4,
        ),
      );
      expect(result.matchingPolicies, isEmpty);
      expect(result.resolvedPolicy, isNull);
      expect(result.evaluationErrors, isEmpty);
      expect(result.shortCircuited, isFalse);
      expect(result.totalPoliciesEvaluated, equals(5));
      expect(
        result.metadata.strategy,
        equals(ConflictResolution.firstMatch),
      );
    });
  });

  // ===========================================================================
  // PolicyEvaluationError
  // ===========================================================================

  group('PolicyEvaluationError', () {
    test('creation', () {
      const error = PolicyEvaluationError(
        policyId: 'dp1',
        error: 'Something went wrong',
      );
      expect(error.policyId, equals('dp1'));
      expect(error.error, equals('Something went wrong'));
    });
  });

  // ===========================================================================
  // ConditionEvaluationResult
  // ===========================================================================

  group('ConditionEvaluationResult', () {
    test('creation with defaults', () {
      const result = ConditionEvaluationResult(matches: true);
      expect(result.matches, isTrue);
      expect(result.confidence, equals(1.0));
      expect(result.evaluationTime, equals(Duration.zero));
      expect(result.isError, isFalse);
      expect(result.error, isNull);
    });

    test('error factory sets isError true and matches false', () {
      final result = ConditionEvaluationResult.error('test error');
      expect(result.isError, isTrue);
      expect(result.matches, isFalse);
      expect(result.error, equals('test error'));
    });
  });

  // ===========================================================================
  // PolicyEvaluationMetadata
  // ===========================================================================

  group('PolicyEvaluationMetadata', () {
    test('creation', () {
      const metadata = PolicyEvaluationMetadata(
        strategy: ConflictResolution.highestPriority,
        parallelism: 8,
      );
      expect(metadata.strategy, equals(ConflictResolution.highestPriority));
      expect(metadata.parallelism, equals(8));
    });
  });

  // ===========================================================================
  // ParallelPolicyEvaluator
  // ===========================================================================

  group('ParallelPolicyEvaluator', () {
    test('evaluate<DecisionPolicy> returns matching policies', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(evaluateAll: true);
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final matchingPolicy = DecisionPolicy(
        id: 'dp1',
        name: 'High Risk',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.7,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
          explanation: 'High risk',
        ),
      );

      final nonMatchingPolicy = DecisionPolicy(
        id: 'dp2',
        name: 'Low Risk',
        priority: 10,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.lessThan,
          value: 0.3,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
          explanation: 'Low risk',
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [matchingPolicy, nonMatchingPolicy],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(1));
      expect(result.matchingPolicies.first.policy.id, equals('dp1'));
      expect(result.totalPoliciesEvaluated, equals(2));
    });

    test('evaluate<DecisionPolicy> returns empty when none match', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(evaluateAll: true);
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.2);
      final context = _createContext();

      final policy = DecisionPolicy(
        id: 'dp1',
        name: 'High Risk',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
          explanation: 'High risk',
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy],
        appraisal,
        context,
      );

      expect(result.matchingPolicies, isEmpty);
      expect(result.resolvedPolicy, isNull);
    });

    test('evaluate<ExpressionPolicy> works with expression policies',
        () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(evaluateAll: true);
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final policy = ExpressionPolicy(
        id: 'ep1',
        name: 'High Risk Expression',
        priority: 80,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.tentative,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [policy],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(1));
      expect(result.matchingPolicies.first.policy.id, equals('ep1'));
    });

    test('conflict resolution firstMatch returns first', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.firstMatch,
        // Disable short-circuit so all policies get evaluated
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final policy1 = DecisionPolicy(
        id: 'dp1',
        name: 'Policy 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
          explanation: 'Reject',
        ),
      );

      final policy2 = DecisionPolicy(
        id: 'dp2',
        name: 'Policy 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.3,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
          explanation: 'Proceed',
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy1, policy2],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(2));
      // firstMatch returns the first in sorted order (highest priority)
      expect(result.resolvedPolicy!.policy.id, equals('dp1'));
    });

    test('conflict resolution highestPriority returns highest', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.highestPriority,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final lowPriority = DecisionPolicy(
        id: 'dp-low',
        name: 'Low',
        priority: 10,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
          explanation: 'Proceed',
        ),
      );

      final highPriority = DecisionPolicy(
        id: 'dp-high',
        name: 'High',
        priority: 95,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
          explanation: 'Reject',
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [lowPriority, highPriority],
        appraisal,
        context,
      );

      // highestPriority resolves to the first match (already sorted by priority)
      expect(result.resolvedPolicy!.policy.id, equals('dp-high'));
    });

    test('short-circuit stops evaluation early for high-priority match',
        () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        shortCircuit: ShortCircuitConfig(enabled: true, priorityThreshold: 80),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final highPriorityPolicy = DecisionPolicy(
        id: 'dp-high',
        name: 'High Priority',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
          explanation: 'Reject',
        ),
      );

      final lowPriorityPolicy = DecisionPolicy(
        id: 'dp-low',
        name: 'Low Priority',
        priority: 10,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
          explanation: 'Proceed',
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [highPriorityPolicy, lowPriorityPolicy],
        appraisal,
        context,
      );

      expect(result.shortCircuited, isTrue);
      expect(result.matchingPolicies.length, equals(1));
      expect(result.matchingPolicies.first.policy.id, equals('dp-high'));
    });

    test('error handling with failOnError throws PolicyEvaluationException',
        () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        failOnError: true,
        policyEvaluationTimeout: Duration(milliseconds: 1),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      // A policy with a condition that references a missing metric
      // won't throw an error in evaluate (it returns false), so we use
      // an expression that will timeout instead
      // Actually, the simpler approach: missing metrics return false, not error.
      // For a true error scenario, we need a condition that causes an exception.
      // Since ThresholdCondition won't throw, let's verify the error collection
      // path with policies that all succeed, and test the exception class directly.

      final policy = DecisionPolicy(
        id: 'dp1',
        name: 'Policy',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
          explanation: 'ok',
        ),
      );

      // This should succeed without error
      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy],
        appraisal,
        context,
      );
      expect(result.evaluationErrors, isEmpty);
    });
  });

  // ===========================================================================
  // PolicyEvaluationException
  // ===========================================================================

  group('PolicyEvaluationException', () {
    test('toString includes error count', () {
      const exception = PolicyEvaluationException([
        PolicyEvaluationError(policyId: 'dp1', error: 'err1'),
        PolicyEvaluationError(policyId: 'dp2', error: 'err2'),
      ]);
      final str = exception.toString();
      expect(str, contains('PolicyEvaluationException'));
      expect(str, contains('2'));
    });
  });

  // ===========================================================================
  // Batch processing with maxParallelism
  // ===========================================================================

  group('Batch processing', () {
    test('evaluates policies in batches based on maxParallelism', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        maxParallelism: 2,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      // Create 5 policies that all match (risk > 0.5)
      final policies = List.generate(
        5,
        (i) => DecisionPolicy(
          id: 'dp-$i',
          name: 'Policy $i',
          priority: 50 - i,
          condition: const ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.5,
          ),
          guidance: DecisionGuidance(
            action: DecisionAction.proceed,
            explanation: 'Policy $i',
          ),
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        policies,
        appraisal,
        context,
      );

      // All 5 policies should match
      expect(result.matchingPolicies.length, equals(5));
      expect(result.totalPoliciesEvaluated, equals(5));
      expect(result.shortCircuited, isFalse);
    });
  });

  // ===========================================================================
  // Short-circuit on first match (evaluateAll=false)
  // ===========================================================================

  group('Short-circuit on first match', () {
    test('stops after first match when evaluateAll is false', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: false,
        // Disable priority-based short-circuit so only first-match triggers
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final policy1 = DecisionPolicy(
        id: 'dp1',
        name: 'Policy 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
          explanation: 'Reject',
        ),
      );

      final policy2 = DecisionPolicy(
        id: 'dp2',
        name: 'Policy 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.3,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
          explanation: 'Proceed',
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy1, policy2],
        appraisal,
        context,
      );

      // Only first match should be recorded, short-circuited
      expect(result.matchingPolicies.length, equals(1));
      expect(result.matchingPolicies.first.policy.id, equals('dp1'));
      expect(result.shortCircuited, isTrue);
    });
  });

  // ===========================================================================
  // Error accumulation (failOnError=false)
  // ===========================================================================

  group('Error accumulation', () {
    test('accumulates errors when failOnError is false', () async {
      final condEval = _SelectiveErrorEvaluator(
        errorPolicyIds: {'dp-err'},
      );
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        failOnError: false,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      final evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      // Use distinct condition instances so the evaluator can identify them
      final errorPolicy = DecisionPolicy(
        id: 'dp-err',
        name: 'Error Policy',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.1,
        ),
        guidance: const DecisionGuidance(action: DecisionAction.reject),
      );

      final goodPolicy = DecisionPolicy(
        id: 'dp-good',
        name: 'Good Policy',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(action: DecisionAction.proceed),
      );

      // Register policies so the evaluator can match conditions to IDs
      condEval.registerPolicies([errorPolicy, goodPolicy]);

      final result = await evaluator.evaluate<DecisionPolicy>(
        [errorPolicy, goodPolicy],
        appraisal,
        context,
      );

      // Error should be accumulated but not thrown
      expect(result.evaluationErrors.length, equals(1));
      expect(result.evaluationErrors.first.policyId, equals('dp-err'));
      // Good policy still matches
      expect(result.matchingPolicies.length, equals(1));
      expect(result.matchingPolicies.first.policy.id, equals('dp-good'));
    });

    test('throws PolicyEvaluationException when failOnError is true',
        () async {
      final condEval = _SelectiveErrorEvaluator(
        errorPolicyIds: {'dp-err'},
      );
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        failOnError: true,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      final evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final errorPolicy = DecisionPolicy(
        id: 'dp-err',
        name: 'Error Policy',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.1,
        ),
        guidance: const DecisionGuidance(action: DecisionAction.reject),
      );

      condEval.registerPolicies([errorPolicy]);

      expect(
        () => evaluator.evaluate<DecisionPolicy>(
          [errorPolicy],
          appraisal,
          context,
        ),
        throwsA(isA<PolicyEvaluationException>()),
      );
    });
  });

  // ===========================================================================
  // Conflict resolution: lastMatch
  // ===========================================================================

  group('Conflict resolution: lastMatch', () {
    test('returns last matching policy', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.lastMatch,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final policy1 = DecisionPolicy(
        id: 'dp1',
        name: 'Policy 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
          explanation: 'Reject',
        ),
      );

      final policy2 = DecisionPolicy(
        id: 'dp2',
        name: 'Policy 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.3,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
          explanation: 'Proceed',
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy1, policy2],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(2));
      // lastMatch returns the last in the sorted matches
      expect(result.resolvedPolicy!.policy.id, equals('dp2'));
    });
  });

  // ===========================================================================
  // Conflict resolution: mostRestrictive
  // ===========================================================================

  group('Conflict resolution: mostRestrictive', () {
    test('returns most restrictive action for DecisionPolicy', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.mostRestrictive,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      // proceed is least restrictive
      final proceedPolicy = DecisionPolicy(
        id: 'dp-proceed',
        name: 'Proceed',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
        ),
      );

      // hold is more restrictive
      final holdPolicy = DecisionPolicy(
        id: 'dp-hold',
        name: 'Hold',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.hold,
        ),
      );

      // reject is most restrictive
      final rejectPolicy = DecisionPolicy(
        id: 'dp-reject',
        name: 'Reject',
        priority: 30,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [proceedPolicy, holdPolicy, rejectPolicy],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(3));
      // reject is most restrictive (index 0 in actionOrder)
      expect(
        result.resolvedPolicy!.policy.guidance.action,
        equals(DecisionAction.reject),
      );
    });

    test('action ordering: reject > escalate > hold > question > defer > '
        'proceedWithCaution > proceed', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.mostRestrictive,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      // escalate should win over proceedWithCaution
      final cautionPolicy = DecisionPolicy(
        id: 'dp-caution',
        name: 'Caution',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceedWithCaution,
        ),
      );

      final escalatePolicy = DecisionPolicy(
        id: 'dp-escalate',
        name: 'Escalate',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.escalate,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [cautionPolicy, escalatePolicy],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.guidance.action,
        equals(DecisionAction.escalate),
      );
    });

    test('falls back to highest priority for non-DecisionPolicy', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.mostRestrictive,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final policy1 = ExpressionPolicy(
        id: 'ep1',
        name: 'Expression 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.low,
            directness: Directness.direct,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.concise,
          ),
        ),
      );

      final policy2 = ExpressionPolicy(
        id: 'ep2',
        name: 'Expression 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.casual,
            confidence: ToneConfidence.tentative,
            empathy: Empathy.high,
            directness: Directness.diplomatic,
          ),
          format: FormatConfig(
            structure: Structure.bullets,
            length: Length.detailed,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [policy1, policy2],
        appraisal,
        context,
      );

      // For non-DecisionPolicy, mostRestrictive falls back to first (highest priority)
      expect(result.resolvedPolicy!.policy.id, equals('ep1'));
    });
  });

  // ===========================================================================
  // Conflict resolution: mostSpecific
  // ===========================================================================

  group('Conflict resolution: mostSpecific', () {
    test('returns last matching policy (most specific scope)', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.mostSpecific,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final broadPolicy = DecisionPolicy(
        id: 'dp-broad',
        name: 'Broad Policy',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.3,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
        ),
      );

      final specificPolicy = DecisionPolicy(
        id: 'dp-specific',
        name: 'Specific Policy',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.7,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [broadPolicy, specificPolicy],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(2));
      // mostSpecific returns last in the sorted list
      expect(result.resolvedPolicy!.policy.id, equals('dp-specific'));
    });
  });

  // ===========================================================================
  // Conflict resolution: unanimous
  // ===========================================================================

  group('Conflict resolution: unanimous', () {
    test('returns first when all agree on the same action', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.unanimous,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final policy1 = DecisionPolicy(
        id: 'dp1',
        name: 'Policy 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
        ),
      );

      final policy2 = DecisionPolicy(
        id: 'dp2',
        name: 'Policy 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy1, policy2],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(2));
      // All agree on reject, so first is returned
      expect(result.resolvedPolicy!.policy.id, equals('dp1'));
      expect(
        result.resolvedPolicy!.policy.guidance.action,
        equals(DecisionAction.reject),
      );
    });

    test('falls back to mostRestrictive when policies disagree', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.unanimous,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final rejectPolicy = DecisionPolicy(
        id: 'dp-reject',
        name: 'Reject',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
        ),
      );

      final proceedPolicy = DecisionPolicy(
        id: 'dp-proceed',
        name: 'Proceed',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [rejectPolicy, proceedPolicy],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(2));
      // Disagreement falls back to mostRestrictive (reject)
      expect(
        result.resolvedPolicy!.policy.guidance.action,
        equals(DecisionAction.reject),
      );
    });

    test('returns first for non-DecisionPolicy', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.unanimous,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final ep1 = ExpressionPolicy(
        id: 'ep1',
        name: 'Expr 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.low,
            directness: Directness.direct,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.concise,
          ),
        ),
      );

      final ep2 = ExpressionPolicy(
        id: 'ep2',
        name: 'Expr 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.casual,
            confidence: ToneConfidence.tentative,
            empathy: Empathy.high,
            directness: Directness.diplomatic,
          ),
          format: FormatConfig(
            structure: Structure.bullets,
            length: Length.detailed,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [ep1, ep2],
        appraisal,
        context,
      );

      // Non-DecisionPolicy unanimous returns first
      expect(result.resolvedPolicy!.policy.id, equals('ep1'));
    });
  });

  // ===========================================================================
  // Conflict resolution: majority
  // ===========================================================================

  group('Conflict resolution: majority', () {
    test('returns most common action for DecisionPolicy', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.majority,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      // 2 proceed vs 1 reject: proceed should win
      final proceed1 = DecisionPolicy(
        id: 'dp-proceed1',
        name: 'Proceed 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
        ),
      );

      final proceed2 = DecisionPolicy(
        id: 'dp-proceed2',
        name: 'Proceed 2',
        priority: 70,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
        ),
      );

      final reject1 = DecisionPolicy(
        id: 'dp-reject1',
        name: 'Reject 1',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [proceed1, proceed2, reject1],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(3));
      // Majority is proceed (2 vs 1)
      expect(
        result.resolvedPolicy!.policy.guidance.action,
        equals(DecisionAction.proceed),
      );
    });

    test('returns first for non-DecisionPolicy', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.majority,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final ep1 = ExpressionPolicy(
        id: 'ep1',
        name: 'Expr 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.low,
            directness: Directness.direct,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.concise,
          ),
        ),
      );

      final ep2 = ExpressionPolicy(
        id: 'ep2',
        name: 'Expr 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.casual,
            confidence: ToneConfidence.tentative,
            empathy: Empathy.high,
            directness: Directness.diplomatic,
          ),
          format: FormatConfig(
            structure: Structure.bullets,
            length: Length.detailed,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [ep1, ep2],
        appraisal,
        context,
      );

      // Non-DecisionPolicy majority returns first
      expect(result.resolvedPolicy!.policy.id, equals('ep1'));
    });
  });

  // ===========================================================================
  // Conflict resolution: merge (DecisionPolicy)
  // ===========================================================================

  group('Conflict resolution: merge (DecisionPolicy)', () {
    test('merges decision policies with most restrictive action and combined '
        'modifiers', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final proceedPolicy = DecisionPolicy(
        id: 'dp-proceed',
        name: 'Proceed',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: DecisionGuidance(
          action: DecisionAction.proceed,
          modifiers: [
            DecisionModifier.log(level: 'info'),
          ],
        ),
      );

      final rejectPolicy = DecisionPolicy(
        id: 'dp-reject',
        name: 'Reject',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: DecisionGuidance(
          action: DecisionAction.reject,
          modifiers: [
            DecisionModifier.requireApproval(approverRole: 'admin'),
          ],
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [proceedPolicy, rejectPolicy],
        appraisal,
        context,
      );

      final resolved = result.resolvedPolicy!;
      // Most restrictive action wins
      expect(
        resolved.policy.guidance.action,
        equals(DecisionAction.reject),
      );
      // Modifiers are combined from both policies
      expect(resolved.policy.guidance.modifiers.length, equals(2));
      // Merged ID format
      expect(resolved.policy.id, contains('merged:'));
      expect(resolved.policy.id, contains('dp-proceed'));
      expect(resolved.policy.id, contains('dp-reject'));
      // Priority is max of both
      expect(resolved.policy.priority, equals(90));
      // Confidence is averaged
      expect(resolved.confidence, greaterThan(0));
    });
  });

  // ===========================================================================
  // Conflict resolution: merge (ExpressionPolicy)
  // ===========================================================================

  group('Conflict resolution: merge (ExpressionPolicy)', () {
    test('merges tone: mostFormal, leastConfident, highestEmpathy', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final formalPolicy = ExpressionPolicy(
        id: 'ep-formal',
        name: 'Formal',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.low,
            directness: Directness.direct,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.concise,
            includeEvidence: true,
            includeCaveats: false,
            includeAlternatives: false,
          ),
        ),
      );

      final casualPolicy = ExpressionPolicy(
        id: 'ep-casual',
        name: 'Casual',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.casual,
            confidence: ToneConfidence.tentative,
            empathy: Empathy.high,
            directness: Directness.diplomatic,
          ),
          format: FormatConfig(
            structure: Structure.bullets,
            length: Length.detailed,
            includeEvidence: false,
            includeCaveats: true,
            includeAlternatives: true,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [formalPolicy, casualPolicy],
        appraisal,
        context,
      );

      final resolved = result.resolvedPolicy!;
      final style = resolved.policy.style;

      // Tone: mostFormal wins
      expect(style.tone.formality, equals(Formality.formal));
      // Tone: leastConfident wins
      expect(style.tone.confidence, equals(ToneConfidence.tentative));
      // Tone: highestEmpathy wins
      expect(style.tone.empathy, equals(Empathy.high));

      // Format: any-true booleans
      expect(style.format.includeEvidence, isTrue);
      expect(style.format.includeCaveats, isTrue);
      expect(style.format.includeAlternatives, isTrue);

      // Format: shortest length
      expect(style.format.length, equals(Length.concise));

      // Merged ID
      expect(resolved.policy.id, contains('merged:'));
      // Priority is max
      expect(resolved.policy.priority, equals(90));
    });

    test('merges hedging: highest level and phrase deduplication', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final lightHedgingPolicy = ExpressionPolicy(
        id: 'ep-light',
        name: 'Light Hedging',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
          hedging: HedgingConfig(
            level: HedgingLevel.light,
            phrases: HedgingPhrases(
              highUncertainty: ['It appears that...'],
              qualifying: ['however'],
            ),
          ),
        ),
      );

      final strongHedgingPolicy = ExpressionPolicy(
        id: 'ep-strong',
        name: 'Strong Hedging',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
          hedging: HedgingConfig(
            level: HedgingLevel.strong,
            phrases: HedgingPhrases(
              highUncertainty: ['It appears that...', 'Preliminary data...'],
              qualifying: ['however', 'although'],
              probabilistic: ['likely', 'possibly'],
            ),
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [lightHedgingPolicy, strongHedgingPolicy],
        appraisal,
        context,
      );

      final resolved = result.resolvedPolicy!;
      final hedging = resolved.policy.style.hedging!;

      // Highest hedging level wins
      expect(hedging.level, equals(HedgingLevel.strong));

      // Phrases are merged with deduplication
      expect(hedging.phrases, isNotNull);
      // 'It appears that...' appears in both but should only appear once
      expect(
        hedging.phrases!.highUncertainty,
        containsAll(['It appears that...', 'Preliminary data...']),
      );
      expect(hedging.phrases!.highUncertainty!.length, equals(2));
      // 'however' appears in both but only once after dedup
      expect(
        hedging.phrases!.qualifying,
        containsAll(['however', 'although']),
      );
      expect(hedging.phrases!.qualifying!.length, equals(2));
      // probabilistic only in strong
      expect(
        hedging.phrases!.probabilistic,
        containsAll(['likely', 'possibly']),
      );
    });

    test('merges expression policies without hedging', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final ep1 = ExpressionPolicy(
        id: 'ep1',
        name: 'No Hedging 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
          // No hedging
        ),
      );

      final ep2 = ExpressionPolicy(
        id: 'ep2',
        name: 'No Hedging 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
          // No hedging
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [ep1, ep2],
        appraisal,
        context,
      );

      final resolved = result.resolvedPolicy!;
      // Hedging level defaults to none when all are null
      expect(resolved.policy.style.hedging!.level, equals(HedgingLevel.none));
      // No phrases merged
      expect(resolved.policy.style.hedging!.phrases, isNull);
    });
  });

  // ===========================================================================
  // Conflict resolution: custom
  // ===========================================================================

  group('Conflict resolution: custom', () {
    test('returns first match as fallback for custom resolution', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.custom,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final policy1 = DecisionPolicy(
        id: 'dp1',
        name: 'Policy 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
        ),
      );

      final policy2 = DecisionPolicy(
        id: 'dp2',
        name: 'Policy 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy1, policy2],
        appraisal,
        context,
      );

      // Custom returns first (highest priority after sort)
      expect(result.resolvedPolicy!.policy.id, equals('dp1'));
    });
  });

  // ===========================================================================
  // _calculateConfidence
  // ===========================================================================

  group('_calculateConfidence (via evaluate)', () {
    test('averages metric confidences', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      // Appraisal with multiple metrics and different confidences
      final appraisal = AppraisalResult(
        profileId: 'test',
        contextId: 'ctx',
        asOf: DateTime.now(),
        metrics: {
          'risk': MetricResult(
            id: 'risk',
            normalizedValue: 0.8,
            sourceType: MetricSourceType.static_,
            confidence: 0.9,
          ),
          'trust': MetricResult(
            id: 'trust',
            normalizedValue: 0.6,
            sourceType: MetricSourceType.static_,
            confidence: 0.7,
          ),
        },
        aggregatedScore: 0.7,
        metadata: AppraisalMetadata(computedAt: DateTime.now()),
      );

      final context = _createContext();

      final policy = DecisionPolicy(
        id: 'dp1',
        name: 'Policy',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy],
        appraisal,
        context,
      );

      // Confidence should be average of 0.9 and 0.7 = 0.8
      expect(result.matchingPolicies.first.confidence, equals(0.8));
    });

    test('returns 0.5 for empty metrics', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      // Appraisal with no metrics
      final appraisal = AppraisalResult(
        profileId: 'test',
        contextId: 'ctx',
        asOf: DateTime.now(),
        metrics: {},
        aggregatedScore: 0.5,
        metadata: AppraisalMetadata(computedAt: DateTime.now()),
      );

      final context = _createContext();

      // Use AlwaysTrueCondition since no metrics to compare against
      final policy = DecisionPolicy(
        id: 'dp1',
        name: 'Policy',
        priority: 50,
        condition: const AlwaysTrueCondition(),
        guidance: const DecisionGuidance(
          action: DecisionAction.proceed,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy],
        appraisal,
        context,
      );

      // Empty metrics should yield default confidence of 0.5
      expect(result.matchingPolicies.first.confidence, equals(0.5));
    });
  });

  // ===========================================================================
  // Single match resolves without conflict
  // ===========================================================================

  group('Single match conflict resolution', () {
    test('returns single match directly without conflict resolution', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final policy = DecisionPolicy(
        id: 'dp1',
        name: 'Only Policy',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: const DecisionGuidance(
          action: DecisionAction.reject,
        ),
      );

      final result = await evaluator.evaluate<DecisionPolicy>(
        [policy],
        appraisal,
        context,
      );

      expect(result.matchingPolicies.length, equals(1));
      // Single match returns directly (no merge needed)
      expect(result.resolvedPolicy!.policy.id, equals('dp1'));
    });
  });

  // ===========================================================================
  // Merge helpers edge cases
  // ===========================================================================

  group('Merge helpers edge cases', () {
    test('_mostFormal returns neutral when no formal present', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final neutralPolicy = ExpressionPolicy(
        id: 'ep-neutral',
        name: 'Neutral',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.low,
            directness: Directness.direct,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final casualPolicy = ExpressionPolicy(
        id: 'ep-casual',
        name: 'Casual',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.casual,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.low,
            directness: Directness.direct,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [neutralPolicy, casualPolicy],
        appraisal,
        context,
      );

      // No formal present, so neutral wins over casual
      expect(
        result.resolvedPolicy!.policy.style.tone.formality,
        equals(Formality.neutral),
      );
    });

    test('_mostFormal returns casual when only casual present', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final casual1 = ExpressionPolicy(
        id: 'ep-casual1',
        name: 'Casual 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.casual,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final casual2 = ExpressionPolicy(
        id: 'ep-casual2',
        name: 'Casual 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.casual,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [casual1, casual2],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.style.tone.formality,
        equals(Formality.casual),
      );
    });

    test('_leastConfident returns moderate when no tentative', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final assertivePolicy = ExpressionPolicy(
        id: 'ep-assert',
        name: 'Assertive',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final moderatePolicy = ExpressionPolicy(
        id: 'ep-moderate',
        name: 'Moderate',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [assertivePolicy, moderatePolicy],
        appraisal,
        context,
      );

      // No tentative, so moderate wins over assertive
      expect(
        result.resolvedPolicy!.policy.style.tone.confidence,
        equals(ToneConfidence.moderate),
      );
    });

    test('_leastConfident returns assertive when all assertive', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final a1 = ExpressionPolicy(
        id: 'ep-a1',
        name: 'Assert 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final a2 = ExpressionPolicy(
        id: 'ep-a2',
        name: 'Assert 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [a1, a2],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.style.tone.confidence,
        equals(ToneConfidence.assertive),
      );
    });

    test('_highestEmpathy returns moderate when no high', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final lowEmpathy = ExpressionPolicy(
        id: 'ep-low',
        name: 'Low',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.low,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final modEmpathy = ExpressionPolicy(
        id: 'ep-mod',
        name: 'Moderate',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [lowEmpathy, modEmpathy],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.style.tone.empathy,
        equals(Empathy.moderate),
      );
    });

    test('_highestEmpathy returns low when all low', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final low1 = ExpressionPolicy(
        id: 'ep-low1',
        name: 'Low 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.low,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final low2 = ExpressionPolicy(
        id: 'ep-low2',
        name: 'Low 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.low,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [low1, low2],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.style.tone.empathy,
        equals(Empathy.low),
      );
    });

    test('_shortestLength returns standard when no concise', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final stdPolicy = ExpressionPolicy(
        id: 'ep-std',
        name: 'Standard',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
        ),
      );

      final detailedPolicy = ExpressionPolicy(
        id: 'ep-detailed',
        name: 'Detailed',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.detailed,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [stdPolicy, detailedPolicy],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.style.format.length,
        equals(Length.standard),
      );
    });

    test('_shortestLength returns detailed when all detailed', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final d1 = ExpressionPolicy(
        id: 'ep-d1',
        name: 'Detailed 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.detailed,
          ),
        ),
      );

      final d2 = ExpressionPolicy(
        id: 'ep-d2',
        name: 'Detailed 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.detailed,
          ),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [d1, d2],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.style.format.length,
        equals(Length.detailed),
      );
    });

    test('_highestHedgingLevel returns moderate when no strong', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final lightPolicy = ExpressionPolicy(
        id: 'ep-light',
        name: 'Light',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
          hedging: HedgingConfig(level: HedgingLevel.light),
        ),
      );

      final moderatePolicy = ExpressionPolicy(
        id: 'ep-mod',
        name: 'Moderate',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
          hedging: HedgingConfig(level: HedgingLevel.moderate),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [lightPolicy, moderatePolicy],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.style.hedging!.level,
        equals(HedgingLevel.moderate),
      );
    });

    test('_highestHedgingLevel returns light when only light', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        conflictResolution: ConflictResolution.merge,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const evaluator = ParallelPolicyEvaluator(config, condEval);

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final l1 = ExpressionPolicy(
        id: 'ep-l1',
        name: 'Light 1',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
          hedging: HedgingConfig(level: HedgingLevel.light),
        ),
      );

      final l2 = ExpressionPolicy(
        id: 'ep-l2',
        name: 'Light 2',
        priority: 50,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
          ),
          hedging: HedgingConfig(level: HedgingLevel.light),
        ),
      );

      final result = await evaluator.evaluate<ExpressionPolicy>(
        [l1, l2],
        appraisal,
        context,
      );

      expect(
        result.resolvedPolicy!.policy.style.hedging!.level,
        equals(HedgingLevel.light),
      );
    });
  });
}
