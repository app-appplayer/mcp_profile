/// ExpressionPortAdapter - Implements mcp_bundle's [ExpressionPort].
///
/// 0.2.0 per docs/03_DDD/core-adapters.md §3.4.
///
/// Bridges the four ExpressionPort operations:
///   - format(template, variables)   — mustache-style substitution
///   - validate(template)             — parse check
///   - extractVariables(template)     — deduplicated reference list
///   - render(style, data)            — ExpressionFormatter delegation
///
/// Internally delegates to `ExpressionEvaluator` (template engine) and
/// `ExpressionFormatter` (style-driven rendering). Callers that need the
/// rich internal `ExpressionEnginePort` (condition evaluation, tone/format
/// adjustment) wire the engine directly rather than through this adapter.
library;

import 'package:mcp_bundle/ports.dart' as bundle;
import 'package:mcp_bundle/src/types/expression_style.dart' as bundle_style;

import '../expression/expression_formatter.dart';
import '../expression/expression_style.dart' as local_style;

/// Adapter implementing mcp_bundle's [bundle.ExpressionPort].
class ExpressionPortAdapter implements bundle.ExpressionPort {
  /// Variable pattern: {{variableName}} or {{nested.path}}
  static final _variablePattern = RegExp(r'\{\{\s*([\w]+(?:\.[\w]+)*)\s*\}\}');

  final ExpressionStyleFormatter _formatter;

  ExpressionPortAdapter({
    ExpressionStyleFormatter? formatter,
  }) : _formatter = formatter ?? const ExpressionStyleFormatter();

  @override
  String format(String template, Map<String, dynamic> variables) {
    return template.replaceAllMapped(_variablePattern, (match) {
      final key = match.group(1)!;
      final value = _resolveVariable(key, variables);
      return value?.toString() ?? '';
    });
  }

  @override
  bool validate(String template) {
    // Balance check: every `{{` must have a matching `}}`.
    final open = RegExp(r'\{\{').allMatches(template).length;
    final close = RegExp(r'\}\}').allMatches(template).length;
    if (open != close) return false;

    // Every captured name must be a valid identifier path.
    final identPattern = RegExp(r'^[\w]+(?:\.[\w]+)*$');
    for (final match in _variablePattern.allMatches(template)) {
      final key = match.group(1)!;
      if (key.isEmpty || !identPattern.hasMatch(key)) return false;
    }
    return true;
  }

  @override
  List<String> extractVariables(String template) {
    final seen = <String>{};
    final out = <String>[];
    for (final m in _variablePattern.allMatches(template)) {
      final name = m.group(1)!;
      if (seen.add(name)) out.add(name);
    }
    return out;
  }

  @override
  String render(bundle_style.ExpressionStyle style, Map<String, dynamic> data) {
    // Translate bundle ExpressionStyle → local ExpressionStyle. The two
    // types are currently structurally compatible; fall back to passthrough
    // if the local formatter doesn't accept it directly.
    final content = (data['content'] as String?) ??
        data.values.whereType<String>().firstOrNull ??
        '';
    try {
      final localStyle = _coerceStyle(style);
      return _formatter.format(content: content, style: localStyle);
    } catch (_) {
      // On any incompatibility, fall back to variable substitution or
      // plain content — never throw from a public port call.
      return format(content, data);
    }
  }

  /// Coerce a bundle ExpressionStyle into the local ExpressionStyle.
  /// The two types are structurally identical in 0.2.0 (local is a
  /// re-export of the bundle type), so this is effectively an identity
  /// cast. Falls back to defaultStyle if a future divergence breaks it.
  local_style.ExpressionStyle _coerceStyle(bundle_style.ExpressionStyle style) {
    // The local ExpressionStyle is a re-export of the bundle type, so
    // [style] is the same runtime type. This function exists for the
    // case a future divergence introduces separate local types.
    return style;
  }

  /// Resolve a nested variable path like `user.profile.name`.
  dynamic _resolveVariable(String path, Map<String, dynamic> variables) {
    final parts = path.split('.');
    dynamic current = variables;
    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }
}

extension on Iterable<String> {
  String? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
