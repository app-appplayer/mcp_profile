/// DecisionPolicy Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  // ===========================================================================
  // ConflictResolution
  // ===========================================================================

  group('ConflictResolution', () {
    test('has all 9 expected values', () {
      expect(ConflictResolution.values.length, equals(9));
      expect(ConflictResolution.values, containsAll([
        ConflictResolution.firstMatch,
        ConflictResolution.lastMatch,
        ConflictResolution.highestPriority,
        ConflictResolution.mostRestrictive,
        ConflictResolution.mostSpecific,
        ConflictResolution.unanimous,
        ConflictResolution.majority,
        ConflictResolution.merge,
        ConflictResolution.custom,
      ]));
    });

    test('toJsonName returns correct strings', () {
      expect(
        ConflictResolution.firstMatch.toJsonName(),
        equals('first_match'),
      );
      expect(
        ConflictResolution.lastMatch.toJsonName(),
        equals('last_match'),
      );
      expect(
        ConflictResolution.highestPriority.toJsonName(),
        equals('highest_priority'),
      );
      expect(
        ConflictResolution.mostRestrictive.toJsonName(),
        equals('most_restrictive'),
      );
      expect(
        ConflictResolution.mostSpecific.toJsonName(),
        equals('most_specific'),
      );
      expect(
        ConflictResolution.unanimous.toJsonName(),
        equals('unanimous'),
      );
      expect(
        ConflictResolution.majority.toJsonName(),
        equals('majority'),
      );
      expect(ConflictResolution.merge.toJsonName(), equals('merge'));
      expect(ConflictResolution.custom.toJsonName(), equals('custom'));
    });
  });

  // ===========================================================================
  // DecisionPolicySection
  // ===========================================================================

  group('DecisionPolicySection', () {
    DecisionPolicy _makePolicy({
      required String id,
      required String name,
      int priority = 0,
    }) {
      return DecisionPolicy(
        id: id,
        name: name,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.0,
        ),
        guidance: const DecisionGuidance(action: DecisionAction.proceed),
        priority: priority,
      );
    }

    test('creates with required and optional fields', () {
      final section = DecisionPolicySection(
        policies: [
          _makePolicy(id: 'p1', name: 'Policy 1'),
        ],
        defaultPolicy: 'p1',
        conflictResolution: ConflictResolution.highestPriority,
      );
      expect(section.policies.length, equals(1));
      expect(section.defaultPolicy, equals('p1'));
      expect(
        section.conflictResolution,
        equals(ConflictResolution.highestPriority),
      );
    });

    test('defaults conflictResolution to firstMatch', () {
      final section = DecisionPolicySection(
        policies: [_makePolicy(id: 'p1', name: 'Policy 1')],
      );
      expect(
        section.conflictResolution,
        equals(ConflictResolution.firstMatch),
      );
    });

    test('getPolicy returns policy when found', () {
      final p1 = _makePolicy(id: 'p1', name: 'Policy 1');
      final p2 = _makePolicy(id: 'p2', name: 'Policy 2');
      final section = DecisionPolicySection(policies: [p1, p2]);

      final found = section.getPolicy('p2');
      expect(found, isNotNull);
      expect(found!.id, equals('p2'));
    });

    test('getPolicy returns null when not found', () {
      final section = DecisionPolicySection(
        policies: [_makePolicy(id: 'p1', name: 'Policy 1')],
      );
      final found = section.getPolicy('nonexistent');
      expect(found, isNull);
    });

    test('sortedPolicies returns policies sorted by priority descending', () {
      final low = _makePolicy(id: 'low', name: 'Low', priority: 10);
      final mid = _makePolicy(id: 'mid', name: 'Mid', priority: 50);
      final high = _makePolicy(id: 'high', name: 'High', priority: 100);
      final section = DecisionPolicySection(policies: [low, high, mid]);

      final sorted = section.sortedPolicies;
      expect(sorted[0].id, equals('high'));
      expect(sorted[1].id, equals('mid'));
      expect(sorted[2].id, equals('low'));
    });

    test('sortedPolicies does not mutate original list', () {
      final low = _makePolicy(id: 'low', name: 'Low', priority: 10);
      final high = _makePolicy(id: 'high', name: 'High', priority: 100);
      final section = DecisionPolicySection(policies: [low, high]);

      section.sortedPolicies;
      expect(section.policies[0].id, equals('low'));
      expect(section.policies[1].id, equals('high'));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'policies': [
          {
            'id': 'p1',
            'name': 'Policy 1',
            'condition': {
              'type': 'threshold',
              'metric': 'risk',
              'operator': '>',
              'value': 0.0,
            },
            'guidance': {'action': 'proceed'},
            'priority': 10,
          },
        ],
        'defaultPolicy': 'p1',
        'conflictResolution': 'highest_priority',
      };
      final section = DecisionPolicySection.fromJson(json);
      expect(section.policies.length, equals(1));
      expect(section.policies.first.id, equals('p1'));
      expect(section.defaultPolicy, equals('p1'));
      expect(
        section.conflictResolution,
        equals(ConflictResolution.highestPriority),
      );
    });

    test('toJson produces correct output', () {
      final section = DecisionPolicySection(
        policies: [_makePolicy(id: 'p1', name: 'P1', priority: 5)],
        defaultPolicy: 'p1',
        conflictResolution: ConflictResolution.merge,
      );
      final json = section.toJson();
      expect(json['policies'], isNotNull);
      expect((json['policies'] as List).length, equals(1));
      expect(json['defaultPolicy'], equals('p1'));
      expect(json['conflictResolution'], equals('merge'));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      final original = DecisionPolicySection(
        policies: [
          _makePolicy(id: 'a', name: 'A', priority: 10),
          _makePolicy(id: 'b', name: 'B', priority: 20),
        ],
        defaultPolicy: 'a',
        conflictResolution: ConflictResolution.unanimous,
      );
      final json = original.toJson();
      final restored = DecisionPolicySection.fromJson(json);
      expect(restored.policies.length, equals(2));
      expect(restored.defaultPolicy, equals('a'));
      expect(
        restored.conflictResolution,
        equals(ConflictResolution.unanimous),
      );
    });
  });

  // ===========================================================================
  // DecisionPolicy
  // ===========================================================================

  group('DecisionPolicy', () {
    test('creates with required and optional fields', () {
      const policy = DecisionPolicy(
        id: 'test-policy',
        name: 'Test Policy',
        condition: ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: DecisionGuidance(action: DecisionAction.reject),
        description: 'Rejects high risk',
        priority: 100,
        enabled: true,
        tags: ['risk', 'safety'],
      );
      expect(policy.id, equals('test-policy'));
      expect(policy.name, equals('Test Policy'));
      expect(policy.condition, isA<ThresholdCondition>());
      expect(policy.guidance.action, equals(DecisionAction.reject));
      expect(policy.description, equals('Rejects high risk'));
      expect(policy.priority, equals(100));
      expect(policy.enabled, isTrue);
      expect(policy.tags, contains('risk'));
      expect(policy.tags, contains('safety'));
    });

    test('defaults priority to 0, enabled to true, tags to empty', () {
      const policy = DecisionPolicy(
        id: 'minimal',
        name: 'Minimal',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.proceed),
      );
      expect(policy.priority, equals(0));
      expect(policy.enabled, isTrue);
      expect(policy.tags, isEmpty);
      expect(policy.description, isNull);
    });

    test('implements Policy interface', () {
      const policy = DecisionPolicy(
        id: 'iface-test',
        name: 'Interface Test',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.proceed),
        priority: 42,
      );
      // Verify the Policy interface contract
      expect(policy, isA<Policy>());
      final Policy asPolicy = policy;
      expect(asPolicy.id, equals('iface-test'));
      expect(asPolicy.priority, equals(42));
      expect(asPolicy.condition, isA<AlwaysTrueCondition>());
    });

    test('copyWith overrides specified fields', () {
      const original = DecisionPolicy(
        id: 'original',
        name: 'Original',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.proceed),
        priority: 10,
        enabled: true,
        tags: ['tag1'],
      );
      final copy = original.copyWith(
        name: 'Modified',
        priority: 99,
        enabled: false,
        tags: ['tag2', 'tag3'],
      );
      expect(copy.id, equals('original'));
      expect(copy.name, equals('Modified'));
      expect(copy.priority, equals(99));
      expect(copy.enabled, isFalse);
      expect(copy.tags, equals(['tag2', 'tag3']));
      // Original is unchanged
      expect(original.name, equals('Original'));
      expect(original.priority, equals(10));
    });

    test('copyWith preserves fields not overridden', () {
      const original = DecisionPolicy(
        id: 'keep',
        name: 'Keep',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.reject),
        description: 'Stays the same',
        priority: 50,
      );
      final copy = original.copyWith(name: 'New Name');
      expect(copy.id, equals('keep'));
      expect(copy.description, equals('Stays the same'));
      expect(copy.priority, equals(50));
      expect(copy.guidance.action, equals(DecisionAction.reject));
    });

    test('copyWith with no parameters returns identical copy', () {
      const original = DecisionPolicy(
        id: 'no-change',
        name: 'No Change',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.proceed),
        description: 'Should stay identical',
        priority: 42,
        enabled: true,
        tags: ['stable'],
      );
      final copy = original.copyWith();
      expect(copy.id, equals(original.id));
      expect(copy.name, equals(original.name));
      expect(copy.description, equals(original.description));
      expect(copy.priority, equals(original.priority));
      expect(copy.enabled, equals(original.enabled));
      expect(copy.tags, equals(original.tags));
      expect(copy.guidance.action, equals(original.guidance.action));
      expect(copy.condition, isA<AlwaysTrueCondition>());
    });

    test('matches returns true when enabled and condition evaluates true', () {
      const policy = DecisionPolicy(
        id: 'match-test',
        name: 'Match Test',
        condition: ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: DecisionGuidance(action: DecisionAction.reject),
        enabled: true,
      );
      expect(policy.matches({'risk': 0.8}, 0.0), isTrue);
    });

    test('matches returns false when condition evaluates false', () {
      const policy = DecisionPolicy(
        id: 'no-match',
        name: 'No Match',
        condition: ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        guidance: DecisionGuidance(action: DecisionAction.reject),
        enabled: true,
      );
      expect(policy.matches({'risk': 0.3}, 0.0), isFalse);
    });

    test('matches returns false when disabled regardless of condition', () {
      const policy = DecisionPolicy(
        id: 'disabled',
        name: 'Disabled',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.proceed),
        enabled: false,
      );
      expect(policy.matches({'risk': 0.8}, 0.0), isFalse);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'id': 'from-json',
        'name': 'From JSON',
        'condition': {
          'type': 'threshold',
          'metric': 'risk',
          'operator': '>',
          'value': 0.5,
        },
        'guidance': {
          'action': 'reject',
          'confidence': 0.95,
        },
        'description': 'A parsed policy',
        'priority': 80,
        'enabled': true,
        'tags': ['safety'],
      };
      final policy = DecisionPolicy.fromJson(json);
      expect(policy.id, equals('from-json'));
      expect(policy.name, equals('From JSON'));
      expect(policy.condition, isA<ThresholdCondition>());
      expect(policy.guidance.action, equals(DecisionAction.reject));
      expect(policy.guidance.confidence, equals(0.95));
      expect(policy.description, equals('A parsed policy'));
      expect(policy.priority, equals(80));
      expect(policy.enabled, isTrue);
      expect(policy.tags, contains('safety'));
    });

    test('fromJson uses defaults for missing optional fields', () {
      final json = {
        'id': 'minimal-json',
        'name': 'Minimal',
        'condition': {
          'type': 'threshold',
          'metric': 'risk',
          'operator': '>',
          'value': 0.0,
        },
        'guidance': {'action': 'proceed'},
      };
      final policy = DecisionPolicy.fromJson(json);
      expect(policy.priority, equals(0));
      expect(policy.enabled, isTrue);
      expect(policy.tags, isEmpty);
      expect(policy.description, isNull);
    });

    test('toJson produces correct output', () {
      const policy = DecisionPolicy(
        id: 'to-json',
        name: 'To JSON',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.proceed),
        description: 'Test',
        priority: 10,
        tags: ['test'],
      );
      final json = policy.toJson();
      expect(json['id'], equals('to-json'));
      expect(json['name'], equals('To JSON'));
      expect(json['condition'], isNotNull);
      expect(json['guidance'], isNotNull);
      expect(json['description'], equals('Test'));
      expect(json['priority'], equals(10));
      expect(json['tags'], contains('test'));
    });

    test('toJson omits enabled when true (default)', () {
      const policy = DecisionPolicy(
        id: 'default-enabled',
        name: 'Default Enabled',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.proceed),
      );
      final json = policy.toJson();
      expect(json.containsKey('enabled'), isFalse);
    });

    test('toJson includes enabled when false', () {
      const policy = DecisionPolicy(
        id: 'disabled',
        name: 'Disabled',
        condition: AlwaysTrueCondition(),
        guidance: DecisionGuidance(action: DecisionAction.proceed),
        enabled: false,
      );
      final json = policy.toJson();
      expect(json['enabled'], isFalse);
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = DecisionPolicy(
        id: 'roundtrip',
        name: 'Roundtrip',
        condition: ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.7,
        ),
        guidance: DecisionGuidance(
          action: DecisionAction.escalate,
          confidence: 0.85,
        ),
        description: 'Roundtrip test',
        priority: 90,
        tags: ['alpha', 'beta'],
      );
      final json = original.toJson();
      final restored = DecisionPolicy.fromJson(json);
      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.priority, equals(original.priority));
      expect(restored.description, equals(original.description));
      expect(restored.guidance.action, equals(original.guidance.action));
      expect(
        restored.guidance.confidence,
        equals(original.guidance.confidence),
      );
      expect(restored.tags, equals(original.tags));
    });
  });

  // ===========================================================================
  // DecisionResult
  // ===========================================================================

  group('DecisionResult', () {
    test('creates with required and optional fields', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.proceed),
        matchedPolicies: [],
        evaluationTraceId: 'trace-123',
        metadata: {'key': 'value'},
      );
      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.matchedPolicies, isEmpty);
      expect(result.evaluationTraceId, equals('trace-123'));
      expect(result.metadata!['key'], equals('value'));
    });

    test('defaults matchedPolicies to empty', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.proceed),
      );
      expect(result.matchedPolicies, isEmpty);
      expect(result.evaluationTraceId, isNull);
      expect(result.metadata, isNull);
    });

    test('allowsProceeding returns true for proceed action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.proceed),
      );
      expect(result.allowsProceeding, isTrue);
    });

    test('allowsProceeding returns true for proceedWithCaution action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(
          action: DecisionAction.proceedWithCaution,
        ),
      );
      expect(result.allowsProceeding, isTrue);
    });

    test('allowsProceeding returns false for reject action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.reject),
      );
      expect(result.allowsProceeding, isFalse);
    });

    test('blocksProceeding returns true for hold action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.hold),
      );
      expect(result.blocksProceeding, isTrue);
    });

    test('blocksProceeding returns true for reject action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.reject),
      );
      expect(result.blocksProceeding, isTrue);
    });

    test('blocksProceeding returns true for defer action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.defer),
      );
      expect(result.blocksProceeding, isTrue);
    });

    test('blocksProceeding returns false for proceed action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.proceed),
      );
      expect(result.blocksProceeding, isFalse);
    });

    test('requiresHuman returns true for escalate action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.escalate),
      );
      expect(result.requiresHuman, isTrue);
    });

    test('requiresHuman returns true for question action', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.question),
      );
      expect(result.requiresHuman, isTrue);
    });

    test('requiresHuman returns true with approval modifier on non-human action', () {
      final result = DecisionResult(
        guidance: DecisionGuidance(
          action: DecisionAction.proceed,
          modifiers: [
            DecisionModifier.requireApproval(approverRole: 'admin'),
          ],
        ),
      );
      expect(result.requiresHuman, isTrue);
    });

    test('requiresHuman returns false for proceed without approval', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.proceed),
      );
      expect(result.requiresHuman, isFalse);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'guidance': {
          'action': 'reject',
          'confidence': 0.95,
        },
        'matchedPolicies': [
          {
            'id': 'p1',
            'name': 'Policy 1',
            'condition': {
              'type': 'threshold',
              'metric': 'risk',
              'operator': '>',
              'value': 0.0,
            },
            'guidance': {'action': 'reject'},
            'priority': 100,
          },
        ],
        'evaluationTraceId': 'trace-abc',
        'metadata': {'engine': 'v2'},
      };
      final result = DecisionResult.fromJson(json);
      expect(result.guidance.action, equals(DecisionAction.reject));
      expect(result.guidance.confidence, equals(0.95));
      expect(result.matchedPolicies.length, equals(1));
      expect(result.matchedPolicies.first.id, equals('p1'));
      expect(result.evaluationTraceId, equals('trace-abc'));
      expect(result.metadata!['engine'], equals('v2'));
    });

    test('fromJson with minimal fields', () {
      final json = {
        'guidance': {'action': 'proceed'},
      };
      final result = DecisionResult.fromJson(json);
      expect(result.guidance.action, equals(DecisionAction.proceed));
      expect(result.matchedPolicies, isEmpty);
      expect(result.evaluationTraceId, isNull);
      expect(result.metadata, isNull);
    });

    test('toJson produces correct output', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(
          action: DecisionAction.escalate,
          confidence: 0.85,
        ),
        matchedPolicies: [
          DecisionPolicy(
            id: 'p1',
            name: 'P1',
            condition: AlwaysTrueCondition(),
            guidance: DecisionGuidance(action: DecisionAction.escalate),
          ),
        ],
        evaluationTraceId: 'trace-xyz',
        metadata: {'ts': 12345},
      );
      final json = result.toJson();
      expect(json['guidance'], isNotNull);
      expect(json['matchedPolicies'], isNotNull);
      expect((json['matchedPolicies'] as List).length, equals(1));
      expect(json['evaluationTraceId'], equals('trace-xyz'));
      expect(json['metadata'], isNotNull);
    });

    test('toJson omits empty/null optional fields', () {
      const result = DecisionResult(
        guidance: DecisionGuidance(action: DecisionAction.proceed),
      );
      final json = result.toJson();
      expect(json.containsKey('matchedPolicies'), isFalse);
      expect(json.containsKey('evaluationTraceId'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = DecisionResult(
        guidance: DecisionGuidance(
          action: DecisionAction.hold,
          confidence: 0.6,
          explanation: 'Needs review',
        ),
        evaluationTraceId: 'trace-roundtrip',
        metadata: {'attempt': 1},
      );
      final json = original.toJson();
      final restored = DecisionResult.fromJson(json);
      expect(restored.guidance.action, equals(original.guidance.action));
      expect(
        restored.guidance.confidence,
        equals(original.guidance.confidence),
      );
      expect(
        restored.guidance.explanation,
        equals(original.guidance.explanation),
      );
      expect(
        restored.evaluationTraceId,
        equals(original.evaluationTraceId),
      );
      expect(restored.metadata!['attempt'], equals(1));
    });
  });

  // ===========================================================================
  // StandardPolicies
  // ===========================================================================

  group('StandardPolicies', () {
    test('criticalRiskReject creates reject policy for risk > 0.9', () {
      final policy = StandardPolicies.criticalRiskReject();
      expect(policy.id, equals('critical_risk_reject'));
      expect(policy.guidance.action, equals(DecisionAction.reject));
      expect(policy.priority, equals(100));
      // Matches risk above 0.9
      expect(policy.matches({'risk': 0.95}, 0.0), isTrue);
      // Does not match risk below 0.9
      expect(policy.matches({'risk': 0.85}, 0.0), isFalse);
    });

    test('criticalRiskReject accepts custom priority', () {
      final policy = StandardPolicies.criticalRiskReject(priority: 200);
      expect(policy.priority, equals(200));
    });

    test('highRiskEscalate creates escalate policy for risk > 0.7', () {
      final policy = StandardPolicies.highRiskEscalate();
      expect(policy.id, equals('high_risk_escalate'));
      expect(policy.guidance.action, equals(DecisionAction.escalate));
      expect(policy.priority, equals(90));
      expect(policy.guidance.requiresApproval, isTrue);
      // Matches risk above 0.7
      expect(policy.matches({'risk': 0.8}, 0.0), isTrue);
      // Does not match risk below 0.7
      expect(policy.matches({'risk': 0.6}, 0.0), isFalse);
    });

    test('moderateRiskCaution creates proceedWithCaution policy for risk > 0.4', () {
      final policy = StandardPolicies.moderateRiskCaution();
      expect(policy.id, equals('moderate_risk_caution'));
      expect(
        policy.guidance.action,
        equals(DecisionAction.proceedWithCaution),
      );
      expect(policy.priority, equals(50));
      // Matches risk above 0.4
      expect(policy.matches({'risk': 0.5}, 0.0), isTrue);
      // Does not match risk at or below 0.4
      expect(policy.matches({'risk': 0.4}, 0.0), isFalse);
    });

    test('highUncertaintyQuestion creates question policy for uncertainty > 0.7', () {
      final policy = StandardPolicies.highUncertaintyQuestion();
      expect(policy.id, equals('high_uncertainty_question'));
      expect(policy.guidance.action, equals(DecisionAction.question));
      expect(policy.priority, equals(80));
      expect(policy.guidance.requiresEvidence, isTrue);
      // Matches uncertainty above 0.7
      expect(policy.matches({'uncertainty': 0.8}, 0.0), isTrue);
      // Does not match uncertainty below 0.7
      expect(policy.matches({'uncertainty': 0.6}, 0.0), isFalse);
    });

    test('all() returns 4 policies', () {
      final policies = StandardPolicies.all();
      expect(policies.length, equals(4));

      final ids = policies.map((p) => p.id).toList();
      expect(ids, contains('critical_risk_reject'));
      expect(ids, contains('high_risk_escalate'));
      expect(ids, contains('moderate_risk_caution'));
      expect(ids, contains('high_uncertainty_question'));
    });

    test('riskBasedPolicies returns 3 policies', () {
      final policies = StandardPolicies.riskBasedPolicies();
      expect(policies.length, equals(3));
    });

    test('uncertaintyBasedPolicies returns 1 policy', () {
      final policies = StandardPolicies.uncertaintyBasedPolicies();
      expect(policies.length, equals(1));
      expect(policies.first.id, equals('high_uncertainty_question'));
    });
  });

  // ===========================================================================
  // Coverage: decision_policy.dart line 56 (orElse fallback in fromJson)
  // ===========================================================================

  group('DecisionPolicySection.fromJson with unknown conflictResolution', () {
    test('falls back to firstMatch for unknown conflictResolution string', () {
      // Covers line 56: orElse: () => ConflictResolution.firstMatch
      final json = {
        'policies': [
          {
            'id': 'p1',
            'name': 'Policy 1',
            'condition': {
              'type': 'threshold',
              'metric': 'risk',
              'operator': '>',
              'value': 0.0,
            },
            'guidance': {'action': 'proceed'},
          },
        ],
        'conflictResolution': 'completely_unknown_strategy',
      };
      final section = DecisionPolicySection.fromJson(json);
      expect(
        section.conflictResolution,
        equals(ConflictResolution.firstMatch),
      );
    });
  });
}
