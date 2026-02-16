/// Runtime Hooks - Event handling for profile execution lifecycle.
///
/// Provides hooks for monitoring and extending profile execution
/// including logging, metrics, and custom event handling.
library;

import '../definition/profile.dart';
import '../ports/profile_port.dart';
import '../appraisal/profile_appraisal.dart';
import '../decision/profile_decision.dart';

/// Hook for profile runtime events.
///
/// Implement this interface to receive notifications about
/// profile execution lifecycle events.
abstract class ProfileRuntimeHook {
  /// Called when profile execution starts.
  Future<void> onExecutionStart(String profileId, ProfileContext context);

  /// Called when profile is loaded.
  Future<void> onProfileLoaded(Profile profile);

  /// Called when appraisal completes.
  Future<void> onAppraisalComplete(ProfileAppraisal appraisal);

  /// Called when section decision completes.
  Future<void> onDecisionComplete(SectionDecision decision);

  /// Called when rendering completes.
  Future<void> onRenderComplete(RenderedProfile rendered);

  /// Called when execution completes successfully.
  Future<void> onExecutionComplete(String profileId);

  /// Called when an error occurs.
  Future<void> onError(Object error, StackTrace stackTrace);
}

/// Logging hook for profile runtime events.
class LoggingProfileHook implements ProfileRuntimeHook {
  /// Log level.
  final ProfileLogLevel level;

  /// Custom logger callback.
  final void Function(ProfileLogLevel level, String message)? logger;

  LoggingProfileHook({
    this.level = ProfileLogLevel.info,
    this.logger,
  });

  @override
  Future<void> onExecutionStart(String profileId, ProfileContext context) async {
    _log(ProfileLogLevel.info, 'Profile execution started: $profileId');
  }

  @override
  Future<void> onProfileLoaded(Profile profile) async {
    _log(ProfileLogLevel.debug, 'Profile loaded: ${profile.id} v${profile.version}');
  }

  @override
  Future<void> onAppraisalComplete(ProfileAppraisal appraisal) async {
    _log(
      ProfileLogLevel.debug,
      'Appraisal complete: ${appraisal.profileId} score=${appraisal.overallScore}',
    );
  }

  @override
  Future<void> onDecisionComplete(SectionDecision decision) async {
    _log(
      ProfileLogLevel.debug,
      'Decision complete: ${decision.included.length} included, ${decision.excluded.length} excluded',
    );
  }

  @override
  Future<void> onRenderComplete(RenderedProfile rendered) async {
    _log(
      ProfileLogLevel.debug,
      'Render complete: ${rendered.systemPrompt.length} chars, ${rendered.activeCapabilities.length} capabilities',
    );
  }

  @override
  Future<void> onExecutionComplete(String profileId) async {
    _log(ProfileLogLevel.info, 'Profile execution complete: $profileId');
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    _log(ProfileLogLevel.error, 'Error: $error\n$stackTrace');
  }

  void _log(ProfileLogLevel logLevel, String message) {
    if (logLevel.index >= level.index) {
      logger?.call(logLevel, message);
    }
  }
}

/// Log levels for profile runtime.
enum ProfileLogLevel {
  debug,
  info,
  warning,
  error,
}

/// Metrics hook for tracking profile execution statistics.
class MetricsProfileHook implements ProfileRuntimeHook {
  /// Metrics collector callback.
  final void Function(String metricName, double value, Map<String, String> tags)?
      collector;

  /// Tracked executions.
  final Map<String, _ExecutionEntry> _executions = {};

  MetricsProfileHook({this.collector});

  @override
  Future<void> onExecutionStart(String profileId, ProfileContext context) async {
    final key = '${profileId}_${DateTime.now().millisecondsSinceEpoch}';
    _executions[key] = _ExecutionEntry(
      profileId: profileId,
      startTime: DateTime.now(),
    );
    _emit('profile.execution.started', 1, {'profile_id': profileId});
  }

  @override
  Future<void> onProfileLoaded(Profile profile) async {
    _emit('profile.loaded', 1, {
      'profile_id': profile.id,
      'sections_count': profile.sections.length.toString(),
    });
  }

  @override
  Future<void> onAppraisalComplete(ProfileAppraisal appraisal) async {
    _emit('profile.appraisal.score', appraisal.overallScore, {
      'profile_id': appraisal.profileId,
    });
    _emit('profile.appraisal.issues', appraisal.issues.length.toDouble(), {
      'profile_id': appraisal.profileId,
    });
  }

  @override
  Future<void> onDecisionComplete(SectionDecision decision) async {
    _emit('profile.decision.included', decision.included.length.toDouble(), {});
    _emit('profile.decision.excluded', decision.excluded.length.toDouble(), {});
  }

  @override
  Future<void> onRenderComplete(RenderedProfile rendered) async {
    _emit('profile.render.length', rendered.systemPrompt.length.toDouble(), {});
    _emit('profile.render.capabilities', rendered.activeCapabilities.length.toDouble(), {});
  }

  @override
  Future<void> onExecutionComplete(String profileId) async {
    final entry = _executions.values.firstWhere(
      (e) => e.profileId == profileId,
      orElse: () => _ExecutionEntry(profileId: profileId, startTime: DateTime.now()),
    );

    final duration = DateTime.now().difference(entry.startTime);
    _emit('profile.execution.completed', 1, {'profile_id': profileId});
    _emit('profile.execution.duration_ms', duration.inMilliseconds.toDouble(), {
      'profile_id': profileId,
    });
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    _emit('profile.execution.error', 1, {'error_type': error.runtimeType.toString()});
  }

  void _emit(String name, double value, Map<String, String> tags) {
    collector?.call(name, value, tags);
  }

  /// Get execution summary.
  Map<String, dynamic> getSummary() {
    return {
      'total_executions': _executions.length,
    };
  }
}

class _ExecutionEntry {
  final String profileId;
  final DateTime startTime;

  _ExecutionEntry({required this.profileId, required this.startTime});
}

/// Composite hook that delegates to multiple hooks.
class CompositeProfileHook implements ProfileRuntimeHook {
  /// Inner hooks.
  final List<ProfileRuntimeHook> hooks;

  CompositeProfileHook(this.hooks);

  @override
  Future<void> onExecutionStart(String profileId, ProfileContext context) async {
    for (final hook in hooks) {
      await hook.onExecutionStart(profileId, context);
    }
  }

  @override
  Future<void> onProfileLoaded(Profile profile) async {
    for (final hook in hooks) {
      await hook.onProfileLoaded(profile);
    }
  }

  @override
  Future<void> onAppraisalComplete(ProfileAppraisal appraisal) async {
    for (final hook in hooks) {
      await hook.onAppraisalComplete(appraisal);
    }
  }

  @override
  Future<void> onDecisionComplete(SectionDecision decision) async {
    for (final hook in hooks) {
      await hook.onDecisionComplete(decision);
    }
  }

  @override
  Future<void> onRenderComplete(RenderedProfile rendered) async {
    for (final hook in hooks) {
      await hook.onRenderComplete(rendered);
    }
  }

  @override
  Future<void> onExecutionComplete(String profileId) async {
    for (final hook in hooks) {
      await hook.onExecutionComplete(profileId);
    }
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    for (final hook in hooks) {
      await hook.onError(error, stackTrace);
    }
  }
}

/// No-op hook that does nothing.
class NoOpProfileHook implements ProfileRuntimeHook {
  const NoOpProfileHook();

  @override
  Future<void> onExecutionStart(String profileId, ProfileContext context) async {}

  @override
  Future<void> onProfileLoaded(Profile profile) async {}

  @override
  Future<void> onAppraisalComplete(ProfileAppraisal appraisal) async {}

  @override
  Future<void> onDecisionComplete(SectionDecision decision) async {}

  @override
  Future<void> onRenderComplete(RenderedProfile rendered) async {}

  @override
  Future<void> onExecutionComplete(String profileId) async {}

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {}
}

/// History hook that records execution history.
class HistoryProfileHook implements ProfileRuntimeHook {
  /// Maximum history entries to keep.
  final int maxEntries;

  /// Recorded history.
  final List<ProfileHistoryEntry> _history = [];

  HistoryProfileHook({this.maxEntries = 1000});

  /// Get recorded history.
  List<ProfileHistoryEntry> get history => List.unmodifiable(_history);

  /// Clear history.
  void clear() => _history.clear();

  @override
  Future<void> onExecutionStart(String profileId, ProfileContext context) async {
    _record(ProfileHistoryEntry(
      type: ProfileHistoryEntryType.executionStart,
      timestamp: DateTime.now(),
      data: {'profileId': profileId},
    ));
  }

  @override
  Future<void> onProfileLoaded(Profile profile) async {
    _record(ProfileHistoryEntry(
      type: ProfileHistoryEntryType.profileLoaded,
      timestamp: DateTime.now(),
      data: {
        'profileId': profile.id,
        'version': profile.version,
        'sectionsCount': profile.sections.length,
      },
    ));
  }

  @override
  Future<void> onAppraisalComplete(ProfileAppraisal appraisal) async {
    _record(ProfileHistoryEntry(
      type: ProfileHistoryEntryType.appraisalComplete,
      timestamp: DateTime.now(),
      data: {
        'profileId': appraisal.profileId,
        'score': appraisal.overallScore,
        'issuesCount': appraisal.issues.length,
      },
    ));
  }

  @override
  Future<void> onDecisionComplete(SectionDecision decision) async {
    _record(ProfileHistoryEntry(
      type: ProfileHistoryEntryType.decisionComplete,
      timestamp: DateTime.now(),
      data: {
        'includedCount': decision.included.length,
        'excludedCount': decision.excluded.length,
      },
    ));
  }

  @override
  Future<void> onRenderComplete(RenderedProfile rendered) async {
    _record(ProfileHistoryEntry(
      type: ProfileHistoryEntryType.renderComplete,
      timestamp: DateTime.now(),
      data: {
        'contentLength': rendered.systemPrompt.length,
        'capabilitiesCount': rendered.activeCapabilities.length,
      },
    ));
  }

  @override
  Future<void> onExecutionComplete(String profileId) async {
    _record(ProfileHistoryEntry(
      type: ProfileHistoryEntryType.executionComplete,
      timestamp: DateTime.now(),
      data: {'profileId': profileId},
    ));
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    _record(ProfileHistoryEntry(
      type: ProfileHistoryEntryType.error,
      timestamp: DateTime.now(),
      data: {
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    ));
  }

  void _record(ProfileHistoryEntry entry) {
    _history.add(entry);
    while (_history.length > maxEntries) {
      _history.removeAt(0);
    }
  }
}

/// History entry.
class ProfileHistoryEntry {
  /// Entry type.
  final ProfileHistoryEntryType type;

  /// Timestamp.
  final DateTime timestamp;

  /// Entry data.
  final Map<String, dynamic> data;

  const ProfileHistoryEntry({
    required this.type,
    required this.timestamp,
    required this.data,
  });

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
      };
}

/// History entry types.
enum ProfileHistoryEntryType {
  executionStart,
  profileLoaded,
  appraisalComplete,
  decisionComplete,
  renderComplete,
  executionComplete,
  error,
}
