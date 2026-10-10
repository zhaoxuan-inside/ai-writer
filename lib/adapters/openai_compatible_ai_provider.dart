import 'package:dio/dio.dart';

import '../core/ai/ai_errors.dart';
import '../core/ai/ai_models.dart';
import '../core/ai/ai_provider.dart';

/// OpenAI Chat Completions–compatible adapter (`/v1/chat/completions`).
class OpenAiCompatibleAiProvider implements AiProvider {
  OpenAiCompatibleAiProvider({
    required AiProviderConfig config,
    Dio? dio,
  })  : _config = config,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final AiProviderConfig _config;
  final Dio _dio;

  @override
  Future<AiCompleteResult> complete(AiCompleteRequest request) async {
    if (!_config.isConfigured) {
      throw const NotConfiguredError();
    }

    final model = request.model ?? _config.model;
    final base = _config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final url = base.endsWith('/chat/completions')
        ? base
        : '$base/chat/completions';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': _systemPrompt(request.mode),
            },
            {
              'role': 'user',
              'content': _userPrompt(request),
            },
          ],
          'temperature': 0.7,
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${_config.apiKey}'},
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const ProviderError('Empty response from AI provider');
      }
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const ProviderError('No choices in AI response');
      }
      final message = choices.first['message'];
      final content = message is Map ? message['content'] : null;
      if (content is! String || content.trim().isEmpty) {
        throw const ProviderError('Empty suggestion from AI provider');
      }
      return AiCompleteResult(
        suggestionMarkdown: content.trim(),
        raw: content,
      );
    } on AiProviderException {
      rethrow;
    } on DioException catch (e) {
      throw ProviderError(_dioMessage(e));
    } catch (e) {
      throw ProviderError('$e');
    }
  }

  String _systemPrompt(AiAssistMode mode) {
    final task = switch (mode) {
      AiAssistMode.continueWriting =>
        'Continue the writing naturally in Markdown. Output only the continuation.',
      AiAssistMode.rewrite =>
        'Rewrite the selection to improve clarity. Output only the rewritten Markdown.',
      AiAssistMode.expand =>
        'Expand the selection with more detail. Output only the expanded Markdown.',
      AiAssistMode.polish =>
        'Polish grammar and style while keeping meaning. Output only the polished Markdown.',
    };
    return 'You are a writing assistant inside a local Markdown editor. $task Do not wrap the answer in code fences unless the user text is code.';
  }

  String _userPrompt(AiCompleteRequest request) {
    final buf = StringBuffer();
    if (request.documentTitle != null && request.documentTitle!.isNotEmpty) {
      buf.writeln('Document title: ${request.documentTitle}');
    }
    if (request.selectionMarkdown != null &&
        request.selectionMarkdown!.trim().isNotEmpty) {
      buf.writeln('Selection:');
      buf.writeln(request.selectionMarkdown);
    } else if (request.cursorContext != null &&
        request.cursorContext!.trim().isNotEmpty) {
      buf.writeln('Context before cursor:');
      buf.writeln(request.cursorContext);
    } else {
      buf.writeln('(empty document)');
    }
    return buf.toString();
  }

  String _dioMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) {
      return 'AI provider HTTP $status';
    }
    return e.message ?? 'AI provider network error';
  }
}
