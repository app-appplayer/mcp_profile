/// Expression Evaluator - Template expression evaluation for profiles.
///
/// Provides expression parsing and evaluation for dynamic profile content.
library;

import '../definition/profile.dart';

/// Evaluates template expressions in profile content.
class ExpressionEvaluator {
  /// Expression syntax type.
  final ExpressionSyntax syntax;

  /// Custom functions available in expressions.
  final Map<String, ExpressionFunction> _functions = {};

  /// Filters available for value transformation.
  final Map<String, ExpressionFilter> _filters = {};

  ExpressionEvaluator({
    this.syntax = ExpressionSyntax.mustache,
  }) {
    _registerBuiltinFunctions();
    _registerBuiltinFilters();
  }

  /// Register a custom function.
  void registerFunction(String name, ExpressionFunction function) {
    _functions[name] = function;
  }

  /// Register a custom filter.
  void registerFilter(String name, ExpressionFilter filter) {
    _filters[name] = filter;
  }

  /// Evaluate a template string with the given context.
  String evaluate(String template, ProfileContext context) {
    if (!_hasExpressions(template)) {
      return template;
    }

    var result = template;

    // Process expressions based on syntax
    switch (syntax) {
      case ExpressionSyntax.mustache:
        result = _evaluateMustache(result, context);
        break;
      case ExpressionSyntax.dartInterpolation:
        result = _evaluateDartInterpolation(result, context);
        break;
      case ExpressionSyntax.both:
        result = _evaluateMustache(result, context);
        result = _evaluateDartInterpolation(result, context);
        break;
    }

    return result;
  }

  /// Evaluate a condition expression.
  bool evaluateCondition(String condition, ProfileContext context) {
    if (condition.isEmpty) return true;

    final trimmed = condition.trim();

    // Simple boolean checks
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    // Check for existence: "variable" or "!variable"
    if (trimmed.startsWith('!')) {
      final varName = trimmed.substring(1).trim();
      return !_isTruthy(context.get(varName));
    }

    // Comparison expressions
    final comparisonMatch = RegExp(r'(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)').firstMatch(trimmed);
    if (comparisonMatch != null) {
      final left = _resolveValue(comparisonMatch.group(1)!.trim(), context);
      final operator = comparisonMatch.group(2)!;
      final right = _resolveValue(comparisonMatch.group(3)!.trim(), context);
      return _compare(left, operator, right);
    }

    // Simple variable existence check
    return _isTruthy(context.get(trimmed));
  }

  /// Extract all variable names from a template.
  Set<String> extractVariables(String template) {
    final variables = <String>{};

    // Extract mustache variables
    final mustachePattern = RegExp(r'\{\{\s*([^}|]+?)(?:\s*\|[^}]*)?\s*\}\}');
    for (final match in mustachePattern.allMatches(template)) {
      variables.add(match.group(1)!.trim());
    }

    // Extract dart interpolation variables
    final dartPattern = RegExp(r'\$\{([^}]+)\}');
    for (final match in dartPattern.allMatches(template)) {
      variables.add(match.group(1)!.trim());
    }

    // Extract simple dart variables
    final simplePattern = RegExp(r'\$([a-zA-Z_][a-zA-Z0-9_]*)');
    for (final match in simplePattern.allMatches(template)) {
      variables.add(match.group(1)!);
    }

    return variables;
  }

  /// Validate a template for syntax errors.
  List<ExpressionError> validate(String template) {
    final errors = <ExpressionError>[];

    // Check for unclosed mustache braces
    var openCount = '{{'.allMatches(template).length;
    var closeCount = '}}'.allMatches(template).length;
    if (openCount != closeCount) {
      errors.add(ExpressionError(
        type: ExpressionErrorType.unclosedExpression,
        message: 'Unbalanced mustache braces: $openCount open, $closeCount close',
      ));
    }

    // Check for unclosed dart interpolation
    final dartOpen = r'${'.allMatches(template).length;
    final dartClose = template.split(r'${').skip(1).where((s) => s.contains('}')).length;
    if (dartOpen != dartClose) {
      errors.add(ExpressionError(
        type: ExpressionErrorType.unclosedExpression,
        message: 'Unbalanced dart interpolation braces',
      ));
    }

    return errors;
  }

  // =========================================================================
  // Private Methods
  // =========================================================================

  bool _hasExpressions(String template) {
    return template.contains('{{') ||
        template.contains(r'${') ||
        template.contains(r'$');
  }

  String _evaluateMustache(String template, ProfileContext context) {
    // Pattern: {{ variable | filter1 | filter2 }}
    final pattern = RegExp(r'\{\{\s*(.+?)\s*\}\}');

    return template.replaceAllMapped(pattern, (match) {
      final expression = match.group(1)!;
      return _evaluateMustacheExpression(expression, context);
    });
  }

  String _evaluateMustacheExpression(String expression, ProfileContext context) {
    // Split by pipe for filters
    final parts = expression.split('|').map((s) => s.trim()).toList();

    // Get base value
    var value = _resolveValue(parts[0], context);

    // Apply filters
    for (var i = 1; i < parts.length; i++) {
      final filterExpr = parts[i];
      value = _applyFilter(filterExpr, value);
    }

    return _stringify(value);
  }

  String _evaluateDartInterpolation(String template, ProfileContext context) {
    // Pattern: ${expression}
    var result = template.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (match) {
      final varPath = match.group(1)!.trim();
      final value = _resolveValue(varPath, context);
      return _stringify(value);
    });

    // Pattern: $variable (simple)
    result = result.replaceAllMapped(RegExp(r'\$([a-zA-Z_][a-zA-Z0-9_]*)'), (match) {
      final varName = match.group(1)!;
      final value = context.get(varName);
      return _stringify(value);
    });

    return result;
  }

  dynamic _resolveValue(String expression, ProfileContext context) {
    final trimmed = expression.trim();

    // String literal
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      return trimmed.substring(1, trimmed.length - 1);
    }

    // Number literal
    final numValue = num.tryParse(trimmed);
    if (numValue != null) return numValue;

    // Boolean literal
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    // Null literal
    if (trimmed == 'null') return null;

    // Function call
    if (trimmed.contains('(')) {
      return _evaluateFunction(trimmed, context);
    }

    // Variable reference
    return context.get(trimmed);
  }

  dynamic _evaluateFunction(String expression, ProfileContext context) {
    final match = RegExp(r'(\w+)\s*\(([^)]*)\)').firstMatch(expression);
    if (match == null) return expression;

    final funcName = match.group(1)!;
    final argsStr = match.group(2)!;

    final function = _functions[funcName];
    if (function == null) {
      return '{{unknown function: $funcName}}';
    }

    // Parse arguments
    final args = argsStr.isEmpty
        ? <dynamic>[]
        : argsStr.split(',').map((a) => _resolveValue(a.trim(), context)).toList();

    return function(args, context);
  }

  dynamic _applyFilter(String filterExpr, dynamic value) {
    // Parse filter name and arguments
    final match = RegExp(r'(\w+)(?:\s*:\s*(.+))?').firstMatch(filterExpr);
    if (match == null) return value;

    final filterName = match.group(1)!;
    final argsStr = match.group(2);

    final filter = _filters[filterName];
    if (filter == null) return value;

    final args = argsStr?.split(',').map((a) => a.trim()).toList() ?? [];
    return filter(value, args);
  }

  bool _compare(dynamic left, String operator, dynamic right) {
    switch (operator) {
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '>':
        return (left as num) > (right as num);
      case '<':
        return (left as num) < (right as num);
      case '>=':
        return (left as num) >= (right as num);
      case '<=':
        return (left as num) <= (right as num);
      default:
        return false;
    }
  }

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  void _registerBuiltinFunctions() {
    // Length function
    _functions['len'] = (args, context) {
      if (args.isEmpty) return 0;
      final value = args[0];
      if (value is String) return value.length;
      if (value is List) return value.length;
      if (value is Map) return value.length;
      return 0;
    };

    // Default value function
    _functions['default'] = (args, context) {
      if (args.length < 2) return args.isNotEmpty ? args[0] : null;
      return args[0] ?? args[1];
    };

    // Date formatting
    _functions['now'] = (args, context) {
      return DateTime.now().toIso8601String();
    };

    // Join array
    _functions['join'] = (args, context) {
      if (args.isEmpty) return '';
      final list = args[0];
      final separator = args.length > 1 ? args[1].toString() : ', ';
      if (list is List) {
        return list.join(separator);
      }
      return list.toString();
    };
  }

  void _registerBuiltinFilters() {
    // String filters
    _filters['upper'] = (value, args) => value.toString().toUpperCase();
    _filters['lower'] = (value, args) => value.toString().toLowerCase();
    _filters['trim'] = (value, args) => value.toString().trim();
    _filters['capitalize'] = (value, args) {
      final s = value.toString();
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1);
    };

    // Default value filter
    _filters['default'] = (value, args) {
      if (value == null || (value is String && value.isEmpty)) {
        return args.isNotEmpty ? args[0] : '';
      }
      return value;
    };

    // Truncate filter
    _filters['truncate'] = (value, args) {
      final s = value.toString();
      final length = args.isNotEmpty ? int.tryParse(args[0]) ?? 50 : 50;
      if (s.length <= length) return s;
      return '${s.substring(0, length)}...';
    };

    // JSON encode
    _filters['json'] = (value, args) {
      if (value is Map || value is List) {
        // Simple JSON encoding
        return value.toString();
      }
      return '"$value"';
    };
  }
}

/// Expression syntax types.
enum ExpressionSyntax {
  /// Mustache syntax: {{ variable }}
  mustache,

  /// Dart string interpolation: ${variable} or $variable
  dartInterpolation,

  /// Support both syntaxes
  both,
}

/// A function that can be called from expressions.
typedef ExpressionFunction = dynamic Function(
  List<dynamic> args,
  ProfileContext context,
);

/// A filter that transforms values in expressions.
typedef ExpressionFilter = dynamic Function(
  dynamic value,
  List<String> args,
);

/// Expression evaluation error.
class ExpressionError {
  /// Error type.
  final ExpressionErrorType type;

  /// Error message.
  final String message;

  /// Position in template (if known).
  final int? position;

  const ExpressionError({
    required this.type,
    required this.message,
    this.position,
  });

  @override
  String toString() => 'ExpressionError(${type.name}): $message';
}

/// Expression error types.
enum ExpressionErrorType {
  /// Syntax error in expression.
  syntaxError,

  /// Unclosed expression.
  unclosedExpression,

  /// Unknown variable.
  unknownVariable,

  /// Unknown function.
  unknownFunction,

  /// Unknown filter.
  unknownFilter,

  /// Type error.
  typeError,

  /// Evaluation error.
  evaluationError,
}
