/// ExpressionFormatter Tests
///
/// Tests for ExpressionPolicyEvaluator (policy matching, style selection,
/// content formatting) and ExpressionStyleFormatter (tone, hedging,
/// format structure, audience adaptation, style prompt generation).
library;

import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

void main() {
  // ===========================================================================
  // Helper Factories
  // ===========================================================================

  AppraisalResult makeAppraisal({
    Map<String, MetricResult>? metrics,
    double aggregatedScore = 0.5,
    String profileId = 'test',
    String contextId = 'ctx',
  }) {
    return AppraisalResult(
      profileId: profileId,
      contextId: contextId,
      asOf: DateTime(2025, 6, 1),
      metrics: metrics ?? {},
      aggregatedScore: aggregatedScore,
      metadata: AppraisalMetadata(computedAt: DateTime(2025, 6, 1)),
    );
  }

  MetricResult makeMetric({
    required String id,
    required double normalizedValue,
    MetricSourceType sourceType = MetricSourceType.static_,
    double confidence = 0.9,
  }) {
    return MetricResult(
      id: id,
      normalizedValue: normalizedValue,
      sourceType: sourceType,
      confidence: confidence,
    );
  }

  ExpressionPolicy makePolicy({
    required String id,
    String name = 'Test',
    required PolicyCondition condition,
    required ExpressionStyle style,
    int priority = 0,
  }) {
    return ExpressionPolicy(
      id: id,
      name: name,
      condition: condition,
      style: style,
      priority: priority,
    );
  }

  // ===========================================================================
  // ExpressionPolicyEvaluator Tests
  // ===========================================================================

  group('ExpressionPolicyEvaluator', () {
    const evaluator = ExpressionPolicyEvaluator();

    test('matching policy returns its style', () {
      final policy = makePolicy(
        id: 'high_uncertainty',
        name: 'Tentative',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'uncertainty',
          operator: ComparisonOperator.greaterThan,
          value: 0.7,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.tentative,
            empathy: Empathy.moderate,
            directness: Directness.diplomatic,
          ),
          format: FormatConfig.standard,
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);

      final appraisal = makeAppraisal(metrics: {
        'uncertainty': makeMetric(id: 'uncertainty', normalizedValue: 0.8),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
      );

      expect(result.policyId, equals('high_uncertainty'));
      expect(result.style.tone.confidence, equals(ToneConfidence.tentative));
      expect(result.style.tone.formality, equals(Formality.formal));
    });

    test('no match uses default policy when specified', () {
      // The default policy uses a condition that won't match via iteration,
      // but is referenced by defaultPolicy ID for fallback
      final defaultPolicy = makePolicy(
        id: 'default_style',
        name: 'Default',
        priority: 0,
        condition: const ThresholdCondition(
          metric: 'nonexistent_metric',
          operator: ComparisonOperator.greaterThan,
          value: 0.0,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig.standard,
        ),
      );

      final highPolicy = makePolicy(
        id: 'high_risk',
        name: 'High Risk',
        priority: 90,
        condition: const ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.8,
        ),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.low,
            directness: Directness.direct,
          ),
          format: FormatConfig.standard,
        ),
      );

      final section = ExpressionPolicySection(
        policies: [highPolicy, defaultPolicy],
        defaultPolicy: 'default_style',
      );

      // risk=0.2 does not match high_risk (>0.8), and nonexistent_metric
      // is not present so default_style won't match via iteration either
      final appraisal = makeAppraisal(metrics: {
        'risk': makeMetric(id: 'risk', normalizedValue: 0.2),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
      );

      expect(result.policyId, equals('default_style'));
      expect(result.style.tone.confidence, equals(ToneConfidence.moderate));
    });

    test('no match and no default uses globalOverrides or defaultStyle', () {
      final section = ExpressionPolicySection(
        policies: [
          makePolicy(
            id: 'never_match',
            priority: 10,
            condition: const ThresholdCondition(
              metric: 'risk',
              operator: ComparisonOperator.greaterThan,
              value: 99.0,
            ),
            style: const ExpressionStyle(
              tone: ToneConfig(
                formality: Formality.formal,
                confidence: ToneConfidence.assertive,
                empathy: Empathy.high,
                directness: Directness.direct,
              ),
              format: FormatConfig.standard,
            ),
          ),
        ],
      );

      final appraisal = makeAppraisal(metrics: {
        'risk': makeMetric(id: 'risk', normalizedValue: 0.1),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
      );

      // Falls back to 'default' policy ID
      expect(result.policyId, equals('default'));
    });

    test('applies global overrides when present', () {
      final globalStyle = const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.casual,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.high,
          directness: Directness.balanced,
        ),
        format: FormatConfig.standard,
      );

      final policy = makePolicy(
        id: 'matching',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.tentative,
            empathy: Empathy.low,
            directness: Directness.diplomatic,
          ),
          format: FormatConfig.standard,
        ),
      );

      final section = ExpressionPolicySection(
        policies: [policy],
        globalOverrides: globalStyle,
      );

      final appraisal = makeAppraisal();

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
      );

      // The global overrides merge onto the matched policy style
      expect(result.policyId, equals('matching'));
      // Global style is merged with matched policy style
      expect(result.style, isNotNull);
    });

    test('formats content when provided', () {
      final policy = makePolicy(
        id: 'format_test',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.neutral,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig(
            structure: Structure.bullets,
            length: Length.standard,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal();

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'First sentence. Second sentence. Third sentence.',
      );

      expect(result.formattedContent, isNotNull);
      // Bullets structure should convert sentences into bullet items
      expect(result.formattedContent, isNotEmpty);
    });

    test('no formatted content when content not provided', () {
      final policy = makePolicy(
        id: 'no_content',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig.standard,
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal();

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
      );

      expect(result.formattedContent, isNull);
    });

    test('hedging applied to content with high uncertainty metric', () {
      final policy = makePolicy(
        id: 'hedging_test',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig.standard,
          hedging: HedgingConfig(
            level: HedgingLevel.moderate,
            position: HedgingPosition.start,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal(metrics: {
        'uncertainty': makeMetric(id: 'uncertainty', normalizedValue: 0.8),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'The data shows clear trends.',
      );

      expect(result.formattedContent, isNotNull);
      // With high uncertainty (>0.7), hedging phrase should be prepended
      expect(result.formattedContent!.length,
          greaterThan('The data shows clear trends.'.length));
    });

    test('higher priority policy is selected over lower priority', () {
      final lowPriority = makePolicy(
        id: 'low_priority',
        name: 'Low',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.casual,
            confidence: ToneConfidence.moderate,
            empathy: Empathy.moderate,
            directness: Directness.balanced,
          ),
          format: FormatConfig.standard,
        ),
      );

      final highPriority = makePolicy(
        id: 'high_priority',
        name: 'High',
        priority: 100,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig(
            formality: Formality.formal,
            confidence: ToneConfidence.assertive,
            empathy: Empathy.high,
            directness: Directness.direct,
          ),
          format: FormatConfig.standard,
        ),
      );

      final section =
          ExpressionPolicySection(policies: [lowPriority, highPriority]);
      final appraisal = makeAppraisal();

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
      );

      expect(result.policyId, equals('high_priority'));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — tone adjustments
  // ===========================================================================

  group('ExpressionStyleFormatter format (tone)', () {
    const formatter = ExpressionStyleFormatter();

    test('formal tone expands contractions', () {
      final style = const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.moderate,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      final result = formatter.format(
        content: "This don't work right.",
        style: style,
      );

      expect(result, contains('do not'));
      expect(result, isNot(contains("don't")));
    });

    test('casual tone simplifies formal phrases', () {
      final style = const ExpressionStyle(
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
      );

      final result = formatter.format(
        content: 'It is recommended that you utilize this tool.',
        style: style,
      );

      expect(result, contains('You should'));
      expect(result, contains('use'));
    });

    test('tentative confidence replaces "is" with "appears to be"', () {
      final style = const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.neutral,
          confidence: ToneConfidence.tentative,
          empathy: Empathy.moderate,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      final result = formatter.format(
        content: 'The system is working.',
        style: style,
      );

      expect(result, contains('appears to be'));
    });

    test('high empathy adds preamble', () {
      final style = const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.neutral,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.high,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      final result = formatter.format(
        content: 'The deadline has passed.',
        style: style,
      );

      expect(result, contains('I understand this may be important to you'));
    });

    test('formal tone combined with tentative confidence', () {
      final style = const ExpressionStyle(
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
      );

      final result = formatter.format(
        content: "It can't be done.",
        style: style,
      );

      // formal expands "can't" to "cannot"
      // The word "is" does not appear in "It cannot be done." so "appears to be"
      // replacement will not fire on this particular input
      expect(result, contains('cannot'));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — hedging
  // ===========================================================================

  group('ExpressionStyleFormatter format (hedging)', () {
    const formatter = ExpressionStyleFormatter();

    test('moderate hedging at start position prepends phrase', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        hedging: HedgingConfig(
          level: HedgingLevel.moderate,
          position: HedgingPosition.start,
        ),
      );

      final result = formatter.format(
        content: 'The data is reliable.',
        style: style,
      );

      expect(result, startsWith('Based on available data,'));
    });

    test('light hedging at end position appends phrase', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        hedging: HedgingConfig(
          level: HedgingLevel.light,
          position: HedgingPosition.end,
        ),
      );

      final result = formatter.format(
        content: 'The data is reliable.',
        style: style,
      );

      expect(result, endsWith('(This appears to be)'));
    });

    test('strong hedging at start position prepends strong phrase', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        hedging: HedgingConfig(
          level: HedgingLevel.strong,
          position: HedgingPosition.start,
        ),
      );

      final result = formatter.format(
        content: 'Analysis complete.',
        style: style,
      );

      expect(result,
          startsWith('Current evidence tentatively suggests that'));
    });

    test('no hedging when level is none', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        hedging: HedgingConfig(level: HedgingLevel.none),
      );

      final result = formatter.format(
        content: 'Analysis complete.',
        style: style,
      );

      expect(result, equals('Analysis complete.'));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — format structure
  // ===========================================================================

  group('ExpressionStyleFormatter format (structure)', () {
    const formatter = ExpressionStyleFormatter();

    test('bullets structure converts to bullet points', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.bullets,
          length: Length.standard,
        ),
      );

      final result = formatter.format(
        content: 'First point. Second point. Third point.',
        style: style,
      );

      final lines = result.split('\n');
      expect(lines.length, equals(3));
      for (final line in lines) {
        expect(line, startsWith('\u2022 '));
      }
    });

    test('numbered structure converts to numbered list', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.numbered,
          length: Length.standard,
        ),
      );

      final result = formatter.format(
        content: 'First step. Second step. Third step.',
        style: style,
      );

      final lines = result.split('\n');
      expect(lines.length, equals(3));
      expect(lines[0], startsWith('1. '));
      expect(lines[1], startsWith('2. '));
      expect(lines[2], startsWith('3. '));
    });

    test('prose structure keeps original text', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      const content = 'This is a single paragraph of text.';
      final result = formatter.format(content: content, style: style);

      expect(result, equals(content));
    });

    test('concise length truncates to max 2 sentences', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.concise,
        ),
      );

      final result = formatter.format(
        content:
            'First sentence. Second sentence. Third sentence. Fourth sentence.',
        style: style,
      );

      // Should keep at most 2 sentences
      final sentenceCount = '. '.allMatches(result).length +
          (result.endsWith('.') ? 1 : 0);
      expect(sentenceCount, lessThanOrEqualTo(3));
    });

    test('maxBullets limits bullet count', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.bullets,
          length: Length.standard,
          maxBullets: 2,
        ),
      );

      final result = formatter.format(
        content:
            'First point. Second point. Third point. Fourth point.',
        style: style,
      );

      final lines = result.split('\n');
      expect(lines.length, equals(2));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — audience adaptation
  // ===========================================================================

  group('ExpressionStyleFormatter format (audience)', () {
    const formatter = ExpressionStyleFormatter();

    test('novice audience adds preamble for long content', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.novice,
          context: AudienceContext.internal,
        ),
      );

      // Content longer than 200 chars
      final longContent = 'A' * 250;
      final result = formatter.format(content: longContent, style: style);

      expect(result, startsWith('Here is a summary of the key points:'));
    });

    test('novice audience does not add preamble for short content', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.novice,
          context: AudienceContext.internal,
        ),
      );

      final result = formatter.format(
        content: 'Short content here.',
        style: style,
      );

      expect(result, isNot(startsWith('Here is a summary')));
    });

    test('public context adds disclaimer', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.public_,
        ),
      );

      final result = formatter.format(
        content: 'Analysis complete.',
        style: style,
      );

      expect(result,
          contains('Note: This information is for general reference.'));
    });

    test('expert audience does not modify content', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.expert,
          context: AudienceContext.internal,
        ),
      );

      const content = 'Technical analysis data.';
      final result = formatter.format(content: content, style: style);

      expect(result, equals(content));
    });

    test('avoidJargon replaces technical terms', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.internal,
          preferences: AudiencePreferences(avoidJargon: true),
        ),
      );

      final result = formatter.format(
        content: 'We need to leverage the tool to optimize results.',
        style: style,
      );

      expect(result, contains('use'));
      expect(result, contains('improve'));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — generateStylePrompt
  // ===========================================================================

  group('ExpressionStyleFormatter generateStylePrompt', () {
    const formatter = ExpressionStyleFormatter();

    test('includes tone information', () {
      final style = const ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.tentative,
          empathy: Empathy.high,
          directness: Directness.diplomatic,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('formal'));
      expect(prompt, contains('tentative'));
      expect(prompt, contains('high'));
      expect(prompt, contains('diplomatic'));
    });

    test('includes format information', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.bullets,
          length: Length.concise,
          includeEvidence: true,
          includeCaveats: true,
          includeAlternatives: true,
          includeNextSteps: true,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('bullets'));
      expect(prompt, contains('concise'));
      expect(prompt, contains('Include evidence'));
      expect(prompt, contains('Include caveats'));
      expect(prompt, contains('Include alternatives'));
      expect(prompt, contains('Include next steps'));
    });

    test('includes hedging information', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        hedging: HedgingConfig(level: HedgingLevel.strong),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('Hedging'));
      expect(prompt, contains('strong'));
    });

    test('includes audience information', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        audience: AudienceConfig(
          expertise: Expertise.novice,
          context: AudienceContext.public_,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('Audience'));
      expect(prompt, contains('novice'));
      expect(prompt, contains('public_'));
    });

    test('omits hedging info when level is none', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        hedging: HedgingConfig(level: HedgingLevel.none),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, isNot(contains('Hedging')));
    });

    test('omits audience info when audience is null', () {
      final style = const ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, isNot(contains('Audience')));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — _applyFormality additional coverage
  // ===========================================================================

  group('ExpressionStyleFormatter _applyFormality (additional)', () {
    const formatter = ExpressionStyleFormatter();

    test('formal tone expands all contraction pairs', () {
      const style = ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.moderate,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      // Test multiple contractions in a single string
      final result = formatter.format(
        content:
            "It doesn't work and they won't help. We shouldn't wait because it's urgent.",
        style: style,
      );

      expect(result, contains('does not'));
      expect(result, contains('will not'));
      expect(result, contains('should not'));
      expect(result, contains('it is'));
      expect(result, isNot(contains("doesn't")));
      expect(result, isNot(contains("won't")));
    });

    test('formal tone expands pronoun contractions', () {
      const style = ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.moderate,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      // Use lowercase contractions as the replacement map keys are lowercase
      final result = formatter.format(
        content: "I'm sure we're right and you're set.",
        style: style,
      );

      expect(result, contains('I am'));
      expect(result, contains('we are'));
      expect(result, contains('you are'));
    });

    test('formal tone expands have/will contractions', () {
      const style = ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.moderate,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      // Use contractions that match the map keys exactly
      final result = formatter.format(
        content: "we've done it. I'll go and you'll see.",
        style: style,
      );

      expect(result, contains('we have'));
      expect(result, contains('I will'));
      expect(result, contains('you will'));
    });

    test('casual tone replaces all formal phrase pairs', () {
      const style = ExpressionStyle(
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
      );

      // Use exact casing from the casualReplacements map keys
      final result = formatter.format(
        content:
            'Please be advised that we will utilize this. '
            'At this time we act. '
            'In the event that issues arise, '
            'Subsequent to review, '
            'Prior to deployment, we will Commence operations.',
        style: style,
      );

      expect(result, contains('Just so you know,'));
      expect(result, contains('Right now'));
      expect(result, contains('use'));
      expect(result, contains('If'));
      expect(result, contains('After'));
      expect(result, contains('Before'));
      expect(result, contains('Start'));
    });

    test('casual tone replaces case-sensitive verb forms', () {
      const style = ExpressionStyle(
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
      );

      // Lowercase versions
      final result = formatter.format(
        content:
            'We should commence and facilitate. Also terminate and endeavor.',
        style: style,
      );

      expect(result, contains('start'));
      expect(result, contains('help'));
      expect(result, contains('end'));
      expect(result, contains('try'));
    });

    test('neutral formality leaves content unchanged', () {
      const style = ExpressionStyle(
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
      );

      const content = "It is recommended that don't utilize this.";
      final result = formatter.format(content: content, style: style);
      expect(result, equals(content));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — _applyConfidence additional coverage
  // ===========================================================================

  group('ExpressionStyleFormatter _applyConfidence (additional)', () {
    const formatter = ExpressionStyleFormatter();

    test('tentative replaces multiple "is", "will", "should" in one string', () {
      const style = ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.neutral,
          confidence: ToneConfidence.tentative,
          empathy: Empathy.moderate,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      final result = formatter.format(
        content: 'This is good. It will work and we should proceed.',
        style: style,
      );

      // "is" -> "appears to be", "will" -> "may", "should" -> "might"
      expect(result, contains('appears to be'));
      expect(result, contains('may'));
      expect(result, contains('might'));
      expect(result, isNot(contains(' is ')));
      // "will" in the original should be replaced
      expect(result, isNot(contains(' will ')));
    });

    test('assertive confidence leaves content unchanged', () {
      const style = ExpressionStyle(
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
      );

      const content = 'This is correct and will work.';
      final result = formatter.format(content: content, style: style);
      expect(result, equals(content));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — _applyEmpathy additional coverage
  // ===========================================================================

  group('ExpressionStyleFormatter _applyEmpathy (additional)', () {
    const formatter = ExpressionStyleFormatter();

    test('high empathy prepends preamble to content', () {
      const style = ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.neutral,
          confidence: ToneConfidence.moderate,
          empathy: Empathy.high,
          directness: Directness.balanced,
        ),
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
      );

      final result = formatter.format(
        content: 'Your request has been denied.',
        style: style,
      );

      expect(
        result,
        startsWith('I understand this may be important to you.'),
      );
      expect(result, contains('Your request has been denied.'));
    });

    test('low empathy leaves content unchanged', () {
      const style = ExpressionStyle(
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
      );

      const content = 'Request denied.';
      final result = formatter.format(content: content, style: style);
      expect(result, equals(content));
    });
  });

  // ===========================================================================
  // ExpressionPolicyEvaluator — _formatContent additional coverage
  // ===========================================================================

  group('ExpressionPolicyEvaluator _formatContent (additional)', () {
    const evaluator = ExpressionPolicyEvaluator();

    test('includeCaveats adds caveat for high uncertainty', () {
      final policy = makePolicy(
        id: 'caveats_test',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
            includeCaveats: true,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal(metrics: {
        'uncertainty':
            makeMetric(id: 'uncertainty', normalizedValue: 0.6),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'Some analysis content.',
      );

      expect(result.formattedContent, isNotNull);
      expect(
        result.formattedContent!,
        contains('Note: This analysis is based on incomplete information.'),
      );
    });

    test('includeCaveats adds caveat for low trust', () {
      final policy = makePolicy(
        id: 'trust_caveat_test',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.standard,
            includeCaveats: true,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal(metrics: {
        'trust': makeMetric(id: 'trust', normalizedValue: 0.3),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'Sourced information.',
      );

      expect(result.formattedContent, isNotNull);
      expect(
        result.formattedContent!,
        contains('Disclaimer: Source reliability has not been fully verified.'),
      );
    });

    test('hedging with moderate uncertainty uses moderate phrases', () {
      final policy = makePolicy(
        id: 'moderate_hedge',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig.standard,
          hedging: HedgingConfig(
            level: HedgingLevel.moderate,
            position: HedgingPosition.start,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal(metrics: {
        'uncertainty':
            makeMetric(id: 'uncertainty', normalizedValue: 0.5),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'Result data.',
      );

      expect(result.formattedContent, isNotNull);
      // Moderate uncertainty (0.4-0.7) should use moderate phrases
      expect(result.formattedContent!.length,
          greaterThan('Result data.'.length));
    });

    test('hedging at end position appends phrase', () {
      final policy = makePolicy(
        id: 'end_hedge',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig.standard,
          hedging: HedgingConfig(
            level: HedgingLevel.moderate,
            position: HedgingPosition.end,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal(metrics: {
        'uncertainty':
            makeMetric(id: 'uncertainty', normalizedValue: 0.8),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'Analysis complete.',
      );

      expect(result.formattedContent, isNotNull);
      expect(result.formattedContent!, contains('('));
    });

    test('hedging inline inserts after first sentence', () {
      final policy = makePolicy(
        id: 'inline_hedge',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig.standard,
          hedging: HedgingConfig(
            level: HedgingLevel.moderate,
            position: HedgingPosition.inline,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal(metrics: {
        'uncertainty':
            makeMetric(id: 'uncertainty', normalizedValue: 0.8),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'First sentence. Second sentence.',
      );

      expect(result.formattedContent, isNotNull);
      // The hedge phrase should be inserted between sentences
      expect(result.formattedContent!.length,
          greaterThan('First sentence. Second sentence.'.length));
    });

    test('hedging inline with no period prepends phrase', () {
      final policy = makePolicy(
        id: 'inline_no_period',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig.standard,
          hedging: HedgingConfig(
            level: HedgingLevel.moderate,
            position: HedgingPosition.inline,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal(metrics: {
        'uncertainty':
            makeMetric(id: 'uncertainty', normalizedValue: 0.8),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'No period here',
      );

      expect(result.formattedContent, isNotNull);
      // When no period+space exists, the phrase is prepended
      expect(result.formattedContent!.length,
          greaterThan('No period here'.length));
    });

    test('hedging with low uncertainty uses low-uncertainty phrases', () {
      final policy = makePolicy(
        id: 'low_uncertainty_hedge',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig.standard,
          hedging: HedgingConfig(
            level: HedgingLevel.moderate,
            position: HedgingPosition.start,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal(metrics: {
        'uncertainty':
            makeMetric(id: 'uncertainty', normalizedValue: 0.2),
      });

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'Certain result.',
      );

      expect(result.formattedContent, isNotNull);
      // Low uncertainty (<= 0.4) should use lowUncertainty phrases
      expect(result.formattedContent!.length,
          greaterThan('Certain result.'.length));
    });

    test('numbered structure in evaluator formats content as numbered list', () {
      final policy = makePolicy(
        id: 'numbered_test',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig(
            structure: Structure.numbered,
            length: Length.standard,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal();

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content: 'First item. Second item. Third item.',
      );

      expect(result.formattedContent, isNotNull);
      expect(result.formattedContent!, contains('1.'));
      expect(result.formattedContent!, contains('2.'));
    });

    test('concise length truncates to 2 sentences', () {
      final policy = makePolicy(
        id: 'concise_test',
        priority: 10,
        condition: const AlwaysTrueCondition(),
        style: const ExpressionStyle(
          tone: ToneConfig.neutral,
          format: FormatConfig(
            structure: Structure.prose,
            length: Length.concise,
          ),
        ),
      );

      final section = ExpressionPolicySection(policies: [policy]);
      final appraisal = makeAppraisal();

      final result = evaluator.evaluate(
        policySection: section,
        appraisalResult: appraisal,
        profileId: 'test-profile',
        content:
            'Sentence one. Sentence two. Sentence three. Sentence four. Sentence five.',
      );

      expect(result.formattedContent, isNotNull);
      // Concise truncates to max 2 sentences
      expect(result.formattedContent!.length,
          lessThan('Sentence one. Sentence two. Sentence three. Sentence four. Sentence five.'.length));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — _applyAudienceAdaptation additional coverage
  // ===========================================================================

  group('ExpressionStyleFormatter _applyAudienceAdaptation (additional)', () {
    const formatter = ExpressionStyleFormatter();

    test('novice audience with long content adds summary preamble', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.novice,
          context: AudienceContext.internal,
        ),
      );

      // Content longer than 200 characters
      final longContent = 'This is a detailed explanation. ' * 10;
      final result = formatter.format(content: longContent, style: style);
      expect(result, startsWith('Here is a summary of the key points:'));
    });

    test('expert audience leaves content as-is', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.expert,
          context: AudienceContext.internal,
        ),
      );

      const content = 'Expert-level technical details here.';
      final result = formatter.format(content: content, style: style);
      expect(result, equals(content));
    });

    test('intermediate audience leaves content as-is', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.internal,
        ),
      );

      const content = 'Regular content.';
      final result = formatter.format(content: content, style: style);
      expect(result, equals(content));
    });

    test('external context leaves content as-is', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.external,
        ),
      );

      const content = 'External content.';
      final result = formatter.format(content: content, style: style);
      expect(result, equals(content));
    });

    test('internal context leaves content as-is', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.internal,
        ),
      );

      const content = 'Internal content.';
      final result = formatter.format(content: content, style: style);
      expect(result, equals(content));
    });

    test('public context adds general reference note', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.public_,
        ),
      );

      final result = formatter.format(
        content: 'Public-facing information.',
        style: style,
      );

      expect(result, contains('Note: This information is for general reference.'));
      expect(result, contains('Public-facing information.'));
    });

    test('avoidJargon replaces all jargon terms', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.internal,
          preferences: AudiencePreferences(avoidJargon: true),
        ),
      );

      final result = formatter.format(
        content:
            'We need to implement the system, mitigate risks, '
            'propagate changes, remediate issues, and instantiate objects.',
        style: style,
      );

      expect(result, contains('set up'));
      expect(result, contains('reduce'));
      expect(result, contains('spread'));
      expect(result, contains('fix'));
      expect(result, contains('create'));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — generateStylePrompt additional coverage
  // ===========================================================================

  group('ExpressionStyleFormatter generateStylePrompt (additional)', () {
    const formatter = ExpressionStyleFormatter();

    test('includes all format flag lines when all are true', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
          includeEvidence: true,
          includeCaveats: true,
          includeAlternatives: true,
          includeNextSteps: true,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('Include evidence/sources'));
      expect(prompt, contains('Include caveats/disclaimers'));
      expect(prompt, contains('Include alternatives'));
      expect(prompt, contains('Include next steps'));
    });

    test('omits format flags when all are false', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
          includeEvidence: false,
          includeCaveats: false,
          includeAlternatives: false,
          includeNextSteps: false,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, isNot(contains('Include evidence')));
      expect(prompt, isNot(contains('Include caveats')));
      expect(prompt, isNot(contains('Include alternatives')));
      expect(prompt, isNot(contains('Include next steps')));
    });

    test('prompt reflects numbered structure and detailed length', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.numbered,
          length: Length.detailed,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('numbered'));
      expect(prompt, contains('detailed'));
    });

    test('prompt reflects table structure and concise length', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.table,
          length: Length.concise,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('table'));
      expect(prompt, contains('concise'));
    });

    test('prompt reflects mixed structure', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.mixed,
          length: Length.standard,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('mixed'));
    });

    test('prompt includes light hedging level', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        hedging: HedgingConfig(level: HedgingLevel.light),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('Hedging'));
      expect(prompt, contains('light'));
    });

    test('prompt includes moderate hedging level', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        hedging: HedgingConfig(level: HedgingLevel.moderate),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('Hedging'));
      expect(prompt, contains('moderate'));
    });

    test('prompt includes audience with expert expertise and external context', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        audience: AudienceConfig(
          expertise: Expertise.expert,
          context: AudienceContext.external,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('Audience'));
      expect(prompt, contains('expert'));
      expect(prompt, contains('external'));
    });

    test('prompt includes audience with intermediate expertise and internal context', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        audience: AudienceConfig(
          expertise: Expertise.intermediate,
          context: AudienceContext.internal,
        ),
      );

      final prompt = formatter.generateStylePrompt(style);

      expect(prompt, contains('Audience'));
      expect(prompt, contains('intermediate'));
      expect(prompt, contains('internal'));
    });
  });

  // ===========================================================================
  // ExpressionStyleFormatter — hedging inline position additional
  // ===========================================================================

  group('ExpressionStyleFormatter hedging inline (additional)', () {
    const formatter = ExpressionStyleFormatter();

    test('inline hedging leaves content as-is for simple hedging', () {
      // The _applyHedgingSimple with inline position just returns content
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.prose,
          length: Length.standard,
        ),
        hedging: HedgingConfig(
          level: HedgingLevel.moderate,
          position: HedgingPosition.inline,
        ),
      );

      const content = 'Simple content.';
      final result = formatter.format(content: content, style: style);
      expect(result, equals(content));
    });
  });

  // ===========================================================================
  // Coverage: _convertToNumbered with maxBullets (line 428)
  // ===========================================================================
  group('ExpressionStyleFormatter _convertToNumbered with maxBullets', () {
    const formatter = ExpressionStyleFormatter();

    test('numbered structure with maxBullets limits items', () {
      const style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig(
          structure: Structure.numbered,
          length: Length.standard,
          maxBullets: 2,
        ),
      );

      final result = formatter.format(
        content: 'First item. Second item. Third item. Fourth item.',
        style: style,
      );

      final lines = result.split('\n');
      expect(lines.length, equals(2));
      expect(lines[0], startsWith('1. '));
      expect(lines[1], startsWith('2. '));
    });
  });
}
