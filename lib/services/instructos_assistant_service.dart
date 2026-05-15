import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:gradeflow/services/firebase_service.dart';

typedef InstructOSCallableInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);

class InstructOSAssistantMessage {
  const InstructOSAssistantMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;

  static const Set<String> allowedRoles = {'user', 'assistant', 'system'};

  Map<String, String> toJson() {
    final normalizedRole = allowedRoles.contains(role) ? role : 'user';
    return {
      'role': normalizedRole,
      'content': content.trim(),
    };
  }
}

class InstructOSAssistantService {
  InstructOSAssistantService({
    FirebaseFunctions? functions,
    InstructOSCallableInvoker? callableInvoker,
  })  : _functions = functions,
        _callableInvoker = callableInvoker;

  static const String fallbackReply =
      'I can help prepare that. In the next version, I\'ll connect to your class data and planning tools.';

  static const String _functionName = 'askInstructOS';
  static const int _maxConversationItems = 20;

  final FirebaseFunctions? _functions;
  final InstructOSCallableInvoker? _callableInvoker;

  Future<String> ask({
    required String message,
    List<InstructOSAssistantMessage> conversation = const [],
    String contextMode = 'general',
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      return fallbackReply;
    }

    final payload = <String, Object?>{
      'message': trimmedMessage,
      'conversation': _conversationPayload(conversation),
      'contextMode':
          contextMode.trim().isEmpty ? 'general' : contextMode.trim(),
    };

    try {
      final data = await _call(payload).timeout(const Duration(seconds: 20));
      final reply = data['reply'];
      if (reply is String && reply.trim().isNotEmpty) {
        return reply.trim();
      }
      return fallbackReply;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Ask InstructOS callable failed: ${error.code}');
      return fallbackReply;
    } catch (error) {
      debugPrint('Ask InstructOS unavailable: ${error.runtimeType}');
      return fallbackReply;
    }
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> payload) async {
    final invoker = _callableInvoker;
    if (invoker != null) {
      return invoker(Map<String, dynamic>.from(payload));
    }

    if (!FirebaseService.isAvailable) {
      return const <String, dynamic>{'reply': fallbackReply};
    }

    final callable =
        (_functions ?? FirebaseFunctions.instance).httpsCallable(_functionName);
    final result = await callable.call<Map<String, dynamic>>(payload);
    return result.data;
  }

  List<Map<String, String>> _conversationPayload(
    List<InstructOSAssistantMessage> conversation,
  ) {
    return conversation
        .where((message) => message.content.trim().isNotEmpty)
        .take(_maxConversationItems)
        .map((message) => message.toJson())
        .toList(growable: false);
  }
}
