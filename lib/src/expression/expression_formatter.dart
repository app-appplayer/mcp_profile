/// Expression Policy Evaluator - Evaluates policies and formats content.
///
/// Implements the expression application flow per spec/04 §12.
library;

import '../appraisal/appraisal_result.dart';
import 'expression_policy.dart';
import 'expression_style.dart';

// =============================================================================
// ExpressionPolicyEvaluator (§12)
// =============================================================================

/// Evaluator that matches expression policies and applies styles.
///
/// Expression application flow per §12:
/// 1. Evaluate expression policies against appraisal
/// 2. Get matching style
/// 3. Apply tone adjustments
/// 4. Apply format restructuring
/// 5. Apply hedging phrases
/// 6. Adapt for audience
/// 7. Return formatted content
class ExpressionPolicyEvaluator {
  const ExpressionPolicyEvaluator();

  /// Evaluate policies and get expression style.
  ExpressionResult evaluate({
    required ExpressionPolicySection policySection,
    required AppraisalResult appraisalResult,
    required String profileId,
    String? content,
  }) {
    final startTime = DateTime.now();

    // Extract metric values
    final metricValues = <String, double>{};
    for (final entry in appraisalResult.metrics.entries) {
      metricValues[entry.key] = entry.value.normalizedValue;
    }
    final aggregatedScore = appraisalResult.aggregatedScore;

    // Sort policies by priority
    final sortedPolicies = policySection.sortedPolicies;

    // Find matching policy
    ExpressionPolicy? matchedPolicy;
    for (final policy in sortedPolicies) {
      if (policy.matches(metricValues, aggregatedScore)) {
        matchedPolicy = policy;
        break;
      }
    }

    // Use default if no match
    if (matchedPolicy == null && policySection.defaultPolicy != null) {
      matchedPolicy = policySection.getPolicy(policySection.defaultPolicy!);
    }

    // Get style (with global overrides if any)
    ExpressionStyle style;
    String policyId;

    if (matchedPolicy != null) {
      style = matchedPolicy.style;
      policyId = matchedPolicy.id;

      // Apply global overrides
      if (policySection.globalOverrides != null) {
        style = policySection.globalOverrides!.merge(style);
      }
    } else {
      style = policySection.globalOverrides ?? ExpressionStyle.defaultStyle;
      policyId = 'default';
    }

    // Format content if provided
    String? formattedContent;
    if (content != null) {
      formattedContent = _formatContent(
        content: content,
        style: style,
        metrics: metricValues,
      );
    }

    return ExpressionResult(
      profileId: profileId,
      policyId: policyId,
      appraisalId: appraisalResult.contextId,
      style: style,
      formattedContent: formattedContent,
      metadata: ExpressionResultMetadata(
        evaluatedAt: startTime,
        hedgingApplied: style.hedging != null &&
            style.hedging!.level != HedgingLevel.none,
        audienceAdaptation: style.audience?.role,
      ),
    );
  }

  /// Format content according to style.
  String _formatContent({
    required String content,
    required ExpressionStyle style,
    required Map<String, double> metrics,
  }) {
    var result = content;

    // Apply hedging
    if (style.hedging != null && style.hedging!.level != HedgingLevel.none) {
      result = _applyHedging(result, style.hedging!, metrics);
    }

    // Apply caveats if needed
    if (style.format.includeCaveats) {
      result = _addCaveats(result, metrics);
    }

    // Apply structure formatting
    result = _applyStructure(result, style.format);

    return result;
  }

  /// Apply hedging phrases to content.
  String _applyHedging(
    String content,
    HedgingConfig hedging,
    Map<String, double> metrics,
  ) {
    final uncertainty = metrics['uncertainty'] ?? 0.0;
    final phrases = hedging.phrases ?? HedgingPhrases.defaults;

    String? hedgePhrase;

    // Select appropriate phrase based on uncertainty
    if (uncertainty > 0.7) {
      hedgePhrase = _selectPhrase(phrases.highUncertainty);
    } else if (uncertainty > 0.4) {
      hedgePhrase = _selectPhrase(phrases.moderateUncertainty);
    } else {
      hedgePhrase = _selectPhrase(phrases.lowUncertainty);
    }

    // Apply based on level
    if (hedgePhrase == null) return content;

    return switch (hedging.position) {
      HedgingPosition.start => '$hedgePhrase $content',
      HedgingPosition.end => '$content ($hedgePhrase)',
      HedgingPosition.inline => _insertHedgingInline(content, hedgePhrase),
    };
  }

  /// Select a phrase from the list (first one for determinism).
  String? _selectPhrase(List<String>? phrases) {
    if (phrases == null || phrases.isEmpty) return null;
    return phrases.first;
  }

  /// Insert hedging phrase inline after first sentence.
  String _insertHedgingInline(String content, String phrase) {
    final firstPeriod = content.indexOf('. ');
    if (firstPeriod > 0) {
      return '${content.substring(0, firstPeriod + 1)} $phrase ${content.substring(firstPeriod + 2)}';
    }
    return '$phrase $content';
  }

  /// Add caveats based on metrics.
  String _addCaveats(String content, Map<String, double> metrics) {
    final caveats = <String>[];

    final uncertainty = metrics['uncertainty'] ?? 0.0;
    final trust = metrics['trust'] ?? 1.0;

    if (uncertainty > 0.5) {
      caveats.add('Note: This analysis is based on incomplete information.');
    }

    if (trust < 0.5) {
      caveats.add(
          'Disclaimer: Source reliability has not been fully verified.');
    }

    if (caveats.isEmpty) return content;

    return '$content\n\n${caveats.join('\n')}';
  }

  /// Apply structure formatting.
  String _applyStructure(String content, FormatConfig format) {
    // Apply length constraints
    if (format.length == Length.concise) {
      // Truncate to first paragraph or max 2 sentences
      final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
      if (sentences.length > 2) {
        return '${sentences.take(2).join(' ')}';
      }
    }

    // Apply structure transformation
    return switch (format.structure) {
      Structure.bullets => _toBullets(content),
      Structure.numbered => _toNumbered(content),
      Structure.table => content, // Tables require structured data
      _ => content, // prose and mixed keep original structure
    };
  }

  /// Convert content to bullet points.
  String _toBullets(String content) {
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences.map((s) => '• ${s.trim()}').join('\n');
  }

  /// Convert content to numbered list.
  String _toNumbered(String content) {
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    var index = 1;
    return sentences.map((s) => '${index++}. ${s.trim()}').join('\n');
  }
}

// =============================================================================
// ExpressionStyleFormatter
// =============================================================================

/// Formatter that applies expression style to raw content.
///
/// This provides more granular control over formatting than
/// the policy evaluator.
class ExpressionStyleFormatter {
  const ExpressionStyleFormatter();

  /// Format content according to style.
  String format({
    required String content,
    required ExpressionStyle style,
    Map<String, double>? metrics,
  }) {
    var result = content;

    // Apply tone adjustments (in real implementation, would use LLM)
    result = _applyTone(result, style.tone);

    // Apply hedging
    if (style.hedging != null && style.hedging!.level != HedgingLevel.none) {
      result = _applyHedgingSimple(result, style.hedging!);
    }

    // Apply format
    result = _applyFormat(result, style.format);

    // Apply audience adaptation
    if (style.audience != null) {
      result = _applyAudienceAdaptation(result, style.audience!);
    }

    return result;
  }

  /// Apply tone adjustments per spec/04 §5.
  ///
  /// Applies deterministic text transformations based on tone settings.
  /// Full natural language transformation would require LLM (see generateStylePrompt).
  String _applyTone(String content, ToneConfig tone) {
    var result = content;

    // Apply formality adjustments
    result = _applyFormality(result, tone.formality);

    // Apply confidence preamble
    result = _applyConfidence(result, tone.confidence);

    // Apply empathy preamble
    result = _applyEmpathy(result, tone.empathy);

    return result;
  }

  /// Apply formality-level text transformations.
  String _applyFormality(String content, Formality formality) {
    switch (formality) {
      case Formality.casual:
        // Expand common formal phrases to casual equivalents
        var result = content;
        const casualReplacements = {
          'It is recommended that': 'You should',
          'Please be advised that': 'Just so you know,',
          'In accordance with': 'Following',
          'At this time': 'Right now',
          'In the event that': 'If',
          'Subsequent to': 'After',
          'Prior to': 'Before',
          'Utilize': 'Use',
          'utilize': 'use',
          'Commence': 'Start',
          'commence': 'start',
          'Terminate': 'End',
          'terminate': 'end',
          'Facilitate': 'Help',
          'facilitate': 'help',
          'Endeavor': 'Try',
          'endeavor': 'try',
        };
        for (final entry in casualReplacements.entries) {
          result = result.replaceAll(entry.key, entry.value);
        }
        return result;

      case Formality.formal:
        // Expand contractions for formal tone
        var result = content;
        const formalReplacements = {
          "don't": 'do not',
          "doesn't": 'does not',
          "won't": 'will not',
          "can't": 'cannot',
          "shouldn't": 'should not',
          "wouldn't": 'would not',
          "couldn't": 'could not',
          "isn't": 'is not',
          "aren't": 'are not',
          "wasn't": 'was not',
          "weren't": 'were not',
          "hasn't": 'has not',
          "haven't": 'have not',
          "hadn't": 'had not',
          "it's": 'it is',
          "that's": 'that is',
          "there's": 'there is',
          "we're": 'we are',
          "they're": 'they are',
          "you're": 'you are',
          "I'm": 'I am',
          "we've": 'we have',
          "they've": 'they have',
          "you've": 'you have',
          "I've": 'I have',
          "we'll": 'we will',
          "they'll": 'they will',
          "you'll": 'you will',
          "I'll": 'I will',
        };
        for (final entry in formalReplacements.entries) {
          result = result.replaceAll(entry.key, entry.value);
        }
        return result;

      case Formality.neutral:
        return content;
    }
  }

  /// Apply confidence-level markers.
  String _applyConfidence(String content, ToneConfidence confidence) {
    return switch (confidence) {
      ToneConfidence.tentative =>
        content.replaceAll(RegExp(r'\bis\b'), 'appears to be')
            .replaceAll(RegExp(r'\bwill\b'), 'may')
            .replaceAll(RegExp(r'\bshould\b'), 'might'),
      ToneConfidence.assertive => content,
      ToneConfidence.moderate => content,
    };
  }

  /// Apply empathy-level preamble.
  String _applyEmpathy(String content, Empathy empathy) {
    return switch (empathy) {
      Empathy.high => 'I understand this may be important to you. $content',
      Empathy.low => content,
      Empathy.moderate => content,
    };
  }

  /// Apply simple hedging.
  String _applyHedgingSimple(String content, HedgingConfig hedging) {
    final phrase = switch (hedging.level) {
      HedgingLevel.none => null,
      HedgingLevel.light => 'This appears to be',
      HedgingLevel.moderate => 'Based on available data,',
      HedgingLevel.strong => 'Current evidence tentatively suggests that',
    };

    if (phrase == null) return content;

    return switch (hedging.position) {
      HedgingPosition.start => '$phrase $content',
      HedgingPosition.end => '$content ($phrase)',
      HedgingPosition.inline => content,
    };
  }

  /// Apply format constraints.
  String _applyFormat(String content, FormatConfig format) {
    var result = content;

    // Apply length
    if (format.length == Length.concise) {
      final sentences = result.split(RegExp(r'(?<=[.!?])\s+'));
      if (sentences.length > 2) {
        result = sentences.take(2).join(' ');
      }
    }

    // Apply structure
    result = switch (format.structure) {
      Structure.bullets => _convertToBullets(result, format.maxBullets),
      Structure.numbered => _convertToNumbered(result, format.maxBullets),
      _ => result,
    };

    return result;
  }

  /// Convert to bullet points.
  String _convertToBullets(String content, int? maxBullets) {
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    final items = maxBullets != null ? sentences.take(maxBullets) : sentences;
    return items.map((s) => '• ${s.trim()}').join('\n');
  }

  /// Convert to numbered list.
  String _convertToNumbered(String content, int? maxBullets) {
    final sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    final items = maxBullets != null ? sentences.take(maxBullets) : sentences;
    var index = 1;
    return items.map((s) => '${index++}. ${s.trim()}').join('\n');
  }

  /// Apply audience adaptation per spec/04 §8.
  ///
  /// Adapts content for expertise level and context.
  /// Full natural language adaptation would require LLM (see generateStylePrompt).
  String _applyAudienceAdaptation(String content, AudienceConfig audience) {
    var result = content;

    // Apply vocabulary adaptation from preferences
    if (audience.preferences != null) {
      if (audience.preferences!.avoidJargon) {
        result = _simplifyJargon(result);
      }
    }

    // Apply expertise-level adaptation
    result = _applyExpertiseLevel(result, audience.expertise);

    // Apply context adaptation
    result = _applyContextAdaptation(result, audience.context);

    return result;
  }

  /// Simplify common technical jargon.
  String _simplifyJargon(String content) {
    var result = content;
    const jargonReplacements = {
      'utilize': 'use',
      'Utilize': 'Use',
      'implement': 'set up',
      'Implement': 'Set up',
      'leverage': 'use',
      'Leverage': 'Use',
      'optimize': 'improve',
      'Optimize': 'Improve',
      'facilitate': 'help with',
      'Facilitate': 'Help with',
      'mitigate': 'reduce',
      'Mitigate': 'Reduce',
      'propagate': 'spread',
      'Propagate': 'Spread',
      'remediate': 'fix',
      'Remediate': 'Fix',
      'instantiate': 'create',
      'Instantiate': 'Create',
    };
    for (final entry in jargonReplacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  /// Apply expertise-level adaptation per §8.1.
  String _applyExpertiseLevel(String content, Expertise expertise) {
    return switch (expertise) {
      Expertise.novice => _adaptForNovice(content),
      Expertise.expert => content,
      Expertise.intermediate => content,
    };
  }

  /// Simplify content for novice audience.
  String _adaptForNovice(String content) {
    // Add explanatory preamble for complex content
    if (content.length > 200) {
      return 'Here is a summary of the key points:\n\n$content';
    }
    return content;
  }

  /// Apply context adaptation per §8.2.
  String _applyContextAdaptation(String content, AudienceContext context) {
    return switch (context) {
      AudienceContext.public_ =>
        'Note: This information is for general reference.\n\n$content',
      AudienceContext.external => content,
      AudienceContext.internal => content,
    };
  }

  /// Generate style prompt for LLM-based formatting.
  String generateStylePrompt(ExpressionStyle style) {
    final parts = <String>[];

    // Tone
    parts.add('Tone: ${style.tone.formality.name}, '
        '${style.tone.confidence.name} confidence, '
        '${style.tone.empathy.name} empathy, '
        '${style.tone.directness.name}');

    // Format
    parts.add('Format: ${style.format.structure.name} structure, '
        '${style.format.length.name} length');

    if (style.format.includeEvidence) parts.add('Include evidence/sources');
    if (style.format.includeCaveats) parts.add('Include caveats/disclaimers');
    if (style.format.includeAlternatives) parts.add('Include alternatives');
    if (style.format.includeNextSteps) parts.add('Include next steps');

    // Hedging
    if (style.hedging != null && style.hedging!.level != HedgingLevel.none) {
      parts.add('Hedging: ${style.hedging!.level.name} level');
    }

    // Audience
    if (style.audience != null) {
      parts.add('Audience: ${style.audience!.expertise.name} expertise, '
          '${style.audience!.context.name} context');
    }

    return parts.join('\n');
  }
}
