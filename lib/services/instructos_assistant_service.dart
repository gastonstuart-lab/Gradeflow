import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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
  static const String _functionRegion = 'us-central1';
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
      debugPrint(
        'Ask InstructOS fallback: empty message payload before callable invocation.',
      );
      return fallbackReply;
    }

    final payload = <String, Object?>{
      'message': trimmedMessage,
      'conversation': _conversationPayload(conversation),
      'contextMode':
          contextMode.trim().isEmpty ? 'general' : contextMode.trim(),
    };

    try {
      debugPrint(
        'Ask InstructOS invoking callable=$_functionName region=$_functionRegion '
        'firebaseAvailable=${FirebaseService.isAvailable} '
        'messageLength=${trimmedMessage.length} '
        'conversationItems=${(payload['conversation'] as List).length} '
        'contextMode=${payload['contextMode']}',
      );
      final data = await _call(payload).timeout(const Duration(seconds: 20));
      debugPrint(
        'Ask InstructOS callable response received '
        'dataType=${data.runtimeType} keys=${data.keys.toList()}',
      );
      final reply = data['reply'];
      if (reply is String && reply.trim().isNotEmpty) {
        debugPrint(
          'Ask InstructOS using callable reply length=${reply.trim().length}',
        );
        return reply.trim();
      }
      debugPrint(
        'Ask InstructOS fallback: callable response missing non-empty string reply. '
        'replyType=${reply.runtimeType}',
      );
      return fallbackReply;
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'Ask InstructOS callable failed: code=${error.code} '
        'message=${error.message ?? 'none'} details=${error.details}',
      );
      debugPrint(
          'Ask InstructOS fallback: FirebaseFunctionsException path used.');
      return _messageForFunctionsError(error);
    } catch (error) {
      debugPrint('Ask InstructOS unavailable: ${error.runtimeType}');
      debugPrint('Ask InstructOS fallback: unexpected exception path used.');
      return fallbackReply;
    }
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> payload) async {
    final invoker = _callableInvoker;
    if (invoker != null) {
      debugPrint('Ask InstructOS using injected callable invoker.');
      return invoker(Map<String, dynamic>.from(payload));
    }

    if (!FirebaseService.isAvailable) {
      debugPrint(
        'Ask InstructOS fallback: Firebase unavailable, returning local fallback reply.',
      );
      return const <String, dynamic>{'reply': fallbackReply};
    }

    final currentFirebaseUser = fb.FirebaseAuth.instance.currentUser;
    if (currentFirebaseUser == null) {
      debugPrint(
        'Ask InstructOS skipped callable: Firebase Auth has no signed-in user.',
      );
      return const <String, dynamic>{
        'reply': 'Please sign in again to use Ask InstructOS.',
      };
    }

    debugPrint(
      'Ask InstructOS Firebase Auth user present uidLength=${currentFirebaseUser.uid.length}',
    );
    debugPrint(
      'Ask InstructOS creating Firebase callable name=$_functionName region=$_functionRegion',
    );
    final callable =
        (_functions ?? FirebaseFunctions.instanceFor(region: _functionRegion))
            .httpsCallable(
      _functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
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

  String _messageForFunctionsError(FirebaseFunctionsException error) {
    final serverMessage = error.message?.trim();
    return switch (error.code) {
      'unauthenticated' => serverMessage?.isNotEmpty == true
          ? serverMessage!
          : 'Please sign in again to use Ask InstructOS.',
      'invalid-argument' => serverMessage?.isNotEmpty == true
          ? serverMessage!
          : 'Ask InstructOS could not understand that request.',
      'failed-precondition' =>
        'Ask InstructOS is not fully configured on the server yet.',
      'unavailable' => serverMessage?.isNotEmpty == true
          ? serverMessage!
          : 'Ask InstructOS cannot reach the AI provider right now. Please try again.',
      'deadline-exceeded' =>
        'Ask InstructOS took too long to reply. Please try again.',
      _ => serverMessage?.isNotEmpty == true
          ? serverMessage!
          : 'Ask InstructOS hit a server error. Please try again shortly.',
    };
  }
}
