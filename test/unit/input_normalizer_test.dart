import 'package:codex/src/input_normalizer.dart';
import 'package:codex/src/options.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeInput', () {
    test('accepts plain text input', () {
      final normalized = normalizeInput('hello');

      expect(normalized.prompt, 'hello');
      expect(normalized.images, isEmpty);
    });

    test('combines text parts and forwards image paths', () {
      final normalized = normalizeInput(<UserInput>[
        UserInput.text('Describe file changes'),
        UserInput.text('Focus on tests'),
        UserInput.localImage('/tmp/first.png'),
      ]);

      expect(normalized.prompt, 'Describe file changes\n\nFocus on tests');
      expect(normalized.images, <String>['/tmp/first.png']);
    });

    test('accepts map-based input items', () {
      final normalized = normalizeInput(<Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': 'one'},
        <String, Object?>{'type': 'local_image', 'path': '/tmp/two.png'},
      ]);

      expect(normalized.prompt, 'one');
      expect(normalized.images, <String>['/tmp/two.png']);
    });

    test('rejects unsupported input item', () {
      expect(() => normalizeInput(<Object>[42]), throwsA(isA<ArgumentError>()));
    });
  });
}
