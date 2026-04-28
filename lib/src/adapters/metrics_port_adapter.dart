/// MetricsPortAdapter - Implements mcp_bundle's [MetricsPort].
///
/// 0.2.0 per docs/03_DDD/core-adapters.md §3.1.
///
/// Delegates to [ProfileRuntime] + [ProfileRegistry]. For each requested
/// metric:
///   1. Resolve the owning profile from the registry (scan metric ids).
///   2. Build a [DefaultRuntimeContext] for the entity/period.
///   3. Run `runtime.appraise` and return the matching [MetricResult].
///
/// `computeMetric` performs an on-demand computation by constructing a
/// synthetic profile section from the [MetricSpec].
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;

import '../registry/profile_registry.dart';
import '../runtime/profile_runtime.dart';
import '../runtime/runtime_context.dart';

/// Adapter implementing [bundle.MetricsPort].
class MetricsPortAdapter implements bundle.MetricsPort {
  final ProfileRuntime _runtime;
  final ProfileRegistry _registry;

  MetricsPortAdapter({
    required ProfileRuntime runtime,
    required ProfileRegistry registry,
  })  : _runtime = runtime,
        _registry = registry;

  @override
  Future<bundle.MetricResult?> getMetric(
    String name,
    String entityId, {
    bundle.Period? period,
  }) async {
    final results = await getMetrics([name], entityId, period: period);
    return results[name];
  }

  @override
  Future<Map<String, bundle.MetricResult>> getMetrics(
    List<String> names,
    String entityId, {
    bundle.Period? period,
  }) async {
    if (names.isEmpty) return const {};
    final owningProfileId = _findOwningProfile(names);
    if (owningProfileId == null) return const {};

    final context = DefaultRuntimeContext(
      profileId: owningProfileId,
      entityId: entityId,
      inputs: const {},
      period: period,
    );
    final appraisal = await _runtime.appraise(context);
    final matched = <String, bundle.MetricResult>{};
    for (final name in names) {
      final result = appraisal.metrics[name];
      if (result != null) matched[name] = result;
    }
    return matched;
  }

  @override
  Future<bundle.MetricResult> computeMetric(bundle.MetricSpec spec) async {
    // Look up the metric definition across all registered profiles by id.
    // If present, route through `runtime.appraise` to honour the metric's
    // source (FactGraph / computed / LLM-derived / static). If the metric
    // is unknown, return a low-confidence static result so the port
    // contract never throws.
    final owningProfileId = _findOwningProfile([spec.id]);
    if (owningProfileId == null) {
      return bundle.MetricResult(
        id: spec.id,
        normalizedValue: 0.5,
        sourceType: bundle.MetricSourceType.static_,
        confidence: 0.2,
      );
    }
    final context = DefaultRuntimeContext(
      profileId: owningProfileId,
      entityId: spec.entityId,
      inputs: spec.parameters ?? const {},
      period: spec.period,
    );
    final appraisal = await _runtime.appraise(context);
    final result = appraisal.metrics[spec.id];
    return result ??
        bundle.MetricResult(
          id: spec.id,
          normalizedValue: 0.5,
          sourceType: bundle.MetricSourceType.computed,
          confidence: 0.3,
        );
  }

  /// Find the first registered profile that declares any of [metricIds] in
  /// its appraisal section. Returns null when none match.
  String? _findOwningProfile(List<String> metricIds) {
    final wanted = metricIds.toSet();
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
