import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/instructos_assistant_service.dart';

void main() {
  test('ask sends only message conversation and context mode', () async {
    Map<String, dynamic>? capturedPayload;
    final service = InstructOSAssistantService(
      callableInvoker: (payload) async {
        capturedPayload = payload;
        return {'reply': 'Backend placeholder reply'};
      },
    );

    final reply = await service.ask(
      message: '  Plan tomorrow  ',
      conversation: const [
        InstructOSAssistantMessage(role: 'user', content: 'Hello'),
        InstructOSAssistantMessage(role: 'assistant', content: 'Hi'),
        InstructOSAssistantMessage(role: 'unknown', content: 'Normalize me'),
        InstructOSAssistantMessage(role: 'user', content: '   '),
      ],
      contextMode: ' general ',
    );

    expect(reply, 'Backend placeholder reply');
    expect(capturedPayload, {
      'message': 'Plan tomorrow',
      'conversation': [
        {'role': 'user', 'content': 'Hello'},
        {'role': 'assistant', 'content': 'Hi'},
        {'role': 'user', 'content': 'Normalize me'},
      ],
      'contextMode': 'general',
    });
  });

  test('ask returns fallback reply when callable fails', () async {
    final service = InstructOSAssistantService(
      callableInvoker: (_) async => throw StateError('offline'),
    );

    final reply = await service.ask(message: 'Create a quick quiz');

    expect(reply, InstructOSAssistantService.fallbackReply);
  });
}
