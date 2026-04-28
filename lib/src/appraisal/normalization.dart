/// Normalization Config - Normalize raw values to 0-1 range.
///
/// As per spec/02-appraisal-metrics-schema.md §5.
library;

import 'dart:math' as math;

// =============================================================================
// NormalizationConfig (§5)
// =============================================================================

/// Configuration for normalizing raw metric values to 0-1 range.
sealed class NormalizationConfig {
  const NormalizationConfig();

  /// Normalize a raw value.
  double normalize(double value);

  /// Create from JSON.
  factory NormalizationConfig.fromJson(Map<String, dynamic> json) {
    final method = json['method'] as String;
    return switch (method) {
      'minmax' => MinMaxNormalization.fromJson(json),
      'zscore' => ZScoreNormalization.fromJson(json),
      'sigmoid' => SigmoidNormalization.fromJson(json),
      'log' => LogNormalization.fromJson(json),
      'custom' => CustomNormalization.fromJson(json),
      'passthrough' => const PassthroughNormalization(),
      'boolean' => BooleanNormalization.fromJson(json),
      _ => throw ArgumentError('Unknown normalization method: $method'),
    };
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson();
}

// =============================================================================
// MinMax Normalization
// =============================================================================

/// MinMax normalization: scale value from [min, max] to [0, 1].
class MinMaxNormalization extends NormalizationConfig {
  /// Minimum value of input range.
  final double min;

  /// Maximum value of input range.
  final double max;

  const MinMaxNormalization({
    this.min = 0.0,
    this.max = 1.0,
  });

  @override
  double normalize(double value) {
    if (max == min) return 0.5;
    final normalized = (value - min) / (max - min);
    return normalized.clamp(0.0, 1.0);
  }

  factory MinMaxNormalization.fromJson(Map<String, dynamic> json) {
    return MinMaxNormalization(
      min: (json['min'] as num?)?.toDouble() ?? 0.0,
      max: (json['max'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'method': 'minmax',
        'min': min,
        'max': max,
      };
}

// =============================================================================
// ZScore Normalization
// =============================================================================

/// ZScore normalization: standardize using mean and standard deviation.
/// Output is clamped to [0, 1] using sigmoid on z-score.
class ZScoreNormalization extends NormalizationConfig {
  /// Population mean.
  final double mean;

  /// Population standard deviation.
  final double stddev;

  const ZScoreNormalization({
    required this.mean,
    required this.stddev,
  });

  @override
  double normalize(double value) {
    if (stddev == 0) return 0.5;
    final zScore = (value - mean) / stddev;
    // Apply sigmoid to map z-score to [0, 1]
    return 1 / (1 + math.exp(-zScore));
  }

  factory ZScoreNormalization.fromJson(Map<String, dynamic> json) {
    return ZScoreNormalization(
      mean: (json['mean'] as num).toDouble(),
      stddev: (json['stddev'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'method': 'zscore',
        'mean': mean,
        'stddev': stddev,
      };
}

// =============================================================================
// Sigmoid Normalization
// =============================================================================

/// Sigmoid normalization: smooth S-curve transition around midpoint.
class SigmoidNormalization extends NormalizationConfig {
  /// Center point of the sigmoid (where output = 0.5).
  final double midpoint;

  /// Steepness of the curve (higher = sharper transition).
  final double steepness;

  const SigmoidNormalization({
    this.midpoint = 50.0,
    this.steepness = 0.1,
  });

  @override
  double normalize(double value) {
    final x = (value - midpoint) * steepness;
    return 1 / (1 + math.exp(-x));
  }

  factory SigmoidNormalization.fromJson(Map<String, dynamic> json) {
    return SigmoidNormalization(
      midpoint: (json['midpoint'] as num?)?.toDouble() ?? 50.0,
      steepness: (json['steepness'] as num?)?.toDouble() ?? 0.1,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'method': 'sigmoid',
        'midpoint': midpoint,
        'steepness': steepness,
      };
}

// =============================================================================
// Log Normalization
// =============================================================================

/// Logarithmic normalization: log(value + 1) / scale, clamped to [0, 1].
class LogNormalization extends NormalizationConfig {
  /// Scale factor for the log value.
  final double scale;

  const LogNormalization({
    this.scale = 5.0,
  });

  @override
  double normalize(double value) {
    if (value < 0) return 0.0;
    final logValue = math.log(value + 1) / scale;
    return logValue.clamp(0.0, 1.0);
  }

  factory LogNormalization.fromJson(Map<String, dynamic> json) {
    return LogNormalization(
      scale: (json['scale'] as num?)?.toDouble() ?? 5.0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'method': 'log',
        'scale': scale,
      };
}

// =============================================================================
// Passthrough Normalization
// =============================================================================

/// Passthrough normalization: value is already in 0-1 range, just clamp.
class PassthroughNormalization extends NormalizationConfig {
  const PassthroughNormalization();

  @override
  double normalize(double value) {
    return value.clamp(0.0, 1.0);
  }

  @override
  Map<String, dynamic> toJson() => {'method': 'passthrough'};
}

// =============================================================================
// Boolean Normalization
// =============================================================================

/// Boolean normalization: converts truthy/falsy to 1.0/0.0.
/// Threshold determines the boundary (default: 0.5).
/// Values >= threshold → 1.0, values < threshold → 0.0.
class BooleanNormalization extends NormalizationConfig {
  /// Threshold for boolean conversion.
  final double threshold;

  const BooleanNormalization({this.threshold = 0.5});

  @override
  double normalize(double value) {
    return value >= threshold ? 1.0 : 0.0;
  }

  factory BooleanNormalization.fromJson(Map<String, dynamic> json) {
    return BooleanNormalization(
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.5,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'method': 'boolean',
        if (threshold != 0.5) 'threshold': threshold,
      };
}

// =============================================================================
// Custom Normalization
// =============================================================================

/// Custom normalization using expression.
/// Expression should contain 'value' variable and return 0-1.
class CustomNormalization extends NormalizationConfig {
  /// Expression string.
  final String expression;

  /// Compiled evaluator (set by engine).
  final double Function(double)? _evaluator;

  const CustomNormalization({
    required this.expression,
    double Function(double)? evaluator,
  }) : _evaluator = evaluator;

  /// Create with evaluator.
  CustomNormalization withEvaluator(double Function(double) evaluator) {
    return CustomNormalization(
      expression: expression,
      evaluator: evaluator,
    );
  }

  @override
  double normalize(double value) {
    if (_evaluator != null) {
      return _evaluator!(value).clamp(0.0, 1.0);
    }
    // Fallback: simple built-in expression evaluation
    return _evaluateSimpleExpression(expression, value);
  }

  /// Simple built-in expression evaluation for common patterns.
  double _evaluateSimpleExpression(String expr, double value) {
    // Handle common patterns
    final trimmed = expr.trim();

    // clamp(log(value + 1) / 5, 0, 1)
    if (trimmed.startsWith('clamp(log(value + 1)')) {
      return (math.log(value + 1) / 5).clamp(0.0, 1.0);
    }

    // value / N pattern
    final divMatch = RegExp(r'^value\s*/\s*(\d+(?:\.\d+)?)$').firstMatch(trimmed);
    if (divMatch != null) {
      final divisor = double.parse(divMatch.group(1)!);
      return (value / divisor).clamp(0.0, 1.0);
    }

    // Fallback: return value clamped
    return value.clamp(0.0, 1.0);
  }

  factory CustomNormalization.fromJson(Map<String, dynamic> json) {
    return CustomNormalization(
      expression: json['expression'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'method': 'custom',
        'expression': expression,
      };
}
