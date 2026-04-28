/// MetricSource Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  // =========================================================================
  // MetricSourceType
  // =========================================================================
  group('MetricSourceType', () {
    test('has 4 values', () {
      expect(MetricSourceType.values.length, equals(4));
    });

    test('contains all expected values', () {
      expect(MetricSourceType.values, contains(MetricSourceType.factgraph));
      expect(MetricSourceType.values, contains(MetricSourceType.computed));
      expect(MetricSourceType.values, contains(MetricSourceType.static_));
      expect(MetricSourceType.values, contains(MetricSourceType.llmDerived));
    });

    group('toJson', () {
      test('factgraph serializes to factgraph', () {
        expect(MetricSourceType.factgraph.toJson(), equals('factgraph'));
      });

      test('computed serializes to computed', () {
        expect(MetricSourceType.computed.toJson(), equals('computed'));
      });

      test('static_ serializes to static', () {
        expect(MetricSourceType.static_.toJson(), equals('static'));
      });

      test('llmDerived serializes to llm_derived', () {
        expect(MetricSourceType.llmDerived.toJson(), equals('llm_derived'));
      });
    });

    group('fromJson', () {
      test('parses factgraph', () {
        expect(
          MetricSourceType.fromJson('factgraph'),
          equals(MetricSourceType.factgraph),
        );
      });

      test('parses computed', () {
        expect(
          MetricSourceType.fromJson('computed'),
          equals(MetricSourceType.computed),
        );
      });

      test('parses static', () {
        expect(
          MetricSourceType.fromJson('static'),
          equals(MetricSourceType.static_),
        );
      });

      test('parses llm_derived', () {
        expect(
          MetricSourceType.fromJson('llm_derived'),
          equals(MetricSourceType.llmDerived),
        );
      });

      test('unknown value defaults to computed', () {
        expect(
          MetricSourceType.fromJson('unknown_source'),
          equals(MetricSourceType.computed),
        );
      });
    });
  });

  // =========================================================================
  // FactGraphSource
  // =========================================================================
  group('FactGraphSource', () {
    test('creates with defaults', () {
      const source = FactGraphSource();

      expect(source.factTypes, isNull);
      expect(source.entityTypes, isNull);
      expect(source.period, isNull);
      expect(source.filters, isNull);
      expect(source.aggregation, equals(FactAggregation.count));
      expect(source.field, isNull);
    });

    test('creates with all fields', () {
      const source = FactGraphSource(
        factTypes: ['risk_indicator', 'security_issue'],
        entityTypes: ['user', 'system'],
        filters: {'severity': 'high'},
        aggregation: FactAggregation.max,
        field: 'severity',
      );

      expect(source.factTypes, equals(['risk_indicator', 'security_issue']));
      expect(source.entityTypes, equals(['user', 'system']));
      expect(source.filters, equals({'severity': 'high'}));
      expect(source.aggregation, equals(FactAggregation.max));
      expect(source.field, equals('severity'));
    });

    test('type getter returns factgraph', () {
      const source = FactGraphSource();

      expect(source.type, equals(MetricSourceType.factgraph));
    });

    group('JSON serialization', () {
      test('toJson produces correct structure with factQuery', () {
        const source = FactGraphSource(
          factTypes: ['risk_indicator'],
          aggregation: FactAggregation.max,
          field: 'severity',
        );

        final json = source.toJson();

        expect(json['type'], equals('factgraph'));
        expect(json['factQuery'], isA<Map>());
        final factQuery = json['factQuery'] as Map<String, dynamic>;
        expect(factQuery['factTypes'], equals(['risk_indicator']));
        expect(factQuery['aggregation'], equals('max'));
        expect(factQuery['field'], equals('severity'));
      });

      test('toJson omits null fields in factQuery', () {
        const source = FactGraphSource();

        final json = source.toJson();
        final factQuery = json['factQuery'] as Map<String, dynamic>;

        expect(factQuery.containsKey('factTypes'), isFalse);
        expect(factQuery.containsKey('entityTypes'), isFalse);
        expect(factQuery.containsKey('period'), isFalse);
        expect(factQuery.containsKey('filters'), isFalse);
        expect(factQuery.containsKey('field'), isFalse);
        expect(factQuery['aggregation'], equals('count'));
      });

      test('fromJson parses factQuery sub-object', () {
        final json = {
          'type': 'factgraph',
          'factQuery': {
            'factTypes': ['deadline', 'sla'],
            'aggregation': 'avg',
            'field': 'urgency_score',
          },
        };

        final source = FactGraphSource.fromJson(json);

        expect(source.factTypes, equals(['deadline', 'sla']));
        expect(source.aggregation, equals(FactAggregation.avg));
        expect(source.field, equals('urgency_score'));
      });

      test('fromJson round-trips correctly', () {
        const original = FactGraphSource(
          factTypes: ['feedback'],
          entityTypes: ['customer'],
          aggregation: FactAggregation.sum,
          field: 'score',
        );

        final restored = FactGraphSource.fromJson(original.toJson());

        expect(restored.factTypes, equals(original.factTypes));
        expect(restored.entityTypes, equals(original.entityTypes));
        expect(restored.aggregation, equals(original.aggregation));
        expect(restored.field, equals(original.field));
      });
    });
  });

  // =========================================================================
  // ComputedSource
  // =========================================================================
  group('ComputedSource', () {
    test('creates with expression', () {
      const source = ComputedSource(expression: '1 - avgConfidence');

      expect(source.expression, equals('1 - avgConfidence'));
    });

    test('type getter returns computed', () {
      const source = ComputedSource(expression: 'x + y');

      expect(source.type, equals(MetricSourceType.computed));
    });

    group('JSON serialization', () {
      test('toJson produces correct structure', () {
        const source = ComputedSource(expression: 'risk * 0.5');

        final json = source.toJson();

        expect(json['type'], equals('computed'));
        expect(json['expression'], equals('risk * 0.5'));
      });

      test('fromJson parses correctly', () {
        final json = {
          'type': 'computed',
          'expression': 'avgSourceReliability',
        };

        final source = ComputedSource.fromJson(json);

        expect(source.expression, equals('avgSourceReliability'));
      });

      test('fromJson round-trips correctly', () {
        const original = ComputedSource(expression: '1 - avgConfidence');

        final restored = ComputedSource.fromJson(original.toJson());

        expect(restored.expression, equals(original.expression));
      });
    });
  });

  // =========================================================================
  // StaticSource
  // =========================================================================
  group('StaticSource', () {
    test('creates with value', () {
      const source = StaticSource(value: 0.75);

      expect(source.value, equals(0.75));
    });

    test('type getter returns static_', () {
      const source = StaticSource(value: 0.5);

      expect(source.type, equals(MetricSourceType.static_));
    });

    group('JSON serialization', () {
      test('toJson produces correct structure', () {
        const source = StaticSource(value: 0.42);

        final json = source.toJson();

        expect(json['type'], equals('static'));
        expect(json['value'], equals(0.42));
      });

      test('fromJson parses correctly', () {
        final json = {
          'type': 'static',
          'value': 0.9,
        };

        final source = StaticSource.fromJson(json);

        expect(source.value, equals(0.9));
      });

      test('fromJson round-trips correctly', () {
        const original = StaticSource(value: 0.33);

        final restored = StaticSource.fromJson(original.toJson());

        expect(restored.value, equals(original.value));
      });
    });
  });

  // =========================================================================
  // LlmDerivedSource
  // =========================================================================
  group('LlmDerivedSource', () {
    test('creates with defaults', () {
      const source = LlmDerivedSource(prompt: 'Analyze the risk level');

      expect(source.prompt, equals('Analyze the risk level'));
      expect(source.outputType, equals(LlmOutputType.numeric));
      expect(source.categories, isNull);
      expect(source.model, isNull);
      expect(source.cacheKey, isNull);
    });

    test('creates with all fields', () {
      const source = LlmDerivedSource(
        prompt: 'Classify sentiment',
        outputType: LlmOutputType.categorical,
        categories: {'positive': 1.0, 'neutral': 0.5, 'negative': 0.0},
        model: 'gpt-4',
        cacheKey: 'sentiment-v1',
      );

      expect(source.prompt, equals('Classify sentiment'));
      expect(source.outputType, equals(LlmOutputType.categorical));
      expect(source.categories!['positive'], equals(1.0));
      expect(source.categories!['neutral'], equals(0.5));
      expect(source.categories!['negative'], equals(0.0));
      expect(source.model, equals('gpt-4'));
      expect(source.cacheKey, equals('sentiment-v1'));
    });

    test('type getter returns llmDerived', () {
      const source = LlmDerivedSource(prompt: 'test');

      expect(source.type, equals(MetricSourceType.llmDerived));
    });

    group('JSON serialization', () {
      test('toJson produces correct structure with llmConfig', () {
        const source = LlmDerivedSource(
          prompt: 'Analyze risk',
          model: 'claude-3',
          cacheKey: 'risk-cache',
        );

        final json = source.toJson();

        expect(json['type'], equals('llm_derived'));
        expect(json['llmConfig'], isA<Map>());
        final llmConfig = json['llmConfig'] as Map<String, dynamic>;
        expect(llmConfig['prompt'], equals('Analyze risk'));
        expect(llmConfig['outputType'], equals('numeric'));
        expect(llmConfig['model'], equals('claude-3'));
        expect(llmConfig['cacheKey'], equals('risk-cache'));
      });

      test('toJson omits null optional fields', () {
        const source = LlmDerivedSource(prompt: 'Simple analysis');

        final json = source.toJson();
        final llmConfig = json['llmConfig'] as Map<String, dynamic>;

        expect(llmConfig.containsKey('categories'), isFalse);
        expect(llmConfig.containsKey('model'), isFalse);
        expect(llmConfig.containsKey('cacheKey'), isFalse);
      });

      test('fromJson parses llmConfig sub-object', () {
        final json = {
          'type': 'llm_derived',
          'llmConfig': {
            'prompt': 'Rate the urgency',
            'outputType': 'categorical',
            'categories': {'high': 1.0, 'medium': 0.5, 'low': 0.0},
            'model': 'gpt-4',
          },
        };

        final source = LlmDerivedSource.fromJson(json);

        expect(source.prompt, equals('Rate the urgency'));
        expect(source.outputType, equals(LlmOutputType.categorical));
        expect(source.categories!['high'], equals(1.0));
        expect(source.model, equals('gpt-4'));
      });

      test('fromJson round-trips correctly', () {
        const original = LlmDerivedSource(
          prompt: 'Evaluate trust',
          outputType: LlmOutputType.categorical,
          categories: {'trusted': 1.0, 'untrusted': 0.0},
          model: 'claude-3',
          cacheKey: 'trust-v2',
        );

        final restored = LlmDerivedSource.fromJson(original.toJson());

        expect(restored.prompt, equals(original.prompt));
        expect(restored.outputType, equals(original.outputType));
        expect(restored.categories, equals(original.categories));
        expect(restored.model, equals(original.model));
        expect(restored.cacheKey, equals(original.cacheKey));
      });
    });
  });

  // =========================================================================
  // MetricSource.fromJson dispatch
  // =========================================================================
  group('MetricSource.fromJson', () {
    test('dispatches factgraph type', () {
      final json = {
        'type': 'factgraph',
        'factQuery': {
          'factTypes': ['risk_indicator'],
          'aggregation': 'count',
        },
      };

      final source = MetricSource.fromJson(json);

      expect(source, isA<FactGraphSource>());
    });

    test('dispatches computed type', () {
      final json = {
        'type': 'computed',
        'expression': '1 - avgConfidence',
      };

      final source = MetricSource.fromJson(json);

      expect(source, isA<ComputedSource>());
    });

    test('dispatches static type', () {
      final json = {
        'type': 'static',
        'value': 0.5,
      };

      final source = MetricSource.fromJson(json);

      expect(source, isA<StaticSource>());
    });

    test('dispatches llm_derived type', () {
      final json = {
        'type': 'llm_derived',
        'llmConfig': {
          'prompt': 'Analyze this',
          'outputType': 'numeric',
        },
      };

      final source = MetricSource.fromJson(json);

      expect(source, isA<LlmDerivedSource>());
    });

    test('throws on unknown type', () {
      final json = {
        'type': 'unknown_type',
      };

      expect(
        () => MetricSource.fromJson(json),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // =========================================================================
  // FactAggregation
  // =========================================================================
  group('FactAggregation', () {
    test('has 6 values', () {
      expect(FactAggregation.values.length, equals(6));
    });

    test('contains all expected values', () {
      expect(FactAggregation.values, contains(FactAggregation.count));
      expect(FactAggregation.values, contains(FactAggregation.avg));
      expect(FactAggregation.values, contains(FactAggregation.max));
      expect(FactAggregation.values, contains(FactAggregation.min));
      expect(FactAggregation.values, contains(FactAggregation.sum));
      expect(FactAggregation.values, contains(FactAggregation.presence));
    });
  });

  // =========================================================================
  // LlmOutputType
  // =========================================================================
  group('LlmOutputType', () {
    test('has 2 values', () {
      expect(LlmOutputType.values.length, equals(2));
    });

    test('contains numeric', () {
      expect(LlmOutputType.values, contains(LlmOutputType.numeric));
    });

    test('contains categorical', () {
      expect(LlmOutputType.values, contains(LlmOutputType.categorical));
    });
  });

  // =========================================================================
  // Coverage: metric_source.dart line 262 (LlmDerivedSource.fromJson orElse)
  // =========================================================================
  group('LlmDerivedSource.fromJson with invalid outputType', () {
    test('falls back to LlmOutputType.numeric for unknown outputType string', () {
      // Covers line 262: orElse: () => LlmOutputType.numeric
      final json = {
        'prompt': 'test prompt',
        'outputType': 'invalid_type',
      };

      final source = LlmDerivedSource.fromJson(json);

      expect(source.prompt, equals('test prompt'));
      expect(source.outputType, equals(LlmOutputType.numeric));
    });
  });

  // =========================================================================
  // Coverage: metric_source.dart line 122 (FactGraphSource.fromJson with period)
  // =========================================================================
  group('FactGraphSource.fromJson with period', () {
    test('parses period from factQuery', () {
      // Covers line 122: Period.fromJson(factQuery['period'] as Map<String, dynamic>)
      final json = {
        'type': 'factgraph',
        'factQuery': {
          'factTypes': ['deadline'],
          'aggregation': 'max',
          'period': {
            'type': 'relative',
            'unit': 'days',
            'value': 30,
          },
        },
      };

      final source = FactGraphSource.fromJson(json);

      expect(source.period, isNotNull);
      expect(source.factTypes, equals(['deadline']));
      expect(source.aggregation, equals(FactAggregation.max));
    });
  });

  // =========================================================================
  // Coverage: metric_source.dart line 127 (FactGraphSource.fromJson orElse)
  // =========================================================================
  group('FactGraphSource.fromJson with unknown aggregation', () {
    test('falls back to count for unknown aggregation string', () {
      // Covers line 127: orElse: () => FactAggregation.count
      final json = {
        'type': 'factgraph',
        'factQuery': {
          'factTypes': ['event'],
          'aggregation': 'totally_unknown_aggregation',
          'filters': {'status': 'active'},
        },
      };

      final source = FactGraphSource.fromJson(json);

      expect(source.aggregation, equals(FactAggregation.count));
      expect(source.filters, equals({'status': 'active'}));
    });
  });

  // =========================================================================
  // Coverage: metric_source.dart line 262 (LlmDerivedSource.toJson categories)
  // =========================================================================
  group('LlmDerivedSource.toJson with categories', () {
    test('includes categories in llmConfig when present', () {
      // Covers line 262: if (categories != null) 'categories': categories
      // (Already partially covered, but verifying the exact path)
      const source = LlmDerivedSource(
        prompt: 'Classify this',
        outputType: LlmOutputType.categorical,
        categories: {'high': 1.0, 'low': 0.0},
      );

      final json = source.toJson();
      final llmConfig = json['llmConfig'] as Map<String, dynamic>;

      expect(llmConfig['categories'], isNotNull);
      expect(llmConfig['categories'], equals({'high': 1.0, 'low': 0.0}));
    });
  });
}
