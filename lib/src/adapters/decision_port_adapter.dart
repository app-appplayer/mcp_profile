/// DecisionPortAdapter - Implements mcp_bundle's [DecisionPort].
///
/// 0.2.0 per docs/03_DDD/core-adapters.md §3.3.
///
/// The `policy` argument is a **profile id** (per mcp_bundle contract).
/// The adapter loads the profile, builds a runtime context from the
/// opaque `context` map, and runs the full apply pipeline, returning
/// the guidance portion.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;

import '../registry/profile_registry.dart';
import '../runtime/profile_runtime.dart';
import '../runtime/runtime_context.dart';

/// Adapter implementing [bundle.DecisionPort].
class DecisionPortAdapter implements bundle.DecisionPort {
  final ProfileRuntime _runtime;
  final ProfileRegistry _registry;

  DecisionPortAdapter({
    required ProfileRuntime runtime,
    required ProfileRegistry registry,
  })  : _runtime = runtime,
        _registry = registry;

  @override
  Future<bundle.DecisionGuidance> decide(
    String policy,
    Map<String, dynamic> context,
  ) async {
    final profile = _registry.get(policy);
    if (profile == null) {
      throw ProfileNotFoundException(policy);
    }
    final runtimeContext = DefaultRuntimeContext(
      profileId: policy,
      entityId: context['entityId'] as String? ?? 'default',
      inputs: context,
    );
    final result = await _runtime.apply(
      runtimeContext,
      rawContent: context['rawContent'] as String?,
    );
    return result.decision;
  }
}
