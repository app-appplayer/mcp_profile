/// Profile Bundle - Loading and managing profile bundles.
///
/// Provides utilities for loading profiles from bundles.
library;

import '../definition/profile.dart';
import '../definition/section.dart';
import '../definition/capability.dart';

/// A bundle of profiles.
class ProfileBundle {
  /// Bundle ID.
  final String bundleId;

  /// Bundle name.
  final String name;

  /// Bundle version.
  final String version;

  /// Profiles in the bundle.
  final List<Profile> profiles;

  /// Default profile ID.
  final String? defaultProfileId;

  /// Bundle metadata.
  final Map<String, dynamic> metadata;

  const ProfileBundle({
    required this.bundleId,
    required this.name,
    this.version = '1.0.0',
    this.profiles = const [],
    this.defaultProfileId,
    this.metadata = const {},
  });

  /// Create from JSON.
  factory ProfileBundle.fromJson(Map<String, dynamic> json) {
    return ProfileBundle(
      bundleId: json['bundleId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      profiles: (json['profiles'] as List<dynamic>?)
              ?.map((e) => Profile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      defaultProfileId: json['defaultProfileId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'bundleId': bundleId,
      'name': name,
      'version': version,
      if (profiles.isNotEmpty)
        'profiles': profiles.map((p) => p.toJson()).toList(),
      if (defaultProfileId != null) 'defaultProfileId': defaultProfileId,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Get profile by ID.
  Profile? getProfile(String profileId) {
    for (final profile in profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  /// Get the default profile.
  Profile? get defaultProfile {
    if (defaultProfileId != null) {
      return getProfile(defaultProfileId!);
    }
    return profiles.isNotEmpty ? profiles.first : null;
  }

  /// Get profiles by tag.
  List<Profile> getProfilesByTag(String tag) {
    return profiles.where((p) => p.tags.contains(tag)).toList();
  }

  /// Get active profiles.
  List<Profile> get activeProfiles {
    return profiles.where((p) => p.active).toList();
  }

  /// Check if bundle has profile.
  bool hasProfile(String profileId) {
    return profiles.any((p) => p.id == profileId);
  }
}

/// Loader for profile bundles.
class ProfileBundleLoader {
  /// Load bundle from JSON.
  ProfileBundle loadFromJson(Map<String, dynamic> json) {
    return ProfileBundle.fromJson(json);
  }

  /// Load profiles from MCP bundle profiles section.
  List<Profile> loadFromMcpBundle(Map<String, dynamic> profilesSection) {
    final profiles = <Profile>[];

    final items = profilesSection['items'] as List<dynamic>? ?? [];
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      profiles.add(_parseProfile(itemMap));
    }

    return profiles;
  }

  Profile _parseProfile(Map<String, dynamic> profileJson) {
    return Profile(
      id: profileJson['id'] as String? ?? '',
      name: profileJson['name'] as String? ?? '',
      description: profileJson['description'] as String?,
      version: profileJson['version'] as String? ?? '1.0.0',
      sections: _parseSections(profileJson['sections'] as List<dynamic>?),
      capabilities:
          _parseCapabilities(profileJson['capabilities'] as List<dynamic>?),
      tags: (profileJson['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      parentId: profileJson['parentId'] as String?,
      active: profileJson['active'] as bool? ?? true,
      metadata: profileJson['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  List<ProfileSection> _parseSections(List<dynamic>? sections) {
    if (sections == null) return [];
    return sections
        .map((e) => ProfileSection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<Capability> _parseCapabilities(List<dynamic>? capabilities) {
    if (capabilities == null) return [];
    return capabilities
        .map((e) => Capability.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Profile bundle validator.
class ProfileBundleValidator {
  /// Validate a profile bundle.
  BundleValidationResult validate(ProfileBundle bundle) {
    final errors = <String>[];
    final warnings = <String>[];

    if (bundle.bundleId.isEmpty) {
      errors.add('Bundle ID is required');
    }

    if (bundle.name.isEmpty) {
      errors.add('Bundle name is required');
    }

    // Validate default profile exists
    if (bundle.defaultProfileId != null &&
        !bundle.hasProfile(bundle.defaultProfileId!)) {
      errors.add(
          'Default profile "${bundle.defaultProfileId}" not found in bundle');
    }

    // Validate each profile
    for (final profile in bundle.profiles) {
      final profileErrors = profile.validate();
      for (final error in profileErrors) {
        errors.add('Profile "${profile.id}": $error');
      }
    }

    // Check for duplicate profile IDs
    final ids = <String>{};
    for (final profile in bundle.profiles) {
      if (ids.contains(profile.id)) {
        errors.add('Duplicate profile ID: ${profile.id}');
      }
      ids.add(profile.id);
    }

    // Check parent references
    for (final profile in bundle.profiles) {
      if (profile.parentId != null && !bundle.hasProfile(profile.parentId!)) {
        warnings.add(
            'Profile "${profile.id}" references non-existent parent "${profile.parentId}"');
      }
    }

    // Check for circular inheritance
    final circularRefs = _checkCircularInheritance(bundle);
    for (final ref in circularRefs) {
      errors.add('Circular inheritance detected: $ref');
    }

    return BundleValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  List<String> _checkCircularInheritance(ProfileBundle bundle) {
    final circular = <String>[];

    for (final profile in bundle.profiles) {
      final visited = <String>{};
      var current = profile;

      while (current.parentId != null) {
        if (visited.contains(current.id)) {
          circular.add('${profile.id} -> ${visited.join(" -> ")}');
          break;
        }
        visited.add(current.id);

        final parent = bundle.getProfile(current.parentId!);
        if (parent == null) break;
        current = parent;
      }
    }

    return circular;
  }
}

/// Validation result for bundle.
class BundleValidationResult {
  /// Whether validation passed.
  final bool isValid;

  /// Error messages.
  final List<String> errors;

  /// Warning messages.
  final List<String> warnings;

  const BundleValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}

/// Profile inheritance resolver.
class ProfileInheritanceResolver {
  /// Resolve a profile with its full inheritance chain.
  Profile resolve(Profile profile, ProfileBundle bundle) {
    if (profile.parentId == null) {
      return profile;
    }

    final parent = bundle.getProfile(profile.parentId!);
    if (parent == null) {
      return profile;
    }

    // Recursively resolve parent
    final resolvedParent = resolve(parent, bundle);

    // Merge parent into profile
    return _merge(resolvedParent, profile);
  }

  Profile _merge(Profile parent, Profile child) {
    return Profile(
      id: child.id,
      name: child.name,
      description: child.description ?? parent.description,
      version: child.version,
      sections: _mergeSections(parent.sections, child.sections),
      capabilities: _mergeCapabilities(parent.capabilities, child.capabilities),
      metadata: {...parent.metadata, ...child.metadata},
      tags: {...parent.tags, ...child.tags}.toList(),
      parentId: child.parentId,
      active: child.active,
      createdAt: child.createdAt,
      updatedAt: child.updatedAt,
    );
  }

  List<ProfileSection> _mergeSections(
    List<ProfileSection> parentSections,
    List<ProfileSection> childSections,
  ) {
    final merged = <String, ProfileSection>{};

    // Add parent sections
    for (final section in parentSections) {
      merged[section.name] = section;
    }

    // Override with child sections
    for (final section in childSections) {
      merged[section.name] = section;
    }

    return merged.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  List<Capability> _mergeCapabilities(
    List<Capability> parentCaps,
    List<Capability> childCaps,
  ) {
    final merged = <String, Capability>{};

    // Add parent capabilities
    for (final cap in parentCaps) {
      merged[cap.id] = cap;
    }

    // Override with child capabilities
    for (final cap in childCaps) {
      merged[cap.id] = cap;
    }

    return merged.values.toList();
  }
}
