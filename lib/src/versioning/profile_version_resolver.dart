/// Profile Version Resolver - Version lifecycle management per design/05-versioning.md §3.
///
/// Manages version resolution, constraint matching, and lifecycle states.
library;

// =============================================================================
// ProfileVersionStatus (§1)
// =============================================================================

/// Version lifecycle states.
enum ProfileVersionStatus {
  /// In development, not yet published.
  draft,

  /// Active and available for use.
  published,

  /// Still works but should migrate.
  deprecated,

  /// Read-only, no new usage.
  archived,

  /// Permanently removed.
  deleted,
}

// =============================================================================
// ProfileVersion (§2)
// =============================================================================

/// Parsed semantic version per design/05-versioning.md §2.
class ProfileVersion {
  /// Major version (breaking changes).
  final int major;

  /// Minor version (new features).
  final int minor;

  /// Patch version (bug fixes).
  final int patch;

  /// Pre-release tag (e.g., "alpha", "beta", "rc").
  final String? preReleaseType;

  /// Pre-release number.
  final int? preReleaseNumber;

  /// Build metadata.
  final String? build;

  /// Lifecycle status.
  final ProfileVersionStatus status;

  /// When this version was published.
  final DateTime? publishedAt;

  /// When this version was deprecated.
  final DateTime? deprecatedAt;

  /// When this version will be removed.
  final DateTime? sunsetDate;

  /// When this version was archived.
  final DateTime? archivedAt;

  /// Compatibility information per §2.
  final VersionCompatibility? compatibility;

  /// Migration information per §2.
  final MigrationInfo? migration;

  const ProfileVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preReleaseType,
    this.preReleaseNumber,
    this.build,
    this.status = ProfileVersionStatus.draft,
    this.publishedAt,
    this.deprecatedAt,
    this.sunsetDate,
    this.archivedAt,
    this.compatibility,
    this.migration,
  });

  /// Parse from string (e.g., "1.2.3", "1.0.0-beta.1").
  factory ProfileVersion.parse(String version) {
    final parts = version.split('-');
    final versionParts = parts[0].split('.');

    String? preType;
    int? preNum;
    if (parts.length > 1) {
      final preParts = parts[1].split('.');
      preType = preParts[0];
      preNum = preParts.length > 1 ? int.tryParse(preParts[1]) : null;
    }

    return ProfileVersion(
      major: int.parse(versionParts[0]),
      minor: versionParts.length > 1 ? int.parse(versionParts[1]) : 0,
      patch: versionParts.length > 2 ? int.parse(versionParts[2]) : 0,
      preReleaseType: preType,
      preReleaseNumber: preNum,
    );
  }

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    if (preReleaseType != null) {
      final pre = preReleaseNumber != null
          ? '$preReleaseType.$preReleaseNumber'
          : preReleaseType!;
      return '$base-$pre';
    }
    return base;
  }
}

// =============================================================================
// VersionCompatibility (§2)
// =============================================================================

/// Compatibility information for a profile version per §2.
class VersionCompatibility {
  /// Minimum schema version required.
  final String minSchemaVersion;

  /// Previous versions this is compatible with.
  final List<String>? backwardCompatibleWith;

  /// Future versions this is compatible with.
  final List<String>? forwardCompatibleWith;

  const VersionCompatibility({
    required this.minSchemaVersion,
    this.backwardCompatibleWith,
    this.forwardCompatibleWith,
  });
}

// =============================================================================
// MigrationInfo (§2)
// =============================================================================

/// Migration information for a profile version per §2.
class MigrationInfo {
  /// Version this migrates from.
  final String fromVersion;

  /// Optional migration script identifier.
  final String? migrationScript;

  /// Whether this is a breaking migration.
  final bool breaking;

  /// Migration notes.
  final String notes;

  const MigrationInfo({
    required this.fromVersion,
    this.migrationScript,
    this.breaking = false,
    required this.notes,
  });
}

// =============================================================================
// VersionConstraint (§2)
// =============================================================================

/// Version constraint specification per §2.
class VersionConstraint {
  /// Version range string (e.g., "^1.0.0", ">=1.0.0 <2.0.0").
  final String range;

  /// Parsed constraint details.
  final VersionConstraintParsed parsed;

  const VersionConstraint({
    required this.range,
    required this.parsed,
  });

  /// Parse from range string.
  factory VersionConstraint.parse(String range) {
    final trimmed = range.trim();

    if (trimmed == '*' || trimmed == 'any') {
      return VersionConstraint(
        range: trimmed,
        parsed: const VersionConstraintParsed(
          type: VersionConstraintType.any,
          inclusiveMin: true,
          inclusiveMax: true,
        ),
      );
    }
    if (trimmed.startsWith('^')) {
      final min = ProfileVersion.parse(trimmed.substring(1));
      return VersionConstraint(
        range: trimmed,
        parsed: VersionConstraintParsed(
          type: VersionConstraintType.caret,
          min: min,
          inclusiveMin: true,
          inclusiveMax: false,
        ),
      );
    }
    if (trimmed.startsWith('~')) {
      final min = ProfileVersion.parse(trimmed.substring(1));
      return VersionConstraint(
        range: trimmed,
        parsed: VersionConstraintParsed(
          type: VersionConstraintType.tilde,
          min: min,
          inclusiveMin: true,
          inclusiveMax: false,
        ),
      );
    }
    if (trimmed.contains(' ')) {
      final parts = trimmed.split(' ');
      ProfileVersion? min;
      ProfileVersion? max;
      bool inclusiveMin = false;
      bool inclusiveMax = false;

      for (final part in parts) {
        if (part.startsWith('>=')) {
          min = ProfileVersion.parse(part.substring(2));
          inclusiveMin = true;
        } else if (part.startsWith('>')) {
          min = ProfileVersion.parse(part.substring(1));
          inclusiveMin = false;
        } else if (part.startsWith('<=')) {
          max = ProfileVersion.parse(part.substring(2));
          inclusiveMax = true;
        } else if (part.startsWith('<')) {
          max = ProfileVersion.parse(part.substring(1));
          inclusiveMax = false;
        }
      }

      return VersionConstraint(
        range: trimmed,
        parsed: VersionConstraintParsed(
          type: VersionConstraintType.range,
          min: min,
          max: max,
          inclusiveMin: inclusiveMin,
          inclusiveMax: inclusiveMax,
        ),
      );
    }

    return VersionConstraint(
      range: trimmed,
      parsed: VersionConstraintParsed(
        type: VersionConstraintType.exact,
        inclusiveMin: true,
        inclusiveMax: true,
      ),
    );
  }
}

/// Parsed version constraint details per §2.
class VersionConstraintParsed {
  /// Constraint type.
  final VersionConstraintType type;

  /// Minimum version bound.
  final ProfileVersion? min;

  /// Maximum version bound.
  final ProfileVersion? max;

  /// Whether the minimum bound is inclusive.
  final bool inclusiveMin;

  /// Whether the maximum bound is inclusive.
  final bool inclusiveMax;

  const VersionConstraintParsed({
    required this.type,
    this.min,
    this.max,
    required this.inclusiveMin,
    required this.inclusiveMax,
  });
}

/// Version constraint types.
enum VersionConstraintType {
  /// Exact version match.
  exact,

  /// Version range (e.g., ">=1.0.0 <2.0.0").
  range,

  /// Caret: ^1.2.3 = >=1.2.3 <2.0.0.
  caret,

  /// Tilde: ~1.2.3 = >=1.2.3 <1.3.0.
  tilde,

  /// Any version.
  any,
}

// =============================================================================
// VersionResolutionConfig (§3)
// =============================================================================

/// Configuration for version resolution behavior.
class VersionResolutionConfig {
  /// Whether to allow deprecated versions.
  final bool allowDeprecated;

  /// Whether to allow pre-release versions.
  final bool allowPreRelease;

  /// Default constraint type when none specified.
  final VersionConstraintType defaultConstraintType;

  const VersionResolutionConfig({
    this.allowDeprecated = true,
    this.allowPreRelease = false,
    this.defaultConstraintType = VersionConstraintType.caret,
  });
}

// =============================================================================
// ProfileVersionResolver (§3)
// =============================================================================

/// Resolves profile versions based on constraints and lifecycle per §3.
class ProfileVersionResolver {
  final VersionResolutionConfig config;

  const ProfileVersionResolver({
    this.config = const VersionResolutionConfig(),
  });

  /// Resolve the best version from a list of versioned profiles.
  ///
  /// Per design/05-versioning.md §3: filters by lifecycle status,
  /// applies constraint, and returns the highest matching version.
  ///
  /// [versions] is a list of (version string, status) pairs.
  /// Returns the best matching version string, or null if none match.
  /// Throws [VersionConstraintException] if constraint specified but no match.
  String? resolve(
    List<VersionedProfile> versions,
    VersionConstraint? constraint,
  ) {
    if (versions.isEmpty) return null;

    // Filter by status (exclude archived/deleted unless explicitly requested)
    final activeVersions = versions.where((v) =>
        v.status == ProfileVersionStatus.published ||
        (config.allowDeprecated &&
            v.status == ProfileVersionStatus.deprecated)).toList();

    if (activeVersions.isEmpty) return null;

    // Filter by pre-release
    final filteredVersions = config.allowPreRelease
        ? activeVersions
        : activeVersions
            .where((v) =>
                ProfileVersion.parse(v.version).preReleaseType == null)
            .toList();

    if (filteredVersions.isEmpty) return null;

    // Apply constraint if provided
    if (constraint != null) {
      final matching = filteredVersions
          .where((v) => satisfiesConstraint(v.version, constraint))
          .toList();

      if (matching.isEmpty) {
        throw VersionConstraintException(
          constraint: constraint,
          availableVersions:
              filteredVersions.map((v) => v.version).toList(),
        );
      }

      // Return highest matching version
      matching.sort((a, b) => compareVersions(b.version, a.version));
      return matching.first.version;
    }

    // No constraint: return latest published version
    filteredVersions
        .sort((a, b) => compareVersions(b.version, a.version));
    return filteredVersions.first.version;
  }

  /// Check if a version satisfies a constraint per §3.
  bool satisfiesConstraint(String version, VersionConstraint constraint) {
    final parsed = ProfileVersion.parse(version);

    return switch (constraint.parsed.type) {
      VersionConstraintType.any => true,
      VersionConstraintType.exact => version == constraint.range,
      VersionConstraintType.caret => _satisfiesCaret(parsed, constraint),
      VersionConstraintType.tilde => _satisfiesTilde(parsed, constraint),
      VersionConstraintType.range => _satisfiesRange(parsed, constraint),
    };
  }

  /// Compare two version strings. Returns negative, zero, or positive.
  int compareVersions(String a, String b) {
    final parsedA = ProfileVersion.parse(a);
    final parsedB = ProfileVersion.parse(b);

    if (parsedA.major != parsedB.major) {
      return parsedA.major.compareTo(parsedB.major);
    }
    if (parsedA.minor != parsedB.minor) {
      return parsedA.minor.compareTo(parsedB.minor);
    }
    if (parsedA.patch != parsedB.patch) {
      return parsedA.patch.compareTo(parsedB.patch);
    }

    // No pre-release > pre-release
    if (parsedA.preReleaseType == null && parsedB.preReleaseType != null) {
      return 1;
    }
    if (parsedA.preReleaseType != null && parsedB.preReleaseType == null) {
      return -1;
    }
    if (parsedA.preReleaseType != null && parsedB.preReleaseType != null) {
      final typeOrder = ['alpha', 'beta', 'rc'];
      final typeCompare = typeOrder.indexOf(parsedA.preReleaseType!)
          .compareTo(typeOrder.indexOf(parsedB.preReleaseType!));
      if (typeCompare != 0) return typeCompare;
      return (parsedA.preReleaseNumber ?? 0)
          .compareTo(parsedB.preReleaseNumber ?? 0);
    }

    return 0;
  }

  bool _satisfiesCaret(ProfileVersion version, VersionConstraint constraint) {
    final min = constraint.parsed.min!;
    return version.major == min.major &&
        compareVersions(version.toString(), min.toString()) >= 0;
  }

  bool _satisfiesTilde(ProfileVersion version, VersionConstraint constraint) {
    final min = constraint.parsed.min!;
    return version.major == min.major &&
        version.minor == min.minor &&
        compareVersions(version.toString(), min.toString()) >= 0;
  }

  bool _satisfiesRange(ProfileVersion version, VersionConstraint constraint) {
    final versionStr = version.toString();

    final min = constraint.parsed.min;
    final max = constraint.parsed.max;

    if (min != null) {
      final cmp = compareVersions(versionStr, min.toString());
      if (constraint.parsed.inclusiveMin ? cmp < 0 : cmp <= 0) return false;
    }

    if (max != null) {
      final cmp = compareVersions(versionStr, max.toString());
      if (constraint.parsed.inclusiveMax ? cmp > 0 : cmp >= 0) return false;
    }

    return true;
  }
}

// =============================================================================
// VersionedProfile (§3)
// =============================================================================

/// Lightweight container pairing a version string with its lifecycle status.
class VersionedProfile {
  /// Version string (e.g. "1.2.3").
  final String version;

  /// Lifecycle status of this version.
  final ProfileVersionStatus status;

  /// Version info (optional, for migration path building).
  final ProfileVersion? versionInfo;

  const VersionedProfile({
    required this.version,
    required this.status,
    this.versionInfo,
  });
}

// =============================================================================
// Exceptions (§3)
// =============================================================================

/// Exception thrown when no version matches a constraint.
class VersionConstraintException implements Exception {
  /// The constraint that could not be satisfied.
  final VersionConstraint constraint;

  /// Available versions that were checked.
  final List<String> availableVersions;

  const VersionConstraintException({
    required this.constraint,
    required this.availableVersions,
  });

  @override
  String toString() =>
      'VersionConstraintException: No version matching '
      '"${constraint.range}" found. '
      'Available: ${availableVersions.join(', ')}';
}
