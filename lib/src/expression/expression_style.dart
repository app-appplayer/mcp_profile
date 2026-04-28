/// Expression Style - Re-export from mcp_bundle.
///
/// All expression style types (ExpressionStyle, ToneConfig, FormatConfig,
/// HedgingConfig, AudienceConfig, LanguageConfig, VocabularyConfig,
/// GrammarConfig, FormattedResponse, and related enums) are now defined
/// in mcp_bundle (Contract Layer).
///
/// This file re-exports them for backward compatibility.
/// Note: FormattedResponse is also exported from mcp_bundle's
/// expression_style.dart, so expression_port.dart should hide it
/// if it defines its own version.
library;

export 'package:mcp_bundle/src/types/expression_style.dart';
