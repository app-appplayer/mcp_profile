/// Profile definition for MCP AI personas.
library;

import 'section.dart';
import 'capability.dart';

/// Represents an AI profile/persona definition.
class Profile {
  /// Unique identifier for this profile.
  final String id;

  /// Display name of the profile.
  final String name;

  /// Profile description.
  final String? description;

  /// Profile version.
  final String version;

  /// Profile sections containing prompt content.
  final List<ProfileSection> sections;

  /// Capabilities this profile has.
  final List<Capability> capabilities;

  /// Profile metadata.
  final Map<String, dynamic> metadata;

  /// Tags for categorization.
  final List<String> tags;

  /// Parent profile ID (for inheritance).
  final String? parentId;

  /// Whether this profile is active.
  final bool active;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    required this.name,
    this.description,
    this.version = '1.0.0',
    this.sections = const [],
    this.capabilities = const [],
    this.metadata = const {},
    this.tags = const [],
    this.parentId,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON.
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      version: json['version'] as String? ?? '1.0.0',
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => ProfileSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((e) => Capability.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      parentId: json['parentId'] as String?,
      active: json['active'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'version': version,
        if (sections.isNotEmpty)
          'sections': sections.map((s) => s.toJson()).toList(),
        if (capabilities.isNotEmpty)
          'capabilities': capabilities.map((c) => c.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (tags.isNotEmpty) 'tags': tags,
        if (parentId != null) 'parentId': parentId,
        'active': active,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  /// Copy with modifications.
  Profile copyWith({
    String? id,
    String? name,
    String? description,
    String? version,
    List<ProfileSection>? sections,
    List<Capability>? capabilities,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    String? parentId,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      sections: sections ?? this.sections,
      capabilities: capabilities ?? this.capabilities,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      parentId: parentId ?? this.parentId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get a section by name.
  ProfileSection? getSection(String name) {
    return sections.where((s) => s.name == name).firstOrNull;
  }

  /// Get sections by type.
  List<ProfileSection> getSectionsByType(SectionType type) {
    return sections.where((s) => s.type == type).toList();
  }

  /// Check if profile has a capability.
  bool hasCapability(String capabilityId) {
    return capabilities.any((c) => c.id == capabilityId && c.enabled);
  }

  /// Get all enabled capabilities.
  List<Capability> get enabledCapabilities {
    return capabilities.where((c) => c.enabled).toList();
  }

  /// Validate the profile.
  List<String> validate() {
    final errors = <String>[];

    if (id.isEmpty) {
      errors.add('Profile ID is required');
    }
    if (name.isEmpty) {
      errors.add('Profile name is required');
    }

    // Validate sections
    for (var i = 0; i < sections.length; i++) {
      final sectionErrors = sections[i].validate();
      for (final error in sectionErrors) {
        errors.add('Section [$i]: $error');
      }
    }

    // Validate capabilities
    for (var i = 0; i < capabilities.length; i++) {
      final capErrors = capabilities[i].validate();
      for (final error in capErrors) {
        errors.add('Capability [$i]: $error');
      }
    }

    return errors;
  }

  @override
  String toString() => 'Profile($id: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Profile context for runtime evaluation.
class ProfileContext {
  /// Current user information.
  final Map<String, dynamic> user;

  /// Environment variables.
  final Map<String, dynamic> environment;

  /// Session data.
  final Map<String, dynamic> session;

  /// Custom variables.
  final Map<String, dynamic> variables;

  const ProfileContext({
    this.user = const {},
    this.environment = const {},
    this.session = const {},
    this.variables = const {},
  });

  /// Get a value by path (dot notation).
  dynamic get(String path) {
    final parts = path.split('.');
    if (parts.isEmpty) return null;

    Map<String, dynamic>? source;
    switch (parts[0]) {
      case 'user':
        source = user;
        break;
      case 'env':
      case 'environment':
        source = environment;
        break;
      case 'session':
        source = session;
        break;
      default:
        source = variables;
        // Include first part in path for variables
        return _getNestedValue(source, parts);
    }

    if (parts.length == 1) return source;
    return _getNestedValue(source, parts.sublist(1));
  }

  dynamic _getNestedValue(Map<String, dynamic>? map, List<String> path) {
    if (map == null || path.isEmpty) return map;

    dynamic current = map;
    for (final key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Create a copy with additional variables.
  ProfileContext withVariables(Map<String, dynamic> additionalVars) {
    return ProfileContext(
      user: user,
      environment: environment,
      session: session,
      variables: {...variables, ...additionalVars},
    );
  }

  /// Convert to a flat map for expression evaluation.
  Map<String, dynamic> toMap() => {
        'user': user,
        'env': environment,
        'environment': environment,
        'session': session,
        ...variables,
      };
}
