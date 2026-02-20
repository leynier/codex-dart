import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'config_serializer.dart';
import 'exceptions.dart';
import 'options.dart';

const String _internalOriginatorEnv = 'CODEX_INTERNAL_ORIGINATOR_OVERRIDE';
const String _dartSdkOriginator = 'codex_sdk_dart';
const String _codexExecutableEnv = 'CODEX_EXECUTABLE';

final class CodexExecArgs {
  const CodexExecArgs({
    required this.input,
    this.baseUrl,
    this.apiKey,
    this.threadId,
    this.images,
    this.model,
    this.sandboxMode,
    this.workingDirectory,
    this.additionalDirectories,
    this.skipGitRepoCheck,
    this.outputSchemaFile,
    this.modelReasoningEffort,
    this.cancelSignal,
    this.networkAccessEnabled,
    this.webSearchMode,
    this.webSearchEnabled,
    this.approvalPolicy,
  });

  final String input;
  final String? baseUrl;
  final String? apiKey;
  final String? threadId;
  final List<String>? images;
  final String? model;
  final SandboxMode? sandboxMode;
  final String? workingDirectory;
  final List<String>? additionalDirectories;
  final bool? skipGitRepoCheck;
  final String? outputSchemaFile;
  final ModelReasoningEffort? modelReasoningEffort;
  final Future<void>? cancelSignal;
  final bool? networkAccessEnabled;
  final WebSearchMode? webSearchMode;
  final bool? webSearchEnabled;
  final ApprovalMode? approvalPolicy;
}

final class CodexExec {
  CodexExec({
    String? codexPathOverride,
    Map<String, String>? env,
    Map<String, Object?>? configOverrides,
  }) : _executablePath = _resolveCodexPath(codexPathOverride),
       _envOverride = env,
       _configOverrides = configOverrides;

  final String _executablePath;
  final Map<String, String>? _envOverride;
  final Map<String, Object?>? _configOverrides;

  Stream<String> run(CodexExecArgs args) async* {
    final commandArgs = <String>['exec', '--experimental-json'];

    final configOverrides = _configOverrides;
    if (configOverrides != null) {
      for (final override in serializeConfigOverrides(configOverrides)) {
        commandArgs
          ..add('--config')
          ..add(override);
      }
    }

    if (args.model != null) {
      commandArgs
        ..add('--model')
        ..add(args.model!);
    }
    if (args.sandboxMode != null) {
      commandArgs
        ..add('--sandbox')
        ..add(args.sandboxMode!.value);
    }
    if (args.workingDirectory != null) {
      commandArgs
        ..add('--cd')
        ..add(args.workingDirectory!);
    }
    if (args.additionalDirectories != null &&
        args.additionalDirectories!.isNotEmpty) {
      for (final dir in args.additionalDirectories!) {
        commandArgs
          ..add('--add-dir')
          ..add(dir);
      }
    }
    if (args.skipGitRepoCheck == true) {
      commandArgs.add('--skip-git-repo-check');
    }
    if (args.outputSchemaFile != null) {
      commandArgs
        ..add('--output-schema')
        ..add(args.outputSchemaFile!);
    }
    if (args.modelReasoningEffort != null) {
      commandArgs
        ..add('--config')
        ..add('model_reasoning_effort="${args.modelReasoningEffort!.value}"');
    }
    if (args.networkAccessEnabled != null) {
      commandArgs
        ..add('--config')
        ..add(
          'sandbox_workspace_write.network_access=${args.networkAccessEnabled}',
        );
    }
    if (args.webSearchMode != null) {
      commandArgs
        ..add('--config')
        ..add('web_search="${args.webSearchMode!.value}"');
    } else if (args.webSearchEnabled == true) {
      commandArgs
        ..add('--config')
        ..add('web_search="live"');
    } else if (args.webSearchEnabled == false) {
      commandArgs
        ..add('--config')
        ..add('web_search="disabled"');
    }
    if (args.approvalPolicy != null) {
      commandArgs
        ..add('--config')
        ..add('approval_policy="${args.approvalPolicy!.value}"');
    }
    if (args.threadId != null) {
      commandArgs
        ..add('resume')
        ..add(args.threadId!);
    }
    if (args.images != null && args.images!.isNotEmpty) {
      for (final image in args.images!) {
        commandArgs
          ..add('--image')
          ..add(image);
      }
    }

    final env = _buildEnvironment(baseUrl: args.baseUrl, apiKey: args.apiKey);

    final process = await _startProcess(_executablePath, commandArgs, env);
    var canceled = false;
    var exited = false;

    final stderrBuilder = BytesBuilder(copy: false);
    final stderrSubscription = process.stderr.listen((data) {
      stderrBuilder.add(data);
    });

    void requestCancel() {
      if (canceled || exited) {
        return;
      }
      canceled = true;
      _killProcess(process);
      Timer(const Duration(milliseconds: 250), () {
        if (!exited) {
          _killProcess(process, force: true);
        }
      });
    }

    if (args.cancelSignal != null) {
      unawaited(args.cancelSignal!.then((_) => requestCancel()));
    }

    try {
      process.stdin.write(args.input);
      await process.stdin.close();

      await for (final line
          in process.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        yield line;
      }

      final exitCode = await process.exitCode;
      exited = true;
      await stderrSubscription.cancel();

      if (canceled) {
        throw CodexCanceledException('Codex execution was canceled.');
      }

      if (exitCode != 0) {
        final stderr = utf8
            .decode(stderrBuilder.takeBytes(), allowMalformed: true)
            .trim();
        final detail = stderr.isEmpty ? 'no stderr output' : stderr;
        throw CodexExecException(
          'Codex exec exited with code $exitCode: $detail',
        );
      }
    } finally {
      if (!exited) {
        _killProcess(process, force: true);
      }
      await stderrSubscription.cancel();
    }
  }

  Map<String, String> _buildEnvironment({String? baseUrl, String? apiKey}) {
    final env = <String, String>{};
    final envOverride = _envOverride;
    if (envOverride != null) {
      env.addAll(envOverride);
    } else {
      env.addAll(Platform.environment);
    }

    if (!env.containsKey(_internalOriginatorEnv)) {
      env[_internalOriginatorEnv] = _dartSdkOriginator;
    }
    if (baseUrl != null) {
      env['OPENAI_BASE_URL'] = baseUrl;
    }
    if (apiKey != null) {
      env['CODEX_API_KEY'] = apiKey;
    }

    return env;
  }
}

Future<Process> _startProcess(
  String executable,
  List<String> commandArgs,
  Map<String, String> env,
) async {
  try {
    return await Process.start(
      executable,
      commandArgs,
      environment: env,
      runInShell: false,
    );
  } catch (error) {
    throw CodexExecException(
      'Failed to spawn codex executable "$executable". Make sure it exists and is executable.',
      cause: error,
    );
  }
}

void _killProcess(Process process, {bool force = false}) {
  if (Platform.isWindows) {
    process.kill();
    return;
  }

  if (force) {
    process.kill(ProcessSignal.sigkill);
  } else {
    process.kill(ProcessSignal.sigterm);
  }
}

String _resolveCodexPath(String? codexPathOverride) {
  final override = codexPathOverride?.trim();
  if (override != null && override.isNotEmpty) {
    return override;
  }

  final envPath = Platform.environment[_codexExecutableEnv]?.trim();
  if (envPath != null && envPath.isNotEmpty) {
    return envPath;
  }

  final pathCandidate = _findCodexInPath();
  if (pathCandidate != null) {
    return pathCandidate;
  }

  throw CodexExecutableNotFoundException(
    'Unable to locate `codex` executable. Set `codexPathOverride`, set '
    '`CODEX_EXECUTABLE`, or add `codex` to PATH.',
  );
}

String? _findCodexInPath() {
  final pathEnv = _readPathEnvironment();
  if (pathEnv == null || pathEnv.isEmpty) {
    return null;
  }

  final separator = Platform.isWindows ? ';' : ':';
  final names = Platform.isWindows
      ? const <String>['codex.exe', 'codex.cmd', 'codex.bat', 'codex']
      : const <String>['codex'];

  for (final rawDir in pathEnv.split(separator)) {
    final dir = rawDir.trim();
    if (dir.isEmpty) {
      continue;
    }

    for (final name in names) {
      final candidate = p.join(dir, name);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
  }

  return null;
}

String? _readPathEnvironment() {
  if (!Platform.isWindows) {
    return Platform.environment['PATH'];
  }

  for (final entry in Platform.environment.entries) {
    if (entry.key.toLowerCase() == 'path') {
      return entry.value;
    }
  }
  return null;
}
