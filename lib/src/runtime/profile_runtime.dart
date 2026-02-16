/// Profile Runtime - Main runtime for profile execution.
///
/// Provides the core runtime for rendering profiles with context,
/// applying appraisal and decision policies, and formatting output.
library;

import '../definition/profile.dart';
import '../bundle/profile_bundle.dart';
import '../ports/profile_ports.dart';
import '../ports/profile_port.dart';
import '../ports/expression_port.dart';
import '../appraisal/profile_appraisal.dart';
import '../decision/profile_decision.dart';
import 'runtime_hooks.dart';

/// Main runtime for profile execution.
class ProfileRuntime {
  /// Port container.
  final ProfilePorts ports;

  /// Runtime hooks.
  final ProfileRuntimeHook hook;

  /// Profile appraiser.
  final ProfileAppraiser? appraiser;

  /// Profile decision engine.
  final ProfileDecisionEngine? decisionEngine;

  /// Inheritance resolver.
  final ProfileInheritanceResolver _inheritanceResolver;

  ProfileRuntime({
    required this.ports,
    ProfileRuntimeHook? hook,
    this.appraiser,
    this.decisionEngine,
  })  : hook = hook ?? const NoOpProfileHook(),
        _inheritanceResolver = ProfileInheritanceResolver();

  /// Execute profile rendering with full pipeline.
  Future<ProfileExecutionResult> execute({
    required String profileId,
    required ProfileContext context,
    ProfileExecutionOptions? options,
  }) async {
    final startTime = DateTime.now();

    try {
      await hook.onExecutionStart(profileId, context);

      // Get profile
      final profile = await ports.storage.getProfile(profileId);
      if (profile == null) {
        return ProfileExecutionResult.failure(
          error: 'Profile not found: $profileId',
          duration: DateTime.now().difference(startTime),
        );
      }

      // Execute with profile
      return await executeWithProfile(
        profile: profile,
        context: context,
        options: options,
      );
    } catch (e, st) {
      await hook.onError(e, st);
      return ProfileExecutionResult.failure(
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Execute with a specific profile.
  Future<ProfileExecutionResult> executeWithProfile({
    required Profile profile,
    required ProfileContext context,
    ProfileExecutionOptions? options,
  }) async {
    final startTime = DateTime.now();
    final opts = options ?? const ProfileExecutionOptions();

    try {
      await hook.onProfileLoaded(profile);

      // Apply appraisal if enabled
      ProfileAppraisal? appraisal;
      if (opts.enableAppraisal && appraiser != null) {
        appraisal = appraiser!.appraise(profile);
        await hook.onAppraisalComplete(appraisal);

        if (!appraisal.passed(threshold: opts.appraisalThreshold)) {
          if (opts.failOnLowAppraisal) {
            return ProfileExecutionResult.failure(
              error: 'Profile appraisal failed: ${appraisal.overallScore}',
              appraisal: appraisal,
              duration: DateTime.now().difference(startTime),
            );
          }
        }
      }

      // Apply section decisions
      SectionDecision? sectionDecision;
      if (opts.enableDecision && decisionEngine != null) {
        sectionDecision = decisionEngine!.decideSections(profile, context);
        await hook.onDecisionComplete(sectionDecision);
      }

      // Render profile
      final rendered = await ports.render.render(
        profile: profile,
        context: context.toMap(),
        options: RenderOptions(
          maxLength: opts.maxContentLength,
          includeSections: opts.includeSections,
          excludeSections: opts.excludeSections,
          includeCapabilities: opts.includeCapabilities,
          variables: context.variables,
        ),
      );

      await hook.onRenderComplete(rendered);

      // Apply expression formatting if enabled
      String formattedContent = rendered.systemPrompt;
      if (opts.enableFormatting && opts.expressionStyle != null) {
        final formatted = await ports.expression.format(
          content: formattedContent,
          style: opts.expressionStyle!,
          context: FormattingContext(
            userPreferences: context.user,
            conversationContext: context.session,
          ),
        );
        formattedContent = formatted.content;
      }

      await hook.onExecutionComplete(profile.id);

      return ProfileExecutionResult.success(
        profileId: profile.id,
        profileVersion: profile.version,
        content: formattedContent,
        instructions: rendered.instructions,
        activeCapabilities: rendered.activeCapabilities,
        appraisal: appraisal,
        sectionDecision: sectionDecision,
        duration: DateTime.now().difference(startTime),
        metadata: {
          'sectionsIncluded': sectionDecision?.included.length ?? profile.sections.length,
          'sectionsExcluded': sectionDecision?.excluded.length ?? 0,
          ...rendered.metadata,
        },
      );
    } catch (e, st) {
      await hook.onError(e, st);
      return ProfileExecutionResult.failure(
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Select and execute best profile from candidates.
  Future<ProfileExecutionResult> selectAndExecute({
    required List<String> candidateIds,
    required ProfileContext context,
    ProfileExecutionOptions? options,
    String? preferredId,
  }) async {
    final startTime = DateTime.now();

    try {
      // Select profile
      final selection = await ports.selection.selectProfile(
        candidateIds: candidateIds,
        context: context.toMap(),
        preferredId: preferredId,
      );

      if (!selection.hasSelection) {
        return ProfileExecutionResult.failure(
          error: 'No suitable profile found: ${selection.reason}',
          duration: DateTime.now().difference(startTime),
        );
      }

      // Execute selected profile
      final result = await execute(
        profileId: selection.selectedId!,
        context: context,
        options: options,
      );

      // Include selection info in metadata
      return result.copyWith(
        metadata: {
          ...result.metadata,
          'selectionConfidence': selection.confidence,
          'selectionReason': selection.reason,
          'alternatives': selection.alternatives,
        },
      );
    } catch (e, st) {
      await hook.onError(e, st);
      return ProfileExecutionResult.failure(
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Execute with profile bundle.
  Future<ProfileExecutionResult> executeFromBundle({
    required ProfileBundle bundle,
    required ProfileContext context,
    String? profileId,
    ProfileExecutionOptions? options,
  }) async {
    final startTime = DateTime.now();

    try {
      // Get profile from bundle
      Profile? profile;
      if (profileId != null) {
        profile = bundle.getProfile(profileId);
      } else {
        profile = bundle.defaultProfile;
      }

      if (profile == null) {
        return ProfileExecutionResult.failure(
          error: profileId != null
              ? 'Profile "$profileId" not found in bundle'
              : 'No default profile in bundle',
          duration: DateTime.now().difference(startTime),
        );
      }

      // Resolve inheritance
      final resolved = _inheritanceResolver.resolve(profile, bundle);

      // Execute
      return await executeWithProfile(
        profile: resolved,
        context: context,
        options: options,
      );
    } catch (e, st) {
      await hook.onError(e, st);
      return ProfileExecutionResult.failure(
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }
}

/// Options for profile execution.
class ProfileExecutionOptions {
  /// Whether to enable appraisal.
  final bool enableAppraisal;

  /// Minimum appraisal score threshold.
  final double appraisalThreshold;

  /// Whether to fail on low appraisal.
  final bool failOnLowAppraisal;

  /// Whether to enable section decision.
  final bool enableDecision;

  /// Whether to enable expression formatting.
  final bool enableFormatting;

  /// Expression style for formatting.
  final ExpressionStyle? expressionStyle;

  /// Maximum content length.
  final int? maxContentLength;

  /// Sections to include.
  final List<String>? includeSections;

  /// Sections to exclude.
  final List<String>? excludeSections;

  /// Whether to include capabilities.
  final bool includeCapabilities;

  const ProfileExecutionOptions({
    this.enableAppraisal = true,
    this.appraisalThreshold = 70.0,
    this.failOnLowAppraisal = false,
    this.enableDecision = true,
    this.enableFormatting = false,
    this.expressionStyle,
    this.maxContentLength,
    this.includeSections,
    this.excludeSections,
    this.includeCapabilities = true,
  });

  /// Create default options.
  static const ProfileExecutionOptions defaults = ProfileExecutionOptions();

  /// Create minimal options (no appraisal, no decision).
  static const ProfileExecutionOptions minimal = ProfileExecutionOptions(
    enableAppraisal: false,
    enableDecision: false,
    enableFormatting: false,
  );
}

/// Result of profile execution.
class ProfileExecutionResult {
  /// Whether execution succeeded.
  final bool success;

  /// Profile ID (if success).
  final String? profileId;

  /// Profile version (if success).
  final String? profileVersion;

  /// Rendered content (if success).
  final String? content;

  /// Additional instructions (if success).
  final String? instructions;

  /// Active capabilities.
  final List<String> activeCapabilities;

  /// Appraisal result (if enabled).
  final ProfileAppraisal? appraisal;

  /// Section decision (if enabled).
  final SectionDecision? sectionDecision;

  /// Error message (if failure).
  final String? error;

  /// Execution duration.
  final Duration duration;

  /// Execution metadata.
  final Map<String, dynamic> metadata;

  const ProfileExecutionResult({
    required this.success,
    this.profileId,
    this.profileVersion,
    this.content,
    this.instructions,
    this.activeCapabilities = const [],
    this.appraisal,
    this.sectionDecision,
    this.error,
    required this.duration,
    this.metadata = const {},
  });

  /// Create success result.
  factory ProfileExecutionResult.success({
    required String profileId,
    required String profileVersion,
    required String content,
    String? instructions,
    List<String> activeCapabilities = const [],
    ProfileAppraisal? appraisal,
    SectionDecision? sectionDecision,
    required Duration duration,
    Map<String, dynamic> metadata = const {},
  }) {
    return ProfileExecutionResult(
      success: true,
      profileId: profileId,
      profileVersion: profileVersion,
      content: content,
      instructions: instructions,
      activeCapabilities: activeCapabilities,
      appraisal: appraisal,
      sectionDecision: sectionDecision,
      duration: duration,
      metadata: metadata,
    );
  }

  /// Create failure result.
  factory ProfileExecutionResult.failure({
    required String error,
    ProfileAppraisal? appraisal,
    required Duration duration,
    Map<String, dynamic> metadata = const {},
  }) {
    return ProfileExecutionResult(
      success: false,
      error: error,
      appraisal: appraisal,
      duration: duration,
      metadata: metadata,
    );
  }

  /// Copy with modifications.
  ProfileExecutionResult copyWith({
    bool? success,
    String? profileId,
    String? profileVersion,
    String? content,
    String? instructions,
    List<String>? activeCapabilities,
    ProfileAppraisal? appraisal,
    SectionDecision? sectionDecision,
    String? error,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    return ProfileExecutionResult(
      success: success ?? this.success,
      profileId: profileId ?? this.profileId,
      profileVersion: profileVersion ?? this.profileVersion,
      content: content ?? this.content,
      instructions: instructions ?? this.instructions,
      activeCapabilities: activeCapabilities ?? this.activeCapabilities,
      appraisal: appraisal ?? this.appraisal,
      sectionDecision: sectionDecision ?? this.sectionDecision,
      error: error ?? this.error,
      duration: duration ?? this.duration,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get full prompt content.
  String? get fullPrompt {
    if (content == null) return null;
    if (instructions != null && instructions!.isNotEmpty) {
      return '$content\n\n$instructions';
    }
    return content;
  }
}
