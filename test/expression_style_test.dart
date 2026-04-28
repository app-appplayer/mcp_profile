/// ExpressionStyle Tests
library;

import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

void main() {
  // ===========================================================================
  // Enum Tests
  // ===========================================================================

  group('Formality', () {
    test('has 3 values', () {
      expect(Formality.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(Formality.values, contains(Formality.formal));
      expect(Formality.values, contains(Formality.neutral));
      expect(Formality.values, contains(Formality.casual));
    });
  });

  group('ToneConfidence', () {
    test('has 3 values', () {
      expect(ToneConfidence.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(ToneConfidence.values, contains(ToneConfidence.assertive));
      expect(ToneConfidence.values, contains(ToneConfidence.moderate));
      expect(ToneConfidence.values, contains(ToneConfidence.tentative));
    });
  });

  group('Empathy', () {
    test('has 3 values', () {
      expect(Empathy.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(Empathy.values, contains(Empathy.high));
      expect(Empathy.values, contains(Empathy.moderate));
      expect(Empathy.values, contains(Empathy.low));
    });
  });

  group('Directness', () {
    test('has 3 values', () {
      expect(Directness.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(Directness.values, contains(Directness.direct));
      expect(Directness.values, contains(Directness.balanced));
      expect(Directness.values, contains(Directness.diplomatic));
    });
  });

  group('Structure', () {
    test('has 5 values', () {
      expect(Structure.values.length, equals(5));
    });

    test('contains expected values', () {
      expect(Structure.values, contains(Structure.prose));
      expect(Structure.values, contains(Structure.bullets));
      expect(Structure.values, contains(Structure.numbered));
      expect(Structure.values, contains(Structure.table));
      expect(Structure.values, contains(Structure.mixed));
    });
  });

  group('Length', () {
    test('has 3 values', () {
      expect(Length.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(Length.values, contains(Length.concise));
      expect(Length.values, contains(Length.standard));
      expect(Length.values, contains(Length.detailed));
    });
  });

  group('HedgingLevel', () {
    test('has 4 values', () {
      expect(HedgingLevel.values.length, equals(4));
    });

    test('contains expected values', () {
      expect(HedgingLevel.values, contains(HedgingLevel.none));
      expect(HedgingLevel.values, contains(HedgingLevel.light));
      expect(HedgingLevel.values, contains(HedgingLevel.moderate));
      expect(HedgingLevel.values, contains(HedgingLevel.strong));
    });
  });

  group('HedgingPosition', () {
    test('has 3 values', () {
      expect(HedgingPosition.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(HedgingPosition.values, contains(HedgingPosition.start));
      expect(HedgingPosition.values, contains(HedgingPosition.inline));
      expect(HedgingPosition.values, contains(HedgingPosition.end));
    });
  });

  group('Expertise', () {
    test('has 3 values', () {
      expect(Expertise.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(Expertise.values, contains(Expertise.expert));
      expect(Expertise.values, contains(Expertise.intermediate));
      expect(Expertise.values, contains(Expertise.novice));
    });
  });

  group('AudienceContext', () {
    test('has 3 values', () {
      expect(AudienceContext.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(AudienceContext.values, contains(AudienceContext.internal));
      expect(AudienceContext.values, contains(AudienceContext.external));
      expect(AudienceContext.values, contains(AudienceContext.public_));
    });
  });

  group('VisualPreference', () {
    test('has 3 values', () {
      expect(VisualPreference.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(VisualPreference.values, contains(VisualPreference.text));
      expect(VisualPreference.values, contains(VisualPreference.diagrams));
      expect(VisualPreference.values, contains(VisualPreference.mixed));
    });
  });

  group('JargonLevel', () {
    test('has 4 values', () {
      expect(JargonLevel.values.length, equals(4));
    });

    test('contains expected values', () {
      expect(JargonLevel.values, contains(JargonLevel.none));
      expect(JargonLevel.values, contains(JargonLevel.minimal));
      expect(JargonLevel.values, contains(JargonLevel.standard));
      expect(JargonLevel.values, contains(JargonLevel.technical));
    });
  });

  group('VoicePreference', () {
    test('has 3 values', () {
      expect(VoicePreference.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(VoicePreference.values, contains(VoicePreference.active));
      expect(VoicePreference.values, contains(VoicePreference.passive));
      expect(VoicePreference.values, contains(VoicePreference.mixed));
    });
  });

  group('SentenceComplexity', () {
    test('has 3 values', () {
      expect(SentenceComplexity.values.length, equals(3));
    });

    test('contains expected values', () {
      expect(SentenceComplexity.values, contains(SentenceComplexity.simple));
      expect(
          SentenceComplexity.values, contains(SentenceComplexity.moderate));
      expect(SentenceComplexity.values, contains(SentenceComplexity.complex));
    });
  });

  // ===========================================================================
  // ToneConfig Tests
  // ===========================================================================

  group('ToneConfig', () {
    test('creation stores all fields', () {
      final tone = ToneConfig(
        formality: Formality.formal,
        confidence: ToneConfidence.assertive,
        empathy: Empathy.high,
        directness: Directness.direct,
      );

      expect(tone.formality, equals(Formality.formal));
      expect(tone.confidence, equals(ToneConfidence.assertive));
      expect(tone.empathy, equals(Empathy.high));
      expect(tone.directness, equals(Directness.direct));
    });

    test('merge replaces all fields', () {
      final base = ToneConfig(
        formality: Formality.formal,
        confidence: ToneConfidence.assertive,
        empathy: Empathy.high,
        directness: Directness.direct,
      );

      final override = ToneConfig(
        formality: Formality.casual,
        confidence: ToneConfidence.tentative,
        empathy: Empathy.low,
        directness: Directness.diplomatic,
      );

      final merged = base.merge(override);

      expect(merged.formality, equals(Formality.casual));
      expect(merged.confidence, equals(ToneConfidence.tentative));
      expect(merged.empathy, equals(Empathy.low));
      expect(merged.directness, equals(Directness.diplomatic));
    });

    test('neutral static const has expected defaults', () {
      final neutral = ToneConfig.neutral;

      expect(neutral.formality, equals(Formality.neutral));
      expect(neutral.confidence, equals(ToneConfidence.moderate));
      expect(neutral.empathy, equals(Empathy.moderate));
      expect(neutral.directness, equals(Directness.balanced));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'formality': 'formal',
        'confidence': 'assertive',
        'empathy': 'high',
        'directness': 'direct',
      };

      final tone = ToneConfig.fromJson(json);

      expect(tone.formality, equals(Formality.formal));
      expect(tone.confidence, equals(ToneConfidence.assertive));
      expect(tone.empathy, equals(Empathy.high));
      expect(tone.directness, equals(Directness.direct));
    });

    test('toJson produces correct map', () {
      final tone = ToneConfig(
        formality: Formality.casual,
        confidence: ToneConfidence.tentative,
        empathy: Empathy.low,
        directness: Directness.diplomatic,
      );

      final json = tone.toJson();

      expect(json['formality'], equals('casual'));
      expect(json['confidence'], equals('tentative'));
      expect(json['empathy'], equals('low'));
      expect(json['directness'], equals('diplomatic'));
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = ToneConfig(
        formality: Formality.formal,
        confidence: ToneConfidence.moderate,
        empathy: Empathy.high,
        directness: Directness.balanced,
      );

      final restored = ToneConfig.fromJson(original.toJson());

      expect(restored.formality, equals(original.formality));
      expect(restored.confidence, equals(original.confidence));
      expect(restored.empathy, equals(original.empathy));
      expect(restored.directness, equals(original.directness));
    });
  });

  // ===========================================================================
  // FormatConfig Tests
  // ===========================================================================

  group('FormatConfig', () {
    test('creation with defaults', () {
      final format = FormatConfig(
        structure: Structure.prose,
        length: Length.standard,
      );

      expect(format.structure, equals(Structure.prose));
      expect(format.length, equals(Length.standard));
      expect(format.includeEvidence, isFalse);
      expect(format.includeCaveats, isFalse);
      expect(format.includeAlternatives, isFalse);
      expect(format.includeNextSteps, isFalse);
      expect(format.maxParagraphs, isNull);
      expect(format.maxBullets, isNull);
    });

    test('creation with all fields', () {
      final format = FormatConfig(
        structure: Structure.bullets,
        length: Length.concise,
        includeEvidence: true,
        includeCaveats: true,
        includeAlternatives: true,
        includeNextSteps: true,
        maxParagraphs: 3,
        maxBullets: 5,
      );

      expect(format.structure, equals(Structure.bullets));
      expect(format.length, equals(Length.concise));
      expect(format.includeEvidence, isTrue);
      expect(format.includeCaveats, isTrue);
      expect(format.includeAlternatives, isTrue);
      expect(format.includeNextSteps, isTrue);
      expect(format.maxParagraphs, equals(3));
      expect(format.maxBullets, equals(5));
    });

    test('merge replaces fields, preserves nullable when other is null', () {
      final base = FormatConfig(
        structure: Structure.prose,
        length: Length.standard,
        includeEvidence: true,
        maxParagraphs: 5,
        maxBullets: 10,
      );

      final override = FormatConfig(
        structure: Structure.bullets,
        length: Length.concise,
      );

      final merged = base.merge(override);

      expect(merged.structure, equals(Structure.bullets));
      expect(merged.length, equals(Length.concise));
      expect(merged.includeEvidence, isFalse);
      expect(merged.maxParagraphs, equals(5));
      expect(merged.maxBullets, equals(10));
    });

    test('standard static const has expected values', () {
      final standard = FormatConfig.standard;

      expect(standard.structure, equals(Structure.prose));
      expect(standard.length, equals(Length.standard));
      expect(standard.includeEvidence, isFalse);
      expect(standard.includeCaveats, isFalse);
    });

    test('defaultFormat static const has expected values', () {
      final defaultFmt = FormatConfig.defaultFormat;

      expect(defaultFmt.structure, equals(Structure.mixed));
      expect(defaultFmt.length, equals(Length.standard));
      expect(defaultFmt.includeEvidence, isTrue);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'structure': 'bullets',
        'length': 'concise',
        'includeEvidence': true,
        'includeCaveats': true,
        'includeAlternatives': false,
        'includeNextSteps': false,
        'maxParagraphs': 4,
        'maxBullets': 8,
      };

      final format = FormatConfig.fromJson(json);

      expect(format.structure, equals(Structure.bullets));
      expect(format.length, equals(Length.concise));
      expect(format.includeEvidence, isTrue);
      expect(format.includeCaveats, isTrue);
      expect(format.includeAlternatives, isFalse);
      expect(format.includeNextSteps, isFalse);
      expect(format.maxParagraphs, equals(4));
      expect(format.maxBullets, equals(8));
    });

    test('toJson produces correct map', () {
      final format = FormatConfig(
        structure: Structure.numbered,
        length: Length.detailed,
        includeEvidence: true,
        includeCaveats: true,
        includeAlternatives: false,
        includeNextSteps: true,
        maxParagraphs: 6,
      );

      final json = format.toJson();

      expect(json['structure'], equals('numbered'));
      expect(json['length'], equals('detailed'));
      expect(json['includeEvidence'], isTrue);
      expect(json['includeCaveats'], isTrue);
      expect(json['includeNextSteps'], isTrue);
      expect(json['maxParagraphs'], equals(6));
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = FormatConfig(
        structure: Structure.table,
        length: Length.detailed,
        includeEvidence: true,
        includeCaveats: true,
        includeAlternatives: true,
        includeNextSteps: true,
        maxParagraphs: 3,
        maxBullets: 7,
      );

      final restored = FormatConfig.fromJson(original.toJson());

      expect(restored.structure, equals(original.structure));
      expect(restored.length, equals(original.length));
      expect(restored.includeEvidence, equals(original.includeEvidence));
      expect(restored.includeCaveats, equals(original.includeCaveats));
      expect(restored.includeAlternatives, equals(original.includeAlternatives));
      expect(restored.includeNextSteps, equals(original.includeNextSteps));
      expect(restored.maxParagraphs, equals(original.maxParagraphs));
      expect(restored.maxBullets, equals(original.maxBullets));
    });
  });

  // ===========================================================================
  // HedgingConfig Tests
  // ===========================================================================

  group('HedgingConfig', () {
    test('creation with defaults', () {
      final config = HedgingConfig();

      expect(config.level, equals(HedgingLevel.none));
      expect(config.phrases, isNull);
      expect(config.position, equals(HedgingPosition.inline));
    });

    test('creation with all fields', () {
      final phrases = HedgingPhrases(
        highUncertainty: ['maybe'],
      );
      final config = HedgingConfig(
        level: HedgingLevel.strong,
        phrases: phrases,
        position: HedgingPosition.start,
      );

      expect(config.level, equals(HedgingLevel.strong));
      expect(config.phrases, isNotNull);
      expect(config.position, equals(HedgingPosition.start));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'level': 'moderate',
        'position': 'end',
      };

      final config = HedgingConfig.fromJson(json);

      expect(config.level, equals(HedgingLevel.moderate));
      expect(config.position, equals(HedgingPosition.end));
      expect(config.phrases, isNull);
    });

    test('fromJson with phrases', () {
      final json = {
        'level': 'light',
        'position': 'start',
        'phrases': {
          'high_uncertainty': ['It seems'],
          'qualifying': ['however'],
        },
      };

      final config = HedgingConfig.fromJson(json);

      expect(config.level, equals(HedgingLevel.light));
      expect(config.phrases, isNotNull);
      expect(config.phrases!.highUncertainty, contains('It seems'));
      expect(config.phrases!.qualifying, contains('however'));
    });

    test('toJson produces correct map', () {
      final config = HedgingConfig(
        level: HedgingLevel.strong,
        position: HedgingPosition.start,
      );

      final json = config.toJson();

      expect(json['level'], equals('strong'));
      expect(json['position'], equals('start'));
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = HedgingConfig(
        level: HedgingLevel.moderate,
        position: HedgingPosition.end,
      );

      final restored = HedgingConfig.fromJson(original.toJson());

      expect(restored.level, equals(original.level));
      expect(restored.position, equals(original.position));
    });
  });

  // ===========================================================================
  // HedgingPhrases Tests
  // ===========================================================================

  group('HedgingPhrases', () {
    test('creation with all fields', () {
      final phrases = HedgingPhrases(
        highUncertainty: ['possibly'],
        moderateUncertainty: ['likely'],
        lowUncertainty: ['clearly'],
        qualifying: ['however'],
        probabilistic: ['probably'],
      );

      expect(phrases.highUncertainty, contains('possibly'));
      expect(phrases.moderateUncertainty, contains('likely'));
      expect(phrases.lowUncertainty, contains('clearly'));
      expect(phrases.qualifying, contains('however'));
      expect(phrases.probabilistic, contains('probably'));
    });

    test('creation with null fields', () {
      final phrases = HedgingPhrases();

      expect(phrases.highUncertainty, isNull);
      expect(phrases.moderateUncertainty, isNull);
      expect(phrases.lowUncertainty, isNull);
      expect(phrases.qualifying, isNull);
      expect(phrases.probabilistic, isNull);
    });

    test('defaults static const has non-empty lists', () {
      final defaults = HedgingPhrases.defaults;

      expect(defaults.highUncertainty, isNotNull);
      expect(defaults.highUncertainty!, isNotEmpty);
      expect(defaults.moderateUncertainty, isNotNull);
      expect(defaults.moderateUncertainty!, isNotEmpty);
      expect(defaults.lowUncertainty, isNotNull);
      expect(defaults.lowUncertainty!, isNotEmpty);
      expect(defaults.qualifying, isNotNull);
      expect(defaults.qualifying!, isNotEmpty);
      expect(defaults.probabilistic, isNotNull);
      expect(defaults.probabilistic!, isNotEmpty);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'high_uncertainty': ['tentatively'],
        'moderate_uncertainty': ['it seems'],
        'low_uncertainty': ['the data shows'],
        'qualifying': ['although'],
        'probabilistic': ['potentially'],
      };

      final phrases = HedgingPhrases.fromJson(json);

      expect(phrases.highUncertainty, contains('tentatively'));
      expect(phrases.moderateUncertainty, contains('it seems'));
      expect(phrases.lowUncertainty, contains('the data shows'));
      expect(phrases.qualifying, contains('although'));
      expect(phrases.probabilistic, contains('potentially'));
    });

    test('toJson produces correct map', () {
      final phrases = HedgingPhrases(
        highUncertainty: ['maybe'],
        qualifying: ['but'],
      );

      final json = phrases.toJson();

      expect(json['high_uncertainty'], equals(['maybe']));
      expect(json['qualifying'], equals(['but']));
      expect(json.containsKey('moderate_uncertainty'), isFalse);
      expect(json.containsKey('low_uncertainty'), isFalse);
      expect(json.containsKey('probabilistic'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = HedgingPhrases(
        highUncertainty: ['a', 'b'],
        moderateUncertainty: ['c'],
        lowUncertainty: ['d'],
        qualifying: ['e'],
        probabilistic: ['f'],
      );

      final restored = HedgingPhrases.fromJson(original.toJson());

      expect(restored.highUncertainty, equals(original.highUncertainty));
      expect(
          restored.moderateUncertainty, equals(original.moderateUncertainty));
      expect(restored.lowUncertainty, equals(original.lowUncertainty));
      expect(restored.qualifying, equals(original.qualifying));
      expect(restored.probabilistic, equals(original.probabilistic));
    });
  });

  // ===========================================================================
  // AudienceConfig Tests
  // ===========================================================================

  group('AudienceConfig', () {
    test('creation with defaults', () {
      final config = AudienceConfig();

      expect(config.expertise, equals(Expertise.intermediate));
      expect(config.context, equals(AudienceContext.internal));
      expect(config.role, isNull);
      expect(config.preferences, isNull);
    });

    test('creation with all fields', () {
      final prefs = AudiencePreferences(
        preferredFormat: 'markdown',
        avoidJargon: true,
      );
      final config = AudienceConfig(
        expertise: Expertise.expert,
        context: AudienceContext.external,
        role: 'developer',
        preferences: prefs,
      );

      expect(config.expertise, equals(Expertise.expert));
      expect(config.context, equals(AudienceContext.external));
      expect(config.role, equals('developer'));
      expect(config.preferences, isNotNull);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'expertise': 'novice',
        'context': 'public_',
        'role': 'analyst',
      };

      final config = AudienceConfig.fromJson(json);

      expect(config.expertise, equals(Expertise.novice));
      expect(config.context, equals(AudienceContext.public_));
      expect(config.role, equals('analyst'));
      expect(config.preferences, isNull);
    });

    test('fromJson with preferences', () {
      final json = {
        'expertise': 'expert',
        'context': 'internal',
        'preferences': {
          'preferredFormat': 'html',
          'avoidJargon': true,
          'includeDefinitions': true,
          'visualPreference': 'diagrams',
        },
      };

      final config = AudienceConfig.fromJson(json);

      expect(config.preferences, isNotNull);
      expect(config.preferences!.preferredFormat, equals('html'));
      expect(config.preferences!.avoidJargon, isTrue);
    });

    test('toJson produces correct map', () {
      final config = AudienceConfig(
        expertise: Expertise.novice,
        context: AudienceContext.public_,
        role: 'user',
      );

      final json = config.toJson();

      expect(json['expertise'], equals('novice'));
      expect(json['context'], equals('public_'));
      expect(json['role'], equals('user'));
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = AudienceConfig(
        expertise: Expertise.expert,
        context: AudienceContext.external,
        role: 'manager',
      );

      final restored = AudienceConfig.fromJson(original.toJson());

      expect(restored.expertise, equals(original.expertise));
      expect(restored.context, equals(original.context));
      expect(restored.role, equals(original.role));
    });
  });

  // ===========================================================================
  // AudiencePreferences Tests
  // ===========================================================================

  group('AudiencePreferences', () {
    test('creation with defaults', () {
      final prefs = AudiencePreferences();

      expect(prefs.preferredFormat, isNull);
      expect(prefs.avoidJargon, isFalse);
      expect(prefs.includeDefinitions, isFalse);
      expect(prefs.visualPreference, equals(VisualPreference.text));
    });

    test('creation with all fields', () {
      final prefs = AudiencePreferences(
        preferredFormat: 'markdown',
        avoidJargon: true,
        includeDefinitions: true,
        visualPreference: VisualPreference.diagrams,
      );

      expect(prefs.preferredFormat, equals('markdown'));
      expect(prefs.avoidJargon, isTrue);
      expect(prefs.includeDefinitions, isTrue);
      expect(prefs.visualPreference, equals(VisualPreference.diagrams));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'preferredFormat': 'plain',
        'avoidJargon': true,
        'includeDefinitions': false,
        'visualPreference': 'mixed',
      };

      final prefs = AudiencePreferences.fromJson(json);

      expect(prefs.preferredFormat, equals('plain'));
      expect(prefs.avoidJargon, isTrue);
      expect(prefs.includeDefinitions, isFalse);
      expect(prefs.visualPreference, equals(VisualPreference.mixed));
    });

    test('toJson produces correct map', () {
      final prefs = AudiencePreferences(
        preferredFormat: 'html',
        avoidJargon: true,
        includeDefinitions: true,
        visualPreference: VisualPreference.diagrams,
      );

      final json = prefs.toJson();

      expect(json['preferredFormat'], equals('html'));
      expect(json['avoidJargon'], isTrue);
      expect(json['includeDefinitions'], isTrue);
      expect(json['visualPreference'], equals('diagrams'));
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = AudiencePreferences(
        preferredFormat: 'pdf',
        avoidJargon: true,
        includeDefinitions: true,
        visualPreference: VisualPreference.mixed,
      );

      final restored = AudiencePreferences.fromJson(original.toJson());

      expect(restored.preferredFormat, equals(original.preferredFormat));
      expect(restored.avoidJargon, equals(original.avoidJargon));
      expect(
          restored.includeDefinitions, equals(original.includeDefinitions));
      expect(restored.visualPreference, equals(original.visualPreference));
    });
  });

  // ===========================================================================
  // LanguageConfig Tests
  // ===========================================================================

  group('LanguageConfig', () {
    test('creation with all fields', () {
      final vocab = VocabularyConfig(
        avoidWords: ['bad'],
        jargonLevel: JargonLevel.minimal,
      );
      final grammar = GrammarConfig(
        voicePreference: VoicePreference.passive,
      );
      final config = LanguageConfig(
        locale: 'en-US',
        vocabulary: vocab,
        grammar: grammar,
      );

      expect(config.locale, equals('en-US'));
      expect(config.vocabulary, isNotNull);
      expect(config.grammar, isNotNull);
    });

    test('creation with null fields', () {
      final config = LanguageConfig();

      expect(config.locale, isNull);
      expect(config.vocabulary, isNull);
      expect(config.grammar, isNull);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'locale': 'ko-KR',
        'vocabulary': {
          'avoidWords': ['slang'],
          'jargonLevel': 'technical',
        },
        'grammar': {
          'voicePreference': 'passive',
          'sentenceComplexity': 'simple',
          'useContractions': true,
        },
      };

      final config = LanguageConfig.fromJson(json);

      expect(config.locale, equals('ko-KR'));
      expect(config.vocabulary, isNotNull);
      expect(config.vocabulary!.jargonLevel, equals(JargonLevel.technical));
      expect(config.grammar, isNotNull);
      expect(
          config.grammar!.voicePreference, equals(VoicePreference.passive));
    });

    test('toJson produces correct map', () {
      final config = LanguageConfig(locale: 'en-US');

      final json = config.toJson();

      expect(json['locale'], equals('en-US'));
      expect(json.containsKey('vocabulary'), isFalse);
      expect(json.containsKey('grammar'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = LanguageConfig(
        locale: 'ja-JP',
        vocabulary: VocabularyConfig(
          avoidWords: ['x'],
          preferredTerms: {'old': 'new'},
          jargonLevel: JargonLevel.none,
        ),
        grammar: GrammarConfig(
          voicePreference: VoicePreference.mixed,
          sentenceComplexity: SentenceComplexity.complex,
          useContractions: true,
        ),
      );

      final restored = LanguageConfig.fromJson(original.toJson());

      expect(restored.locale, equals(original.locale));
      expect(restored.vocabulary, isNotNull);
      expect(restored.vocabulary!.avoidWords,
          equals(original.vocabulary!.avoidWords));
      expect(restored.vocabulary!.preferredTerms,
          equals(original.vocabulary!.preferredTerms));
      expect(restored.vocabulary!.jargonLevel,
          equals(original.vocabulary!.jargonLevel));
      expect(restored.grammar, isNotNull);
      expect(restored.grammar!.voicePreference,
          equals(original.grammar!.voicePreference));
      expect(restored.grammar!.sentenceComplexity,
          equals(original.grammar!.sentenceComplexity));
      expect(restored.grammar!.useContractions,
          equals(original.grammar!.useContractions));
    });
  });

  // ===========================================================================
  // VocabularyConfig Tests
  // ===========================================================================

  group('VocabularyConfig', () {
    test('creation with defaults', () {
      final config = VocabularyConfig();

      expect(config.avoidWords, isNull);
      expect(config.preferredTerms, isNull);
      expect(config.jargonLevel, equals(JargonLevel.standard));
    });

    test('creation with all fields', () {
      final config = VocabularyConfig(
        avoidWords: ['bad', 'ugly'],
        preferredTerms: {'old': 'new', 'legacy': 'modern'},
        jargonLevel: JargonLevel.technical,
      );

      expect(config.avoidWords, equals(['bad', 'ugly']));
      expect(config.preferredTerms, equals({'old': 'new', 'legacy': 'modern'}));
      expect(config.jargonLevel, equals(JargonLevel.technical));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'avoidWords': ['foo'],
        'preferredTerms': {'a': 'b'},
        'jargonLevel': 'minimal',
      };

      final config = VocabularyConfig.fromJson(json);

      expect(config.avoidWords, equals(['foo']));
      expect(config.preferredTerms, equals({'a': 'b'}));
      expect(config.jargonLevel, equals(JargonLevel.minimal));
    });

    test('toJson produces correct map', () {
      final config = VocabularyConfig(
        avoidWords: ['x'],
        preferredTerms: {'y': 'z'},
        jargonLevel: JargonLevel.none,
      );

      final json = config.toJson();

      expect(json['avoidWords'], equals(['x']));
      expect(json['preferredTerms'], equals({'y': 'z'}));
      expect(json['jargonLevel'], equals('none'));
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = VocabularyConfig(
        avoidWords: ['stop', 'halt'],
        preferredTerms: {'start': 'begin'},
        jargonLevel: JargonLevel.technical,
      );

      final restored = VocabularyConfig.fromJson(original.toJson());

      expect(restored.avoidWords, equals(original.avoidWords));
      expect(restored.preferredTerms, equals(original.preferredTerms));
      expect(restored.jargonLevel, equals(original.jargonLevel));
    });
  });

  // ===========================================================================
  // GrammarConfig Tests
  // ===========================================================================

  group('GrammarConfig', () {
    test('creation with defaults', () {
      final config = GrammarConfig();

      expect(config.voicePreference, equals(VoicePreference.active));
      expect(config.sentenceComplexity, equals(SentenceComplexity.moderate));
      expect(config.useContractions, isFalse);
    });

    test('creation with all fields', () {
      final config = GrammarConfig(
        voicePreference: VoicePreference.passive,
        sentenceComplexity: SentenceComplexity.complex,
        useContractions: true,
      );

      expect(config.voicePreference, equals(VoicePreference.passive));
      expect(config.sentenceComplexity, equals(SentenceComplexity.complex));
      expect(config.useContractions, isTrue);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'voicePreference': 'mixed',
        'sentenceComplexity': 'simple',
        'useContractions': true,
      };

      final config = GrammarConfig.fromJson(json);

      expect(config.voicePreference, equals(VoicePreference.mixed));
      expect(config.sentenceComplexity, equals(SentenceComplexity.simple));
      expect(config.useContractions, isTrue);
    });

    test('toJson produces correct map', () {
      final config = GrammarConfig(
        voicePreference: VoicePreference.passive,
        sentenceComplexity: SentenceComplexity.complex,
        useContractions: true,
      );

      final json = config.toJson();

      expect(json['voicePreference'], equals('passive'));
      expect(json['sentenceComplexity'], equals('complex'));
      expect(json['useContractions'], isTrue);
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = GrammarConfig(
        voicePreference: VoicePreference.mixed,
        sentenceComplexity: SentenceComplexity.simple,
        useContractions: true,
      );

      final restored = GrammarConfig.fromJson(original.toJson());

      expect(restored.voicePreference, equals(original.voicePreference));
      expect(restored.sentenceComplexity,
          equals(original.sentenceComplexity));
      expect(restored.useContractions, equals(original.useContractions));
    });
  });

  // ===========================================================================
  // ExpressionStyle Tests
  // ===========================================================================

  group('ExpressionStyle', () {
    test('creation with required fields only', () {
      final style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
      );

      expect(style.tone, isNotNull);
      expect(style.format, isNotNull);
      expect(style.hedging, isNull);
      expect(style.audience, isNull);
      expect(style.language, isNull);
      expect(style.metadata, isNull);
    });

    test('creation with all fields', () {
      final style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        hedging: HedgingConfig(level: HedgingLevel.moderate),
        audience: AudienceConfig(expertise: Expertise.expert),
        language: LanguageConfig(locale: 'en-US'),
        metadata: {'key': 'value'},
      );

      expect(style.hedging, isNotNull);
      expect(style.hedging!.level, equals(HedgingLevel.moderate));
      expect(style.audience, isNotNull);
      expect(style.audience!.expertise, equals(Expertise.expert));
      expect(style.language, isNotNull);
      expect(style.language!.locale, equals('en-US'));
      expect(style.metadata, equals({'key': 'value'}));
    });

    test('merge with null returns this', () {
      final style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
      );

      final merged = style.merge(null);

      expect(merged.tone.formality, equals(style.tone.formality));
      expect(merged.format.structure, equals(style.format.structure));
    });

    test('merge replaces tone and format, takes override optional fields', () {
      final base = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        hedging: HedgingConfig(level: HedgingLevel.light),
        language: LanguageConfig(locale: 'en-US'),
      );

      final override = ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.assertive,
          empathy: Empathy.high,
          directness: Directness.direct,
        ),
        format: FormatConfig(
          structure: Structure.bullets,
          length: Length.concise,
        ),
        audience: AudienceConfig(expertise: Expertise.expert),
      );

      final merged = base.merge(override);

      expect(merged.tone.formality, equals(Formality.formal));
      expect(merged.format.structure, equals(Structure.bullets));
      expect(merged.audience, isNotNull);
      expect(merged.audience!.expertise, equals(Expertise.expert));
      expect(merged.hedging, isNotNull);
      expect(merged.hedging!.level, equals(HedgingLevel.light));
      expect(merged.language, isNotNull);
      expect(merged.language!.locale, equals('en-US'));
    });

    test('merge combines metadata', () {
      final base = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        metadata: {'a': 1, 'b': 2},
      );

      final override = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
        metadata: {'b': 3, 'c': 4},
      );

      final merged = base.merge(override);

      expect(merged.metadata, equals({'a': 1, 'b': 3, 'c': 4}));
    });

    test('defaultStyle has neutral tone and defaultFormat', () {
      final style = ExpressionStyle.defaultStyle;

      expect(style.tone.formality, equals(Formality.neutral));
      expect(style.tone.confidence, equals(ToneConfidence.moderate));
      expect(style.tone.empathy, equals(Empathy.moderate));
      expect(style.tone.directness, equals(Directness.balanced));
      expect(style.format.structure, equals(Structure.mixed));
      expect(style.format.length, equals(Length.standard));
      expect(style.format.includeEvidence, isTrue);
      expect(style.hedging, isNull);
      expect(style.audience, isNull);
      expect(style.language, isNull);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'tone': {
          'formality': 'casual',
          'confidence': 'tentative',
          'empathy': 'low',
          'directness': 'diplomatic',
        },
        'format': {
          'structure': 'bullets',
          'length': 'concise',
          'includeEvidence': false,
          'includeCaveats': false,
          'includeAlternatives': false,
        },
      };

      final style = ExpressionStyle.fromJson(json);

      expect(style.tone.formality, equals(Formality.casual));
      expect(style.format.structure, equals(Structure.bullets));
      expect(style.hedging, isNull);
      expect(style.audience, isNull);
      expect(style.language, isNull);
    });

    test('fromJson with all optional fields', () {
      final json = {
        'tone': {
          'formality': 'formal',
          'confidence': 'assertive',
          'empathy': 'high',
          'directness': 'direct',
        },
        'format': {
          'structure': 'prose',
          'length': 'detailed',
          'includeEvidence': true,
          'includeCaveats': true,
          'includeAlternatives': false,
        },
        'hedging': {
          'level': 'strong',
          'position': 'start',
        },
        'audience': {
          'expertise': 'expert',
          'context': 'external',
        },
        'language': {
          'locale': 'en-GB',
        },
        'metadata': {'version': 2},
      };

      final style = ExpressionStyle.fromJson(json);

      expect(style.hedging, isNotNull);
      expect(style.hedging!.level, equals(HedgingLevel.strong));
      expect(style.audience, isNotNull);
      expect(style.audience!.expertise, equals(Expertise.expert));
      expect(style.language, isNotNull);
      expect(style.language!.locale, equals('en-GB'));
      expect(style.metadata, equals({'version': 2}));
    });

    test('toJson produces correct map', () {
      final style = ExpressionStyle(
        tone: ToneConfig.neutral,
        format: FormatConfig.standard,
      );

      final json = style.toJson();

      expect(json.containsKey('tone'), isTrue);
      expect(json.containsKey('format'), isTrue);
      expect(json.containsKey('hedging'), isFalse);
      expect(json.containsKey('audience'), isFalse);
      expect(json.containsKey('language'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves values', () {
      final original = ExpressionStyle(
        tone: ToneConfig(
          formality: Formality.formal,
          confidence: ToneConfidence.assertive,
          empathy: Empathy.high,
          directness: Directness.direct,
        ),
        format: FormatConfig(
          structure: Structure.numbered,
          length: Length.detailed,
          includeEvidence: true,
          includeCaveats: true,
          includeAlternatives: true,
          includeNextSteps: true,
          maxParagraphs: 5,
          maxBullets: 10,
        ),
        hedging: HedgingConfig(
          level: HedgingLevel.strong,
          position: HedgingPosition.start,
        ),
        audience: AudienceConfig(
          expertise: Expertise.novice,
          context: AudienceContext.public_,
          role: 'student',
        ),
        language: LanguageConfig(locale: 'en-US'),
        metadata: {'source': 'test'},
      );

      final restored = ExpressionStyle.fromJson(original.toJson());

      expect(restored.tone.formality, equals(original.tone.formality));
      expect(restored.tone.confidence, equals(original.tone.confidence));
      expect(restored.format.structure, equals(original.format.structure));
      expect(restored.format.length, equals(original.format.length));
      expect(
          restored.format.includeEvidence, equals(original.format.includeEvidence));
      expect(restored.hedging, isNotNull);
      expect(restored.hedging!.level, equals(original.hedging!.level));
      expect(restored.audience, isNotNull);
      expect(restored.audience!.expertise, equals(original.audience!.expertise));
      expect(restored.audience!.context, equals(original.audience!.context));
      expect(restored.audience!.role, equals(original.audience!.role));
      expect(restored.language, isNotNull);
      expect(restored.language!.locale, equals(original.language!.locale));
      expect(restored.metadata, equals(original.metadata));
    });
  });

  // ===========================================================================
  // D11: Additional coverage tests
  // ===========================================================================

  group('FormatConfig.toJson with includeNextSteps=false', () {
    test('omits includeNextSteps when false', () {
      final format = FormatConfig(
        structure: Structure.prose,
        length: Length.standard,
        includeNextSteps: false,
      );

      final json = format.toJson();

      // includeNextSteps is conditionally included only when true
      expect(json.containsKey('includeNextSteps'), isFalse);
      expect(json['structure'], equals('prose'));
      expect(json['length'], equals('standard'));
    });

    test('includes includeNextSteps when true', () {
      final format = FormatConfig(
        structure: Structure.prose,
        length: Length.standard,
        includeNextSteps: true,
      );

      final json = format.toJson();

      expect(json.containsKey('includeNextSteps'), isTrue);
      expect(json['includeNextSteps'], isTrue);
    });
  });

  group('HedgingPhrases.fromJson with partial lists', () {
    test('parses json with only highUncertainty provided', () {
      final json = {
        'high_uncertainty': ['very uncertain about this'],
      };

      final phrases = HedgingPhrases.fromJson(json);

      expect(phrases.highUncertainty, isNotNull);
      expect(phrases.highUncertainty, contains('very uncertain about this'));
      expect(phrases.moderateUncertainty, isNull);
      expect(phrases.lowUncertainty, isNull);
      expect(phrases.qualifying, isNull);
      expect(phrases.probabilistic, isNull);
    });

    test('parses json with only probabilistic and qualifying', () {
      final json = {
        'qualifying': ['however', 'nonetheless'],
        'probabilistic': ['maybe'],
      };

      final phrases = HedgingPhrases.fromJson(json);

      expect(phrases.highUncertainty, isNull);
      expect(phrases.moderateUncertainty, isNull);
      expect(phrases.lowUncertainty, isNull);
      expect(phrases.qualifying, equals(['however', 'nonetheless']));
      expect(phrases.probabilistic, equals(['maybe']));
    });

    test('parses empty json map', () {
      final phrases = HedgingPhrases.fromJson(<String, dynamic>{});

      expect(phrases.highUncertainty, isNull);
      expect(phrases.moderateUncertainty, isNull);
      expect(phrases.lowUncertainty, isNull);
      expect(phrases.qualifying, isNull);
      expect(phrases.probabilistic, isNull);
    });
  });

  group('LanguageConfig with only grammar (no vocabulary)', () {
    test('creates LanguageConfig with grammar but no vocabulary', () {
      final config = LanguageConfig(
        grammar: GrammarConfig(
          voicePreference: VoicePreference.passive,
          sentenceComplexity: SentenceComplexity.simple,
          useContractions: true,
        ),
      );

      expect(config.locale, isNull);
      expect(config.vocabulary, isNull);
      expect(config.grammar, isNotNull);
      expect(config.grammar!.voicePreference, equals(VoicePreference.passive));
      expect(config.grammar!.sentenceComplexity, equals(SentenceComplexity.simple));
      expect(config.grammar!.useContractions, isTrue);
    });

    test('toJson with only grammar omits vocabulary and locale', () {
      final config = LanguageConfig(
        grammar: GrammarConfig(
          voicePreference: VoicePreference.mixed,
          sentenceComplexity: SentenceComplexity.complex,
          useContractions: false,
        ),
      );

      final json = config.toJson();

      expect(json.containsKey('locale'), isFalse);
      expect(json.containsKey('vocabulary'), isFalse);
      expect(json.containsKey('grammar'), isTrue);
      expect(json['grammar']['voicePreference'], equals('mixed'));
    });

    test('fromJson with only grammar', () {
      final json = {
        'grammar': {
          'voicePreference': 'active',
          'sentenceComplexity': 'moderate',
          'useContractions': false,
        },
      };

      final config = LanguageConfig.fromJson(json);

      expect(config.locale, isNull);
      expect(config.vocabulary, isNull);
      expect(config.grammar, isNotNull);
      expect(config.grammar!.voicePreference, equals(VoicePreference.active));
    });
  });

  group('AudiencePreferences.fromJson with missing fields', () {
    test('uses defaults when all fields are missing', () {
      final prefs = AudiencePreferences.fromJson(<String, dynamic>{});

      expect(prefs.preferredFormat, isNull);
      expect(prefs.avoidJargon, isFalse);
      expect(prefs.includeDefinitions, isFalse);
      expect(prefs.visualPreference, equals(VisualPreference.text));
    });

    test('uses defaults for missing boolean fields', () {
      final prefs = AudiencePreferences.fromJson({
        'preferredFormat': 'markdown',
      });

      expect(prefs.preferredFormat, equals('markdown'));
      expect(prefs.avoidJargon, isFalse);
      expect(prefs.includeDefinitions, isFalse);
      expect(prefs.visualPreference, equals(VisualPreference.text));
    });

    test('uses default visualPreference when invalid value', () {
      final prefs = AudiencePreferences.fromJson({
        'visualPreference': 'nonexistent_value',
      });

      // orElse falls back to VisualPreference.text
      expect(prefs.visualPreference, equals(VisualPreference.text));
    });
  });

  // ===========================================================================
  // fromJson orElse fallback coverage for invalid enum values
  // ===========================================================================

  group('ToneConfig.fromJson with invalid enum values', () {
    test('falls back to Formality.neutral for invalid formality', () {
      final tone = ToneConfig.fromJson({
        'formality': 'invalid_value',
        'confidence': 'moderate',
        'empathy': 'moderate',
        'directness': 'balanced',
      });
      expect(tone.formality, equals(Formality.neutral));
    });

    test('falls back to ToneConfidence.moderate for invalid confidence', () {
      final tone = ToneConfig.fromJson({
        'formality': 'neutral',
        'confidence': 'invalid_value',
        'empathy': 'moderate',
        'directness': 'balanced',
      });
      expect(tone.confidence, equals(ToneConfidence.moderate));
    });

    test('falls back to Empathy.moderate for invalid empathy', () {
      final tone = ToneConfig.fromJson({
        'formality': 'neutral',
        'confidence': 'moderate',
        'empathy': 'invalid_value',
        'directness': 'balanced',
      });
      expect(tone.empathy, equals(Empathy.moderate));
    });

    test('falls back to Directness.balanced for invalid directness', () {
      final tone = ToneConfig.fromJson({
        'formality': 'neutral',
        'confidence': 'moderate',
        'empathy': 'moderate',
        'directness': 'invalid_value',
      });
      expect(tone.directness, equals(Directness.balanced));
    });
  });

  group('FormatConfig.fromJson with invalid enum values', () {
    test('falls back to Structure.prose for invalid structure', () {
      final format = FormatConfig.fromJson({
        'structure': 'invalid_value',
        'length': 'standard',
      });
      expect(format.structure, equals(Structure.prose));
    });

    test('falls back to Length.standard for invalid length', () {
      final format = FormatConfig.fromJson({
        'structure': 'prose',
        'length': 'invalid_value',
      });
      expect(format.length, equals(Length.standard));
    });
  });

  group('HedgingConfig.fromJson with invalid enum values', () {
    test('falls back to HedgingLevel.none for invalid level', () {
      final config = HedgingConfig.fromJson({
        'level': 'invalid_value',
        'position': 'inline',
      });
      expect(config.level, equals(HedgingLevel.none));
    });

    test('falls back to HedgingPosition.inline for invalid position', () {
      final config = HedgingConfig.fromJson({
        'level': 'none',
        'position': 'invalid_value',
      });
      expect(config.position, equals(HedgingPosition.inline));
    });
  });

  group('AudienceConfig.fromJson with invalid enum values', () {
    test('falls back to Expertise.intermediate for invalid expertise', () {
      final config = AudienceConfig.fromJson({
        'expertise': 'invalid_value',
        'context': 'internal',
      });
      expect(config.expertise, equals(Expertise.intermediate));
    });

    test('falls back to AudienceContext.internal for invalid context', () {
      final config = AudienceConfig.fromJson({
        'expertise': 'intermediate',
        'context': 'invalid_value',
      });
      expect(config.context, equals(AudienceContext.internal));
    });
  });

  group('VocabularyConfig.fromJson with invalid enum values', () {
    test('falls back to JargonLevel.standard for invalid jargonLevel', () {
      final config = VocabularyConfig.fromJson({
        'jargonLevel': 'invalid_value',
      });
      expect(config.jargonLevel, equals(JargonLevel.standard));
    });
  });

  group('GrammarConfig.fromJson with invalid enum values', () {
    test('falls back to VoicePreference.active for invalid voicePreference', () {
      final config = GrammarConfig.fromJson({
        'voicePreference': 'invalid_value',
        'sentenceComplexity': 'moderate',
        'useContractions': false,
      });
      expect(config.voicePreference, equals(VoicePreference.active));
    });

    test('falls back to SentenceComplexity.moderate for invalid sentenceComplexity', () {
      final config = GrammarConfig.fromJson({
        'voicePreference': 'active',
        'sentenceComplexity': 'invalid_value',
        'useContractions': false,
      });
      expect(config.sentenceComplexity, equals(SentenceComplexity.moderate));
    });
  });
}
