import 'package:codex/src/config_serializer.dart';
import 'package:test/test.dart';

void main() {
  group('serializeConfigOverrides', () {
    test('serializes nested overrides to dotted TOML paths', () {
      final overrides = serializeConfigOverrides(<String, Object?>{
        'approval_policy': 'never',
        'sandbox_workspace_write': <String, Object?>{'network_access': true},
        'retry_budget': 3,
        'tool_rules': <String, Object?>{
          'allow': <Object?>['git status', 'git diff'],
        },
      });

      expect(overrides, <String>[
        'approval_policy="never"',
        'sandbox_workspace_write.network_access=true',
        'retry_budget=3',
        'tool_rules.allow=["git status", "git diff"]',
      ]);
    });

    test('serializes empty nested objects', () {
      final overrides = serializeConfigOverrides(<String, Object?>{
        'sandbox_workspace_write': <String, Object?>{},
      });

      expect(overrides, <String>['sandbox_workspace_write={}']);
    });

    test('rejects null values', () {
      expect(
        () => serializeConfigOverrides(<String, Object?>{
          'approval_policy': null,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects non-finite numbers', () {
      expect(
        () => serializeConfigOverrides(<String, Object?>{
          'threshold': double.nan,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
