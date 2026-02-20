import 'options.dart';

final class NormalizedInput {
  const NormalizedInput({required this.prompt, required this.images});

  final String prompt;
  final List<String> images;
}

NormalizedInput normalizeInput(Object input) {
  if (input is String) {
    return NormalizedInput(prompt: input, images: const <String>[]);
  }

  if (input is! List) {
    throw ArgumentError('Input must be a String or List<UserInput>.');
  }

  final promptParts = <String>[];
  final images = <String>[];

  for (final Object? item in input) {
    if (item is TextUserInput) {
      promptParts.add(item.text);
      continue;
    }
    if (item is LocalImageUserInput) {
      images.add(item.path);
      continue;
    }
    if (item is Map) {
      _consumeMapInput(item, promptParts, images);
      continue;
    }
    throw ArgumentError('Unsupported input item type: ${item.runtimeType}');
  }

  return NormalizedInput(
    prompt: promptParts.join('\n\n'),
    images: List.unmodifiable(images),
  );
}

void _consumeMapInput(
  Map<Object?, Object?> map,
  List<String> promptParts,
  List<String> images,
) {
  final type = map['type'];
  if (type is! String) {
    throw ArgumentError('Input item map must contain a string "type" field.');
  }

  switch (type) {
    case 'text':
      final text = map['text'];
      if (text is! String) {
        throw ArgumentError(
          'Text input item must contain a string "text" field.',
        );
      }
      promptParts.add(text);
      return;
    case 'local_image':
      final path = map['path'];
      if (path is! String) {
        throw ArgumentError(
          'Local image input item must contain a string "path" field.',
        );
      }
      images.add(path);
      return;
    default:
      throw ArgumentError('Unsupported input item type: $type');
  }
}
