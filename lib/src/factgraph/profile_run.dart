/// Profile Run Entity - Persisted profile evaluation run per design/07-factgraph-integration.md §3.
///
/// Represents a completed profile evaluation run that can be
/// persisted to FactGraph as an L3 entity.
library;

import '../decision/decision_guidance.dart';
import '../expression/expression_style.dart';

// =============================================================================
// ProfileRunStatus (§3)
// =============================================================================

/// Status of a profile evaluation run.
enum ProfileRunStatus {
  /// Run completed successfully.
  completed,

  /// Run failed during evaluation.
  failed,

  /// Run exceeded time limit.
  timedOut,
}

// =============================================================================
// ProfileRun (§3)
// =============================================================================

/// Profile evaluation run entity for persistence.
class ProfileRun {
  /// Unique run identifier.
  final String runId;

  /// Profile that was evaluated.
  final String profileId;

  /// Profile version used.
  final String profileVersion;

  /// Context ID for this execution.
  final String contextId;

  /// When the run started.
  final DateTime startedAt;

  /// When the run completed.
  final DateTime completedAt;

  /// Run status.
  final ProfileRunStatus status;

  /// Computed metric values (normalized).
  final Map<String, double> metricValues;

  /// Aggregated score.
  final double aggregatedScore;

  /// Decision guidance produced.
  final DecisionGuidance decision;

  /// Expression style applied (if any).
  final ExpressionStyle? expression;

  /// References to supporting evidence.
  final List<String> evidenceRefs;

  /// Linked SkillRun ID (if evaluated during a skill execution).
  final String? skillRunId;

  /// Audit metadata.
  final Map<String, dynamic> metadata;

  /// When this entity was created.
  final DateTime createdAt;

  ProfileRun({
    required this.runId,
    required this.profileId,
    required this.profileVersion,
    required this.contextId,
    required this.startedAt,
    required this.completedAt,
    required this.status,
    required this.metricValues,
    required this.aggregatedScore,
    required this.decision,
    this.expression,
    required this.evidenceRefs,
    this.skillRunId,
    this.metadata = const {},
    required this.createdAt,
  });

  /// Duration of the run.
  Duration get duration => completedAt.difference(startedAt);

  /// Whether the run was successful.
  bool get isSuccess => status == ProfileRunStatus.completed;
}
