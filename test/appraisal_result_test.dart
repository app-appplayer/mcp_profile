/// AppraisalResult Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  // =========================================================================
  // MetricResult
  // =========================================================================
  group('MetricResult', () {
    test('creates with required fields', () {
      const result = MetricResult(
        id: 'risk',
        normalizedValue: 0.7,
        sourceType: MetricSourceType.factgraph,
        confidence: 0.85,
      );

      expect(result.id, equals('risk'));
      expect(result.rawValue, isNull);
      expect(result.normalizedValue, equals(0.7));
      expect(result.sourceType, equals(MetricSourceType.factgraph));
      expect(result.confidence, equals(0.85));
    });

    test('creates with rawValue', () {
      const result = MetricResult(
        id: 'urgency',
        rawValue: 42.0,
        normalizedValue: 0.42,
        sourceType: MetricSourceType.computed,
        confidence: 0.6,
      );

      expect(result.rawValue, equals(42.0));
      expect(result.normalizedValue, equals(0.42));
    });

    group('isLowConfidence', () {
      test('returns true when confidence < 0.5', () {
        const result = MetricResult(
          id: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.factgraph,
          confidence: 0.3,
        );

        expect(result.isLowConfidence, isTrue);
      });

      test('returns false when confidence >= 0.5', () {
        const result = MetricResult(
          id: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.factgraph,
          confidence: 0.8,
        );

        expect(result.isLowConfidence, isFalse);
      });
    });

    group('isMediumConfidence', () {
      test('returns true when confidence >= 0.5 and < 0.8', () {
        const result = MetricResult(
          id: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.computed,
          confidence: 0.6,
        );

        expect(result.isMediumConfidence, isTrue);
      });

      test('returns false when confidence >= 0.8', () {
        const result = MetricResult(
          id: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.computed,
          confidence: 0.9,
        );

        expect(result.isMediumConfidence, isFalse);
      });

      test('returns false when confidence < 0.5', () {
        const result = MetricResult(
          id: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.computed,
          confidence: 0.3,
        );

        expect(result.isMediumConfidence, isFalse);
      });
    });

    group('isHighConfidence', () {
      test('returns true when confidence >= 0.8', () {
        const result = MetricResult(
          id: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
          confidence: 0.9,
        );

        expect(result.isHighConfidence, isTrue);
      });

      test('returns true at boundary 0.8', () {
        const result = MetricResult(
          id: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
          confidence: 0.8,
        );

        expect(result.isHighConfidence, isTrue);
      });

      test('returns false when confidence < 0.8', () {
        const result = MetricResult(
          id: 'm1',
          normalizedValue: 0.5,
          sourceType: MetricSourceType.static_,
          confidence: 0.4,
        );

        expect(result.isHighConfidence, isFalse);
      });
    });

    group('JSON serialization', () {
      test('toJson includes all fields', () {
        const result = MetricResult(
          id: 'risk',
          rawValue: 7.5,
          normalizedValue: 0.75,
          sourceType: MetricSourceType.factgraph,
          confidence: 0.9,
        );

        final json = result.toJson();

        expect(json['id'], equals('risk'));
        expect(json['rawValue'], equals(7.5));
        expect(json['normalizedValue'], equals(0.75));
        expect(json['sourceType'], equals('factgraph'));
        expect(json['confidence'], equals(0.9));
      });

      test('toJson omits null rawValue', () {
        const result = MetricResult(
          id: 'trust',
          normalizedValue: 0.8,
          sourceType: MetricSourceType.computed,
          confidence: 0.7,
        );

        final json = result.toJson();

        expect(json.containsKey('rawValue'), isFalse);
      });

      test('fromJson round-trips correctly', () {
        const original = MetricResult(
          id: 'sentiment',
          rawValue: 0.6,
          normalizedValue: 0.8,
          sourceType: MetricSourceType.llmDerived,
          confidence: 0.7,
        );

        final restored = MetricResult.fromJson(original.toJson());

        expect(restored.id, equals(original.id));
        expect(restored.rawValue, equals(original.rawValue));
        expect(restored.normalizedValue, equals(original.normalizedValue));
        expect(restored.sourceType, equals(original.sourceType));
        expect(restored.confidence, equals(original.confidence));
      });

      test('fromJson parses JSON map', () {
        final json = {
          'id': 'uncertainty',
          'normalizedValue': 0.5,
          'sourceType': 'computed',
          'confidence': 0.65,
        };

        final result = MetricResult.fromJson(json);

        expect(result.id, equals('uncertainty'));
        expect(result.rawValue, isNull);
        expect(result.normalizedValue, equals(0.5));
        expect(result.sourceType, equals(MetricSourceType.computed));
        expect(result.confidence, equals(0.65));
      });
    });
  });

  // =========================================================================
  // AppraisalResult
  // =========================================================================
  group('AppraisalResult', () {
    final now = DateTime(2024, 6, 15, 10, 30);

    MetricResult makeMetric(String id, double confidence) {
      return MetricResult(
        id: id,
        normalizedValue: 0.5,
        sourceType: MetricSourceType.factgraph,
        confidence: confidence,
      );
    }

    AppraisalResult makeResult({
      required Map<String, MetricResult> metrics,
    }) {
      return AppraisalResult(
        profileId: 'profile-1',
        contextId: 'context-1',
        asOf: now,
        metrics: metrics,
        aggregatedScore: 0.75,
        metadata: AppraisalMetadata(computedAt: now),
      );
    }

    test('creates with required fields', () {
      final result = makeResult(metrics: {
        'risk': makeMetric('risk', 0.9),
      });

      expect(result.profileId, equals('profile-1'));
      expect(result.contextId, equals('context-1'));
      expect(result.asOf, equals(now));
      expect(result.metrics.length, equals(1));
      expect(result.aggregatedScore, equals(0.75));
      expect(result.metadata, isNotNull);
    });

    group('getMetric', () {
      test('returns metric when found', () {
        final result = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
        });

        final metric = result.getMetric('risk');

        expect(metric, isNotNull);
        expect(metric!.id, equals('risk'));
      });

      test('returns null when not found', () {
        final result = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
        });

        expect(result.getMetric('nonexistent'), isNull);
      });
    });

    group('getNormalizedValue', () {
      test('returns value when metric found', () {
        final result = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
        });

        expect(result.getNormalizedValue('risk'), equals(0.5));
      });

      test('returns null when metric not found', () {
        final result = makeResult(metrics: {});

        expect(result.getNormalizedValue('missing'), isNull);
      });
    });

    group('isHighConfidence', () {
      test('returns true when all metrics >= 0.6', () {
        final result = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
          'trust': makeMetric('trust', 0.7),
          'urgency': makeMetric('urgency', 0.6),
        });

        expect(result.isHighConfidence, isTrue);
      });

      test('returns false when some metrics < 0.6', () {
        final result = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
          'trust': makeMetric('trust', 0.4),
        });

        expect(result.isHighConfidence, isFalse);
      });

      test('returns true for empty metrics', () {
        final result = makeResult(metrics: {});

        expect(result.isHighConfidence, isTrue);
      });
    });

    group('lowConfidenceMetrics', () {
      test('returns metrics with confidence <= 0.5', () {
        final result = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
          'trust': makeMetric('trust', 0.3),
          'urgency': makeMetric('urgency', 0.5),
        });

        final lowMetrics = result.lowConfidenceMetrics;

        expect(lowMetrics.length, equals(2));
        expect(lowMetrics.map((m) => m.id), contains('trust'));
        expect(lowMetrics.map((m) => m.id), contains('urgency'));
      });

      test('returns empty list when all metrics > 0.5', () {
        final result = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
          'trust': makeMetric('trust', 0.8),
        });

        expect(result.lowConfidenceMetrics, isEmpty);
      });
    });

    group('JSON serialization', () {
      test('toJson produces correct structure', () {
        final result = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
        });

        final json = result.toJson();

        expect(json['profileId'], equals('profile-1'));
        expect(json['contextId'], equals('context-1'));
        expect(json['asOf'], isA<String>());
        expect(json['metrics'], isA<Map>());
        expect(json['aggregatedScore'], equals(0.75));
        expect(json['metadata'], isA<Map>());
      });

      test('fromJson round-trips correctly', () {
        final original = makeResult(metrics: {
          'risk': makeMetric('risk', 0.9),
          'trust': makeMetric('trust', 0.7),
        });

        final restored = AppraisalResult.fromJson(original.toJson());

        expect(restored.profileId, equals(original.profileId));
        expect(restored.contextId, equals(original.contextId));
        expect(restored.aggregatedScore, equals(original.aggregatedScore));
        expect(restored.metrics.length, equals(2));
        expect(restored.metrics['risk']!.confidence, equals(0.9));
        expect(restored.metrics['trust']!.confidence, equals(0.7));
      });
    });
  });

  // =========================================================================
  // AppraisalMetadata
  // =========================================================================
  group('AppraisalMetadata', () {
    final computedAt = DateTime(2024, 6, 15, 10, 30);

    test('creates with defaults', () {
      final metadata = AppraisalMetadata(computedAt: computedAt);

      expect(metadata.computedAt, equals(computedAt));
      expect(metadata.durationMs, equals(0));
      expect(metadata.sourceCounts, isEmpty);
      expect(metadata.missingMetrics, isEmpty);
      expect(metadata.lowConfidenceMetrics, isNull);
      expect(metadata.metricsRequiringEvidence, isEmpty);
      expect(metadata.warnings, isEmpty);
    });

    test('creates with custom values', () {
      final metadata = AppraisalMetadata(
        computedAt: computedAt,
        durationMs: 150,
        sourceCounts: {'factgraph': 3, 'computed': 2},
        missingMetrics: ['sentiment'],
        lowConfidenceMetrics: ['trust'],
        metricsRequiringEvidence: ['risk'],
        warnings: ['Insufficient data for urgency'],
      );

      expect(metadata.durationMs, equals(150));
      expect(metadata.sourceCounts['factgraph'], equals(3));
      expect(metadata.sourceCounts['computed'], equals(2));
      expect(metadata.missingMetrics, contains('sentiment'));
      expect(metadata.lowConfidenceMetrics, contains('trust'));
      expect(metadata.metricsRequiringEvidence, contains('risk'));
      expect(metadata.warnings, contains('Insufficient data for urgency'));
    });

    test('duration getter returns Duration', () {
      final metadata = AppraisalMetadata(
        computedAt: computedAt,
        durationMs: 250,
      );

      expect(metadata.duration, equals(const Duration(milliseconds: 250)));
    });

    test('duration getter returns zero for default', () {
      final metadata = AppraisalMetadata(computedAt: computedAt);

      expect(metadata.duration, equals(Duration.zero));
    });

    group('JSON serialization', () {
      test('toJson with defaults omits empty collections', () {
        final metadata = AppraisalMetadata(computedAt: computedAt);
        final json = metadata.toJson();

        expect(json['computedAt'], isA<String>());
        expect(json['durationMs'], equals(0));
        expect(json.containsKey('sourceCounts'), isFalse);
        expect(json.containsKey('missingMetrics'), isFalse);
        expect(json.containsKey('lowConfidenceMetrics'), isFalse);
        expect(json.containsKey('metricsRequiringEvidence'), isFalse);
        expect(json.containsKey('warnings'), isFalse);
      });

      test('toJson includes non-empty collections', () {
        final metadata = AppraisalMetadata(
          computedAt: computedAt,
          durationMs: 100,
          sourceCounts: {'factgraph': 5},
          missingMetrics: ['urgency'],
          lowConfidenceMetrics: ['trust'],
          metricsRequiringEvidence: ['risk'],
          warnings: ['Data incomplete'],
        );

        final json = metadata.toJson();

        expect(json['sourceCounts'], isNotNull);
        expect(json['missingMetrics'], contains('urgency'));
        expect(json['lowConfidenceMetrics'], contains('trust'));
        expect(json['metricsRequiringEvidence'], contains('risk'));
        expect(json['warnings'], contains('Data incomplete'));
      });

      test('fromJson round-trips correctly', () {
        final original = AppraisalMetadata(
          computedAt: computedAt,
          durationMs: 200,
          sourceCounts: {'factgraph': 3},
          missingMetrics: ['sentiment'],
          lowConfidenceMetrics: ['urgency'],
          metricsRequiringEvidence: ['risk'],
          warnings: ['Low data quality'],
        );

        final restored = AppraisalMetadata.fromJson(original.toJson());

        expect(restored.durationMs, equals(original.durationMs));
        expect(restored.sourceCounts, equals(original.sourceCounts));
        expect(restored.missingMetrics, equals(original.missingMetrics));
        expect(
          restored.lowConfidenceMetrics,
          equals(original.lowConfidenceMetrics),
        );
        expect(
          restored.metricsRequiringEvidence,
          equals(original.metricsRequiringEvidence),
        );
        expect(restored.warnings, equals(original.warnings));
      });

      test('fromJson handles missing optional fields', () {
        final json = {
          'computedAt': computedAt.toIso8601String(),
        };

        final metadata = AppraisalMetadata.fromJson(json);

        expect(metadata.durationMs, equals(0));
        expect(metadata.sourceCounts, isEmpty);
        expect(metadata.missingMetrics, isEmpty);
        expect(metadata.lowConfidenceMetrics, isNull);
        expect(metadata.metricsRequiringEvidence, isEmpty);
        expect(metadata.warnings, isEmpty);
      });
    });
  });

  // =========================================================================
  // ConfidenceThresholdConfig
  // =========================================================================
  group('ConfidenceThresholdConfig', () {
    test('creates with defaults', () {
      const config = ConfidenceThresholdConfig();

      expect(config.minConfidenceThreshold, equals(0.3));
      expect(config.fallbackThreshold, equals(0.2));
      expect(config.triggerEvidenceOnLowConfidence, isTrue);
      expect(config.evidenceTriggerThreshold, equals(0.5));
    });

    test('creates with custom values', () {
      const config = ConfidenceThresholdConfig(
        minConfidenceThreshold: 0.5,
        fallbackThreshold: 0.1,
        triggerEvidenceOnLowConfidence: false,
        evidenceTriggerThreshold: 0.4,
      );

      expect(config.minConfidenceThreshold, equals(0.5));
      expect(config.fallbackThreshold, equals(0.1));
      expect(config.triggerEvidenceOnLowConfidence, isFalse);
      expect(config.evidenceTriggerThreshold, equals(0.4));
    });

    group('JSON serialization', () {
      test('toJson includes all fields', () {
        const config = ConfidenceThresholdConfig();
        final json = config.toJson();

        expect(json['minConfidenceThreshold'], equals(0.3));
        expect(json['fallbackThreshold'], equals(0.2));
        expect(json['triggerEvidenceOnLowConfidence'], isTrue);
        expect(json['evidenceTriggerThreshold'], equals(0.5));
      });

      test('fromJson round-trips correctly', () {
        const original = ConfidenceThresholdConfig(
          minConfidenceThreshold: 0.4,
          fallbackThreshold: 0.15,
          triggerEvidenceOnLowConfidence: false,
          evidenceTriggerThreshold: 0.6,
        );

        final restored =
            ConfidenceThresholdConfig.fromJson(original.toJson());

        expect(
          restored.minConfidenceThreshold,
          equals(original.minConfidenceThreshold),
        );
        expect(
          restored.fallbackThreshold,
          equals(original.fallbackThreshold),
        );
        expect(
          restored.triggerEvidenceOnLowConfidence,
          equals(original.triggerEvidenceOnLowConfidence),
        );
        expect(
          restored.evidenceTriggerThreshold,
          equals(original.evidenceTriggerThreshold),
        );
      });

      test('fromJson uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final config = ConfidenceThresholdConfig.fromJson(json);

        expect(config.minConfidenceThreshold, equals(0.3));
        expect(config.fallbackThreshold, equals(0.2));
        expect(config.triggerEvidenceOnLowConfidence, isTrue);
        expect(config.evidenceTriggerThreshold, equals(0.5));
      });
    });
  });
}
