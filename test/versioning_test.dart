/// ProfileVersionResolver and ProfileVersionMigrator Tests
library;

import 'package:test/test.dart';
import 'package:mcp_profile/mcp_profile.dart';

// =============================================================================
// Test Helpers
// =============================================================================

/// Mock MigrationScriptRunner for testing script-based migrations.
class _MockScriptRunner implements MigrationScriptRunner {
  @override
  Future<Map<String, dynamic>> run(
    String script,
    Map<String, dynamic> data,
  ) async {
    return {...data, 'migrated_by': script};
  }
}

void main() {
  // ===========================================================================
  // ProfileVersionStatus
  // ===========================================================================

  group('ProfileVersionStatus', () {
    test('has 5 values', () {
      expect(ProfileVersionStatus.values.length, equals(5));
      expect(ProfileVersionStatus.values, containsAll([
        ProfileVersionStatus.draft,
        ProfileVersionStatus.published,
        ProfileVersionStatus.deprecated,
        ProfileVersionStatus.archived,
        ProfileVersionStatus.deleted,
      ]));
    });
  });

  // ===========================================================================
  // VersionConstraintType
  // ===========================================================================

  group('VersionConstraintType', () {
    test('has 5 values', () {
      expect(VersionConstraintType.values.length, equals(5));
      expect(VersionConstraintType.values, containsAll([
        VersionConstraintType.exact,
        VersionConstraintType.range,
        VersionConstraintType.caret,
        VersionConstraintType.tilde,
        VersionConstraintType.any,
      ]));
    });
  });

  // ===========================================================================
  // ProfileVersion
  // ===========================================================================

  group('ProfileVersion', () {
    test('parse "1.2.3" extracts major, minor, patch', () {
      final v = ProfileVersion.parse('1.2.3');
      expect(v.major, equals(1));
      expect(v.minor, equals(2));
      expect(v.patch, equals(3));
      expect(v.preReleaseType, isNull);
      expect(v.preReleaseNumber, isNull);
    });

    test('parse "1.0.0-alpha.1" extracts prerelease', () {
      final v = ProfileVersion.parse('1.0.0-alpha.1');
      expect(v.major, equals(1));
      expect(v.minor, equals(0));
      expect(v.patch, equals(0));
      expect(v.preReleaseType, equals('alpha'));
      expect(v.preReleaseNumber, equals(1));
    });

    test('toString round-trips "1.2.3"', () {
      final v = ProfileVersion.parse('1.2.3');
      expect(v.toString(), equals('1.2.3'));
    });

    test('toString round-trips "1.0.0-alpha.1"', () {
      final v = ProfileVersion.parse('1.0.0-alpha.1');
      expect(v.toString(), equals('1.0.0-alpha.1'));
    });
  });

  // ===========================================================================
  // VersionCompatibility
  // ===========================================================================

  group('VersionCompatibility', () {
    test('creation with fields', () {
      const compat = VersionCompatibility(
        minSchemaVersion: '1.0.0',
        backwardCompatibleWith: ['0.9.0'],
        forwardCompatibleWith: ['2.0.0'],
      );
      expect(compat.minSchemaVersion, equals('1.0.0'));
      expect(compat.backwardCompatibleWith, equals(['0.9.0']));
      expect(compat.forwardCompatibleWith, equals(['2.0.0']));
    });
  });

  // ===========================================================================
  // MigrationInfo
  // ===========================================================================

  group('MigrationInfo', () {
    test('creation with fields', () {
      const info = MigrationInfo(
        fromVersion: '1.0.0',
        migrationScript: 'migrate_v1_to_v2.dart',
        breaking: true,
        notes: 'Major schema overhaul',
      );
      expect(info.fromVersion, equals('1.0.0'));
      expect(info.migrationScript, equals('migrate_v1_to_v2.dart'));
      expect(info.breaking, isTrue);
      expect(info.notes, equals('Major schema overhaul'));
    });
  });

  // ===========================================================================
  // VersionConstraint.parse
  // ===========================================================================

  group('VersionConstraint.parse', () {
    test('exact "1.2.3"', () {
      final c = VersionConstraint.parse('1.2.3');
      expect(c.range, equals('1.2.3'));
      expect(c.parsed.type, equals(VersionConstraintType.exact));
    });

    test('range ">=1.0.0 <2.0.0"', () {
      final c = VersionConstraint.parse('>=1.0.0 <2.0.0');
      expect(c.parsed.type, equals(VersionConstraintType.range));
      expect(c.parsed.min, isNotNull);
      expect(c.parsed.min!.major, equals(1));
      expect(c.parsed.min!.minor, equals(0));
      expect(c.parsed.max, isNotNull);
      expect(c.parsed.max!.major, equals(2));
      expect(c.parsed.inclusiveMin, isTrue);
      expect(c.parsed.inclusiveMax, isFalse);
    });

    test('caret "^1.2.0"', () {
      final c = VersionConstraint.parse('^1.2.0');
      expect(c.parsed.type, equals(VersionConstraintType.caret));
      expect(c.parsed.min, isNotNull);
      expect(c.parsed.min!.major, equals(1));
      expect(c.parsed.min!.minor, equals(2));
    });

    test('tilde "~1.2.0"', () {
      final c = VersionConstraint.parse('~1.2.0');
      expect(c.parsed.type, equals(VersionConstraintType.tilde));
      expect(c.parsed.min, isNotNull);
      expect(c.parsed.min!.major, equals(1));
      expect(c.parsed.min!.minor, equals(2));
    });

    test('any "*"', () {
      final c = VersionConstraint.parse('*');
      expect(c.parsed.type, equals(VersionConstraintType.any));
    });
  });

  // ===========================================================================
  // ProfileVersionResolver
  // ===========================================================================

  group('ProfileVersionResolver', () {
    const resolver = ProfileVersionResolver();

    test('resolve picks latest published', () {
      final versions = [
        const VersionedProfile(
          version: '1.0.0',
          status: ProfileVersionStatus.published,
        ),
        const VersionedProfile(
          version: '1.1.0',
          status: ProfileVersionStatus.published,
        ),
        const VersionedProfile(
          version: '1.2.0',
          status: ProfileVersionStatus.published,
        ),
      ];
      final result = resolver.resolve(versions, null);
      expect(result, equals('1.2.0'));
    });

    test('resolve filters out archived and deleted', () {
      final versions = [
        const VersionedProfile(
          version: '1.0.0',
          status: ProfileVersionStatus.published,
        ),
        const VersionedProfile(
          version: '2.0.0',
          status: ProfileVersionStatus.archived,
        ),
        const VersionedProfile(
          version: '3.0.0',
          status: ProfileVersionStatus.deleted,
        ),
      ];
      final result = resolver.resolve(versions, null);
      expect(result, equals('1.0.0'));
    });

    test('resolve respects constraints', () {
      final versions = [
        const VersionedProfile(
          version: '1.0.0',
          status: ProfileVersionStatus.published,
        ),
        const VersionedProfile(
          version: '1.5.0',
          status: ProfileVersionStatus.published,
        ),
        const VersionedProfile(
          version: '2.0.0',
          status: ProfileVersionStatus.published,
        ),
      ];
      final constraint = VersionConstraint.parse('^1.0.0');
      final result = resolver.resolve(versions, constraint);
      expect(result, equals('1.5.0'));
    });

    test('resolve returns null for empty list', () {
      final result = resolver.resolve([], null);
      expect(result, isNull);
    });

    test('resolve throws VersionConstraintException when no match', () {
      final versions = [
        const VersionedProfile(
          version: '2.0.0',
          status: ProfileVersionStatus.published,
        ),
      ];
      final constraint = VersionConstraint.parse('^1.0.0');
      expect(
        () => resolver.resolve(versions, constraint),
        throwsA(isA<VersionConstraintException>()),
      );
    });
  });

  // ===========================================================================
  // satisfiesConstraint
  // ===========================================================================

  group('ProfileVersionResolver.satisfiesConstraint', () {
    const resolver = ProfileVersionResolver();

    test('caret satisfies same major', () {
      final constraint = VersionConstraint.parse('^1.2.0');
      expect(resolver.satisfiesConstraint('1.2.0', constraint), isTrue);
      expect(resolver.satisfiesConstraint('1.3.0', constraint), isTrue);
      expect(resolver.satisfiesConstraint('1.9.9', constraint), isTrue);
      expect(resolver.satisfiesConstraint('2.0.0', constraint), isFalse);
      expect(resolver.satisfiesConstraint('1.1.0', constraint), isFalse);
    });

    test('tilde satisfies same major and minor', () {
      final constraint = VersionConstraint.parse('~1.2.0');
      expect(resolver.satisfiesConstraint('1.2.0', constraint), isTrue);
      expect(resolver.satisfiesConstraint('1.2.5', constraint), isTrue);
      expect(resolver.satisfiesConstraint('1.3.0', constraint), isFalse);
      expect(resolver.satisfiesConstraint('2.0.0', constraint), isFalse);
    });

    test('range satisfies within bounds', () {
      final constraint = VersionConstraint.parse('>=1.0.0 <2.0.0');
      expect(resolver.satisfiesConstraint('1.0.0', constraint), isTrue);
      expect(resolver.satisfiesConstraint('1.5.0', constraint), isTrue);
      expect(resolver.satisfiesConstraint('1.9.9', constraint), isTrue);
      expect(resolver.satisfiesConstraint('2.0.0', constraint), isFalse);
      expect(resolver.satisfiesConstraint('0.9.0', constraint), isFalse);
    });

    test('any satisfies all versions', () {
      final constraint = VersionConstraint.parse('*');
      expect(resolver.satisfiesConstraint('0.0.1', constraint), isTrue);
      expect(resolver.satisfiesConstraint('1.0.0', constraint), isTrue);
      expect(resolver.satisfiesConstraint('99.99.99', constraint), isTrue);
    });
  });

  // ===========================================================================
  // compareVersions
  // ===========================================================================

  group('ProfileVersionResolver.compareVersions', () {
    const resolver = ProfileVersionResolver();

    test('major dominates minor and patch', () {
      expect(resolver.compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(resolver.compareVersions('1.0.0', '2.0.0'), lessThan(0));
    });

    test('minor dominates patch', () {
      expect(resolver.compareVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(resolver.compareVersions('1.1.0', '1.2.0'), lessThan(0));
    });

    test('patch comparison', () {
      expect(resolver.compareVersions('1.0.2', '1.0.1'), greaterThan(0));
      expect(resolver.compareVersions('1.0.1', '1.0.2'), lessThan(0));
    });

    test('pre-release is less than release', () {
      expect(
        resolver.compareVersions('1.0.0-alpha.1', '1.0.0'),
        lessThan(0),
      );
      expect(
        resolver.compareVersions('1.0.0', '1.0.0-rc.1'),
        greaterThan(0),
      );
    });

    test('alpha < beta < rc', () {
      expect(
        resolver.compareVersions('1.0.0-alpha.1', '1.0.0-beta.1'),
        lessThan(0),
      );
      expect(
        resolver.compareVersions('1.0.0-beta.1', '1.0.0-rc.1'),
        lessThan(0),
      );
      expect(
        resolver.compareVersions('1.0.0-alpha.1', '1.0.0-rc.1'),
        lessThan(0),
      );
    });

    test('equal versions return zero', () {
      expect(resolver.compareVersions('1.0.0', '1.0.0'), equals(0));
      expect(
        resolver.compareVersions('1.0.0-alpha.1', '1.0.0-alpha.1'),
        equals(0),
      );
    });

    test('two identical pre-release versions return zero', () {
      expect(
        resolver.compareVersions('2.1.0-beta.3', '2.1.0-beta.3'),
        equals(0),
      );
      expect(
        resolver.compareVersions('1.0.0-rc.2', '1.0.0-rc.2'),
        equals(0),
      );
    });
  });

  // ===========================================================================
  // _satisfiesRange edge case min==max
  // ===========================================================================
  group('ProfileVersionResolver._satisfiesRange edge cases', () {
    const resolver = ProfileVersionResolver();

    test('range with inclusive min==max matches exact version', () {
      // >=1.5.0 <=1.5.0 is effectively an exact match
      final constraint = VersionConstraint.parse('>=1.5.0 <=1.5.0');
      expect(resolver.satisfiesConstraint('1.5.0', constraint), isTrue);
      expect(resolver.satisfiesConstraint('1.4.9', constraint), isFalse);
      expect(resolver.satisfiesConstraint('1.5.1', constraint), isFalse);
    });

    test('range with exclusive min==max matches nothing', () {
      // >1.5.0 <1.5.0 is impossible to satisfy
      final constraint = VersionConstraint.parse('>1.5.0 <1.5.0');
      expect(resolver.satisfiesConstraint('1.5.0', constraint), isFalse);
      expect(resolver.satisfiesConstraint('1.4.9', constraint), isFalse);
      expect(resolver.satisfiesConstraint('1.5.1', constraint), isFalse);
    });
  });

  // ===========================================================================
  // VersionConstraintException
  // ===========================================================================

  group('VersionConstraintException', () {
    test('toString includes constraint and available versions', () {
      final constraint = VersionConstraint.parse('^3.0.0');
      final exception = VersionConstraintException(
        constraint: constraint,
        availableVersions: ['1.0.0', '2.0.0'],
      );
      final str = exception.toString();
      expect(str, contains('VersionConstraintException'));
      expect(str, contains('^3.0.0'));
      expect(str, contains('1.0.0'));
      expect(str, contains('2.0.0'));
    });
  });

  // ===========================================================================
  // ProfileMigration
  // ===========================================================================

  group('ProfileMigration', () {
    test('creation with fields', () {
      final migration = ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        transform: (data) => {...data, 'version': '2.0.0'},
        breaking: true,
        notes: 'Major upgrade',
      );
      expect(migration.fromVersion, equals('1.0.0'));
      expect(migration.toVersion, equals('2.0.0'));
      expect(migration.breaking, isTrue);
      expect(migration.notes, equals('Major upgrade'));
    });
  });

  // ===========================================================================
  // MigrationStep
  // ===========================================================================

  group('MigrationStep', () {
    test('creation with fields', () {
      final migration = ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        transform: (data) => data,
      );
      final step = MigrationStep(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        migration: migration,
      );
      expect(step.fromVersion, equals('1.0.0'));
      expect(step.toVersion, equals('1.1.0'));
      expect(step.migration.fromVersion, equals('1.0.0'));
    });
  });

  // ===========================================================================
  // MigrationResult
  // ===========================================================================

  group('MigrationResult', () {
    test('creation with fields', () {
      const result = MigrationResult(
        profileId: 'p1',
        fromVersion: '1.0.0',
        targetVersion: '2.0.0',
        success: true,
        migratedData: {'key': 'value'},
      );
      expect(result.profileId, equals('p1'));
      expect(result.fromVersion, equals('1.0.0'));
      expect(result.targetVersion, equals('2.0.0'));
      expect(result.success, isTrue);
      expect(result.migratedData, equals({'key': 'value'}));
      expect(result.steps, isEmpty);
      expect(result.error, isNull);
    });
  });

  // ===========================================================================
  // StepMigrationResult
  // ===========================================================================

  group('StepMigrationResult', () {
    test('creation with fields', () {
      final migration = ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        transform: (data) => data,
      );
      final step = MigrationStep(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        migration: migration,
      );
      final result = StepMigrationResult(
        step: step,
        success: true,
        migratedData: {'migrated': true},
      );
      expect(result.step.fromVersion, equals('1.0.0'));
      expect(result.success, isTrue);
      expect(result.migratedData, equals({'migrated': true}));
      expect(result.error, isNull);
    });
  });

  // ===========================================================================
  // ProfileVersionMigrator
  // ===========================================================================

  group('ProfileVersionMigrator', () {
    test('register adds migration', () {
      final migrator = ProfileVersionMigrator();
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        transform: (data) => {...data, 'v': '1.1.0'},
      ));

      final path = migrator.buildMigrationPath('1.0.0', '1.1.0');
      expect(path.length, equals(1));
      expect(path.first.fromVersion, equals('1.0.0'));
      expect(path.first.toVersion, equals('1.1.0'));
    });

    test('migrate success path', () async {
      final migrator = ProfileVersionMigrator();
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        transform: (data) => {...data, 'upgraded': true},
      ));

      final result = await migrator.migrate(
        'p1',
        {'name': 'test'},
        '1.0.0',
        '2.0.0',
      );
      expect(result.success, isTrue);
      expect(result.migratedData!['upgraded'], isTrue);
      expect(result.migratedData!['name'], equals('test'));
      expect(result.steps.length, equals(1));
    });

    test('migrate multi-step path', () async {
      final migrator = ProfileVersionMigrator();
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        transform: (data) => {...data, 'step1': true},
      ));
      migrator.register(ProfileMigration(
        fromVersion: '1.1.0',
        toVersion: '2.0.0',
        transform: (data) => {...data, 'step2': true},
      ));

      final result = await migrator.migrate(
        'p1',
        {'name': 'test'},
        '1.0.0',
        '2.0.0',
      );
      expect(result.success, isTrue);
      expect(result.steps.length, equals(2));
      expect(result.migratedData!['step1'], isTrue);
      expect(result.migratedData!['step2'], isTrue);
    });

    test('buildMigrationPath uses BFS', () {
      final migrator = ProfileVersionMigrator();
      // Direct path: 1.0.0 -> 3.0.0
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '3.0.0',
        transform: (data) => data,
      ));
      // Indirect path: 1.0.0 -> 2.0.0 -> 3.0.0
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        transform: (data) => data,
      ));
      migrator.register(ProfileMigration(
        fromVersion: '2.0.0',
        toVersion: '3.0.0',
        transform: (data) => data,
      ));

      // BFS should find the direct (shortest) path
      final path = migrator.buildMigrationPath('1.0.0', '3.0.0');
      expect(path.length, equals(1));
      expect(path.first.fromVersion, equals('1.0.0'));
      expect(path.first.toVersion, equals('3.0.0'));
    });

    test('no path throws NoMigrationPathException', () async {
      final migrator = ProfileVersionMigrator();
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        transform: (data) => data,
      ));

      expect(
        () => migrator.migrate('p1', {}, '1.0.0', '5.0.0'),
        throwsA(isA<NoMigrationPathException>()),
      );
    });

    test('script-based migration with mock MigrationScriptRunner', () async {
      final scriptRunner = _MockScriptRunner();
      final migrator = ProfileVersionMigrator(scriptRunner: scriptRunner);
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        transform: (data) => data,
        migrationScript: 'v1_to_v2.dart',
      ));

      final result = await migrator.migrate(
        'p1',
        {'name': 'test'},
        '1.0.0',
        '2.0.0',
      );
      expect(result.success, isTrue);
      expect(result.migratedData!['migrated_by'], equals('v1_to_v2.dart'));
      expect(result.migratedData!['name'], equals('test'));
    });

    test('same version migration returns unchanged data', () async {
      final migrator = ProfileVersionMigrator();
      final result = await migrator.migrate(
        'p1',
        {'key': 'value'},
        '1.0.0',
        '1.0.0',
      );
      expect(result.success, isTrue);
      expect(result.steps, isEmpty);
    });
  });

  // ===========================================================================
  // Exceptions
  // ===========================================================================

  group('NoMigrationPathException', () {
    test('toString includes version info', () {
      const exception = NoMigrationPathException('p1', '1.0.0', '5.0.0');
      final str = exception.toString();
      expect(str, contains('NoMigrationPathException'));
      expect(str, contains('1.0.0'));
      expect(str, contains('5.0.0'));
      expect(str, contains('p1'));
    });
  });

  group('MigrationScriptRequiredException', () {
    test('toString includes step version info', () {
      final migration = ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        transform: (data) => data,
        breaking: true,
        migrationScript: 'script.dart',
      );
      final step = MigrationStep(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        migration: migration,
      );
      final exception = MigrationScriptRequiredException(step);
      final str = exception.toString();
      expect(str, contains('MigrationScriptRequiredException'));
      expect(str, contains('1.0.0'));
      expect(str, contains('2.0.0'));
    });
  });

  // ===========================================================================
  // ProfileVersionMigrator — additional coverage
  // ===========================================================================

  group('ProfileVersionMigrator (additional coverage)', () {
    test('breaking migration with script but no runner throws MigrationScriptRequiredException',
        () async {
      // No scriptRunner provided to the migrator
      final migrator = ProfileVersionMigrator();
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        transform: (data) => {...data, 'upgraded': true},
        breaking: true,
        migrationScript: 'v1_to_v2.dart',
      ));

      expect(
        () => migrator.migrate('p1', {'name': 'test'}, '1.0.0', '2.0.0'),
        throwsA(isA<MigrationScriptRequiredException>()),
      );
    });

    test('transform that throws produces error in StepMigrationResult',
        () async {
      final migrator = ProfileVersionMigrator();
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        transform: (data) {
          throw FormatException('Invalid data format');
        },
      ));

      final result = await migrator.migrate(
        'p1',
        {'name': 'test'},
        '1.0.0',
        '1.1.0',
      );

      expect(result.success, isFalse);
      expect(result.steps.length, equals(1));
      expect(result.steps.first.success, isFalse);
      expect(result.steps.first.error, isNotNull);
      expect(result.steps.first.error, contains('Invalid data format'));
      expect(result.error, contains('Invalid data format'));
    });

    test('same-version migration is a no-op with success and returns data',
        () async {
      final migrator = ProfileVersionMigrator();
      // Register some migration, but it should not be invoked
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        transform: (data) => {...data, 'upgraded': true},
      ));

      final result = await migrator.migrate(
        'p1',
        {'key': 'value'},
        '1.0.0',
        '1.0.0',
      );

      expect(result.success, isTrue);
      expect(result.steps, isEmpty);
      expect(result.migratedData, equals({'key': 'value'}));
    });

    test('breaking migration without script applies transform', () async {
      final migrator = ProfileVersionMigrator();
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '2.0.0',
        transform: (data) => {...data, 'breaking_applied': true},
        breaking: true,
        // No migrationScript, so it falls through to apply transform
      ));

      final result = await migrator.migrate(
        'p1',
        {'name': 'test'},
        '1.0.0',
        '2.0.0',
      );

      expect(result.success, isTrue);
      expect(result.migratedData!['breaking_applied'], isTrue);
      expect(result.migratedData!['name'], equals('test'));
    });

    test('multi-step migration where second step fails', () async {
      final migrator = ProfileVersionMigrator();
      migrator.register(ProfileMigration(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
        transform: (data) => {...data, 'step1': true},
      ));
      migrator.register(ProfileMigration(
        fromVersion: '1.1.0',
        toVersion: '2.0.0',
        transform: (data) {
          throw StateError('migration failed');
        },
      ));

      final result = await migrator.migrate(
        'p1',
        {'name': 'test'},
        '1.0.0',
        '2.0.0',
      );

      expect(result.success, isFalse);
      expect(result.steps.length, equals(2));
      expect(result.steps[0].success, isTrue);
      expect(result.steps[1].success, isFalse);
      expect(result.steps[1].error, contains('migration failed'));
    });
  });
}
