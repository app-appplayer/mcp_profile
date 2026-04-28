# MCP Profile

> **Positioning:** `mcp_profile` is an internal component of the MakeMind knowledge stack exposed through the `mcp_knowledge` facade. Application code should import `package:mcp_knowledge/mcp_knowledge.dart` — the symbols declared here are re-exported from there. Direct `package:mcp_profile/` imports remain valid for advanced or integration scenarios but are discouraged in product code.

AI persona definitions with template rendering, context injection, profile selection, and appraisal scoring. Pluggable engines (appraisal / decision / expression) drive a unified runtime that exposes the `mcp_bundle` standard ports.

## Components

- **Definition** — `Profile`, sections, capability metadata, builder, registry, renderer.
- **Expression** — formatter, policy, style, evaluator (templated profile prompts).
- **Appraisal** — engine, metric definition / source, normalization, results.
- **Decision** — evaluator, decision policy, policy condition, guidance.
- **Bundle** — profile bundle spec.
- **Engines** (re-exported for custom implementations and tests) — `AppraisalEnginePort`, `DecisionEnginePort`, `ExpressionEnginePort`, `EnginePorts` container.
- **Standard port adapters** — `MetricsPortAdapter`, `AppraisalPortAdapter`, `DecisionPortAdapter`, `ExpressionPortAdapter`, `ProfileSummariesPortAdapter` implementing `mcp_bundle` Contract Layer.
- **Runtime** — unified `ProfileRuntime` orchestrating Appraisal → Decision → Expression.
- **Feature modules** — cache, versioning, concurrency, fact-graph integration.

## Quick Start

```dart
import 'package:mcp_profile/mcp_profile.dart';

final runtime = ProfileRuntime(
  registry: ProfileRegistry(),
  engines: EnginePorts(
    appraisal: StubAppraisalEnginePort(),
    decision: DefaultDecisionEnginePort(),
    expression: PassthroughExpressionEnginePort(),
    facts: factsPort,
    summaries: summariesPort,
    llm: llmPort,
  ),
);

final result = await runtime.apply(profileId, RuntimeProfileContext(...));
```

## Support

- [Issue Tracker](https://github.com/app-appplayer/mcp_profile/issues)
- [Discussions](https://github.com/app-appplayer/mcp_profile/discussions)

## License

MIT — see [LICENSE](LICENSE).
