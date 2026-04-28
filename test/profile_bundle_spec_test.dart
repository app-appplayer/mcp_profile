/// ProfileBundleSpec Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  // ===========================================================================
  // ProfileScope
  // ===========================================================================

  group('ProfileScope', () {
    test('has 4 expected values', () {
      expect(ProfileScope.values.length, equals(4));
      expect(ProfileScope.values, containsAll([
        ProfileScope.person,
        ProfileScope.team,
        ProfileScope.project,
        ProfileScope.global,
      ]));
    });

    test('toJsonName returns "person" for person', () {
      expect(ProfileScope.person.toJsonName(), equals('person'));
    });

    test('toJsonName returns "team" for team', () {
      expect(ProfileScope.team.toJsonName(), equals('team'));
    });

    test('toJsonName returns "project" for project', () {
      expect(ProfileScope.project.toJsonName(), equals('project'));
    });

    test('toJsonName returns "global" for global', () {
      expect(ProfileScope.global.toJsonName(), equals('global'));
    });
  });

  // ===========================================================================
  // ProfileManifest
  // ===========================================================================

  group('ProfileManifest', () {
    test('creates with required fields', () {
      const manifest = ProfileManifest(
        id: 'com.example.safety',
        name: 'Safety Profile',
        version: '1.0.0',
        provider: 'Example Corp',
        scope: ProfileScope.project,
      );
      expect(manifest.id, equals('com.example.safety'));
      expect(manifest.name, equals('Safety Profile'));
      expect(manifest.version, equals('1.0.0'));
      expect(manifest.provider, equals('Example Corp'));
      expect(manifest.scope, equals(ProfileScope.project));
    });

    test('has correct default values', () {
      const manifest = ProfileManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        provider: 'Test',
        scope: ProfileScope.person,
      );
      expect(manifest.priority, equals(50));
      expect(manifest.defaultEnabled, isTrue);
      expect(manifest.tags, isEmpty);
      expect(manifest.description, isNull);
      expect(manifest.appliesTo, isNull);
      expect(manifest.compat, isNull);
    });

    test('creates with all optional fields', () {
      const manifest = ProfileManifest(
        id: 'com.example.full',
        name: 'Full Manifest',
        version: '2.0.0',
        provider: 'Full Corp',
        scope: ProfileScope.global,
        description: 'A full manifest',
        appliesTo: ['skill.code.*', 'skill.review.*'],
        priority: 80,
        defaultEnabled: false,
        tags: ['safety', 'enterprise'],
        compat: CompatConfig(schemaVersion: '>=0.1.0'),
      );
      expect(manifest.description, equals('A full manifest'));
      expect(manifest.appliesTo, contains('skill.code.*'));
      expect(manifest.priority, equals(80));
      expect(manifest.defaultEnabled, isFalse);
      expect(manifest.tags.length, equals(2));
      expect(manifest.compat, isNotNull);
    });

    test('fromJson creates instance with required fields', () {
      final manifest = ProfileManifest.fromJson({
        'id': 'com.example.test',
        'name': 'Test Profile',
        'version': '1.0.0',
        'provider': 'TestCo',
        'scope': 'team',
      });
      expect(manifest.id, equals('com.example.test'));
      expect(manifest.name, equals('Test Profile'));
      expect(manifest.version, equals('1.0.0'));
      expect(manifest.provider, equals('TestCo'));
      expect(manifest.scope, equals(ProfileScope.team));
    });

    test('fromJson uses defaults for optional fields', () {
      final manifest = ProfileManifest.fromJson({
        'id': 'test',
        'name': 'Test',
        'version': '1.0.0',
        'provider': 'Test',
        'scope': 'person',
      });
      expect(manifest.priority, equals(50));
      expect(manifest.defaultEnabled, isTrue);
      expect(manifest.tags, isEmpty);
    });

    test('fromJson parses all optional fields', () {
      final manifest = ProfileManifest.fromJson({
        'id': 'test',
        'name': 'Test',
        'version': '1.0.0',
        'provider': 'Test',
        'scope': 'global',
        'description': 'Description',
        'appliesTo': ['skill.*'],
        'priority': 90,
        'defaultEnabled': false,
        'tags': ['tag1', 'tag2'],
        'compat': {
          'schemaVersion': '>=0.1.0',
          'requirements': {'mcp_bundle': '>=1.0.0'},
        },
      });
      expect(manifest.description, equals('Description'));
      expect(manifest.appliesTo, contains('skill.*'));
      expect(manifest.priority, equals(90));
      expect(manifest.defaultEnabled, isFalse);
      expect(manifest.tags.length, equals(2));
      expect(manifest.compat, isNotNull);
      expect(manifest.compat!.schemaVersion, equals('>=0.1.0'));
    });

    test('toJson produces correct output with required fields only', () {
      const manifest = ProfileManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        provider: 'TestCo',
        scope: ProfileScope.project,
      );
      final json = manifest.toJson();
      expect(json['id'], equals('test'));
      expect(json['name'], equals('Test'));
      expect(json['version'], equals('1.0.0'));
      expect(json['provider'], equals('TestCo'));
      expect(json['scope'], equals('project'));
      // Defaults are omitted
      expect(json.containsKey('priority'), isFalse);
      expect(json.containsKey('defaultEnabled'), isFalse);
      expect(json.containsKey('tags'), isFalse);
      expect(json.containsKey('description'), isFalse);
    });

    test('toJson includes non-default optional fields', () {
      const manifest = ProfileManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        provider: 'TestCo',
        scope: ProfileScope.person,
        priority: 80,
        defaultEnabled: false,
        tags: ['important'],
        description: 'Desc',
      );
      final json = manifest.toJson();
      expect(json['priority'], equals(80));
      expect(json['defaultEnabled'], isFalse);
      expect(json['tags'], contains('important'));
      expect(json['description'], equals('Desc'));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = ProfileManifest(
        id: 'com.example.roundtrip',
        name: 'Roundtrip',
        version: '3.0.0',
        provider: 'RoundtripCo',
        scope: ProfileScope.team,
        description: 'Roundtrip test',
        priority: 75,
        tags: ['a', 'b'],
      );
      final json = original.toJson();
      final restored = ProfileManifest.fromJson(json);
      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.version, equals(original.version));
      expect(restored.provider, equals(original.provider));
      expect(restored.scope, equals(original.scope));
      expect(restored.description, equals(original.description));
      expect(restored.priority, equals(original.priority));
      expect(restored.tags.length, equals(original.tags.length));
    });
  });

  // ===========================================================================
  // CompatConfig
  // ===========================================================================

  group('CompatConfig', () {
    test('creates with no fields', () {
      const config = CompatConfig();
      expect(config.schemaVersion, isNull);
      expect(config.requirements, isNull);
    });

    test('creates with all fields', () {
      const config = CompatConfig(
        schemaVersion: '>=0.1.0',
        requirements: {'mcp_bundle': '>=1.0.0', 'mcp_skill': '>=0.5.0'},
      );
      expect(config.schemaVersion, equals('>=0.1.0'));
      expect(config.requirements, isNotNull);
      expect(config.requirements!.length, equals(2));
      expect(config.requirements!['mcp_bundle'], equals('>=1.0.0'));
    });

    test('fromJson creates instance with all fields', () {
      final config = CompatConfig.fromJson({
        'schemaVersion': '>=0.2.0',
        'requirements': {'some_pkg': '>=2.0.0'},
      });
      expect(config.schemaVersion, equals('>=0.2.0'));
      expect(config.requirements, isNotNull);
      expect(config.requirements!['some_pkg'], equals('>=2.0.0'));
    });

    test('fromJson handles missing fields', () {
      final config = CompatConfig.fromJson(<String, dynamic>{});
      expect(config.schemaVersion, isNull);
      expect(config.requirements, isNull);
    });

    test('toJson produces correct output', () {
      const config = CompatConfig(
        schemaVersion: '>=0.1.0',
        requirements: {'pkg': '>=1.0.0'},
      );
      final json = config.toJson();
      expect(json['schemaVersion'], equals('>=0.1.0'));
      expect(json['requirements'], isNotNull);
    });

    test('toJson omits null fields', () {
      const config = CompatConfig();
      final json = config.toJson();
      expect(json.containsKey('schemaVersion'), isFalse);
      expect(json.containsKey('requirements'), isFalse);
    });

    test('fromJson/toJson roundtrip preserves data', () {
      const original = CompatConfig(
        schemaVersion: '>=0.3.0',
        requirements: {'dep1': '>=1.0.0', 'dep2': '>=2.0.0'},
      );
      final json = original.toJson();
      final restored = CompatConfig.fromJson(json);
      expect(restored.schemaVersion, equals(original.schemaVersion));
      expect(restored.requirements!.length, equals(original.requirements!.length));
      expect(
        restored.requirements!['dep1'],
        equals(original.requirements!['dep1']),
      );
    });
  });

  // ===========================================================================
  // SpecProfileBundle
  // ===========================================================================

  group('SpecProfileBundle', () {
    SpecProfileBundle createTestBundle({
      String schemaVersion = '0.1.0',
      ProfileManifest? manifest,
      AppraisalSection? appraisals,
    }) {
      return SpecProfileBundle(
        schemaVersion: schemaVersion,
        manifest: manifest ??
            const ProfileManifest(
              id: 'com.example.test',
              name: 'Test Bundle',
              version: '1.0.0',
              provider: 'TestCo',
              scope: ProfileScope.project,
              priority: 60,
            ),
        appraisals: appraisals ??
            AppraisalSection(
              metrics: [
                AppraisalMetricDef(
                  id: 'risk',
                  name: 'Risk',
                  source: const StaticSource(value: 0.5),
                ),
              ],
            ),
      );
    }

    test('creates with required fields', () {
      final bundle = createTestBundle();
      expect(bundle.schemaVersion, equals('0.1.0'));
      expect(bundle.manifest, isNotNull);
      expect(bundle.appraisals, isNotNull);
      expect(bundle.decisionPolicies, isNull);
      expect(bundle.expressionPolicies, isNull);
      expect(bundle.extensions, isNull);
    });

    test('convenience getter id delegates to manifest', () {
      final bundle = createTestBundle();
      expect(bundle.id, equals('com.example.test'));
    });

    test('convenience getter name delegates to manifest', () {
      final bundle = createTestBundle();
      expect(bundle.name, equals('Test Bundle'));
    });

    test('convenience getter version delegates to manifest', () {
      final bundle = createTestBundle();
      expect(bundle.version, equals('1.0.0'));
    });

    test('convenience getter scope delegates to manifest', () {
      final bundle = createTestBundle();
      expect(bundle.scope, equals(ProfileScope.project));
    });

    test('convenience getter priority delegates to manifest', () {
      final bundle = createTestBundle();
      expect(bundle.priority, equals(60));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'schemaVersion': '0.1.0',
        'manifest': {
          'id': 'com.example.json',
          'name': 'JSON Bundle',
          'version': '2.0.0',
          'provider': 'JSONCo',
          'scope': 'global',
        },
        'appraisals': {
          'metrics': [
            {
              'id': 'risk',
              'name': 'Risk',
              'source': {'type': 'static', 'value': 0.3},
              'weight': 1.0,
            },
          ],
        },
      };
      final bundle = SpecProfileBundle.fromJson(json);
      expect(bundle.schemaVersion, equals('0.1.0'));
      expect(bundle.id, equals('com.example.json'));
      expect(bundle.name, equals('JSON Bundle'));
      expect(bundle.scope, equals(ProfileScope.global));
      expect(bundle.appraisals.metrics.length, equals(1));
    });

    test('toJson produces correct output', () {
      final bundle = createTestBundle();
      final json = bundle.toJson();
      expect(json['schemaVersion'], equals('0.1.0'));
      expect(json['manifest'], isNotNull);
      expect(json['appraisals'], isNotNull);
      expect(json.containsKey('decisionPolicies'), isFalse);
      expect(json.containsKey('expressionPolicies'), isFalse);
      expect(json.containsKey('extensions'), isFalse);
    });

    test('toJson includes extensions when present', () {
      final bundle = SpecProfileBundle(
        schemaVersion: '0.1.0',
        manifest: const ProfileManifest(
          id: 'test',
          name: 'Test',
          version: '1.0.0',
          provider: 'TestCo',
          scope: ProfileScope.person,
        ),
        appraisals: AppraisalSection(
          metrics: [
            AppraisalMetricDef(
              id: 'risk',
              name: 'Risk',
              source: const StaticSource(value: 0.5),
            ),
          ],
        ),
        extensions: {'customKey': 'customValue'},
      );
      final json = bundle.toJson();
      expect(json['extensions'], isNotNull);
      expect(json['extensions']['customKey'], equals('customValue'));
    });

    test('fromJson/toJson roundtrip preserves data', () {
      final original = createTestBundle(
        schemaVersion: '0.2.0',
        manifest: const ProfileManifest(
          id: 'com.example.roundtrip',
          name: 'Roundtrip',
          version: '3.0.0',
          provider: 'RoundtripCo',
          scope: ProfileScope.team,
          priority: 80,
        ),
      );
      final json = original.toJson();
      final restored = SpecProfileBundle.fromJson(json);
      expect(restored.schemaVersion, equals(original.schemaVersion));
      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.version, equals(original.version));
      expect(restored.scope, equals(original.scope));
      expect(restored.priority, equals(original.priority));
      expect(
        restored.appraisals.metrics.length,
        equals(original.appraisals.metrics.length),
      );
    });

    // =========================================================================
    // D12: Additional coverage tests
    // =========================================================================
    test('toJson with extensions included', () {
      final bundle = SpecProfileBundle(
        schemaVersion: '0.1.0',
        manifest: const ProfileManifest(
          id: 'com.example.ext',
          name: 'Extension Test',
          version: '1.0.0',
          provider: 'ExtCo',
          scope: ProfileScope.project,
        ),
        appraisals: AppraisalSection(
          metrics: [
            AppraisalMetricDef(
              id: 'metric1',
              name: 'Metric 1',
              source: const StaticSource(value: 0.5),
            ),
          ],
        ),
        extensions: {
          'x-custom-field': 'custom-value',
          'x-nested': {'key': 'value'},
        },
      );

      final json = bundle.toJson();

      expect(json.containsKey('extensions'), isTrue);
      expect(json['extensions']['x-custom-field'], equals('custom-value'));
      expect((json['extensions']['x-nested'] as Map)['key'], equals('value'));
    });
  });

  // ===========================================================================
  // D12: ProfileManifest.toJson with default priority (omitted)
  // ===========================================================================

  group('ProfileManifest.toJson default priority omitted', () {
    test('toJson omits priority when it is the default value of 50', () {
      const manifest = ProfileManifest(
        id: 'com.example.default-priority',
        name: 'Default Priority',
        version: '1.0.0',
        provider: 'TestCo',
        scope: ProfileScope.person,
        priority: 50, // default value
      );
      final json = manifest.toJson();

      // priority == 50 (default) should be omitted from JSON
      expect(json.containsKey('priority'), isFalse);
    });

    test('toJson includes priority when it differs from default', () {
      const manifest = ProfileManifest(
        id: 'com.example.custom-priority',
        name: 'Custom Priority',
        version: '1.0.0',
        provider: 'TestCo',
        scope: ProfileScope.person,
        priority: 75,
      );
      final json = manifest.toJson();

      expect(json.containsKey('priority'), isTrue);
      expect(json['priority'], equals(75));
    });
  });

  // ===========================================================================
  // D12: CompatConfig.fromJson with null requirements
  // ===========================================================================

  group('CompatConfig.fromJson with null requirements', () {
    test('handles explicit null for requirements', () {
      final config = CompatConfig.fromJson({
        'schemaVersion': '>=0.1.0',
        'requirements': null,
      });

      expect(config.schemaVersion, equals('>=0.1.0'));
      expect(config.requirements, isNull);
    });

    test('handles missing requirements key', () {
      final config = CompatConfig.fromJson({
        'schemaVersion': '>=0.2.0',
      });

      expect(config.schemaVersion, equals('>=0.2.0'));
      expect(config.requirements, isNull);
    });

    test('handles schemaVersion only', () {
      final config = CompatConfig.fromJson({
        'schemaVersion': '>=0.3.0',
      });

      expect(config.schemaVersion, equals('>=0.3.0'));
      expect(config.requirements, isNull);

      final json = config.toJson();
      expect(json.containsKey('schemaVersion'), isTrue);
      expect(json.containsKey('requirements'), isFalse);
    });
  });

  // ===========================================================================
  // Coverage: ProfileManifest.fromJson with unknown scope (line 137)
  // ===========================================================================
  group('ProfileManifest.fromJson unknown scope', () {
    test('fromJson falls back to project scope for unknown scope string', () {
      final manifest = ProfileManifest.fromJson({
        'id': 'test-unknown-scope',
        'name': 'Test',
        'version': '1.0.0',
        'provider': 'TestCo',
        'scope': 'unknown_scope_value',
      });
      expect(manifest.scope, equals(ProfileScope.project));
    });
  });

  // ===========================================================================
  // Coverage: SpecProfileBundle.fromJson with decisionPolicies and
  // expressionPolicies (lines 224-225, 228-229)
  // ===========================================================================
  group('SpecProfileBundle.fromJson with policy sections', () {
    test('fromJson parses decisionPolicies when present', () {
      final json = {
        'schemaVersion': '0.1.0',
        'manifest': {
          'id': 'com.example.policies',
          'name': 'Policies Bundle',
          'version': '1.0.0',
          'provider': 'TestCo',
          'scope': 'project',
        },
        'appraisals': {
          'metrics': [
            {
              'id': 'risk',
              'name': 'Risk',
              'source': {'type': 'static', 'value': 0.5},
              'weight': 1.0,
            },
          ],
        },
        'decisionPolicies': {
          'policies': [
            {
              'id': 'dp1',
              'name': 'Decision 1',
              'condition': {
                'type': 'threshold',
                'metric': 'risk',
                'operator': '>',
                'value': 0.7,
              },
              'guidance': {
                'action': 'escalate',
              },
            },
          ],
        },
        'expressionPolicies': {
          'policies': [
            {
              'id': 'ep1',
              'name': 'Expression 1',
              'condition': {
                'type': 'threshold',
                'metric': 'risk',
                'operator': '>',
                'value': 0.3,
              },
              'style': {
                'tone': {
                  'formality': 'formal',
                  'confidence': 'moderate',
                  'empathy': 'moderate',
                  'directness': 'balanced',
                },
                'format': {
                  'structure': 'prose',
                  'length': 'standard',
                },
              },
            },
          ],
        },
      };

      final bundle = SpecProfileBundle.fromJson(json);
      expect(bundle.decisionPolicies, isNotNull);
      expect(bundle.decisionPolicies!.policies, hasLength(1));
      expect(bundle.decisionPolicies!.policies.first.id, equals('dp1'));
      expect(bundle.expressionPolicies, isNotNull);
      expect(bundle.expressionPolicies!.policies, hasLength(1));
      expect(bundle.expressionPolicies!.policies.first.id, equals('ep1'));
    });
  });

  // ===========================================================================
  // Coverage: SpecProfileBundle.toJson with decisionPolicies and
  // expressionPolicies present (lines 240, 242)
  // ===========================================================================
  group('SpecProfileBundle.toJson with policy sections', () {
    test('toJson includes decisionPolicies and expressionPolicies when present', () {
      final bundle = SpecProfileBundle(
        schemaVersion: '0.1.0',
        manifest: const ProfileManifest(
          id: 'com.example.full-spec',
          name: 'Full Spec',
          version: '1.0.0',
          provider: 'TestCo',
          scope: ProfileScope.project,
        ),
        appraisals: AppraisalSection(
          metrics: [
            AppraisalMetricDef(
              id: 'risk',
              name: 'Risk',
              source: const StaticSource(value: 0.5),
            ),
          ],
        ),
        decisionPolicies: DecisionPolicySection(
          policies: [
            DecisionPolicy(
              id: 'dp1',
              name: 'Decision 1',
              condition: const AlwaysTrueCondition(),
              guidance: const DecisionGuidance(action: DecisionAction.proceed),
            ),
          ],
        ),
        expressionPolicies: ExpressionPolicySection(
          policies: [
            ExpressionPolicy(
              id: 'ep1',
              name: 'Expression 1',
              condition: const AlwaysTrueCondition(),
              style: ExpressionStyle.defaultStyle,
            ),
          ],
        ),
      );

      final json = bundle.toJson();
      expect(json.containsKey('decisionPolicies'), isTrue);
      expect(json.containsKey('expressionPolicies'), isTrue);
      expect((json['decisionPolicies'] as Map)['policies'], isNotNull);
      expect((json['expressionPolicies'] as Map)['policies'], isNotNull);
    });
  });
}
