/// Runtime Context — immutable context for profile evaluation per
/// docs/03_DDD/core-runtime.md v0.2.0 §3.1.
library;

import 'package:mcp_bundle/ports.dart'
    show Period, FactsPort, PatternsPort, SummariesPort, LlmPort;

// =============================================================================
// Type Aliases
// =============================================================================

/// Alias used in older engine method signatures.
typedef ProfileContext = RuntimeProfileContext;

/// Alias for [RuntimeContextBuilder].
typedef ProfileContextBuilder = RuntimeContextBuilder;

/// Alias for [DefaultRuntimeContext].
typedef DefaultProfileContext = DefaultRuntimeContext;

// =============================================================================
// Clock Interface
// =============================================================================

/// Clock abstraction for testability.
abstract class Clock {
  DateTime now();
}

/// System clock implementation.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Fixed clock for deterministic tests.
class FixedClock implements Clock {
  final DateTime _time;

  const FixedClock(this._time);

  @override
  DateTime now() => _time;
}

// =============================================================================
// RuntimeProfileContext
// =============================================================================

/// Immutable context for profile evaluation.
///
/// Carries identity (contextId / profileId / runId / traceId / entityId),
/// time (asOf / period / clock), data (inputs / metadata), and optional
/// consumed standard ports (FactsPort / PatternsPort / SummariesPort /
/// LlmPort). Facts themselves are no longer snapshotted on the context
/// — the runtime queries them through [facts] at computation time.
abstract class RuntimeProfileContext {
  // === IDENTITY ===

  /// Unique context ID.
  String get contextId;

  /// Profile being evaluated.
  String get profileId;

  /// Primary entity identifier (required — used by facts/summaries
  /// queries and cache keying).
  String get entityId;

  /// Execution run ID.
  String get runId;

  /// Distributed tracing ID.
  String? get traceId;

  // === TIME ===

  /// Point-in-time for data queries.
  DateTime get asOf;

  /// Time range if applicable.
  Period? get period;

  /// Clock for testability.
  Clock get clock;

  // === DATA ===

  /// Input parameters.
  Map<String, dynamic> get inputs;

  /// Additional metadata.
  Map<String, dynamic> get metadata;

  // === CONSUMED STANDARD PORTS (all optional) ===

  /// Fact graph facts port (mcp_bundle contract).
  FactsPort? get facts;

  /// Fact graph patterns port.
  PatternsPort? get patterns;

  /// Fact-level summaries port.
  SummariesPort? get summaries;

  /// LLM port for semantic operations.
  LlmPort? get llm;

  // === EXTERNAL CONTEXT ===

  /// SkillContext (from mcp_skill) when running inside a skill; dynamic
  /// to avoid a circular package dependency.
  dynamic get skillContext;
}

/// Default implementation of [RuntimeProfileContext].
class DefaultRuntimeContext implements RuntimeProfileContext {
  @override
  final String contextId;

  @override
  final String profileId;

  @override
  final String entityId;

  @override
  final String runId;

  @override
  final String? traceId;

  @override
  final DateTime asOf;

  @override
  final Period? period;

  @override
  final Clock clock;

  @override
  final Map<String, dynamic> inputs;

  @override
  final Map<String, dynamic> metadata;

  @override
  final FactsPort? facts;

  @override
  final PatternsPort? patterns;

  @override
  final SummariesPort? summaries;

  @override
  final LlmPort? llm;

  @override
  final dynamic skillContext;

  DefaultRuntimeContext({
    required this.profileId,
    this.entityId = 'default',
    String? contextId,
    String? runId,
    this.traceId,
    DateTime? asOf,
    this.period,
    Clock? clock,
    this.inputs = const {},
    this.metadata = const {},
    this.facts,
    this.patterns,
    this.summaries,
    this.llm,
    this.skillContext,
  })  : contextId = contextId ?? _generateId('ctx'),
        runId = runId ?? _generateId('run'),
        asOf = asOf ?? DateTime.now(),
        clock = clock ?? const SystemClock();

  static String _generateId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$prefix-$timestamp';
  }
}

// =============================================================================
// RuntimeContextBuilder
// =============================================================================

/// Fluent builder for [RuntimeProfileContext].
class RuntimeContextBuilder {
  RuntimeContextBuilder();

  String? _profileId;
  String _entityId = 'default';
  String? _contextId;
  String? _runId;
  String? _traceId;
  DateTime? _asOf;
  Period? _period;
  Clock? _clock;
  Map<String, dynamic> _inputs = {};
  Map<String, dynamic> _metadata = {};
  FactsPort? _facts;
  PatternsPort? _patterns;
  SummariesPort? _summaries;
  LlmPort? _llm;
  dynamic _skillContext;

  /// Create a builder pre-populated from an existing context.
  factory RuntimeContextBuilder.fromProfileContext(
      RuntimeProfileContext context) {
    return RuntimeContextBuilder()
      ..withProfile(context.profileId)
      ..withEntity(context.entityId)
      ..withContextId(context.contextId)
      ..withRunId(context.runId)
      .._traceId = context.traceId
      ..withAsOf(context.asOf)
      .._period = context.period
      ..withClock(context.clock)
      ..withInputs(Map.of(context.inputs))
      ..withMetadata(Map.of(context.metadata))
      .._facts = context.facts
      .._patterns = context.patterns
      .._summaries = context.summaries
      .._llm = context.llm
      .._skillContext = context.skillContext;
  }

  /// Create a builder from a dynamic SkillContext (duck-typed).
  factory RuntimeContextBuilder.fromSkillContext(dynamic skillContext) {
    final builder = RuntimeContextBuilder();
    builder._skillContext = skillContext;
    try {
      builder._contextId = 'profile-${skillContext.contextId}';
    } catch (_) {}
    try {
      builder._traceId = skillContext.traceId as String?;
    } catch (_) {}
    try {
      builder._asOf = skillContext.asOf as DateTime?;
    } catch (_) {}
    try {
      final inputs = skillContext.inputs;
      if (inputs is Map<String, dynamic>) {
        builder._inputs = inputs;
      }
    } catch (_) {}
    try {
      builder._entityId = skillContext.entityId as String? ?? 'default';
    } catch (_) {}
    return builder;
  }

  RuntimeContextBuilder withProfile(String profileId) {
    _profileId = profileId;
    return this;
  }

  RuntimeContextBuilder withEntity(String entityId) {
    _entityId = entityId;
    return this;
  }

  RuntimeContextBuilder withContextId(String contextId) {
    _contextId = contextId;
    return this;
  }

  RuntimeContextBuilder withRunId(String runId) {
    _runId = runId;
    return this;
  }

  RuntimeContextBuilder withTraceId(String traceId) {
    _traceId = traceId;
    return this;
  }

  RuntimeContextBuilder withAsOf(DateTime asOf) {
    _asOf = asOf;
    return this;
  }

  RuntimeContextBuilder withPeriod(Period period) {
    _period = period;
    return this;
  }

  RuntimeContextBuilder withClock(Clock clock) {
    _clock = clock;
    return this;
  }

  RuntimeContextBuilder withInputs(Map<String, dynamic> inputs) {
    _inputs = inputs;
    return this;
  }

  RuntimeContextBuilder withMetadata(Map<String, dynamic> metadata) {
    _metadata = metadata;
    return this;
  }

  /// Set the optional consumed standard ports.
  RuntimeContextBuilder withPorts({
    FactsPort? facts,
    PatternsPort? patterns,
    SummariesPort? summaries,
    LlmPort? llm,
  }) {
    _facts = facts;
    _patterns = patterns;
    _summaries = summaries;
    _llm = llm;
    return this;
  }

  RuntimeContextBuilder withSkillContext(dynamic skillContext) {
    _skillContext = skillContext;
    return this;
  }

  RuntimeProfileContext build() {
    if (_profileId == null) {
      throw ArgumentError('profileId is required');
    }
    return DefaultRuntimeContext(
      profileId: _profileId!,
      entityId: _entityId,
      contextId: _contextId,
      runId: _runId,
      traceId: _traceId,
      asOf: _asOf,
      period: _period,
      clock: _clock,
      inputs: _inputs,
      metadata: _metadata,
      facts: _facts,
      patterns: _patterns,
      summaries: _summaries,
      llm: _llm,
      skillContext: _skillContext,
    );
  }
}
