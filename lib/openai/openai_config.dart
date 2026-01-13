import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenAIConfig {
  static const String apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
  static const String endpoint =
      String.fromEnvironment('OPENAI_PROXY_ENDPOINT', defaultValue: '');

  static bool get isConfigured =>
      apiKey.trim().isNotEmpty && endpoint.trim().isNotEmpty;

  static Uri chatCompletionsUri() {
    final raw = endpoint.trim();
    if (raw.isEmpty) {
      throw StateError(
          'OpenAI is not configured. Provide --dart-define=OPENAI_PROXY_API_KEY and --dart-define=OPENAI_PROXY_ENDPOINT');
    }

    final base = Uri.parse(raw);
    // Allow either:
    // - https://.../v1/chat/completions
    // - https://.../v1
    // - https://...
    if (base.path.endsWith('/chat/completions')) return base;

    final path = base.path.endsWith('/v1')
        ? '${base.path}/chat/completions'
        : (base.path.isEmpty || base.path == '/')
            ? '/v1/chat/completions'
            : '${base.path}/v1/chat/completions';

    return base.replace(path: path);
  }
}

class OpenAIClient {
  const OpenAIClient({http.Client? httpClient}) : _http = httpClient;

  final http.Client? _http;

  Future<Map<String, dynamic>> chatJson({
    required String model,
    required List<Map<String, Object?>> messages,
    Duration timeout = const Duration(seconds: 40),
  }) async {
    if (!OpenAIConfig.isConfigured) {
      throw StateError(
          'OpenAI is not configured. Provide OPENAI_PROXY_API_KEY and OPENAI_PROXY_ENDPOINT.');
    }

    final client = _http ?? http.Client();
    try {
      final uri = OpenAIConfig.chatCompletionsUri();
      final body = <String, Object?>{
        'model': model,
        'messages': messages,
        // Prefer strict JSON output when supported.
        'response_format': const {'type': 'json_object'},
      };

      final res = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError(
            'OpenAI request failed (${res.statusCode}): ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        throw StateError('OpenAI response was not a JSON object');
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw StateError('OpenAI response missing choices');
      }

      final first = choices.first;
      if (first is! Map) throw StateError('OpenAI choice was not an object');

      final message = first['message'];
      if (message is! Map) throw StateError('OpenAI message was not an object');

      final content = message['content']?.toString() ?? '';
      if (content.trim().isEmpty) {
        throw StateError('OpenAI returned empty content');
      }

      final obj = jsonDecode(content);
      if (obj is! Map<String, dynamic>) {
        throw StateError('OpenAI content was not a JSON object');
      }

      return obj;
    } catch (e) {
      debugPrint('OpenAIClient.chatJson failed: $e');
      rethrow;
    } finally {
      if (_http == null) {
        client.close();
      }
    }
  }
}
