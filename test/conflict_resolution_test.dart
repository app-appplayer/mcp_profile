/// Tests for conflict resolution strategies and ConflictResolver
/// implementations from src/runtime/conflict_resolution.dart.
library;

import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

void main() {
  // Shared test guidance values.
  const proceed = DecisionGuidance(
    action: DecisionAction.proceed,
    explanation: 'ok',
  );
  const reject = DecisionGuidance(
    action: DecisionAction.reject,
    explanation: 'no',
  );
  const escalate = DecisionGuidance(
    action: DecisionAction.escalate,
    explanation: 'up',
  );
  const hold = DecisionGuidance(
    action: DecisionAction.hold,
    explanation: 'wait',
  );
  const question = DecisionGuidance(
    action: DecisionAction.question,
    explanation: 'ask',
  );
  const defer = DecisionGuidance(
    action: DecisionAction.defer,
    explanation: 'later',
  );
  const custom = DecisionGuidance(
    action: DecisionAction.custom,
    explanation: 'custom',
  );
  const proceedWithCaution = DecisionGuidance(
    action: DecisionAction.proceedWithCaution,
    explanation: 'careful',
  );

  // ---------------------------------------------------------------------------
  // resolveConflictingGuidance - 9 strategies
  // ---------------------------------------------------------------------------
  group('resolveConflictingGuidance', () {
    test('empty list returns defaultProceed', () {
      final result = resolveConflictingGuidance(
        [],
        ConflictResolution.firstMatch,
      );
      expect(result.action, DecisionAction.proceed);
    });

    test('single item returns that item', () {
      final result = resolveConflictingGuidance(
        [reject],
        ConflictResolution.firstMatch,
      );
      expect(result, same(reject));
    });

    test('firstMatch returns first item', () {
      final result = resolveConflictingGuidance(
        [proceed, reject],
        ConflictResolution.firstMatch,
      );
      expect(result, same(proceed));
    });

    test('lastMatch returns last item', () {
      final result = resolveConflictingGuidance(
        [proceed, reject],
        ConflictResolution.lastMatch,
      );
      expect(result, same(reject));
    });

    test('highestPriority returns first (already sorted)', () {
      final result = resolveConflictingGuidance(
        [escalate, proceed],
        ConflictResolution.highestPriority,
      );
      expect(result, same(escalate));
    });

    test('mostRestrictive returns the most restrictive action', () {
      // Order: reject > escalate > hold > question > defer > custom >
      //        proceedWithCaution > proceed
      final result = resolveConflictingGuidance(
        [proceed, escalate, hold],
        ConflictResolution.mostRestrictive,
      );
      expect(result.action, DecisionAction.escalate);
    });

    test('mostRestrictive ordering: reject beats all', () {
      final result = resolveConflictingGuidance(
        [proceed, reject, escalate, hold, question, defer, custom,
         proceedWithCaution],
        ConflictResolution.mostRestrictive,
      );
      expect(result.action, DecisionAction.reject);
    });

    test('mostSpecific returns last', () {
      final result = resolveConflictingGuidance(
        [proceed, reject],
        ConflictResolution.mostSpecific,
      );
      expect(result, same(reject));
    });

    test('unanimous: all same action returns that action', () {
      const p1 = DecisionGuidance(
        action: DecisionAction.hold,
        explanation: 'a',
      );
      const p2 = DecisionGuidance(
        action: DecisionAction.hold,
        explanation: 'b',
      );
      final result = resolveConflictingGuidance(
        [p1, p2],
        ConflictResolution.unanimous,
      );
      expect(result.action, DecisionAction.hold);
    });

    test('unanimous: mixed falls back to mostRestrictive', () {
      final result = resolveConflictingGuidance(
        [proceed, hold],
        ConflictResolution.unanimous,
      );
      // mostRestrictive picks hold over proceed
      expect(result.action, DecisionAction.hold);
    });

    test('majority: most common action wins', () {
      const hold2 = DecisionGuidance(
        action: DecisionAction.hold,
        explanation: 'wait more',
      );
      final result = resolveConflictingGuidance(
        [hold, hold2, proceed],
        ConflictResolution.majority,
      );
      expect(result.action, DecisionAction.hold);
    });

    test('merge: combines modifiers from all, uses first action', () {
      final g1 = DecisionGuidance(
        action: DecisionAction.proceedWithCaution,
        explanation: 'care',
        modifiers: [
          DecisionModifier.log(level: 'warning'),
        ],
      );
      final g2 = DecisionGuidance(
        action: DecisionAction.proceed,
        explanation: 'fine',
        modifiers: [
          DecisionModifier.requireEvidence(minSources: 2),
        ],
      );
      final result = resolveConflictingGuidance(
        [g1, g2],
        ConflictResolution.merge,
      );
      expect(result.action, DecisionAction.proceedWithCaution);
      expect(result.explanation, equals('care'));
      expect(result.modifiers, hasLength(2));
    });

    test('custom returns first (fallback)', () {
      final result = resolveConflictingGuidance(
        [hold, proceed],
        ConflictResolution.custom,
      );
      expect(result, same(hold));
    });
  });

  // ---------------------------------------------------------------------------
  // ConflictResolver implementations
  // ---------------------------------------------------------------------------
  group('ConflictResolver implementations', () {
    test('FirstMatchResolver resolves as firstMatch', () {
      const resolver = FirstMatchResolver();
      final result = resolver.resolve([proceed, reject]);
      expect(result.action, DecisionAction.proceed);
    });

    test('HighestPriorityResolver resolves as highestPriority', () {
      const resolver = HighestPriorityResolver();
      final result = resolver.resolve([escalate, proceed]);
      expect(result.action, DecisionAction.escalate);
    });

    test('MostRestrictiveResolver resolves as mostRestrictive', () {
      const resolver = MostRestrictiveResolver();
      final result = resolver.resolve([proceed, hold]);
      expect(result.action, DecisionAction.hold);
    });

    test('MergeResolver resolves as merge', () {
      const resolver = MergeResolver();
      final g1 = DecisionGuidance(
        action: DecisionAction.proceed,
        explanation: 'ok',
        modifiers: [DecisionModifier.log()],
      );
      final g2 = DecisionGuidance(
        action: DecisionAction.hold,
        explanation: 'wait',
        modifiers: [DecisionModifier.requireEvidence()],
      );
      final result = resolver.resolve([g1, g2]);
      // First action wins in merge
      expect(result.action, DecisionAction.proceed);
      expect(result.modifiers, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // createResolver factory
  // ---------------------------------------------------------------------------
  group('createResolver', () {
    test('returns resolver for each strategy', () {
      for (final strategy in ConflictResolution.values) {
        final resolver = createResolver(strategy);
        expect(resolver, isA<ConflictResolver>());

        // Verify it can resolve without throwing
        final result = resolver.resolve([proceed, reject]);
        expect(result, isA<DecisionGuidance>());
      }
    });

    test('returned resolver delegates to resolveConflictingGuidance', () {
      final resolver = createResolver(ConflictResolution.lastMatch);
      final result = resolver.resolve([proceed, reject]);
      expect(result.action, DecisionAction.reject);
    });
  });
}
