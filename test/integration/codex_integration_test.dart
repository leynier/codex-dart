import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex/codex.dart';
import 'package:test/test.dart';

void main() {
  final executable = Platform.environment['CODEX_EXECUTABLE'];
  final shouldRun = executable != null && executable.isNotEmpty;

  test(
    'runs against real codex binary with local responses proxy',
    () async {
      final proxy = await _startProxyServer();
      addTearDown(proxy.close);

      final client = Codex(
        codexPathOverride: executable,
        baseUrl: proxy.url,
        apiKey: 'test',
      );

      final thread = client.startThread(
        const ThreadOptions(skipGitRepoCheck: true),
      );
      final result = await thread.run('Hello, world!');

      expect(result.items, isNotEmpty);
      expect(result.finalResponse, 'Hi!');
      expect(thread.id, isNotNull);
    },
    skip: shouldRun ? false : 'Set CODEX_EXECUTABLE to run integration tests',
  );
}

final class _Proxy {
  _Proxy({required this.url, required this.close});

  final String url;
  final Future<void> Function() close;
}

Future<_Proxy> _startProxyServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  unawaited(() async {
    await for (final request in server) {
      if (request.method == 'POST' && request.uri.path == '/responses') {
        await request.drain();
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );

        request.response.write(
          _formatSse(<String, Object?>{
            'type': 'response.created',
            'response': <String, Object?>{'id': 'response_1'},
          }),
        );
        request.response.write(
          _formatSse(<String, Object?>{
            'type': 'response.output_item.done',
            'item': <String, Object?>{
              'type': 'message',
              'role': 'assistant',
              'id': 'item_1',
              'content': <Object?>[
                <String, Object?>{'type': 'output_text', 'text': 'Hi!'},
              ],
            },
          }),
        );
        request.response.write(
          _formatSse(<String, Object?>{
            'type': 'response.completed',
            'response': <String, Object?>{
              'id': 'response_1',
              'usage': <String, Object?>{
                'input_tokens': 42,
                'input_tokens_details': <String, Object?>{'cached_tokens': 12},
                'output_tokens': 5,
                'output_tokens_details': null,
                'total_tokens': 47,
              },
            },
          }),
        );
        await request.response.close();
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    }
  }());

  return _Proxy(
    url: 'http://${server.address.host}:${server.port}',
    close: () => server.close(force: true),
  );
}

String _formatSse(Map<String, Object?> event) {
  return 'event: ${event['type']}\n'
      'data: ${jsonEncode(event)}\n\n';
}
