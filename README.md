# MCP Profile

## Support This Project

If you find this package useful, consider supporting ongoing development on PayPal.

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)
Support makemind via [PayPal](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)

---

### MCP Knowledge Package Family

- [`mcp_bundle`](https://pub.dev/packages/mcp_bundle): Bundle schema, loader, validator, and expression language for MCP ecosystem.
- [`mcp_fact_graph`](https://pub.dev/packages/mcp_fact_graph): Temporal knowledge graph with evidence-based fact management and summarization.
- [`mcp_skill`](https://pub.dev/packages/mcp_skill): Skill definitions and runtime execution for AI capabilities.
- [`mcp_profile`](https://pub.dev/packages/mcp_profile): Profile definitions for AI personas with template rendering and appraisal.
- [`mcp_knowledge_ops`](https://pub.dev/packages/mcp_knowledge_ops): Knowledge operations including pipelines, workflows, and scheduling.
- [`mcp_knowledge`](https://pub.dev/packages/mcp_knowledge): Unified integration package for the complete knowledge system.

---

A powerful Dart package for defining AI personas with template rendering, context injection, and appraisal scoring. Part of the MakeMind MCP ecosystem.

## Features

### Core Features
- **Profile Definitions**: Define AI personas with system prompts and metadata
- **Template Rendering**: Mustache-style template rendering with context injection
- **Profile Selection**: Intelligent profile selection based on context
- **Appraisal System**: Score and validate rendered profiles

### Profile Model
- **System Prompts**: Customizable system prompt templates
- **Context Variables**: Dynamic variable injection
- **Tags & Categories**: Organize profiles with metadata
- **Versioning**: Track profile versions

### Advanced Features
- **Fact Graph Integration**: Inject entity context from fact graph
- **Expression Language**: Use MCP expression language in templates
- **Port-Based Architecture**: Clean dependency injection via ports
- **Execution Tracking**: Full rendering history and metrics

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  mcp_profile: ^0.1.0
```

### Basic Usage

```dart
import 'package:mcp_profile/mcp_profile.dart';

void main() async {
  // Create profile runtime with ports
  final runtime = ProfileRuntime(
    ports: ProfilePorts(
      storage: InMemoryProfileStorage(),
      selection: DefaultProfileSelection(),
      render: MustacheRenderPort(),
      factGraph: myFactGraphPort,
    ),
  );

  // Define a profile
  final profile = Profile(
    id: 'friendly_assistant',
    name: 'Friendly Assistant',
    description: 'A helpful and friendly AI assistant',
    systemPrompt: '''
You are a friendly assistant helping {{user.name}}.

User preferences:
{{#user.preferences}}
- {{.}}
{{/user.preferences}}

Always be helpful and respectful.
''',
    tags: ['assistant', 'friendly'],
    version: '1.0.0',
  );

  // Register profile
  await runtime.registerProfile(profile);

  // Render profile with context
  final result = await runtime.execute(
    profileId: 'friendly_assistant',
    context: ProfileContext(
      entity: {
        'user': {
          'name': 'John',
          'preferences': ['dark mode', 'concise responses'],
        },
      },
    ),
  );

  print('System Prompt: ${result.content}');
}
```

## Core Concepts

### Profiles

Profiles define AI personas with system prompts:

```dart
final profile = Profile(
  id: 'technical_expert',
  name: 'Technical Expert',
  description: 'Expert in software development',
  systemPrompt: '''
You are a technical expert specializing in {{domain}}.

Current context:
- Project: {{project.name}}
- Language: {{project.language}}

Provide detailed technical guidance.
''',
  tags: ['technical', 'expert'],
  category: 'development',
  version: '1.0.0',
);
```

### Profile Context

Context provides data for template rendering:

```dart
final context = ProfileContext(
  entity: {
    'domain': 'Dart development',
    'project': {
      'name': 'MCP Knowledge',
      'language': 'Dart',
    },
  },
  session: {
    'currentTask': 'Code review',
  },
);
```

### Profile Selection

Select the best profile based on context:

```dart
final selection = await runtime.selectProfile(
  candidates: ['friendly_assistant', 'technical_expert'],
  context: selectionContext,
);

print('Selected: ${selection.profileId}');
print('Confidence: ${selection.confidence}');
```

### Appraisal

Score and validate rendered profiles:

```dart
final result = await runtime.execute(
  profileId: 'friendly_assistant',
  context: context,
  appraise: true,
);

print('Appraisal Score: ${result.appraisal?.score}');
print('Feedback: ${result.appraisal?.feedback}');
```

## Port-Based Architecture

The package uses a port-based dependency injection pattern:

```dart
// Define custom render port
class MyRenderPort implements ProfileRenderPort {
  @override
  Future<String> render(String template, Map<String, dynamic> context) async {
    // Your template engine implementation
  }
}

// Define custom selection port
class MySelectionPort implements ProfileSelectionPort {
  @override
  Future<ProfileSelectionResult> select(
    List<Profile> candidates,
    Map<String, dynamic> context,
  ) async {
    // Your selection logic
  }
}

// Inject custom ports
final runtime = ProfileRuntime(
  ports: ProfilePorts(
    storage: MyProfileStorage(),
    render: MyRenderPort(),
    selection: MySelectionPort(),
    factGraph: myFactGraphPort,
  ),
);
```

## API Reference

### ProfileRuntime

| Method | Description |
|--------|-------------|
| `registerProfile(profile)` | Register a profile definition |
| `execute(profileId, context)` | Render a profile with context |
| `selectProfile(candidates, context)` | Select best profile |
| `getProfile(profileId)` | Get profile definition |
| `listProfiles(filter)` | List available profiles |

### ProfileExecutionResult

| Property | Description |
|----------|-------------|
| `success` | Whether rendering succeeded |
| `content` | Rendered system prompt |
| `error` | Error message if failed |
| `duration` | Rendering duration |
| `appraisal` | Appraisal result if requested |

## Examples

### Complete Examples Available
- `example/basic_profile.dart` - Basic profile definition and rendering
- `example/context_injection.dart` - Context variable injection
- `example/profile_selection.dart` - Profile selection workflow
- `example/fact_graph_integration.dart` - Fact graph context integration

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## Support

- [Documentation](https://github.com/app-appplayer/mcp_profile/wiki)
- [Issue Tracker](https://github.com/app-appplayer/mcp_profile/issues)
- [Discussions](https://github.com/app-appplayer/mcp_profile/discussions)
- [Support on Patreon](https://www.patreon.com/mcpdevstudio)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
