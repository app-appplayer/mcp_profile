## [0.2.0] - 2026-04-28 - Engine Contracts & Standard Port Adapters

### Added
- Five standard port adapters implementing `mcp_bundle` Contract Layer — `MetricsPortAdapter`, `AppraisalPortAdapter`, `DecisionPortAdapter`, `ExpressionPortAdapter`, `ProfileSummariesPortAdapter`.
- Internal engine contracts under `src/engines/` — `AppraisalEnginePort`, `DecisionEnginePort`, `ExpressionEnginePort`, with `EnginePorts` container.

### Changed
- `ProfileApplicationRuntime` → `ProfileRuntime`, `ProfilePorts` → `EnginePorts` (no back-compat aliases).
- `AppraisalEngine` consumes `FactsPort` directly via `FactQuery` / `FactRecord`; required `workspaceId` construction field.
- `RuntimeProfileContext` carries `facts` / `patterns` / `summaries` / `llm` standard ports.
- New dependency: `mcp_bundle ^0.3.0`.

### Removed
- Legacy `src/ports/` directory in full (replaced by engine ports + Contract Layer adapters).
- Legacy adapters, factgraph plumbing, runtime hooks, and the text-renderer profile runtime.
- All typedef back-compat aliases.

---

## [0.1.0] - Initial Release

### Added

#### Core Features
- **Profile Definitions**
  - `Profile` model with system prompt templates
  - Metadata support (tags, categories, version)
  - Context variable specifications
  - Versioning and history tracking

- **Profile Runtime**
  - `ProfileRuntime` as the main execution engine
  - Profile registration and discovery
  - Template rendering with context injection
  - Execution tracking and metrics

- **Template Rendering**
  - Mustache-style template syntax
  - Context variable injection
  - Conditional sections and loops
  - Expression language support

- **Profile Selection**
  - Context-based profile selection
  - Confidence scoring for selections
  - Alternative suggestions
  - Selection criteria customization

- **Appraisal System**
  - Profile quality scoring
  - Feedback generation
  - Threshold-based validation
  - Custom appraisal criteria

- **Port-Based Architecture**
  - `ProfileStoragePort` for profile persistence
  - `ProfileRenderPort` for template rendering
  - `ProfileSelectionPort` for profile selection
  - `ProfileAppraisalPort` for quality scoring
  - `FactGraphPortL1` for fact graph integration

- **In-Memory Implementations**
  - Complete in-memory storage for testing
  - Default render and selection implementations

### Data Models
- `Profile` - Profile definition with templates
- `ProfileContext` - Rendering context data
- `ProfileExecutionResult` - Rendering outcome
- `ProfileSelectionResult` - Selection outcome
- `ProfileAppraisal` - Quality assessment

---

## Support and Contributing

- [Report Issues](https://github.com/app-appplayer/mcp_profile/issues)
- [Join Discussions](https://github.com/app-appplayer/mcp_profile/discussions)
- [Read Documentation](https://github.com/app-appplayer/mcp_profile/wiki)
- [Support Development](https://www.patreon.com/mcpdevstudio)
