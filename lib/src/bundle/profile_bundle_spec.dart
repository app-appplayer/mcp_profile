/// Spec-compliant ProfileBundle - Schema v0.1.0
///
/// As per spec/01-profile-bundle-schema.md §2, §5.
/// Named SpecProfileBundle to avoid conflict with legacy ProfileBundle.
library;

import '../appraisal/metric_definition.dart';
import '../decision/decision_policy.dart';
import '../expression/expression_policy.dart';

// =============================================================================
// ProfileScope (§5)
// =============================================================================

/// Application scope for a profile.
enum ProfileScope {
  /// Individual user profile.
  person,

  /// Team-level profile.
  team,

  /// Project-specific profile.
  project,

  /// Organization-wide profile.
  global,
}

extension ProfileScopeExtension on ProfileScope {
  String toJsonName() {
    return switch (this) {
      ProfileScope.person => 'person',
      ProfileScope.team => 'team',
      ProfileScope.project => 'project',
      ProfileScope.global => 'global',
    };
  }
}

// =============================================================================
// CompatConfig (§5)
// =============================================================================

/// Compatibility requirements for a profile.
class CompatConfig {
  /// Required schema version (semver range).
  final String? schemaVersion;

  /// Package requirements (package name → version constraint).
  final Map<String, String>? requirements;

  const CompatConfig({
    this.schemaVersion,
    this.requirements,
  });

  factory CompatConfig.fromJson(Map<String, dynamic> json) {
    return CompatConfig(
      schemaVersion: json['schemaVersion'] as String?,
      requirements: (json['requirements'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as String)),
    );
  }

  Map<String, dynamic> toJson() => {
        if (schemaVersion != null) 'schemaVersion': schemaVersion,
        if (requirements != null) 'requirements': requirements,
      };
}

// =============================================================================
// ProfileManifest (§5)
// =============================================================================

/// Identity and metadata for a profile bundle.
class ProfileManifest {
  // === REQUIRED ===

  /// Unique identifier (reverse domain notation).
  final String id;

  /// Human-readable name.
  final String name;

  /// Semantic version.
  final String version;

  /// Organization or author.
  final String provider;

  /// Application scope.
  final ProfileScope scope;

  // === OPTIONAL ===

  /// Profile description.
  final String? description;

  /// Skill IDs this profile applies to (supports wildcards).
  final List<String>? appliesTo;

  /// Priority for profile stacking (higher = first). Default: 50.
  final int priority;

  /// Auto-enable on load.
  final bool defaultEnabled;

  /// Discovery tags.
  final List<String> tags;

  /// Compatibility requirements.
  final CompatConfig? compat;

  const ProfileManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.provider,
    required this.scope,
    this.description,
    this.appliesTo,
    this.priority = 50,
    this.defaultEnabled = true,
    this.tags = const [],
    this.compat,
  });

  factory ProfileManifest.fromJson(Map<String, dynamic> json) {
    return ProfileManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      provider: json['provider'] as String,
      scope: ProfileScope.values.firstWhere(
        (s) => s.toJsonName() == (json['scope'] as String),
        orElse: () => ProfileScope.project,
      ),
      description: json['description'] as String?,
      appliesTo: (json['appliesTo'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      priority: json['priority'] as int? ?? 50,
      defaultEnabled: json['defaultEnabled'] as bool? ?? true,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      compat: json['compat'] != null
          ? CompatConfig.fromJson(json['compat'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'provider': provider,
        'scope': scope.toJsonName(),
        if (description != null) 'description': description,
        if (appliesTo != null) 'appliesTo': appliesTo,
        if (priority != 50) 'priority': priority,
        if (!defaultEnabled) 'defaultEnabled': defaultEnabled,
        if (tags.isNotEmpty) 'tags': tags,
        if (compat != null) 'compat': compat!.toJson(),
      };
}

// =============================================================================
// SpecProfileBundle (§2)
// =============================================================================

/// Spec-compliant profile bundle per schema v0.1.0.
///
/// Named SpecProfileBundle to avoid conflict with legacy [ProfileBundle].
class SpecProfileBundle {
  // === REQUIRED ===

  /// Schema version (e.g., "0.1.0").
  final String schemaVersion;

  /// Identity and metadata.
  final ProfileManifest manifest;

  /// Metric definitions.
  final AppraisalSection appraisals;

  // === OPTIONAL ===

  /// Decision rules.
  final DecisionPolicySection? decisionPolicies;

  /// Expression/communication rules.
  final ExpressionPolicySection? expressionPolicies;

  /// Custom extension data.
  final Map<String, dynamic>? extensions;

  const SpecProfileBundle({
    required this.schemaVersion,
    required this.manifest,
    required this.appraisals,
    this.decisionPolicies,
    this.expressionPolicies,
    this.extensions,
  });

  /// Convenience accessors.
  String get id => manifest.id;
  String get name => manifest.name;
  String get version => manifest.version;
  ProfileScope get scope => manifest.scope;
  int get priority => manifest.priority;

  factory SpecProfileBundle.fromJson(Map<String, dynamic> json) {
    return SpecProfileBundle(
      schemaVersion: json['schemaVersion'] as String,
      manifest:
          ProfileManifest.fromJson(json['manifest'] as Map<String, dynamic>),
      appraisals: AppraisalSection.fromJson(
          json['appraisals'] as Map<String, dynamic>),
      decisionPolicies: json['decisionPolicies'] != null
          ? DecisionPolicySection.fromJson(
              json['decisionPolicies'] as Map<String, dynamic>)
          : null,
      expressionPolicies: json['expressionPolicies'] != null
          ? ExpressionPolicySection.fromJson(
              json['expressionPolicies'] as Map<String, dynamic>)
          : null,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'manifest': manifest.toJson(),
        'appraisals': appraisals.toJson(),
        if (decisionPolicies != null)
          'decisionPolicies': decisionPolicies!.toJson(),
        if (expressionPolicies != null)
          'expressionPolicies': expressionPolicies!.toJson(),
        if (extensions != null) 'extensions': extensions,
      };
}
