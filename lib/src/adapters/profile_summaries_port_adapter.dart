/// ProfileSummariesPortAdapter - Implements mcp_bundle's
/// [ProfileSummariesPort].
///
/// 0.2.0 per docs/03_DDD/core-adapters.md §3.5.
///
/// Aggregates appraisal output across all registered profiles for a given
/// entity and returns a [ProfileSummaryResult]. Distinct from
/// `SummariesPort` (fact-level) — this is the evaluation-level summary.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;

import '../registry/profile_registry.dart';
import '../runtime/profile_runtime.dart';
import '../runtime/runtime_context.dart';

/// Adapter implementing [bundle.ProfileSummariesPort].
class ProfileSummariesPortAdapter implements bundle.ProfileSummariesPort {
  final ProfileRuntime _runtime;
  final ProfileRegistry _registry;

  ProfileSummariesPortAdapter({
    required ProfileRuntime runtime,
    required ProfileRegistry registry,
  })  : _runtime = runtime,
        _registry = registry;

  @override
  Future<bundle.ProfileSummaryResult?> getProfileSummary(
    String entityId, {
    bundle.Period? period,
  }) async {
    final profiles = _registry.all;
    if (profiles.isEmpty) return null;

    final dimensionScores = <String, double>{};
    var totalScore = 0.0;
    var runCount = 0;
    DateTime? lastAt;
    final narrativeParts = <String>[];

    for (final profile in profiles) {
      final section = profile.getAppraisalSection();
      if (section == null || section.metrics.isEmpty) continue;
      final context = DefaultRuntimeContext(
        profileId: profile.id,
        entityId: entityId,
        inputs: const {},
        period: period,
      );
      final result = await _runtime.apply(context);
      for (final entry in result.appraisal.metrics.entries) {
        dimensionScores[entry.key] = entry.value.normalizedValue;
      }
      totalScore += result.appraisal.aggregatedScore;
      runCount += 1;
      lastAt = result.metadata.completedAt;
      narrativeParts.add(
        '${profile.name} (${profile.id}): score=${result.appraisal.aggregatedScore.toStringAsFixed(2)}',
      );
    }

    if (runCount == 0) return null;

    return bundle.ProfileSummaryResult(
      entityId: entityId,
      narrative: narrativeParts.join(' | '),
      dimensionScores: dimensionScores,
      confidence: runCount > 0 ? totalScore / runCount : 0.0,
      period: period,
      generatedAt: lastAt ?? DateTime.now(),
    );
  }
}
