/// ProfileBuilder Tests
///
/// Tests for ProfileBuilder, SectionBuilder, and CapabilityBuilder.
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  group('ProfileBuilder', () {
    test('builds profile with basic fields', () {
      final profile = ProfileBuilder()
          .id('test-profile')
          .name('Test Profile')
          .description('A test profile')
          .version('1.0.0')
          .build();

      expect(profile.id, equals('test-profile'));
      expect(profile.name, equals('Test Profile'));
      expect(profile.description, equals('A test profile'));
      expect(profile.version, equals('1.0.0'));
    });

    test('builds profile with parent', () {
      final profile = ProfileBuilder()
          .id('child-profile')
          .name('Child')
          .parent('parent-profile')
          .build();

      expect(profile.parentId, equals('parent-profile'));
    });

    test('builds profile with active status', () {
      final activeProfile = ProfileBuilder()
          .id('active')
          .name('Active')
          .active(true)
          .build();

      final inactiveProfile = ProfileBuilder()
          .id('inactive')
          .name('Inactive')
          .active(false)
          .build();

      expect(activeProfile.active, isTrue);
      expect(inactiveProfile.active, isFalse);
    });

    test('adds section directly', () {
      const section = ProfileSection(
        name: 'system',
        type: SectionType.system,
        content: 'System prompt',
      );

      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .section(section)
          .build();

      expect(profile.sections.length, equals(1));
      expect(profile.sections.first.name, equals('system'));
    });

    test('adds section using builder', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .sectionBuilder((builder) {
            builder
                .name('custom')
                .type(SectionType.custom)
                .content('Custom content')
                .priority(50);
          })
          .build();

      expect(profile.sections.length, equals(1));
      expect(profile.sections.first.name, equals('custom'));
      expect(profile.sections.first.priority, equals(50));
    });

    test('adds system prompt section', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .systemPrompt('You are a helpful assistant.', priority: 100)
          .build();

      expect(profile.sections.length, equals(1));
      expect(profile.sections.first.type, equals(SectionType.system));
      expect(profile.sections.first.priority, equals(100));
    });

    test('adds instructions section', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .instructions('Follow these instructions.', priority: 90)
          .build();

      expect(profile.sections.first.type, equals(SectionType.instructions));
    });

    test('adds context section', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .context('Context information', priority: 80)
          .build();

      expect(profile.sections.first.type, equals(SectionType.context));
    });

    test('adds examples section', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .examples('Example 1, Example 2', priority: 70)
          .build();

      expect(profile.sections.first.type, equals(SectionType.examples));
    });

    test('adds constraints section', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .constraints('Do not reveal secrets.', priority: 95)
          .build();

      expect(profile.sections.first.type, equals(SectionType.constraints));
    });

    test('adds persona section', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .persona('A friendly AI assistant', priority: 85)
          .build();

      expect(profile.sections.first.type, equals(SectionType.persona));
    });

    test('adds capability directly', () {
      const capability = Capability(
        id: 'search',
        name: 'Search',
        enabled: true,
      );

      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .capability(capability)
          .build();

      expect(profile.capabilities.length, equals(1));
      expect(profile.capabilities.first.id, equals('search'));
    });

    test('adds capability by id', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .capabilityId('code_generation', enabled: true)
          .build();

      expect(profile.capabilities.length, equals(1));
    });

    test('adds multiple capabilities by ids', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .capabilityIds(['cap1', 'cap2', 'cap3'])
          .build();

      expect(profile.capabilities.length, equals(3));
    });

    test('adds metadata', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .metadata('key1', 'value1')
          .metadata('key2', 42)
          .build();

      expect(profile.metadata['key1'], equals('value1'));
      expect(profile.metadata['key2'], equals(42));
    });

    test('adds multiple metadata entries', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .metadataAll({'a': 1, 'b': 2, 'c': 3})
          .build();

      expect(profile.metadata.length, equals(3));
    });

    test('adds tag', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .tag('assistant')
          .tag('helpful')
          .build();

      expect(profile.tags, containsAll(['assistant', 'helpful']));
    });

    test('adds multiple tags', () {
      final profile = ProfileBuilder()
          .id('test')
          .name('Test')
          .tags(['tag1', 'tag2', 'tag3'])
          .build();

      expect(profile.tags.length, equals(3));
    });

    test('reset clears all fields', () {
      final builder = ProfileBuilder()
          .id('test')
          .name('Test')
          .description('Description')
          .tag('tag1')
          .metadata('key', 'value');

      builder.reset();

      final profile = builder.id('new').name('New').build();

      expect(profile.id, equals('new'));
      expect(profile.description, isNull);
      expect(profile.tags, isEmpty);
      expect(profile.metadata, isEmpty);
    });
  });

  group('SectionBuilder', () {
    test('builds section with basic fields', () {
      final section = SectionBuilder()
          .name('test-section')
          .type(SectionType.context)
          .content('Section content')
          .priority(75)
          .build();

      expect(section.name, equals('test-section'));
      expect(section.type, equals(SectionType.context));
      expect(section.content, equals('Section content'));
      expect(section.priority, equals(75));
    });

    test('builds section with condition', () {
      final section = SectionBuilder()
          .name('conditional')
          .type(SectionType.custom)
          .content('Content')
          .condition('user.role == "admin"')
          .build();

      expect(section.condition, equals('user.role == "admin"'));
    });

    test('builds section with enabled status', () {
      final enabledSection = SectionBuilder()
          .name('enabled')
          .type(SectionType.custom)
          .content('Content')
          .enabled(true)
          .build();

      final disabledSection = SectionBuilder()
          .name('disabled')
          .type(SectionType.custom)
          .content('Content')
          .enabled(false)
          .build();

      expect(enabledSection.enabled, isTrue);
      expect(disabledSection.enabled, isFalse);
    });

    test('adds metadata', () {
      final section = SectionBuilder()
          .name('test')
          .type(SectionType.custom)
          .content('Content')
          .metadata('key1', 'value1')
          .metadata('key2', 123)
          .build();

      expect(section.metadata['key1'], equals('value1'));
      expect(section.metadata['key2'], equals(123));
    });

    test('adds child section directly', () {
      const child = ProfileSection(
        name: 'child',
        type: SectionType.custom,
        content: 'Child content',
      );

      final section = SectionBuilder()
          .name('parent')
          .type(SectionType.context)
          .content('Parent content')
          .child(child)
          .build();

      expect(section.children.length, equals(1));
      expect(section.children.first.name, equals('child'));
    });

    test('adds child using builder', () {
      final section = SectionBuilder()
          .name('parent')
          .type(SectionType.context)
          .content('Parent')
          .childBuilder((builder) {
            builder
                .name('child')
                .type(SectionType.custom)
                .content('Child content');
          })
          .build();

      expect(section.children.length, equals(1));
    });
  });

  group('CapabilityBuilder', () {
    test('builds capability with basic fields', () {
      final capability = CapabilityBuilder()
          .id('cap-1')
          .name('Test Capability')
          .description('A test capability')
          .build();

      expect(capability.id, equals('cap-1'));
      expect(capability.name, equals('Test Capability'));
      expect(capability.description, equals('A test capability'));
    });

    test('builds capability with enabled status', () {
      final enabledCap = CapabilityBuilder()
          .id('enabled')
          .name('Enabled')
          .enabled(true)
          .build();

      final disabledCap = CapabilityBuilder()
          .id('disabled')
          .name('Disabled')
          .enabled(false)
          .build();

      expect(enabledCap.enabled, isTrue);
      expect(disabledCap.enabled, isFalse);
    });

    test('adds config', () {
      final capability = CapabilityBuilder()
          .id('cap')
          .name('Cap')
          .config('maxTokens', 1000)
          .config('temperature', 0.7)
          .build();

      expect(capability.config['maxTokens'], equals(1000));
      expect(capability.config['temperature'], equals(0.7));
    });

    test('adds permission', () {
      final capability = CapabilityBuilder()
          .id('cap')
          .name('Cap')
          .permission('read')
          .permission('write')
          .build();

      expect(capability.permissions, containsAll(['read', 'write']));
    });

    test('adds dependency', () {
      final capability = CapabilityBuilder()
          .id('cap')
          .name('Cap')
          .dependency('dep1')
          .dependency('dep2')
          .build();

      expect(capability.dependencies, containsAll(['dep1', 'dep2']));
    });
  });
}
