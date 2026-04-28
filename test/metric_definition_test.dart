/// MetricDefinition Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  // =========================================================================
  // AppraisalMetricDef
  // =========================================================================
  group('AppraisalMetricDef', () {
    test('creates with required fields', () {
      const def = AppraisalMetricDef(
        id: 'risk',
        name: 'Risk Level',
        source: StaticSource(value: 0.5),
      );

      expect(def.id, equals('risk'));
      expect(def.name, equals('Risk Level'));
      expect(def.source, isA<StaticSource>());
    });

    test('has correct defaults', () {
      const def = AppraisalMetricDef(
        id: 'test',
        name: 'Test Metric',
        source: StaticSource(value: 0.5),
      );

      expect(def.description, isNull);
      expect(def.normalization, isNull);
      expect(def.defaultValue, isNull);
      expect(def.weight, equals(1.0));
      expect(def.inverse, isFalse);
      expect(def.tags, isEmpty);
    });

    test('creates with all optional fields', () {
      const def = AppraisalMetricDef(
        id: 'uncertainty',
        name: 'Uncertainty',
        source: ComputedSource(expression: '1 - avgConfidence'),
        description: 'Measures uncertainty level',
        defaultValue: 0.5,
        weight: 0.25,
        inverse: true,
        tags: ['core', 'computed'],
      );

      expect(def.description, equals('Measures uncertainty level'));
      expect(def.defaultValue, equals(0.5));
      expect(def.weight, equals(0.25));
      expect(def.inverse, isTrue);
      expect(def.tags, equals(['core', 'computed']));
    });

    group('JSON serialization', () {
      test('toJson includes required fields', () {
        const def = AppraisalMetricDef(
          id: 'risk',
          name: 'Risk Level',
          source: StaticSource(value: 0.5),
        );

        final json = def.toJson();

        expect(json['id'], equals('risk'));
        expect(json['name'], equals('Risk Level'));
        expect(json['source'], isA<Map>());
        expect(json['weight'], equals(1.0));
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('defaultValue'), isFalse);
        expect(json.containsKey('inverse'), isFalse);
        expect(json.containsKey('tags'), isFalse);
      });

      test('toJson includes optional fields when set', () {
        const def = AppraisalMetricDef(
          id: 'trust',
          name: 'Trust',
          source: ComputedSource(expression: 'avgSourceReliability'),
          description: 'Source reliability',
          defaultValue: 0.7,
          weight: 0.1,
          inverse: true,
          tags: ['reliability'],
        );

        final json = def.toJson();

        expect(json['description'], equals('Source reliability'));
        expect(json['defaultValue'], equals(0.7));
        expect(json['inverse'], isTrue);
        expect(json['tags'], contains('reliability'));
      });

      test('fromJson round-trips correctly', () {
        const original = AppraisalMetricDef(
          id: 'sentiment',
          name: 'Sentiment',
          source: StaticSource(value: 0.5),
          description: 'Emotional context',
          defaultValue: 0.5,
          weight: 0.1,
          tags: ['emotional'],
        );

        final restored = AppraisalMetricDef.fromJson(original.toJson());

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.source, isA<StaticSource>());
        expect(restored.description, equals(original.description));
        expect(restored.defaultValue, equals(original.defaultValue));
        expect(restored.weight, equals(original.weight));
        expect(restored.inverse, equals(original.inverse));
        expect(restored.tags, equals(original.tags));
      });
    });
  });

  // =========================================================================
  // AppraisalSection
  // =========================================================================
  group('AppraisalSection', () {
    test('creates with metrics only', () {
      const section = AppraisalSection(
        metrics: [
          AppraisalMetricDef(
            id: 'risk',
            name: 'Risk',
            source: StaticSource(value: 0.3),
          ),
        ],
      );

      expect(section.metrics.length, equals(1));
      expect(section.metrics.first.id, equals('risk'));
      expect(section.aggregation, isNull);
    });

    test('creates with aggregation', () {
      const section = AppraisalSection(
        metrics: [
          AppraisalMetricDef(
            id: 'risk',
            name: 'Risk',
            source: StaticSource(value: 0.3),
          ),
          AppraisalMetricDef(
            id: 'trust',
            name: 'Trust',
            source: StaticSource(value: 0.7),
          ),
        ],
        aggregation: AggregationConfig(
          method: AggregationMethod.weightedAverage,
        ),
      );

      expect(section.metrics.length, equals(2));
      expect(section.aggregation, isNotNull);
      expect(
        section.aggregation!.method,
        equals(AggregationMethod.weightedAverage),
      );
    });

    group('JSON serialization', () {
      test('toJson produces correct structure', () {
        const section = AppraisalSection(
          metrics: [
            AppraisalMetricDef(
              id: 'risk',
              name: 'Risk',
              source: StaticSource(value: 0.3),
            ),
          ],
        );

        final json = section.toJson();

        expect(json['metrics'], isA<List>());
        expect((json['metrics'] as List).length, equals(1));
        expect(json.containsKey('aggregation'), isFalse);
      });

      test('fromJson round-trips correctly', () {
        const original = AppraisalSection(
          metrics: [
            AppraisalMetricDef(
              id: 'risk',
              name: 'Risk',
              source: StaticSource(value: 0.3),
            ),
            AppraisalMetricDef(
              id: 'trust',
              name: 'Trust',
              source: StaticSource(value: 0.7),
            ),
          ],
          aggregation: AggregationConfig(
            method: AggregationMethod.max,
          ),
        );

        final restored = AppraisalSection.fromJson(original.toJson());

        expect(restored.metrics.length, equals(2));
        expect(restored.metrics[0].id, equals('risk'));
        expect(restored.metrics[1].id, equals('trust'));
        expect(restored.aggregation, isNotNull);
        expect(
          restored.aggregation!.method,
          equals(AggregationMethod.max),
        );
      });
    });
  });

  // =========================================================================
  // AggregationConfig
  // =========================================================================
  group('AggregationConfig', () {
    test('creates with defaults', () {
      const config = AggregationConfig();

      expect(config.method, equals(AggregationMethod.weightedAverage));
      expect(config.weights, isNull);
      expect(config.expression, isNull);
    });

    test('creates with custom values', () {
      const config = AggregationConfig(
        method: AggregationMethod.custom,
        weights: {'risk': 0.5, 'trust': 0.3},
        expression: 'risk * 0.7 + trust * 0.3',
      );

      expect(config.method, equals(AggregationMethod.custom));
      expect(config.weights, isNotNull);
      expect(config.weights!['risk'], equals(0.5));
      expect(config.expression, equals('risk * 0.7 + trust * 0.3'));
    });

    group('JSON serialization', () {
      test('toJson with defaults', () {
        const config = AggregationConfig();
        final json = config.toJson();

        expect(json['method'], equals('weighted_average'));
        expect(json.containsKey('weights'), isFalse);
        expect(json.containsKey('expression'), isFalse);
      });

      test('toJson with all fields', () {
        const config = AggregationConfig(
          method: AggregationMethod.custom,
          weights: {'risk': 0.6},
          expression: 'risk * 2',
        );

        final json = config.toJson();

        expect(json['method'], equals('custom'));
        expect(json['weights'], isNotNull);
        expect(json['expression'], equals('risk * 2'));
      });

      test('fromJson round-trips correctly', () {
        const original = AggregationConfig(
          method: AggregationMethod.sum,
          weights: {'risk': 0.4, 'trust': 0.6},
        );

        final restored = AggregationConfig.fromJson(original.toJson());

        expect(restored.method, equals(original.method));
        expect(restored.weights, equals(original.weights));
        expect(restored.expression, isNull);
      });

      test('fromJson defaults to weightedAverage for missing method', () {
        final json = <String, dynamic>{};

        final config = AggregationConfig.fromJson(json);

        expect(config.method, equals(AggregationMethod.weightedAverage));
      });
    });
  });

  // =========================================================================
  // AggregationMethod
  // =========================================================================
  group('AggregationMethod', () {
    test('has 5 values', () {
      expect(AggregationMethod.values.length, equals(5));
    });

    test('contains all expected values', () {
      expect(
        AggregationMethod.values,
        contains(AggregationMethod.weightedAverage),
      );
      expect(AggregationMethod.values, contains(AggregationMethod.max));
      expect(AggregationMethod.values, contains(AggregationMethod.min));
      expect(AggregationMethod.values, contains(AggregationMethod.sum));
      expect(AggregationMethod.values, contains(AggregationMethod.custom));
    });

    group('toJsonName', () {
      test('weightedAverage returns weighted_average', () {
        expect(
          AggregationMethod.weightedAverage.toJsonName(),
          equals('weighted_average'),
        );
      });

      test('max returns max', () {
        expect(AggregationMethod.max.toJsonName(), equals('max'));
      });

      test('min returns min', () {
        expect(AggregationMethod.min.toJsonName(), equals('min'));
      });

      test('sum returns sum', () {
        expect(AggregationMethod.sum.toJsonName(), equals('sum'));
      });

      test('custom returns custom', () {
        expect(AggregationMethod.custom.toJsonName(), equals('custom'));
      });
    });
  });

  // =========================================================================
  // StandardMetrics
  // =========================================================================
  group('StandardMetrics', () {
    test('risk() returns correct definition', () {
      final risk = StandardMetrics.risk();

      expect(risk.id, equals('risk'));
      expect(risk.name, equals('Risk Level'));
      expect(risk.weight, equals(0.35));
      expect(risk.defaultValue, equals(0.3));
      expect(risk.source, isA<FactGraphSource>());
    });

    test('risk() accepts custom weight and defaultValue', () {
      final risk = StandardMetrics.risk(weight: 0.5, defaultValue: 0.1);

      expect(risk.weight, equals(0.5));
      expect(risk.defaultValue, equals(0.1));
    });

    test('uncertainty() returns correct definition', () {
      final uncertainty = StandardMetrics.uncertainty();

      expect(uncertainty.id, equals('uncertainty'));
      expect(uncertainty.name, equals('Uncertainty'));
      expect(uncertainty.weight, equals(0.25));
      expect(uncertainty.defaultValue, equals(0.5));
      expect(uncertainty.source, isA<ComputedSource>());
    });

    test('urgency() returns correct definition', () {
      final urgency = StandardMetrics.urgency();

      expect(urgency.id, equals('urgency'));
      expect(urgency.name, equals('Urgency'));
      expect(urgency.weight, equals(0.2));
      expect(urgency.defaultValue, equals(0.3));
      expect(urgency.source, isA<FactGraphSource>());
    });

    test('trust() returns correct definition', () {
      final trust = StandardMetrics.trust();

      expect(trust.id, equals('trust'));
      expect(trust.name, equals('Source Trust'));
      expect(trust.weight, equals(0.1));
      expect(trust.defaultValue, equals(0.7));
      expect(trust.source, isA<ComputedSource>());
    });

    test('sentiment() returns correct definition', () {
      final sentiment = StandardMetrics.sentiment();

      expect(sentiment.id, equals('sentiment'));
      expect(sentiment.name, equals('Sentiment'));
      expect(sentiment.weight, equals(0.1));
      expect(sentiment.defaultValue, equals(0.5));
      expect(sentiment.source, isA<FactGraphSource>());
    });

    test('all() returns 5 metrics', () {
      final all = StandardMetrics.all();

      expect(all.length, equals(5));
      expect(all.map((m) => m.id), contains('risk'));
      expect(all.map((m) => m.id), contains('uncertainty'));
      expect(all.map((m) => m.id), contains('urgency'));
      expect(all.map((m) => m.id), contains('trust'));
      expect(all.map((m) => m.id), contains('sentiment'));
    });
  });

  // ===========================================================================
  // Coverage: metric_definition.dart lines 65-66
  //   (AppraisalMetricDef.fromJson with normalization)
  // ===========================================================================

  group('AppraisalMetricDef.fromJson with normalization', () {
    test('parses normalization field when present', () {
      // Covers lines 65-66: NormalizationConfig.fromJson
      final json = {
        'id': 'with-norm',
        'name': 'With Normalization',
        'source': {
          'type': 'static',
          'value': 0.5,
        },
        'normalization': {
          'method': 'minmax',
          'min': 0,
          'max': 100,
        },
      };

      final def = AppraisalMetricDef.fromJson(json);

      expect(def.normalization, isNotNull);
      expect(def.normalization, isA<MinMaxNormalization>());
      final norm = def.normalization! as MinMaxNormalization;
      expect(norm.min, equals(0.0));
      expect(norm.max, equals(100.0));
    });
  });

  // ===========================================================================
  // Coverage: metric_definition.dart line 153
  //   (AggregationConfig.fromJson weights parsing)
  // ===========================================================================

  group('AggregationConfig.fromJson with weights', () {
    test('parses weights map correctly', () {
      // Covers line 153: ?.map((k, v) => MapEntry(k, (v as num).toDouble()))
      final json = {
        'method': 'weighted_average',
        'weights': {
          'risk': 0.5,
          'trust': 0.3,
          'urgency': 0.2,
        },
      };

      final config = AggregationConfig.fromJson(json);

      expect(config.weights, isNotNull);
      expect(config.weights!['risk'], equals(0.5));
      expect(config.weights!['trust'], equals(0.3));
      expect(config.weights!['urgency'], equals(0.2));
    });

    test('fromJson defaults to weightedAverage for unknown method string', () {
      // Covers line 153: orElse: () => AggregationMethod.weightedAverage
      final json = {
        'method': 'invalid_unknown_method',
      };

      final config = AggregationConfig.fromJson(json);

      expect(config.method, equals(AggregationMethod.weightedAverage));
    });

    test('parses weights with integer values', () {
      final json = {
        'method': 'weighted_average',
        'weights': {
          'risk': 1,
          'trust': 2,
        },
      };

      final config = AggregationConfig.fromJson(json);

      expect(config.weights, isNotNull);
      expect(config.weights!['risk'], equals(1.0));
      expect(config.weights!['trust'], equals(2.0));
    });
  });
}
