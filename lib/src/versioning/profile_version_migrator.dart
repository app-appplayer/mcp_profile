/// Profile Version Migrator - Schema migration per design/05-versioning.md §4.
///
/// Handles migration of profile data between versions.
library;


// =============================================================================
// MigrationScriptRunner (§4)
// =============================================================================

/// Interface for running migration scripts per §4.
abstract class MigrationScriptRunner {
  /// Run a migration script on profile data.
  Future<Map<String, dynamic>> run(
    String script,
    Map<String, dynamic> data,
  );
}

// =============================================================================
// ProfileMigration (§4)
// =============================================================================

/// Describes a migration between two profile versions.
class ProfileMigration {
  /// Source version.
  final String fromVersion;

  /// Target version.
  final String toVersion;

  /// Transform function (takes old data, returns new data).
  final Map<String, dynamic> Function(Map<String, dynamic>) transform;

  /// Whether this is a breaking change.
  final bool breaking;

  /// Migration notes.
  final String? notes;

  /// Optional migration script identifier.
  final String? migrationScript;

  const ProfileMigration({
    required this.fromVersion,
    required this.toVersion,
    required this.transform,
    this.breaking = false,
    this.notes,
    this.migrationScript,
  });
}

// =============================================================================
// MigrationStep (§4)
// =============================================================================

/// A single step in a migration path.
class MigrationStep {
  /// Source version.
  final String fromVersion;

  /// Target version.
  final String toVersion;

  /// The migration to apply.
  final ProfileMigration migration;

  const MigrationStep({
    required this.fromVersion,
    required this.toVersion,
    required this.migration,
  });
}

// =============================================================================
// MigrationResult (§4)
// =============================================================================

/// Result of a migration operation.
class MigrationResult {
  /// Profile ID that was migrated.
  final String profileId;

  /// Source version.
  final String fromVersion;

  /// Target version.
  final String targetVersion;

  /// Whether migration succeeded.
  final bool success;

  /// Steps executed.
  final List<StepMigrationResult> steps;

  /// Error message if failed.
  final String? error;

  /// Migrated data if successful.
  final Map<String, dynamic>? migratedData;

  const MigrationResult({
    required this.profileId,
    required this.fromVersion,
    required this.targetVersion,
    required this.success,
    this.steps = const [],
    this.error,
    this.migratedData,
  });
}

/// Result of a single migration step.
class StepMigrationResult {
  /// The step that was executed.
  final MigrationStep step;

  /// Whether this step succeeded.
  final bool success;

  /// Migrated data if successful.
  final Map<String, dynamic>? migratedData;

  /// Error message if failed.
  final String? error;

  const StepMigrationResult({
    required this.step,
    required this.success,
    this.migratedData,
    this.error,
  });
}

// =============================================================================
// ProfileVersionMigrator (§4)
// =============================================================================

/// Handles migration of profile data between versions per §4.
///
/// Uses a [MigrationScriptRunner] for script-based migrations and
/// registered [ProfileMigration]s for programmatic migrations.
class ProfileVersionMigrator {
  /// Script runner for script-based migrations.
  final MigrationScriptRunner? scriptRunner;

  /// Registered migrations.
  final List<ProfileMigration> _migrations;

  ProfileVersionMigrator({
    this.scriptRunner,
    List<ProfileMigration>? migrations,
  }) : _migrations = migrations ?? [];

  /// Register a migration.
  void register(ProfileMigration migration) {
    _migrations.add(migration);
  }

  /// Migrate profile data from one version to another per §4.
  Future<MigrationResult> migrate(
    String profileId,
    Map<String, dynamic> data,
    String fromVersion,
    String targetVersion,
  ) async {
    // Build migration path
    final path = buildMigrationPath(fromVersion, targetVersion);

    if (path.isEmpty && fromVersion != targetVersion) {
      throw NoMigrationPathException(profileId, fromVersion, targetVersion);
    }

    final results = <StepMigrationResult>[];
    var currentData = Map<String, dynamic>.from(data);

    // Execute migration steps
    for (final step in path) {
      final stepResult = await _migrateStep(currentData, step);
      results.add(stepResult);

      if (!stepResult.success) {
        return MigrationResult(
          profileId: profileId,
          fromVersion: fromVersion,
          targetVersion: targetVersion,
          success: false,
          steps: results,
          error: stepResult.error,
        );
      }

      currentData = stepResult.migratedData!;
    }

    return MigrationResult(
      profileId: profileId,
      fromVersion: fromVersion,
      targetVersion: targetVersion,
      success: true,
      steps: results,
      migratedData: currentData,
    );
  }

  /// Build optimal migration path between versions using BFS.
  List<MigrationStep> buildMigrationPath(
    String fromVersion,
    String targetVersion,
  ) {
    if (fromVersion == targetVersion) return [];

    final queue = <List<MigrationStep>>[[]];
    final visited = <String>{fromVersion};

    while (queue.isNotEmpty) {
      final currentPath = queue.removeAt(0);
      final currentVersion = currentPath.isEmpty
          ? fromVersion
          : currentPath.last.toVersion;

      if (currentVersion == targetVersion) {
        return currentPath;
      }

      // Find migrations from current version
      for (final migration in _migrations) {
        if (migration.fromVersion == currentVersion &&
            !visited.contains(migration.toVersion)) {
          visited.add(migration.toVersion);
          queue.add([
            ...currentPath,
            MigrationStep(
              fromVersion: currentVersion,
              toVersion: migration.toVersion,
              migration: migration,
            ),
          ]);
        }
      }
    }

    return []; // No path found
  }

  /// Execute a single migration step per §4.
  Future<StepMigrationResult> _migrateStep(
    Map<String, dynamic> data,
    MigrationStep step,
  ) async {
    try {
      // Run migration script if provided and script runner available
      if (step.migration.migrationScript != null && scriptRunner != null) {
        final migratedData = await scriptRunner!.run(
          step.migration.migrationScript!,
          data,
        );
        return StepMigrationResult(
          step: step,
          success: true,
          migratedData: migratedData,
        );
      }

      // Automatic migration for non-breaking changes
      if (!step.migration.breaking) {
        final migratedData = step.migration.transform(data);
        return StepMigrationResult(
          step: step,
          success: true,
          migratedData: migratedData,
        );
      }

      // Breaking change requires script
      if (step.migration.migrationScript != null && scriptRunner == null) {
        throw MigrationScriptRequiredException(step);
      }

      // Apply transform for breaking changes when no script needed
      final migratedData = step.migration.transform(data);
      return StepMigrationResult(
        step: step,
        success: true,
        migratedData: migratedData,
      );
    } catch (e) {
      if (e is MigrationScriptRequiredException) rethrow;
      return StepMigrationResult(
        step: step,
        success: false,
        error: e.toString(),
      );
    }
  }
}

// =============================================================================
// Exceptions (§4)
// =============================================================================

/// Exception thrown when no migration path exists between versions.
class NoMigrationPathException implements Exception {
  final String profileId;
  final String fromVersion;
  final String targetVersion;

  const NoMigrationPathException(
    this.profileId,
    this.fromVersion,
    this.targetVersion,
  );

  @override
  String toString() =>
      'NoMigrationPathException: No migration path from '
      '$fromVersion to $targetVersion for profile $profileId';
}

/// Exception thrown when a breaking migration requires a script.
class MigrationScriptRequiredException implements Exception {
  final MigrationStep step;

  const MigrationScriptRequiredException(this.step);

  @override
  String toString() =>
      'MigrationScriptRequiredException: Breaking migration from '
      '${step.fromVersion} to ${step.toVersion} requires a migration script';
}
