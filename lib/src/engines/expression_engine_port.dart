/// Expression Engine Port - Internal engine contract for condition/format.
///
/// See docs/03_DDD/core-engines.md §5.
library;

import '../appraisal/appraisal_result.dart';
import '../decision/policy_condition.dart';
import '../expression/expression_style.dart';
import '../runtime/runtime_context.dart';

// FormattedResponse is defined in mcp_bundle (Contract Layer).
export 'package:mcp_bundle/src/types/expression_style.dart'
    show FormattedResponse;

/// Engine contract for expression formatting and condition evaluation.
abstract class ExpressionEnginePort {
  /// Format content according to style.
  Future<FormattedResponse> format(
    String content,
    ExpressionStyle style,
    RuntimeProfileContext context,
  );

  /// Evaluate expression policy condition.
  Future<bool> evaluateCondition(
    PolicyCondition condition,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  );

  /// Get hedging phrases for uncertainty level.
  List<String> getHedgingPhrases(
    double uncertainty,
    HedgingConfig? config,
  );

  /// Adjust tone of content.
  Future<String> adjustTone(
    String content,
    ToneConfig tone,
    RuntimeProfileContext context,
  );

  /// Restructure content format.
  Future<String> restructure(
    String content,
    FormatConfig format,
    RuntimeProfileContext context,
  );
}

/// Identity engine port: returns content unchanged.
class PassthroughExpressionEnginePort implements ExpressionEnginePort {
  const PassthroughExpressionEnginePort();

  @override
  Future<FormattedResponse> format(
    String content,
    ExpressionStyle style,
    RuntimeProfileContext context,
  ) async {
    return FormattedResponse(content: content, appliedStyle: style);
  }

  @override
  Future<bool> evaluateCondition(
    PolicyCondition condition,
    AppraisalResult appraisal,
    RuntimeProfileContext context,
  ) async {
    final metrics = <String, double>{};
    for (final entry in appraisal.metrics.entries) {
      metrics[entry.key] = entry.value.normalizedValue;
    }
    return condition.evaluate(metrics, appraisal.aggregatedScore);
  }

  @override
  List<String> getHedgingPhrases(
    double uncertainty,
    HedgingConfig? config,
  ) =>
      const [];

  @override
  Future<String> adjustTone(
    String content,
    ToneConfig tone,
    RuntimeProfileContext context,
  ) async {
    return content;
  }

  @override
  Future<String> restructure(
    String content,
    FormatConfig format,
    RuntimeProfileContext context,
  ) async {
    return content;
  }
}
