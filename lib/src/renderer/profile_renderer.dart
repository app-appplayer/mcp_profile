/// Profile renderer for generating prompts.
library;

import 'package:mcp_bundle/mcp_bundle.dart' hide ProfileSection;

import '../definition/profile.dart';
import '../definition/section.dart';

/// Renders profiles into prompts.
class ProfileRenderer {
  final ProfileRenderOptions options;

  const ProfileRenderer({this.options = const ProfileRenderOptions()});

  /// Render a profile to a prompt string.
  Future<String> render(Profile profile, {ProfileContext? context}) async {
    final ctx = context ?? const ProfileContext();
    final sections = _filterAndSortSections(profile.sections, ctx);

    final buffer = StringBuffer();
    for (final section in sections) {
      final renderedSection = await _renderSection(section, ctx);
      if (renderedSection.isNotEmpty) {
        if (buffer.isNotEmpty && options.sectionSeparator.isNotEmpty) {
          buffer.write(options.sectionSeparator);
        }
        buffer.write(renderedSection);
      }
    }

    return buffer.toString();
  }

  /// Render a profile to structured sections.
  Future<List<RenderedSection>> renderSections(
    Profile profile, {
    ProfileContext? context,
  }) async {
    final ctx = context ?? const ProfileContext();
    final sections = _filterAndSortSections(profile.sections, ctx);

    final result = <RenderedSection>[];
    for (final section in sections) {
      final content = await _renderSection(section, ctx);
      if (content.isNotEmpty) {
        result.add(RenderedSection(
          name: section.name,
          type: section.type,
          content: content,
          priority: section.priority,
        ));
      }
    }

    return result;
  }

  List<ProfileSection> _filterAndSortSections(
    List<ProfileSection> sections,
    ProfileContext context,
  ) {
    // Filter enabled sections
    var filtered = sections.where((s) => s.enabled).toList();

    // Filter by condition
    filtered = filtered.where((s) {
      if (s.condition == null) return true;
      return _evaluateCondition(s.condition!, context);
    }).toList();

    // Sort by ordering strategy
    switch (options.ordering) {
      case SectionOrdering.byPriority:
        filtered.sort((a, b) => b.priority.compareTo(a.priority));
      case SectionOrdering.byType:
        filtered.sort((a, b) => _typeOrder(a.type).compareTo(_typeOrder(b.type)));
      case SectionOrdering.asIs:
      case SectionOrdering.custom:
        // Keep original order
        break;
    }

    return filtered;
  }

  int _typeOrder(SectionType type) {
    switch (type) {
      case SectionType.system:
        return 0;
      case SectionType.persona:
        return 1;
      case SectionType.instructions:
        return 2;
      case SectionType.constraints:
        return 3;
      case SectionType.context:
        return 4;
      case SectionType.knowledge:
        return 5;
      case SectionType.examples:
        return 6;
      case SectionType.tools:
        return 7;
      case SectionType.custom:
        return 8;
    }
  }

  bool _evaluateCondition(String expression, ProfileContext context) {
    try {
      final lexer = Lexer(expression);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final evalContext = EvaluationContext.from(
        inputs: context.toMap(),
      );

      final evaluator = ExpressionEvaluator(evalContext);
      final result = evaluator.evaluate(ast);

      if (result.success) {
        final value = result.value;
        if (value is bool) return value;
        if (value == null) return false;
        if (value is num) return value != 0;
        if (value is String) return value.isNotEmpty;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String> _renderSection(
    ProfileSection section,
    ProfileContext context,
  ) async {
    var content = section.content;

    // Process template expressions
    if (section.hasTemplateExpressions) {
      content = await _processTemplate(content, context);
    }

    // Render children if present
    if (section.children.isNotEmpty) {
      final childBuffer = StringBuffer();
      if (content.isNotEmpty) {
        childBuffer.write(content);
      }

      for (final child in section.children) {
        if (!child.enabled) continue;
        if (child.condition != null &&
            !_evaluateCondition(child.condition!, context)) {
          continue;
        }

        final childContent = await _renderSection(child, context);
        if (childContent.isNotEmpty) {
          if (childBuffer.isNotEmpty) {
            childBuffer.write(options.childSeparator);
          }
          childBuffer.write(childContent);
        }
      }

      content = childBuffer.toString();
    }

    // Apply section wrapper if configured
    if (options.wrapSections && content.isNotEmpty) {
      content = _wrapSection(section, content);
    }

    return content;
  }

  Future<String> _processTemplate(
    String template,
    ProfileContext context,
  ) async {
    // Process ${...} expressions
    final dollarPattern = RegExp(r'\$\{([^}]+)\}');
    var result = template;

    for (final match in dollarPattern.allMatches(template)) {
      final expression = match.group(1)!;
      final value = await _evaluateExpression(expression, context);
      result = result.replaceFirst(match.group(0)!, _stringify(value));
    }

    // Process {{...}} expressions (if different syntax needed)
    final bracePattern = RegExp(r'\{\{([^}]+)\}\}');
    for (final match in bracePattern.allMatches(result)) {
      final expression = match.group(1)!.trim();
      final value = await _evaluateExpression(expression, context);
      result = result.replaceFirst(match.group(0)!, _stringify(value));
    }

    return result;
  }

  Future<dynamic> _evaluateExpression(
    String expression,
    ProfileContext context,
  ) async {
    try {
      final lexer = Lexer(expression);
      final tokens = lexer.tokenize();
      final parser = Parser(tokens);
      final ast = parser.parse();

      final evalContext = EvaluationContext.from(
        inputs: context.toMap(),
      );

      final evaluator = ExpressionEvaluator(evalContext);
      final result = evaluator.evaluate(ast);

      return result.success ? result.value : '';
    } catch (_) {
      return '';
    }
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) return value.join(', ');
    if (value is Map) return value.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    return value.toString();
  }

  String _wrapSection(ProfileSection section, String content) {
    final header = options.sectionHeaderFormat
        .replaceAll('{name}', section.name)
        .replaceAll('{type}', section.type.name);
    final footer = options.sectionFooterFormat
        .replaceAll('{name}', section.name)
        .replaceAll('{type}', section.type.name);

    if (header.isEmpty && footer.isEmpty) return content;

    final buffer = StringBuffer();
    if (header.isNotEmpty) {
      buffer.writeln(header);
    }
    buffer.write(content);
    if (footer.isNotEmpty) {
      buffer.writeln();
      buffer.write(footer);
    }
    return buffer.toString();
  }
}

/// Options for profile rendering.
class ProfileRenderOptions {
  /// Section ordering strategy.
  final SectionOrdering ordering;

  /// Separator between sections.
  final String sectionSeparator;

  /// Separator between child sections.
  final String childSeparator;

  /// Whether to wrap sections with headers/footers.
  final bool wrapSections;

  /// Section header format.
  final String sectionHeaderFormat;

  /// Section footer format.
  final String sectionFooterFormat;

  /// Whether to include disabled sections.
  final bool includeDisabled;

  const ProfileRenderOptions({
    this.ordering = SectionOrdering.byPriority,
    this.sectionSeparator = '\n\n',
    this.childSeparator = '\n',
    this.wrapSections = false,
    this.sectionHeaderFormat = '## {name}',
    this.sectionFooterFormat = '',
    this.includeDisabled = false,
  });

  ProfileRenderOptions copyWith({
    SectionOrdering? ordering,
    String? sectionSeparator,
    String? childSeparator,
    bool? wrapSections,
    String? sectionHeaderFormat,
    String? sectionFooterFormat,
    bool? includeDisabled,
  }) {
    return ProfileRenderOptions(
      ordering: ordering ?? this.ordering,
      sectionSeparator: sectionSeparator ?? this.sectionSeparator,
      childSeparator: childSeparator ?? this.childSeparator,
      wrapSections: wrapSections ?? this.wrapSections,
      sectionHeaderFormat: sectionHeaderFormat ?? this.sectionHeaderFormat,
      sectionFooterFormat: sectionFooterFormat ?? this.sectionFooterFormat,
      includeDisabled: includeDisabled ?? this.includeDisabled,
    );
  }
}

/// A rendered section.
class RenderedSection {
  /// Section name.
  final String name;

  /// Section type.
  final SectionType type;

  /// Rendered content.
  final String content;

  /// Original priority.
  final int priority;

  const RenderedSection({
    required this.name,
    required this.type,
    required this.content,
    required this.priority,
  });

  @override
  String toString() => content;
}
