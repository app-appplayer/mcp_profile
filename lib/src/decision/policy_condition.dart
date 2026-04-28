/// Policy Condition Types - Conditions for decision policy matching.
///
/// As per spec/03-decision-policy-schema.md §4.
library;

// =============================================================================
// Policy (base interface for all policy types)
// =============================================================================

/// Base interface for all policy types (Decision, Expression).
///
/// Used as a generic constraint for [ParallelPolicyEvaluator]
/// per design/06-concurrency.md §3.
abstract class Policy {
  /// Unique policy ID.
  String get id;

  /// Evaluation priority (higher first).
  int get priority;

  /// When this policy applies.
  PolicyCondition get condition;
}

// =============================================================================
// PolicyCondition (§4)
// =============================================================================

/// Condition for when a policy applies.
sealed class PolicyCondition {
  const PolicyCondition();

  /// Evaluate condition against metric values.
  bool evaluate(Map<String, double> metrics, double aggregatedScore);

  /// Create from JSON.
  factory PolicyCondition.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'threshold' => ThresholdCondition.fromJson(json),
      'expression' => ExpressionCondition.fromJson(json),
      'composite' => CompositeCondition.fromJson(json),
      _ => throw ArgumentError('Unknown condition type: $type'),
    };
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson();
}

// =============================================================================
// ThresholdCondition (§4.1)
// =============================================================================

/// Simple metric threshold comparison.
class ThresholdCondition extends PolicyCondition {
  /// Metric ID to compare.
  final String metric;

  /// Comparison operator.
  final ComparisonOperator operator;

  /// Value to compare against (single or range).
  final Object value; // double or List<double> for between/outside

  const ThresholdCondition({
    required this.metric,
    required this.operator,
    required this.value,
  });

  @override
  bool evaluate(Map<String, double> metrics, double aggregatedScore) {
    final metricValue = metric == 'aggregatedScore'
        ? aggregatedScore
        : metrics[metric];

    if (metricValue == null) return false;

    return switch (operator) {
      ComparisonOperator.greaterThan => metricValue > (value as double),
      ComparisonOperator.greaterThanOrEqual =>
        metricValue >= (value as double),
      ComparisonOperator.lessThan => metricValue < (value as double),
      ComparisonOperator.lessThanOrEqual => metricValue <= (value as double),
      ComparisonOperator.equal => metricValue == (value as double),
      ComparisonOperator.notEqual => metricValue != (value as double),
      ComparisonOperator.between => _evaluateBetween(metricValue),
      ComparisonOperator.outside => _evaluateOutside(metricValue),
    };
  }

  bool _evaluateBetween(double metricValue) {
    if (value is! List) return false;
    final range = value as List;
    if (range.length != 2) return false;
    final min = (range[0] as num).toDouble();
    final max = (range[1] as num).toDouble();
    return metricValue >= min && metricValue <= max;
  }

  bool _evaluateOutside(double metricValue) {
    return !_evaluateBetween(metricValue);
  }

  factory ThresholdCondition.fromJson(Map<String, dynamic> json) {
    return ThresholdCondition(
      metric: json['metric'] as String,
      operator: _parseOperator(json['operator'] as String),
      value: json['value'],
    );
  }

  static ComparisonOperator _parseOperator(String op) {
    return switch (op) {
      '>' => ComparisonOperator.greaterThan,
      '>=' => ComparisonOperator.greaterThanOrEqual,
      '<' => ComparisonOperator.lessThan,
      '<=' => ComparisonOperator.lessThanOrEqual,
      '==' => ComparisonOperator.equal,
      '!=' => ComparisonOperator.notEqual,
      'between' => ComparisonOperator.between,
      'outside' => ComparisonOperator.outside,
      _ => throw ArgumentError('Unknown operator: $op'),
    };
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'threshold',
        'metric': metric,
        'operator': operator.toJsonString(),
        'value': value,
      };
}

/// Comparison operators for threshold conditions.
enum ComparisonOperator {
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  equal,
  notEqual,
  between,
  outside,
}

extension ComparisonOperatorExtension on ComparisonOperator {
  String toJsonString() {
    return switch (this) {
      ComparisonOperator.greaterThan => '>',
      ComparisonOperator.greaterThanOrEqual => '>=',
      ComparisonOperator.lessThan => '<',
      ComparisonOperator.lessThanOrEqual => '<=',
      ComparisonOperator.equal => '==',
      ComparisonOperator.notEqual => '!=',
      ComparisonOperator.between => 'between',
      ComparisonOperator.outside => 'outside',
    };
  }
}

// =============================================================================
// ExpressionCondition (§4.2)
// =============================================================================

/// Complex condition using expression language.
class ExpressionCondition extends PolicyCondition {
  /// Expression to evaluate.
  final String expression;

  const ExpressionCondition({required this.expression});

  @override
  bool evaluate(Map<String, double> metrics, double aggregatedScore) {
    return _evaluateExpression(expression, metrics, aggregatedScore);
  }

  /// Evaluate simple boolean expressions.
  bool _evaluateExpression(
    String expr,
    Map<String, double> metrics,
    double aggregatedScore,
  ) {
    final trimmed = expr.trim();

    // Handle AND (&&)
    if (trimmed.contains('&&')) {
      final parts = _splitAtTopLevel(trimmed, '&&');
      return parts.every((p) => _evaluateExpression(p, metrics, aggregatedScore));
    }

    // Handle OR (||)
    if (trimmed.contains('||')) {
      final parts = _splitAtTopLevel(trimmed, '||');
      return parts.any((p) => _evaluateExpression(p, metrics, aggregatedScore));
    }

    // Handle NOT (!)
    if (trimmed.startsWith('!')) {
      return !_evaluateExpression(
        trimmed.substring(1).trim(),
        metrics,
        aggregatedScore,
      );
    }

    // Handle parentheses
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      return _evaluateExpression(
        trimmed.substring(1, trimmed.length - 1),
        metrics,
        aggregatedScore,
      );
    }

    // Handle simple comparisons: metric > value
    final comparisonMatch = RegExp(
      r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*(>=|<=|>|<|==|!=)\s*([0-9.]+)$',
    ).firstMatch(trimmed);

    if (comparisonMatch != null) {
      final metric = comparisonMatch.group(1)!;
      final op = comparisonMatch.group(2)!;
      final value = double.parse(comparisonMatch.group(3)!);

      final metricValue = metric == 'aggregatedScore'
          ? aggregatedScore
          : metrics[metric] ?? 0.0;

      return switch (op) {
        '>' => metricValue > value,
        '>=' => metricValue >= value,
        '<' => metricValue < value,
        '<=' => metricValue <= value,
        '==' => metricValue == value,
        '!=' => metricValue != value,
        _ => false,
      };
    }

    // Handle (1 - metric) patterns
    final invertMatch = RegExp(
      r'^\(\s*1\s*-\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\)\s*(>=|<=|>|<|==|!=)\s*([0-9.]+)$',
    ).firstMatch(trimmed);

    if (invertMatch != null) {
      final metric = invertMatch.group(1)!;
      final op = invertMatch.group(2)!;
      final value = double.parse(invertMatch.group(3)!);

      final metricValue = 1.0 - (metrics[metric] ?? 0.0);

      return switch (op) {
        '>' => metricValue > value,
        '>=' => metricValue >= value,
        '<' => metricValue < value,
        '<=' => metricValue <= value,
        '==' => metricValue == value,
        '!=' => metricValue != value,
        _ => false,
      };
    }

    return false;
  }

  /// Split expression at top-level operator (outside parentheses).
  List<String> _splitAtTopLevel(String expr, String op) {
    final result = <String>[];
    var depth = 0;
    var start = 0;

    for (var i = 0; i < expr.length - op.length + 1; i++) {
      final char = expr[i];
      if (char == '(') depth++;
      if (char == ')') depth--;

      if (depth == 0 && expr.substring(i, i + op.length) == op) {
        result.add(expr.substring(start, i).trim());
        start = i + op.length;
        i += op.length - 1;
      }
    }
    result.add(expr.substring(start).trim());

    return result;
  }

  factory ExpressionCondition.fromJson(Map<String, dynamic> json) {
    return ExpressionCondition(
      expression: json['expression'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'expression',
        'expression': expression,
      };
}

// =============================================================================
// AlwaysTrueCondition (for default fallback)
// =============================================================================

/// A condition that always evaluates to true (for default case).
class AlwaysTrueCondition extends PolicyCondition {
  const AlwaysTrueCondition();

  @override
  bool evaluate(Map<String, double> metrics, double aggregatedScore) => true;

  @override
  Map<String, dynamic> toJson() => {'type': 'always_true'};
}

// =============================================================================
// CompositeCondition (§4.3)
// =============================================================================

/// Composite condition combining multiple conditions.
class CompositeCondition extends PolicyCondition {
  /// All conditions must match (AND).
  final List<PolicyCondition>? all;

  /// Any condition must match (OR).
  final List<PolicyCondition>? any;

  /// Condition must not match (NOT).
  final PolicyCondition? not;

  const CompositeCondition({
    this.all,
    this.any,
    this.not,
  });

  @override
  bool evaluate(Map<String, double> metrics, double aggregatedScore) {
    // Handle NOT
    if (not != null) {
      return !not!.evaluate(metrics, aggregatedScore);
    }

    // Handle ALL (AND)
    if (all != null && all!.isNotEmpty) {
      return all!.every((c) => c.evaluate(metrics, aggregatedScore));
    }

    // Handle ANY (OR)
    if (any != null && any!.isNotEmpty) {
      return any!.any((c) => c.evaluate(metrics, aggregatedScore));
    }

    // No conditions specified
    return true;
  }

  factory CompositeCondition.fromJson(Map<String, dynamic> json) {
    return CompositeCondition(
      all: (json['all'] as List<dynamic>?)
          ?.map((e) => PolicyCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      any: (json['any'] as List<dynamic>?)
          ?.map((e) => PolicyCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      not: json['not'] != null
          ? PolicyCondition.fromJson(json['not'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'composite',
        if (all != null) 'all': all!.map((c) => c.toJson()).toList(),
        if (any != null) 'any': any!.map((c) => c.toJson()).toList(),
        if (not != null) 'not': not!.toJson(),
      };
}
