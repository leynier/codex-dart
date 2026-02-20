import 'dart:convert';
import 'dart:io';

final class OutputSchemaFile {
  const OutputSchemaFile({required this.schemaPath, required this.cleanup});

  final String? schemaPath;
  final Future<void> Function() cleanup;
}

Future<OutputSchemaFile> createOutputSchemaFile(Object? schema) async {
  if (schema == null) {
    return OutputSchemaFile(schemaPath: null, cleanup: () async {});
  }

  if (schema is! Map) {
    throw ArgumentError('outputSchema must be a plain JSON object');
  }

  final schemaDir = await Directory.systemTemp.createTemp(
    'codex-output-schema-',
  );
  final schemaPath = '${schemaDir.path}${Platform.pathSeparator}schema.json';

  Future<void> cleanup() async {
    try {
      await schemaDir.delete(recursive: true);
    } catch (_) {
      // ignore
    }
  }

  try {
    final schemaText = jsonEncode(schema);
    await File(schemaPath).writeAsString(schemaText);
    return OutputSchemaFile(schemaPath: schemaPath, cleanup: cleanup);
  } catch (_) {
    await cleanup();
    rethrow;
  }
}
