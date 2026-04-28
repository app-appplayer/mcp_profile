/// Appraisal Module - Runtime metric computation per spec/02.
///
/// This module provides the runtime appraisal pipeline that computes
/// context-aware metrics (Risk, Uncertainty, Urgency, Trust, Sentiment)
/// from FactGraph data.
///
/// Note: This is different from profile_appraisal.dart which assesses
/// the quality of profile definitions.
library;

export 'appraisal_engine.dart';
export 'appraisal_result.dart';
export 'metric_definition.dart';
export 'metric_source.dart';
export 'normalization.dart';
