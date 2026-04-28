/// PolicyCondition Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  // ===========================================================================
  // ComparisonOperator
  // ===========================================================================

  group('ComparisonOperator', () {
    test('has all 8 expected values', () {
      expect(ComparisonOperator.values.length, equals(8));
      expect(ComparisonOperator.values, containsAll([
        ComparisonOperator.greaterThan,
        ComparisonOperator.greaterThanOrEqual,
        ComparisonOperator.lessThan,
        ComparisonOperator.lessThanOrEqual,
        ComparisonOperator.equal,
        ComparisonOperator.notEqual,
        ComparisonOperator.between,
        ComparisonOperator.outside,
      ]));
    });

    test('toJsonString maps greaterThan to ">"', () {
      expect(ComparisonOperator.greaterThan.toJsonString(), equals('>'));
    });

    test('toJsonString maps greaterThanOrEqual to ">="', () {
      expect(ComparisonOperator.greaterThanOrEqual.toJsonString(), equals('>='));
    });

    test('toJsonString maps lessThan to "<"', () {
      expect(ComparisonOperator.lessThan.toJsonString(), equals('<'));
    });

    test('toJsonString maps lessThanOrEqual to "<="', () {
      expect(ComparisonOperator.lessThanOrEqual.toJsonString(), equals('<='));
    });

    test('toJsonString maps equal to "=="', () {
      expect(ComparisonOperator.equal.toJsonString(), equals('=='));
    });

    test('toJsonString maps notEqual to "!="', () {
      expect(ComparisonOperator.notEqual.toJsonString(), equals('!='));
    });

    test('toJsonString maps between to "between"', () {
      expect(ComparisonOperator.between.toJsonString(), equals('between'));
    });

    test('toJsonString maps outside to "outside"', () {
      expect(ComparisonOperator.outside.toJsonString(), equals('outside'));
    });
  });

  // ===========================================================================
  // ThresholdCondition
  // ===========================================================================

  group('ThresholdCondition', () {
    test('greaterThan returns true when metric exceeds value', () {
      const condition = ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
      );
      final result = condition.evaluate({'risk': 0.8}, 0.0);
      expect(result, isTrue);
    });

    test('greaterThan returns false when metric is below value', () {
      const condition = ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
      );
      final result = condition.evaluate({'risk': 0.3}, 0.0);
      expect(result, isFalse);
    });

    test('greaterThan returns false when metric equals value', () {
      const condition = ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
      );
      final result = condition.evaluate({'risk': 0.5}, 0.0);
      expect(result, isFalse);
    });

    test('greaterThanOrEqual returns true when metric equals value', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.greaterThanOrEqual,
        value: 0.7,
      );
      final result = condition.evaluate({'score': 0.7}, 0.0);
      expect(result, isTrue);
    });

    test('lessThan returns true when metric is below value', () {
      const condition = ThresholdCondition(
        metric: 'confidence',
        operator: ComparisonOperator.lessThan,
        value: 0.5,
      );
      final result = condition.evaluate({'confidence': 0.3}, 0.0);
      expect(result, isTrue);
    });

    test('lessThan returns false when metric equals value', () {
      const condition = ThresholdCondition(
        metric: 'confidence',
        operator: ComparisonOperator.lessThan,
        value: 0.5,
      );
      final result = condition.evaluate({'confidence': 0.5}, 0.0);
      expect(result, isFalse);
    });

    test('lessThanOrEqual returns true when metric equals value', () {
      const condition = ThresholdCondition(
        metric: 'confidence',
        operator: ComparisonOperator.lessThanOrEqual,
        value: 0.5,
      );
      final result = condition.evaluate({'confidence': 0.5}, 0.0);
      expect(result, isTrue);
    });

    test('equal returns true when metric matches value', () {
      const condition = ThresholdCondition(
        metric: 'tier',
        operator: ComparisonOperator.equal,
        value: 1.0,
      );
      final result = condition.evaluate({'tier': 1.0}, 0.0);
      expect(result, isTrue);
    });

    test('equal returns false when metric does not match value', () {
      const condition = ThresholdCondition(
        metric: 'tier',
        operator: ComparisonOperator.equal,
        value: 1.0,
      );
      final result = condition.evaluate({'tier': 2.0}, 0.0);
      expect(result, isFalse);
    });

    test('notEqual returns true when metric differs from value', () {
      const condition = ThresholdCondition(
        metric: 'tier',
        operator: ComparisonOperator.notEqual,
        value: 1.0,
      );
      final result = condition.evaluate({'tier': 2.0}, 0.0);
      expect(result, isTrue);
    });

    test('notEqual returns false when metric matches value', () {
      const condition = ThresholdCondition(
        metric: 'tier',
        operator: ComparisonOperator.notEqual,
        value: 1.0,
      );
      final result = condition.evaluate({'tier': 1.0}, 0.0);
      expect(result, isFalse);
    });

    test('between returns true when metric is within range (inclusive)', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.between,
        value: [0.3, 0.7],
      );
      expect(condition.evaluate({'score': 0.5}, 0.0), isTrue);
      // Boundaries are inclusive
      expect(condition.evaluate({'score': 0.3}, 0.0), isTrue);
      expect(condition.evaluate({'score': 0.7}, 0.0), isTrue);
    });

    test('between returns false when metric is outside range', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.between,
        value: [0.3, 0.7],
      );
      expect(condition.evaluate({'score': 0.1}, 0.0), isFalse);
      expect(condition.evaluate({'score': 0.9}, 0.0), isFalse);
    });

    test('outside returns true when metric is outside range', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.outside,
        value: [0.3, 0.7],
      );
      expect(condition.evaluate({'score': 0.1}, 0.0), isTrue);
      expect(condition.evaluate({'score': 0.9}, 0.0), isTrue);
    });

    test('outside returns false when metric is within range', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.outside,
        value: [0.3, 0.7],
      );
      expect(condition.evaluate({'score': 0.5}, 0.0), isFalse);
    });

    test('returns false when metric is not found in map', () {
      const condition = ThresholdCondition(
        metric: 'missing',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
      );
      final result = condition.evaluate({'risk': 0.8}, 0.0);
      expect(result, isFalse);
    });

    test('uses aggregatedScore when metric is "aggregatedScore"', () {
      const condition = ThresholdCondition(
        metric: 'aggregatedScore',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
      );
      final result = condition.evaluate({}, 0.9);
      expect(result, isTrue);

      final resultFalse = condition.evaluate({}, 0.3);
      expect(resultFalse, isFalse);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'type': 'threshold',
        'metric': 'risk',
        'operator': '>',
        'value': 0.5,
      };
      final condition = ThresholdCondition.fromJson(json);
      expect(condition.metric, equals('risk'));
      expect(condition.operator, equals(ComparisonOperator.greaterThan));
      expect(condition.value, equals(0.5));
    });

    test('toJson produces correct output', () {
      const condition = ThresholdCondition(
        metric: 'risk',
        operator: ComparisonOperator.greaterThan,
        value: 0.5,
      );
      final json = condition.toJson();
      expect(json['type'], equals('threshold'));
      expect(json['metric'], equals('risk'));
      expect(json['operator'], equals('>'));
      expect(json['value'], equals(0.5));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = ThresholdCondition(
        metric: 'uncertainty',
        operator: ComparisonOperator.lessThanOrEqual,
        value: 0.3,
      );
      final json = original.toJson();
      final restored = ThresholdCondition.fromJson(json);
      expect(restored.metric, equals(original.metric));
      expect(restored.operator, equals(original.operator));
      expect(restored.value, equals(original.value));
    });
  });

  // ===========================================================================
  // ExpressionCondition
  // ===========================================================================

  group('ExpressionCondition', () {
    test('evaluates simple comparison "risk > 0.5"', () {
      const condition = ExpressionCondition(expression: 'risk > 0.5');
      expect(condition.evaluate({'risk': 0.8}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 0.3}, 0.0), isFalse);
    });

    test('evaluates AND expression "risk > 0.3 && uncertainty < 0.8"', () {
      const condition = ExpressionCondition(
        expression: 'risk > 0.3 && uncertainty < 0.8',
      );
      // Both conditions met
      expect(
        condition.evaluate({'risk': 0.5, 'uncertainty': 0.5}, 0.0),
        isTrue,
      );
      // First condition fails
      expect(
        condition.evaluate({'risk': 0.1, 'uncertainty': 0.5}, 0.0),
        isFalse,
      );
      // Second condition fails
      expect(
        condition.evaluate({'risk': 0.5, 'uncertainty': 0.9}, 0.0),
        isFalse,
      );
    });

    test('evaluates OR expression "risk > 0.9 || uncertainty > 0.9"', () {
      const condition = ExpressionCondition(
        expression: 'risk > 0.9 || uncertainty > 0.9',
      );
      // Only first met
      expect(
        condition.evaluate({'risk': 0.95, 'uncertainty': 0.5}, 0.0),
        isTrue,
      );
      // Only second met
      expect(
        condition.evaluate({'risk': 0.5, 'uncertainty': 0.95}, 0.0),
        isTrue,
      );
      // Neither met
      expect(
        condition.evaluate({'risk': 0.5, 'uncertainty': 0.5}, 0.0),
        isFalse,
      );
    });

    test('evaluates NOT expression "!(risk > 0.5)"', () {
      const condition = ExpressionCondition(expression: '!(risk > 0.5)');
      expect(condition.evaluate({'risk': 0.3}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 0.8}, 0.0), isFalse);
    });

    test('evaluates parenthesized expression', () {
      const condition = ExpressionCondition(expression: '(risk > 0.5)');
      expect(condition.evaluate({'risk': 0.8}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 0.3}, 0.0), isFalse);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'type': 'expression',
        'expression': 'risk > 0.5',
      };
      final condition = ExpressionCondition.fromJson(json);
      expect(condition.expression, equals('risk > 0.5'));
    });

    test('toJson produces correct output', () {
      const condition = ExpressionCondition(expression: 'risk > 0.5');
      final json = condition.toJson();
      expect(json['type'], equals('expression'));
      expect(json['expression'], equals('risk > 0.5'));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = ExpressionCondition(
        expression: 'risk > 0.3 && uncertainty < 0.8',
      );
      final json = original.toJson();
      final restored = ExpressionCondition.fromJson(json);
      expect(restored.expression, equals(original.expression));
    });
  });

  // ===========================================================================
  // AlwaysTrueCondition
  // ===========================================================================

  group('AlwaysTrueCondition', () {
    test('evaluate always returns true', () {
      const condition = AlwaysTrueCondition();
      expect(condition.evaluate({}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 1.0}, 0.5), isTrue);
    });

    test('toJson returns type always_true', () {
      const condition = AlwaysTrueCondition();
      final json = condition.toJson();
      expect(json, equals({'type': 'always_true'}));
    });
  });

  // ===========================================================================
  // CompositeCondition
  // ===========================================================================

  group('CompositeCondition', () {
    test('all (AND) returns true when all conditions are true', () {
      const condition = CompositeCondition(
        all: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.3,
          ),
          ThresholdCondition(
            metric: 'uncertainty',
            operator: ComparisonOperator.lessThan,
            value: 0.8,
          ),
        ],
      );
      final result = condition.evaluate(
        {'risk': 0.5, 'uncertainty': 0.5},
        0.0,
      );
      expect(result, isTrue);
    });

    test('all (AND) returns false when one condition is false', () {
      const condition = CompositeCondition(
        all: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.3,
          ),
          ThresholdCondition(
            metric: 'uncertainty',
            operator: ComparisonOperator.lessThan,
            value: 0.2,
          ),
        ],
      );
      final result = condition.evaluate(
        {'risk': 0.5, 'uncertainty': 0.5},
        0.0,
      );
      expect(result, isFalse);
    });

    test('any (OR) returns true when at least one condition is true', () {
      const condition = CompositeCondition(
        any: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.9,
          ),
          ThresholdCondition(
            metric: 'uncertainty',
            operator: ComparisonOperator.greaterThan,
            value: 0.3,
          ),
        ],
      );
      final result = condition.evaluate(
        {'risk': 0.5, 'uncertainty': 0.5},
        0.0,
      );
      expect(result, isTrue);
    });

    test('any (OR) returns false when no conditions are true', () {
      const condition = CompositeCondition(
        any: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.9,
          ),
          ThresholdCondition(
            metric: 'uncertainty',
            operator: ComparisonOperator.greaterThan,
            value: 0.9,
          ),
        ],
      );
      final result = condition.evaluate(
        {'risk': 0.5, 'uncertainty': 0.5},
        0.0,
      );
      expect(result, isFalse);
    });

    test('not negates the inner condition', () {
      const condition = CompositeCondition(
        not: ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
      );
      // risk=0.3 means risk>0.5 is false, negated = true
      expect(condition.evaluate({'risk': 0.3}, 0.0), isTrue);
      // risk=0.8 means risk>0.5 is true, negated = false
      expect(condition.evaluate({'risk': 0.8}, 0.0), isFalse);
    });

    test('returns true when no conditions are specified', () {
      const condition = CompositeCondition();
      expect(condition.evaluate({}, 0.0), isTrue);
    });

    test('nested composite evaluates correctly', () {
      const condition = CompositeCondition(
        all: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.3,
          ),
          CompositeCondition(
            any: [
              ThresholdCondition(
                metric: 'confidence',
                operator: ComparisonOperator.greaterThan,
                value: 0.8,
              ),
              ThresholdCondition(
                metric: 'evidence',
                operator: ComparisonOperator.greaterThan,
                value: 0.7,
              ),
            ],
          ),
        ],
      );
      // risk>0.3 AND (confidence>0.8 OR evidence>0.7)
      // risk=0.5, confidence=0.9 => true
      expect(
        condition.evaluate(
          {'risk': 0.5, 'confidence': 0.9, 'evidence': 0.1},
          0.0,
        ),
        isTrue,
      );
      // risk=0.5, confidence=0.5, evidence=0.5 => false (neither OR branch)
      expect(
        condition.evaluate(
          {'risk': 0.5, 'confidence': 0.5, 'evidence': 0.5},
          0.0,
        ),
        isFalse,
      );
    });

    test('fromJson creates correct instance with all', () {
      final json = {
        'type': 'composite',
        'all': [
          {
            'type': 'threshold',
            'metric': 'risk',
            'operator': '>',
            'value': 0.5,
          },
        ],
      };
      final condition = CompositeCondition.fromJson(json);
      expect(condition.all, isNotNull);
      expect(condition.all!.length, equals(1));
      expect(condition.all!.first, isA<ThresholdCondition>());
    });

    test('fromJson creates correct instance with not', () {
      final json = {
        'type': 'composite',
        'not': {
          'type': 'threshold',
          'metric': 'risk',
          'operator': '>',
          'value': 0.5,
        },
      };
      final condition = CompositeCondition.fromJson(json);
      expect(condition.not, isNotNull);
      expect(condition.not, isA<ThresholdCondition>());
    });

    test('toJson produces correct output', () {
      const condition = CompositeCondition(
        all: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.5,
          ),
        ],
      );
      final json = condition.toJson();
      expect(json['type'], equals('composite'));
      expect(json['all'], isNotNull);
      expect((json['all'] as List).length, equals(1));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = CompositeCondition(
        any: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.5,
          ),
          ThresholdCondition(
            metric: 'urgency',
            operator: ComparisonOperator.lessThan,
            value: 0.3,
          ),
        ],
      );
      final json = original.toJson();
      final restored = CompositeCondition.fromJson(json);
      expect(restored.any, isNotNull);
      expect(restored.any!.length, equals(2));
    });
  });

  // ===========================================================================
  // PolicyCondition.fromJson dispatch
  // ===========================================================================

  group('PolicyCondition.fromJson', () {
    test('dispatches threshold type to ThresholdCondition', () {
      final json = {
        'type': 'threshold',
        'metric': 'risk',
        'operator': '>',
        'value': 0.5,
      };
      final condition = PolicyCondition.fromJson(json);
      expect(condition, isA<ThresholdCondition>());
    });

    test('dispatches expression type to ExpressionCondition', () {
      final json = {
        'type': 'expression',
        'expression': 'risk > 0.5',
      };
      final condition = PolicyCondition.fromJson(json);
      expect(condition, isA<ExpressionCondition>());
    });

    test('dispatches composite type to CompositeCondition', () {
      final json = {
        'type': 'composite',
        'all': <dynamic>[],
      };
      final condition = PolicyCondition.fromJson(json);
      expect(condition, isA<CompositeCondition>());
    });

    test('throws ArgumentError for unknown type', () {
      final json = {'type': 'unknown'};
      expect(
        () => PolicyCondition.fromJson(json),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ===========================================================================
  // ThresholdCondition — additional coverage
  // ===========================================================================

  group('ThresholdCondition (additional)', () {
    test('aggregatedScore used as metric name with between operator', () {
      const condition = ThresholdCondition(
        metric: 'aggregatedScore',
        operator: ComparisonOperator.between,
        value: [0.3, 0.7],
      );
      // aggregatedScore = 0.5, which is between 0.3 and 0.7
      expect(condition.evaluate({}, 0.5), isTrue);
      // aggregatedScore = 0.1, which is outside range
      expect(condition.evaluate({}, 0.1), isFalse);
      // aggregatedScore = 0.9, which is outside range
      expect(condition.evaluate({}, 0.9), isFalse);
    });

    test('aggregatedScore used with lessThanOrEqual', () {
      const condition = ThresholdCondition(
        metric: 'aggregatedScore',
        operator: ComparisonOperator.lessThanOrEqual,
        value: 0.5,
      );
      expect(condition.evaluate({}, 0.5), isTrue);
      expect(condition.evaluate({}, 0.3), isTrue);
      expect(condition.evaluate({}, 0.8), isFalse);
    });

    test('between returns false when value is not a List', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.between,
        value: 0.5, // Not a List
      );
      expect(condition.evaluate({'score': 0.5}, 0.0), isFalse);
    });

    test('between returns false when list length is not 2', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.between,
        value: [0.3], // Only 1 element
      );
      expect(condition.evaluate({'score': 0.5}, 0.0), isFalse);
    });

    test('between returns false when list has 3 elements', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.between,
        value: [0.1, 0.5, 0.9], // 3 elements
      );
      expect(condition.evaluate({'score': 0.5}, 0.0), isFalse);
    });

    test('outside returns true when value is not a List (inverse of between)', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.outside,
        value: 0.5, // Not a List: between returns false, so outside returns true
      );
      expect(condition.evaluate({'score': 0.5}, 0.0), isTrue);
    });

    test('outside returns true when list length is invalid', () {
      const condition = ThresholdCondition(
        metric: 'score',
        operator: ComparisonOperator.outside,
        value: [0.3], // Invalid length: between returns false, so outside returns true
      );
      expect(condition.evaluate({'score': 0.5}, 0.0), isTrue);
    });
  });

  // ===========================================================================
  // ExpressionCondition — additional coverage
  // ===========================================================================

  group('ExpressionCondition (additional)', () {
    test('NOT operator (!) negates a simple comparison', () {
      const condition = ExpressionCondition(expression: '!risk > 0.5');
      // risk=0.3: "risk > 0.5" is false, negated = true
      expect(condition.evaluate({'risk': 0.3}, 0.0), isTrue);
      // risk=0.8: "risk > 0.5" is true, negated = false
      expect(condition.evaluate({'risk': 0.8}, 0.0), isFalse);
    });

    test('AND (&&) with 3 terms all true', () {
      const condition = ExpressionCondition(
        expression: 'risk > 0.3 && uncertainty < 0.8 && confidence > 0.5',
      );
      expect(
        condition.evaluate(
          {'risk': 0.5, 'uncertainty': 0.5, 'confidence': 0.7},
          0.0,
        ),
        isTrue,
      );
    });

    test('AND (&&) with 3 terms, one false', () {
      const condition = ExpressionCondition(
        expression: 'risk > 0.3 && uncertainty < 0.8 && confidence > 0.5',
      );
      // confidence=0.2 fails the third term
      expect(
        condition.evaluate(
          {'risk': 0.5, 'uncertainty': 0.5, 'confidence': 0.2},
          0.0,
        ),
        isFalse,
      );
    });

    test('OR (||) with 3 terms, only last true', () {
      const condition = ExpressionCondition(
        expression: 'risk > 0.9 || uncertainty > 0.9 || confidence > 0.5',
      );
      // Only confidence > 0.5 is true
      expect(
        condition.evaluate(
          {'risk': 0.1, 'uncertainty': 0.1, 'confidence': 0.7},
          0.0,
        ),
        isTrue,
      );
    });

    test('OR (||) with 3 terms, all false', () {
      const condition = ExpressionCondition(
        expression: 'risk > 0.9 || uncertainty > 0.9 || confidence > 0.9',
      );
      expect(
        condition.evaluate(
          {'risk': 0.1, 'uncertainty': 0.1, 'confidence': 0.1},
          0.0,
        ),
        isFalse,
      );
    });

    test('nested double parentheses: ((a))', () {
      const condition = ExpressionCondition(
        expression: '((risk > 0.5))',
      );
      expect(condition.evaluate({'risk': 0.8}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 0.3}, 0.0), isFalse);
    });

    test('top-level AND with parenthesized sub-expressions', () {
      // Use top-level && with each side wrapped in parentheses
      const condition = ExpressionCondition(
        expression: '(risk > 0.5) && (uncertainty < 0.3)',
      );
      expect(
        condition.evaluate(
          {'risk': 0.8, 'uncertainty': 0.2},
          0.0,
        ),
        isTrue,
      );
      expect(
        condition.evaluate(
          {'risk': 0.8, 'uncertainty': 0.5},
          0.0,
        ),
        isFalse,
      );
    });

    test('top-level OR with parenthesized sub-expressions', () {
      const condition = ExpressionCondition(
        expression: '(risk > 0.9) || (confidence > 0.9)',
      );
      expect(
        condition.evaluate(
          {'risk': 0.95, 'confidence': 0.1},
          0.0,
        ),
        isTrue,
      );
      expect(
        condition.evaluate(
          {'risk': 0.1, 'confidence': 0.95},
          0.0,
        ),
        isTrue,
      );
      expect(
        condition.evaluate(
          {'risk': 0.1, 'confidence': 0.1},
          0.0,
        ),
        isFalse,
      );
    });

    test('expression with aggregatedScore metric', () {
      const condition = ExpressionCondition(
        expression: 'aggregatedScore > 0.7',
      );
      expect(condition.evaluate({}, 0.9), isTrue);
      expect(condition.evaluate({}, 0.5), isFalse);
    });

    test('expression returns false for invalid/unparseable expression', () {
      const condition = ExpressionCondition(
        expression: 'not_a_valid_expression',
      );
      expect(condition.evaluate({'risk': 0.5}, 0.0), isFalse);
    });

    test('expression with inverted metric pattern: (1 - metric) > value', () {
      const condition = ExpressionCondition(
        expression: '(1 - risk) > 0.5',
      );
      // risk=0.3 => (1-0.3) = 0.7 > 0.5 => true
      expect(condition.evaluate({'risk': 0.3}, 0.0), isTrue);
      // risk=0.8 => (1-0.8) = 0.2 > 0.5 => false
      expect(condition.evaluate({'risk': 0.8}, 0.0), isFalse);
    });
  });

  // ===========================================================================
  // CompositeCondition — additional coverage
  // ===========================================================================

  group('CompositeCondition (additional)', () {
    test('deeply nested 3 levels: all -> any -> not', () {
      const condition = CompositeCondition(
        all: [
          ThresholdCondition(
            metric: 'risk',
            operator: ComparisonOperator.greaterThan,
            value: 0.3,
          ),
          CompositeCondition(
            any: [
              CompositeCondition(
                not: ThresholdCondition(
                  metric: 'trust',
                  operator: ComparisonOperator.greaterThan,
                  value: 0.8,
                ),
              ),
              ThresholdCondition(
                metric: 'urgency',
                operator: ComparisonOperator.greaterThan,
                value: 0.7,
              ),
            ],
          ),
        ],
      );

      // risk>0.3 AND (NOT(trust>0.8) OR urgency>0.7)
      // risk=0.5, trust=0.5 (NOT(false)=true) => true
      expect(
        condition.evaluate(
          {'risk': 0.5, 'trust': 0.5, 'urgency': 0.1},
          0.0,
        ),
        isTrue,
      );

      // risk=0.5, trust=0.9 (NOT(true)=false), urgency=0.9 (true) => true
      expect(
        condition.evaluate(
          {'risk': 0.5, 'trust': 0.9, 'urgency': 0.9},
          0.0,
        ),
        isTrue,
      );

      // risk=0.5, trust=0.9 (NOT(true)=false), urgency=0.1 (false) => false
      expect(
        condition.evaluate(
          {'risk': 0.5, 'trust': 0.9, 'urgency': 0.1},
          0.0,
        ),
        isFalse,
      );

      // risk=0.1 (fails first all condition) => false
      expect(
        condition.evaluate(
          {'risk': 0.1, 'trust': 0.5, 'urgency': 0.9},
          0.0,
        ),
        isFalse,
      );
    });

    test('deeply nested 3 levels: any -> all -> threshold', () {
      const condition = CompositeCondition(
        any: [
          CompositeCondition(
            all: [
              ThresholdCondition(
                metric: 'risk',
                operator: ComparisonOperator.greaterThan,
                value: 0.8,
              ),
              ThresholdCondition(
                metric: 'urgency',
                operator: ComparisonOperator.greaterThan,
                value: 0.8,
              ),
            ],
          ),
          CompositeCondition(
            all: [
              ThresholdCondition(
                metric: 'trust',
                operator: ComparisonOperator.lessThan,
                value: 0.2,
              ),
              ThresholdCondition(
                metric: 'confidence',
                operator: ComparisonOperator.lessThan,
                value: 0.2,
              ),
            ],
          ),
        ],
      );

      // First any branch: risk>0.8 AND urgency>0.8
      expect(
        condition.evaluate(
          {'risk': 0.9, 'urgency': 0.9, 'trust': 0.5, 'confidence': 0.5},
          0.0,
        ),
        isTrue,
      );

      // Second any branch: trust<0.2 AND confidence<0.2
      expect(
        condition.evaluate(
          {'risk': 0.1, 'urgency': 0.1, 'trust': 0.1, 'confidence': 0.1},
          0.0,
        ),
        isTrue,
      );

      // Neither branch satisfied
      expect(
        condition.evaluate(
          {'risk': 0.5, 'urgency': 0.5, 'trust': 0.5, 'confidence': 0.5},
          0.0,
        ),
        isFalse,
      );
    });

    test('fromJson with any field creates correct instance', () {
      final json = {
        'type': 'composite',
        'any': [
          {
            'type': 'threshold',
            'metric': 'risk',
            'operator': '>',
            'value': 0.5,
          },
          {
            'type': 'threshold',
            'metric': 'urgency',
            'operator': '>',
            'value': 0.7,
          },
        ],
      };
      final condition = CompositeCondition.fromJson(json);
      expect(condition.any, isNotNull);
      expect(condition.any!.length, equals(2));
    });

    test('toJson includes not field when set', () {
      const condition = CompositeCondition(
        not: ThresholdCondition(
          metric: 'risk',
          operator: ComparisonOperator.greaterThan,
          value: 0.5,
        ),
      );
      final json = condition.toJson();
      expect(json['type'], equals('composite'));
      expect(json['not'], isNotNull);
      expect(json.containsKey('all'), isFalse);
      expect(json.containsKey('any'), isFalse);
    });

    test('toJson omits null fields', () {
      const condition = CompositeCondition();
      final json = condition.toJson();
      expect(json['type'], equals('composite'));
      expect(json.containsKey('all'), isFalse);
      expect(json.containsKey('any'), isFalse);
      expect(json.containsKey('not'), isFalse);
    });
  });

  // ===========================================================================
  // ThresholdCondition._parseOperator coverage (lines 120-124)
  // ===========================================================================

  group('ThresholdCondition._parseOperator via fromJson', () {
    test('parses "==" operator', () {
      final condition = ThresholdCondition.fromJson({
        'type': 'threshold',
        'metric': 'score',
        'operator': '==',
        'value': 0.5,
      });
      expect(condition.operator, equals(ComparisonOperator.equal));
    });

    test('parses "!=" operator', () {
      final condition = ThresholdCondition.fromJson({
        'type': 'threshold',
        'metric': 'score',
        'operator': '!=',
        'value': 0.5,
      });
      expect(condition.operator, equals(ComparisonOperator.notEqual));
    });

    test('parses "between" operator', () {
      final condition = ThresholdCondition.fromJson({
        'type': 'threshold',
        'metric': 'score',
        'operator': 'between',
        'value': [0.3, 0.7],
      });
      expect(condition.operator, equals(ComparisonOperator.between));
    });

    test('parses "outside" operator', () {
      final condition = ThresholdCondition.fromJson({
        'type': 'threshold',
        'metric': 'score',
        'operator': 'outside',
        'value': [0.3, 0.7],
      });
      expect(condition.operator, equals(ComparisonOperator.outside));
    });

    test('throws ArgumentError for unknown operator string', () {
      expect(
        () => ThresholdCondition.fromJson({
          'type': 'threshold',
          'metric': 'score',
          'operator': 'invalid_op',
          'value': 0.5,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ===========================================================================
  // ExpressionCondition — simple comparison <=, ==, != (lines 236-238)
  // ===========================================================================

  group('ExpressionCondition simple comparison operators', () {
    test('evaluates <= operator in simple comparison', () {
      const condition = ExpressionCondition(expression: 'risk <= 0.5');
      expect(condition.evaluate({'risk': 0.3}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 0.5}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 0.8}, 0.0), isFalse);
    });

    test('evaluates == operator in simple comparison', () {
      const condition = ExpressionCondition(expression: 'risk == 0.5');
      expect(condition.evaluate({'risk': 0.5}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 0.3}, 0.0), isFalse);
    });

    test('evaluates != operator in simple comparison', () {
      const condition = ExpressionCondition(expression: 'risk != 0.5');
      expect(condition.evaluate({'risk': 0.3}, 0.0), isTrue);
      expect(condition.evaluate({'risk': 0.5}, 0.0), isFalse);
    });
  });

  // ===========================================================================
  // ExpressionCondition — inverted metric pattern <=, ==, != (lines 257-261)
  // ===========================================================================

  group('ExpressionCondition inverted metric pattern operators', () {
    test('evaluates (1 - metric) <= value', () {
      const condition = ExpressionCondition(
        expression: '(1 - risk) <= 0.5',
      );
      // risk=0.8 => (1-0.8)=0.2 <= 0.5 => true
      expect(condition.evaluate({'risk': 0.8}, 0.0), isTrue);
      // risk=0.5 => (1-0.5)=0.5 <= 0.5 => true
      expect(condition.evaluate({'risk': 0.5}, 0.0), isTrue);
      // risk=0.2 => (1-0.2)=0.8 <= 0.5 => false
      expect(condition.evaluate({'risk': 0.2}, 0.0), isFalse);
    });

    test('evaluates (1 - metric) == value', () {
      const condition = ExpressionCondition(
        expression: '(1 - risk) == 0.5',
      );
      // risk=0.5 => (1-0.5)=0.5 == 0.5 => true
      expect(condition.evaluate({'risk': 0.5}, 0.0), isTrue);
      // risk=0.3 => (1-0.3)=0.7 == 0.5 => false
      expect(condition.evaluate({'risk': 0.3}, 0.0), isFalse);
    });

    test('evaluates (1 - metric) != value', () {
      const condition = ExpressionCondition(
        expression: '(1 - risk) != 0.5',
      );
      // risk=0.3 => (1-0.3)=0.7 != 0.5 => true
      expect(condition.evaluate({'risk': 0.3}, 0.0), isTrue);
      // risk=0.5 => (1-0.5)=0.5 != 0.5 => false
      expect(condition.evaluate({'risk': 0.5}, 0.0), isFalse);
    });
  });
}
