import 'dart:io';

import 'package:codex/src/output_schema_file.dart';
import 'package:test/test.dart';

void main() {
  group('createOutputSchemaFile', () {
    test('returns no schema path when schema is null', () async {
      final file = await createOutputSchemaFile(null);
      expect(file.schemaPath, isNull);
      await file.cleanup();
    });

    test('writes schema file and cleans up after cleanup call', () async {
      final schema = <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'answer': <String, Object?>{'type': 'string'},
        },
      };

      final file = await createOutputSchemaFile(schema);
      final schemaPath = file.schemaPath;

      expect(schemaPath, isNotNull);
      expect(await File(schemaPath!).exists(), isTrue);

      await file.cleanup();
      expect(await File(schemaPath).exists(), isFalse);
    });

    test('rejects non-object schema', () {
      expect(
        () => createOutputSchemaFile(<Object?>['not-an-object']),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
