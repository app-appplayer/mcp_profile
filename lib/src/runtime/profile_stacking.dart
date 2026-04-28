/// Profile Stacking - Multi-profile composition per design/03-runtime.md §7.
///
/// Supports three stacking modes: merge, replace, and stack.
library;

import '../appraisal/metric_definition.dart';
import '../bundle/profile_bundle_spec.dart';
import '../decision/decision_policy.dart';
import '../expression/expression_policy.dart';
import '../expression/expression_style.dart';
import 'profile_runtime.dart';
import 'runtime_context.dart';

// =============================================================================
// ProfileStackMode (§7)
// =============================================================================

/// Stacking mode determines how multiple profiles are combined.
enum ProfileStackMode {
  /// Merge all profiles into a single combined profile.
  merge,

  /// Replace: highest-priority profile wins entirely.
  replace,

  /// Stack: evaluate all profiles in order, combine results.
  stack,
}

// =============================================================================
// ProfileStackConfig (§7)
// =============================================================================

/// Configuration for profile stacking behavior.
class ProfileStackConfig {
  /// Stacking mode.
  final ProfileStackMode mode;

  /// Conflict resolution strategy for policy conflicts.
  final ConflictResolution conflictResolution;

  const ProfileStackConfig({
    this.mode = ProfileStackMode.merge,
    this.conflictResolution = ConflictResolution.highestPriority,
  });
}

// =============================================================================
// ProfileStackingPolicy (§7)
// =============================================================================

/// Policy for stacking profiles.
abstract class ProfileStackingPolicy {
  /// Stack multiple profiles into one.
  SpecProfileBundle stack(List<SpecProfileBundle> profiles);
}

// =============================================================================
// MergeStackingPolicy (§7)
// =============================================================================

/// Merge all profiles into one combined profile.
class MergeStackingPolicy implements ProfileStackingPolicy {
  const MergeStackingPolicy();

  @override
  SpecProfileBundle stack(List<SpecProfileBundle> profiles) {
    if (profiles.isEmpty) throw ArgumentError('No profiles to stack');
    if (profiles.length == 1) return profiles.first;

    // Merge metrics (union, first occurrence wins)
    final allMetrics = mergeMetrics(profiles);

    // Merge decision policies
    final decisionSection = mergeDecisionPolicies(profiles);

    // Merge expression policies
    final expressionSection = mergeExpressionPolicies(profiles);

    return SpecProfileBundle(
      schemaVersion: profiles.first.schemaVersion,
      manifest: ProfileManifest(
        id: 'stacked:${profiles.map((p) => p.id).join('+')}',
        name: 'Stacked Profile',
        version: '1.0.0',
        provider: 'system',
        scope: profiles.first.scope,
      ),
      appraisals: AppraisalSection(metrics: allMetrics),
      decisionPolicies: decisionSection,
      expressionPolicies: expressionSection,
    );
  }
}

// =============================================================================
// ReplaceStackingPolicy (§7)
// =============================================================================

/// Highest-priority profile wins entirely (no merging).
class ReplaceStackingPolicy implements ProfileStackingPolicy {
  const ReplaceStackingPolicy();

  @override
  SpecProfileBundle stack(List<SpecProfileBundle> profiles) {
    if (profiles.isEmpty) throw ArgumentError('No profiles to stack');
    // Already sorted by priority; first = highest priority
    return profiles.first;
  }
}

// =============================================================================
// StackStackingPolicy (§7)
// =============================================================================

/// Evaluate all profiles in sequence, accumulate results.
class StackStackingPolicy implements ProfileStackingPolicy {
  const StackStackingPolicy();

  @override
  SpecProfileBundle stack(List<SpecProfileBundle> profiles) {
    if (profiles.isEmpty) throw ArgumentError('No profiles to stack');
    if (profiles.length == 1) return profiles.first;

    // Similar to merge but preserves all policies without deduplication
    return const MergeStackingPolicy().stack(profiles);
  }
}

// =============================================================================
// Merge Helpers (§7.2, §7.3, §7.4)
// =============================================================================

/// Merge metrics from multiple profiles (§7.2).
/// First occurrence wins (profiles are assumed sorted by priority).
List<AppraisalMetricDef> mergeMetrics(List<SpecProfileBundle> profiles) {
  final mergedMetrics = <String, AppraisalMetricDef>{};

  for (final profile in profiles) {
    for (final metric in profile.appraisals.metrics) {
      // First occurrence wins
      mergedMetrics.putIfAbsent(metric.id, () => metric);
    }
  }

  return mergedMetrics.values.toList();
}

/// Merge decision policies from multiple profiles (§7.3).
/// Policies are prefixed with profile ID and boosted by profile priority.
DecisionPolicySection? mergeDecisionPolicies(
    List<SpecProfileBundle> profiles) {
  final allPolicies = <DecisionPolicy>[];
  String? defaultPolicy;

  for (final profile in profiles) {
    if (profile.decisionPolicies == null) continue;

    for (final policy in profile.decisionPolicies!.policies) {
      allPolicies.add(policy.copyWith(
        id: '${profile.id}:${policy.id}',
        // Boost priority based on profile priority
        priority: policy.priority + profile.priority * 10,
      ));
    }

    // First default policy wins
    defaultPolicy ??= profile.decisionPolicies!.defaultPolicy;
  }

  if (allPolicies.isEmpty) return null;

  // Sort by computed priority
  allPolicies.sort((a, b) => b.priority.compareTo(a.priority));

  return DecisionPolicySection(
    policies: allPolicies,
    defaultPolicy: defaultPolicy,
    conflictResolution: ConflictResolution.highestPriority,
  );
}

/// Merge expression policies from multiple profiles.
ExpressionPolicySection? mergeExpressionPolicies(
    List<SpecProfileBundle> profiles) {
  final allPolicies = <ExpressionPolicy>[];
  String? defaultPolicy;
  ExpressionStyle? globalOverrides;

  for (final profile in profiles) {
    if (profile.expressionPolicies == null) continue;

    allPolicies.addAll(profile.expressionPolicies!.policies);
    defaultPolicy ??= profile.expressionPolicies!.defaultPolicy;
    globalOverrides ??= profile.expressionPolicies!.globalOverrides;
  }

  if (allPolicies.isEmpty) return null;

  return ExpressionPolicySection(
    policies: allPolicies,
    defaultPolicy: defaultPolicy,
    globalOverrides: globalOverrides,
  );
}

/// Merge expression styles from multiple policies (§7.4).
ExpressionStyle mergeExpressionStyles(List<ExpressionStyle> styles) {
  if (styles.isEmpty) return ExpressionStyle.defaultStyle;
  if (styles.length == 1) return styles.first;

  // Merge tone: use most extreme/cautious values
  final mergedTone = ToneConfig(
    formality: _mostFormal(styles.map((s) => s.tone.formality)),
    confidence: _leastConfident(styles.map((s) => s.tone.confidence)),
    empathy: _highest(styles.map((s) => s.tone.empathy)),
    directness: _average(styles.map((s) => s.tone.directness)),
  );

  // Merge format: use most restrictive
  final mergedFormat = FormatConfig(
    structure: styles.first.format.structure,
    length: _shortest(styles.map((s) => s.format.length)),
    includeEvidence: styles.any((s) => s.format.includeEvidence),
    includeCaveats: styles.any((s) => s.format.includeCaveats),
    includeAlternatives: styles.any((s) => s.format.includeAlternatives),
  );

  // Merge hedging: use highest level, merge phrases by category
  final mergedPhrases = <String, List<String>>{};
  for (final style in styles) {
    final phrases = style.hedging?.phrases;
    if (phrases != null) {
      _mergePhrasesInto(mergedPhrases, phrases.highUncertainty, 'high_uncertainty');
      _mergePhrasesInto(mergedPhrases, phrases.moderateUncertainty, 'moderate_uncertainty');
      _mergePhrasesInto(mergedPhrases, phrases.lowUncertainty, 'low_uncertainty');
      _mergePhrasesInto(mergedPhrases, phrases.qualifying, 'qualifying');
      _mergePhrasesInto(mergedPhrases, phrases.probabilistic, 'probabilistic');
    }
  }

  final mergedHedging = HedgingConfig(
    level: _highestHedging(
        styles.map((s) => s.hedging?.level ?? HedgingLevel.none)),
    phrases: mergedPhrases.isNotEmpty
        ? HedgingPhrases(
            highUncertainty: mergedPhrases['high_uncertainty'],
            moderateUncertainty: mergedPhrases['moderate_uncertainty'],
            lowUncertainty: mergedPhrases['low_uncertainty'],
            qualifying: mergedPhrases['qualifying'],
            probabilistic: mergedPhrases['probabilistic'],
          )
        : null,
  );

  return ExpressionStyle(
    tone: mergedTone,
    format: mergedFormat,
    hedging: mergedHedging,
  );
}

// Merge helpers for enum values
Formality _mostFormal(Iterable<Formality> values) {
  if (values.any((v) => v == Formality.formal)) return Formality.formal;
  if (values.any((v) => v == Formality.neutral)) return Formality.neutral;
  return Formality.casual;
}

ToneConfidence _leastConfident(Iterable<ToneConfidence> values) {
  if (values.any((v) => v == ToneConfidence.tentative)) return ToneConfidence.tentative;
  if (values.any((v) => v == ToneConfidence.moderate)) return ToneConfidence.moderate;
  return ToneConfidence.assertive;
}

Empathy _highest(Iterable<Empathy> values) {
  if (values.any((v) => v == Empathy.high)) return Empathy.high;
  if (values.any((v) => v == Empathy.moderate)) return Empathy.moderate;
  return Empathy.low;
}

Directness _average(Iterable<Directness> values) {
  // Average: balanced is default
  return Directness.balanced;
}

Length _shortest(Iterable<Length> values) {
  if (values.any((v) => v == Length.concise)) return Length.concise;
  if (values.any((v) => v == Length.standard)) return Length.standard;
  return Length.detailed;
}

/// Merge phrase lists into a map by category (deduplicating).
void _mergePhrasesInto(
  Map<String, List<String>> target,
  List<String>? phrases,
  String category,
) {
  if (phrases == null) return;
  target.putIfAbsent(category, () => []);
  for (final phrase in phrases) {
    if (!target[category]!.contains(phrase)) {
      target[category]!.add(phrase);
    }
  }
}

HedgingLevel _highestHedging(Iterable<HedgingLevel> values) {
  if (values.any((v) => v == HedgingLevel.strong)) return HedgingLevel.strong;
  if (values.any((v) => v == HedgingLevel.moderate)) {
    return HedgingLevel.moderate;
  }
  if (values.any((v) => v == HedgingLevel.light)) return HedgingLevel.light;
  return HedgingLevel.none;
}

// =============================================================================
// StackingProfileRuntime (§7 - design/03-runtime.md)
// =============================================================================

/// Runtime that supports multiple profiles via stacking.
///
/// Per design/03-runtime.md §7: Extends ProfileRuntime
/// to support applying multiple profiles in priority order
/// using a configurable stacking policy.
class StackingProfileRuntime extends ProfileRuntime {
  /// The stacking policy to use.
  final ProfileStackingPolicy stackingPolicy;

  StackingProfileRuntime({
    required super.registry,
    required super.engines,
    super.hooks,
    this.stackingPolicy = const MergeStackingPolicy(),
  });

  /// Apply multiple profiles in order per design/03-runtime.md §7.
  ///
  /// Sorts profiles by priority, stacks according to policy,
  /// and then applies the stacked result through the inherited pipeline.
  Future<ProfileApplicationResult> applyStack(
    List<SpecProfileBundle> profiles,
    RuntimeProfileContext context, {
    String? rawContent,
  }) async {
    if (profiles.isEmpty) {
      throw ArgumentError('No profiles to stack');
    }

    // Sort by priority (highest first, default: 50 per spec/01 manifest)
    final sorted = [...profiles]
      ..sort((a, b) =>
          (b.manifest.priority).compareTo(a.manifest.priority));

    // Stack according to policy
    final stacked = stackingPolicy.stack(sorted);

    // Build context with stacked profile ID
    final stackedContext = RuntimeContextBuilder.fromProfileContext(context)
        .withProfile(stacked.manifest.id)
        .build();

    // Apply through the inherited runtime pipeline
    return apply(stackedContext, rawContent: rawContent);
  }
}
