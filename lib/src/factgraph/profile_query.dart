/// Profile Query - Query builder for profile history lookups.
///
/// Internal query descriptor used by the feat-factgraph integration.
/// Concrete queries are issued through the capability-named ports
/// (`FactsPort`/`PatternsPort`/`SummariesPort`) at execution time.
library;

import 'profile_run.dart';

// =============================================================================
// DateTimeRange
// =============================================================================

/// A time range with start and end.
class DateTimeRange {
  /// Start of the range (inclusive).
  final DateTime start;

  /// End of the range (exclusive).
  final DateTime end;

  const DateTimeRange({required this.start, required this.end});

  /// Duration of the range.
  Duration get duration => end.difference(start);
}

// =============================================================================
// ProfileQueryCriteria (§9)
// =============================================================================

/// Criteria for querying profile history.
class ProfileQueryCriteria {
  /// Filter by profile ID.
  final String? profileId;

  /// Filter by profile version.
  final String? profileVersion;

  /// Filter by context ID.
  final String? contextId;

  /// Filter by time range.
  final DateTimeRange? timeRange;

  /// Filter by run status.
  final ProfileRunStatus? status;

  /// Filter by minimum aggregated score.
  final double? minScore;

  /// Filter by maximum aggregated score.
  final double? maxScore;

  /// Sort field.
  final String sortBy;

  /// Sort direction.
  final bool ascending;

  /// Maximum results.
  final int limit;

  /// Offset for pagination.
  final int offset;

  const ProfileQueryCriteria({
    this.profileId,
    this.profileVersion,
    this.contextId,
    this.timeRange,
    this.status,
    this.minScore,
    this.maxScore,
    this.sortBy = 'startedAt',
    this.ascending = false,
    this.limit = 100,
    this.offset = 0,
  });
}

// =============================================================================
// MetricTrendAnalysis (§9)
// =============================================================================

/// Analysis of metric trends over time.
class MetricTrendAnalysis {
  /// Metric identifier.
  final String metricId;

  /// Metric values over time.
  final List<double> values;

  /// Mean value.
  final double mean;

  /// Standard deviation.
  final double stddev;

  /// Trend direction: positive (increasing), negative (decreasing), flat.
  final TrendDirection trend;

  const MetricTrendAnalysis({
    required this.metricId,
    required this.values,
    required this.mean,
    required this.stddev,
    required this.trend,
  });
}

/// Trend direction for metric analysis.
enum TrendDirection {
  /// Metric is increasing over time.
  increasing,

  /// Metric is decreasing over time.
  decreasing,

  /// Metric is relatively stable.
  stable,
}

// =============================================================================
// ProfileQueryPort (§9)
// =============================================================================

/// Port for querying profile history.
///
/// A capability-specific abstract port for full graph traversal,
/// distinct from the capability-named `FactsPort` used for metric
/// sourcing. Implementations live outside mcp_profile.
abstract class ProfileQueryPort {
  /// Query profile runs matching criteria.
  Future<List<ProfileRun>> queryProfileRuns(ProfileQueryCriteria criteria);

  /// Find similar profile applications.
  Future<List<ProfileRun>> findSimilarApplications({
    required String profileId,
    required double minScoreSimilarity,
    DateTimeRange? timeRange,
    int limit = 10,
  });

  /// Analyze metric trends over time.
  Future<MetricTrendAnalysis> analyzeMetricTrends({
    required String profileId,
    required String metricId,
    required DateTimeRange timeRange,
  });

  /// Find profiles associated with a pattern.
  ///
  /// Per design/07-factgraph-integration.md §9: resolves
  /// pattern references to find related profile runs.
  Future<List<ProfileRun>> findProfilesFromPattern({
    required String patternId,
    DateTimeRange? timeRange,
    int limit = 10,
  });
}

// =============================================================================
// StubProfileQueryPort
// =============================================================================

/// Stub implementation for testing.
class StubProfileQueryPort implements ProfileQueryPort {
  const StubProfileQueryPort();

  @override
  Future<List<ProfileRun>> queryProfileRuns(
    ProfileQueryCriteria criteria,
  ) async {
    return [];
  }

  @override
  Future<List<ProfileRun>> findSimilarApplications({
    required String profileId,
    required double minScoreSimilarity,
    DateTimeRange? timeRange,
    int limit = 10,
  }) async {
    return [];
  }

  @override
  Future<MetricTrendAnalysis> analyzeMetricTrends({
    required String profileId,
    required String metricId,
    required DateTimeRange timeRange,
  }) async {
    return MetricTrendAnalysis(
      metricId: metricId,
      values: const [],
      mean: 0.0,
      stddev: 0.0,
      trend: TrendDirection.stable,
    );
  }

  @override
  Future<List<ProfileRun>> findProfilesFromPattern({
    required String patternId,
    DateTimeRange? timeRange,
    int limit = 10,
  }) async {
    return [];
  }
}
