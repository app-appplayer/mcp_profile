/// MCP Profile - Profile definitions for AI personas and prompts.
///
/// This library provides profile management for MCP applications,
/// allowing definition of AI personas, system prompts, and
/// contextual configurations.
library mcp_profile;

// Definition
export 'src/definition/profile.dart';
export 'src/definition/section.dart';
export 'src/definition/capability.dart';

// Builder
export 'src/builder/profile_builder.dart';

// Registry
export 'src/registry/profile_registry.dart';

// Renderer
export 'src/renderer/profile_renderer.dart';

// Expression
export 'src/expression/expression_evaluator.dart';

// Appraisal
export 'src/appraisal/profile_appraisal.dart';

// Decision
export 'src/decision/profile_decision.dart';

// Bundle
export 'src/bundle/profile_bundle.dart';

// Ports
export 'src/ports/profile_port.dart';
export 'src/ports/fact_graph_port.dart';
export 'src/ports/appraisal_port.dart';
export 'src/ports/expression_port.dart';
export 'src/ports/profile_ports.dart';

// Runtime
export 'src/runtime/profile_runtime.dart';
export 'src/runtime/runtime_hooks.dart';
