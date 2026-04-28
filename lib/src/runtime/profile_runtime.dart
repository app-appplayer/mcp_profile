/// Profile Runtime - Unified runtime per docs/03_DDD/core-runtime.md v0.2.0.
///
/// Implements the full profile application pipeline:
/// 1. Appraisal - Compute metrics from context
/// 2. Decision - Evaluate policies and get guidance
/// 3. Expression - Determine communication style
/// 4. Formatting - Apply style to content
library;

import '../appraisal/appraisal_result.dart';
import '../appraisal/metric_definition.dart';
import '../decision/decision_guidance.dart';
import '../decision/decision_policy.dart';
import '../definition/profile.dart';
import '../engines/appraisal_engine_port.dart';
import '../engines/engine_ports.dart';
import '../engines/expression_engine_port.dart' as engines;
import '../expression/expression_policy.dart';
import '../expression/expression_style.dart';
import '../registry/profile_registry.dart';
import 'runtime_context.dart';

// =============================================================================
// ProfileApplicationResult (§5)
// =============================================================================

/// Complete profile application result per design/03-runtime.md §5.
class ProfileApplicationResult {
  /// Profile ID that was applied.
  final String profileId;

  /// Context ID for this execution.
  final String contextId;

  /// Appraisal result with metrics.
  final AppraisalResult appraisal;

  /// Decision guidance from policy evaluation.
  final DecisionGuidance decision;

  /// Expression style determined by policies.
  final ExpressionStyle expression;

  /// Formatted response if content was provided.
  final FormattedResponse? formatted;

  /// Execution metadata.
  final ProfileApplicationMetadata metadata;

  const ProfileApplicationResult({
    required this.profileId,
    required this.contextId,
    required this.appraisal,
    required this.decision,
    required this.expression,
    this.formatted,
    required this.metadata,
  });
}

/// Metadata for profile application execution per design/03-runtime.md §5.
class ProfileApplicationMetadata {
  /// When the application started.
  final DateTime startedAt;

  /// When the application completed.
  final DateTime completedAt;

  /// Profile version used.
  final String profileVersion;

  const ProfileApplicationMetadata({
    required this.startedAt,
    required this.completedAt,
    required this.profileVersion,
  });

  /// Get execution duration.
  Duration get duration => completedAt.difference(startedAt);
}

/// Re-export FormattedResponse from expression port.
typedef FormattedResponse = engines.FormattedResponse;

// =============================================================================
// ProfileRuntime (§4)
// =============================================================================

/// Profile application runtime per docs/03_DDD/core-runtime.md v0.2.0.
///
/// Spec-compliant runtime that implements the full pipeline:
/// appraise → decision → expression → formatting. Uses [EnginePorts] for
/// delegation to the internal engine contracts defined in
/// `src/engines/`.
class ProfileRuntime {
  /// Profile registry for loading profiles.
  final ProfileRegistry registry;

  /// Engine port container — the three internal engine contracts plus the
  /// optional consumed standard ports (FactsPort/PatternsPort/
  /// SummariesPort/LlmPort).
  final EnginePorts engines;

  /// Runtime hooks.
  final List<ProfileRuntimeHook>? hooks;

  ProfileRuntime({
    required this.registry,
    required this.engines,
    this.hooks,
  });

  /// Full profile application pipeline per §4.
  ///
  /// Pipeline:
  /// 1. Load profile from registry
  /// 2. Compute appraisal metrics via AppraisalPort
  /// 3. Get decision guidance via DecisionPort
  /// 4. Get expression style via ExpressionPort
  /// 5. Format content if provided via ExpressionPort
  Future<ProfileApplicationResult> apply(
    RuntimeProfileContext context, {
    String? rawContent,
  }) async {
    final startTime = context.clock.now();

    await _callHooks('beforeApply', context);

    // 1. Load profile
    final profile = registry.get(context.profileId);
    if (profile == null) {
      throw ProfileNotFoundException(context.profileId);
    }

    // 2. Compute appraisal
    final appraisal = await appraise(context, profile: profile);
    await _callHooks('afterAppraise', context, appraisal: appraisal);

    // 3. Get decision guidance
    var decision = await getDecisionGuidance(appraisal, context, profile: profile);

    // §9.3 step 4: Add implicit require_evidence modifier for low-confidence metrics
    if (appraisal.metadata.metricsRequiringEvidence.isNotEmpty) {
      final hasEvidenceModifier =
          decision.modifiers.any((m) => m.type == ModifierType.requireEvidence);
      if (!hasEvidenceModifier) {
        decision = DecisionGuidance(
          action: decision.action,
          confidence: decision.confidence,
          explanation: decision.explanation,
          modifiers: [
            ...decision.modifiers,
            DecisionModifier.requireEvidence(
              minSources: 2,
              evidenceTypes: null,
            ),
          ],
          metadata: {
            ...?decision.metadata,
            'implicitEvidenceReason': 'Low confidence metrics: '
                '${appraisal.metadata.metricsRequiringEvidence.join(', ')}',
          },
        );
      }
    }
    await _callHooks('afterDecision', context, decision: decision);

    // 4. Get expression style
    final expression = await getExpressionStyle(appraisal, context, profile: profile);

    // 5. Format content if provided
    FormattedResponse? formatted;
    if (rawContent != null) {
      formatted = await applyExpression(rawContent, expression, context);
    }

    await _callHooks('afterApply', context);

    return ProfileApplicationResult(
      profileId: context.profileId,
      contextId: context.contextId,
      appraisal: appraisal,
      decision: decision,
      expression: expression,
      formatted: formatted,
      metadata: ProfileApplicationMetadata(
        startedAt: startTime,
        completedAt: context.clock.now(),
        profileVersion: profile.version,
      ),
    );
  }

  /// Compute appraisal metrics per §4 step 2.
  ///
  /// Uses AppraisalPort.computeMetrics() and MetricResultConverter.convertBatch()
  /// per design/02-ports.md §4.2.
  Future<AppraisalResult> appraise(
    RuntimeProfileContext context, {
    Profile? profile,
  }) async {
    profile ??= registry.get(context.profileId);
    if (profile == null) {
      throw ProfileNotFoundException(context.profileId);
    }

    // Get appraisal section from profile metadata
    final appraisalSection = profile.getAppraisalSection();
    if (appraisalSection == null) {
      // No appraisal defined, return empty result
      return AppraisalResult(
        profileId: context.profileId,
        contextId: context.contextId,
        asOf: context.asOf,
        metrics: const {},
        aggregatedScore: 1.0,
        metadata: AppraisalMetadata(
          computedAt: context.clock.now(),
        ),
      );
    }

    final startTime = context.clock.now();

    // Compute metrics using port
    final computeResults = await engines.appraisal.computeMetrics(
      appraisalSection.metrics,
      context,
    );

    // Convert MetricComputeResult -> MetricResult using batch converter
    final converted = MetricResultConverter.convertBatch(
      computeResults,
      defaultValues: {
        for (final m in appraisalSection.metrics)
          if (m.defaultValue != null) m.id: m.defaultValue!,
      },
    );

    // Compute aggregate score
    final aggregatedScore = await engines.appraisal.computeAggregate(
      computeResults,
      appraisalSection.aggregation,
    );

    return AppraisalResult(
      profileId: context.profileId,
      contextId: context.contextId,
      asOf: context.asOf,
      metrics: converted.results,
      aggregatedScore: aggregatedScore,
      metadata: AppraisalMetadata(
        computedAt: context.clock.now(),
        durationMs: context.clock.now().difference(startTime).inMilliseconds,
        lowConfidenceMetrics: converted.results.entries
            .where((e) => e.value.confidence < 0.5)
            .map((e) => e.key)
            .toList(),
        warnings: converted.warnings,
      ),
    );
  }

  /// Get decision guidance per §4 step 3.
  ///
  /// Uses DecisionPort.evaluate() per design/02-ports.md §5.
  Future<DecisionGuidance> getDecisionGuidance(
    AppraisalResult appraisal,
    RuntimeProfileContext context, {
    Profile? profile,
  }) async {
    profile ??= registry.get(context.profileId);
    if (profile == null) {
      throw ProfileNotFoundException(context.profileId);
    }

    // Get decision policies from profile metadata
    final decisionSection = profile.getDecisionSection();
    if (decisionSection == null || decisionSection.policies.isEmpty) {
      return DecisionGuidance.defaultProceed;
    }

    // Evaluate policies using port
    return engines.decision.evaluate(
      decisionSection.policies,
      appraisal,
      context,
    );
  }

  /// Get expression style per §4 step 4.
  ///
  /// Uses ExpressionPort.evaluateCondition() per design/02-ports.md §6.
  Future<ExpressionStyle> getExpressionStyle(
    AppraisalResult appraisal,
    RuntimeProfileContext context, {
    Profile? profile,
  }) async {
    profile ??= registry.get(context.profileId);
    if (profile == null) {
      throw ProfileNotFoundException(context.profileId);
    }

    // Get expression policies from profile metadata
    final expressionSection = profile.getExpressionSection();
    if (expressionSection == null || expressionSection.policies.isEmpty) {
      return ExpressionStyle.defaultStyle;
    }

    // Sort by priority and find matching policy
    final policies = [...expressionSection.policies]
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final policy in policies) {
      if (!policy.enabled) continue;

      final matches = await engines.expression.evaluateCondition(
        policy.condition,
        appraisal,
        context,
      );

      if (matches) {
        var resultStyle = policy.style;

        // Apply globalOverrides if configured
        if (expressionSection.globalOverrides != null) {
          resultStyle = _mergeWithOverrides(resultStyle, expressionSection.globalOverrides!);
        }

        return resultStyle;
      }
    }

    // Return default if configured, otherwise default style
    ExpressionStyle resultStyle;
    if (expressionSection.defaultPolicy != null) {
      final defaultPolicy = policies.firstWhere(
        (p) => p.id == expressionSection.defaultPolicy,
        orElse: () => throw PolicyNotFoundException(
          expressionSection.defaultPolicy!,
        ),
      );
      resultStyle = defaultPolicy.style;
    } else {
      resultStyle = ExpressionStyle.defaultStyle;
    }

    // Apply globalOverrides if configured
    if (expressionSection.globalOverrides != null) {
      resultStyle = _mergeWithOverrides(resultStyle, expressionSection.globalOverrides!);
    }

    return resultStyle;
  }

  /// Merge an ExpressionStyle with globalOverrides per design/03-runtime.md §4.
  ExpressionStyle _mergeWithOverrides(
    ExpressionStyle base,
    ExpressionStyle overrides,
  ) {
    return ExpressionStyle(
      tone: ToneConfig(
        formality: overrides.tone.formality,
        confidence: overrides.tone.confidence,
        empathy: overrides.tone.empathy,
        directness: overrides.tone.directness,
      ),
      format: FormatConfig(
        structure: overrides.format.structure,
        length: overrides.format.length,
        includeEvidence: overrides.format.includeEvidence,
        includeCaveats: overrides.format.includeCaveats,
        includeAlternatives: overrides.format.includeAlternatives,
      ),
      hedging: overrides.hedging ?? base.hedging,
      audience: overrides.audience ?? base.audience,
      language: overrides.language ?? base.language,
    );
  }

  /// Apply expression style to content per §4 step 5.
  ///
  /// Uses ExpressionPort.format() per design/02-ports.md §6.
  Future<FormattedResponse> applyExpression(
    String rawContent,
    ExpressionStyle style,
    RuntimeProfileContext context,
  ) async {
    return engines.expression.format(rawContent, style, context);
  }

  Future<void> _callHooks(
    String event,
    RuntimeProfileContext context, {
    AppraisalResult? appraisal,
    DecisionGuidance? decision,
  }) async {
    if (hooks == null) return;

    for (final hook in hooks!) {
      await hook.call(event, context, appraisal: appraisal, decision: decision);
    }
  }
}

// =============================================================================
// Profile Extensions for Spec Sections
// =============================================================================

/// Extension to extract appraisal/decision/expression sections from Profile.
///
/// Sections are stored in profile.metadata under reserved keys:
/// - '_appraisal': AppraisalSection configuration
/// - '_decision': DecisionPolicySection configuration
/// - '_expression': ExpressionPolicySection configuration
extension ProfileSpecSections on Profile {
  /// Get appraisal section from metadata.
  AppraisalSection? getAppraisalSection() {
    final data = metadata['_appraisal'];
    if (data is AppraisalSection) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      return AppraisalSection.fromJson(data);
    }
    return null;
  }

  /// Get decision policy section from metadata.
  DecisionPolicySection? getDecisionSection() {
    final data = metadata['_decision'];
    if (data is DecisionPolicySection) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      return DecisionPolicySection.fromJson(data);
    }
    return null;
  }

  /// Get expression policy section from metadata.
  ExpressionPolicySection? getExpressionSection() {
    final data = metadata['_expression'];
    if (data is ExpressionPolicySection) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      return ExpressionPolicySection.fromJson(data);
    }
    return null;
  }
}

// =============================================================================
// Hooks (§6)
// =============================================================================

/// Hook for runtime events per design/03-runtime.md §6.
abstract class ProfileRuntimeHook {
  Future<void> call(
    String event,
    RuntimeProfileContext context, {
    AppraisalResult? appraisal,
    DecisionGuidance? decision,
  });
}

/// Alias for backward compatibility.
typedef ProfileApplicationHook = ProfileRuntimeHook;

/// No-op hook for default behavior.
class NoOpApplicationHook implements ProfileRuntimeHook {
  const NoOpApplicationHook();

  @override
  Future<void> call(
    String event,
    RuntimeProfileContext context, {
    AppraisalResult? appraisal,
    DecisionGuidance? decision,
  }) async {}
}

// =============================================================================
// Exceptions
// =============================================================================

/// Exception thrown when a profile is not found.
class ProfileNotFoundException implements Exception {
  final String profileId;

  const ProfileNotFoundException(this.profileId);

  @override
  String toString() => 'ProfileNotFoundException: Profile not found: $profileId';
}

/// Exception thrown when a policy is not found.
class PolicyNotFoundException implements Exception {
  final String policyId;

  const PolicyNotFoundException(this.policyId);

  @override
  String toString() => 'PolicyNotFoundException: Policy not found: $policyId';
}

