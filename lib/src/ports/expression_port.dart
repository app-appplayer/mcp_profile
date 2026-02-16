/// Expression Port - Interface for expression formatting and styling.
///
/// Provides methods for formatting profile output with tone, style,
/// and structure adjustments.
library;

/// Port for expression/formatting operations.
abstract class ExpressionPort {
  /// Format content with style.
  Future<FormattedContent> format({
    required String content,
    required ExpressionStyle style,
    FormattingContext? context,
  });

  /// Adjust tone of content.
  Future<String> adjustTone({
    required String content,
    required Tone targetTone,
    Tone? sourceTone,
  });

  /// Apply hedging to claims.
  Future<String> applyHedging({
    required String content,
    required HedgingLevel level,
    List<String>? claimPatterns,
  });

  /// Structure content according to template.
  Future<String> structureContent({
    required String content,
    required StructureTemplate template,
  });
}

/// Formatted content result.
class FormattedContent {
  /// Formatted content.
  final String content;

  /// Applied styles.
  final List<String> appliedStyles;

  /// Formatting metadata.
  final Map<String, dynamic> metadata;

  const FormattedContent({
    required this.content,
    this.appliedStyles = const [],
    this.metadata = const {},
  });
}

/// Expression style definition.
class ExpressionStyle {
  /// Style name.
  final String name;

  /// Target tone.
  final Tone tone;

  /// Hedging level.
  final HedgingLevel hedging;

  /// Formality level.
  final FormalityLevel formality;

  /// Response length preference.
  final LengthPreference length;

  /// Additional style parameters.
  final Map<String, dynamic> parameters;

  const ExpressionStyle({
    required this.name,
    this.tone = Tone.neutral,
    this.hedging = HedgingLevel.moderate,
    this.formality = FormalityLevel.professional,
    this.length = LengthPreference.moderate,
    this.parameters = const {},
  });

  /// Create from JSON.
  factory ExpressionStyle.fromJson(Map<String, dynamic> json) {
    return ExpressionStyle(
      name: json['name'] as String,
      tone: Tone.values.firstWhere(
        (t) => t.name == json['tone'],
        orElse: () => Tone.neutral,
      ),
      hedging: HedgingLevel.values.firstWhere(
        (h) => h.name == json['hedging'],
        orElse: () => HedgingLevel.moderate,
      ),
      formality: FormalityLevel.values.firstWhere(
        (f) => f.name == json['formality'],
        orElse: () => FormalityLevel.professional,
      ),
      length: LengthPreference.values.firstWhere(
        (l) => l.name == json['length'],
        orElse: () => LengthPreference.moderate,
      ),
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'name': name,
        'tone': tone.name,
        'hedging': hedging.name,
        'formality': formality.name,
        'length': length.name,
        if (parameters.isNotEmpty) 'parameters': parameters,
      };

  /// Standard professional style.
  static const ExpressionStyle professional = ExpressionStyle(
    name: 'professional',
    tone: Tone.neutral,
    hedging: HedgingLevel.moderate,
    formality: FormalityLevel.professional,
  );

  /// Casual/friendly style.
  static const ExpressionStyle casual = ExpressionStyle(
    name: 'casual',
    tone: Tone.friendly,
    hedging: HedgingLevel.low,
    formality: FormalityLevel.casual,
  );

  /// Formal/academic style.
  static const ExpressionStyle formal = ExpressionStyle(
    name: 'formal',
    tone: Tone.neutral,
    hedging: HedgingLevel.high,
    formality: FormalityLevel.formal,
  );

  /// Technical/expert style.
  static const ExpressionStyle technical = ExpressionStyle(
    name: 'technical',
    tone: Tone.neutral,
    hedging: HedgingLevel.low,
    formality: FormalityLevel.professional,
  );
}

/// Tone options.
enum Tone {
  /// Neutral, balanced tone.
  neutral,

  /// Warm, friendly tone.
  friendly,

  /// Direct, assertive tone.
  assertive,

  /// Empathetic, understanding tone.
  empathetic,

  /// Cautious, measured tone.
  cautious,

  /// Enthusiastic, positive tone.
  enthusiastic,
}

/// Hedging level for claims.
enum HedgingLevel {
  /// No hedging (direct statements).
  none,

  /// Low hedging (occasional qualifiers).
  low,

  /// Moderate hedging (balanced qualifiers).
  moderate,

  /// High hedging (frequent qualifiers).
  high,
}

/// Formality level.
enum FormalityLevel {
  /// Very casual/informal.
  casual,

  /// Professional but approachable.
  professional,

  /// Formal/academic.
  formal,
}

/// Response length preference.
enum LengthPreference {
  /// Brief, concise responses.
  brief,

  /// Moderate length responses.
  moderate,

  /// Detailed, thorough responses.
  detailed,

  /// Let context determine length.
  adaptive,
}

/// Context for formatting.
class FormattingContext {
  /// User preferences.
  final Map<String, dynamic> userPreferences;

  /// Conversation context.
  final Map<String, dynamic> conversationContext;

  /// Domain/topic context.
  final String? domain;

  /// Audience type.
  final String? audience;

  const FormattingContext({
    this.userPreferences = const {},
    this.conversationContext = const {},
    this.domain,
    this.audience,
  });
}

/// Structure template for content.
class StructureTemplate {
  /// Template name.
  final String name;

  /// Template sections.
  final List<TemplateSection> sections;

  /// Whether sections are required.
  final bool sectionsRequired;

  const StructureTemplate({
    required this.name,
    required this.sections,
    this.sectionsRequired = false,
  });

  /// Standard Q&A template.
  static const StructureTemplate qAndA = StructureTemplate(
    name: 'q_and_a',
    sections: [
      TemplateSection(name: 'answer', required: true),
      TemplateSection(name: 'explanation', required: false),
    ],
  );

  /// Step-by-step template.
  static const StructureTemplate stepByStep = StructureTemplate(
    name: 'step_by_step',
    sections: [
      TemplateSection(name: 'overview', required: true),
      TemplateSection(name: 'steps', required: true),
      TemplateSection(name: 'summary', required: false),
    ],
  );

  /// Analysis template.
  static const StructureTemplate analysis = StructureTemplate(
    name: 'analysis',
    sections: [
      TemplateSection(name: 'summary', required: true),
      TemplateSection(name: 'findings', required: true),
      TemplateSection(name: 'recommendations', required: false),
    ],
  );
}

/// Template section.
class TemplateSection {
  /// Section name.
  final String name;

  /// Whether section is required.
  final bool required;

  /// Maximum length for section.
  final int? maxLength;

  const TemplateSection({
    required this.name,
    this.required = false,
    this.maxLength,
  });
}

/// Empty implementation for testing.
class EmptyExpressionPort implements ExpressionPort {
  const EmptyExpressionPort();

  @override
  Future<FormattedContent> format({
    required String content,
    required ExpressionStyle style,
    FormattingContext? context,
  }) async {
    return FormattedContent(content: content);
  }

  @override
  Future<String> adjustTone({
    required String content,
    required Tone targetTone,
    Tone? sourceTone,
  }) async =>
      content;

  @override
  Future<String> applyHedging({
    required String content,
    required HedgingLevel level,
    List<String>? claimPatterns,
  }) async =>
      content;

  @override
  Future<String> structureContent({
    required String content,
    required StructureTemplate template,
  }) async =>
      content;
}
