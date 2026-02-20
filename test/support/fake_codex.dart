import 'dart:convert';
import 'dart:io';

final class FakeCodex {
  FakeCodex({
    required this.directory,
    required this.executablePath,
    required this.environment,
    required this.argsPath,
    required this.stdinPath,
    required this.envPath,
  });

  final Directory directory;
  final String executablePath;
  final Map<String, String> environment;
  final String argsPath;
  final String stdinPath;
  final String envPath;

  Future<List<String>> readArgs() async {
    final content = await File(argsPath).readAsString();
    final decoded = jsonDecode(content);
    return (decoded as List)
        .map((Object? value) => value.toString())
        .toList(growable: false);
  }

  Future<String> readStdin() async {
    return File(stdinPath).readAsString();
  }

  Future<Map<String, String>> readSelectedEnv() async {
    final content = await File(envPath).readAsString();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    return decoded.map(
      (String key, dynamic value) => MapEntry(key, value?.toString() ?? ''),
    );
  }

  Future<void> dispose() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

Future<FakeCodex> createFakeCodex({
  List<String>? stdoutLines,
  String mode = 'success',
}) async {
  final directory = await Directory.systemTemp.createTemp('codex-fake-');
  final argsPath = '${directory.path}${Platform.pathSeparator}args.json';
  final stdinPath = '${directory.path}${Platform.pathSeparator}stdin.txt';
  final envPath = '${directory.path}${Platform.pathSeparator}env.json';
  final scriptPath = '${directory.path}${Platform.pathSeparator}driver.dart';

  await File(scriptPath).writeAsString(_driverScript);

  final executablePath = Platform.isWindows
      ? '${directory.path}${Platform.pathSeparator}codex.cmd'
      : '${directory.path}${Platform.pathSeparator}codex';

  if (Platform.isWindows) {
    final escapedDart = Platform.resolvedExecutable.replaceAll('"', '""');
    final escapedScript = scriptPath.replaceAll('"', '""');
    await File(
      executablePath,
    ).writeAsString('@echo off\r\n"$escapedDart" "$escapedScript" %*\r\n');
  } else {
    final escapedDart = Platform.resolvedExecutable.replaceAll("'", "'\"'\"'");
    final escapedScript = scriptPath.replaceAll("'", "'\"'\"'");
    await File(executablePath).writeAsString(
      "#!/bin/sh\nexec '$escapedDart' '$escapedScript' \"\$@\"\n",
    );
    await Process.run('chmod', <String>['+x', executablePath]);
  }

  final environment = <String, String>{
    'FAKE_CODEX_ARGS_FILE': argsPath,
    'FAKE_CODEX_STDIN_FILE': stdinPath,
    'FAKE_CODEX_ENV_FILE': envPath,
    'FAKE_CODEX_MODE': mode,
    'FAKE_CODEX_STDOUT_LINES': jsonEncode(stdoutLines ?? _defaultStdoutLines),
  };

  return FakeCodex(
    directory: directory,
    executablePath: executablePath,
    environment: environment,
    argsPath: argsPath,
    stdinPath: stdinPath,
    envPath: envPath,
  );
}

final List<String> _defaultStdoutLines = <String>[
  '{"type":"thread.started","thread_id":"thread_1"}',
  '{"type":"turn.started"}',
  '{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"Hi!"}}',
  '{"type":"turn.completed","usage":{"input_tokens":42,"cached_input_tokens":12,"output_tokens":5}}',
];

const String _driverScript = r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final argsFile = Platform.environment['FAKE_CODEX_ARGS_FILE'];
  final stdinFile = Platform.environment['FAKE_CODEX_STDIN_FILE'];
  final envFile = Platform.environment['FAKE_CODEX_ENV_FILE'];
  final mode = Platform.environment['FAKE_CODEX_MODE'] ?? 'success';
  final stdoutLinesRaw = Platform.environment['FAKE_CODEX_STDOUT_LINES'] ?? '[]';

  if (argsFile != null) {
    await File(argsFile).writeAsString(jsonEncode(args));
  }

  final input = await stdin.transform(utf8.decoder).join();
  if (stdinFile != null) {
    await File(stdinFile).writeAsString(input);
  }

  if (envFile != null) {
    final selected = <String, String>{};
    for (final key in <String>[
      'OPENAI_BASE_URL',
      'CODEX_API_KEY',
      'CODEX_INTERNAL_ORIGINATOR_OVERRIDE',
      'CUSTOM_ENV',
      'LEAK_TEST',
    ]) {
      final value = Platform.environment[key];
      if (value != null) {
        selected[key] = value;
      }
    }
    await File(envFile).writeAsString(jsonEncode(selected));
  }

  switch (mode) {
    case 'invalid_json':
      stdout.writeln('this is not json');
      return;
    case 'exit_error':
      stderr.write('boom');
      exit(2);
    case 'hang':
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    default:
      final lines = (jsonDecode(stdoutLinesRaw) as List)
          .map((Object? value) => value.toString())
          .toList(growable: false);
      for (final line in lines) {
        stdout.writeln(line);
      }
      return;
  }
}
''';
