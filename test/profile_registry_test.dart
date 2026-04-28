/// ProfileRegistry Tests
///
/// Tests for ProfileRegistry, VersionedProfileRegistry, and ProfileGroup.
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

void main() {
  group('ProfileRegistry', () {
    late ProfileRegistry registry;

    setUp(() {
      registry = ProfileRegistry();
    });

    test('registers profile', () {
      const profile = Profile(id: 'test', name: 'Test');
      registry.register(profile);

      expect(registry.has('test'), isTrue);
      expect(registry.get('test'), equals(profile));
    });

    test('registers multiple profiles', () {
      const profiles = [
        Profile(id: 'p1', name: 'Profile 1'),
        Profile(id: 'p2', name: 'Profile 2'),
        Profile(id: 'p3', name: 'Profile 3'),
      ];

      registry.registerAll(profiles);

      expect(registry.count, equals(3));
      expect(registry.has('p1'), isTrue);
      expect(registry.has('p2'), isTrue);
      expect(registry.has('p3'), isTrue);
    });

    test('unregisters profile', () {
      const profile = Profile(id: 'test', name: 'Test');
      registry.register(profile);

      final result = registry.unregister('test');

      expect(result, isTrue);
      expect(registry.has('test'), isFalse);
    });

    test('unregister returns false for unknown profile', () {
      final result = registry.unregister('unknown');
      expect(result, isFalse);
    });

    test('get returns null for unknown profile', () {
      expect(registry.get('unknown'), isNull);
    });

    test('ids returns all profile ids', () {
      registry.register(const Profile(id: 'a', name: 'A'));
      registry.register(const Profile(id: 'b', name: 'B'));
      registry.register(const Profile(id: 'c', name: 'C'));

      expect(registry.ids, containsAll(['a', 'b', 'c']));
    });

    test('all returns all profiles', () {
      registry.register(const Profile(id: 'a', name: 'A'));
      registry.register(const Profile(id: 'b', name: 'B'));

      expect(registry.all.length, equals(2));
    });

    test('active returns only active profiles', () {
      registry.register(const Profile(id: 'active1', name: 'Active 1', active: true));
      registry.register(const Profile(id: 'inactive', name: 'Inactive', active: false));
      registry.register(const Profile(id: 'active2', name: 'Active 2', active: true));

      final active = registry.active;

      expect(active.length, equals(2));
      expect(active.map((p) => p.id), containsAll(['active1', 'active2']));
    });

    test('getByTag returns profiles with tag', () {
      registry.register(const Profile(id: 'p1', name: 'P1', tags: ['assistant']));
      registry.register(const Profile(id: 'p2', name: 'P2', tags: ['assistant', 'code']));
      registry.register(const Profile(id: 'p3', name: 'P3', tags: ['code']));

      final assistants = registry.getByTag('assistant');

      expect(assistants.length, equals(2));
      expect(assistants.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('getByTags returns profiles with all tags', () {
      registry.register(const Profile(id: 'p1', name: 'P1', tags: ['a', 'b']));
      registry.register(const Profile(id: 'p2', name: 'P2', tags: ['a', 'b', 'c']));
      registry.register(const Profile(id: 'p3', name: 'P3', tags: ['a']));

      final profiles = registry.getByTags(['a', 'b']);

      expect(profiles.length, equals(2));
      expect(profiles.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('getByTags returns empty for empty tags', () {
      registry.register(const Profile(id: 'p1', name: 'P1', tags: ['a']));

      expect(registry.getByTags([]), isEmpty);
    });

    test('searchByName finds profiles', () {
      registry.register(const Profile(id: 'p1', name: 'Code Assistant'));
      registry.register(const Profile(id: 'p2', name: 'Writing Helper'));
      registry.register(const Profile(id: 'p3', name: 'Code Review Expert'));

      final results = registry.searchByName('code');

      expect(results.length, equals(2));
    });

    test('getResolved returns profile without parent', () {
      const profile = Profile(id: 'standalone', name: 'Standalone');
      registry.register(profile);

      final resolved = registry.getResolved('standalone');

      expect(resolved, equals(profile));
    });

    test('getResolved merges with parent', () {
      const parent = Profile(
        id: 'parent',
        name: 'Parent',
        sections: [
          ProfileSection(name: 'system', type: SectionType.system, content: 'Parent system'),
        ],
        capabilities: [
          Capability(id: 'cap1', name: 'Cap 1'),
        ],
        tags: ['parent-tag'],
      );

      const child = Profile(
        id: 'child',
        name: 'Child',
        parentId: 'parent',
        sections: [
          ProfileSection(name: 'context', type: SectionType.context, content: 'Child context'),
        ],
        capabilities: [
          Capability(id: 'cap2', name: 'Cap 2'),
        ],
        tags: ['child-tag'],
      );

      registry.register(parent);
      registry.register(child);

      final resolved = registry.getResolved('child');

      expect(resolved, isNotNull);
      expect(resolved!.sections.length, equals(2));
      expect(resolved.capabilities.length, equals(2));
      expect(resolved.tags, containsAll(['parent-tag', 'child-tag']));
    });

    test('getResolved returns null for unknown profile', () {
      expect(registry.getResolved('unknown'), isNull);
    });

    test('getResolved handles missing parent', () {
      const child = Profile(
        id: 'orphan',
        name: 'Orphan',
        parentId: 'missing-parent',
      );
      registry.register(child);

      final resolved = registry.getResolved('orphan');

      expect(resolved, equals(child));
    });

    test('clear removes all profiles', () {
      registry.register(const Profile(id: 'p1', name: 'P1'));
      registry.register(const Profile(id: 'p2', name: 'P2'));

      registry.clear();

      expect(registry.count, equals(0));
      expect(registry.ids, isEmpty);
    });

    test('unregister cleans up empty tag index entries', () {
      // Covers lines 111-113: _removeTagIndex removing empty tag lists
      registry.register(const Profile(id: 'tagged', name: 'Tagged', tags: ['unique-tag']));
      // Verify the profile is findable by tag
      expect(registry.getByTag('unique-tag').length, equals(1));

      // Unregister the only profile with this tag
      registry.unregister('tagged');

      // After removal, tag index should be cleaned up (empty list removed)
      expect(registry.getByTag('unique-tag'), isEmpty);
    });

    test('unregister preserves tag index for other profiles with same tag', () {
      registry.register(const Profile(id: 'p1', name: 'P1', tags: ['shared-tag']));
      registry.register(const Profile(id: 'p2', name: 'P2', tags: ['shared-tag']));

      registry.unregister('p1');

      // The tag should still be in the index with p2
      final remaining = registry.getByTag('shared-tag');
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('p2'));
    });
  });

  group('VersionedProfileRegistry', () {
    late VersionedProfileRegistry registry;

    setUp(() {
      registry = VersionedProfileRegistry();
    });

    test('registers profile version', () {
      const profile = Profile(id: 'test', name: 'Test', version: '1.0.0');
      registry.register(profile);

      expect(registry.has('test'), isTrue);
      expect(registry.has('test', version: '1.0.0'), isTrue);
    });

    test('registers multiple versions', () {
      registry.register(const Profile(id: 'test', name: 'Test v1', version: '1.0.0'));
      registry.register(const Profile(id: 'test', name: 'Test v2', version: '2.0.0'));
      registry.register(const Profile(id: 'test', name: 'Test v3', version: '1.5.0'));

      final versions = registry.getVersions('test');

      expect(versions.length, equals(3));
      expect(versions, containsAll(['1.0.0', '2.0.0', '1.5.0']));
    });

    test('get returns specific version', () {
      registry.register(const Profile(id: 'test', name: 'Test v1', version: '1.0.0'));
      registry.register(const Profile(id: 'test', name: 'Test v2', version: '2.0.0'));

      final v1 = registry.get('test', version: '1.0.0');
      final v2 = registry.get('test', version: '2.0.0');

      expect(v1!.name, equals('Test v1'));
      expect(v2!.name, equals('Test v2'));
    });

    test('get returns latest version by default', () {
      registry.register(const Profile(id: 'test', name: 'Test v1', version: '1.0.0'));
      registry.register(const Profile(id: 'test', name: 'Test v2', version: '2.0.0'));
      registry.register(const Profile(id: 'test', name: 'Test v1.5', version: '1.5.0'));

      final latest = registry.get('test');

      expect(latest!.name, equals('Test v2'));
    });

    test('getLatest returns latest version', () {
      registry.register(const Profile(id: 'test', name: 'Old', version: '0.9.0'));
      registry.register(const Profile(id: 'test', name: 'Latest', version: '1.0.0'));

      final latest = registry.getLatest('test');

      expect(latest!.name, equals('Latest'));
    });

    test('has returns false for unknown profile', () {
      expect(registry.has('unknown'), isFalse);
      expect(registry.has('unknown', version: '1.0.0'), isFalse);
    });

    test('has returns false for unknown version', () {
      registry.register(const Profile(id: 'test', name: 'Test', version: '1.0.0'));

      expect(registry.has('test', version: '2.0.0'), isFalse);
    });

    test('ids returns all profile ids', () {
      registry.register(const Profile(id: 'p1', name: 'P1', version: '1.0.0'));
      registry.register(const Profile(id: 'p2', name: 'P2', version: '1.0.0'));
      registry.register(const Profile(id: 'p1', name: 'P1v2', version: '2.0.0'));

      expect(registry.ids.length, equals(2));
      expect(registry.ids, containsAll(['p1', 'p2']));
    });

    test('clear removes all profiles', () {
      registry.register(const Profile(id: 'p1', name: 'P1', version: '1.0.0'));
      registry.register(const Profile(id: 'p2', name: 'P2', version: '1.0.0'));

      registry.clear();

      expect(registry.ids, isEmpty);
    });

    test('compares versions correctly', () {
      registry.register(const Profile(id: 'test', name: 'v1.0', version: '1.0.0'));
      registry.register(const Profile(id: 'test', name: 'v1.10', version: '1.10.0'));
      registry.register(const Profile(id: 'test', name: 'v1.2', version: '1.2.0'));

      final latest = registry.getLatest('test');

      expect(latest!.name, equals('v1.10'));
    });

    test('_compareVersions handles pre-release version strings', () {
      // Pre-release tags like "1.0.0-beta" should parse non-numeric parts as 0
      registry.register(const Profile(
        id: 'pre',
        name: 'Pre-Release',
        version: '1.0.0-beta',
      ));
      registry.register(const Profile(
        id: 'pre',
        name: 'Release',
        version: '1.0.0',
      ));

      // The int.tryParse for "0-beta" returns null, which falls back to 0,
      // so both are treated as equivalent version numbers
      final latest = registry.getLatest('pre');
      expect(latest, isNotNull);
      // The first registered version is "1.0.0-beta", then "1.0.0" replaces it
      // because _compareVersions treats both as "1.0.0" numerically (the
      // patch "0-beta" parses as 0). After registering "1.0.0" second,
      // comparison returns 0 (not > 0), so latest stays "1.0.0-beta".
      expect(latest!.version, equals('1.0.0-beta'));
    });
  });

  group('ProfileGroup', () {
    test('creates group with required fields', () {
      const group = ProfileGroup(
        id: 'group-1',
        name: 'Test Group',
      );

      expect(group.id, equals('group-1'));
      expect(group.name, equals('Test Group'));
      expect(group.profileIds, isEmpty);
    });

    test('creates group with all fields', () {
      const group = ProfileGroup(
        id: 'group-2',
        name: 'Full Group',
        description: 'A complete group',
        profileIds: ['p1', 'p2', 'p3'],
        defaultProfileId: 'p1',
      );

      expect(group.description, equals('A complete group'));
      expect(group.profileIds, containsAll(['p1', 'p2', 'p3']));
      expect(group.defaultProfileId, equals('p1'));
    });

    test('fromJson creates group', () {
      final json = {
        'id': 'group-3',
        'name': 'JSON Group',
        'description': 'From JSON',
        'profileIds': ['a', 'b'],
        'defaultProfileId': 'a',
      };

      final group = ProfileGroup.fromJson(json);

      expect(group.id, equals('group-3'));
      expect(group.name, equals('JSON Group'));
      expect(group.description, equals('From JSON'));
      expect(group.profileIds.length, equals(2));
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};

      final group = ProfileGroup.fromJson(json);

      expect(group.id, equals(''));
      expect(group.name, equals(''));
      expect(group.profileIds, isEmpty);
    });

    test('toJson serializes group', () {
      const group = ProfileGroup(
        id: 'group-4',
        name: 'Serializable',
        description: 'Test',
        profileIds: ['p1'],
        defaultProfileId: 'p1',
      );

      final json = group.toJson();

      expect(json['id'], equals('group-4'));
      expect(json['name'], equals('Serializable'));
      expect(json['description'], equals('Test'));
      expect(json['profileIds'], contains('p1'));
      expect(json['defaultProfileId'], equals('p1'));
    });

    test('toJson omits null fields', () {
      const group = ProfileGroup(
        id: 'minimal',
        name: 'Minimal',
      );

      final json = group.toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('profileIds'), isFalse);
      expect(json.containsKey('defaultProfileId'), isFalse);
    });

    test('addProfile creates new group with profile', () {
      const group = ProfileGroup(
        id: 'group',
        name: 'Group',
        profileIds: ['p1'],
      );

      final updated = group.addProfile('p2');

      expect(group.profileIds.length, equals(1));
      expect(updated.profileIds.length, equals(2));
      expect(updated.profileIds, containsAll(['p1', 'p2']));
    });

    test('removeProfile creates new group without profile', () {
      const group = ProfileGroup(
        id: 'group',
        name: 'Group',
        profileIds: ['p1', 'p2', 'p3'],
        defaultProfileId: 'p1',
      );

      final updated = group.removeProfile('p2');

      expect(group.profileIds.length, equals(3));
      expect(updated.profileIds.length, equals(2));
      expect(updated.profileIds, containsAll(['p1', 'p3']));
    });

    test('removeProfile clears default if removed', () {
      const group = ProfileGroup(
        id: 'group',
        name: 'Group',
        profileIds: ['p1', 'p2'],
        defaultProfileId: 'p1',
      );

      final updated = group.removeProfile('p1');

      expect(updated.defaultProfileId, isNull);
    });

    test('removeProfile keeps default if not removed', () {
      const group = ProfileGroup(
        id: 'group',
        name: 'Group',
        profileIds: ['p1', 'p2'],
        defaultProfileId: 'p1',
      );

      final updated = group.removeProfile('p2');

      expect(updated.defaultProfileId, equals('p1'));
    });

    test('setDefault creates new group with default', () {
      const group = ProfileGroup(
        id: 'group',
        name: 'Group',
        profileIds: ['p1', 'p2'],
      );

      final updated = group.setDefault('p2');

      expect(group.defaultProfileId, isNull);
      expect(updated.defaultProfileId, equals('p2'));
    });

    test('removeProfile when defaultProfileId is the removed profile', () {
      const group = ProfileGroup(
        id: 'group',
        name: 'Group',
        profileIds: ['default-p', 'other-p'],
        defaultProfileId: 'default-p',
      );

      final updated = group.removeProfile('default-p');

      expect(updated.profileIds, equals(['other-p']));
      expect(updated.defaultProfileId, isNull);
    });
  });
}
