/// Conflict Resolution - Strategy implementations per design/03-runtime.md §7.3.
///
/// Resolves conflicts when multiple decision policies match.
library;

import '../decision/decision_guidance.dart';
import '../decision/decision_policy.dart';

// =============================================================================
// Conflict Resolution (§7.3)
// =============================================================================

/// Resolve conflicting guidance from multiple matched policies.
///
/// Implements all 9 ConflictResolution strategies.
DecisionGuidance resolveConflictingGuidance(
  List<DecisionGuidance> matches,
  ConflictResolution strategy,
) {
  if (matches.isEmpty) return DecisionGuidance.defaultProceed;
  if (matches.length == 1) return matches.first;

  return switch (strategy) {
    ConflictResolution.firstMatch => matches.first,
    ConflictResolution.lastMatch => matches.last,
    ConflictResolution.highestPriority =>
      matches.first, // Already sorted by priority
    ConflictResolution.mostRestrictive => _mostRestrictive(matches),
    ConflictResolution.mostSpecific =>
      matches.last, // Last in sorted = most specific
    ConflictResolution.unanimous => _unanimous(matches),
    ConflictResolution.majority => _majority(matches),
    ConflictResolution.merge => _merge(matches),
    ConflictResolution.custom =>
      matches.first, // Custom requires app-level implementation
  };
}

/// Most restrictive action wins.
/// Order: reject > escalate > hold > question > defer > custom > proceedWithCaution > proceed
DecisionGuidance _mostRestrictive(List<DecisionGuidance> matches) {
  const actionOrder = [
    DecisionAction.reject,
    DecisionAction.escalate,
    DecisionAction.hold,
    DecisionAction.question,
    DecisionAction.defer,
    DecisionAction.custom,
    DecisionAction.proceedWithCaution,
    DecisionAction.proceed,
  ];

  return matches.reduce((a, b) {
    final aIndex = actionOrder.indexOf(a.action);
    final bIndex = actionOrder.indexOf(b.action);
    return aIndex < bIndex ? a : b;
  });
}

/// Unanimous: all must agree on action. Falls back to most restrictive.
DecisionGuidance _unanimous(List<DecisionGuidance> matches) {
  final actions = matches.map((m) => m.action).toSet();
  if (actions.length == 1) return matches.first;
  // No consensus: fall back to most restrictive
  return _mostRestrictive(matches);
}

/// Majority: most common action wins.
DecisionGuidance _majority(List<DecisionGuidance> matches) {
  final actionCounts = <DecisionAction, int>{};
  for (final m in matches) {
    actionCounts[m.action] = (actionCounts[m.action] ?? 0) + 1;
  }
  final majorityAction = actionCounts.entries
      .reduce((a, b) => a.value >= b.value ? a : b)
      .key;
  return matches.firstWhere((m) => m.action == majorityAction);
}

/// Merge: combine modifiers from all matches, use first match's action.
DecisionGuidance _merge(List<DecisionGuidance> matches) {
  final allModifiers = matches.expand((m) => m.modifiers).toList();
  return DecisionGuidance(
    action: matches.first.action,
    explanation: matches.first.explanation,
    modifiers: allModifiers,
    confidence: matches.first.confidence,
    metadata: matches.first.metadata,
  );
}

// =============================================================================
// ConflictResolver (Strategy Pattern)
// =============================================================================

/// Abstract conflict resolver using strategy pattern.
abstract class ConflictResolver {
  /// Resolve conflicts between multiple matched guidances.
  DecisionGuidance resolve(List<DecisionGuidance> matches);
}

/// First match resolver.
class FirstMatchResolver implements ConflictResolver {
  const FirstMatchResolver();

  @override
  DecisionGuidance resolve(List<DecisionGuidance> matches) =>
      resolveConflictingGuidance(matches, ConflictResolution.firstMatch);
}

/// Highest priority resolver.
class HighestPriorityResolver implements ConflictResolver {
  const HighestPriorityResolver();

  @override
  DecisionGuidance resolve(List<DecisionGuidance> matches) =>
      resolveConflictingGuidance(matches, ConflictResolution.highestPriority);
}

/// Most restrictive resolver.
class MostRestrictiveResolver implements ConflictResolver {
  const MostRestrictiveResolver();

  @override
  DecisionGuidance resolve(List<DecisionGuidance> matches) =>
      resolveConflictingGuidance(matches, ConflictResolution.mostRestrictive);
}

/// Merge resolver.
class MergeResolver implements ConflictResolver {
  const MergeResolver();

  @override
  DecisionGuidance resolve(List<DecisionGuidance> matches) =>
      resolveConflictingGuidance(matches, ConflictResolution.merge);
}

/// Factory to create a resolver from a ConflictResolution strategy.
ConflictResolver createResolver(ConflictResolution strategy) {
  return _StrategyResolver(strategy);
}

class _StrategyResolver implements ConflictResolver {
  final ConflictResolution strategy;

  const _StrategyResolver(this.strategy);

  @override
  DecisionGuidance resolve(List<DecisionGuidance> matches) =>
      resolveConflictingGuidance(matches, strategy);
}
