import 'dart:io';

import 'package:codex/codex.dart';
import 'package:test/test.dart';

import '../support/fake_codex.dart';

void main() {
  group('Thread', () {
    test(
      'run returns final response, completed items, usage, and thread id',
      () async {
        final fake = await createFakeCodex(
          stdoutLines: <String>[
            '{"type":"thread.started","thread_id":"thread_123"}',
            '{"type":"turn.started"}',
            '{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"Hi!"}}',
            '{"type":"turn.completed","usage":{"input_tokens":42,"cached_input_tokens":12,"output_tokens":5}}',
          ],
        );
        addTearDown(fake.dispose);

        final codex = Codex(
          codexPathOverride: fake.executablePath,
          env: fake.environment,
        );
        final thread = codex.startThread();

        final result = await thread.run('Hello world');

        expect(thread.id, 'thread_123');
        expect(result.finalResponse, 'Hi!');
        expect(result.items, hasLength(1));
        expect(result.items.first, isA<AgentMessageItem>());
        expect(result.usage?.inputTokens, 42);
        expect(result.usage?.cachedInputTokens, 12);
        expect(result.usage?.outputTokens, 5);
      },
    );

    test('run throws on turn failure', () async {
      final fake = await createFakeCodex(
        stdoutLines: <String>[
          '{"type":"thread.started","thread_id":"thread_123"}',
          '{"type":"turn.started"}',
          '{"type":"turn.failed","error":{"message":"rate limit exceeded"}}',
        ],
      );
      addTearDown(fake.dispose);

      final codex = Codex(
        codexPathOverride: fake.executablePath,
        env: fake.environment,
      );
      final thread = codex.startThread();

      await expectLater(
        () => thread.run('fail'),
        throwsA(isA<ThreadRunException>()),
      );
    });

    test('runStreamed returns typed events', () async {
      final fake = await createFakeCodex();
      addTearDown(fake.dispose);

      final codex = Codex(
        codexPathOverride: fake.executablePath,
        env: fake.environment,
      );
      final thread = codex.startThread();
      final streamed = await thread.runStreamed('Hello');

      final events = await streamed.events.toList();
      expect(events, hasLength(4));
      expect(events.first, isA<ThreadStartedEvent>());
      expect(events[1], isA<TurnStartedEvent>());
      expect(events[2], isA<ItemCompletedEvent>());
      expect(events[3], isA<TurnCompletedEvent>());
    });

    test('throws parse exception on invalid JSON event line', () async {
      final fake = await createFakeCodex(mode: 'invalid_json');
      addTearDown(fake.dispose);

      final codex = Codex(
        codexPathOverride: fake.executablePath,
        env: fake.environment,
      );
      final thread = codex.startThread();

      await expectLater(
        () => thread.run('Hello'),
        throwsA(isA<CodexParseException>()),
      );
    });

    test('writes output schema file and cleans it up', () async {
      final fake = await createFakeCodex();
      addTearDown(fake.dispose);

      final codex = Codex(
        codexPathOverride: fake.executablePath,
        env: fake.environment,
      );
      final thread = codex.startThread();

      await thread.run(
        'structured output',
        const TurnOptions(
          outputSchema: <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'answer': <String, Object?>{'type': 'string'},
            },
          },
        ),
      );

      final args = await fake.readArgs();
      final schemaFlagIndex = args.indexOf('--output-schema');
      expect(schemaFlagIndex, greaterThan(-1));

      final schemaPath = args[schemaFlagIndex + 1];
      expect(schemaPath, isNotEmpty);
      expect(await File(schemaPath).exists(), isFalse);
    });
  });
}
