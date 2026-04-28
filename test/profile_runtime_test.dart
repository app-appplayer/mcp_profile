/// ProfileRuntime — pipeline tests for the 0.2.0 unified runtime.
library;

import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

Profile _profileWith({
  String id = 'p1',
  List<AppraisalMetricDef>? metrics,
  List<DecisionPolicy>? policies,
}) {
  final metadata = <String, dynamic>{};
  if (metrics != null) {
    metadata['_appraisal'] = AppraisalSection(metrics: metrics);
  }
  if (policies != null) {
    metadata['_decision'] = DecisionPolicySection(policies: policies);
  }
  return Profile(
    id: id,
    name: 'Test $id',
    version: '0.1.0',
    metadata: metadata,
  );
}

DefaultRuntimeContext _context({String profileId = 'p1'}) {
  return DefaultRuntimeContext(
    profileId: profileId,
    entityId: 'e1',
  );
}

void main() {
  group('ProfileRuntime.apply', () {
    late ProfileRegistry registry;
    late ProfileRuntime runtime;

    setUp(() {
      registry = ProfileRegistry();
      runtime = ProfileRuntime(
        registry: registry,
        engines: EnginePorts.stub(),
      );
    });

    test('throws ProfileNotFoundException when profile absent', () async {
      expect(
        () async => runtime.apply(_context(profileId: 'missing')),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });

    test('returns an empty-appraisal result when profile has no metrics',
        () async {
      registry.register(_profileWith());
      final result = await runtime.apply(_context());
      expect(result.profileId, 'p1');
      expect(result.appraisal.metrics, isEmpty);
      expect(result.appraisal.aggregatedScore, 1.0);
    });

    test('returns defaultProceed decision when no policies', () async {
      registry.register(_profileWith(metrics: [
        AppraisalMetricDef(
          id: 'quality',
          name: 'quality',
          source: const StaticSource(value: 0.8),
        ),
      ]));
      final result = await runtime.apply(_context());
      expect(result.decision.action, DecisionAction.proceed);
    });

    test('returns defaultStyle expression when no policies', () async {
      registry.register(_profileWith());
      final result = await runtime.apply(_context());
      expect(result.expression, isNotNull);
    });

    test('runs format stage when rawContent is provided', () async {
      registry.register(_profileWith());
      final result = await runtime.apply(_context(), rawContent: 'hello');
      expect(result.formatted, isNotNull);
      expect(result.formatted!.content, 'hello');
    });

    test('skips format stage when rawContent is null', () async {
      registry.register(_profileWith());
      final result = await runtime.apply(_context());
      expect(result.formatted, isNull);
    });

    test('records start/end metadata with clock', () async {
      registry.register(_profileWith());
      final result = await runtime.apply(_context());
      expect(result.metadata.profileVersion, '0.1.0');
      expect(
        result.metadata.completedAt.isAfter(result.metadata.startedAt) ||
            result.metadata.completedAt == result.metadata.startedAt,
        isTrue,
      );
    });
  });

  group('EnginePorts', () {
    test('stub factory produces a usable container', () {
      final ports = EnginePorts.stub();
      expect(ports.appraisal, isA<AppraisalEnginePort>());
      expect(ports.decision, isA<DecisionEnginePort>());
      expect(ports.expression, isA<ExpressionEnginePort>());
      expect(ports.facts, isNull);
      expect(ports.patterns, isNull);
      expect(ports.summaries, isNull);
      expect(ports.llm, isNull);
    });

    test('copyWith replaces selected fields only', () {
      final base = EnginePorts.stub();
      final replaced = base.copyWith(
        decision: const DefaultDecisionEnginePort(),
      );
      expect(replaced.appraisal, base.appraisal);
      expect(replaced.decision, isA<DefaultDecisionEnginePort>());
      expect(replaced.expression, base.expression);
    });
  });
}
