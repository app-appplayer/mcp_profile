/// Profile Port - Abstract interfaces for profile operations.
///
/// Defines contracts for profile loading, storage, and execution.
library;

import '../definition/profile.dart';

/// Port for profile storage operations.
abstract class ProfileStoragePort {
  /// Save a profile.
  Future<void> saveProfile(Profile profile);

  /// Get profile by ID.
  Future<Profile?> getProfile(String profileId);

  /// Get profile by ID and version.
  Future<Profile?> getProfileVersion(String profileId, String version);

  /// Get all profiles.
  Future<List<Profile>> getAllProfiles();

  /// Delete profile.
  Future<void> deleteProfile(String profileId);

  /// Get profiles by tag.
  Future<List<Profile>> getProfilesByTag(String tag);

  /// Search profiles by name or description.
  Future<List<Profile>> searchProfiles(String query);

  /// Get profile versions.
  Future<List<String>> getProfileVersions(String profileId);
}

/// Port for profile selection/routing.
abstract class ProfileSelectionPort {
  /// Select best profile for context.
  Future<ProfileSelectionResult> selectProfile({
    required List<String> candidateIds,
    required Map<String, dynamic> context,
    String? preferredId,
  });

  /// Get profile recommendations for context.
  Future<List<ProfileRecommendation>> getRecommendations({
    required Map<String, dynamic> context,
    int maxResults = 5,
  });
}

/// Result of profile selection.
class ProfileSelectionResult {
  /// Selected profile ID.
  final String? selectedId;

  /// Selection confidence.
  final double confidence;

  /// Selection reason.
  final String reason;

  /// Alternative profile IDs.
  final List<String> alternatives;

  const ProfileSelectionResult({
    this.selectedId,
    required this.confidence,
    required this.reason,
    this.alternatives = const [],
  });

  /// Check if a profile was selected.
  bool get hasSelection => selectedId != null;
}

/// Profile recommendation.
class ProfileRecommendation {
  /// Profile ID.
  final String profileId;

  /// Recommendation score.
  final double score;

  /// Recommendation reason.
  final String reason;

  /// Matched capabilities.
  final List<String> matchedCapabilities;

  const ProfileRecommendation({
    required this.profileId,
    required this.score,
    required this.reason,
    this.matchedCapabilities = const [],
  });
}

/// Port for profile rendering.
abstract class ProfileRenderPort {
  /// Render profile to prompt.
  Future<RenderedProfile> render({
    required Profile profile,
    required Map<String, dynamic> context,
    RenderOptions? options,
  });
}

/// Rendered profile content.
class RenderedProfile {
  /// System prompt content.
  final String systemPrompt;

  /// Additional instructions.
  final String? instructions;

  /// Active capabilities.
  final List<String> activeCapabilities;

  /// Rendering metadata.
  final Map<String, dynamic> metadata;

  const RenderedProfile({
    required this.systemPrompt,
    this.instructions,
    this.activeCapabilities = const [],
    this.metadata = const {},
  });

  /// Get full prompt.
  String get fullPrompt {
    if (instructions != null && instructions!.isNotEmpty) {
      return '$systemPrompt\n\n$instructions';
    }
    return systemPrompt;
  }
}

/// Options for profile rendering.
class RenderOptions {
  /// Maximum content length.
  final int? maxLength;

  /// Section types to include.
  final List<String>? includeSections;

  /// Section types to exclude.
  final List<String>? excludeSections;

  /// Whether to include capability descriptions.
  final bool includeCapabilities;

  /// Custom variables for rendering.
  final Map<String, dynamic>? variables;

  const RenderOptions({
    this.maxLength,
    this.includeSections,
    this.excludeSections,
    this.includeCapabilities = true,
    this.variables,
  });
}
