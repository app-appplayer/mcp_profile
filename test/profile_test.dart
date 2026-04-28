library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  group('Profile', () {
    test('creates profile with required fields', () {
      const profile = Profile(
        id: 'profile-1',
        name: 'Test Profile',
      );

      expect(profile.id, equals('profile-1'));
      expect(profile.name, equals('Test Profile'));
      expect(profile.version, equals('1.0.0'));
      expect(profile.active, isTrue);
    });

    test('creates profile with all fields', () {
      const profile = Profile(
        id: 'profile-2',
        name: 'Full Profile',
        description: 'A complete profile definition',
        version: '2.0.0',
        sections: [
          ProfileSection(
            name: 'system',
            type: SectionType.system,
            content: 'You are a helpful assistant.',
          ),
        ],
        capabilities: [
          Capability(id: 'cap-1', name: 'Search'),
        ],
        tags: ['assistant', 'helpful'],
        active: true,
      );

      expect(profile.description, equals('A complete profile definition'));
      expect(profile.sections.length, equals(1));
      expect(profile.capabilities.length, equals(1));
      expect(profile.tags, containsAll(['assistant', 'helpful']));
    });

    test('getSection finds section by name', () {
      const profile = Profile(
        id: 'profile-3',
        name: 'Test',
        sections: [
          ProfileSection(name: 'system', type: SectionType.system, content: 'System prompt'),
          ProfileSection(name: 'context', type: SectionType.context, content: 'Context'),
        ],
      );

      expect(profile.getSection('system'), isNotNull);
      expect(profile.getSection('system')!.content, equals('System prompt'));
      expect(profile.getSection('missing'), isNull);
    });

    test('getSectionsByType filters correctly', () {
      const profile = Profile(
        id: 'profile-4',
        name: 'Test',
        sections: [
          ProfileSection(name: 'sys1', type: SectionType.system, content: 'System 1'),
          ProfileSection(name: 'ctx1', type: SectionType.context, content: 'Context 1'),
          ProfileSection(name: 'sys2', type: SectionType.system, content: 'System 2'),
        ],
      );

      final systemSections = profile.getSectionsByType(SectionType.system);
      expect(systemSections.length, equals(2));
    });

    test('hasCapability checks correctly', () {
      const profile = Profile(
        id: 'profile-5',
        name: 'Test',
        capabilities: [
          Capability(id: 'search', name: 'Search', enabled: true),
          Capability(id: 'write', name: 'Write', enabled: false),
        ],
      );

      expect(profile.hasCapability('search'), isTrue);
      expect(profile.hasCapability('write'), isFalse);
      expect(profile.hasCapability('missing'), isFalse);
    });

    test('enabledCapabilities returns only enabled', () {
      const profile = Profile(
        id: 'profile-6',
        name: 'Test',
        capabilities: [
          Capability(id: 'cap1', name: 'Cap 1', enabled: true),
          Capability(id: 'cap2', name: 'Cap 2', enabled: false),
          Capability(id: 'cap3', name: 'Cap 3', enabled: true),
        ],
      );

      final enabled = profile.enabledCapabilities;
      expect(enabled.length, equals(2));
    });

    test('validate checks required fields', () {
      const emptyIdProfile = Profile(id: '', name: 'Test');
      const emptyNameProfile = Profile(id: 'test', name: '');
      const validProfile = Profile(id: 'test', name: 'Test');

      expect(emptyIdProfile.validate(), isNotEmpty);
      expect(emptyNameProfile.validate(), isNotEmpty);
      expect(validProfile.validate(), isEmpty);
    });

    test('serializes and deserializes correctly', () {
      const original = Profile(
        id: 'profile-7',
        name: 'Serializable Profile',
        description: 'Test description',
        version: '1.2.3',
      );

      final json = original.toJson();
      final restored = Profile.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
      expect(restored.version, equals(original.version));
    });

    test('copyWith creates modified copy', () {
      const original = Profile(
        id: 'profile-8',
        name: 'Original',
        active: true,
      );

      final modified = original.copyWith(
        name: 'Modified',
        active: false,
      );

      expect(original.name, equals('Original'));
      expect(modified.name, equals('Modified'));
      expect(original.active, isTrue);
      expect(modified.active, isFalse);
    });
  });

  group('ProfileSection', () {
    test('creates section with required fields', () {
      const section = ProfileSection(
        name: 'system',
        type: SectionType.system,
        content: 'System prompt content',
      );

      expect(section.name, equals('system'));
      expect(section.type, equals(SectionType.system));
      expect(section.content, equals('System prompt content'));
    });

    test('serializes and deserializes correctly', () {
      const original = ProfileSection(
        name: 'test',
        type: SectionType.context,
        content: 'Test content',
      );

      final json = original.toJson();
      final restored = ProfileSection.fromJson(json);

      expect(restored.name, equals(original.name));
      expect(restored.type, equals(original.type));
      expect(restored.content, equals(original.content));
    });
  });

  group('Capability', () {
    test('creates capability with required fields', () {
      const cap = Capability(
        id: 'cap-1',
        name: 'Test Capability',
      );

      expect(cap.id, equals('cap-1'));
      expect(cap.name, equals('Test Capability'));
      expect(cap.enabled, isTrue);
    });

    test('creates disabled capability', () {
      const cap = Capability(
        id: 'cap-2',
        name: 'Disabled',
        enabled: false,
      );

      expect(cap.enabled, isFalse);
    });

    test('serializes and deserializes correctly', () {
      const original = Capability(
        id: 'cap-3',
        name: 'Test',
        description: 'Test description',
        enabled: false,
      );

      final json = original.toJson();
      final restored = Capability.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.enabled, equals(original.enabled));
    });
  });

  group('ProfileContext', () {
    test('creates context with variables', () {
      const context = ProfileContext(
        user: {'name': 'John', 'role': 'admin'},
        environment: {'debug': true},
        session: {'id': 'sess-123'},
      );

      expect(context.user['name'], equals('John'));
      expect(context.environment['debug'], equals(true));
      expect(context.session['id'], equals('sess-123'));
    });

    test('get retrieves nested values', () {
      const context = ProfileContext(
        user: {'profile': {'age': 25}},
      );

      expect(context.get('user.profile.age'), equals(25));
    });

    test('withVariables creates new context', () {
      const original = ProfileContext(
        variables: {'x': 1},
      );

      final modified = original.withVariables({'y': 2});

      expect(modified.variables['x'], equals(1));
      expect(modified.variables['y'], equals(2));
    });

    test('toMap flattens context', () {
      const context = ProfileContext(
        user: {'name': 'Test'},
        environment: {'env': 'prod'},
      );

      final map = context.toMap();
      expect(map['user'], isA<Map>());
      expect(map['env'], isA<Map>());
    });
  });

  // ================================================================
  // Additional coverage tests for section.dart
  // ================================================================

  group('ProfileSection.fromJson', () {
    test('deserializes all fields including children', () {
      final json = {
        'name': 'parent',
        'content': 'Parent content',
        'type': 'system',
        'priority': 5,
        'condition': 'env.debug == true',
        'enabled': false,
        'metadata': {'key': 'value', 'count': 42},
        'children': [
          {
            'name': 'child1',
            'content': 'Child 1 content',
            'type': 'context',
          },
          {
            'name': 'child2',
            'content': 'Child 2 content',
            'type': 'instructions',
            'children': [
              {
                'name': 'grandchild',
                'content': 'Deep nested',
                'type': 'examples',
              },
            ],
          },
        ],
      };

      final section = ProfileSection.fromJson(json);

      expect(section.name, equals('parent'));
      expect(section.content, equals('Parent content'));
      expect(section.type, equals(SectionType.system));
      expect(section.priority, equals(5));
      expect(section.condition, equals('env.debug == true'));
      expect(section.enabled, isFalse);
      expect(section.metadata, equals({'key': 'value', 'count': 42}));
      expect(section.children.length, equals(2));
      expect(section.children[0].name, equals('child1'));
      expect(section.children[0].type, equals(SectionType.context));
      expect(section.children[1].children.length, equals(1));
      expect(section.children[1].children[0].name, equals('grandchild'));
    });

    test('uses defaults for missing optional fields', () {
      final json = <String, dynamic>{};
      final section = ProfileSection.fromJson(json);

      expect(section.name, equals(''));
      expect(section.content, equals(''));
      expect(section.type, equals(SectionType.custom));
      expect(section.priority, equals(0));
      expect(section.condition, isNull);
      expect(section.enabled, isTrue);
      expect(section.metadata, isEmpty);
      expect(section.children, isEmpty);
    });
  });

  group('ProfileSection.toJson', () {
    test('omits priority when 0', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
        priority: 0,
      );
      final json = section.toJson();
      expect(json.containsKey('priority'), isFalse);
    });

    test('includes priority when non-zero', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
        priority: 3,
      );
      final json = section.toJson();
      expect(json['priority'], equals(3));
    });

    test('omits enabled when true', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
        enabled: true,
      );
      final json = section.toJson();
      expect(json.containsKey('enabled'), isFalse);
    });

    test('includes enabled when false', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
        enabled: false,
      );
      final json = section.toJson();
      expect(json['enabled'], isFalse);
    });

    test('omits metadata when empty', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
        metadata: {},
      );
      final json = section.toJson();
      expect(json.containsKey('metadata'), isFalse);
    });

    test('includes metadata when non-empty', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
        metadata: {'lang': 'en'},
      );
      final json = section.toJson();
      expect(json['metadata'], equals({'lang': 'en'}));
    });

    test('omits children when empty', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
      );
      final json = section.toJson();
      expect(json.containsKey('children'), isFalse);
    });

    test('includes children when non-empty and serializes recursively', () {
      const section = ProfileSection(
        name: 'parent',
        content: 'parent content',
        children: [
          ProfileSection(name: 'child', content: 'child content'),
        ],
      );
      final json = section.toJson();
      expect(json.containsKey('children'), isTrue);
      final childList = json['children'] as List;
      expect(childList.length, equals(1));
      expect((childList[0] as Map)['name'], equals('child'));
    });

    test('omits condition when null', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
      );
      final json = section.toJson();
      expect(json.containsKey('condition'), isFalse);
    });

    test('includes condition when set', () {
      const section = ProfileSection(
        name: 'test',
        content: 'content',
        condition: 'user.role == admin',
      );
      final json = section.toJson();
      expect(json['condition'], equals('user.role == admin'));
    });
  });

  group('ProfileSection.copyWith', () {
    test('copies all parameters', () {
      const original = ProfileSection(
        name: 'original',
        content: 'original content',
        type: SectionType.system,
        priority: 1,
        condition: 'old_cond',
        enabled: true,
        metadata: {'a': 1},
        children: [
          ProfileSection(name: 'child', content: 'child'),
        ],
      );

      final copied = original.copyWith(
        name: 'copied',
        content: 'new content',
        type: SectionType.context,
        priority: 10,
        condition: 'new_cond',
        enabled: false,
        metadata: {'b': 2},
        children: [],
      );

      expect(copied.name, equals('copied'));
      expect(copied.content, equals('new content'));
      expect(copied.type, equals(SectionType.context));
      expect(copied.priority, equals(10));
      expect(copied.condition, equals('new_cond'));
      expect(copied.enabled, isFalse);
      expect(copied.metadata, equals({'b': 2}));
      expect(copied.children, isEmpty);

      // Verify original is unchanged
      expect(original.name, equals('original'));
      expect(original.content, equals('original content'));
      expect(original.type, equals(SectionType.system));
      expect(original.priority, equals(1));
      expect(original.enabled, isTrue);
    });

    test('preserves original values when no arguments given', () {
      const original = ProfileSection(
        name: 'keep',
        content: 'keep content',
        type: SectionType.persona,
        priority: 7,
        condition: 'keep_cond',
        enabled: false,
        metadata: {'x': 'y'},
      );

      final copied = original.copyWith();

      expect(copied.name, equals(original.name));
      expect(copied.content, equals(original.content));
      expect(copied.type, equals(original.type));
      expect(copied.priority, equals(original.priority));
      expect(copied.condition, equals(original.condition));
      expect(copied.enabled, equals(original.enabled));
      expect(copied.metadata, equals(original.metadata));
    });
  });

  group('ProfileSection.validate', () {
    test('returns error for empty name', () {
      const section = ProfileSection(
        name: '',
        content: 'has content',
      );
      final errors = section.validate();
      expect(errors, contains('Section name is required'));
    });

    test('returns error for empty content without children', () {
      const section = ProfileSection(
        name: 'valid-name',
        content: '',
      );
      final errors = section.validate();
      expect(errors, contains('Section must have content or children'));
    });

    test('no error for empty content when children exist', () {
      const section = ProfileSection(
        name: 'valid-name',
        content: '',
        children: [
          ProfileSection(name: 'child', content: 'child content'),
        ],
      );
      final errors = section.validate();
      expect(errors, isEmpty);
    });

    test('validates children recursively', () {
      const section = ProfileSection(
        name: 'parent',
        content: 'parent content',
        children: [
          ProfileSection(name: '', content: 'child content'),
          ProfileSection(name: 'good-child', content: ''),
        ],
      );
      final errors = section.validate();
      expect(errors, contains('Child [0]: Section name is required'));
      expect(
          errors, contains('Child [1]: Section must have content or children'));
    });

    test('returns both errors for empty name and empty content', () {
      const section = ProfileSection(
        name: '',
        content: '',
      );
      final errors = section.validate();
      expect(errors.length, equals(2));
      expect(errors, contains('Section name is required'));
      expect(errors, contains('Section must have content or children'));
    });

    test('valid section returns no errors', () {
      const section = ProfileSection(
        name: 'valid',
        content: 'valid content',
      );
      final errors = section.validate();
      expect(errors, isEmpty);
    });
  });

  group('ProfileSection.hasTemplateExpressions', () {
    test('detects dollar-brace template expressions', () {
      const section = ProfileSection(
        name: 'test',
        content: r'Hello ${user.name}!',
      );
      expect(section.hasTemplateExpressions, isTrue);
    });

    test('detects double-brace template expressions', () {
      const section = ProfileSection(
        name: 'test',
        content: 'Hello {{user.name}}!',
      );
      expect(section.hasTemplateExpressions, isTrue);
    });

    test('returns false for plain content', () {
      const section = ProfileSection(
        name: 'test',
        content: 'Hello world!',
      );
      expect(section.hasTemplateExpressions, isFalse);
    });

    test('returns false for empty content', () {
      const section = ProfileSection(
        name: 'test',
        content: '',
      );
      expect(section.hasTemplateExpressions, isFalse);
    });

    test('detects when both expression types present', () {
      const section = ProfileSection(
        name: 'test',
        content: r'${a} and {{b}}',
      );
      expect(section.hasTemplateExpressions, isTrue);
    });
  });

  group('ProfileSection.allChildren', () {
    test('returns empty list for no children', () {
      const section = ProfileSection(
        name: 'leaf',
        content: 'content',
      );
      expect(section.allChildren, isEmpty);
    });

    test('returns direct children', () {
      const section = ProfileSection(
        name: 'parent',
        content: 'content',
        children: [
          ProfileSection(name: 'a', content: 'a'),
          ProfileSection(name: 'b', content: 'b'),
        ],
      );
      final all = section.allChildren;
      expect(all.length, equals(2));
      expect(all.map((c) => c.name), containsAll(['a', 'b']));
    });

    test('collects grandchildren recursively', () {
      const section = ProfileSection(
        name: 'root',
        content: 'root',
        children: [
          ProfileSection(
            name: 'level1',
            content: 'l1',
            children: [
              ProfileSection(
                name: 'level2a',
                content: 'l2a',
                children: [
                  ProfileSection(name: 'level3', content: 'l3'),
                ],
              ),
              ProfileSection(name: 'level2b', content: 'l2b'),
            ],
          ),
        ],
      );
      final all = section.allChildren;
      expect(all.length, equals(4));
      expect(all.map((c) => c.name),
          containsAll(['level1', 'level2a', 'level2b', 'level3']));
    });
  });

  // ================================================================
  // Additional coverage tests for TemplateVariable
  // ================================================================

  group('TemplateVariable', () {
    test('fromJson/toJson roundtrip with all fields', () {
      final json = {
        'name': 'userName',
        'type': 'string',
        'default': 'anonymous',
        'required': false,
        'description': 'The user name',
      };

      final variable = TemplateVariable.fromJson(json);

      expect(variable.name, equals('userName'));
      expect(variable.type, equals('string'));
      expect(variable.defaultValue, equals('anonymous'));
      expect(variable.required, isFalse);
      expect(variable.description, equals('The user name'));

      final output = variable.toJson();
      expect(output['name'], equals('userName'));
      expect(output['type'], equals('string'));
      expect(output['default'], equals('anonymous'));
      expect(output['required'], isFalse);
      expect(output['description'], equals('The user name'));
    });

    test('fromJson uses defaults for missing optional fields', () {
      final json = <String, dynamic>{};
      final variable = TemplateVariable.fromJson(json);

      expect(variable.name, equals(''));
      expect(variable.type, equals('string'));
      expect(variable.defaultValue, isNull);
      expect(variable.required, isTrue);
      expect(variable.description, isNull);
    });

    test('toJson omits null default and null description', () {
      const variable = TemplateVariable(name: 'x');
      final json = variable.toJson();

      expect(json.containsKey('default'), isFalse);
      expect(json.containsKey('description'), isFalse);
      expect(json['name'], equals('x'));
      expect(json['type'], equals('string'));
      expect(json['required'], isTrue);
    });

    test('fromJson with integer default value', () {
      final json = {
        'name': 'count',
        'type': 'int',
        'default': 10,
        'required': true,
      };
      final variable = TemplateVariable.fromJson(json);
      expect(variable.defaultValue, equals(10));
      expect(variable.type, equals('int'));
    });
  });

  // ================================================================
  // Additional coverage tests for SectionType.fromString
  // ================================================================

  group('SectionType.fromString', () {
    test('parses all known section types', () {
      expect(SectionType.fromString('system'), equals(SectionType.system));
      expect(SectionType.fromString('instructions'),
          equals(SectionType.instructions));
      expect(SectionType.fromString('context'), equals(SectionType.context));
      expect(SectionType.fromString('examples'), equals(SectionType.examples));
      expect(SectionType.fromString('constraints'),
          equals(SectionType.constraints));
      expect(SectionType.fromString('persona'), equals(SectionType.persona));
      expect(
          SectionType.fromString('knowledge'), equals(SectionType.knowledge));
      expect(SectionType.fromString('tools'), equals(SectionType.tools));
      expect(SectionType.fromString('custom'), equals(SectionType.custom));
    });

    test('falls back to custom for unknown string', () {
      expect(
          SectionType.fromString('nonexistent'), equals(SectionType.custom));
      expect(SectionType.fromString(''), equals(SectionType.custom));
      expect(SectionType.fromString('System'), equals(SectionType.custom));
    });
  });

  // ================================================================
  // Additional coverage tests for ProfileContext
  // ================================================================

  group('ProfileContext.get (extended)', () {
    test('resolves "variables" scope via default path', () {
      const context = ProfileContext(
        variables: {'greeting': 'hello', 'nested': {'deep': 'value'}},
      );

      // Variables are accessed without a "variables" prefix
      expect(context.get('greeting'), equals('hello'));
      expect(context.get('nested.deep'), equals('value'));
    });

    test('returns source map when path has single segment for known scope', () {
      const context = ProfileContext(
        user: {'name': 'Alice'},
      );
      // Single segment returns the entire map
      expect(context.get('user'), isA<Map>());
      expect((context.get('user') as Map)['name'], equals('Alice'));
    });

    test('returns null for nonexistent nested path', () {
      const context = ProfileContext(
        user: {'name': 'Alice'},
      );
      expect(context.get('user.address.city'), isNull);
    });

    test('resolves environment via "env" alias', () {
      const context = ProfileContext(
        environment: {'mode': 'production'},
      );
      expect(context.get('env.mode'), equals('production'));
    });

    test('resolves environment via "environment" key', () {
      const context = ProfileContext(
        environment: {'debug': false},
      );
      expect(context.get('environment.debug'), equals(false));
    });

    test('resolves session scope', () {
      const context = ProfileContext(
        session: {'token': 'abc123', 'meta': {'source': 'web'}},
      );
      expect(context.get('session.token'), equals('abc123'));
      expect(context.get('session.meta.source'), equals('web'));
    });
  });

  // ================================================================
  // Additional coverage tests for Profile
  // ================================================================

  group('Profile.toJson (extended)', () {
    test('omits all null/empty optional fields', () {
      const profile = Profile(
        id: 'p1',
        name: 'Minimal',
      );
      final json = profile.toJson();

      expect(json['id'], equals('p1'));
      expect(json['name'], equals('Minimal'));
      expect(json['version'], equals('1.0.0'));
      expect(json['active'], isTrue);
      // Optional fields should be absent
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('sections'), isFalse);
      expect(json.containsKey('capabilities'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
      expect(json.containsKey('tags'), isFalse);
      expect(json.containsKey('parentId'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
      expect(json.containsKey('updatedAt'), isFalse);
    });

    test('includes all populated optional fields', () {
      final now = DateTime(2025, 1, 15, 12, 0, 0);
      final profile = Profile(
        id: 'p2',
        name: 'Full',
        description: 'A description',
        version: '2.0.0',
        sections: const [
          ProfileSection(name: 's1', content: 'c1'),
        ],
        capabilities: const [
          Capability(id: 'cap1', name: 'Cap 1'),
        ],
        metadata: const {'key': 'val'},
        tags: const ['tag1'],
        parentId: 'parent-1',
        active: false,
        createdAt: now,
        updatedAt: now,
      );
      final json = profile.toJson();

      expect(json['description'], equals('A description'));
      expect(json.containsKey('sections'), isTrue);
      expect(json.containsKey('capabilities'), isTrue);
      expect(json['metadata'], equals({'key': 'val'}));
      expect(json['tags'], equals(['tag1']));
      expect(json['parentId'], equals('parent-1'));
      expect(json['active'], isFalse);
      expect(json['createdAt'], equals(now.toIso8601String()));
      expect(json['updatedAt'], equals(now.toIso8601String()));
    });
  });

  group('Profile.fromJson (extended)', () {
    test('full roundtrip with all fields', () {
      final now = DateTime(2025, 6, 1, 8, 30, 0);
      final original = Profile(
        id: 'roundtrip',
        name: 'Roundtrip Profile',
        description: 'Tests full serialization cycle',
        version: '3.0.0',
        sections: const [
          ProfileSection(
            name: 'system',
            content: 'Be helpful',
            type: SectionType.system,
            priority: 10,
          ),
        ],
        capabilities: const [
          Capability(
            id: 'search',
            name: 'Search',
            description: 'Web search',
            enabled: true,
            permissions: ['internet'],
          ),
        ],
        metadata: const {'source': 'test'},
        tags: const ['roundtrip', 'test'],
        parentId: 'base-profile',
        active: false,
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = Profile.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
      expect(restored.version, equals(original.version));
      expect(restored.sections.length, equals(1));
      expect(restored.sections[0].name, equals('system'));
      expect(restored.sections[0].priority, equals(10));
      expect(restored.capabilities.length, equals(1));
      expect(restored.capabilities[0].id, equals('search'));
      expect(restored.capabilities[0].permissions, equals(['internet']));
      expect(restored.metadata, equals({'source': 'test'}));
      expect(restored.tags, equals(['roundtrip', 'test']));
      expect(restored.parentId, equals('base-profile'));
      expect(restored.active, isFalse);
      expect(restored.createdAt, equals(now));
      expect(restored.updatedAt, equals(now));
    });

    test('fromJson with minimal input uses defaults', () {
      final profile = Profile.fromJson({'id': 'x', 'name': 'X'});
      expect(profile.id, equals('x'));
      expect(profile.name, equals('X'));
      expect(profile.version, equals('1.0.0'));
      expect(profile.active, isTrue);
      expect(profile.sections, isEmpty);
      expect(profile.capabilities, isEmpty);
      expect(profile.metadata, isEmpty);
      expect(profile.tags, isEmpty);
      expect(profile.parentId, isNull);
      expect(profile.createdAt, isNull);
      expect(profile.updatedAt, isNull);
    });
  });

  // ================================================================
  // Additional coverage tests for Capability
  // ================================================================

  group('Capability.copyWith (extended)', () {
    test('partial updates preserve other fields', () {
      const original = Capability(
        id: 'orig',
        name: 'Original',
        description: 'desc',
        enabled: true,
        config: {'key': 'val'},
        permissions: ['read'],
        dependencies: ['dep1'],
      );

      final updated = original.copyWith(name: 'Updated', enabled: false);

      expect(updated.id, equals('orig'));
      expect(updated.name, equals('Updated'));
      expect(updated.description, equals('desc'));
      expect(updated.enabled, isFalse);
      expect(updated.config, equals({'key': 'val'}));
      expect(updated.permissions, equals(['read']));
      expect(updated.dependencies, equals(['dep1']));
    });

    test('can update all fields', () {
      const original = Capability(id: 'a', name: 'A');

      final updated = original.copyWith(
        id: 'b',
        name: 'B',
        description: 'new desc',
        enabled: false,
        config: {'x': 1},
        permissions: ['write'],
        dependencies: ['other'],
      );

      expect(updated.id, equals('b'));
      expect(updated.name, equals('B'));
      expect(updated.description, equals('new desc'));
      expect(updated.enabled, isFalse);
      expect(updated.config, equals({'x': 1}));
      expect(updated.permissions, equals(['write']));
      expect(updated.dependencies, equals(['other']));
    });
  });

  group('Capability.validate (extended)', () {
    test('returns error for empty id', () {
      const cap = Capability(id: '', name: 'Valid Name');
      final errors = cap.validate();
      expect(errors, contains('Capability ID is required'));
      expect(errors.length, equals(1));
    });

    test('returns error for empty name', () {
      const cap = Capability(id: 'valid-id', name: '');
      final errors = cap.validate();
      expect(errors, contains('Capability name is required'));
      expect(errors.length, equals(1));
    });

    test('returns both errors for empty id and name', () {
      const cap = Capability(id: '', name: '');
      final errors = cap.validate();
      expect(errors.length, equals(2));
      expect(errors, contains('Capability ID is required'));
      expect(errors, contains('Capability name is required'));
    });

    test('valid capability returns no errors', () {
      const cap = Capability(id: 'ok', name: 'OK');
      final errors = cap.validate();
      expect(errors, isEmpty);
    });
  });

  group('Capability.fromJson (extended)', () {
    test('uses defaults for missing optional fields', () {
      final cap = Capability.fromJson({'id': 'test', 'name': 'Test'});
      expect(cap.id, equals('test'));
      expect(cap.name, equals('Test'));
      expect(cap.description, isNull);
      expect(cap.enabled, isTrue);
      expect(cap.config, isEmpty);
      expect(cap.permissions, isEmpty);
      expect(cap.dependencies, isEmpty);
    });

    test('deserializes all fields including permissions and dependencies', () {
      final json = {
        'id': 'full-cap',
        'name': 'Full Capability',
        'description': 'Everything set',
        'enabled': false,
        'config': {'timeout': 30},
        'permissions': ['read', 'write'],
        'dependencies': ['auth', 'network'],
      };

      final cap = Capability.fromJson(json);
      expect(cap.id, equals('full-cap'));
      expect(cap.name, equals('Full Capability'));
      expect(cap.description, equals('Everything set'));
      expect(cap.enabled, isFalse);
      expect(cap.config, equals({'timeout': 30}));
      expect(cap.permissions, equals(['read', 'write']));
      expect(cap.dependencies, equals(['auth', 'network']));
    });
  });

  // ================================================================
  // Additional coverage tests for StandardCapabilities
  // ================================================================

  group('StandardCapabilities', () {
    test('create with default name and description', () {
      final cap = StandardCapabilities.create(
        StandardCapabilities.codeGeneration,
      );
      expect(cap.id, equals('code_generation'));
      expect(cap.name, equals('Code Generation'));
      expect(cap.description, equals(
          'Generate code in various programming languages'));
      expect(cap.enabled, isTrue);
    });

    test('create with custom name and description', () {
      final cap = StandardCapabilities.create(
        StandardCapabilities.testing,
        name: 'Custom Testing',
        description: 'Custom test description',
      );
      expect(cap.id, equals('testing'));
      expect(cap.name, equals('Custom Testing'));
      expect(cap.description, equals('Custom test description'));
    });

    test('create with custom config and disabled', () {
      final cap = StandardCapabilities.create(
        StandardCapabilities.webSearch,
        enabled: false,
        config: {'maxResults': 10},
      );
      expect(cap.enabled, isFalse);
      expect(cap.config, equals({'maxResults': 10}));
    });

    test('create with unknown id falls back to custom description', () {
      final cap = StandardCapabilities.create('unknown_capability');
      expect(cap.name, equals('Unknown Capability'));
      expect(cap.description, equals('Custom capability'));
    });

    test('create generates correct names for all standard capabilities', () {
      // Verify the default name generation logic for a few known ids
      final codeReview = StandardCapabilities.create(
        StandardCapabilities.codeReview,
      );
      expect(codeReview.name, equals('Code Review'));
      expect(codeReview.description, equals(
          'Review code for issues and improvements'));

      final fileOps = StandardCapabilities.create(
        StandardCapabilities.fileOperations,
      );
      expect(fileOps.name, equals('File Operations'));
      expect(fileOps.description, equals('Read, write, and manage files'));
    });

    test('all list contains 12 standard capability IDs', () {
      expect(StandardCapabilities.all.length, equals(12));
      expect(StandardCapabilities.all,
          contains(StandardCapabilities.codeGeneration));
      expect(StandardCapabilities.all,
          contains(StandardCapabilities.apiAccess));
    });

    test('create covers all standard description cases', () {
      // Exercise every branch in _defaultDescription
      final caps = StandardCapabilities.all
          .map((id) => StandardCapabilities.create(id))
          .toList();

      for (final cap in caps) {
        expect(cap.description, isNotNull);
        expect(cap.description, isNotEmpty);
        expect(cap.name, isNotEmpty);
      }

      // Spot-check descriptions
      final docs = caps.firstWhere((c) => c.id == 'documentation');
      expect(docs.description, equals('Create and update documentation'));

      final debug = caps.firstWhere((c) => c.id == 'debugging');
      expect(debug.description, equals('Debug and troubleshoot issues'));

      final refactor = caps.firstWhere((c) => c.id == 'refactoring');
      expect(refactor.description, equals(
          'Refactor and improve code structure'));

      final analysis = caps.firstWhere((c) => c.id == 'analysis');
      expect(analysis.description, equals('Analyze code and data'));

      final planning = caps.firstWhere((c) => c.id == 'planning');
      expect(planning.description, equals('Plan and organize tasks'));

      final comm = caps.firstWhere((c) => c.id == 'communication');
      expect(comm.description, equals(
          'Communicate with users and systems'));

      final api = caps.firstWhere((c) => c.id == 'api_access');
      expect(api.description, equals('Access external APIs'));
    });
  });

  // ================================================================
  // Coverage: profile.dart lines 175, 181-183, 190-191, 196, 198-199
  // ================================================================

  group('Profile.validate with section and capability errors', () {
    test('reports section validation errors with index prefix', () {
      // Covers line 175: errors.add('Section [$i]: $error')
      const profile = Profile(
        id: 'valid-id',
        name: 'Valid Name',
        sections: [
          ProfileSection(name: '', content: 'has content'),
          ProfileSection(name: 'good', content: 'also good'),
          ProfileSection(name: '', content: ''),
        ],
      );
      final errors = profile.validate();
      expect(errors, contains('Section [0]: Section name is required'));
      expect(errors, contains('Section [2]: Section name is required'));
      expect(
          errors, contains('Section [2]: Section must have content or children'));
    });

    test('reports capability validation errors with index prefix', () {
      // Covers lines 181-183: capErrors loop and errors.add('Capability [$i]: $error')
      const profile = Profile(
        id: 'valid-id',
        name: 'Valid Name',
        capabilities: [
          Capability(id: '', name: 'No ID'),
          Capability(id: 'good', name: 'Good'),
          Capability(id: '', name: ''),
        ],
      );
      final errors = profile.validate();
      expect(errors, contains('Capability [0]: Capability ID is required'));
      expect(errors, contains('Capability [2]: Capability ID is required'));
      expect(errors, contains('Capability [2]: Capability name is required'));
    });
  });

  group('Profile.toString', () {
    test('returns correct string representation', () {
      // Covers lines 190-191
      const profile = Profile(id: 'my-profile', name: 'My Profile');
      expect(profile.toString(), equals('Profile(my-profile: My Profile)'));
    });
  });

  group('Profile equality and hashCode', () {
    test('equal profiles with same id', () {
      // Covers lines 196, 198-199
      const profile1 = Profile(id: 'same-id', name: 'Name 1');
      const profile2 = Profile(id: 'same-id', name: 'Name 2');
      expect(profile1 == profile2, isTrue);
      expect(profile1.hashCode, equals(profile2.hashCode));
    });

    test('unequal profiles with different ids', () {
      const profile1 = Profile(id: 'id-a', name: 'Name');
      const profile2 = Profile(id: 'id-b', name: 'Name');
      expect(profile1 == profile2, isFalse);
    });

    test('not equal to non-Profile object', () {
      // Covers the 'other is Profile' branch on line 196
      const profile = Profile(id: 'test', name: 'Test');
      expect(profile == Object(), isFalse);
    });
  });

  // ================================================================
  // Coverage: section.dart lines 168-169
  // ================================================================

  group('ProfileSection.toString', () {
    test('returns correct string representation', () {
      // Covers lines 168-169
      const section = ProfileSection(
        name: 'my-section',
        type: SectionType.system,
        content: 'some content',
      );
      expect(section.toString(), equals('ProfileSection(my-section: system)'));
    });
  });

  // ================================================================
  // Coverage: capability.dart lines 81, 102-103, 108-110, 112-113
  // ================================================================

  group('Capability.copyWith with explicit enabled parameter', () {
    test('copyWith(enabled: false) changes enabled from true to false', () {
      const original = Capability(
        id: 'cap-enabled',
        name: 'Enabled Cap',
        enabled: true,
      );

      final updated = original.copyWith(enabled: false);

      expect(original.enabled, isTrue);
      expect(updated.enabled, isFalse);
      expect(updated.id, equals('cap-enabled'));
      expect(updated.name, equals('Enabled Cap'));
    });

    test('copyWith(enabled: true) changes enabled from false to true', () {
      const original = Capability(
        id: 'cap-disabled',
        name: 'Disabled Cap',
        enabled: false,
      );

      final updated = original.copyWith(enabled: true);

      expect(original.enabled, isFalse);
      expect(updated.enabled, isTrue);
    });

    test('copyWith with no enabled parameter preserves original enabled', () {
      const original = Capability(
        id: 'cap-keep-enabled',
        name: 'Keep Enabled',
        enabled: false,
      );

      // Call copyWith without the enabled parameter (null),
      // forcing the 'this.enabled' fallback path on line 81.
      final updated = original.copyWith(name: 'Renamed');

      expect(updated.enabled, isFalse);
      expect(updated.name, equals('Renamed'));
    });
  });

  group('Capability.validate returns error for empty name (line 81 explicit)', () {
    test('validates empty name returning error on line 81 path', () {
      // Covers line 81: errors.add('Capability name is required')
      // (already partially covered, but explicitly exercised here)
      const cap = Capability(id: 'has-id', name: '');
      final errors = cap.validate();
      expect(errors, contains('Capability name is required'));
      expect(errors.length, equals(1));
    });
  });

  group('Capability.toString', () {
    test('returns correct string representation', () {
      // Covers lines 102-103
      const cap = Capability(id: 'cap-x', name: 'Cap X', enabled: true);
      expect(cap.toString(), equals('Capability(cap-x: Cap X, enabled: true)'));
    });

    test('returns correct representation when disabled', () {
      const cap = Capability(id: 'cap-y', name: 'Cap Y', enabled: false);
      expect(cap.toString(), equals('Capability(cap-y: Cap Y, enabled: false)'));
    });
  });

  group('Capability equality and hashCode', () {
    test('equal capabilities with same id', () {
      // Covers lines 108-110, 112-113
      const cap1 = Capability(id: 'same', name: 'Name 1');
      const cap2 = Capability(id: 'same', name: 'Name 2');
      expect(cap1 == cap2, isTrue);
      expect(cap1.hashCode, equals(cap2.hashCode));
    });

    test('unequal capabilities with different ids', () {
      const cap1 = Capability(id: 'id-a', name: 'Name');
      const cap2 = Capability(id: 'id-b', name: 'Name');
      expect(cap1 == cap2, isFalse);
    });

    test('not equal to non-Capability object', () {
      // Covers the 'other is Capability' branch on line 108
      const cap = Capability(id: 'test', name: 'Test');
      expect(cap == Object(), isFalse);
    });
  });
}
