import 'dart:collection';

import 'items.dart';

final class Usage {
  const Usage({
    required this.inputTokens,
    required this.cachedInputTokens,
    required this.outputTokens,
  });

  factory Usage.fromJson(Map<String, Object?> json) {
    return Usage(
      inputTokens: _readInt(json, 'input_tokens'),
      cachedInputTokens: _readInt(json, 'cached_input_tokens'),
      outputTokens: _readInt(json, 'output_tokens'),
    );
  }

  final int inputTokens;
  final int cachedInputTokens;
  final int outputTokens;
}

final class ThreadError {
  const ThreadError({required this.message});

  factory ThreadError.fromJson(Map<String, Object?> json) {
    return ThreadError(message: _readString(json, 'message'));
  }

  final String message;
}

sealed class ThreadEvent {
  const ThreadEvent();

  static ThreadEvent fromJson(Map<String, Object?> json) {
    final type = _readString(json, 'type');
    switch (type) {
      case 'thread.started':
        return ThreadStartedEvent(threadId: _readString(json, 'thread_id'));
      case 'turn.started':
        return const TurnStartedEvent();
      case 'turn.completed':
        return TurnCompletedEvent(
          usage: Usage.fromJson(_readMap(json, 'usage')),
        );
      case 'turn.failed':
        return TurnFailedEvent(
          error: ThreadError.fromJson(_readMap(json, 'error')),
        );
      case 'item.started':
        return ItemStartedEvent(
          item: ThreadItem.fromJson(_readMap(json, 'item')),
        );
      case 'item.updated':
        return ItemUpdatedEvent(
          item: ThreadItem.fromJson(_readMap(json, 'item')),
        );
      case 'item.completed':
        return ItemCompletedEvent(
          item: ThreadItem.fromJson(_readMap(json, 'item')),
        );
      case 'error':
        return ThreadErrorEvent(message: _readString(json, 'message'));
      default:
        throw FormatException('Unsupported thread event type: $type');
    }
  }
}

final class ThreadStartedEvent extends ThreadEvent {
  const ThreadStartedEvent({required this.threadId});

  final String threadId;
}

final class TurnStartedEvent extends ThreadEvent {
  const TurnStartedEvent();
}

final class TurnCompletedEvent extends ThreadEvent {
  const TurnCompletedEvent({required this.usage});

  final Usage usage;
}

final class TurnFailedEvent extends ThreadEvent {
  const TurnFailedEvent({required this.error});

  final ThreadError error;
}

final class ItemStartedEvent extends ThreadEvent {
  const ItemStartedEvent({required this.item});

  final ThreadItem item;
}

final class ItemUpdatedEvent extends ThreadEvent {
  const ItemUpdatedEvent({required this.item});

  final ThreadItem item;
}

final class ItemCompletedEvent extends ThreadEvent {
  const ItemCompletedEvent({required this.item});

  final ThreadItem item;
}

final class ThreadErrorEvent extends ThreadEvent {
  const ThreadErrorEvent({required this.message});

  final String message;
}

Map<String, Object?> _readMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map) {
    return UnmodifiableMapView<String, Object?>(
      value.map(
        (Object? mapKey, Object? mapValue) =>
            MapEntry(mapKey.toString(), mapValue),
      ),
    );
  }
  throw FormatException('Expected a JSON object for $key');
}

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected a string for $key');
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected an int for $key');
}
