/// ExpressionPolicy Tests
library;

import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

void main() {
  // ===========================================================================
  // Helper factories
  // ===========================================================================

  ExpressionStyle makeStyle({
    Formality formality = Formality.neutral,
    ToneConfidence confidence = ToneConfidence.moderate,
    Empathy empathy = Empathy.moderate,
    Directness directness = Directness.balanced,
    Structure structure = Structure.prose,
    Length length = Length.standard,
  }) {
    return ExpressionStyle(
      tone: ToneConfig(
        formality: formality,
        confidence: confidence,
        empathy: empathy,
        directness: directness,
      ),
      format: FormatConfig(
        structure: structure,
        length: length,
      ),
    );
  }

  ExpressionPolicy makePolicy({
    String id = 'test-policy',
    String name = 'Test Policy',
    PolicyCondition? condition,
    ExpressionStyle? style,
    String? description,
    int priority = 0,
    bool enabled = true,
    List<String> tags = const [],
  }) {
    return ExpressionPolicy(
      id: id,
      name: name,
      condition: condition ?? const ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.0,
      ),
      style: style ?? makeStyle(),
      description: description,
      priority: priority,
      enabled: enabled,
      tags: tags,
    );
  }

  // ===========================================================================
  // ExpressionPolicySection Tests
  // ===========================================================================

  group('ExpressionPolicySection', () {
    test('creation stores all fields', () {
      final policies = [
        makePolicy(id: 'p1', name: 'Policy 1', priority: 10),
        makePolicy(id: 'p2', name: 'Policy 2', priority: 20),
      ];
      final globalOverrides = makeStyle(formality: Formality.formal);

      final section = ExpressionPolicySection(
        policies: policies,
        defaultPolicy: 'p1',
        globalOverrides: globalOverrides,
      );

      expect(section.policies.length, equals(2));
      expect(section.defaultPolicy, equals('p1'));
      expect(section.globalOverrides, isNotNull);
    });

    test('getPolicy returns policy when found', () {
      final section = ExpressionPolicySection(
        policies: [
          makePolicy(id: 'alpha', name: 'Alpha'),
          makePolicy(id: 'beta', name: 'Beta'),
        ],
      );

      final found = section.getPolicy('beta');

      expect(found, isNotNull);
      expect(found!.id, equals('beta'));
      expect(found.name, equals('Beta'));
    });

    test('getPolicy returns null when not found', () {
      final section = ExpressionPolicySection(
        policies: [
          makePolicy(id: 'alpha', name: 'Alpha'),
        ],
      );

      final result = section.getPolicy('nonexistent');

      expect(result, isNull);
    });

    test('sortedPolicies returns policies sorted by priority descending', () {
      final section = ExpressionPolicySection(
        policies: [
          makePolicy(id: 'low', priority: 10),
          makePolicy(id: 'high', priority: 100),
          makePolicy(id: 'mid', priority: 50),
        ],
      );

      final sorted = section.sortedPolicies;

      expect(sorted.length, equals(3));
      expect(sorted[0].id, equals('high'));
      expect(sorted[1].id, equals('mid'));
      expect(sorted[2].id, equals('low'));
    });

    test('sortedPolicies does not mutate original list', () {
      final section = ExpressionPolicySection(
        policies: [
          makePolicy(id: 'low', priority: 10),
          makePolicy(id: 'high', priority: 100),
        ],
      );

      section.sortedPolicies;

      expect(section.policies[0].id, equals('low'));
      expect(section.policies[1].id, equals('high'));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'policies': [
          {
            'id': 'p1',
            'name': 'Policy One',
            'condition': {
              'type': 'threshold',
              'metric': 'risk',
              'operator': '>',
              'value': 0.0,
            },
            'style': {
              'tone': {
                'formality': 'neutral',
                'confidence': 'moderate',
                'empathy': 'moderate',
                'directness': 'balanced',
              },
              'format': {
                'structure': 'prose',
                'length': 'standard',
                'includeEvidence': false,
                'includeCaveats': false,
                'includeAlternatives': false,
              },
            },
            'priority': 10,
          },
        ],
        'defaultPolicy': 'p1',
      };

      final section = ExpressionPolicySection.fromJson(json);

      expect(section.policies.length, equals(1));
      expect(section.policies[0].id, equals('p1'));
      expect(section.defaultPolicy, equals('p1'));
      expect(section.globalOverrides, isNull);
    });

    test('toJson produces correct map', () {
      final section = ExpressionPolicySection(
        policies: [
          makePolicy(id: 'p1', priority: 5),
        ],
        defaultPolicy: 'p1',
      );

      final json = section.toJson();

      expect(json['policies'], isA<List>());
      expect((json['policies'] as List).length, equals(1));
      expect(json['defaultPolicy'], equals('p1'));
      expect(json.containsKey('globalOverrides'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final section = ExpressionPolicySection(
        policies: [
          makePolicy(id: 'r1', name: 'Roundtrip', priority: 42),
          makePolicy(id: 'r2', name: 'Roundtrip 2', priority: 7),
        ],
        defaultPolicy: 'r1',
      );

      final restored = ExpressionPolicySection.fromJson(section.toJson());

      expect(restored.policies.length, equals(2));
      expect(restored.policies[0].id, equals('r1'));
      expect(restored.policies[0].priority, equals(42));
      expect(restored.policies[1].id, equals('r2'));
      expect(restored.defaultPolicy, equals('r1'));
    });
  });

  // ===========================================================================
  // ExpressionPolicy Tests
  // ===========================================================================

  group('ExpressionPolicy', () {
    test('creation with required fields and defaults', () {
      final policy = makePolicy(id: 'test', name: 'Test');

      expect(policy.id, equals('test'));
      expect(policy.name, equals('Test'));
      expect(policy.condition, isA<PolicyCondition>());
      expect(policy.style, isNotNull);
      expect(policy.description, isNull);
      expect(policy.priority, equals(0));
      expect(policy.enabled, isTrue);
      expect(policy.tags, isEmpty);
    });

    test('creation with all fields', () {
      final policy = makePolicy(
        id: 'full',
        name: 'Full Policy',
        description: 'A complete policy',
        priority: 99,
        enabled: false,
        tags: ['urgent', 'critical'],
      );

      expect(policy.id, equals('full'));
      expect(policy.name, equals('Full Policy'));
      expect(policy.description, equals('A complete policy'));
      expect(policy.priority, equals(99));
      expect(policy.enabled, isFalse);
      expect(policy.tags, equals(['urgent', 'critical']));
    });

    test('implements Policy interface', () {
      final policy = makePolicy(id: 'iface', priority: 42);

      expect(policy, isA<Policy>());

      final Policy asPolicy = policy;
      expect(asPolicy.id, equals('iface'));
      expect(asPolicy.priority, equals(42));
      expect(asPolicy.condition, isA<PolicyCondition>());
    });

    test('matches returns true when enabled and condition evaluates to true', () {
      final policy = ExpressionPolicy(
        id: 'match-test',
        name: 'Match Test',
        condition: const ThresholdCondition(
          metric: 'uncertainty',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: makeStyle(),
      );

      final result = policy.matches({'uncertainty': 0.8}, 0.0);

      expect(result, isTrue);
    });

    test('matches returns false when condition does not evaluate to true', () {
      final policy = ExpressionPolicy(
        id: 'no-match',
        name: 'No Match',
        condition: const ThresholdCondition(
          metric: 'uncertainty',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
        style: makeStyle(),
      );

      final result = policy.matches({'uncertainty': 0.3}, 0.0);

      expect(result, isFalse);
    });

    test('matches returns false when disabled regardless of condition', () {
      final policy = ExpressionPolicy(
        id: 'disabled',
        name: 'Disabled',
        condition: const AlwaysTrueCondition(),
        style: makeStyle(),
        enabled: false,
      );

      final result = policy.matches({'uncertainty': 1.0}, 1.0);

      expect(result, isFalse);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'id': 'json-policy',
        'name': 'JSON Policy',
        'condition': {
          'type': 'threshold',
          'metric': 'risk',
          'operator': '>',
          'value': 0.6,
        },
        'style': {
          'tone': {
            'formality': 'formal',
            'confidence': 'moderate',
            'empathy': 'moderate',
            'directness': 'balanced',
          },
          'format': {
            'structure': 'prose',
            'length': 'standard',
            'includeEvidence': false,
            'includeCaveats': false,
            'includeAlternatives': false,
          },
        },
        'description': 'From JSON',
        'priority': 80,
        'enabled': true,
        'tags': ['risk', 'formal'],
      };

      final policy = ExpressionPolicy.fromJson(json);

      expect(policy.id, equals('json-policy'));
      expect(policy.name, equals('JSON Policy'));
      expect(policy.description, equals('From JSON'));
      expect(policy.priority, equals(80));
      expect(policy.enabled, isTrue);
      expect(policy.tags, equals(['risk', 'formal']));
      expect(policy.condition, isA<ThresholdCondition>());
    });

    test('toJson produces correct map', () {
      final policy = makePolicy(
        id: 'to-json',
        name: 'To JSON',
        description: 'Test',
        priority: 50,
        tags: ['tag1'],
      );

      final json = policy.toJson();

      expect(json['id'], equals('to-json'));
      expect(json['name'], equals('To JSON'));
      expect(json['description'], equals('Test'));
      expect(json['priority'], equals(50));
      expect(json['tags'], equals(['tag1']));
      expect(json.containsKey('condition'), isTrue);
      expect(json.containsKey('style'), isTrue);
    });

    test('toJson omits enabled when true', () {
      final policy = makePolicy(enabled: true);

      final json = policy.toJson();

      expect(json.containsKey('enabled'), isFalse);
    });

    test('toJson includes enabled when false', () {
      final policy = makePolicy(enabled: false);

      final json = policy.toJson();

      expect(json['enabled'], isFalse);
    });

    test('toJson omits tags when empty', () {
      final policy = makePolicy(tags: []);

      final json = policy.toJson();

      expect(json.containsKey('tags'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = ExpressionPolicy(
        id: 'roundtrip',
        name: 'Roundtrip',
        condition: const ThresholdCondition(
          metric: 'urgency',
          operator: ComparisonOperator.greaterThan,
          value: 0.9,
        ),
        style: makeStyle(formality: Formality.formal),
        description: 'Roundtrip test',
        priority: 75,
        tags: ['a', 'b'],
      );

      final restored = ExpressionPolicy.fromJson(original.toJson());

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
      expect(restored.priority, equals(original.priority));
      expect(restored.enabled, equals(original.enabled));
      expect(restored.tags, equals(original.tags));
      expect(restored.style.tone.formality,
          equals(original.style.tone.formality));
    });
  });

  // ===========================================================================
  // ExpressionResult Tests
  // ===========================================================================

  group('ExpressionResult', () {
    test('creation stores all fields', () {
      final style = makeStyle();
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 1, 15),
        hedgingApplied: true,
      );

      final result = ExpressionResult(
        profileId: 'profile-1',
        policyId: 'policy-1',
        appraisalId: 'appraisal-1',
        style: style,
        formattedContent: 'Hello, world.',
        metadata: metadata,
      );

      expect(result.profileId, equals('profile-1'));
      expect(result.policyId, equals('policy-1'));
      expect(result.appraisalId, equals('appraisal-1'));
      expect(result.style, isNotNull);
      expect(result.formattedContent, equals('Hello, world.'));
      expect(result.metadata, isNotNull);
    });

    test('creation without formattedContent', () {
      final result = ExpressionResult(
        profileId: 'p',
        policyId: 'q',
        appraisalId: 'a',
        style: makeStyle(),
        metadata: ExpressionResultMetadata(
          evaluatedAt: DateTime(2025, 6, 1),
          hedgingApplied: false,
        ),
      );

      expect(result.formattedContent, isNull);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'profileId': 'prof-1',
        'policyId': 'pol-1',
        'appraisalId': 'apr-1',
        'style': {
          'tone': {
            'formality': 'neutral',
            'confidence': 'moderate',
            'empathy': 'moderate',
            'directness': 'balanced',
          },
          'format': {
            'structure': 'prose',
            'length': 'standard',
            'includeEvidence': false,
            'includeCaveats': false,
            'includeAlternatives': false,
          },
        },
        'formattedContent': 'Test content',
        'metadata': {
          'evaluatedAt': '2025-01-15T00:00:00.000',
          'hedgingApplied': true,
        },
      };

      final result = ExpressionResult.fromJson(json);

      expect(result.profileId, equals('prof-1'));
      expect(result.policyId, equals('pol-1'));
      expect(result.appraisalId, equals('apr-1'));
      expect(result.formattedContent, equals('Test content'));
      expect(result.metadata.hasHedging, isTrue);
    });

    test('toJson produces correct map', () {
      final result = ExpressionResult(
        profileId: 'p1',
        policyId: 'q1',
        appraisalId: 'a1',
        style: makeStyle(),
        formattedContent: 'Output text',
        metadata: ExpressionResultMetadata(
          evaluatedAt: DateTime(2025, 3, 10),
          hedgingApplied: false,
          audienceAdaptation: 'novice',
        ),
      );

      final json = result.toJson();

      expect(json['profileId'], equals('p1'));
      expect(json['policyId'], equals('q1'));
      expect(json['appraisalId'], equals('a1'));
      expect(json['formattedContent'], equals('Output text'));
      expect(json.containsKey('style'), isTrue);
      expect(json.containsKey('metadata'), isTrue);
    });

    test('toJson omits formattedContent when null', () {
      final result = ExpressionResult(
        profileId: 'p',
        policyId: 'q',
        appraisalId: 'a',
        style: makeStyle(),
        metadata: ExpressionResultMetadata(
          evaluatedAt: DateTime(2025, 1, 1),
          hedgingApplied: false,
        ),
      );

      final json = result.toJson();

      expect(json.containsKey('formattedContent'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = ExpressionResult(
        profileId: 'prof-rt',
        policyId: 'pol-rt',
        appraisalId: 'apr-rt',
        style: makeStyle(formality: Formality.formal),
        formattedContent: 'Roundtrip content',
        metadata: ExpressionResultMetadata(
          evaluatedAt: DateTime(2025, 6, 15, 10, 30),
          hedgingApplied: true,
          audienceAdaptation: 'expert',
        ),
      );

      final restored = ExpressionResult.fromJson(original.toJson());

      expect(restored.profileId, equals(original.profileId));
      expect(restored.policyId, equals(original.policyId));
      expect(restored.appraisalId, equals(original.appraisalId));
      expect(restored.formattedContent, equals(original.formattedContent));
      expect(restored.style.tone.formality,
          equals(original.style.tone.formality));
      expect(restored.metadata.audienceAdaptation,
          equals(original.metadata.audienceAdaptation));
    });
  });

  // ===========================================================================
  // ExpressionResultMetadata Tests
  // ===========================================================================

  group('ExpressionResultMetadata', () {
    test('creation with bool hedgingApplied', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 5, 20),
        hedgingApplied: true,
        audienceAdaptation: 'expert',
      );

      expect(metadata.evaluatedAt, equals(DateTime(2025, 5, 20)));
      expect(metadata.hedgingApplied, equals(true));
      expect(metadata.audienceAdaptation, equals('expert'));
    });

    test('creation with List hedgingApplied', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 5, 20),
        hedgingApplied: ['It seems that...', 'however'],
      );

      expect(metadata.hedgingApplied, isA<List>());
      expect(metadata.audienceAdaptation, isNull);
    });

    test('hasHedging returns true when hedgingApplied is true', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 1, 1),
        hedgingApplied: true,
      );

      expect(metadata.hasHedging, isTrue);
    });

    test('hasHedging returns false when hedgingApplied is false', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 1, 1),
        hedgingApplied: false,
      );

      expect(metadata.hasHedging, isFalse);
    });

    test('hasHedging returns true when hedgingApplied is non-empty list', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 1, 1),
        hedgingApplied: ['phrase1'],
      );

      expect(metadata.hasHedging, isTrue);
    });

    test('hasHedging returns false when hedgingApplied is empty list', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 1, 1),
        hedgingApplied: <String>[],
      );

      expect(metadata.hasHedging, isFalse);
    });

    test('hedgingPhrases returns list when hedgingApplied is List', () {
      final phrases = ['It seems that...', 'however'];
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 1, 1),
        hedgingApplied: phrases,
      );

      expect(metadata.hedgingPhrases, equals(phrases));
    });

    test('hedgingPhrases returns empty list when hedgingApplied is bool', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 1, 1),
        hedgingApplied: true,
      );

      expect(metadata.hedgingPhrases, isEmpty);
    });

    test('fromJson with bool hedgingApplied', () {
      final json = {
        'evaluatedAt': '2025-03-15T12:00:00.000',
        'hedgingApplied': true,
        'audienceAdaptation': 'intermediate',
      };

      final metadata = ExpressionResultMetadata.fromJson(json);

      expect(metadata.hedgingApplied, equals(true));
      expect(metadata.hasHedging, isTrue);
      expect(metadata.audienceAdaptation, equals('intermediate'));
    });

    test('fromJson with List hedgingApplied', () {
      final json = {
        'evaluatedAt': '2025-03-15T12:00:00.000',
        'hedgingApplied': ['phrase a', 'phrase b'],
      };

      final metadata = ExpressionResultMetadata.fromJson(json);

      expect(metadata.hedgingApplied, isA<List>());
      expect(metadata.hedgingPhrases, equals(['phrase a', 'phrase b']));
      expect(metadata.hasHedging, isTrue);
    });

    test('fromJson with null hedgingApplied defaults to false', () {
      final json = {
        'evaluatedAt': '2025-06-01T00:00:00.000',
      };

      final metadata = ExpressionResultMetadata.fromJson(json);

      expect(metadata.hedgingApplied, equals(false));
      expect(metadata.hasHedging, isFalse);
    });

    test('toJson produces correct map with bool hedging', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 4, 1),
        hedgingApplied: true,
        audienceAdaptation: 'novice',
      );

      final json = metadata.toJson();

      expect(json['hedgingApplied'], equals(true));
      expect(json['audienceAdaptation'], equals('novice'));
      expect(json.containsKey('evaluatedAt'), isTrue);
    });

    test('toJson produces correct map with list hedging', () {
      final metadata = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 4, 1),
        hedgingApplied: ['x', 'y'],
      );

      final json = metadata.toJson();

      expect(json['hedgingApplied'], equals(['x', 'y']));
      expect(json.containsKey('audienceAdaptation'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves bool hedging', () {
      final original = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 7, 10, 14, 30),
        hedgingApplied: true,
        audienceAdaptation: 'expert',
      );

      final restored =
          ExpressionResultMetadata.fromJson(original.toJson());

      expect(restored.hedgingApplied, equals(true));
      expect(restored.hasHedging, isTrue);
      expect(restored.audienceAdaptation, equals('expert'));
    });

    test('fromJson/toJson roundtrip preserves list hedging', () {
      final original = ExpressionResultMetadata(
        evaluatedAt: DateTime(2025, 7, 10, 14, 30),
        hedgingApplied: ['alpha', 'beta'],
      );

      final restored =
          ExpressionResultMetadata.fromJson(original.toJson());

      expect(restored.hedgingPhrases, equals(['alpha', 'beta']));
      expect(restored.hasHedging, isTrue);
    });
  });

  // ===========================================================================
  // StandardExpressionPolicies Tests
  // ===========================================================================

  group('StandardExpressionPolicies', () {
    test('highUncertaintyTentative creates correct policy', () {
      final policy = StandardExpressionPolicies.highUncertaintyTentative();

      expect(policy.id, equals('high_uncertainty_tentative'));
      expect(policy.name, equals('Highly Tentative'));
      expect(policy.priority, equals(90));
      expect(policy.enabled, isTrue);
      expect(policy.condition, isA<ThresholdCondition>());
      expect(policy.style.tone.confidence, equals(ToneConfidence.tentative));
      expect(policy.style.hedging, isNotNull);
      expect(
          policy.style.hedging!.level, equals(HedgingLevel.strong));
    });

    test('moderateUncertaintyBalanced creates correct policy', () {
      final policy =
          StandardExpressionPolicies.moderateUncertaintyBalanced();

      expect(policy.id, equals('moderate_uncertainty_balanced'));
      expect(policy.name, equals('Balanced with Caveats'));
      expect(policy.priority, equals(50));
      expect(policy.condition, isA<ThresholdCondition>());
      expect(policy.style.tone.confidence, equals(ToneConfidence.moderate));
      expect(policy.style.hedging, isNotNull);
      expect(policy.style.hedging!.level, equals(HedgingLevel.moderate));
    });

    test('urgentConcise creates correct policy', () {
      final policy = StandardExpressionPolicies.urgentConcise();

      expect(policy.id, equals('urgent_concise'));
      expect(policy.name, equals('Urgent Concise'));
      expect(policy.priority, equals(100));
      expect(policy.condition, isA<ThresholdCondition>());
      expect(policy.style.tone.confidence, equals(ToneConfidence.assertive));
      expect(policy.style.tone.directness, equals(Directness.direct));
      expect(policy.style.format.structure, equals(Structure.bullets));
      expect(policy.style.format.length, equals(Length.concise));
      expect(policy.style.format.maxBullets, equals(5));
      expect(policy.style.hedging, isNotNull);
      expect(policy.style.hedging!.level, equals(HedgingLevel.none));
    });

    test('highRiskFormal creates correct policy', () {
      final policy = StandardExpressionPolicies.highRiskFormal();

      expect(policy.id, equals('high_risk_formal'));
      expect(policy.name, equals('Formal Risk Communication'));
      expect(policy.priority, equals(80));
      expect(policy.condition, isA<ThresholdCondition>());
      expect(policy.style.tone.formality, equals(Formality.formal));
      expect(policy.style.format.structure, equals(Structure.numbered));
      expect(policy.style.format.length, equals(Length.detailed));
      expect(policy.style.audience, isNotNull);
      expect(policy.style.audience!.expertise,
          equals(Expertise.intermediate));
    });

    test('lowTrustQualified creates correct policy', () {
      final policy = StandardExpressionPolicies.lowTrustQualified();

      expect(policy.id, equals('low_trust_qualified'));
      expect(policy.name, equals('Qualified with Sources'));
      expect(policy.priority, equals(70));
      expect(policy.condition, isA<ThresholdCondition>());
      expect(policy.style.tone.confidence, equals(ToneConfidence.tentative));
      expect(policy.style.hedging, isNotNull);
      expect(policy.style.hedging!.level, equals(HedgingLevel.moderate));
      expect(policy.style.hedging!.phrases, isNotNull);
      expect(policy.style.hedging!.phrases!.qualifying, isNotNull);
      expect(policy.style.hedging!.phrases!.qualifying!, isNotEmpty);
    });

    test('all returns 5 policies', () {
      final policies = StandardExpressionPolicies.all();

      expect(policies.length, equals(5));
    });

    test('all contains all standard policy IDs', () {
      final policies = StandardExpressionPolicies.all();
      final ids = policies.map((p) => p.id).toList();

      expect(ids, contains('high_uncertainty_tentative'));
      expect(ids, contains('moderate_uncertainty_balanced'));
      expect(ids, contains('urgent_concise'));
      expect(ids, contains('high_risk_formal'));
      expect(ids, contains('low_trust_qualified'));
    });

    test('highUncertaintyTentative accepts custom priority', () {
      final policy =
          StandardExpressionPolicies.highUncertaintyTentative(priority: 42);

      expect(policy.priority, equals(42));
    });

    test('urgentConcise accepts custom priority', () {
      final policy =
          StandardExpressionPolicies.urgentConcise(priority: 200);

      expect(policy.priority, equals(200));
    });
  });

  // ===========================================================================
  // Coverage: expression_policy.dart lines 53-54
  //   (ExpressionPolicySection.fromJson with globalOverrides)
  // ===========================================================================

  group('ExpressionPolicySection.fromJson with globalOverrides', () {
    test('parses globalOverrides when present', () {
      // Covers lines 53-54: ExpressionStyle.fromJson(json['globalOverrides']...)
      final json = {
        'policies': [
          {
            'id': 'p1',
            'name': 'Policy One',
            'condition': {
              'type': 'threshold',
              'metric': 'risk',
              'operator': '>',
              'value': 0.0,
            },
            'style': {
              'tone': {
                'formality': 'neutral',
                'confidence': 'moderate',
                'empathy': 'moderate',
                'directness': 'balanced',
              },
              'format': {
                'structure': 'prose',
                'length': 'standard',
                'includeEvidence': false,
                'includeCaveats': false,
                'includeAlternatives': false,
              },
            },
            'priority': 10,
          },
        ],
        'defaultPolicy': 'p1',
        'globalOverrides': {
          'tone': {
            'formality': 'formal',
            'confidence': 'assertive',
            'empathy': 'high',
            'directness': 'direct',
          },
          'format': {
            'structure': 'bullets',
            'length': 'concise',
            'includeEvidence': true,
            'includeCaveats': true,
            'includeAlternatives': false,
          },
        },
      };

      final section = ExpressionPolicySection.fromJson(json);

      expect(section.globalOverrides, isNotNull);
      expect(section.globalOverrides!.tone.formality, equals(Formality.formal));
      expect(
          section.globalOverrides!.tone.confidence, equals(ToneConfidence.assertive));
      expect(
          section.globalOverrides!.format.structure, equals(Structure.bullets));
      expect(section.globalOverrides!.format.length, equals(Length.concise));
    });

    test('toJson includes globalOverrides when present', () {
      final section = ExpressionPolicySection(
        policies: [
          makePolicy(id: 'p1', priority: 5),
        ],
        globalOverrides: makeStyle(formality: Formality.formal),
      );

      final json = section.toJson();

      expect(json.containsKey('globalOverrides'), isTrue);
      final overrides = json['globalOverrides'] as Map<String, dynamic>;
      final tone = overrides['tone'] as Map<String, dynamic>;
      expect(tone['formality'], equals('formal'));
    });
  });
}
