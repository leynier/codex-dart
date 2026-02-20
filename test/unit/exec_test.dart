import 'dart:async';

import 'package:codex/src/exceptions.dart';
import 'package:codex/src/exec.dart';
import 'package:codex/src/options.dart';
import 'package:test/test.dart';

import '../support/fake_codex.dart';

void main() {
  group('CodexExec', () {
    test('builds expected args and env and forwards stdin', () async {
      final fake = await createFakeCodex();
      addTearDown(fake.dispose);

      final env = <String, String>{...fake.environment, 'CUSTOM_ENV': 'custom'};

      final exec = CodexExec(
        codexPathOverride: fake.executablePath,
        env: env,
        configOverrides: <String, Object?>{
          'approval_policy': 'never',
          'sandbox_workspace_write': <String, Object?>{'network_access': true},
        },
      );

      final args = CodexExecArgs(
        input: 'hello world',
        baseUrl: 'http://127.0.0.1:1234',
        apiKey: 'test-key',
        threadId: 'thread_123',
        images: const <String>['/tmp/a.png', '/tmp/b.jpg'],
        model: 'gpt-test-1',
        sandboxMode: SandboxMode.workspaceWrite,
        workingDirectory: '/tmp/work',
        additionalDirectories: const <String>['/tmp/one', '/tmp/two'],
        skipGitRepoCheck: true,
        outputSchemaFile: '/tmp/schema.json',
        modelReasoningEffort: ModelReasoningEffort.high,
        networkAccessEnabled: true,
        webSearchMode: WebSearchMode.cached,
        approvalPolicy: ApprovalMode.onRequest,
      );

      final lines = await exec.run(args).toList();
      expect(lines, isNotEmpty);

      final forwardedArgs = await fake.readArgs();
      expect(forwardedArgs.take(2), <String>['exec', '--experimental-json']);
      expect(_containsPair(forwardedArgs, '--model', 'gpt-test-1'), isTrue);
      expect(
        _containsPair(forwardedArgs, '--sandbox', 'workspace-write'),
        isTrue,
      );
      expect(_containsPair(forwardedArgs, '--cd', '/tmp/work'), isTrue);
      expect(
        _containsPair(forwardedArgs, '--output-schema', '/tmp/schema.json'),
        isTrue,
      );
      expect(
        _containsPair(
          forwardedArgs,
          '--config',
          'model_reasoning_effort="high"',
        ),
        isTrue,
      );
      expect(
        _containsPair(
          forwardedArgs,
          '--config',
          'sandbox_workspace_write.network_access=true',
        ),
        isTrue,
      );
      expect(
        _containsPair(forwardedArgs, '--config', 'web_search="cached"'),
        isTrue,
      );
      expect(
        _containsPair(
          forwardedArgs,
          '--config',
          'approval_policy="on-request"',
        ),
        isTrue,
      );
      expect(_containsPair(forwardedArgs, '--add-dir', '/tmp/one'), isTrue);
      expect(_containsPair(forwardedArgs, '--add-dir', '/tmp/two'), isTrue);

      final resumeIndex = forwardedArgs.indexOf('resume');
      final imageIndex = forwardedArgs.indexOf('--image');
      expect(resumeIndex, greaterThan(-1));
      expect(imageIndex, greaterThan(-1));
      expect(resumeIndex, lessThan(imageIndex));

      final selectedEnv = await fake.readSelectedEnv();
      expect(selectedEnv['CUSTOM_ENV'], 'custom');
      expect(selectedEnv['OPENAI_BASE_URL'], 'http://127.0.0.1:1234');
      expect(selectedEnv['CODEX_API_KEY'], 'test-key');
      expect(selectedEnv['CODEX_INTERNAL_ORIGINATOR_OVERRIDE'], isNotEmpty);
      expect(selectedEnv.containsKey('LEAK_TEST'), isFalse);

      final stdin = await fake.readStdin();
      expect(stdin, 'hello world');
    });

    test('throws on non-zero exit code', () async {
      final fake = await createFakeCodex(mode: 'exit_error');
      addTearDown(fake.dispose);

      final exec = CodexExec(
        codexPathOverride: fake.executablePath,
        env: fake.environment,
      );

      expect(
        () async => exec.run(const CodexExecArgs(input: 'hello')).toList(),
        throwsA(isA<CodexExecException>()),
      );
    });

    test('throws cancel error when canceled', () async {
      final fake = await createFakeCodex(mode: 'hang');
      addTearDown(fake.dispose);

      final exec = CodexExec(
        codexPathOverride: fake.executablePath,
        env: fake.environment,
      );

      final cancel = Completer<void>();
      final future = exec
          .run(CodexExecArgs(input: 'hello', cancelSignal: cancel.future))
          .drain<void>();

      cancel.complete();

      await expectLater(future, throwsA(isA<CodexCanceledException>()));
    });
  });
}

bool _containsPair(List<String> args, String key, String value) {
  for (var i = 0; i < args.length - 1; i += 1) {
    if (args[i] == key && args[i + 1] == value) {
      return true;
    }
  }
  return false;
}
