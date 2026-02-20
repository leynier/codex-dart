import 'dart:convert';

import 'events.dart';
import 'exceptions.dart';
import 'exec.dart';
import 'input_normalizer.dart';
import 'items.dart';
import 'options.dart';
import 'output_schema_file.dart';

typedef Input = Object;

final class RunResult {
  const RunResult({
    required this.items,
    required this.finalResponse,
    required this.usage,
  });

  final List<ThreadItem> items;
  final String finalResponse;
  final Usage? usage;
}

final class RunStreamedResult {
  const RunStreamedResult({required this.events});

  final Stream<ThreadEvent> events;
}

class Thread {
  Thread.internal({
    required CodexExec exec,
    required String? baseUrl,
    required String? apiKey,
    required ThreadOptions threadOptions,
    String? id,
  }) : _exec = exec,
       _baseUrl = baseUrl,
       _apiKey = apiKey,
       _threadOptions = threadOptions,
       _id = id;

  final CodexExec _exec;
  final String? _baseUrl;
  final String? _apiKey;
  final ThreadOptions _threadOptions;

  String? _id;

  String? get id => _id;

  Future<RunStreamedResult> runStreamed(
    Object input, [
    TurnOptions turnOptions = const TurnOptions(),
  ]) async {
    return RunStreamedResult(events: _runStreamedInternal(input, turnOptions));
  }

  Stream<ThreadEvent> _runStreamedInternal(
    Object input,
    TurnOptions turnOptions,
  ) async* {
    final outputSchemaFile = await createOutputSchemaFile(
      turnOptions.outputSchema,
    );
    final normalized = normalizeInput(input);

    final stream = _exec.run(
      CodexExecArgs(
        input: normalized.prompt,
        baseUrl: _baseUrl,
        apiKey: _apiKey,
        threadId: _id,
        images: normalized.images,
        model: _threadOptions.model,
        sandboxMode: _threadOptions.sandboxMode,
        workingDirectory: _threadOptions.workingDirectory,
        additionalDirectories: _threadOptions.additionalDirectories,
        skipGitRepoCheck: _threadOptions.skipGitRepoCheck,
        outputSchemaFile: outputSchemaFile.schemaPath,
        modelReasoningEffort: _threadOptions.modelReasoningEffort,
        cancelSignal: turnOptions.cancelSignal,
        networkAccessEnabled: _threadOptions.networkAccessEnabled,
        webSearchMode: _threadOptions.webSearchMode,
        webSearchEnabled: _threadOptions.webSearchEnabled,
        approvalPolicy: _threadOptions.approvalPolicy,
      ),
    );

    try {
      await for (final line in stream) {
        final json = _parseLine(line);
        final event = _parseEvent(json, line);
        if (event is ThreadStartedEvent) {
          _id = event.threadId;
        }
        yield event;
      }
    } finally {
      await outputSchemaFile.cleanup();
    }
  }

  Future<RunResult> run(
    Object input, [
    TurnOptions turnOptions = const TurnOptions(),
  ]) async {
    final items = <ThreadItem>[];
    String finalResponse = '';
    Usage? usage;
    ThreadError? turnFailure;

    await for (final event in _runStreamedInternal(input, turnOptions)) {
      if (event is ItemCompletedEvent) {
        final item = event.item;
        if (item is AgentMessageItem) {
          finalResponse = item.text;
        }
        items.add(item);
        continue;
      }

      if (event is TurnCompletedEvent) {
        usage = event.usage;
        continue;
      }

      if (event is TurnFailedEvent) {
        turnFailure = event.error;
        break;
      }
    }

    if (turnFailure != null) {
      throw ThreadRunException(turnFailure.message);
    }

    return RunResult(
      items: List.unmodifiable(items),
      finalResponse: finalResponse,
      usage: usage,
    );
  }
}

Map<String, Object?> _parseLine(String line) {
  try {
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      throw const FormatException('Event JSON line is not an object.');
    }
    return decoded.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  } catch (error) {
    throw CodexParseException(
      'Failed to parse event line as JSON: $line',
      cause: error,
    );
  }
}

ThreadEvent _parseEvent(Map<String, Object?> json, String line) {
  try {
    return ThreadEvent.fromJson(json);
  } catch (error) {
    throw CodexParseException(
      'Failed to parse thread event from line: $line',
      cause: error,
    );
  }
}
