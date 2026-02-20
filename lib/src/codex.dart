import 'exec.dart';
import 'options.dart';
import 'thread.dart';

class Codex {
  Codex({
    String? codexPathOverride,
    String? baseUrl,
    String? apiKey,
    Map<String, dynamic>? config,
    Map<String, String>? env,
  }) : _exec = CodexExec(
         codexPathOverride: codexPathOverride,
         env: env,
         configOverrides: _normalizeConfig(config),
       ),
       _baseUrl = baseUrl,
       _apiKey = apiKey;

  final CodexExec _exec;
  final String? _baseUrl;
  final String? _apiKey;

  Thread startThread([ThreadOptions options = const ThreadOptions()]) {
    return Thread.internal(
      exec: _exec,
      baseUrl: _baseUrl,
      apiKey: _apiKey,
      threadOptions: options,
    );
  }

  Thread resumeThread(
    String id, [
    ThreadOptions options = const ThreadOptions(),
  ]) {
    return Thread.internal(
      exec: _exec,
      baseUrl: _baseUrl,
      apiKey: _apiKey,
      threadOptions: options,
      id: id,
    );
  }
}

Map<String, Object?>? _normalizeConfig(Map<String, dynamic>? config) {
  if (config == null) {
    return null;
  }
  return config.map((key, value) => MapEntry(key, value));
}
