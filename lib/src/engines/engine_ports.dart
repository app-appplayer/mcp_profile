/// Engine Ports Container — the internal dependency bag passed to
/// [ProfileRuntime]. See docs/03_DDD/core-engines.md §6.
library;

import 'package:mcp_bundle/ports.dart'
    show FactsPort, PatternsPort, SummariesPort, LlmPort;

import 'appraisal_engine_port.dart';
import 'decision_engine_port.dart';
import 'expression_engine_port.dart';

/// Container for the three internal engine contracts plus the optional
/// consumed standard ports (FactsPort/PatternsPort/SummariesPort/LlmPort).
class EnginePorts {
  /// Appraisal engine contract.
  final AppraisalEnginePort appraisal;

  /// Decision engine contract.
  final DecisionEnginePort decision;

  /// Expression engine contract.
  final ExpressionEnginePort expression;

  /// Optional fact graph facts port (mcp_fact_graph).
  final FactsPort? facts;

  /// Optional pattern port (mcp_fact_graph).
  final PatternsPort? patterns;

  /// Optional fact-level summaries port (mcp_fact_graph).
  final SummariesPort? summaries;

  /// Optional LLM port (mcp_llm).
  final LlmPort? llm;

  const EnginePorts({
    required this.appraisal,
    required this.decision,
    required this.expression,
    this.facts,
    this.patterns,
    this.summaries,
    this.llm,
  });

  /// Test / bootstrap convenience. Uses stub engine contracts and no
  /// consumed ports.
  factory EnginePorts.stub() {
    return const EnginePorts(
      appraisal: StubAppraisalEnginePort(),
      decision: StubDecisionEnginePort(),
      expression: PassthroughExpressionEnginePort(),
    );
  }

  /// Return a copy with selected fields replaced.
  EnginePorts copyWith({
    AppraisalEnginePort? appraisal,
    DecisionEnginePort? decision,
    ExpressionEnginePort? expression,
    FactsPort? facts,
    PatternsPort? patterns,
    SummariesPort? summaries,
    LlmPort? llm,
  }) {
    return EnginePorts(
      appraisal: appraisal ?? this.appraisal,
      decision: decision ?? this.decision,
      expression: expression ?? this.expression,
      facts: facts ?? this.facts,
      patterns: patterns ?? this.patterns,
      summaries: summaries ?? this.summaries,
      llm: llm ?? this.llm,
    );
  }
}
