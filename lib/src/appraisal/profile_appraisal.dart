/// Profile Appraisal - Evaluation and scoring of profile effectiveness.
///
/// Provides tools for assessing profile quality, coverage, and performance.
library;

import '../definition/profile.dart';
import '../definition/section.dart';

/// Appraiser for evaluating profile quality and effectiveness.
class ProfileAppraiser {
  /// Evaluation criteria weights.
  final AppraisalWeights weights;

  /// Custom validators.
  final List<ProfileValidator> _validators = [];

  ProfileAppraiser({
    this.weights = const AppraisalWeights(),
  });

  /// Register a custom validator.
  void registerValidator(ProfileValidator validator) {
    _validators.add(validator);
  }

  /// Perform a full appraisal of a profile.
  ProfileAppraisal appraise(Profile profile) {
    final now = DateTime.now();
    final scores = <String, DimensionScore>{};
    final issues = <AppraisalIssue>[];

    // Evaluate completeness
    final completeness = _evaluateCompleteness(profile);
    scores['completeness'] = completeness.score;
    issues.addAll(completeness.issues);

    // Evaluate structure
    final structure = _evaluateStructure(profile);
    scores['structure'] = structure.score;
    issues.addAll(structure.issues);

    // Evaluate clarity
    final clarity = _evaluateClarity(profile);
    scores['clarity'] = clarity.score;
    issues.addAll(clarity.issues);

    // Evaluate capabilities
    final capabilities = _evaluateCapabilities(profile);
    scores['capabilities'] = capabilities.score;
    issues.addAll(capabilities.issues);

    // Run custom validators
    for (final validator in _validators) {
      final result = validator.validate(profile);
      if (result.score != null) {
        scores[result.name] = result.score!;
      }
      issues.addAll(result.issues);
    }

    // Calculate overall score
    final overallScore = _calculateOverallScore(scores);

    return ProfileAppraisal(
      profileId: profile.id,
      profileVersion: profile.version,
      overallScore: overallScore,
      dimensionScores: scores,
      issues: issues,
      recommendations: _generateRecommendations(issues),
      appraisedAt: now,
    );
  }

  /// Quick check for critical issues only.
  List<AppraisalIssue> quickCheck(Profile profile) {
    final issues = <AppraisalIssue>[];

    // Check for empty profile
    if (profile.id.isEmpty) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.critical,
        category: 'identity',
        message: 'Profile ID is required',
        suggestion: 'Add a unique identifier for the profile',
      ));
    }

    if (profile.name.isEmpty) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.critical,
        category: 'identity',
        message: 'Profile name is required',
        suggestion: 'Add a descriptive name for the profile',
      ));
    }

    // Check for system prompt
    if (!profile.sections.any((s) => s.type == SectionType.system)) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.warning,
        category: 'structure',
        message: 'No system prompt section found',
        suggestion: 'Add a system section to define the base persona',
      ));
    }

    return issues;
  }

  /// Compare two profiles.
  ProfileComparison compare(Profile baseline, Profile candidate) {
    final baselineAppraisal = appraise(baseline);
    final candidateAppraisal = appraise(candidate);

    final differences = <String, double>{};
    for (final key in baselineAppraisal.dimensionScores.keys) {
      final baseScore = baselineAppraisal.dimensionScores[key]?.value ?? 0;
      final candScore = candidateAppraisal.dimensionScores[key]?.value ?? 0;
      differences[key] = candScore - baseScore;
    }

    return ProfileComparison(
      baselineId: baseline.id,
      candidateId: candidate.id,
      baselineScore: baselineAppraisal.overallScore,
      candidateScore: candidateAppraisal.overallScore,
      scoreDifference: candidateAppraisal.overallScore - baselineAppraisal.overallScore,
      dimensionDifferences: differences,
      baselineIssueCount: baselineAppraisal.issues.length,
      candidateIssueCount: candidateAppraisal.issues.length,
    );
  }

  // =========================================================================
  // Private Evaluation Methods
  // =========================================================================

  _EvaluationResult _evaluateCompleteness(Profile profile) {
    final issues = <AppraisalIssue>[];
    var score = 100.0;

    // Check description
    if (profile.description == null || profile.description!.isEmpty) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.minor,
        category: 'completeness',
        message: 'Profile has no description',
        suggestion: 'Add a description explaining the profile purpose',
      ));
      score -= 5;
    }

    // Check sections
    if (profile.sections.isEmpty) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.critical,
        category: 'completeness',
        message: 'Profile has no sections',
        suggestion: 'Add at least a system prompt section',
      ));
      score -= 50;
    }

    // Check for essential section types
    final sectionTypes = profile.sections.map((s) => s.type).toSet();

    if (!sectionTypes.contains(SectionType.system)) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.warning,
        category: 'completeness',
        message: 'Missing system prompt section',
        suggestion: 'Add a system section for the base AI persona',
      ));
      score -= 15;
    }

    if (!sectionTypes.contains(SectionType.instructions)) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.minor,
        category: 'completeness',
        message: 'Missing instructions section',
        suggestion: 'Consider adding explicit instructions',
      ));
      score -= 5;
    }

    return _EvaluationResult(
      score: DimensionScore(
        name: 'completeness',
        value: score.clamp(0, 100),
        weight: weights.completeness,
      ),
      issues: issues,
    );
  }

  _EvaluationResult _evaluateStructure(Profile profile) {
    final issues = <AppraisalIssue>[];
    var score = 100.0;

    // Check section priorities
    final hasPriorities = profile.sections.any((s) => s.priority != 0);
    if (!hasPriorities && profile.sections.length > 1) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.minor,
        category: 'structure',
        message: 'Sections have no priorities defined',
        suggestion: 'Set priorities to control section ordering',
      ));
      score -= 5;
    }

    // Check for duplicate section names
    final names = <String>{};
    for (final section in profile.sections) {
      if (names.contains(section.name)) {
        issues.add(AppraisalIssue(
          severity: AppraisalSeverity.warning,
          category: 'structure',
          message: 'Duplicate section name: ${section.name}',
          suggestion: 'Use unique names for each section',
        ));
        score -= 10;
      }
      names.add(section.name);
    }

    // Check section content lengths
    for (final section in profile.sections) {
      if (section.content.length > 10000) {
        issues.add(AppraisalIssue(
          severity: AppraisalSeverity.warning,
          category: 'structure',
          message: 'Section "${section.name}" is very long (${section.content.length} chars)',
          suggestion: 'Consider breaking into smaller sections',
        ));
        score -= 5;
      }
    }

    return _EvaluationResult(
      score: DimensionScore(
        name: 'structure',
        value: score.clamp(0, 100),
        weight: weights.structure,
      ),
      issues: issues,
    );
  }

  _EvaluationResult _evaluateClarity(Profile profile) {
    final issues = <AppraisalIssue>[];
    var score = 100.0;

    for (final section in profile.sections) {
      // Check for empty content
      if (section.content.trim().isEmpty && section.children.isEmpty) {
        issues.add(AppraisalIssue(
          severity: AppraisalSeverity.warning,
          category: 'clarity',
          message: 'Section "${section.name}" has empty content',
          suggestion: 'Add content or remove the empty section',
        ));
        score -= 10;
      }

      // Check for overly complex conditions
      if (section.condition != null && section.condition!.length > 100) {
        issues.add(AppraisalIssue(
          severity: AppraisalSeverity.minor,
          category: 'clarity',
          message: 'Section "${section.name}" has complex condition',
          suggestion: 'Simplify the condition or use a function',
        ));
        score -= 3;
      }
    }

    return _EvaluationResult(
      score: DimensionScore(
        name: 'clarity',
        value: score.clamp(0, 100),
        weight: weights.clarity,
      ),
      issues: issues,
    );
  }

  _EvaluationResult _evaluateCapabilities(Profile profile) {
    final issues = <AppraisalIssue>[];
    var score = 100.0;

    // Check for disabled capabilities
    final disabled = profile.capabilities.where((c) => !c.enabled).toList();
    if (disabled.length > profile.capabilities.length / 2) {
      issues.add(const AppraisalIssue(
        severity: AppraisalSeverity.minor,
        category: 'capabilities',
        message: 'More than half of capabilities are disabled',
        suggestion: 'Review and remove unused capabilities',
      ));
      score -= 5;
    }

    // Check for duplicate capability IDs
    final ids = <String>{};
    for (final cap in profile.capabilities) {
      if (ids.contains(cap.id)) {
        issues.add(AppraisalIssue(
          severity: AppraisalSeverity.warning,
          category: 'capabilities',
          message: 'Duplicate capability ID: ${cap.id}',
          suggestion: 'Remove duplicate capability definitions',
        ));
        score -= 10;
      }
      ids.add(cap.id);
    }

    // Check for unmet dependencies
    for (final cap in profile.capabilities.where((c) => c.enabled)) {
      for (final dep in cap.dependencies) {
        if (!profile.hasCapability(dep)) {
          issues.add(AppraisalIssue(
            severity: AppraisalSeverity.warning,
            category: 'capabilities',
            message: 'Capability "${cap.id}" depends on missing "${dep}"',
            suggestion: 'Add the required dependency or remove the capability',
          ));
          score -= 10;
        }
      }
    }

    return _EvaluationResult(
      score: DimensionScore(
        name: 'capabilities',
        value: score.clamp(0, 100),
        weight: weights.capabilities,
      ),
      issues: issues,
    );
  }

  double _calculateOverallScore(Map<String, DimensionScore> scores) {
    if (scores.isEmpty) return 0;

    var weightedSum = 0.0;
    var totalWeight = 0.0;

    for (final score in scores.values) {
      weightedSum += score.value * score.weight;
      totalWeight += score.weight;
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0;
  }

  List<String> _generateRecommendations(List<AppraisalIssue> issues) {
    final recommendations = <String>{};

    // Prioritize critical issues
    final critical = issues.where((i) => i.severity == AppraisalSeverity.critical);
    for (final issue in critical) {
      if (issue.suggestion != null) {
        recommendations.add('[CRITICAL] ${issue.suggestion}');
      }
    }

    // Add warning recommendations
    final warnings = issues.where((i) => i.severity == AppraisalSeverity.warning);
    for (final issue in warnings.take(5)) {
      if (issue.suggestion != null) {
        recommendations.add(issue.suggestion!);
      }
    }

    return recommendations.toList();
  }
}

/// Evaluation result with score and issues.
class _EvaluationResult {
  final DimensionScore score;
  final List<AppraisalIssue> issues;

  const _EvaluationResult({
    required this.score,
    required this.issues,
  });
}

/// Complete profile appraisal result.
class ProfileAppraisal {
  /// Profile ID that was appraised.
  final String profileId;

  /// Profile version that was appraised.
  final String profileVersion;

  /// Overall score (0-100).
  final double overallScore;

  /// Scores by dimension.
  final Map<String, DimensionScore> dimensionScores;

  /// Issues found during appraisal.
  final List<AppraisalIssue> issues;

  /// Recommendations for improvement.
  final List<String> recommendations;

  /// When the appraisal was performed.
  final DateTime appraisedAt;

  const ProfileAppraisal({
    required this.profileId,
    required this.profileVersion,
    required this.overallScore,
    required this.dimensionScores,
    required this.issues,
    required this.recommendations,
    required this.appraisedAt,
  });

  /// Get issues by severity.
  List<AppraisalIssue> getIssuesBySeverity(AppraisalSeverity severity) {
    return issues.where((i) => i.severity == severity).toList();
  }

  /// Check if appraisal passed (no critical issues, score above threshold).
  bool passed({double threshold = 70.0}) {
    return overallScore >= threshold &&
        !issues.any((i) => i.severity == AppraisalSeverity.critical);
  }

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'profileVersion': profileVersion,
        'overallScore': overallScore,
        'dimensionScores': dimensionScores.map((k, v) => MapEntry(k, v.toJson())),
        'issues': issues.map((i) => i.toJson()).toList(),
        'recommendations': recommendations,
        'appraisedAt': appraisedAt.toIso8601String(),
      };
}

/// Score for a specific evaluation dimension.
class DimensionScore {
  /// Dimension name.
  final String name;

  /// Score value (0-100).
  final double value;

  /// Weight in overall calculation.
  final double weight;

  const DimensionScore({
    required this.name,
    required this.value,
    this.weight = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'weight': weight,
      };
}

/// Issue found during appraisal.
class AppraisalIssue {
  /// Issue severity.
  final AppraisalSeverity severity;

  /// Issue category.
  final String category;

  /// Issue message.
  final String message;

  /// Suggestion for fixing.
  final String? suggestion;

  /// Related section name.
  final String? sectionName;

  const AppraisalIssue({
    required this.severity,
    required this.category,
    required this.message,
    this.suggestion,
    this.sectionName,
  });

  Map<String, dynamic> toJson() => {
        'severity': severity.name,
        'category': category,
        'message': message,
        if (suggestion != null) 'suggestion': suggestion,
        if (sectionName != null) 'sectionName': sectionName,
      };
}

/// Appraisal issue severity levels.
enum AppraisalSeverity {
  /// Critical issue that must be fixed.
  critical,

  /// Warning that should be addressed.
  warning,

  /// Minor issue or suggestion.
  minor,

  /// Informational note.
  info,
}

/// Weights for different appraisal dimensions.
class AppraisalWeights {
  /// Weight for completeness dimension.
  final double completeness;

  /// Weight for structure dimension.
  final double structure;

  /// Weight for clarity dimension.
  final double clarity;

  /// Weight for capabilities dimension.
  final double capabilities;

  const AppraisalWeights({
    this.completeness = 1.0,
    this.structure = 1.0,
    this.clarity = 1.0,
    this.capabilities = 0.8,
  });
}

/// Comparison between two profiles.
class ProfileComparison {
  /// Baseline profile ID.
  final String baselineId;

  /// Candidate profile ID.
  final String candidateId;

  /// Baseline overall score.
  final double baselineScore;

  /// Candidate overall score.
  final double candidateScore;

  /// Score difference (positive means candidate is better).
  final double scoreDifference;

  /// Differences by dimension.
  final Map<String, double> dimensionDifferences;

  /// Number of issues in baseline.
  final int baselineIssueCount;

  /// Number of issues in candidate.
  final int candidateIssueCount;

  const ProfileComparison({
    required this.baselineId,
    required this.candidateId,
    required this.baselineScore,
    required this.candidateScore,
    required this.scoreDifference,
    required this.dimensionDifferences,
    required this.baselineIssueCount,
    required this.candidateIssueCount,
  });

  /// Check if candidate is an improvement.
  bool get isImprovement => scoreDifference > 0;
}

/// Custom profile validator interface.
abstract class ProfileValidator {
  /// Validator name.
  String get name;

  /// Validate a profile.
  ValidationResult validate(Profile profile);
}

/// Result from a custom validator.
class ValidationResult {
  /// Validator name.
  final String name;

  /// Optional score.
  final DimensionScore? score;

  /// Issues found.
  final List<AppraisalIssue> issues;

  const ValidationResult({
    required this.name,
    this.score,
    this.issues = const [],
  });
}
