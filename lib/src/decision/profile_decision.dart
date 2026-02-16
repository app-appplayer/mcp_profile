/// Profile Decision - Decision making based on profile capabilities.
///
/// Provides decision logic for selecting and adapting profiles at runtime.
library;

import '../definition/profile.dart';
import '../definition/capability.dart';
import '../expression/expression_evaluator.dart';

/// Decision engine for profile selection and adaptation.
class ProfileDecisionEngine {
  /// Expression evaluator for conditions.
  final ExpressionEvaluator _evaluator;

  /// Registered decision rules.
  final List<DecisionRule> _rules = [];

  /// Profile selection strategies.
  final Map<String, ProfileSelectionStrategy> _strategies = {};

  ProfileDecisionEngine({
    ExpressionEvaluator? evaluator,
  }) : _evaluator = evaluator ?? ExpressionEvaluator() {
    _registerDefaultStrategies();
  }

  /// Register a decision rule.
  void registerRule(DecisionRule rule) {
    _rules.add(rule);
  }

  /// Register a selection strategy.
  void registerStrategy(String name, ProfileSelectionStrategy strategy) {
    _strategies[name] = strategy;
  }

  /// Select the best profile from candidates based on context.
  ProfileDecision selectProfile({
    required List<Profile> candidates,
    required ProfileContext context,
    String strategy = 'score',
  }) {
    if (candidates.isEmpty) {
      return ProfileDecision.noMatch(
        reason: 'No candidate profiles provided',
      );
    }

    // Filter by active status
    final active = candidates.where((p) => p.active).toList();
    if (active.isEmpty) {
      return ProfileDecision.noMatch(
        reason: 'No active profiles available',
      );
    }

    // Apply decision rules to filter candidates
    var filtered = active;
    final appliedRules = <String>[];

    for (final rule in _rules) {
      if (_evaluator.evaluateCondition(rule.condition, context)) {
        filtered = _applyRule(filtered, rule, context);
        appliedRules.add(rule.name);
      }
    }

    if (filtered.isEmpty) {
      return ProfileDecision.noMatch(
        reason: 'No profiles match the decision rules',
        appliedRules: appliedRules,
      );
    }

    // Apply selection strategy
    final selector = _strategies[strategy] ?? _strategies['score']!;
    final scored = selector.score(filtered, context);

    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    final selected = scored.first;

    return ProfileDecision.selected(
      profile: selected.profile,
      score: selected.score,
      reason: selected.reason,
      alternatives: scored.skip(1).take(3).toList(),
      appliedRules: appliedRules,
    );
  }

  /// Decide which sections to include based on context.
  SectionDecision decideSections(Profile profile, ProfileContext context) {
    final included = <ProfileSectionResult>[];
    final excluded = <ProfileSectionResult>[];

    for (final section in profile.sections) {
      if (!section.enabled) {
        excluded.add(ProfileSectionResult(
          section: section,
          reason: 'Section is disabled',
        ));
        continue;
      }

      if (section.condition != null) {
        final conditionMet = _evaluator.evaluateCondition(
          section.condition!,
          context,
        );
        if (!conditionMet) {
          excluded.add(ProfileSectionResult(
            section: section,
            reason: 'Condition not met: ${section.condition}',
          ));
          continue;
        }
      }

      included.add(ProfileSectionResult(
        section: section,
        reason: 'Included',
      ));
    }

    // Sort included by priority
    included.sort((a, b) => b.section.priority.compareTo(a.section.priority));

    return SectionDecision(
      included: included,
      excluded: excluded,
    );
  }

  /// Decide which capabilities to enable based on context.
  CapabilityDecision decideCapabilities(
    Profile profile,
    ProfileContext context, {
    List<String>? requiredCapabilities,
    List<String>? disabledCapabilities,
  }) {
    final enabled = <CapabilityResult>[];
    final disabled = <CapabilityResult>[];

    for (final cap in profile.capabilities) {
      // Check if explicitly disabled
      if (disabledCapabilities?.contains(cap.id) == true) {
        disabled.add(CapabilityResult(
          capability: cap,
          reason: 'Explicitly disabled',
        ));
        continue;
      }

      // Check if capability is disabled in profile
      if (!cap.enabled) {
        // But check if it's required
        if (requiredCapabilities?.contains(cap.id) == true) {
          enabled.add(CapabilityResult(
            capability: cap.copyWith(enabled: true),
            reason: 'Force enabled (required)',
          ));
        } else {
          disabled.add(CapabilityResult(
            capability: cap,
            reason: 'Disabled in profile',
          ));
        }
        continue;
      }

      // Check dependencies
      final unmetDeps = cap.dependencies
          .where((dep) => !profile.hasCapability(dep))
          .toList();

      if (unmetDeps.isNotEmpty) {
        disabled.add(CapabilityResult(
          capability: cap,
          reason: 'Unmet dependencies: ${unmetDeps.join(", ")}',
        ));
        continue;
      }

      enabled.add(CapabilityResult(
        capability: cap,
        reason: 'Enabled',
      ));
    }

    return CapabilityDecision(
      enabled: enabled,
      disabled: disabled,
    );
  }

  /// Make a routing decision based on input characteristics.
  RoutingDecision decideRouting({
    required Profile profile,
    required ProfileContext context,
    required String input,
    List<RoutingOption>? options,
  }) {
    final routingOptions = options ?? _defaultRoutingOptions();
    final matches = <RoutingMatch>[];

    for (final option in routingOptions) {
      final score = _scoreRoutingOption(option, profile, context, input);
      if (score > 0) {
        matches.add(RoutingMatch(
          option: option,
          score: score,
          reason: 'Matched ${option.name}',
        ));
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));

    if (matches.isEmpty) {
      return RoutingDecision(
        selectedRoute: null,
        alternatives: [],
        confidence: 0,
        reason: 'No routing options matched',
      );
    }

    return RoutingDecision(
      selectedRoute: matches.first.option,
      alternatives: matches.skip(1).take(3).map((m) => m.option).toList(),
      confidence: matches.first.score,
      reason: matches.first.reason,
    );
  }

  // =========================================================================
  // Private Methods
  // =========================================================================

  void _registerDefaultStrategies() {
    // Score-based strategy
    _strategies['score'] = ScoreBasedStrategy();

    // Capability match strategy
    _strategies['capability'] = CapabilityMatchStrategy();

    // First match strategy
    _strategies['first'] = FirstMatchStrategy();
  }

  List<Profile> _applyRule(
    List<Profile> profiles,
    DecisionRule rule,
    ProfileContext context,
  ) {
    switch (rule.action) {
      case RuleAction.require:
        return profiles.where((p) => _matchesRequirement(p, rule)).toList();
      case RuleAction.prefer:
        // Don't filter, just affects scoring
        return profiles;
      case RuleAction.exclude:
        return profiles.where((p) => !_matchesRequirement(p, rule)).toList();
      case RuleAction.boost:
        // Don't filter, affects scoring
        return profiles;
    }
  }

  bool _matchesRequirement(Profile profile, DecisionRule rule) {
    switch (rule.target) {
      case RuleTarget.capability:
        return profile.hasCapability(rule.value);
      case RuleTarget.tag:
        return profile.tags.contains(rule.value);
      case RuleTarget.metadata:
        return profile.metadata[rule.key] == rule.value;
      case RuleTarget.section:
        return profile.getSection(rule.value) != null;
    }
  }

  double _scoreRoutingOption(
    RoutingOption option,
    Profile profile,
    ProfileContext context,
    String input,
  ) {
    var score = 0.0;

    // Check capability requirements
    for (final cap in option.requiredCapabilities) {
      if (profile.hasCapability(cap)) {
        score += 1.0;
      } else {
        return 0; // Required capability missing
      }
    }

    // Check keyword matches
    final lowerInput = input.toLowerCase();
    for (final keyword in option.keywords) {
      if (lowerInput.contains(keyword.toLowerCase())) {
        score += 0.5;
      }
    }

    // Apply base score
    score += option.baseScore;

    return score;
  }

  List<RoutingOption> _defaultRoutingOptions() {
    return [
      RoutingOption(
        name: 'code_generation',
        requiredCapabilities: [StandardCapabilities.codeGeneration],
        keywords: ['write', 'create', 'generate', 'code', 'implement'],
        baseScore: 0.5,
      ),
      RoutingOption(
        name: 'code_review',
        requiredCapabilities: [StandardCapabilities.codeReview],
        keywords: ['review', 'check', 'analyze', 'improve'],
        baseScore: 0.5,
      ),
      RoutingOption(
        name: 'documentation',
        requiredCapabilities: [StandardCapabilities.documentation],
        keywords: ['document', 'explain', 'describe', 'readme'],
        baseScore: 0.5,
      ),
    ];
  }
}

/// A decision rule for profile selection.
class DecisionRule {
  /// Rule name.
  final String name;

  /// Condition expression.
  final String condition;

  /// Rule action.
  final RuleAction action;

  /// Rule target.
  final RuleTarget target;

  /// Target key (for metadata).
  final String? key;

  /// Target value.
  final String value;

  /// Rule priority.
  final int priority;

  const DecisionRule({
    required this.name,
    this.condition = 'true',
    required this.action,
    required this.target,
    this.key,
    required this.value,
    this.priority = 0,
  });
}

/// Rule actions.
enum RuleAction {
  /// Require the target (filter out non-matching).
  require,

  /// Prefer the target (boost score).
  prefer,

  /// Exclude the target (filter out matching).
  exclude,

  /// Boost score for matching.
  boost,
}

/// Rule targets.
enum RuleTarget {
  /// Target a capability.
  capability,

  /// Target a tag.
  tag,

  /// Target metadata.
  metadata,

  /// Target a section.
  section,
}

/// Result of profile selection.
class ProfileDecision {
  /// Whether a profile was selected.
  final bool matched;

  /// Selected profile.
  final Profile? profile;

  /// Selection score.
  final double score;

  /// Selection reason.
  final String reason;

  /// Alternative profiles considered.
  final List<ScoredProfile> alternatives;

  /// Rules that were applied.
  final List<String> appliedRules;

  const ProfileDecision({
    required this.matched,
    this.profile,
    required this.score,
    required this.reason,
    this.alternatives = const [],
    this.appliedRules = const [],
  });

  factory ProfileDecision.selected({
    required Profile profile,
    required double score,
    required String reason,
    List<ScoredProfile> alternatives = const [],
    List<String> appliedRules = const [],
  }) {
    return ProfileDecision(
      matched: true,
      profile: profile,
      score: score,
      reason: reason,
      alternatives: alternatives,
      appliedRules: appliedRules,
    );
  }

  factory ProfileDecision.noMatch({
    required String reason,
    List<String> appliedRules = const [],
  }) {
    return ProfileDecision(
      matched: false,
      profile: null,
      score: 0,
      reason: reason,
      appliedRules: appliedRules,
    );
  }
}

/// A profile with a selection score.
class ScoredProfile {
  /// The profile.
  final Profile profile;

  /// Selection score.
  final double score;

  /// Scoring reason.
  final String reason;

  const ScoredProfile({
    required this.profile,
    required this.score,
    required this.reason,
  });
}

/// Decision about which sections to include.
class SectionDecision {
  /// Sections to include.
  final List<ProfileSectionResult> included;

  /// Sections excluded.
  final List<ProfileSectionResult> excluded;

  const SectionDecision({
    required this.included,
    required this.excluded,
  });
}

/// Result for a section decision.
class ProfileSectionResult {
  /// The section.
  final dynamic section; // ProfileSection

  /// Decision reason.
  final String reason;

  const ProfileSectionResult({
    required this.section,
    required this.reason,
  });
}

/// Decision about capabilities.
class CapabilityDecision {
  /// Enabled capabilities.
  final List<CapabilityResult> enabled;

  /// Disabled capabilities.
  final List<CapabilityResult> disabled;

  const CapabilityDecision({
    required this.enabled,
    required this.disabled,
  });

  /// Get all enabled capability IDs.
  List<String> get enabledIds => enabled.map((c) => c.capability.id).toList();
}

/// Result for a capability decision.
class CapabilityResult {
  /// The capability.
  final Capability capability;

  /// Decision reason.
  final String reason;

  const CapabilityResult({
    required this.capability,
    required this.reason,
  });
}

/// A routing option.
class RoutingOption {
  /// Option name.
  final String name;

  /// Required capabilities.
  final List<String> requiredCapabilities;

  /// Keywords that suggest this route.
  final List<String> keywords;

  /// Base score.
  final double baseScore;

  /// Metadata for the route.
  final Map<String, dynamic> metadata;

  const RoutingOption({
    required this.name,
    this.requiredCapabilities = const [],
    this.keywords = const [],
    this.baseScore = 0,
    this.metadata = const {},
  });
}

/// Routing decision result.
class RoutingDecision {
  /// Selected route.
  final RoutingOption? selectedRoute;

  /// Alternative routes.
  final List<RoutingOption> alternatives;

  /// Confidence in the decision.
  final double confidence;

  /// Decision reason.
  final String reason;

  const RoutingDecision({
    required this.selectedRoute,
    required this.alternatives,
    required this.confidence,
    required this.reason,
  });

  /// Check if a route was selected.
  bool get hasSelection => selectedRoute != null;
}

/// Internal routing match.
class RoutingMatch {
  final RoutingOption option;
  final double score;
  final String reason;

  const RoutingMatch({
    required this.option,
    required this.score,
    required this.reason,
  });
}

// =========================================================================
// Selection Strategies
// =========================================================================

/// Strategy for selecting profiles.
abstract class ProfileSelectionStrategy {
  /// Score profiles based on context.
  List<ScoredProfile> score(List<Profile> profiles, ProfileContext context);
}

/// Score-based selection strategy.
class ScoreBasedStrategy implements ProfileSelectionStrategy {
  @override
  List<ScoredProfile> score(List<Profile> profiles, ProfileContext context) {
    return profiles.map((p) {
      var score = 50.0; // Base score

      // Boost for having description
      if (p.description != null && p.description!.isNotEmpty) {
        score += 5;
      }

      // Boost for sections
      score += p.sections.length * 2;

      // Boost for enabled capabilities
      score += p.enabledCapabilities.length * 3;

      return ScoredProfile(
        profile: p,
        score: score,
        reason: 'Score-based evaluation',
      );
    }).toList();
  }
}

/// Capability match selection strategy.
class CapabilityMatchStrategy implements ProfileSelectionStrategy {
  @override
  List<ScoredProfile> score(List<Profile> profiles, ProfileContext context) {
    final required = context.get('requiredCapabilities') as List<String>? ?? [];

    return profiles.map((p) {
      var score = 0.0;

      for (final cap in required) {
        if (p.hasCapability(cap)) {
          score += 10;
        }
      }

      return ScoredProfile(
        profile: p,
        score: score,
        reason: 'Capability match: ${score ~/ 10} of ${required.length}',
      );
    }).toList();
  }
}

/// First match selection strategy.
class FirstMatchStrategy implements ProfileSelectionStrategy {
  @override
  List<ScoredProfile> score(List<Profile> profiles, ProfileContext context) {
    return profiles.asMap().entries.map((entry) {
      return ScoredProfile(
        profile: entry.value,
        score: (profiles.length - entry.key).toDouble(),
        reason: 'First match priority',
      );
    }).toList();
  }
}
