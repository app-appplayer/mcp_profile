/// StackedPolicyEvaluator Tests
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

void main() {
  // ===========================================================================
  // StackedEvaluationResult
  // ===========================================================================

  group('StackedEvaluationResult', () {
    test('creation with all fields', () {
      final result = StackedEvaluationResult<DecisionPolicy>(
        allMatches: [],
        matchesByProfile: {},
        resolvedPolicy: null,
        conflictResolutionApplied: false,
        profilesEvaluated: 3,
        policiesEvaluated: 10,
      );
      expect(result.allMatches, isEmpty);
      expect(result.matchesByProfile, isEmpty);
      expect(result.resolvedPolicy, isNull);
      expect(result.conflictResolutionApplied, isFalse);
      expect(result.profilesEvaluated, equals(3));
      expect(result.policiesEvaluated, equals(10));
    });
  });

  // ===========================================================================
  // StackedPolicyEvaluator - Decision Policies
  // ===========================================================================

  group('StackedPolicyEvaluator.evaluateDecisionPolicies', () {
    test('evaluates across multiple profiles with priority adjustment',
        () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const parallelEval = ParallelPolicyEvaluator(config, condEval);
      const stacked = StackedPolicyEvaluator(parallelEval, config);

      final profile1 = SpecProfileBundle(
        schemaVersion: '1.0.0',
        manifest: const ProfileManifest(
          id: 'p1',
          name: 'Profile 1',
          version: '1.0.0',
          provider: 'test',
          scope: ProfileScope.project,
          priority: 10,
        ),
        appraisals: const AppraisalSection(metrics: []),
        decisionPolicies: DecisionPolicySection(policies: [
          DecisionPolicy(
            id: 'dp1',
            name: 'D1',
            priority: 5,
            condition: const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.5,
            ),
            guidance: const DecisionGuidance(
              action: DecisionAction.proceed,
              explanation: 'ok',
            ),
          ),
        ]),
      );

      final profile2 = SpecProfileBundle(
        schemaVersion: '1.0.0',
        manifest: const ProfileManifest(
          id: 'p2',
          name: 'Profile 2',
          version: '1.0.0',
          provider: 'test',
          scope: ProfileScope.global,
          priority: 20,
        ),
        appraisals: const AppraisalSection(metrics: []),
        decisionPolicies: DecisionPolicySection(policies: [
          DecisionPolicy(
            id: 'dp2',
            name: 'D2',
            priority: 3,
            condition: const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.5,
            ),
            guidance: const DecisionGuidance(
              action: DecisionAction.reject,
              explanation: 'too risky',
            ),
          ),
        ]),
      );

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final result = await stacked.evaluateDecisionPolicies(
        [profile1, profile2],
        appraisal,
        context,
      );

      // Both policies should match (risk > 0.5)
      expect(result.allMatches.length, equals(2));
      expect(result.profilesEvaluated, equals(2));
      expect(result.policiesEvaluated, equals(2));

      // Priority adjustment: profilePriority * 10 + policyPriority
      // p1: 10 * 10 + 5 = 105
      // p2: 20 * 10 + 3 = 203
      // Resolved policy should be p2's dp2 (higher adjusted priority)
      expect(result.resolvedPolicy, isNotNull);
      expect(result.resolvedPolicy!.policy.id, equals('p2:dp2'));

      // Conflict resolution applied because multiple policies matched
      expect(result.conflictResolutionApplied, isTrue);
    });

    test('matchesByProfile groups matches by source profile ID', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const parallelEval = ParallelPolicyEvaluator(config, condEval);
      const stacked = StackedPolicyEvaluator(parallelEval, config);

      final profile1 = SpecProfileBundle(
        schemaVersion: '1.0.0',
        manifest: const ProfileManifest(
          id: 'p1',
          name: 'Profile 1',
          version: '1.0.0',
          provider: 'test',
          scope: ProfileScope.project,
          priority: 10,
        ),
        appraisals: const AppraisalSection(metrics: []),
        decisionPolicies: DecisionPolicySection(policies: [
          DecisionPolicy(
            id: 'dp1',
            name: 'D1',
            priority: 5,
            condition: const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.5,
            ),
            guidance: const DecisionGuidance(
              action: DecisionAction.proceed,
              explanation: 'ok',
            ),
          ),
          DecisionPolicy(
            id: 'dp2',
            name: 'D2',
            priority: 8,
            condition: const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.3,
            ),
            guidance: const DecisionGuidance(
              action: DecisionAction.proceedWithCaution,
              explanation: 'careful',
            ),
          ),
        ]),
      );

      final profile2 = SpecProfileBundle(
        schemaVersion: '1.0.0',
        manifest: const ProfileManifest(
          id: 'p2',
          name: 'Profile 2',
          version: '1.0.0',
          provider: 'test',
          scope: ProfileScope.global,
          priority: 5,
        ),
        appraisals: const AppraisalSection(metrics: []),
        decisionPolicies: DecisionPolicySection(policies: [
          DecisionPolicy(
            id: 'dp3',
            name: 'D3',
            priority: 2,
            condition: const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.5,
            ),
            guidance: const DecisionGuidance(
              action: DecisionAction.reject,
              explanation: 'no',
            ),
          ),
        ]),
      );

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final result = await stacked.evaluateDecisionPolicies(
        [profile1, profile2],
        appraisal,
        context,
      );

      // All 3 policies should match
      expect(result.allMatches.length, equals(3));

      // matchesByProfile should have 2 entries
      expect(result.matchesByProfile.containsKey('p1'), isTrue);
      expect(result.matchesByProfile.containsKey('p2'), isTrue);
      expect(result.matchesByProfile['p1']!.length, equals(2));
      expect(result.matchesByProfile['p2']!.length, equals(1));
    });

    test('profilesEvaluated and policiesEvaluated counts are correct',
        () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const parallelEval = ParallelPolicyEvaluator(config, condEval);
      const stacked = StackedPolicyEvaluator(parallelEval, config);

      final profiles = [
        SpecProfileBundle(
          schemaVersion: '1.0.0',
          manifest: const ProfileManifest(
            id: 'p1',
            name: 'P1',
            version: '1.0.0',
            provider: 'test',
            scope: ProfileScope.project,
            priority: 10,
          ),
          appraisals: const AppraisalSection(metrics: []),
          decisionPolicies: DecisionPolicySection(policies: [
            DecisionPolicy(
              id: 'dp1',
              name: 'D1',
              priority: 1,
              condition: const ThresholdCondition(
                metric: 'risk',
                operator: ComparisonOperator.greaterThan,
                value: 0.9,
              ),
              guidance: const DecisionGuidance(
                action: DecisionAction.proceed,
                explanation: 'ok',
              ),
            ),
          ]),
        ),
        SpecProfileBundle(
          schemaVersion: '1.0.0',
          manifest: const ProfileManifest(
            id: 'p2',
            name: 'P2',
            version: '1.0.0',
            provider: 'test',
            scope: ProfileScope.project,
            priority: 5,
          ),
          appraisals: const AppraisalSection(metrics: []),
          decisionPolicies: DecisionPolicySection(policies: [
            DecisionPolicy(
              id: 'dp2',
              name: 'D2',
              priority: 2,
              condition: const ThresholdCondition(
                metric: 'risk',
                operator: ComparisonOperator.greaterThan,
                value: 0.9,
              ),
              guidance: const DecisionGuidance(
                action: DecisionAction.proceed,
                explanation: 'ok',
              ),
            ),
            DecisionPolicy(
              id: 'dp3',
              name: 'D3',
              priority: 3,
              condition: const ThresholdCondition(
                metric: 'risk',
                operator: ComparisonOperator.greaterThan,
                value: 0.9,
              ),
              guidance: const DecisionGuidance(
                action: DecisionAction.proceed,
                explanation: 'ok',
              ),
            ),
          ]),
        ),
      ];

      final appraisal = _createAppraisal(riskValue: 0.5);
      final context = _createContext();

      final result = await stacked.evaluateDecisionPolicies(
        profiles,
        appraisal,
        context,
      );

      expect(result.profilesEvaluated, equals(2));
      expect(result.policiesEvaluated, equals(3));
      // None match (risk 0.5 not > 0.9)
      expect(result.allMatches, isEmpty);
    });

    test('handles profiles without decision policies', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(evaluateAll: true);
      const parallelEval = ParallelPolicyEvaluator(config, condEval);
      const stacked = StackedPolicyEvaluator(parallelEval, config);

      final profile = SpecProfileBundle(
        schemaVersion: '1.0.0',
        manifest: const ProfileManifest(
          id: 'p1',
          name: 'P1',
          version: '1.0.0',
          provider: 'test',
          scope: ProfileScope.project,
        ),
        appraisals: const AppraisalSection(metrics: []),
        // No decision policies
      );

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final result = await stacked.evaluateDecisionPolicies(
        [profile],
        appraisal,
        context,
      );

      expect(result.allMatches, isEmpty);
      expect(result.profilesEvaluated, equals(1));
      expect(result.policiesEvaluated, equals(0));
    });
  });

  // ===========================================================================
  // StackedPolicyEvaluator - Expression Policies
  // ===========================================================================

  group('StackedPolicyEvaluator.evaluateExpressionPolicies', () {
    test('evaluates across profiles', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(
        evaluateAll: true,
        shortCircuit: ShortCircuitConfig(enabled: false),
      );
      const parallelEval = ParallelPolicyEvaluator(config, condEval);
      const stacked = StackedPolicyEvaluator(parallelEval, config);

      final profile1 = SpecProfileBundle(
        schemaVersion: '1.0.0',
        manifest: const ProfileManifest(
          id: 'p1',
          name: 'Profile 1',
          version: '1.0.0',
          provider: 'test',
          scope: ProfileScope.project,
          priority: 10,
        ),
        appraisals: const AppraisalSection(metrics: []),
        expressionPolicies: ExpressionPolicySection(policies: [
          ExpressionPolicy(
            id: 'ep1',
            name: 'E1',
            priority: 5,
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
          ),
        ]),
      );

      final profile2 = SpecProfileBundle(
        schemaVersion: '1.0.0',
        manifest: const ProfileManifest(
          id: 'p2',
          name: 'Profile 2',
          version: '1.0.0',
          provider: 'test',
          scope: ProfileScope.global,
          priority: 20,
        ),
        appraisals: const AppraisalSection(metrics: []),
        expressionPolicies: ExpressionPolicySection(policies: [
          ExpressionPolicy(
            id: 'ep2',
            name: 'E2',
            priority: 3,
            condition: const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 0.5,
            ),
            style: const ExpressionStyle(
              tone: ToneConfig(
                formality: Formality.casual,
                confidence: ToneConfidence.assertive,
                empathy: Empathy.high,
                directness: Directness.direct,
              ),
              format: FormatConfig(
                structure: Structure.bullets,
                length: Length.concise,
              ),
            ),
          ),
        ]),
      );

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final result = await stacked.evaluateExpressionPolicies(
        [profile1, profile2],
        appraisal,
        context,
      );

      expect(result.allMatches.length, equals(2));
      expect(result.profilesEvaluated, equals(2));
      expect(result.policiesEvaluated, equals(2));

      // Priority adjustment: p2 has higher profile priority
      // p1: 10 * 10 + 5 = 105
      // p2: 20 * 10 + 3 = 203
      // Resolved should be p2's ep2
      expect(result.resolvedPolicy, isNotNull);
      expect(result.resolvedPolicy!.policy.id, equals('p2:ep2'));
    });

    test('handles profiles without expression policies', () async {
      const condEval = DefaultPolicyConditionEvaluator();
      const config = ConcurrentEvaluationConfig(evaluateAll: true);
      const parallelEval = ParallelPolicyEvaluator(config, condEval);
      const stacked = StackedPolicyEvaluator(parallelEval, config);

      final profile = SpecProfileBundle(
        schemaVersion: '1.0.0',
        manifest: const ProfileManifest(
          id: 'p1',
          name: 'P1',
          version: '1.0.0',
          provider: 'test',
          scope: ProfileScope.project,
        ),
        appraisals: const AppraisalSection(metrics: []),
        // No expression policies
      );

      final appraisal = _createAppraisal(riskValue: 0.8);
      final context = _createContext();

      final result = await stacked.evaluateExpressionPolicies(
        [profile],
        appraisal,
        context,
      );

      expect(result.allMatches, isEmpty);
      expect(result.profilesEvaluated, equals(1));
      expect(result.policiesEvaluated, equals(0));
    });
  });
}
