/// Profile section definitions.
library;

/// Types of profile sections.
enum SectionType {
  /// System prompt section.
  system,

  /// Instructions section.
  instructions,

  /// Context section.
  context,

  /// Examples section.
  examples,

  /// Constraints section.
  constraints,

  /// Persona section.
  persona,

  /// Knowledge section.
  knowledge,

  /// Tools section.
  tools,

  /// Custom section.
  custom;

  static SectionType fromString(String value) {
    return SectionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SectionType.custom,
    );
  }
}

/// A section within a profile.
class ProfileSection {
  /// Section name/identifier.
  final String name;

  /// Section type.
  final SectionType type;

  /// Section content (may contain template expressions).
  final String content;

  /// Section priority (higher = earlier in output).
  final int priority;

  /// Condition for including this section.
  final String? condition;

  /// Whether this section is enabled.
  final bool enabled;

  /// Section metadata.
  final Map<String, dynamic> metadata;

  /// Child sections (for nested structure).
  final List<ProfileSection> children;

  const ProfileSection({
    required this.name,
    required this.content,
    this.type = SectionType.custom,
    this.priority = 0,
    this.condition,
    this.enabled = true,
    this.metadata = const {},
    this.children = const [],
  });

  /// Create from JSON.
  factory ProfileSection.fromJson(Map<String, dynamic> json) {
    return ProfileSection(
      name: json['name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: SectionType.fromString(json['type'] as String? ?? 'custom'),
      priority: json['priority'] as int? ?? 0,
      condition: json['condition'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => ProfileSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'content': content,
        'type': type.name,
        if (priority != 0) 'priority': priority,
        if (condition != null) 'condition': condition,
        if (!enabled) 'enabled': enabled,
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };

  /// Copy with modifications.
  ProfileSection copyWith({
    String? name,
    String? content,
    SectionType? type,
    int? priority,
    String? condition,
    bool? enabled,
    Map<String, dynamic>? metadata,
    List<ProfileSection>? children,
  }) {
    return ProfileSection(
      name: name ?? this.name,
      content: content ?? this.content,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      condition: condition ?? this.condition,
      enabled: enabled ?? this.enabled,
      metadata: metadata ?? this.metadata,
      children: children ?? this.children,
    );
  }

  /// Validate the section.
  List<String> validate() {
    final errors = <String>[];

    if (name.isEmpty) {
      errors.add('Section name is required');
    }
    if (content.isEmpty && children.isEmpty) {
      errors.add('Section must have content or children');
    }

    // Validate children
    for (var i = 0; i < children.length; i++) {
      final childErrors = children[i].validate();
      for (final error in childErrors) {
        errors.add('Child [$i]: $error');
      }
    }

    return errors;
  }

  /// Check if section has template expressions.
  bool get hasTemplateExpressions {
    return content.contains(r'${') || content.contains('{{');
  }

  /// Get all child sections recursively.
  List<ProfileSection> get allChildren {
    final result = <ProfileSection>[];
    for (final child in children) {
      result.add(child);
      result.addAll(child.allChildren);
    }
    return result;
  }

  @override
  String toString() => 'ProfileSection($name: ${type.name})';
}

/// A template variable within section content.
class TemplateVariable {
  /// Variable name.
  final String name;

  /// Variable type.
  final String type;

  /// Default value.
  final dynamic defaultValue;

  /// Whether the variable is required.
  final bool required;

  /// Variable description.
  final String? description;

  const TemplateVariable({
    required this.name,
    this.type = 'string',
    this.defaultValue,
    this.required = true,
    this.description,
  });

  factory TemplateVariable.fromJson(Map<String, dynamic> json) {
    return TemplateVariable(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'string',
      defaultValue: json['default'],
      required: json['required'] as bool? ?? true,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        if (defaultValue != null) 'default': defaultValue,
        'required': required,
        if (description != null) 'description': description,
      };
}

/// Section ordering strategies.
enum SectionOrdering {
  /// Order by priority (descending).
  byPriority,

  /// Order by type (system first, then instructions, etc.).
  byType,

  /// Order as defined.
  asIs,

  /// Custom ordering.
  custom;
}
