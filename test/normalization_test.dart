/// NormalizationConfig Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  // ===========================================================================
  // MinMaxNormalization
  // ===========================================================================

  group('MinMaxNormalization', () {
    test('normalizes 0 to 0.0 with range 0-100', () {
      const norm = MinMaxNormalization(min: 0, max: 100);
      expect(norm.normalize(0), equals(0.0));
    });

    test('normalizes 50 to 0.5 with range 0-100', () {
      const norm = MinMaxNormalization(min: 0, max: 100);
      expect(norm.normalize(50), equals(0.5));
    });

    test('normalizes 100 to 1.0 with range 0-100', () {
      const norm = MinMaxNormalization(min: 0, max: 100);
      expect(norm.normalize(100), equals(1.0));
    });

    test('normalizes with custom range 10-20', () {
      const norm = MinMaxNormalization(min: 10, max: 20);
      expect(norm.normalize(10), equals(0.0));
      expect(norm.normalize(15), equals(0.5));
      expect(norm.normalize(20), equals(1.0));
    });

    test('returns 0.5 when min equals max', () {
      const norm = MinMaxNormalization(min: 5, max: 5);
      expect(norm.normalize(5), equals(0.5));
      expect(norm.normalize(100), equals(0.5));
    });

    test('clamps values below range to 0.0', () {
      const norm = MinMaxNormalization(min: 0, max: 100);
      expect(norm.normalize(-10), equals(0.0));
    });

    test('clamps values above range to 1.0', () {
      const norm = MinMaxNormalization(min: 0, max: 100);
      expect(norm.normalize(150), equals(1.0));
    });

    test('uses default min=0.0 and max=1.0', () {
      const norm = MinMaxNormalization();
      expect(norm.normalize(0.0), equals(0.0));
      expect(norm.normalize(0.5), equals(0.5));
      expect(norm.normalize(1.0), equals(1.0));
    });

    test('fromJson creates instance with correct values', () {
      final norm = MinMaxNormalization.fromJson({
        'method': 'minmax',
        'min': 10,
        'max': 50,
      });
      expect(norm.min, equals(10.0));
      expect(norm.max, equals(50.0));
    });

    test('fromJson uses defaults when values missing', () {
      final norm = MinMaxNormalization.fromJson({'method': 'minmax'});
      expect(norm.min, equals(0.0));
      expect(norm.max, equals(1.0));
    });

    test('toJson produces correct output', () {
      const norm = MinMaxNormalization(min: 0, max: 100);
      final json = norm.toJson();
      expect(json['method'], equals('minmax'));
      expect(json['min'], equals(0.0));
      expect(json['max'], equals(100.0));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = MinMaxNormalization(min: -5, max: 95);
      final json = original.toJson();
      final restored = MinMaxNormalization.fromJson(json);
      expect(restored.min, equals(original.min));
      expect(restored.max, equals(original.max));
      expect(restored.normalize(45), equals(original.normalize(45)));
    });
  });

  // ===========================================================================
  // ZScoreNormalization
  // ===========================================================================

  group('ZScoreNormalization', () {
    test('normalizes value at mean to approximately 0.5', () {
      const norm = ZScoreNormalization(mean: 50, stddev: 10);
      expect(norm.normalize(50), equals(0.5));
    });

    test('normalizes value above mean to greater than 0.5', () {
      const norm = ZScoreNormalization(mean: 50, stddev: 10);
      expect(norm.normalize(70), greaterThan(0.5));
    });

    test('normalizes value below mean to less than 0.5', () {
      const norm = ZScoreNormalization(mean: 50, stddev: 10);
      expect(norm.normalize(30), lessThan(0.5));
    });

    test('returns 0.5 when stddev is 0', () {
      const norm = ZScoreNormalization(mean: 50, stddev: 0);
      expect(norm.normalize(50), equals(0.5));
      expect(norm.normalize(100), equals(0.5));
    });

    test('output is bounded between 0 and 1 for extreme values', () {
      const norm = ZScoreNormalization(mean: 50, stddev: 10);
      final high = norm.normalize(1000);
      final low = norm.normalize(-1000);
      expect(high, lessThanOrEqualTo(1.0));
      expect(high, greaterThan(0.99));
      expect(low, greaterThanOrEqualTo(0.0));
      expect(low, lessThan(0.01));
    });

    test('fromJson creates instance with correct values', () {
      final norm = ZScoreNormalization.fromJson({
        'method': 'zscore',
        'mean': 100,
        'stddev': 15,
      });
      expect(norm.mean, equals(100.0));
      expect(norm.stddev, equals(15.0));
    });

    test('toJson produces correct output', () {
      const norm = ZScoreNormalization(mean: 50, stddev: 10);
      final json = norm.toJson();
      expect(json['method'], equals('zscore'));
      expect(json['mean'], equals(50.0));
      expect(json['stddev'], equals(10.0));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = ZScoreNormalization(mean: 75, stddev: 25);
      final json = original.toJson();
      final restored = ZScoreNormalization.fromJson(json);
      expect(restored.mean, equals(original.mean));
      expect(restored.stddev, equals(original.stddev));
    });
  });

  // ===========================================================================
  // SigmoidNormalization
  // ===========================================================================

  group('SigmoidNormalization', () {
    test('normalizes midpoint value to approximately 0.5', () {
      const norm = SigmoidNormalization(midpoint: 50, steepness: 0.1);
      expect(norm.normalize(50), equals(0.5));
    });

    test('normalizes value far above midpoint to close to 1.0', () {
      const norm = SigmoidNormalization(midpoint: 50, steepness: 0.1);
      final result = norm.normalize(150);
      expect(result, greaterThan(0.99));
    });

    test('normalizes value far below midpoint to close to 0.0', () {
      const norm = SigmoidNormalization(midpoint: 50, steepness: 0.1);
      final result = norm.normalize(-50);
      expect(result, lessThan(0.01));
    });

    test('uses default midpoint=50 and steepness=0.1', () {
      const norm = SigmoidNormalization();
      expect(norm.midpoint, equals(50.0));
      expect(norm.steepness, equals(0.1));
      expect(norm.normalize(50), equals(0.5));
    });

    test('fromJson creates instance with correct values', () {
      final norm = SigmoidNormalization.fromJson({
        'method': 'sigmoid',
        'midpoint': 75,
        'steepness': 0.2,
      });
      expect(norm.midpoint, equals(75.0));
      expect(norm.steepness, equals(0.2));
    });

    test('fromJson uses defaults when values missing', () {
      final norm = SigmoidNormalization.fromJson({'method': 'sigmoid'});
      expect(norm.midpoint, equals(50.0));
      expect(norm.steepness, equals(0.1));
    });

    test('toJson produces correct output', () {
      const norm = SigmoidNormalization(midpoint: 50, steepness: 0.1);
      final json = norm.toJson();
      expect(json['method'], equals('sigmoid'));
      expect(json['midpoint'], equals(50.0));
      expect(json['steepness'], equals(0.1));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = SigmoidNormalization(midpoint: 30, steepness: 0.5);
      final json = original.toJson();
      final restored = SigmoidNormalization.fromJson(json);
      expect(restored.midpoint, equals(original.midpoint));
      expect(restored.steepness, equals(original.steepness));
    });
  });

  // ===========================================================================
  // LogNormalization
  // ===========================================================================

  group('LogNormalization', () {
    test('normalizes 0 to 0.0', () {
      const norm = LogNormalization(scale: 5);
      expect(norm.normalize(0), equals(0.0));
    });

    test('normalizes positive values to positive results', () {
      const norm = LogNormalization(scale: 5);
      final result = norm.normalize(10);
      expect(result, greaterThan(0.0));
      expect(result, lessThanOrEqualTo(1.0));
    });

    test('normalizes negative values to 0.0', () {
      const norm = LogNormalization(scale: 5);
      expect(norm.normalize(-1), equals(0.0));
      expect(norm.normalize(-100), equals(0.0));
    });

    test('clamps large values to 1.0', () {
      const norm = LogNormalization(scale: 5);
      final result = norm.normalize(1000000);
      expect(result, equals(1.0));
    });

    test('uses default scale=5.0', () {
      const norm = LogNormalization();
      expect(norm.scale, equals(5.0));
    });

    test('fromJson creates instance with correct scale', () {
      final norm = LogNormalization.fromJson({
        'method': 'log',
        'scale': 10,
      });
      expect(norm.scale, equals(10.0));
    });

    test('fromJson uses default scale when missing', () {
      final norm = LogNormalization.fromJson({'method': 'log'});
      expect(norm.scale, equals(5.0));
    });

    test('toJson produces correct output', () {
      const norm = LogNormalization(scale: 5);
      final json = norm.toJson();
      expect(json['method'], equals('log'));
      expect(json['scale'], equals(5.0));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = LogNormalization(scale: 8);
      final json = original.toJson();
      final restored = LogNormalization.fromJson(json);
      expect(restored.scale, equals(original.scale));
    });
  });

  // ===========================================================================
  // PassthroughNormalization
  // ===========================================================================

  group('PassthroughNormalization', () {
    test('passes through 0.5 unchanged', () {
      const norm = PassthroughNormalization();
      expect(norm.normalize(0.5), equals(0.5));
    });

    test('clamps negative values to 0.0', () {
      const norm = PassthroughNormalization();
      expect(norm.normalize(-0.1), equals(0.0));
    });

    test('clamps values above 1 to 1.0', () {
      const norm = PassthroughNormalization();
      expect(norm.normalize(1.5), equals(1.0));
    });

    test('passes through boundary values', () {
      const norm = PassthroughNormalization();
      expect(norm.normalize(0.0), equals(0.0));
      expect(norm.normalize(1.0), equals(1.0));
    });

    test('toJson produces correct output', () {
      const norm = PassthroughNormalization();
      final json = norm.toJson();
      expect(json, equals({'method': 'passthrough'}));
    });
  });

  // ===========================================================================
  // BooleanNormalization
  // ===========================================================================

  group('BooleanNormalization', () {
    test('returns 0.0 for value below default threshold', () {
      const norm = BooleanNormalization();
      expect(norm.normalize(0.3), equals(0.0));
    });

    test('returns 1.0 for value at default threshold', () {
      const norm = BooleanNormalization();
      expect(norm.normalize(0.5), equals(1.0));
    });

    test('returns 1.0 for value above default threshold', () {
      const norm = BooleanNormalization();
      expect(norm.normalize(0.8), equals(1.0));
    });

    test('uses default threshold of 0.5', () {
      const norm = BooleanNormalization();
      expect(norm.threshold, equals(0.5));
    });

    test('uses custom threshold 0.7', () {
      const norm = BooleanNormalization(threshold: 0.7);
      expect(norm.normalize(0.6), equals(0.0));
      expect(norm.normalize(0.7), equals(1.0));
      expect(norm.normalize(0.8), equals(1.0));
    });

    test('fromJson creates instance with threshold', () {
      final norm = BooleanNormalization.fromJson({
        'method': 'boolean',
        'threshold': 0.7,
      });
      expect(norm.threshold, equals(0.7));
    });

    test('fromJson uses default threshold when missing', () {
      final norm = BooleanNormalization.fromJson({'method': 'boolean'});
      expect(norm.threshold, equals(0.5));
    });

    test('toJson produces correct output with default threshold', () {
      const norm = BooleanNormalization();
      final json = norm.toJson();
      expect(json['method'], equals('boolean'));
      expect(json.containsKey('threshold'), isFalse);
    });

    test('toJson includes threshold when non-default', () {
      const norm = BooleanNormalization(threshold: 0.7);
      final json = norm.toJson();
      expect(json['method'], equals('boolean'));
      expect(json['threshold'], equals(0.7));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = BooleanNormalization(threshold: 0.8);
      final json = original.toJson();
      final restored = BooleanNormalization.fromJson(json);
      expect(restored.threshold, equals(original.threshold));
    });
  });

  // ===========================================================================
  // CustomNormalization
  // ===========================================================================

  group('CustomNormalization', () {
    test('uses evaluator when provided and clamps result', () {
      final norm = CustomNormalization(
        expression: 'value * 2',
        evaluator: (v) => v * 2,
      );
      expect(norm.normalize(0.3), equals(0.6));
      // Clamped to 1.0
      expect(norm.normalize(0.8), equals(1.0));
    });

    test('evaluates "value / N" expression without evaluator', () {
      const norm = CustomNormalization(expression: 'value / 10');
      expect(norm.normalize(5), equals(0.5));
      expect(norm.normalize(10), equals(1.0));
      // Clamped
      expect(norm.normalize(15), equals(1.0));
    });

    test('evaluates "value / N" with decimal divisor', () {
      const norm = CustomNormalization(expression: 'value / 2.5');
      expect(norm.normalize(1.25), equals(0.5));
    });

    test('falls back to clamped value for unknown expression', () {
      const norm = CustomNormalization(expression: 'some_complex_expr');
      expect(norm.normalize(0.7), equals(0.7));
      expect(norm.normalize(1.5), equals(1.0));
      expect(norm.normalize(-0.5), equals(0.0));
    });

    test('unrecognized expression pattern uses clamp fallback', () {
      // Expressions that do not match "clamp(log(...)" or "value / N" patterns
      const norm1 = CustomNormalization(expression: 'sqrt(value)');
      expect(norm1.normalize(0.5), equals(0.5));
      expect(norm1.normalize(2.0), equals(1.0));
      expect(norm1.normalize(-1.0), equals(0.0));

      const norm2 = CustomNormalization(expression: 'value * value + 1');
      expect(norm2.normalize(0.3), equals(0.3));
      expect(norm2.normalize(5.0), equals(1.0));
    });

    test('withEvaluator creates new instance with evaluator', () {
      const norm = CustomNormalization(expression: 'value * 3');
      final withEval = norm.withEvaluator((v) => v * 3);
      expect(withEval.expression, equals('value * 3'));
      expect(withEval.normalize(0.2), closeTo(0.6, 1e-10));
    });

    test('fromJson creates instance with expression', () {
      final norm = CustomNormalization.fromJson({
        'method': 'custom',
        'expression': 'value / 100',
      });
      expect(norm.expression, equals('value / 100'));
    });

    test('toJson produces correct output', () {
      const norm = CustomNormalization(expression: 'value / 50');
      final json = norm.toJson();
      expect(json['method'], equals('custom'));
      expect(json['expression'], equals('value / 50'));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = CustomNormalization(expression: 'value / 25');
      final json = original.toJson();
      final restored = CustomNormalization.fromJson(json);
      expect(restored.expression, equals(original.expression));
    });
  });

  // ===========================================================================
  // NormalizationConfig.fromJson dispatch
  // ===========================================================================

  group('NormalizationConfig.fromJson', () {
    test('dispatches minmax method to MinMaxNormalization', () {
      final config = NormalizationConfig.fromJson({
        'method': 'minmax',
        'min': 0,
        'max': 100,
      });
      expect(config, isA<MinMaxNormalization>());
    });

    test('dispatches zscore method to ZScoreNormalization', () {
      final config = NormalizationConfig.fromJson({
        'method': 'zscore',
        'mean': 50,
        'stddev': 10,
      });
      expect(config, isA<ZScoreNormalization>());
    });

    test('dispatches sigmoid method to SigmoidNormalization', () {
      final config = NormalizationConfig.fromJson({
        'method': 'sigmoid',
      });
      expect(config, isA<SigmoidNormalization>());
    });

    test('dispatches log method to LogNormalization', () {
      final config = NormalizationConfig.fromJson({
        'method': 'log',
      });
      expect(config, isA<LogNormalization>());
    });

    test('dispatches passthrough method to PassthroughNormalization', () {
      final config = NormalizationConfig.fromJson({
        'method': 'passthrough',
      });
      expect(config, isA<PassthroughNormalization>());
    });

    test('dispatches boolean method to BooleanNormalization', () {
      final config = NormalizationConfig.fromJson({
        'method': 'boolean',
      });
      expect(config, isA<BooleanNormalization>());
    });

    test('dispatches custom method to CustomNormalization', () {
      final config = NormalizationConfig.fromJson({
        'method': 'custom',
        'expression': 'value / 10',
      });
      expect(config, isA<CustomNormalization>());
    });

    test('throws ArgumentError for unknown method', () {
      expect(
        () => NormalizationConfig.fromJson({'method': 'unknown'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ===========================================================================
  // Coverage: normalization.dart line 279
  //   (CustomNormalization._evaluateSimpleExpression clamp(log(...)) pattern)
  // ===========================================================================

  group('CustomNormalization clamp(log(value + 1) pattern', () {
    test('evaluates clamp(log(value + 1) expression pattern', () {
      // Covers line 279: return (math.log(value + 1) / 5).clamp(0.0, 1.0)
      const norm = CustomNormalization(
        expression: 'clamp(log(value + 1) / 5, 0, 1)',
      );

      // log(0 + 1) = 0.0, clamped to 0.0
      expect(norm.normalize(0), equals(0.0));

      // log(e^5) / 5 = 1.0
      // A very large value should clamp to 1.0
      expect(norm.normalize(1000000), equals(1.0));

      // A moderate value should be between 0 and 1
      final mid = norm.normalize(10);
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));
    });
  });
}
