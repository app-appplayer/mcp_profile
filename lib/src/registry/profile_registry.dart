/// Profile registry for managing profiles.
library;

import '../definition/capability.dart';
import '../definition/profile.dart';
import '../definition/section.dart';

/// Registry for managing profiles.
class ProfileRegistry {
  final Map<String, Profile> _profiles = {};
  final Map<String, List<String>> _tagIndex = {};

  /// Register a profile.
  void register(Profile profile) {
    _profiles[profile.id] = profile;
    _indexTags(profile);
  }

  /// Register multiple profiles.
  void registerAll(Iterable<Profile> profiles) {
    for (final profile in profiles) {
      register(profile);
    }
  }

  /// Unregister a profile.
  bool unregister(String id) {
    final profile = _profiles.remove(id);
    if (profile != null) {
      _removeTagIndex(profile);
      return true;
    }
    return false;
  }

  /// Get a profile by ID.
  Profile? get(String id) => _profiles[id];

  /// Check if a profile exists.
  bool has(String id) => _profiles.containsKey(id);

  /// Get all profile IDs.
  List<String> get ids => _profiles.keys.toList();

  /// Get all profiles.
  List<Profile> get all => _profiles.values.toList();

  /// Get active profiles.
  List<Profile> get active {
    return _profiles.values.where((p) => p.active).toList();
  }

  /// Get profiles by tag.
  List<Profile> getByTag(String tag) {
    final ids = _tagIndex[tag] ?? [];
    return ids.map((id) => _profiles[id]).nonNulls.toList();
  }

  /// Get profiles by tags (all tags must match).
  List<Profile> getByTags(List<String> tags) {
    if (tags.isEmpty) return [];

    final firstTagIds = _tagIndex[tags.first] ?? [];
    final matchingIds = firstTagIds.where((id) {
      final profile = _profiles[id];
      if (profile == null) return false;
      return tags.every((tag) => profile.tags.contains(tag));
    }).toList();

    return matchingIds.map((id) => _profiles[id]).nonNulls.toList();
  }

  /// Search profiles by name.
  List<Profile> searchByName(String query) {
    final lowerQuery = query.toLowerCase();
    return _profiles.values
        .where((p) => p.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get a resolved profile (with parent inheritance).
  Profile? getResolved(String id) {
    final profile = _profiles[id];
    if (profile == null) return null;

    if (profile.parentId == null) return profile;

    final parent = getResolved(profile.parentId!);
    if (parent == null) return profile;

    return _mergeProfiles(parent, profile);
  }

  /// Clear all profiles.
  void clear() {
    _profiles.clear();
    _tagIndex.clear();
  }

  /// Get profile count.
  int get count => _profiles.length;

  void _indexTags(Profile profile) {
    for (final tag in profile.tags) {
      _tagIndex.putIfAbsent(tag, () => []).add(profile.id);
    }
  }

  void _removeTagIndex(Profile profile) {
    for (final tag in profile.tags) {
      _tagIndex[tag]?.remove(profile.id);
      if (_tagIndex[tag]?.isEmpty ?? false) {
        _tagIndex.remove(tag);
      }
    }
  }

  Profile _mergeProfiles(Profile parent, Profile child) {
    // Merge sections (child sections override parent by name)
    final mergedSections = <String, ProfileSection>{};
    for (final section in parent.sections) {
      mergedSections[section.name] = section;
    }
    for (final section in child.sections) {
      mergedSections[section.name] = section;
    }

    // Merge capabilities (child capabilities override parent by ID)
    final mergedCapabilities = <String, Capability>{};
    for (final cap in parent.capabilities) {
      mergedCapabilities[cap.id] = cap;
    }
    for (final cap in child.capabilities) {
      mergedCapabilities[cap.id] = cap;
    }

    // Merge metadata
    final mergedMetadata = <String, dynamic>{
      ...parent.metadata,
      ...child.metadata,
    };

    // Merge tags
    final mergedTags = {...parent.tags, ...child.tags}.toList();

    return child.copyWith(
      sections: mergedSections.values.toList(),
      capabilities: mergedCapabilities.values.toList(),
      metadata: mergedMetadata,
      tags: mergedTags,
    );
  }
}

/// Versioned profile registry.
class VersionedProfileRegistry {
  final Map<String, Map<String, Profile>> _versions = {};
  final Map<String, String> _latest = {};

  /// Register a profile version.
  void register(Profile profile) {
    _versions.putIfAbsent(profile.id, () => {})[profile.version] = profile;

    // Update latest if this is a newer version
    final currentLatest = _latest[profile.id];
    if (currentLatest == null ||
        _compareVersions(profile.version, currentLatest) > 0) {
      _latest[profile.id] = profile.version;
    }
  }

  /// Get a specific version.
  Profile? get(String id, {String? version}) {
    final versions = _versions[id];
    if (versions == null) return null;

    final targetVersion = version ?? _latest[id];
    if (targetVersion == null) return null;

    return versions[targetVersion];
  }

  /// Get the latest version.
  Profile? getLatest(String id) => get(id);

  /// Get all versions of a profile.
  List<String> getVersions(String id) {
    return _versions[id]?.keys.toList() ?? [];
  }

  /// Check if a profile exists.
  bool has(String id, {String? version}) {
    if (!_versions.containsKey(id)) return false;
    if (version == null) return true;
    return _versions[id]?.containsKey(version) ?? false;
  }

  /// Get all profile IDs.
  List<String> get ids => _versions.keys.toList();

  /// Clear all profiles.
  void clear() {
    _versions.clear();
    _latest.clear();
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }
}

/// Profile group for organizing related profiles.
class ProfileGroup {
  /// Group identifier.
  final String id;

  /// Group name.
  final String name;

  /// Group description.
  final String? description;

  /// Profile IDs in this group.
  final List<String> profileIds;

  /// Default profile ID.
  final String? defaultProfileId;

  const ProfileGroup({
    required this.id,
    required this.name,
    this.description,
    this.profileIds = const [],
    this.defaultProfileId,
  });

  factory ProfileGroup.fromJson(Map<String, dynamic> json) {
    return ProfileGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      profileIds: (json['profileIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      defaultProfileId: json['defaultProfileId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (profileIds.isNotEmpty) 'profileIds': profileIds,
        if (defaultProfileId != null) 'defaultProfileId': defaultProfileId,
      };

  /// Add a profile to the group.
  ProfileGroup addProfile(String profileId) {
    return ProfileGroup(
      id: id,
      name: name,
      description: description,
      profileIds: [...profileIds, profileId],
      defaultProfileId: defaultProfileId,
    );
  }

  /// Remove a profile from the group.
  ProfileGroup removeProfile(String profileId) {
    return ProfileGroup(
      id: id,
      name: name,
      description: description,
      profileIds: profileIds.where((p) => p != profileId).toList(),
      defaultProfileId:
          defaultProfileId == profileId ? null : defaultProfileId,
    );
  }

  /// Set the default profile.
  ProfileGroup setDefault(String profileId) {
    return ProfileGroup(
      id: id,
      name: name,
      description: description,
      profileIds: profileIds,
      defaultProfileId: profileId,
    );
  }
}
