/// MCP Profile — Profile evaluation runtime for MCP applications.
///
/// 0.2.0 public surface per docs/02_SDD/SDD.md v0.2.0.
///
/// The public surface exposes:
///   1. The **five capability-named standard port adapters** under
///      `src/adapters/` — these implement the mcp_bundle contracts
///      MetricsPort, AppraisalPort, DecisionPort, ExpressionPort and
///      ProfileSummariesPort. They are the only port types hosts should
///      wire.
///   2. The unified **ProfileRuntime** and its execution context /
///      stacking / conflict-resolution support types.
///   3. The **internal engine contracts** (AppraisalEnginePort,
///      DecisionEnginePort, ExpressionEnginePort, EnginePorts). These
///      are re-exported because custom engine implementations and
///      tests need them — external hosts should not depend on their
///      details directly.
///   4. The **domain model** (Profile, AppraisalMetricDef,
///      DecisionPolicy, ExpressionPolicy, etc.).
///   5. Feature modules (cache, versioning, concurrency, factgraph
///      integration).
library mcp_profile;

// ============================================================================
// Domain Model — Definition
// ============================================================================

export 'src/definition/profile.dart';
export 'src/definition/section.dart';
export 'src/definition/capability.dart';
export 'src/builder/profile_builder.dart';
export 'src/registry/profile_registry.dart';
export 'src/renderer/profile_renderer.dart';

// ============================================================================
// Domain Model — Expression
// ============================================================================

export 'src/expression/expression_evaluator.dart';
export 'src/expression/expression_formatter.dart';
export 'src/expression/expression_policy.dart';
export 'src/expression/expression_style.dart';

// ============================================================================
// Domain Model — Appraisal
// ============================================================================

export 'src/appraisal/appraisal_engine.dart';
export 'src/appraisal/appraisal_result.dart';
export 'src/appraisal/metric_definition.dart';
export 'src/appraisal/metric_source.dart';
export 'src/appraisal/normalization.dart';

// ============================================================================
// Domain Model — Decision
// ============================================================================

export 'src/decision/decision_evaluator.dart';
export 'src/decision/decision_guidance.dart';
export 'src/decision/decision_policy.dart';
export 'src/decision/policy_condition.dart';

// ============================================================================
// Domain Model — Bundle
// ============================================================================

export 'src/bundle/profile_bundle_spec.dart';

// ============================================================================
// Engine Contracts (internal, but re-exported for custom engines & tests)
// ============================================================================

export 'src/engines/appraisal_engine_port.dart';
export 'src/engines/decision_engine_port.dart';
export 'src/engines/expression_engine_port.dart';
export 'src/engines/engine_ports.dart';

// ============================================================================
// Standard Port Adapters (0.2.0 public surface)
// ============================================================================

export 'src/adapters/metrics_port_adapter.dart';
export 'src/adapters/appraisal_port_adapter.dart';
export 'src/adapters/decision_port_adapter.dart';
export 'src/adapters/expression_port_adapter.dart';
export 'src/adapters/profile_summaries_port_adapter.dart';

// ============================================================================
// Runtime
// ============================================================================

// Runtime context — hide `ProfileContext` alias (legacy external consumers
// sometimes collide with other `ProfileContext` types; the canonical name
// is `RuntimeProfileContext`).
export 'src/runtime/runtime_context.dart' hide ProfileContext;

// Unified ProfileRuntime. FormattedResponse is re-exported by the engine
// contract (expression_engine_port.dart), hide the duplicate here.
export 'src/runtime/profile_runtime.dart' hide FormattedResponse;

// Multi-profile composition.
export 'src/runtime/profile_stacking.dart';
export 'src/runtime/conflict_resolution.dart';

// ============================================================================
// Feature Modules
// ============================================================================

// Cache
export 'src/cache/metric_caching_service.dart';
export 'src/cache/caching_appraisal_port.dart';

// Versioning
export 'src/versioning/profile_version_resolver.dart';
export 'src/versioning/profile_version_migrator.dart';

// Concurrency
export 'src/concurrency/parallel_policy_evaluator.dart';
export 'src/concurrency/stacked_policy_evaluator.dart';

// FactGraph integration (consumes optional FactsPort/PatternsPort/
// SummariesPort from mcp_fact_graph via mcp_bundle contracts).
export 'src/factgraph/profile_run.dart';
export 'src/factgraph/profile_query.dart';
