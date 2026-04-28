/// Appraisal Engine - Runtime metric computation.
///
/// Computes appraisal metrics (Risk, Uncertainty, Urgency, Trust, Sentiment)
/// from FactGraph data as per spec/02-appraisal-metrics-schema.md.
library;

import 'dart:math' as math;

import 'package:mcp_bundle/ports.dart';

import 'appraisal_result.dart';
import 'metric_definition.dart';
import 'metric_source.dart';

// =============================================================================
// AppraisalEngine
// =============================================================================

/// Engine for computing appraisal metrics at runtime.
///
/// Implements the metric computation pipeline per spec/02:
/// 1. Fetch data from source (factgraph, computed, static, llm_derived)
/// 2. Compute raw value
/// 3. Apply normalization (§5)
/// 4. Apply inverse if configured
/// 5. Compute confidence (§9.4)
/// 6. Aggregate metrics (§7)
///
/// Consumes the capability-named `FactsPort` for all fact queries.
/// The `factsPort` is optional — when absent, `FactGraphSource`
/// metrics produce `(null, 0.0)` so that the outer runtime can
/// degrade gracefully.
class AppraisalEngine {
  /// Workspace identifier used in [FactQuery] requests.
  final String workspaceId;

  /// Facts port (optional).
  final FactsPort? factsPort;

  /// LLM port for llm_derived metrics (optional).
  final LlmPort? llmPort;

  /// Confidence threshold configuration.
  final ConfidenceThresholdConfig confidenceConfig;

  /// Metric value cache.
  final Map<String, _CachedMetric> _cache = {};

  /// LLM result cache (keyed by cacheKey per design/04-caching.md).
  final Map<String, _CachedLlmResult> _llmCache = {};

  /// Cache TTL.
  final Duration cacheTtl;

  AppraisalEngine({
    this.workspaceId = 'default',
    this.factsPort,
    this.llmPort,
    this.confidenceConfig = const ConfidenceThresholdConfig(),
    this.cacheTtl = const Duration(minutes: 5),
  });

  /// Compute appraisal metrics for an entity.
  ///
  /// [section] defines which metrics to compute and how to aggregate.
  /// [entityId] is the primary entity to appraise.
  /// [profileId] identifies the profile being applied.
  /// [contextId] identifies the context being appraised.
  Future<AppraisalResult> appraise({
    required AppraisalSection section,
    required String entityId,
    required String profileId,
    required String contextId,
    Period? period,
  }) async {
    final startTime = DateTime.now();
    final metrics = <String, MetricResult>{};
    final sourceCounts = <String, int>{};
    final missingMetrics = <String>[];
    final warnings = <String>[];

    // Context for computed metrics
    final computeContext = _ComputeContext(
      entityId: entityId,
      period: period,
      metrics: {},
      confidences: {},
      avgConfidence: 0.0,
      avgSourceReliability: 0.0,
      factCount: 0,
      evidenceCount: 0,
      conflictCount: 0,
    );

    // First pass: compute non-computed metrics
    for (final metricDef in section.metrics) {
      if (metricDef.source.type != MetricSourceType.computed) {
        final result = await _computeMetric(
          metricDef: metricDef,
          context: computeContext,
        );

        if (result != null) {
          metrics[metricDef.id] = result;
          computeContext.metrics[metricDef.id] = result.normalizedValue;
          computeContext.confidences[metricDef.id] = result.confidence;
          sourceCounts[result.sourceType.name] =
              (sourceCounts[result.sourceType.name] ?? 0) + 1;
        } else {
          missingMetrics.add(metricDef.id);
        }
      }
    }

    // Update context stats
    await _updateContextStats(computeContext, entityId, period);

    // Second pass: compute computed metrics
    for (final metricDef in section.metrics) {
      if (metricDef.source.type == MetricSourceType.computed) {
        final result = await _computeMetric(
          metricDef: metricDef,
          context: computeContext,
        );

        if (result != null) {
          metrics[metricDef.id] = result;
          computeContext.metrics[metricDef.id] = result.normalizedValue;
          computeContext.confidences[metricDef.id] = result.confidence;
          sourceCounts[result.sourceType.name] =
              (sourceCounts[result.sourceType.name] ?? 0) + 1;
        } else {
          missingMetrics.add(metricDef.id);
        }
      }
    }

    // Apply confidence threshold rules per §9.3
    final metricsRequiringEvidence = <String>[];
    for (final metricDef in section.metrics) {
      final result = metrics[metricDef.id];
      if (result != null) {
        // Step 3: confidence < fallbackThreshold → use defaultValue
        if (result.confidence < confidenceConfig.fallbackThreshold) {
          if (metricDef.defaultValue != null) {
            metrics[metricDef.id] = MetricResult(
              id: result.id,
              rawValue: metricDef.defaultValue,
              normalizedValue: metricDef.defaultValue!.clamp(0.0, 1.0),
              sourceType: metricDef.source.type,
              confidence: 1.0,
            );
            warnings.add(
              'Metric ${metricDef.id} used fallback value due to low confidence',
            );
          } else {
            // No default available, exclude metric
            metrics.remove(metricDef.id);
            missingMetrics.add(metricDef.id);
            warnings.add(
              'Metric ${metricDef.id} excluded: confidence below fallback threshold and no default',
            );
          }
          continue;
        }

        // Step 5: confidence < minConfidenceThreshold → exclude metric
        if (result.confidence < confidenceConfig.minConfidenceThreshold) {
          if (metricDef.defaultValue != null) {
            metrics[metricDef.id] = MetricResult(
              id: result.id,
              rawValue: metricDef.defaultValue,
              normalizedValue: metricDef.defaultValue!.clamp(0.0, 1.0),
              sourceType: metricDef.source.type,
              confidence: 1.0,
            );
            warnings.add(
              'Metric ${metricDef.id} replaced with default: confidence below minimum threshold',
            );
          } else {
            metrics.remove(metricDef.id);
            missingMetrics.add(metricDef.id);
            warnings.add(
              'Metric ${metricDef.id} excluded: confidence below minimum threshold',
            );
          }
          continue;
        }

        // Step 4: confidence < evidenceTriggerThreshold → flag for require_evidence
        if (result.confidence < confidenceConfig.evidenceTriggerThreshold &&
            confidenceConfig.triggerEvidenceOnLowConfidence) {
          metricsRequiringEvidence.add(metricDef.id);
          warnings.add(
            'Metric ${metricDef.id} has low confidence; evidence required',
          );
        }
      }
    }

    // Compute aggregated score
    final aggregatedScore = _aggregate(
      metrics: metrics,
      metricDefs: section.metrics,
      config: section.aggregation ?? const AggregationConfig(),
    );

    final duration = DateTime.now().difference(startTime);

    return AppraisalResult(
      profileId: profileId,
      contextId: contextId,
      asOf: startTime,
      metrics: metrics,
      aggregatedScore: aggregatedScore,
      metadata: AppraisalMetadata(
        computedAt: DateTime.now(),
        durationMs: duration.inMilliseconds,
        sourceCounts: sourceCounts,
        missingMetrics: missingMetrics,
        lowConfidenceMetrics: metrics.entries
            .where((e) => e.value.confidence < 0.5)
            .map((e) => e.key)
            .toList(),
        metricsRequiringEvidence: metricsRequiringEvidence,
        warnings: warnings,
      ),
    );
  }

  /// Compute a single metric.
  Future<MetricResult?> _computeMetric({
    required AppraisalMetricDef metricDef,
    required _ComputeContext context,
  }) async {
    // Check cache
    final cacheKey = '${context.entityId}:${metricDef.id}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired(cacheTtl)) {
      return cached.result;
    }

    try {
      final (rawValue, confidence) = await _computeRawValue(
        source: metricDef.source,
        context: context,
      );

      if (rawValue == null) {
        // Use default value if available
        if (metricDef.defaultValue != null) {
          final normalizedDefault = metricDef.defaultValue!.clamp(0.0, 1.0);
          final result = MetricResult(
            id: metricDef.id,
            rawValue: metricDef.defaultValue,
            normalizedValue: metricDef.inverse
                ? 1.0 - normalizedDefault
                : normalizedDefault,
            sourceType: MetricSourceType.static_,
            confidence: 1.0,
          );
          _cache[cacheKey] = _CachedMetric(result);
          return result;
        }
        return null;
      }

      // Apply normalization
      double normalizedValue = rawValue;
      if (metricDef.normalization != null) {
        normalizedValue = metricDef.normalization!.normalize(rawValue);
      } else {
        normalizedValue = rawValue.clamp(0.0, 1.0);
      }

      // Apply inverse
      if (metricDef.inverse) {
        normalizedValue = 1.0 - normalizedValue;
      }

      final result = MetricResult(
        id: metricDef.id,
        rawValue: rawValue,
        normalizedValue: normalizedValue,
        sourceType: metricDef.source.type,
        confidence: confidence,
      );

      _cache[cacheKey] = _CachedMetric(result);
      return result;
    } catch (e) {
      // Use default on error
      if (metricDef.defaultValue != null) {
        return MetricResult(
          id: metricDef.id,
          rawValue: metricDef.defaultValue,
          normalizedValue: metricDef.defaultValue!.clamp(0.0, 1.0),
          sourceType: metricDef.source.type,
          confidence: 0.5,
        );
      }
      return null;
    }
  }

  /// Compute raw value from source.
  /// Returns (rawValue, confidence).
  Future<(double?, double)> _computeRawValue({
    required MetricSource source,
    required _ComputeContext context,
  }) async {
    return switch (source) {
      FactGraphSource() =>
        await _computeFromFactGraph(source, context.entityId, context.period),
      ComputedSource() => await _computeFromExpression(source, context),
      StaticSource() => (source.value, 1.0),
      LlmDerivedSource() => await _computeFromLlm(source, context),
    };
  }

  /// Compute metric from FactsPort query.
  Future<(double?, double)> _computeFromFactGraph(
    FactGraphSource source,
    String entityId,
    Period? period,
  ) async {
    final port = factsPort;
    if (port == null) {
      // Graceful degrade — the caller wraps this into a
      // MetricComputeResult with success=false and a warning.
      return (null, 0.0);
    }

    final allFacts = <FactRecord>[];
    final factTypes = source.factTypes ?? const <String>[];
    if (factTypes.isEmpty) {
      allFacts.addAll(await port.queryFacts(FactQuery(
        workspaceId: workspaceId,
        entityId: entityId,
        period: period,
      )));
    } else {
      allFacts.addAll(await port.queryFacts(FactQuery(
        workspaceId: workspaceId,
        entityId: entityId,
        types: factTypes,
        period: period,
      )));
    }

    if (allFacts.isEmpty) {
      return (null, 0.0);
    }

    // Average confidence (facts lacking confidence default to 1.0).
    final avgConfidence = allFacts
            .map((f) => f.confidence ?? 1.0)
            .reduce((a, b) => a + b) /
        allFacts.length;

    final rawValue = _aggregateFactValues(
      facts: allFacts,
      aggregation: source.aggregation,
      field: source.field,
    );

    return (rawValue, avgConfidence);
  }

  /// Aggregate fact values based on aggregation function.
  double? _aggregateFactValues({
    required List<FactRecord> facts,
    required FactAggregation aggregation,
    String? field,
  }) {
    if (facts.isEmpty) return null;

    return switch (aggregation) {
      FactAggregation.count => facts.length.toDouble(),
      FactAggregation.presence => 1.0,
      FactAggregation.avg => _aggregateField(facts, field, (values) {
          return values.reduce((a, b) => a + b) / values.length;
        }),
      FactAggregation.max => _aggregateField(facts, field, (values) {
          return values.reduce(math.max);
        }),
      FactAggregation.min => _aggregateField(facts, field, (values) {
          return values.reduce(math.min);
        }),
      FactAggregation.sum => _aggregateField(facts, field, (values) {
          return values.reduce((a, b) => a + b);
        }),
    };
  }

  /// Extract field values from facts and apply aggregation.
  double? _aggregateField(
    List<FactRecord> facts,
    String? field,
    double Function(List<double>) aggregator,
  ) {
    if (field == null) return null;

    final values = <double>[];
    for (final fact in facts) {
      final value = fact.content[field];
      if (value is num) {
        values.add(value.toDouble());
      }
    }

    if (values.isEmpty) return null;
    return aggregator(values);
  }

  /// Compute metric from expression.
  Future<(double?, double)> _computeFromExpression(
    ComputedSource source,
    _ComputeContext context,
  ) async {
    // Compute confidence (minimum confidence of input metrics per §9.4)
    final inputConfidences = context.confidences.values.toList();
    final confidence = inputConfidences.isNotEmpty
        ? inputConfidences.reduce(math.min)
        : 1.0;

    // Evaluate expression
    final rawValue = _evaluateExpression(source.expression, context);

    return (rawValue, confidence);
  }

  /// Evaluate an expression using recursive descent parser.
  ///
  /// Supports per spec/02 §4.2 and Expression Language reference:
  /// - Variable references: metric IDs, avgConfidence, avgSourceReliability, etc.
  /// - Arithmetic: +, -, *, /
  /// - Parentheses for grouping
  /// - Functions: max(), min(), abs(), clamp(), round(), avg(), sum()
  double? _evaluateExpression(String expression, _ComputeContext context) {
    final variables = <String, double>{
      ...context.metrics,
      'avgConfidence': context.avgConfidence,
      'avgSourceReliability': context.avgSourceReliability,
      'factCount': context.factCount.toDouble(),
      'evidenceCount': context.evidenceCount.toDouble(),
      'conflictCount': context.conflictCount.toDouble(),
    };
    return _ExpressionParser(expression, variables).parse();
  }

  /// Compute metric from LLM.
  Future<(double?, double)> _computeFromLlm(
    LlmDerivedSource source,
    _ComputeContext context,
  ) async {
    if (llmPort == null) {
      return (null, 0.0);
    }

    // Check LLM result cache using cacheKey per design/04-caching.md
    if (source.cacheKey != null) {
      final cached = _llmCache[source.cacheKey!];
      if (cached != null && !cached.isExpired(cacheTtl)) {
        return (cached.rawValue, cached.confidence);
      }
    }

    // Call LLM
    final response = await llmPort!.complete(LlmRequest(
      prompt: source.prompt,
    ));

    final content = response.content.trim();

    // Parse response based on output type
    double? rawValue;
    double confidence = 0.7; // Default confidence per §9.4

    if (source.outputType == LlmOutputType.numeric) {
      // Parse numeric directly
      rawValue = double.tryParse(content);
    } else if (source.outputType == LlmOutputType.categorical) {
      // Map category to value
      if (source.categories != null) {
        rawValue = source.categories![content.toLowerCase()];
      }
    }

    // Store in LLM cache
    if (source.cacheKey != null && rawValue != null) {
      _llmCache[source.cacheKey!] = _CachedLlmResult(
        rawValue: rawValue,
        confidence: confidence,
      );
    }

    return (rawValue, confidence);
  }

  /// Update context statistics by querying [FactsPort].
  ///
  /// When no FactsPort is wired, leaves the statistics at their default
  /// zero values (the runtime degrades gracefully rather than failing).
  Future<void> _updateContextStats(
    _ComputeContext context,
    String entityId,
    Period? period,
  ) async {
    final port = factsPort;
    if (port == null) {
      context.avgSourceReliability = 0.7;
      return;
    }

    final facts = await port.queryFacts(FactQuery(
      workspaceId: workspaceId,
      entityId: entityId,
      period: period,
    ));

    context.factCount = facts.length;

    if (facts.isNotEmpty) {
      context.avgConfidence = facts
              .map((f) => f.confidence ?? 1.0)
              .reduce((a, b) => a + b) /
          facts.length;

      // Evidence count is the sum of evidence references across facts.
      context.evidenceCount =
          facts.fold(0, (sum, f) => sum + f.evidenceRefs.length);
    }

    // Source reliability is an optional summary-level signal. In 0.2.0
    // the runtime does not depend on a separate metric port for it;
    // we fall back to a stable neutral value.
    context.avgSourceReliability = 0.7;
  }

  /// Aggregate metrics into single score (§7).
  double _aggregate({
    required Map<String, MetricResult> metrics,
    required List<AppraisalMetricDef> metricDefs,
    required AggregationConfig config,
  }) {
    if (metrics.isEmpty) return 0.0;

    return switch (config.method) {
      AggregationMethod.weightedAverage => _weightedAverage(
          metrics: metrics,
          metricDefs: metricDefs,
          weightOverrides: config.weights,
        ),
      AggregationMethod.max => metrics.values
          .map((r) => r.normalizedValue)
          .reduce((a, b) => math.max(a, b)),
      AggregationMethod.min => metrics.values
          .map((r) => r.normalizedValue)
          .reduce((a, b) => math.min(a, b)),
      AggregationMethod.sum =>
        metrics.values.map((r) => r.normalizedValue).reduce((a, b) => a + b).clamp(0.0, 1.0),
      AggregationMethod.custom =>
        _evaluateAggregationExpression(config.expression!, metrics) ?? 0.0,
    };
  }

  /// Compute weighted average.
  double _weightedAverage({
    required Map<String, MetricResult> metrics,
    required List<AppraisalMetricDef> metricDefs,
    Map<String, double>? weightOverrides,
  }) {
    var weightedSum = 0.0;
    var totalWeight = 0.0;

    for (final metricDef in metricDefs) {
      final result = metrics[metricDef.id];
      if (result != null) {
        final weight = weightOverrides?[metricDef.id] ?? metricDef.weight;
        weightedSum += result.normalizedValue * weight;
        totalWeight += weight;
      }
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  /// Evaluate custom aggregation expression.
  ///
  /// Variables are metric IDs mapped to their normalized values.
  double? _evaluateAggregationExpression(
    String expression,
    Map<String, MetricResult> metrics,
  ) {
    final variables = <String, double>{};
    for (final entry in metrics.entries) {
      variables[entry.key] = entry.value.normalizedValue;
    }
    return _ExpressionParser(expression, variables).parse();
  }

  /// Clear cached metrics.
  void clearCache({String? entityId}) {
    if (entityId != null) {
      _cache.removeWhere((key, _) => key.startsWith('$entityId:'));
    } else {
      _cache.clear();
      _llmCache.clear();
    }
  }
}

// =============================================================================
// Internal Types
// =============================================================================

/// Context for metric computation.
class _ComputeContext {
  final String entityId;
  final Period? period;
  final Map<String, double> metrics;
  final Map<String, double> confidences;
  double avgConfidence;
  double avgSourceReliability;
  int factCount;
  int evidenceCount;
  int conflictCount;

  _ComputeContext({
    required this.entityId,
    required this.period,
    required this.metrics,
    required this.confidences,
    required this.avgConfidence,
    required this.avgSourceReliability,
    required this.factCount,
    required this.evidenceCount,
    required this.conflictCount,
  });
}

/// Cached metric result.
class _CachedMetric {
  final MetricResult result;
  final DateTime cachedAt;

  _CachedMetric(this.result) : cachedAt = DateTime.now();

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

/// Cached LLM result (for llm_derived source cacheKey).
class _CachedLlmResult {
  final double rawValue;
  final double confidence;
  final DateTime cachedAt;

  _CachedLlmResult({
    required this.rawValue,
    required this.confidence,
  }) : cachedAt = DateTime.now();

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

// =============================================================================
// Expression Parser
// =============================================================================

/// Recursive descent parser for metric expressions.
///
/// Supports per spec/02 Expression Language reference:
/// - Numeric literals
/// - Variable references (metric IDs and context variables)
/// - Arithmetic: +, -, *, /
/// - Parentheses for grouping
/// - Functions: max(), min(), abs(), clamp(), round(), avg(), sum()
class _ExpressionParser {
  final String _source;
  final Map<String, double> _variables;
  int _pos = 0;

  _ExpressionParser(this._source, this._variables);

  /// Parse the expression and return the result.
  double? parse() {
    _skipWhitespace();
    if (_pos >= _source.length) return null;
    final result = _parseAddSub();
    return result;
  }

  /// Parse addition and subtraction.
  double? _parseAddSub() {
    var left = _parseMulDiv();
    if (left == null) return null;

    while (_pos < _source.length) {
      _skipWhitespace();
      if (_pos >= _source.length) break;
      final op = _source[_pos];
      if (op != '+' && op != '-') break;
      _pos++;
      final right = _parseMulDiv();
      if (right == null) return null;
      left = op == '+' ? left! + right : left! - right;
    }
    return left;
  }

  /// Parse multiplication and division.
  double? _parseMulDiv() {
    var left = _parseUnary();
    if (left == null) return null;

    while (_pos < _source.length) {
      _skipWhitespace();
      if (_pos >= _source.length) break;
      final op = _source[_pos];
      if (op != '*' && op != '/' && op != '%') break;
      _pos++;
      final right = _parseUnary();
      if (right == null) return null;
      if (op == '*') {
        left = left! * right;
      } else if (op == '/') {
        left = right != 0 ? left! / right : 0.0;
      } else {
        left = right != 0 ? left! % right : 0.0;
      }
    }
    return left;
  }

  /// Parse unary minus.
  double? _parseUnary() {
    _skipWhitespace();
    if (_pos < _source.length && _source[_pos] == '-') {
      _pos++;
      final value = _parsePrimary();
      return value != null ? -value : null;
    }
    return _parsePrimary();
  }

  /// Parse primary: number, variable, function call, or parenthesized expr.
  double? _parsePrimary() {
    _skipWhitespace();
    if (_pos >= _source.length) return null;

    // Parenthesized expression
    if (_source[_pos] == '(') {
      _pos++;
      final result = _parseAddSub();
      _skipWhitespace();
      if (_pos < _source.length && _source[_pos] == ')') _pos++;
      return result;
    }

    // Number literal
    if (_isDigit(_source[_pos]) || _source[_pos] == '.') {
      return _parseNumber();
    }

    // Identifier (variable or function call)
    if (_isAlpha(_source[_pos]) || _source[_pos] == '_') {
      return _parseIdentifier();
    }

    return null;
  }

  /// Parse a number literal.
  double _parseNumber() {
    final start = _pos;
    while (_pos < _source.length &&
        (_isDigit(_source[_pos]) || _source[_pos] == '.')) {
      _pos++;
    }
    return double.parse(_source.substring(start, _pos));
  }

  /// Parse an identifier (variable reference or function call).
  double? _parseIdentifier() {
    final start = _pos;
    while (_pos < _source.length &&
        (_isAlphaNumeric(_source[_pos]) || _source[_pos] == '_')) {
      _pos++;
    }
    final name = _source.substring(start, _pos);
    _skipWhitespace();

    // Function call
    if (_pos < _source.length && _source[_pos] == '(') {
      _pos++;
      final args = _parseArgList();
      _skipWhitespace();
      if (_pos < _source.length && _source[_pos] == ')') _pos++;
      return _callFunction(name, args);
    }

    // Variable reference
    return _variables[name];
  }

  /// Parse a comma-separated argument list.
  List<double> _parseArgList() {
    final args = <double>[];
    _skipWhitespace();

    if (_pos < _source.length && _source[_pos] == ')') return args;

    final first = _parseAddSub();
    if (first != null) args.add(first);

    while (_pos < _source.length) {
      _skipWhitespace();
      if (_pos >= _source.length || _source[_pos] != ',') break;
      _pos++;
      final arg = _parseAddSub();
      if (arg != null) args.add(arg);
    }

    return args;
  }

  /// Evaluate a built-in function.
  double? _callFunction(String name, List<double> args) {
    return switch (name) {
      'max' when args.length >= 2 =>
        args.reduce((a, b) => math.max(a, b)),
      'min' when args.length >= 2 =>
        args.reduce((a, b) => math.min(a, b)),
      'abs' when args.length == 1 =>
        args[0].abs(),
      'round' when args.length == 1 =>
        args[0].roundToDouble(),
      'clamp' when args.length == 3 =>
        args[0].clamp(args[1], args[2]),
      'avg' when args.isNotEmpty =>
        args.reduce((a, b) => a + b) / args.length,
      'sum' when args.isNotEmpty =>
        args.reduce((a, b) => a + b),
      _ => null,
    };
  }

  void _skipWhitespace() {
    while (_pos < _source.length && _source[_pos] == ' ') {
      _pos++;
    }
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _isAlpha(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  bool _isAlphaNumeric(String c) => _isAlpha(c) || _isDigit(c);
}
