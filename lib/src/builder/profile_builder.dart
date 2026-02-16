/// Fluent builder for creating profiles.
library;

import '../definition/profile.dart';
import '../definition/section.dart';
import '../definition/capability.dart';

/// Fluent builder for creating profiles.
class ProfileBuilder {
  String _id = '';
  String _name = '';
  String? _description;
  String _version = '1.0.0';
  final List<ProfileSection> _sections = [];
  final List<Capability> _capabilities = [];
  final Map<String, dynamic> _metadata = {};
  final List<String> _tags = [];
  String? _parentId;
  bool _active = true;

  /// Set profile ID.
  ProfileBuilder id(String id) {
    _id = id;
    return this;
  }

  /// Set profile name.
  ProfileBuilder name(String name) {
    _name = name;
    return this;
  }

  /// Set profile description.
  ProfileBuilder description(String description) {
    _description = description;
    return this;
  }

  /// Set profile version.
  ProfileBuilder version(String version) {
    _version = version;
    return this;
  }

  /// Set parent profile ID for inheritance.
  ProfileBuilder parent(String parentId) {
    _parentId = parentId;
    return this;
  }

  /// Set active status.
  ProfileBuilder active(bool active) {
    _active = active;
    return this;
  }

  /// Add a section.
  ProfileBuilder section(ProfileSection section) {
    _sections.add(section);
    return this;
  }

  /// Add a section using a builder.
  ProfileBuilder sectionBuilder(
    void Function(SectionBuilder builder) builderFn,
  ) {
    final builder = SectionBuilder();
    builderFn(builder);
    _sections.add(builder.build());
    return this;
  }

  /// Add a system prompt section.
  ProfileBuilder systemPrompt(String content, {int priority = 100}) {
    _sections.add(ProfileSection(
      name: 'system',
      type: SectionType.system,
      content: content,
      priority: priority,
    ));
    return this;
  }

  /// Add an instructions section.
  ProfileBuilder instructions(String content, {int priority = 90}) {
    _sections.add(ProfileSection(
      name: 'instructions',
      type: SectionType.instructions,
      content: content,
      priority: priority,
    ));
    return this;
  }

  /// Add a context section.
  ProfileBuilder context(String content, {int priority = 80}) {
    _sections.add(ProfileSection(
      name: 'context',
      type: SectionType.context,
      content: content,
      priority: priority,
    ));
    return this;
  }

  /// Add an examples section.
  ProfileBuilder examples(String content, {int priority = 70}) {
    _sections.add(ProfileSection(
      name: 'examples',
      type: SectionType.examples,
      content: content,
      priority: priority,
    ));
    return this;
  }

  /// Add a constraints section.
  ProfileBuilder constraints(String content, {int priority = 95}) {
    _sections.add(ProfileSection(
      name: 'constraints',
      type: SectionType.constraints,
      content: content,
      priority: priority,
    ));
    return this;
  }

  /// Add a persona section.
  ProfileBuilder persona(String content, {int priority = 85}) {
    _sections.add(ProfileSection(
      name: 'persona',
      type: SectionType.persona,
      content: content,
      priority: priority,
    ));
    return this;
  }

  /// Add a capability.
  ProfileBuilder capability(Capability capability) {
    _capabilities.add(capability);
    return this;
  }

  /// Add a capability by ID.
  ProfileBuilder capabilityId(String id, {bool enabled = true}) {
    _capabilities.add(StandardCapabilities.create(id, enabled: enabled));
    return this;
  }

  /// Add multiple capabilities by IDs.
  ProfileBuilder capabilityIds(List<String> ids) {
    for (final id in ids) {
      capabilityId(id);
    }
    return this;
  }

  /// Add metadata.
  ProfileBuilder metadata(String key, dynamic value) {
    _metadata[key] = value;
    return this;
  }

  /// Add multiple metadata entries.
  ProfileBuilder metadataAll(Map<String, dynamic> metadata) {
    _metadata.addAll(metadata);
    return this;
  }

  /// Add a tag.
  ProfileBuilder tag(String tag) {
    _tags.add(tag);
    return this;
  }

  /// Add multiple tags.
  ProfileBuilder tags(List<String> tags) {
    _tags.addAll(tags);
    return this;
  }

  /// Build the profile.
  Profile build() {
    return Profile(
      id: _id,
      name: _name,
      description: _description,
      version: _version,
      sections: List.unmodifiable(_sections),
      capabilities: List.unmodifiable(_capabilities),
      metadata: Map.unmodifiable(_metadata),
      tags: List.unmodifiable(_tags),
      parentId: _parentId,
      active: _active,
      createdAt: DateTime.now(),
    );
  }

  /// Reset the builder.
  void reset() {
    _id = '';
    _name = '';
    _description = null;
    _version = '1.0.0';
    _sections.clear();
    _capabilities.clear();
    _metadata.clear();
    _tags.clear();
    _parentId = null;
    _active = true;
  }
}

/// Fluent builder for creating sections.
class SectionBuilder {
  String _name = '';
  SectionType _type = SectionType.custom;
  String _content = '';
  int _priority = 0;
  String? _condition;
  bool _enabled = true;
  final Map<String, dynamic> _metadata = {};
  final List<ProfileSection> _children = [];

  /// Set section name.
  SectionBuilder name(String name) {
    _name = name;
    return this;
  }

  /// Set section type.
  SectionBuilder type(SectionType type) {
    _type = type;
    return this;
  }

  /// Set section content.
  SectionBuilder content(String content) {
    _content = content;
    return this;
  }

  /// Set section priority.
  SectionBuilder priority(int priority) {
    _priority = priority;
    return this;
  }

  /// Set section condition.
  SectionBuilder condition(String condition) {
    _condition = condition;
    return this;
  }

  /// Set enabled status.
  SectionBuilder enabled(bool enabled) {
    _enabled = enabled;
    return this;
  }

  /// Add metadata.
  SectionBuilder metadata(String key, dynamic value) {
    _metadata[key] = value;
    return this;
  }

  /// Add a child section.
  SectionBuilder child(ProfileSection child) {
    _children.add(child);
    return this;
  }

  /// Add a child section using a builder.
  SectionBuilder childBuilder(
    void Function(SectionBuilder builder) builderFn,
  ) {
    final builder = SectionBuilder();
    builderFn(builder);
    _children.add(builder.build());
    return this;
  }

  /// Build the section.
  ProfileSection build() {
    return ProfileSection(
      name: _name,
      type: _type,
      content: _content,
      priority: _priority,
      condition: _condition,
      enabled: _enabled,
      metadata: Map.unmodifiable(_metadata),
      children: List.unmodifiable(_children),
    );
  }
}

/// Fluent builder for creating capabilities.
class CapabilityBuilder {
  String _id = '';
  String _name = '';
  String? _description;
  bool _enabled = true;
  final Map<String, dynamic> _config = {};
  final List<String> _permissions = [];
  final List<String> _dependencies = [];

  /// Set capability ID.
  CapabilityBuilder id(String id) {
    _id = id;
    return this;
  }

  /// Set capability name.
  CapabilityBuilder name(String name) {
    _name = name;
    return this;
  }

  /// Set capability description.
  CapabilityBuilder description(String description) {
    _description = description;
    return this;
  }

  /// Set enabled status.
  CapabilityBuilder enabled(bool enabled) {
    _enabled = enabled;
    return this;
  }

  /// Add configuration.
  CapabilityBuilder config(String key, dynamic value) {
    _config[key] = value;
    return this;
  }

  /// Add a permission.
  CapabilityBuilder permission(String permission) {
    _permissions.add(permission);
    return this;
  }

  /// Add a dependency.
  CapabilityBuilder dependency(String dependency) {
    _dependencies.add(dependency);
    return this;
  }

  /// Build the capability.
  Capability build() {
    return Capability(
      id: _id,
      name: _name,
      description: _description,
      enabled: _enabled,
      config: Map.unmodifiable(_config),
      permissions: List.unmodifiable(_permissions),
      dependencies: List.unmodifiable(_dependencies),
    );
  }
}
