import 'dart:convert';

List<String> serializeConfigOverrides(Map<String, Object?> configOverrides) {
  final overrides = <String>[];
  _flattenConfigOverrides(configOverrides, '', overrides);
  return overrides;
}

void _flattenConfigOverrides(
  Object? value,
  String prefix,
  List<String> overrides,
) {
  if (!_isPlainObject(value)) {
    if (prefix.isEmpty) {
      throw ArgumentError('Codex config overrides must be a plain object');
    }
    overrides.add('$prefix=${_toTomlValue(value, prefix)}');
    return;
  }

  final entries = _asStringKeyMap(value).entries.toList(growable: false);
  if (prefix.isEmpty && entries.isEmpty) {
    return;
  }

  if (prefix.isNotEmpty && entries.isEmpty) {
    overrides.add('$prefix={}');
    return;
  }

  for (final entry in entries) {
    final key = entry.key;
    final child = entry.value;

    if (key.isEmpty) {
      throw ArgumentError(
        'Codex config override keys must be non-empty strings',
      );
    }
    if (child == null) {
      throw ArgumentError('Codex config override at $key cannot be null');
    }

    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (_isPlainObject(child)) {
      _flattenConfigOverrides(child, path, overrides);
    } else {
      overrides.add('$path=${_toTomlValue(child, path)}');
    }
  }
}

String _toTomlValue(Object? value, String path) {
  if (value is String) {
    return jsonEncode(value);
  }
  if (value is num) {
    if (value is double && !value.isFinite) {
      throw ArgumentError(
        'Codex config override at $path must be a finite number',
      );
    }
    return '$value';
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is List) {
    final rendered = <String>[];
    for (var i = 0; i < value.length; i += 1) {
      final item = value[i];
      if (item == null) {
        throw ArgumentError(
          'Codex config override at $path[$i] cannot be null',
        );
      }
      rendered.add(_toTomlValue(item, '$path[$i]'));
    }
    return '[${rendered.join(', ')}]';
  }
  if (_isPlainObject(value)) {
    final parts = <String>[];
    final object = _asStringKeyMap(value);
    for (final entry in object.entries) {
      final key = entry.key;
      final child = entry.value;
      if (key.isEmpty) {
        throw ArgumentError(
          'Codex config override keys must be non-empty strings',
        );
      }
      if (child == null) {
        throw ArgumentError(
          'Codex config override at $path.$key cannot be null',
        );
      }
      parts.add(
        '${_formatTomlKey(key)} = ${_toTomlValue(child, '$path.$key')}',
      );
    }
    return '{${parts.join(', ')}}';
  }

  throw ArgumentError(
    'Unsupported Codex config override value at $path: ${value.runtimeType}',
  );
}

final RegExp _tomlBareKey = RegExp(r'^[A-Za-z0-9_-]+$');

String _formatTomlKey(String key) {
  return _tomlBareKey.hasMatch(key) ? key : jsonEncode(key);
}

bool _isPlainObject(Object? value) => value is Map;

Map<String, Object?> _asStringKeyMap(Object? value) {
  if (value is! Map) {
    throw ArgumentError('Expected a map object');
  }
  return value.map((Object? key, Object? val) => MapEntry(key.toString(), val));
}
