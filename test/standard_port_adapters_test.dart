/// Standard Port Adapters — 0.2.0 contract tests.
///
/// Verifies the five mcp_bundle standard-port adapters provided by
/// mcp_profile per docs/03_DDD/core-adapters.md v0.2.0.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;
import 'package:mcp_profile/mcp_profile.dart';
import 'package:test/test.dart';

ProfileRuntime _buildRuntime(ProfileRegistry registry) {
  return ProfileRuntime(
    registry: registry,
    engines: EnginePorts.stub(),
  );
}

Profile _sampleProfile({String id = 'prof_x', List<String>? metricIds}) {
  final metrics = (metricIds ?? ['quality', 'clarity'])
      .map((id) => AppraisalMetricDef(
            id: id,
            name: id,
            source: const StaticSource(value: 0.75),
          ))
      .toList();
  return Profile(
    id: id,
    name: 'Sample $id',
    version: '0.1.0',
    sections: const [
      ProfileSection(
        name: 'appraisal',
        type: SectionType.custom,
        content: '',
      ),
    ],
    metadata: {
      '_appraisal': AppraisalSection(metrics: metrics),
    },
  );
}

void main() {
  group('ExpressionPortAdapter', () {
    late ExpressionPortAdapter adapter;

    setUp(() {
      adapter = ExpressionPortAdapter();
    });

    test('format substitutes flat variables', () {
      final out = adapter.format('hello {{name}}', {'name': 'Alice'});
      expect(out, 'hello Alice');
    });

    test('format substitutes nested variables', () {
      final out = adapter.format(
        'user: {{user.name}}',
        {
          'user': {'name': 'Bob'},
        },
      );
      expect(out, 'user: Bob');
    });

    test('format replaces missing variables with empty string', () {
      final out = adapter.format('hi {{missing}}', {});
      expect(out, 'hi ');
    });

    test('validate accepts balanced templates', () {
      expect(adapter.validate('{{foo}} + {{bar}}'), isTrue);
    });

    test('validate rejects unbalanced braces', () {
      expect(adapter.validate('{{foo'), isFalse);
      expect(adapter.validate('foo}}'), isFalse);
    });

    test('extractVariables returns deduplicated ordered list', () {
      final vars = adapter.extractVariables('{{a}} {{b}} {{a}} {{c}}');
      expect(vars, equals(['a', 'b', 'c']));
    });

    test('render never throws on missing ExpressionStyle metadata', () {
      final out = adapter.render(
        ExpressionStyle.defaultStyle,
        {'content': 'plain text'},
      );
      expect(out, isA<String>());
      expect(out, isNotEmpty);
    });
  });

  group('MetricsPortAdapter', () {
    late ProfileRegistry registry;
    late ProfileRuntime runtime;
    late MetricsPortAdapter adapter;

    setUp(() {
      registry = ProfileRegistry();
      registry.register(_sampleProfile(metricIds: ['quality', 'clarity']));
      runtime = _buildRuntime(registry);
      adapter = MetricsPortAdapter(runtime: runtime, registry: registry);
    });

    test('getMetric returns the metric result when owning profile found',
        () async {
      final result = await adapter.getMetric('quality', 'entity_1');
      expect(result, isNotNull);
      expect(result!.id, 'quality');
    });

    test('getMetric returns null when metric not registered anywhere',
        () async {
      final result = await adapter.getMetric('unknown_metric', 'entity_1');
      expect(result, isNull);
    });

    test('getMetrics batches requests and filters to requested names',
        () async {
      final results =
          await adapter.getMetrics(['quality', 'nonexistent'], 'entity_1');
      expect(results.keys, contains('quality'));
      expect(results.keys, isNot(contains('nonexistent')));
    });

    test('computeMetric degrades gracefully for unknown spec', () async {
      final result = await adapter.computeMetric(
        const bundle.MetricSpec(id: 'unknown_metric', entityId: 'entity_1'),
      );
      expect(result.id, 'unknown_metric');
      expect(result.confidence, lessThan(0.5));
    });
  });

  group('AppraisalPortAdapter', () {
    late ProfileRegistry registry;
    late ProfileRuntime runtime;
    late AppraisalPortAdapter adapter;

    setUp(() {
      registry = ProfileRegistry();
      registry.register(_sampleProfile());
      runtime = _buildRuntime(registry);
      adapter = AppraisalPortAdapter(runtime: runtime, registry: registry);
    });

    test('appraise resolves profile via context.profileId', () async {
      final result = await adapter.appraise(
        ['quality', 'clarity'],
        {'profileId': 'prof_x', 'entityId': 'entity_1'},
      );
      expect(result.profileId, 'prof_x');
    });

    test('appraise falls back to metric-id lookup when profileId missing',
        () async {
      final result = await adapter.appraise(['quality'], {});
      expect(result.profileId, 'prof_x');
    });

    test('appraise returns empty result when no profile matches', () async {
      final result = await adapter.appraise(['nonsense'], {});
      expect(result.metrics, isEmpty);
    });

    test('appraise filters metrics to requested dimensions', () async {
      final result = await adapter.appraise(
        ['quality'],
        {'profileId': 'prof_x'},
      );
      expect(result.metrics.keys, contains('quality'));
      expect(result.metrics.keys, isNot(contains('clarity')));
    });

    test('getHistory returns an empty list when unsupported', () async {
      final history = await adapter.getHistory(
        'prof_x',
        const bundle.RelativePeriod(
          value: 1,
          unit: bundle.PeriodUnit.days,
          direction: bundle.PeriodDirection.past,
        ),
      );
      expect(history, isA<List<bundle.AppraisalResult>>());
    });
  });

  group('DecisionPortAdapter', () {
    late ProfileRegistry registry;
    late ProfileRuntime runtime;
    late DecisionPortAdapter adapter;

    setUp(() {
      registry = ProfileRegistry();
      registry.register(_sampleProfile());
      runtime = _buildRuntime(registry);
      adapter = DecisionPortAdapter(runtime: runtime, registry: registry);
    });

    test('decide throws ProfileNotFoundException for unknown policy',
        () async {
      expect(
        () async => adapter.decide('ghost_profile', const {}),
        throwsA(isA<ProfileNotFoundException>()),
      );
    });

    test('decide returns DecisionGuidance for a known profile', () async {
      final guidance = await adapter.decide('prof_x', const {});
      expect(guidance, isNotNull);
    });
  });

  group('ProfileSummariesPortAdapter', () {
    late ProfileRegistry registry;
    late ProfileRuntime runtime;
    late ProfileSummariesPortAdapter adapter;

    setUp(() {
      registry = ProfileRegistry();
      registry.register(_sampleProfile(id: 'prof_a'));
      registry.register(_sampleProfile(id: 'prof_b', metricIds: ['safety']));
      runtime = _buildRuntime(registry);
      adapter =
          ProfileSummariesPortAdapter(runtime: runtime, registry: registry);
    });

    test('getProfileSummary aggregates dimensions across all profiles',
        () async {
      final summary = await adapter.getProfileSummary('entity_1');
      expect(summary, isNotNull);
      expect(summary!.entityId, 'entity_1');
      expect(summary.dimensionScores.keys, containsAll(['quality', 'clarity', 'safety']));
    });

    test('getProfileSummary returns null when no profiles have appraisal',
        () async {
      final emptyRegistry = ProfileRegistry();
      final emptyRuntime = _buildRuntime(emptyRegistry);
      final emptyAdapter = ProfileSummariesPortAdapter(
        runtime: emptyRuntime,
        registry: emptyRegistry,
      );
      expect(await emptyAdapter.getProfileSummary('any'), isNull);
    });
  });
}
