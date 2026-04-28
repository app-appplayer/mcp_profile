/// AppraisalPortAdapter - Implements mcp_bundle's [AppraisalPort].
///
/// 0.2.0 per docs/03_DDD/core-adapters.md §3.2.
///
/// Bridges the simple `appraise(dimensions, context)` / `getHistory`
/// contract to the rich internal [ProfileRuntime] appraisal pipeline.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;

import '../registry/profile_registry.dart';
import '../runtime/profile_runtime.dart';
import '../runtime/runtime_context.dart';

/// Adapter implementing [bundle.AppraisalPort].
class AppraisalPortAdapter implements bundle.AppraisalPort {
  final ProfileRuntime _runtime;
  final ProfileRegistry _registry;

  AppraisalPortAdapter({
    required ProfileRuntime runtime,
    required ProfileRegistry registry,
  })  : _runtime = runtime,
        _registry = registry;

  @override
  Future<bundle.AppraisalResult> appraise(
    List<String> dimensions,
    Map<String, dynamic> context,
  ) async {
    final profileId = _resolveProfileId(dimensions, context);
    if (profileId == null) {
      return bundle.AppraisalResult.empty(
        profileId: context['profileId'] as String? ?? 'unknown',
      );
    }
    final runtimeContext = DefaultRuntimeContext(
      profileId: profileId,
      entityId: context['entityId'] as String? ?? 'default',
      inputs: context,
      metadata: {'requestedDimensions': dimensions},
    );
    final result = await _runtime.appraise(runtimeContext);

    // Filter metrics to the requested dimensions (when supplied). Empty
    // dimensions means "return whatever the profile produced".
    if (dimensions.isEmpty) return result;
    final filtered = <String, bundle.MetricResult>{};
    for (final dim in dimensions) {
      final m = result.metrics[dim];
      if (m != null) filtered[dim] = m;
    }
    return bundle.AppraisalResult(
      profileId: result.profileId,
      contextId: result.contextId,
      asOf: result.asOf,
      metrics: filtered,
      aggregatedScore: result.aggregatedScore,
      metadata: result.metadata,
    );
  }

  @override
  Future<List<bundle.AppraisalResult>> getHistory(
    String profileId,
    bundle.Period period,
  ) async {
    // Delegate to the internal appraisal engine contract when available.
    // The runtime exposes history via its engines container.
    try {
      return await _runtime.engines.appraisal.getHistory(profileId, period);
    } on UnsupportedError {
      return const [];
    }
  }

  /// Find the profile id that should be used for appraisal.
  ///
  /// Resolution order:
  ///   1. Explicit `context['profileId']` when present.
  ///   2. First registered profile that declares any of [dimensions] in
  ///      its appraisal section.
  ///   3. null — caller receives an empty result.
  String? _resolveProfileId(
    List<String> dimensions,
    Map<String, dynamic> context,
  ) {
    final explicit = context['profileId'];
    if (explicit is String && explicit.isNotEmpty) return explicit;
    if (dimensions.isEmpty) return null;
    final wanted = dimensions.toSet();
    for (final profile in _registry.all) {
      final section = profile.getAppraisalSection();
      if (section == null) continue;
      for (final metric in section.metrics) {
        if (wanted.contains(metric.id)) return profile.id;
      }
    }
    return null;
  }
}
