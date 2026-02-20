# codex

Dart SDK for Codex.

This package wraps the `codex` CLI and exchanges JSONL events over stdin/stdout.

## Installation

```bash
dart pub add codex
```

## Quickstart

```dart
import 'package:codex/codex.dart';

Future<void> main() async {
  final codex = Codex();
  final thread = codex.startThread();

  final turn = await thread.run('Diagnose the failing test and propose a fix.');
  print(turn.finalResponse);
}
```

## Streaming

```dart
import 'package:codex/codex.dart';

Future<void> main() async {
  final codex = Codex();
  final thread = codex.startThread();

  final streamed = await thread.runStreamed('Inspect this repo and summarize risks.');
  await for (final event in streamed.events) {
    if (event is ItemCompletedEvent) {
      print(event.item.runtimeType);
    }
  }
}
```

## Structured output

```dart
import 'package:codex/codex.dart';

Future<void> main() async {
  final codex = Codex();
  final thread = codex.startThread();

  final schema = {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
      'status': {
        'type': 'string',
        'enum': ['ok', 'action_required'],
      },
    },
    'required': ['summary', 'status'],
    'additionalProperties': false,
  };

  final result = await thread.run(
    'Summarize repository status',
    TurnOptions(outputSchema: schema),
  );

  print(result.finalResponse);
}
```

## Binary resolution strategy

This package resolves the executable in this order:

1. `codexPathOverride`
2. `CODEX_EXECUTABLE`
3. `PATH`

If `codex` cannot be found, it throws a clear error with remediation steps.

## Attribution and license

This project is a Dart port inspired by the TypeScript SDK in the OpenAI Codex repository (`sdk/typescript`).

- Upstream project: https://github.com/openai/codex
- Upstream license: Apache-2.0

See `LICENSE` and `NOTICE` in this repository for attribution details.
