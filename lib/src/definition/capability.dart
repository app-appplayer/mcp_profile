/// Capability definitions for profiles.
library;

/// A capability that a profile can have.
class Capability {
  /// Capability identifier.
  final String id;

  /// Capability name.
  final String name;

  /// Capability description.
  final String? description;

  /// Whether this capability is enabled.
  final bool enabled;

  /// Capability configuration.
  final Map<String, dynamic> config;

  /// Required permissions for this capability.
  final List<String> permissions;

  /// Dependencies on other capabilities.
  final List<String> dependencies;

  const Capability({
    required this.id,
    required this.name,
    this.description,
    this.enabled = true,
    this.config = const {},
    this.permissions = const [],
    this.dependencies = const [],
  });

  /// Create from JSON.
  factory Capability.fromJson(Map<String, dynamic> json) {
    return Capability(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      config: json['config'] as Map<String, dynamic>? ?? {},
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'enabled': enabled,
        if (config.isNotEmpty) 'config': config,
        if (permissions.isNotEmpty) 'permissions': permissions,
        if (dependencies.isNotEmpty) 'dependencies': dependencies,
      };

  /// Copy with modifications.
  Capability copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
    Map<String, dynamic>? config,
    List<String>? permissions,
    List<String>? dependencies,
  }) {
    return Capability(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      config: config ?? this.config,
      permissions: permissions ?? this.permissions,
      dependencies: dependencies ?? this.dependencies,
    );
  }

  /// Validate the capability.
  List<String> validate() {
    final errors = <String>[];

    if (id.isEmpty) {
      errors.add('Capability ID is required');
    }
    if (name.isEmpty) {
      errors.add('Capability name is required');
    }

    return errors;
  }

  @override
  String toString() => 'Capability($id: $name, enabled: $enabled)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Capability &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Standard capability IDs.
class StandardCapabilities {
  /// Code generation capability.
  static const String codeGeneration = 'code_generation';

  /// Code review capability.
  static const String codeReview = 'code_review';

  /// Documentation capability.
  static const String documentation = 'documentation';

  /// Testing capability.
  static const String testing = 'testing';

  /// Debugging capability.
  static const String debugging = 'debugging';

  /// Refactoring capability.
  static const String refactoring = 'refactoring';

  /// Analysis capability.
  static const String analysis = 'analysis';

  /// Planning capability.
  static const String planning = 'planning';

  /// Communication capability.
  static const String communication = 'communication';

  /// File operations capability.
  static const String fileOperations = 'file_operations';

  /// Web search capability.
  static const String webSearch = 'web_search';

  /// API access capability.
  static const String apiAccess = 'api_access';

  /// All standard capabilities.
  static const List<String> all = [
    codeGeneration,
    codeReview,
    documentation,
    testing,
    debugging,
    refactoring,
    analysis,
    planning,
    communication,
    fileOperations,
    webSearch,
    apiAccess,
  ];

  /// Create a capability with standard ID.
  static Capability create(
    String id, {
    String? name,
    String? description,
    bool enabled = true,
    Map<String, dynamic> config = const {},
  }) {
    return Capability(
      id: id,
      name: name ?? _defaultName(id),
      description: description ?? _defaultDescription(id),
      enabled: enabled,
      config: config,
    );
  }

  static String _defaultName(String id) {
    return id
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  static String _defaultDescription(String id) {
    switch (id) {
      case codeGeneration:
        return 'Generate code in various programming languages';
      case codeReview:
        return 'Review code for issues and improvements';
      case documentation:
        return 'Create and update documentation';
      case testing:
        return 'Write and run tests';
      case debugging:
        return 'Debug and troubleshoot issues';
      case refactoring:
        return 'Refactor and improve code structure';
      case analysis:
        return 'Analyze code and data';
      case planning:
        return 'Plan and organize tasks';
      case communication:
        return 'Communicate with users and systems';
      case fileOperations:
        return 'Read, write, and manage files';
      case webSearch:
        return 'Search the web for information';
      case apiAccess:
        return 'Access external APIs';
      default:
        return 'Custom capability';
    }
  }
}
