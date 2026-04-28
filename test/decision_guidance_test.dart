/// DecisionGuidance Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  // ===========================================================================
  // DecisionAction
  // ===========================================================================

  group('DecisionAction', () {
    test('has all 8 expected values', () {
      expect(DecisionAction.values.length, equals(8));
      expect(DecisionAction.values, containsAll([
        DecisionAction.proceed,
        DecisionAction.proceedWithCaution,
        DecisionAction.hold,
        DecisionAction.question,
        DecisionAction.escalate,
        DecisionAction.reject,
        DecisionAction.defer,
        DecisionAction.custom,
      ]));
    });

    test('toJsonName returns correct strings', () {
      expect(DecisionAction.proceed.toJsonName(), equals('proceed'));
      expect(
        DecisionAction.proceedWithCaution.toJsonName(),
        equals('proceed_with_caution'),
      );
      expect(DecisionAction.hold.toJsonName(), equals('hold'));
      expect(DecisionAction.question.toJsonName(), equals('question'));
      expect(DecisionAction.escalate.toJsonName(), equals('escalate'));
      expect(DecisionAction.reject.toJsonName(), equals('reject'));
      expect(DecisionAction.defer.toJsonName(), equals('defer'));
      expect(DecisionAction.custom.toJsonName(), equals('custom'));
    });

    test('fromJsonName parses known names', () {
      expect(
        DecisionActionExtension.fromJsonName('proceed'),
        equals(DecisionAction.proceed),
      );
      expect(
        DecisionActionExtension.fromJsonName('proceed_with_caution'),
        equals(DecisionAction.proceedWithCaution),
      );
      expect(
        DecisionActionExtension.fromJsonName('hold'),
        equals(DecisionAction.hold),
      );
      expect(
        DecisionActionExtension.fromJsonName('question'),
        equals(DecisionAction.question),
      );
      expect(
        DecisionActionExtension.fromJsonName('escalate'),
        equals(DecisionAction.escalate),
      );
      expect(
        DecisionActionExtension.fromJsonName('reject'),
        equals(DecisionAction.reject),
      );
      expect(
        DecisionActionExtension.fromJsonName('defer'),
        equals(DecisionAction.defer),
      );
      expect(
        DecisionActionExtension.fromJsonName('custom'),
        equals(DecisionAction.custom),
      );
    });

    test('fromJsonName defaults to proceed for unknown name', () {
      expect(
        DecisionActionExtension.fromJsonName('unknown_action'),
        equals(DecisionAction.proceed),
      );
    });

    test('allowsProceeding is true for proceed and proceedWithCaution', () {
      expect(DecisionAction.proceed.allowsProceeding, isTrue);
      expect(DecisionAction.proceedWithCaution.allowsProceeding, isTrue);
    });

    test('allowsProceeding is false for non-proceeding actions', () {
      expect(DecisionAction.reject.allowsProceeding, isFalse);
      expect(DecisionAction.hold.allowsProceeding, isFalse);
      expect(DecisionAction.escalate.allowsProceeding, isFalse);
      expect(DecisionAction.question.allowsProceeding, isFalse);
      expect(DecisionAction.defer.allowsProceeding, isFalse);
      expect(DecisionAction.custom.allowsProceeding, isFalse);
    });

    test('blocksProceeding is true for hold, reject, and defer', () {
      expect(DecisionAction.hold.blocksProceeding, isTrue);
      expect(DecisionAction.reject.blocksProceeding, isTrue);
      expect(DecisionAction.defer.blocksProceeding, isTrue);
    });

    test('blocksProceeding is false for non-blocking actions', () {
      expect(DecisionAction.proceed.blocksProceeding, isFalse);
      expect(DecisionAction.proceedWithCaution.blocksProceeding, isFalse);
      expect(DecisionAction.escalate.blocksProceeding, isFalse);
      expect(DecisionAction.question.blocksProceeding, isFalse);
      expect(DecisionAction.custom.blocksProceeding, isFalse);
    });

    test('requiresHuman is true for escalate and question', () {
      expect(DecisionAction.escalate.requiresHuman, isTrue);
      expect(DecisionAction.question.requiresHuman, isTrue);
    });

    test('requiresHuman is false for non-human-required actions', () {
      expect(DecisionAction.proceed.requiresHuman, isFalse);
      expect(DecisionAction.proceedWithCaution.requiresHuman, isFalse);
      expect(DecisionAction.hold.requiresHuman, isFalse);
      expect(DecisionAction.reject.requiresHuman, isFalse);
      expect(DecisionAction.defer.requiresHuman, isFalse);
      expect(DecisionAction.custom.requiresHuman, isFalse);
    });
  });

  // ===========================================================================
  // ModifierType
  // ===========================================================================

  group('ModifierType', () {
    test('has all 9 expected values', () {
      expect(ModifierType.values.length, equals(9));
      expect(ModifierType.values, containsAll([
        ModifierType.requireEvidence,
        ModifierType.requireApproval,
        ModifierType.addDisclaimer,
        ModifierType.limitScope,
        ModifierType.reduceConfidence,
        ModifierType.increaseValidation,
        ModifierType.notify,
        ModifierType.log,
        ModifierType.custom,
      ]));
    });

    test('toJsonName returns correct strings', () {
      expect(
        ModifierType.requireEvidence.toJsonName(),
        equals('require_evidence'),
      );
      expect(
        ModifierType.requireApproval.toJsonName(),
        equals('require_approval'),
      );
      expect(
        ModifierType.addDisclaimer.toJsonName(),
        equals('add_disclaimer'),
      );
      expect(ModifierType.limitScope.toJsonName(), equals('limit_scope'));
      expect(
        ModifierType.reduceConfidence.toJsonName(),
        equals('reduce_confidence'),
      );
      expect(
        ModifierType.increaseValidation.toJsonName(),
        equals('increase_validation'),
      );
      expect(ModifierType.notify.toJsonName(), equals('notify'));
      expect(ModifierType.log.toJsonName(), equals('log'));
      expect(ModifierType.custom.toJsonName(), equals('custom'));
    });
  });

  // ===========================================================================
  // DecisionModifier
  // ===========================================================================

  group('DecisionModifier', () {
    test('creates with type and config', () {
      const modifier = DecisionModifier(
        type: ModifierType.log,
        config: {'level': 'info'},
      );
      expect(modifier.type, equals(ModifierType.log));
      expect(modifier.config, isNotNull);
      expect(modifier.config!['level'], equals('info'));
    });

    test('creates with type and null config', () {
      const modifier = DecisionModifier(type: ModifierType.custom);
      expect(modifier.type, equals(ModifierType.custom));
      expect(modifier.config, isNull);
    });

    test('getConfig returns typed value', () {
      const modifier = DecisionModifier(
        type: ModifierType.log,
        config: {'level': 'warning', 'count': 3},
      );
      expect(modifier.getConfig<String>('level'), equals('warning'));
      expect(modifier.getConfig<int>('count'), equals(3));
    });

    test('getConfig returns null for missing key', () {
      const modifier = DecisionModifier(
        type: ModifierType.log,
        config: {'level': 'info'},
      );
      expect(modifier.getConfig<String>('missing'), isNull);
    });

    test('getConfig returns null when config is null', () {
      const modifier = DecisionModifier(type: ModifierType.custom);
      expect(modifier.getConfig<String>('any'), isNull);
    });

    test('getConfig returns null for type mismatch', () {
      const modifier = DecisionModifier(
        type: ModifierType.log,
        config: {'level': 'info'},
      );
      expect(modifier.getConfig<int>('level'), isNull);
    });

    group('factory constructors', () {
      test('requireEvidence creates correct modifier', () {
        final modifier = DecisionModifier.requireEvidence(
          minSources: 3,
          evidenceTypes: ['citation', 'data'],
        );
        expect(modifier.type, equals(ModifierType.requireEvidence));
        expect(modifier.getConfig<int>('minSources'), equals(3));
        expect(modifier.config!['evidenceTypes'], contains('citation'));
        expect(modifier.config!['evidenceTypes'], contains('data'));
      });

      test('requireEvidence uses defaults', () {
        final modifier = DecisionModifier.requireEvidence();
        expect(modifier.getConfig<int>('minSources'), equals(1));
        expect(modifier.config!.containsKey('evidenceTypes'), isFalse);
      });

      test('requireApproval creates correct modifier', () {
        final modifier = DecisionModifier.requireApproval(
          approverRole: 'risk_officer',
          expiresIn: '24h',
        );
        expect(modifier.type, equals(ModifierType.requireApproval));
        expect(
          modifier.getConfig<String>('approverRole'),
          equals('risk_officer'),
        );
        expect(modifier.getConfig<String>('expiresIn'), equals('24h'));
      });

      test('requireApproval without expiresIn', () {
        final modifier = DecisionModifier.requireApproval(
          approverRole: 'admin',
        );
        expect(modifier.config!.containsKey('expiresIn'), isFalse);
      });

      test('addDisclaimer creates correct modifier', () {
        final modifier = DecisionModifier.addDisclaimer(
          text: 'High risk content',
          position: 'end',
        );
        expect(modifier.type, equals(ModifierType.addDisclaimer));
        expect(
          modifier.getConfig<String>('text'),
          equals('High risk content'),
        );
        expect(modifier.getConfig<String>('position'), equals('end'));
      });

      test('addDisclaimer defaults position to start', () {
        final modifier = DecisionModifier.addDisclaimer(
          text: 'Warning',
        );
        expect(modifier.getConfig<String>('position'), equals('start'));
      });

      test('notify creates correct modifier', () {
        final modifier = DecisionModifier.notify(
          channels: ['email', 'slack'],
          recipients: ['admin@example.com'],
          template: 'risk_alert',
          urgency: 'high',
        );
        expect(modifier.type, equals(ModifierType.notify));
        expect(modifier.config!['channels'], contains('email'));
        expect(modifier.config!['channels'], contains('slack'));
        expect(modifier.config!['recipients'], contains('admin@example.com'));
        expect(modifier.getConfig<String>('template'), equals('risk_alert'));
        expect(modifier.getConfig<String>('urgency'), equals('high'));
      });

      test('notify defaults urgency to normal', () {
        final modifier = DecisionModifier.notify(
          channels: ['email'],
          recipients: ['user@example.com'],
        );
        expect(modifier.getConfig<String>('urgency'), equals('normal'));
        expect(modifier.config!.containsKey('template'), isFalse);
      });

      test('log creates correct modifier', () {
        final modifier = DecisionModifier.log(level: 'error');
        expect(modifier.type, equals(ModifierType.log));
        expect(modifier.getConfig<String>('level'), equals('error'));
      });

      test('log defaults level to info', () {
        final modifier = DecisionModifier.log();
        expect(modifier.getConfig<String>('level'), equals('info'));
      });
    });

    test('fromJson creates correct instance', () {
      final json = {
        'type': 'require_approval',
        'config': {
          'approverRole': 'manager',
        },
      };
      final modifier = DecisionModifier.fromJson(json);
      expect(modifier.type, equals(ModifierType.requireApproval));
      expect(
        modifier.getConfig<String>('approverRole'),
        equals('manager'),
      );
    });

    test('fromJson without config', () {
      final json = {
        'type': 'log',
      };
      final modifier = DecisionModifier.fromJson(json);
      expect(modifier.type, equals(ModifierType.log));
      expect(modifier.config, isNull);
    });

    test('fromJson defaults to custom for unknown type', () {
      final json = {
        'type': 'totally_unknown',
      };
      final modifier = DecisionModifier.fromJson(json);
      expect(modifier.type, equals(ModifierType.custom));
    });

    test('toJson produces correct output', () {
      final modifier = DecisionModifier.log(level: 'warning');
      final json = modifier.toJson();
      expect(json['type'], equals('log'));
      expect(json['config'], isNotNull);
      expect((json['config'] as Map)['level'], equals('warning'));
    });

    test('toJson omits config when null', () {
      const modifier = DecisionModifier(type: ModifierType.custom);
      final json = modifier.toJson();
      expect(json['type'], equals('custom'));
      expect(json.containsKey('config'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves data', () {
      final original = DecisionModifier.requireApproval(
        approverRole: 'director',
        expiresIn: '48h',
      );
      final json = original.toJson();
      final restored = DecisionModifier.fromJson(json);
      expect(restored.type, equals(original.type));
      expect(
        restored.getConfig<String>('approverRole'),
        equals('director'),
      );
      expect(restored.getConfig<String>('expiresIn'), equals('48h'));
    });
  });

  // ===========================================================================
  // DecisionGuidance
  // ===========================================================================

  group('DecisionGuidance', () {
    test('creates with required and optional fields', () {
      final guidance = DecisionGuidance(
        action: DecisionAction.escalate,
        confidence: 0.85,
        explanation: 'High risk detected',
        modifiers: [
          DecisionModifier.requireApproval(approverRole: 'admin'),
        ],
        metadata: {'source': 'auto'},
      );
      expect(guidance.action, equals(DecisionAction.escalate));
      expect(guidance.confidence, equals(0.85));
      expect(guidance.explanation, equals('High risk detected'));
      expect(guidance.modifiers.length, equals(1));
      expect(guidance.metadata, isNotNull);
      expect(guidance.metadata!['source'], equals('auto'));
    });

    test('creates with defaults', () {
      const guidance = DecisionGuidance(action: DecisionAction.proceed);
      expect(guidance.confidence, isNull);
      expect(guidance.explanation, isNull);
      expect(guidance.modifiers, isEmpty);
      expect(guidance.metadata, isNull);
    });

    test('requiresApproval returns true when approval modifier present', () {
      final guidance = DecisionGuidance(
        action: DecisionAction.escalate,
        modifiers: [
          DecisionModifier.requireApproval(approverRole: 'admin'),
        ],
      );
      expect(guidance.requiresApproval, isTrue);
    });

    test('requiresApproval returns false when no approval modifier', () {
      final guidance = DecisionGuidance(
        action: DecisionAction.proceed,
        modifiers: [
          DecisionModifier.log(level: 'info'),
        ],
      );
      expect(guidance.requiresApproval, isFalse);
    });

    test('requiresApproval returns false when no modifiers', () {
      const guidance = DecisionGuidance(action: DecisionAction.proceed);
      expect(guidance.requiresApproval, isFalse);
    });

    test('requiresEvidence returns true when evidence modifier present', () {
      final guidance = DecisionGuidance(
        action: DecisionAction.question,
        modifiers: [
          DecisionModifier.requireEvidence(minSources: 2),
        ],
      );
      expect(guidance.requiresEvidence, isTrue);
    });

    test('requiresEvidence returns false when no evidence modifier', () {
      const guidance = DecisionGuidance(action: DecisionAction.proceed);
      expect(guidance.requiresEvidence, isFalse);
    });

    test('getModifiers returns matching modifiers', () {
      final guidance = DecisionGuidance(
        action: DecisionAction.escalate,
        modifiers: [
          DecisionModifier.log(level: 'info'),
          DecisionModifier.requireApproval(approverRole: 'admin'),
          DecisionModifier.log(level: 'warning'),
        ],
      );
      final logModifiers = guidance.getModifiers(ModifierType.log);
      expect(logModifiers.length, equals(2));

      final approvalModifiers =
          guidance.getModifiers(ModifierType.requireApproval);
      expect(approvalModifiers.length, equals(1));
    });

    test('getModifiers returns empty list when none match', () {
      const guidance = DecisionGuidance(action: DecisionAction.proceed);
      final result = guidance.getModifiers(ModifierType.notify);
      expect(result, isEmpty);
    });

    test('defaultProceed has action proceed and confidence 1.0', () {
      expect(
        DecisionGuidance.defaultProceed.action,
        equals(DecisionAction.proceed),
      );
      expect(DecisionGuidance.defaultProceed.confidence, equals(1.0));
      expect(DecisionGuidance.defaultProceed.modifiers, isEmpty);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'action': 'escalate',
        'confidence': 0.85,
        'explanation': 'Risk is high',
        'modifiers': [
          {
            'type': 'require_approval',
            'config': {'approverRole': 'admin'},
          },
        ],
        'metadata': {'source': 'auto'},
      };
      final guidance = DecisionGuidance.fromJson(json);
      expect(guidance.action, equals(DecisionAction.escalate));
      expect(guidance.confidence, equals(0.85));
      expect(guidance.explanation, equals('Risk is high'));
      expect(guidance.modifiers.length, equals(1));
      expect(
        guidance.modifiers.first.type,
        equals(ModifierType.requireApproval),
      );
      expect(guidance.metadata!['source'], equals('auto'));
    });

    test('fromJson with minimal fields', () {
      final json = {'action': 'proceed'};
      final guidance = DecisionGuidance.fromJson(json);
      expect(guidance.action, equals(DecisionAction.proceed));
      expect(guidance.confidence, isNull);
      expect(guidance.explanation, isNull);
      expect(guidance.modifiers, isEmpty);
      expect(guidance.metadata, isNull);
    });

    test('toJson produces correct output', () {
      final guidance = DecisionGuidance(
        action: DecisionAction.reject,
        confidence: 0.95,
        explanation: 'Critical risk',
        modifiers: [
          DecisionModifier.log(level: 'error'),
        ],
      );
      final json = guidance.toJson();
      expect(json['action'], equals('reject'));
      expect(json['confidence'], equals(0.95));
      expect(json['explanation'], equals('Critical risk'));
      expect(json['modifiers'], isNotNull);
      expect((json['modifiers'] as List).length, equals(1));
    });

    test('toJson omits null/empty optional fields', () {
      const guidance = DecisionGuidance(action: DecisionAction.proceed);
      final json = guidance.toJson();
      expect(json['action'], equals('proceed'));
      expect(json.containsKey('confidence'), isFalse);
      expect(json.containsKey('explanation'), isFalse);
      expect(json.containsKey('modifiers'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves data', () {
      final original = DecisionGuidance(
        action: DecisionAction.proceedWithCaution,
        confidence: 0.75,
        explanation: 'Moderate risk',
        modifiers: [
          DecisionModifier.addDisclaimer(text: 'Use with caution'),
          DecisionModifier.log(level: 'warning'),
        ],
        metadata: {'evaluatedAt': '2026-01-01'},
      );
      final json = original.toJson();
      final restored = DecisionGuidance.fromJson(json);
      expect(restored.action, equals(original.action));
      expect(restored.confidence, equals(original.confidence));
      expect(restored.explanation, equals(original.explanation));
      expect(restored.modifiers.length, equals(original.modifiers.length));
      expect(restored.metadata!['evaluatedAt'], equals('2026-01-01'));
    });
  });
}
