import 'dart:convert';

import 'package:ai_writer/adapters/fake_ai_provider.dart';
import 'package:ai_writer/adapters/openai_compatible_ai_provider.dart';
import 'package:ai_writer/core/ai/ai_errors.dart';
import 'package:ai_writer/core/ai/ai_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAiProvider', () {
    test('rewrite prefixes selection', () async {
      final provider = FakeAiProvider();
      final result = await provider.complete(
        const AiCompleteRequest(
          mode: AiAssistMode.rewrite,
          selectionMarkdown: 'hello',
        ),
      );
      expect(result.suggestionMarkdown, 'Rewritten: hello');
    });

    test('continue uses cursor context when no selection', () async {
      final provider = FakeAiProvider();
      final result = await provider.complete(
        const AiCompleteRequest(
          mode: AiAssistMode.continueWriting,
          cursorContext: 'Once upon',
        ),
      );
      expect(result.suggestionMarkdown, contains('Once upon'));
      expect(result.suggestionMarkdown, contains('continued'));
    });

    test('throws NotConfigured when required', () async {
      final provider = FakeAiProvider(
        requireConfigured: true,
        configured: false,
      );
      expect(
        () => provider.complete(
          const AiCompleteRequest(mode: AiAssistMode.polish),
        ),
        throwsA(isA<NotConfiguredError>()),
      );
    });
  });

  group('OpenAiCompatibleAiProvider', () {
    test('throws NotConfigured without api key', () async {
      final provider = OpenAiCompatibleAiProvider(
        config: const AiProviderConfig(baseUrl: 'https://api.example.com/v1', apiKey: ''),
      );
      expect(
        () => provider.complete(
          const AiCompleteRequest(mode: AiAssistMode.expand),
        ),
        throwsA(isA<NotConfiguredError>()),
      );
    });

    test('parses chat completion content', () async {
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) {
        expect(options.path, contains('chat/completions'));
        expect(options.headers?['Authorization'], 'Bearer test-key');
        return {
          'choices': [
            {
              'message': {'role': 'assistant', 'content': 'Polished text'},
            },
          ],
        };
      });

      final provider = OpenAiCompatibleAiProvider(
        config: const AiProviderConfig(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'test-key',
          model: 'gpt-test',
        ),
        dio: dio,
      );

      final result = await provider.complete(
        const AiCompleteRequest(
          mode: AiAssistMode.polish,
          selectionMarkdown: 'raw',
        ),
      );
      expect(result.suggestionMarkdown, 'Polished text');
    });

    test('maps HTTP errors to ProviderError', () async {
      final dio = Dio();
      dio.httpClientAdapter = _ErrorAdapter(401);
      final provider = OpenAiCompatibleAiProvider(
        config: const AiProviderConfig(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'bad',
        ),
        dio: dio,
      );
      expect(
        () => provider.complete(
          const AiCompleteRequest(mode: AiAssistMode.rewrite),
        ),
        throwsA(isA<ProviderError>()),
      );
    });
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this._handler);

  final Map<String, dynamic> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = jsonEncode(_handler(options));
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _ErrorAdapter implements HttpClientAdapter {
  _ErrorAdapter(this.statusCode);

  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"error":"nope"}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
