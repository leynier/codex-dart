import 'dart:collection';

sealed class ThreadItem {
  const ThreadItem(this.id);

  final String id;

  static ThreadItem fromJson(Map<String, Object?> json) {
    final id = _readString(json, 'id');
    final type = _readString(json, 'type');

    switch (type) {
      case 'agent_message':
        return AgentMessageItem(id: id, text: _readString(json, 'text'));
      case 'reasoning':
        return ReasoningItem(id: id, text: _readString(json, 'text'));
      case 'command_execution':
        return CommandExecutionItem(
          id: id,
          command: _readString(json, 'command'),
          aggregatedOutput: _readString(
            json,
            'aggregated_output',
            defaultValue: '',
          ),
          exitCode: _readIntOrNull(json, 'exit_code'),
          status: CommandExecutionStatusX.parse(_readString(json, 'status')),
        );
      case 'file_change':
        return FileChangeItem(
          id: id,
          changes: _readList(json, 'changes')
              .map((Object? raw) {
                final map = _asMap(raw, 'file_change.changes[]');
                return FileUpdateChange(
                  path: _readString(map, 'path'),
                  kind: PatchChangeKindX.parse(_readString(map, 'kind')),
                );
              })
              .toList(growable: false),
          status: PatchApplyStatusX.parse(_readString(json, 'status')),
        );
      case 'mcp_tool_call':
        return McpToolCallItem(
          id: id,
          server: _readString(json, 'server'),
          tool: _readString(json, 'tool'),
          arguments: json['arguments'],
          result: _readOptionalMap(json, 'result') == null
              ? null
              : McpToolCallResult(
                  content: _readList(
                    _readOptionalMap(json, 'result')!,
                    'content',
                  ),
                  structuredContent: _readOptionalMap(
                    json,
                    'result',
                  )!['structured_content'],
                ),
          error: _readOptionalMap(json, 'error') == null
              ? null
              : McpToolCallError(
                  message: _readString(
                    _readOptionalMap(json, 'error')!,
                    'message',
                  ),
                ),
          status: McpToolCallStatusX.parse(_readString(json, 'status')),
        );
      case 'web_search':
        return WebSearchItem(
          id: id,
          query: _readString(json, 'query', defaultValue: ''),
        );
      case 'todo_list':
        return TodoListItem(
          id: id,
          items: _readList(json, 'items')
              .map((Object? raw) {
                final map = _asMap(raw, 'todo_list.items[]');
                return TodoEntry(
                  text: _readString(map, 'text'),
                  completed: _readBool(map, 'completed'),
                );
              })
              .toList(growable: false),
        );
      case 'error':
        return ErrorItem(id: id, message: _readString(json, 'message'));
      default:
        throw FormatException('Unsupported thread item type: $type');
    }
  }
}

final class AgentMessageItem extends ThreadItem {
  const AgentMessageItem({required String id, required this.text}) : super(id);
  final String text;
}

final class ReasoningItem extends ThreadItem {
  const ReasoningItem({required String id, required this.text}) : super(id);
  final String text;
}

enum CommandExecutionStatus { inProgress, completed, failed, declined }

extension CommandExecutionStatusX on CommandExecutionStatus {
  static CommandExecutionStatus parse(String value) {
    return switch (value) {
      'in_progress' => CommandExecutionStatus.inProgress,
      'completed' => CommandExecutionStatus.completed,
      'failed' => CommandExecutionStatus.failed,
      'declined' => CommandExecutionStatus.declined,
      _ => throw FormatException(
        'Unsupported command execution status: $value',
      ),
    };
  }
}

final class CommandExecutionItem extends ThreadItem {
  const CommandExecutionItem({
    required String id,
    required this.command,
    required this.aggregatedOutput,
    required this.status,
    this.exitCode,
  }) : super(id);

  final String command;
  final String aggregatedOutput;
  final int? exitCode;
  final CommandExecutionStatus status;
}

enum PatchChangeKind { add, delete, update }

extension PatchChangeKindX on PatchChangeKind {
  static PatchChangeKind parse(String value) {
    return switch (value) {
      'add' => PatchChangeKind.add,
      'delete' => PatchChangeKind.delete,
      'update' => PatchChangeKind.update,
      _ => throw FormatException('Unsupported patch change kind: $value'),
    };
  }
}

final class FileUpdateChange {
  const FileUpdateChange({required this.path, required this.kind});

  final String path;
  final PatchChangeKind kind;
}

enum PatchApplyStatus { inProgress, completed, failed }

extension PatchApplyStatusX on PatchApplyStatus {
  static PatchApplyStatus parse(String value) {
    return switch (value) {
      'in_progress' => PatchApplyStatus.inProgress,
      'completed' => PatchApplyStatus.completed,
      'failed' => PatchApplyStatus.failed,
      _ => throw FormatException('Unsupported patch apply status: $value'),
    };
  }
}

final class FileChangeItem extends ThreadItem {
  const FileChangeItem({
    required String id,
    required this.changes,
    required this.status,
  }) : super(id);

  final List<FileUpdateChange> changes;
  final PatchApplyStatus status;
}

enum McpToolCallStatus { inProgress, completed, failed }

extension McpToolCallStatusX on McpToolCallStatus {
  static McpToolCallStatus parse(String value) {
    return switch (value) {
      'in_progress' => McpToolCallStatus.inProgress,
      'completed' => McpToolCallStatus.completed,
      'failed' => McpToolCallStatus.failed,
      _ => throw FormatException('Unsupported mcp tool call status: $value'),
    };
  }
}

final class McpToolCallResult {
  const McpToolCallResult({
    required this.content,
    required this.structuredContent,
  });

  final List<Object?> content;
  final Object? structuredContent;
}

final class McpToolCallError {
  const McpToolCallError({required this.message});

  final String message;
}

final class McpToolCallItem extends ThreadItem {
  const McpToolCallItem({
    required String id,
    required this.server,
    required this.tool,
    required this.arguments,
    required this.status,
    this.result,
    this.error,
  }) : super(id);

  final String server;
  final String tool;
  final Object? arguments;
  final McpToolCallResult? result;
  final McpToolCallError? error;
  final McpToolCallStatus status;
}

final class WebSearchItem extends ThreadItem {
  const WebSearchItem({required String id, required this.query}) : super(id);

  final String query;
}

final class TodoEntry {
  const TodoEntry({required this.text, required this.completed});

  final String text;
  final bool completed;
}

final class TodoListItem extends ThreadItem {
  const TodoListItem({required String id, required this.items}) : super(id);

  final List<TodoEntry> items;
}

final class ErrorItem extends ThreadItem {
  const ErrorItem({required String id, required this.message}) : super(id);

  final String message;
}

Map<String, Object?> _asMap(Object? value, String field) {
  if (value is Map) {
    return UnmodifiableMapView<String, Object?>(
      value.map((Object? key, Object? val) => MapEntry(key.toString(), val)),
    );
  }
  throw FormatException('Expected a JSON object at $field');
}

String _readString(
  Map<String, Object?> json,
  String key, {
  String? defaultValue,
}) {
  final value = json[key];
  if (value == null && defaultValue != null) {
    return defaultValue;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Expected a string for $key');
}

int? _readIntOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected an int for $key');
}

bool _readBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected a bool for $key');
}

List<Object?> _readList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List) {
    return List<Object?>.from(value);
  }
  throw FormatException('Expected a list for $key');
}

Map<String, Object?>? _readOptionalMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  return _asMap(value, key);
}
