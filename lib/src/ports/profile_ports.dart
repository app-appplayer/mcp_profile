/// Profile Ports Container - Container for all port implementations.
///
/// Provides a unified container for all ports required by profile execution.
library;

import '../definition/profile.dart';
import 'profile_port.dart';
import 'fact_graph_port.dart';
import 'appraisal_port.dart';
import 'expression_port.dart';

/// Container for all port implementations.
class ProfilePorts {
  /// Profile storage port.
  final ProfileStoragePort storage;

  /// Profile selection port.
  final ProfileSelectionPort selection;

  /// Profile render port.
  final ProfileRenderPort render;

  /// FactGraph port for data queries (L1).
  final FactGraphPortL1 factGraph;

  /// Appraisal port for metric computation.
  final AppraisalPort appraisal;

  /// Expression port for formatting.
  final ExpressionPort expression;

  const ProfilePorts({
    required this.storage,
    required this.selection,
    required this.render,
    required this.factGraph,
    required this.appraisal,
    required this.expression,
  });

  /// Create with stub implementations.
  factory ProfilePorts.stub() {
    return ProfilePorts(
      storage: StubProfileStoragePort(),
      selection: StubProfileSelectionPort(),
      render: StubProfileRenderPort(),
      factGraph: const EmptyFactGraphPortL1(),
      appraisal: const EmptyAppraisalPort(),
      expression: const EmptyExpressionPort(),
    );
  }

  /// Create a copy with some ports replaced.
  ProfilePorts copyWith({
    ProfileStoragePort? storage,
    ProfileSelectionPort? selection,
    ProfileRenderPort? render,
    FactGraphPortL1? factGraph,
    AppraisalPort? appraisal,
    ExpressionPort? expression,
  }) {
    return ProfilePorts(
      storage: storage ?? this.storage,
      selection: selection ?? this.selection,
      render: render ?? this.render,
      factGraph: factGraph ?? this.factGraph,
      appraisal: appraisal ?? this.appraisal,
      expression: expression ?? this.expression,
    );
  }
}

/// Stub implementation of ProfileStoragePort.
class StubProfileStoragePort implements ProfileStoragePort {
  final Map<String, Profile> _profiles = {};
  final Map<String, Profile> _versionedProfiles = {};

  @override
  Future<void> saveProfile(Profile profile) async {
    _profiles[profile.id] = profile;
    _versionedProfiles['${profile.id}:${profile.version}'] = profile;
  }

  @override
  Future<Profile?> getProfile(String profileId) async {
    return _profiles[profileId];
  }

  @override
  Future<Profile?> getProfileVersion(String profileId, String version) async {
    return _versionedProfiles['$profileId:$version'];
  }

  @override
  Future<List<Profile>> getAllProfiles() async {
    return _profiles.values.toList();
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    _profiles.remove(profileId);
  }

  @override
  Future<List<Profile>> getProfilesByTag(String tag) async {
    return _profiles.values.where((p) => p.tags.contains(tag)).toList();
  }

  @override
  Future<List<Profile>> searchProfiles(String query) async {
    final lowerQuery = query.toLowerCase();
    return _profiles.values.where((p) {
      return p.name.toLowerCase().contains(lowerQuery) ||
          (p.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  @override
  Future<List<String>> getProfileVersions(String profileId) async {
    return _versionedProfiles.keys
        .where((k) => k.startsWith('$profileId:'))
        .map((k) => k.split(':').last)
        .toList();
  }
}

/// Stub implementation of ProfileSelectionPort.
class StubProfileSelectionPort implements ProfileSelectionPort {
  @override
  Future<ProfileSelectionResult> selectProfile({
    required List<String> candidateIds,
    required Map<String, dynamic> context,
    String? preferredId,
  }) async {
    if (candidateIds.isEmpty) {
      return const ProfileSelectionResult(
        selectedId: null,
        confidence: 0,
        reason: 'No candidates provided',
      );
    }

    // Select preferred or first candidate
    final selected = preferredId != null && candidateIds.contains(preferredId)
        ? preferredId
        : candidateIds.first;

    return ProfileSelectionResult(
      selectedId: selected,
      confidence: 0.8,
      reason: 'Default selection',
      alternatives: candidateIds.where((id) => id != selected).toList(),
    );
  }

  @override
  Future<List<ProfileRecommendation>> getRecommendations({
    required Map<String, dynamic> context,
    int maxResults = 5,
  }) async {
    return [];
  }
}

/// Stub implementation of ProfileRenderPort.
class StubProfileRenderPort implements ProfileRenderPort {
  @override
  Future<RenderedProfile> render({
    required Profile profile,
    required Map<String, dynamic> context,
    RenderOptions? options,
  }) async {
    final content = profile.sections
        .map((s) => s.content)
        .where((c) => c.isNotEmpty)
        .join('\n\n');

    return RenderedProfile(
      systemPrompt: content,
      activeCapabilities: profile.enabledCapabilities.map((c) => c.id).toList(),
    );
  }
}
