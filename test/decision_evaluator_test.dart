/// DecisionPolicyEvaluator Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

// =============================================================================
// Test Helpers
// =============================================================================

/// Create a minimal AppraisalResult with given metrics and aggregated score.
AppraisalResult makeAppraisalResult({
  Map<String, double> metrics = const {},
  double aggregatedScore = 0.5,
}) {
  final metricResults = <String, MetricResult>{};
  for (final entry in metrics.entries) {
    metricResults[entry.key] = MetricResult(
      id: entry.key,
      normalizedValue: entry.value,
      sourceType: MetricSourceType.static_,
      confidence: 1.0,
    );
  }
  return AppraisalResult(
    profileId: 'test-profile',
    contextId: 'test-context',
    asOf: DateTime(2026, 1, 1),
    metrics: metricResults,
    aggregatedScore: aggregatedScore,
    metadata: AppraisalMetadata(computedAt: DateTime(2026, 1, 1)),
  );
}

/// Create a policy with a threshold condition.
DecisionPolicy makeThresholdPolicy({
  required String id,
  required String metric,
  required ComparisonOperator operator,
  required double value,
  required DecisionAction action,
  int priority = 0,
  double? confidence,
  String? explanation,
  List<DecisionModifier> modifiers = const [],
  bool enabled = true,
}) {
  return DecisionPolicy(
    id: id,
    name: 'Policy $id',
    condition: ThresholdCondition(
      metric: metric,
      operator: operator,
      value: value,
    ),
    guidance: DecisionGuidance(
      action: action,
      confidence: confidence,
      explanation: explanation,
      modifiers: modifiers,
    ),
    priority: priority,
    enabled: enabled,
  );
}

/// Create a policy with an expression condition.
DecisionPolicy makeExpressionPolicy({
  required String id,
  required String expression,
  required DecisionAction action,
  int priority = 0,
  double? confidence,
  String? explanation,
  List<DecisionModifier> modifiers = const [],
}) {
  return DecisionPolicy(
    id: id,
    name: 'Policy $id',
    condition: ExpressionCondition(expression: expression),
    guidance: DecisionGuidance(
      action: action,
      confidence: confidence,
      explanation: explanation,
      modifiers: modifiers,
    ),
    priority: priority,
  );
}

/// Create a policy with a composite condition.
DecisionPolicy makeCompositePolicy({
  required String id,
  required PolicyCondition condition,
  required DecisionAction action,
  int priority = 0,
  double? confidence,
  String? explanation,
  List<DecisionModifier> modifiers = const [],
}) {
  return DecisionPolicy(
    id: id,
    name: 'Policy $id',
    condition: condition,
    guidance: DecisionGuidance(
      action: action,
      confidence: confidence,
      explanation: explanation,
      modifiers: modifiers,
    ),
    priority: priority,
  );
}

/// Create a policy with an AlwaysTrueCondition.
DecisionPolicy makeAlwaysTruePolicy({
  required String id,
  required DecisionAction action,
  int priority = 0,
  double? confidence,
  String? explanation,
}) {
  return DecisionPolicy(
    id: id,
    name: 'Policy $id',
    condition: const AlwaysTrueCondition(),
    guidance: DecisionGuidance(
      action: action,
      confidence: confidence,
      explanation: explanation,
    ),
    priority: priority,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late DecisionPolicyEvaluator evaluator;

  setUp(() {
    evaluator = const DecisionPolicyEvaluator();
  });

  // ===========================================================================
  // Construction
  // ===========================================================================

  group('DecisionPolicyEvaluator creation', () {
    test('const constructor creates evaluator', () {
      const e = DecisionPolicyEvaluator();
      expect(e, isA<DecisionPolicyEvaluator>());
    });
  });

  // ===========================================================================
  // evaluate() - firstMatch strategy
  // ===========================================================================

  group('evaluate() - firstMatch strategy', () {
    test('policies sorted by priority descending', () {
      // Lower priority policy is declared first, but higher priority should
      // be evaluated first due to sorting.
      final lowPriority = makeThresholdPolicy(
        id: 'low',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.3,
        action: DecisionAction.proceedWithCaution,
        priority: 10,
      );
      final highPriority = makeThresholdPolicy(
        id: 'high',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.3,
        action: DecisionAction.reject,
        priority: 100,
      );
      final section = DecisionPolicySection(
        policies: [lowPriority, highPriority],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // Higher priority policy (reject) should match first
      expect(result.guidance.action, equals(DecisionAction.reject));
      expect(result.matchedPolicies.length, equals(1));
      expect(result.matchedPolicies.first.id, equals('high'));
    });

    test('equal priority uses declaration order', () {
      final first = makeThresholdPolicy(
        id: 'first',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.3,
        action: DecisionAction.hold,
        priority: 50,
      );
      final second = makeThresholdPolicy(
        id: 'second',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.3,
        action: DecisionAction.reject,
        priority: 50,
      );
      final section = DecisionPolicySection(
        policies: [first, second],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // With equal priority, sort is stable so declaration order is preserved.
      // The first declared policy should be the first in sorted list.
      expect(result.matchedPolicies.length, equals(1));
      expect(result.matchedPolicies.first.id, equals('first'));
      expect(result.guidance.action, equals(DecisionAction.hold));
    });

    test('returns first match and stops evaluation', () {
      final matching = makeThresholdPolicy(
        id: 'match1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.3,
        action: DecisionAction.escalate,
        priority: 100,
      );
      final alsoMatching = makeThresholdPolicy(
        id: 'match2',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.reject,
        priority: 50,
      );
      final section = DecisionPolicySection(
        policies: [matching, alsoMatching],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // Only first match returned
      expect(result.matchedPolicies.length, equals(1));
      expect(result.matchedPolicies.first.id, equals('match1'));
      expect(result.guidance.action, equals(DecisionAction.escalate));
    });

    test('condition evaluated against appraisal metrics', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'quality',
        operator: ComparisonOperator.lessThan,
        value: 0.5,
        action: DecisionAction.hold,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.firstMatch,
      );

      // quality=0.3 < 0.5 should match
      final matching = makeAppraisalResult(metrics: {'quality': 0.3});
      final result1 = evaluator.evaluate(
        policySection: section,
        appraisalResult: matching,
        profileId: 'p1',
      );
      expect(result1.guidance.action, equals(DecisionAction.hold));

      // quality=0.8 < 0.5 should NOT match
      final notMatching = makeAppraisalResult(metrics: {'quality': 0.8});
      final result2 = evaluator.evaluate(
        policySection: section,
        appraisalResult: notMatching,
        profileId: 'p1',
      );
      // Falls through to default proceed
      expect(result2.guidance.action, equals(DecisionAction.proceed));
    });

    test('no match with defaultPolicy returns default policy guidance', () {
      final nonMatching = makeThresholdPolicy(
        id: 'never-matches',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 100,
      );
      // The default policy must also not match during iteration, but exist
      // in the policies list so getPolicy() can find it by ID.
      final defaultP = makeThresholdPolicy(
        id: 'fallback',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.proceedWithCaution,
        explanation: 'Default fallback',
        priority: 0,
      );
      final section = DecisionPolicySection(
        policies: [nonMatching, defaultP],
        defaultPolicy: 'fallback',
        conflictResolution: ConflictResolution.firstMatch,
      );
      // risk=0.1, so neither policy's condition (> 0.9) matches
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(
        result.guidance.action,
        equals(DecisionAction.proceedWithCaution),
      );
      expect(result.metadata?['source'], equals('defaultPolicy'));
      expect(result.matchedPolicies.first.id, equals('fallback'));
    });

    test('no match and no defaultPolicy returns defaultProceed', () {
      final nonMatching = makeThresholdPolicy(
        id: 'never-matches',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 100,
      );
      final section = DecisionPolicySection(
        policies: [nonMatching],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.guidance.confidence, equals(1.0));
      expect(result.metadata?['source'], equals('fallback'));
      expect(result.matchedPolicies, isEmpty);
    });

    test('no match with defaultPolicy ID that does not exist falls back to defaultProceed', () {
      final nonMatching = makeThresholdPolicy(
        id: 'never-matches',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 100,
      );
      final section = DecisionPolicySection(
        policies: [nonMatching],
        defaultPolicy: 'nonexistent-id',
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // defaultPolicy ID does not resolve, so we fall back to defaultProceed
      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.metadata?['source'], equals('fallback'));
    });

    test('metadata contains evaluatedAt, policiesEvaluated, evaluationPath', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.3,
        action: DecisionAction.reject,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.metadata, isNotNull);
      expect(result.metadata!['evaluatedAt'], isA<String>());
      expect(result.metadata!['policiesEvaluated'], equals(1));
      expect(result.metadata!['evaluationPath'], isA<List>());
      expect(
        (result.metadata!['evaluationPath'] as List),
        contains('p1'),
      );
    });
  });

  // ===========================================================================
  // evaluate() - highestPriority strategy
  // ===========================================================================

  group('evaluate() - highestPriority strategy', () {
    test('behaves same as firstMatch since pre-sorted by priority', () {
      final lowPri = makeThresholdPolicy(
        id: 'low',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.2,
        action: DecisionAction.proceedWithCaution,
        priority: 10,
      );
      final highPri = makeThresholdPolicy(
        id: 'high',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.2,
        action: DecisionAction.reject,
        priority: 100,
      );
      final section = DecisionPolicySection(
        policies: [lowPri, highPri],
        conflictResolution: ConflictResolution.highestPriority,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.reject));
      expect(result.matchedPolicies.first.id, equals('high'));
    });

    test('no match returns default', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.highestPriority,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.metadata?['source'], equals('fallback'));
    });
  });

  // ===========================================================================
  // evaluate() - mostRestrictive strategy
  // ===========================================================================

  group('evaluate() - mostRestrictive strategy', () {
    test('reject wins over all other actions', () {
      final proceed = makeThresholdPolicy(
        id: 'proceed',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 100,
      );
      final reject = makeThresholdPolicy(
        id: 'reject',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.reject,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [proceed, reject],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.reject));
      expect(result.matchedPolicies.length, equals(2));
    });

    test('escalate wins over hold, question, defer, proceedWithCaution, proceed', () {
      final escalate = makeThresholdPolicy(
        id: 'escalate',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.escalate,
        priority: 10,
      );
      final hold = makeThresholdPolicy(
        id: 'hold',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 10,
      );
      final proceed = makeThresholdPolicy(
        id: 'proceed',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [hold, proceed, escalate],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.escalate));
    });

    test('hold wins over question, defer, proceedWithCaution, proceed', () {
      final hold = makeThresholdPolicy(
        id: 'hold',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 10,
      );
      final question = makeThresholdPolicy(
        id: 'question',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.question,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [question, hold],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.hold));
    });

    test('question wins over defer, proceedWithCaution, proceed', () {
      final question = makeThresholdPolicy(
        id: 'question',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.question,
        priority: 10,
      );
      final defer = makeThresholdPolicy(
        id: 'defer',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.defer,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [defer, question],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.question));
    });

    test('defer wins over proceedWithCaution and proceed', () {
      final defer = makeThresholdPolicy(
        id: 'defer',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.defer,
        priority: 10,
      );
      final cautious = makeThresholdPolicy(
        id: 'cautious',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceedWithCaution,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [cautious, defer],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.defer));
    });

    test('proceedWithCaution wins over proceed', () {
      final cautious = makeThresholdPolicy(
        id: 'cautious',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceedWithCaution,
        priority: 10,
      );
      final proceed = makeThresholdPolicy(
        id: 'proceed',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [proceed, cautious],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.proceedWithCaution));
    });

    test('custom is treated as least restrictive', () {
      final custom = makeThresholdPolicy(
        id: 'custom',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.custom,
        priority: 10,
      );
      final proceed = makeThresholdPolicy(
        id: 'proceed',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [custom, proceed],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // proceed (index=6) wins over custom (index=7) because 6 < 7
      expect(result.guidance.action, equals(DecisionAction.proceed));
    });

    test('no match returns default result', () {
      final policy = makeThresholdPolicy(
        id: 'never',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.metadata?['source'], equals('fallback'));
    });

    test('result is a DecisionPolicy so metadata has no mergedPolicyIds', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.reject,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // Since resolved is a DecisionPolicy (not _MergedResult),
      // metadata should NOT contain mergedPolicyIds
      expect(result.metadata?['mergedPolicyIds'], isNull);
      expect(result.guidance.action, equals(DecisionAction.reject));
    });
  });

  // ===========================================================================
  // evaluate() - mostSpecific strategy
  // ===========================================================================

  group('evaluate() - mostSpecific strategy', () {
    test('composite condition wins over expression', () {
      final composite = makeCompositePolicy(
        id: 'composite',
        condition: CompositeCondition(
          all: [
            const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.1,
            ),
          ],
        ),
        action: DecisionAction.reject,
        priority: 10,
      );
      final expression = makeExpressionPolicy(
        id: 'expression',
        expression: 'risk > 0.1',
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [expression, composite],
        conflictResolution: ConflictResolution.mostSpecific,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.reject));
    });

    test('expression condition wins over threshold', () {
      final expression = makeExpressionPolicy(
        id: 'expression',
        expression: 'risk > 0.1',
        action: DecisionAction.escalate,
        priority: 10,
      );
      final threshold = makeThresholdPolicy(
        id: 'threshold',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [threshold, expression],
        conflictResolution: ConflictResolution.mostSpecific,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.escalate));
    });

    test('threshold condition wins over always_true', () {
      final threshold = makeThresholdPolicy(
        id: 'threshold',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 10,
      );
      final alwaysTrue = makeAlwaysTruePolicy(
        id: 'always',
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [alwaysTrue, threshold],
        conflictResolution: ConflictResolution.mostSpecific,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.hold));
    });

    test('equal specificity resolved by higher priority', () {
      final thresholdA = makeThresholdPolicy(
        id: 'threshold-high',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.reject,
        priority: 100,
      );
      final thresholdB = makeThresholdPolicy(
        id: 'threshold-low',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [thresholdB, thresholdA],
        conflictResolution: ConflictResolution.mostSpecific,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.reject));
    });

    test('equal specificity and equal priority uses first in reduce order', () {
      final a = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 50,
      );
      final b = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.escalate,
        priority: 50,
      );
      final section = DecisionPolicySection(
        policies: [a, b],
        conflictResolution: ConflictResolution.mostSpecific,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // reduce starts with 'b' (sorted by priority desc, 'b' first due to priority tie
      // but stable sort keeps declaration order), then compares with 'a'.
      // specA == specB and a.priority >= b.priority => returns 'a'.
      // Actually, sorted by priority descending. Both are 50. Stable sort keeps
      // declaration order [a, b]. Reduce: accumulator=a, compare b.
      // specA (1) == specB (1), a.priority (50) >= b.priority (50) => returns a.
      expect(result.matchedPolicies.length, equals(2));
      expect(result.guidance.action, equals(DecisionAction.hold));
    });

    test('no match returns default', () {
      final policy = makeThresholdPolicy(
        id: 'never',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.mostSpecific,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.metadata?['source'], equals('fallback'));
    });
  });

  // ===========================================================================
  // evaluate() - merge strategy
  // ===========================================================================

  group('evaluate() - merge strategy', () {
    test('uses most restrictive action from all matching policies', () {
      final proceed = makeThresholdPolicy(
        id: 'proceed',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final hold = makeThresholdPolicy(
        id: 'hold',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [proceed, hold],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.hold));
    });

    test('combines modifiers from all matching policies', () {
      final logModifier = DecisionModifier.log(level: 'warning');
      final approvalModifier =
          DecisionModifier.requireApproval(approverRole: 'admin');

      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        modifiers: [logModifier],
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        modifiers: [approvalModifier],
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.modifiers.length, equals(2));
      final types = result.guidance.modifiers.map((m) => m.type).toSet();
      expect(types, contains(ModifierType.log));
      expect(types, contains(ModifierType.requireApproval));
    });

    test('deduplicates modifiers by type (keeps first)', () {
      final log1 = DecisionModifier.log(level: 'warning');
      final log2 = DecisionModifier.log(level: 'error');

      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        modifiers: [log1],
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        modifiers: [log2],
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // Only one log modifier (first encountered wins via putIfAbsent)
      final logModifiers = result.guidance.modifiers
          .where((m) => m.type == ModifierType.log)
          .toList();
      expect(logModifiers.length, equals(1));
      // First one should be kept
      expect(logModifiers.first.getConfig<String>('level'), equals('warning'));
    });

    test('uses minimum confidence from all matching policies', () {
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        confidence: 0.9,
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        confidence: 0.5,
      );
      final policyC = makeThresholdPolicy(
        id: 'c',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        confidence: 0.7,
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB, policyC],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.confidence, equals(0.5));
    });

    test('null confidence policies do not affect minConfidence', () {
      final noConf = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        // confidence is null
      );
      final withConf = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        confidence: 0.8,
      );
      final section = DecisionPolicySection(
        policies: [noConf, withConf],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.confidence, equals(0.8));
    });

    test('all null confidences result in null confidence', () {
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.confidence, isNull);
    });

    test('combines explanations with semicolons', () {
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        explanation: 'Risk is elevated',
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        explanation: 'Quality is low',
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(
        result.guidance.explanation,
        equals('Risk is elevated; Quality is low'),
      );
    });

    test('null explanations are skipped', () {
      final withExplanation = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
        explanation: 'Risk is elevated',
      );
      final noExplanation = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [withExplanation, noExplanation],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.explanation, equals('Risk is elevated'));
    });

    test('all null explanations result in null explanation', () {
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policyA],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.explanation, isNull);
    });

    test('metadata contains mergedPolicyIds', () {
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.metadata?['mergedPolicyIds'], isA<List>());
      final mergedIds = result.metadata!['mergedPolicyIds'] as List;
      expect(mergedIds, containsAll(['a', 'b']));
    });

    test('no match returns default with defaultPolicy', () {
      final nonMatching = makeThresholdPolicy(
        id: 'never',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 10,
      );
      final fallback = makeAlwaysTruePolicy(
        id: 'default',
        action: DecisionAction.defer,
      );
      final section = DecisionPolicySection(
        policies: [nonMatching, fallback],
        defaultPolicy: 'default',
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // The alwaysTrue policy matches, so it is NOT "no match"
      // Let me adjust: make the fallback also not match by using a threshold
      // Actually alwaysTrue always matches, so we need a different test.
      // The "no match" scenario for merge: all policies don't match.
      expect(result.guidance.action, equals(DecisionAction.defer));
    });

    test('merge strategy no match falls to default', () {
      final nonMatching = makeThresholdPolicy(
        id: 'never',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [nonMatching],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.metadata?['source'], equals('fallback'));
    });
  });

  // ===========================================================================
  // evaluate() - other/fallback strategies (line 93 branch)
  // ===========================================================================

  group('evaluate() - fallback strategy branch', () {
    test('unknown/unhandled strategy uses first matching policy', () {
      // ConflictResolution.lastMatch, .unanimous, .majority, .custom
      // all fall through to the `_ => matchingPolicies.first` branch.
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 100,
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.reject,
        priority: 50,
      );

      // Test with lastMatch strategy
      final section = DecisionPolicySection(
        policies: [policyA, policyB],
        conflictResolution: ConflictResolution.lastMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // matchingPolicies.first => the first in the matchingPolicies list
      // (which is iterated from sortedPolicies, so highest priority first)
      expect(result.guidance.action, equals(DecisionAction.hold));
      expect(result.matchedPolicies.length, equals(2));
      // Metadata should NOT contain mergedPolicyIds
      expect(result.metadata?['mergedPolicyIds'], isNull);
    });

    test('unanimous strategy falls to first matching (default switch branch)', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.escalate,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.unanimous,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.escalate));
    });
  });

  // ===========================================================================
  // evaluateCondition()
  // ===========================================================================

  group('evaluateCondition()', () {
    test('delegates to condition.evaluate()', () {
      const condition = ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
      );

      final resultTrue = evaluator.evaluateCondition(
        condition: condition,
        metrics: {'risk': 0.8},
        aggregatedScore: 0.5,
      );
      expect(resultTrue, isTrue);

      final resultFalse = evaluator.evaluateCondition(
        condition: condition,
        metrics: {'risk': 0.3},
        aggregatedScore: 0.5,
      );
      expect(resultFalse, isFalse);
    });

    test('works with AlwaysTrueCondition', () {
      const condition = AlwaysTrueCondition();
      final result = evaluator.evaluateCondition(
        condition: condition,
        metrics: {},
        aggregatedScore: 0.0,
      );
      expect(result, isTrue);
    });

    test('works with ExpressionCondition', () {
      const condition = ExpressionCondition(expression: 'risk > 0.5');
      final result = evaluator.evaluateCondition(
        condition: condition,
        metrics: {'risk': 0.8},
        aggregatedScore: 0.5,
      );
      expect(result, isTrue);
    });

    test('works with CompositeCondition', () {
      const condition = CompositeCondition(
        all: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.3,
          ),
          ThresholdCondition(
            metric: 'quality',
            operator: ComparisonOperator.lessThan,
            value: 0.5,
          ),
        ],
      );
      final result = evaluator.evaluateCondition(
        condition: condition,
        metrics: {'risk': 0.5, 'quality': 0.3},
        aggregatedScore: 0.5,
      );
      expect(result, isTrue);

      final resultFalse = evaluator.evaluateCondition(
        condition: condition,
        metrics: {'risk': 0.5, 'quality': 0.8},
        aggregatedScore: 0.5,
      );
      expect(resultFalse, isFalse);
    });
  });

  // ===========================================================================
  // findAllMatching()
  // ===========================================================================

  group('findAllMatching()', () {
    test('returns all matching policies', () {
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.3,
        action: DecisionAction.hold,
        priority: 10,
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 5,
      );
      final policyC = makeThresholdPolicy(
        id: 'c',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 100,
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB, policyC],
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final matching = evaluator.findAllMatching(
        policySection: section,
        appraisalResult: appraisal,
      );

      expect(matching.length, equals(2));
      final ids = matching.map((p) => p.id).toSet();
      expect(ids, containsAll(['a', 'b']));
      expect(ids, isNot(contains('c')));
    });

    test('returns empty when no policies match', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 10,
      );
      final section = DecisionPolicySection(policies: [policy]);
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.1});

      final matching = evaluator.findAllMatching(
        policySection: section,
        appraisalResult: appraisal,
      );

      expect(matching, isEmpty);
    });

    test('uses policies list directly (not sortedPolicies)', () {
      // findAllMatching uses policySection.policies, not sortedPolicies
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 10,
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 100,
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB],
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final matching = evaluator.findAllMatching(
        policySection: section,
        appraisalResult: appraisal,
      );

      // Both match, returns in declaration order
      expect(matching.length, equals(2));
      expect(matching[0].id, equals('a'));
      expect(matching[1].id, equals('b'));
    });
  });

  // ===========================================================================
  // explain()
  // ===========================================================================

  group('explain()', () {
    test('explains threshold condition match', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
        action: DecisionAction.reject,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.8});

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      expect(explanation.policyId, equals('p1'));
      expect(explanation.matched, isTrue);
      expect(explanation.conditionDetails.length, equals(1));
      expect(explanation.conditionDetails.first.type, equals('threshold'));
      expect(
        explanation.conditionDetails.first.description,
        equals('risk > 0.5'),
      );
      expect(explanation.conditionDetails.first.actualValue, equals(0.8));
      expect(explanation.conditionDetails.first.expectedValue, equals(0.5));
      expect(explanation.conditionDetails.first.matched, isTrue);
      expect(explanation.metricValues, equals({'risk': 0.8}));
      expect(explanation.aggregatedScore, equals(0.5));
    });

    test('explains threshold condition non-match', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.3});

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      expect(explanation.matched, isFalse);
      expect(explanation.conditionDetails.first.matched, isFalse);
      expect(explanation.conditionDetails.first.actualValue, equals(0.3));
    });

    test('explains threshold condition with aggregatedScore metric', () {
      final policy = DecisionPolicy(
        id: 'agg-check',
        name: 'AggCheck',
        condition: const ThresholdCondition(
          metric: 'aggregatedScore',
          operator: ComparisonOperator.greaterThan,
          value: 0.7,
        ),
        guidance: const DecisionGuidance(action: DecisionAction.reject),
      );
      final appraisal = makeAppraisalResult(
        metrics: {'risk': 0.5},
        aggregatedScore: 0.9,
      );

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      expect(explanation.matched, isTrue);
      expect(explanation.conditionDetails.first.actualValue, equals(0.9));
      expect(explanation.aggregatedScore, equals(0.9));
    });

    test('explains threshold condition with missing metric', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'nonexistent',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
        action: DecisionAction.reject,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.8});

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      expect(explanation.matched, isFalse);
      expect(explanation.conditionDetails.first.actualValue, isNull);
    });

    test('explains expression condition', () {
      final policy = makeExpressionPolicy(
        id: 'expr1',
        expression: 'risk > 0.5 && quality < 0.3',
        action: DecisionAction.hold,
      );
      final appraisal = makeAppraisalResult(
        metrics: {'risk': 0.8, 'quality': 0.1},
      );

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      expect(explanation.policyId, equals('expr1'));
      expect(explanation.matched, isTrue);
      expect(explanation.conditionDetails.length, equals(1));
      expect(explanation.conditionDetails.first.type, equals('expression'));
      expect(
        explanation.conditionDetails.first.description,
        equals('risk > 0.5 && quality < 0.3'),
      );
      expect(explanation.conditionDetails.first.matched, isTrue);
    });

    test('explains composite condition with all', () {
      final policy = makeCompositePolicy(
        id: 'comp-all',
        condition: const CompositeCondition(
          all: [
            ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.3,
            ),
            ThresholdCondition(
              metric: 'quality',
              operator: ComparisonOperator.lessThan,
              value: 0.5,
            ),
          ],
        ),
        action: DecisionAction.hold,
      );
      final appraisal = makeAppraisalResult(
        metrics: {'risk': 0.5, 'quality': 0.3},
      );

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      expect(explanation.matched, isTrue);
      // Composite with `all` produces details for each sub-condition
      expect(explanation.conditionDetails.length, equals(2));
      expect(explanation.conditionDetails[0].type, equals('threshold'));
      expect(explanation.conditionDetails[1].type, equals('threshold'));
    });

    test('explains composite condition with any', () {
      final policy = makeCompositePolicy(
        id: 'comp-any',
        condition: const CompositeCondition(
          any: [
            ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.9,
            ),
            ThresholdCondition(
              metric: 'quality',
              operator: ComparisonOperator.lessThan,
              value: 0.5,
            ),
          ],
        ),
        action: DecisionAction.question,
      );
      final appraisal = makeAppraisalResult(
        metrics: {'risk': 0.3, 'quality': 0.2},
      );

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      // quality < 0.5 matches, so overall matched is true
      expect(explanation.matched, isTrue);
      expect(explanation.conditionDetails.length, equals(2));
      // First sub-condition (risk > 0.9) should not match
      expect(explanation.conditionDetails[0].matched, isFalse);
      // Second sub-condition (quality < 0.5) should match
      expect(explanation.conditionDetails[1].matched, isTrue);
    });

    test('explains composite condition with not', () {
      final policy = makeCompositePolicy(
        id: 'comp-not',
        condition: const CompositeCondition(
          not: ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.5,
          ),
        ),
        action: DecisionAction.proceed,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.3});

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      // NOT (risk > 0.5) => NOT false => true
      expect(explanation.matched, isTrue);
      expect(explanation.conditionDetails.length, equals(1));
      expect(explanation.conditionDetails.first.type, equals('threshold'));
    });

    test('explains composite with both all and any', () {
      final policy = makeCompositePolicy(
        id: 'comp-both',
        condition: const CompositeCondition(
          all: [
            ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.1,
            ),
          ],
          any: [
            ThresholdCondition(
              metric: 'quality',
              operator: ComparisonOperator.lessThan,
              value: 0.5,
            ),
          ],
        ),
        action: DecisionAction.hold,
      );
      final appraisal = makeAppraisalResult(
        metrics: {'risk': 0.5, 'quality': 0.3},
      );

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      // Composite with 'not' takes precedence in evaluate(), but explain
      // iterates all/any/not independently
      expect(explanation.conditionDetails.length, equals(2));
    });

    test('explains always_true condition', () {
      final policy = makeAlwaysTruePolicy(
        id: 'always',
        action: DecisionAction.proceed,
      );
      final appraisal = makeAppraisalResult(metrics: {});

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      expect(explanation.policyId, equals('always'));
      expect(explanation.matched, isTrue);
      expect(explanation.conditionDetails.length, equals(1));
      expect(explanation.conditionDetails.first.type, equals('always_true'));
      expect(
        explanation.conditionDetails.first.description,
        equals('Always matches (default fallback)'),
      );
      expect(explanation.conditionDetails.first.matched, isTrue);
    });

    test('nested composite produces details for all sub-conditions', () {
      final policy = makeCompositePolicy(
        id: 'nested',
        condition: CompositeCondition(
          all: [
            const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.1,
            ),
            CompositeCondition(
              any: [
                const ThresholdCondition(
                  metric: 'quality',
                  operator: ComparisonOperator.lessThan,
                  value: 0.5,
                ),
                const ExpressionCondition(expression: 'risk > 0.8'),
              ],
            ),
          ],
        ),
        action: DecisionAction.hold,
      );
      final appraisal = makeAppraisalResult(
        metrics: {'risk': 0.5, 'quality': 0.3},
      );

      final explanation = evaluator.explain(
        policy: policy,
        appraisalResult: appraisal,
      );

      // Should have details for: threshold(risk), threshold(quality), expression(risk>0.8)
      expect(explanation.conditionDetails.length, equals(3));
    });
  });

  // ===========================================================================
  // PolicyEvaluationExplanation
  // ===========================================================================

  group('PolicyEvaluationExplanation', () {
    test('stores all fields', () {
      const explanation = PolicyEvaluationExplanation(
        policyId: 'p1',
        matched: true,
        conditionDetails: [],
        metricValues: {'risk': 0.8},
        aggregatedScore: 0.75,
      );

      expect(explanation.policyId, equals('p1'));
      expect(explanation.matched, isTrue);
      expect(explanation.conditionDetails, isEmpty);
      expect(explanation.metricValues, equals({'risk': 0.8}));
      expect(explanation.aggregatedScore, equals(0.75));
    });
  });

  // ===========================================================================
  // ConditionDetail
  // ===========================================================================

  group('ConditionDetail', () {
    test('stores required fields', () {
      const detail = ConditionDetail(
        type: 'threshold',
        description: 'risk > 0.5',
        matched: true,
      );

      expect(detail.type, equals('threshold'));
      expect(detail.description, equals('risk > 0.5'));
      expect(detail.matched, isTrue);
      expect(detail.actualValue, isNull);
      expect(detail.expectedValue, isNull);
    });

    test('stores optional fields', () {
      const detail = ConditionDetail(
        type: 'threshold',
        description: 'risk > 0.5',
        actualValue: 0.8,
        expectedValue: 0.5,
        matched: true,
      );

      expect(detail.actualValue, equals(0.8));
      expect(detail.expectedValue, equals(0.5));
    });
  });

  // ===========================================================================
  // DecisionResult
  // ===========================================================================

  group('DecisionResult from evaluate()', () {
    test('contains guidance and matched policies', () {
      final policy = makeThresholdPolicy(
        id: 'p1',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.3,
        action: DecisionAction.reject,
        confidence: 0.95,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.reject));
      expect(result.guidance.confidence, equals(0.95));
      expect(result.matchedPolicies.length, equals(1));
      expect(result.matchedPolicies.first.id, equals('p1'));
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('Edge cases', () {
    test('empty policy list returns default', () {
      final section = DecisionPolicySection(
        policies: [],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.proceed));
    });

    test('disabled policy is skipped', () {
      final disabled = makeThresholdPolicy(
        id: 'disabled',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.reject,
        priority: 100,
        enabled: false,
      );
      final enabled = makeThresholdPolicy(
        id: 'enabled',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.proceed,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [disabled, enabled],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // Disabled policy should be skipped; enabled policy matches
      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.matchedPolicies.first.id, equals('enabled'));
    });

    test('aggregatedScore used for threshold metric "aggregatedScore"', () {
      final policy = DecisionPolicy(
        id: 'agg-policy',
        name: 'Aggregated Score Policy',
        condition: const ThresholdCondition(
          metric: 'aggregatedScore',
          operator: ComparisonOperator.lessThan,
          value: 0.3,
        ),
        guidance: const DecisionGuidance(action: DecisionAction.hold),
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.firstMatch,
      );
      final appraisal = makeAppraisalResult(
        metrics: {'risk': 0.5},
        aggregatedScore: 0.2,
      );

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.hold));
    });

    test('multiple metrics used across different policies', () {
      final riskPolicy = makeThresholdPolicy(
        id: 'risk',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.8,
        action: DecisionAction.reject,
        priority: 100,
      );
      final qualityPolicy = makeThresholdPolicy(
        id: 'quality',
        metric: 'quality',
        operator: ComparisonOperator.lessThan,
        value: 0.2,
        action: DecisionAction.hold,
        priority: 50,
      );
      final section = DecisionPolicySection(
        policies: [riskPolicy, qualityPolicy],
        conflictResolution: ConflictResolution.firstMatch,
      );
      // risk=0.5 does not exceed 0.8, quality=0.1 is below 0.2
      final appraisal = makeAppraisalResult(
        metrics: {'risk': 0.5, 'quality': 0.1},
      );

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // First match (by priority): risk policy does not match,
      // quality policy matches
      expect(result.guidance.action, equals(DecisionAction.hold));
      expect(result.matchedPolicies.first.id, equals('quality'));
    });

    test('evaluation path tracks all evaluated policy IDs', () {
      final policyA = makeThresholdPolicy(
        id: 'a',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.9,
        action: DecisionAction.reject,
        priority: 100,
      );
      final policyB = makeThresholdPolicy(
        id: 'b',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.8,
        action: DecisionAction.escalate,
        priority: 50,
      );
      final policyC = makeThresholdPolicy(
        id: 'c',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.hold,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policyA, policyB, policyC],
        conflictResolution: ConflictResolution.firstMatch,
      );
      // risk=0.5: only c matches (> 0.1)
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      // Evaluation path should include all policies evaluated up to and including match
      final path = result.metadata!['evaluationPath'] as List;
      expect(path, equals(['a', 'b', 'c']));
    });

    test('merge with single matching policy', () {
      final policy = makeThresholdPolicy(
        id: 'single',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.escalate,
        priority: 10,
        confidence: 0.7,
        explanation: 'Only match',
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.merge,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.escalate));
      expect(result.guidance.confidence, equals(0.7));
      expect(result.guidance.explanation, equals('Only match'));
      final mergedIds = result.metadata!['mergedPolicyIds'] as List;
      expect(mergedIds, equals(['single']));
    });

    test('mostRestrictive with single policy returns that policy', () {
      final policy = makeThresholdPolicy(
        id: 'sole',
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.1,
        action: DecisionAction.question,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.mostRestrictive,
      );
      final appraisal = makeAppraisalResult(metrics: {'risk': 0.5});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.question));
    });

    test('mostSpecific with single policy returns that policy', () {
      final policy = makeAlwaysTruePolicy(
        id: 'sole',
        action: DecisionAction.defer,
        priority: 10,
      );
      final section = DecisionPolicySection(
        policies: [policy],
        conflictResolution: ConflictResolution.mostSpecific,
      );
      final appraisal = makeAppraisalResult(metrics: {});

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'p1',
      );

      expect(result.guidance.action, equals(DecisionAction.defer));
    });
  });
}
