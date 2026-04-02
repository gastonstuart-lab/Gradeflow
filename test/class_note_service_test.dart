import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class_note_item.dart';
import 'package:gradeflow/services/class_note_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('class note service persists notes per class and user', () async {
    final service = ClassNoteService();
    final item = ClassNoteItem(
      id: 'note-1',
      text: 'Bring costume examples for next class.',
      createdAt: DateTime(2026, 4, 1, 9, 30),
      remindAt: DateTime(2026, 4, 8),
    );

    await service.save(
      classId: 'class-pa',
      userId: 'teacher-1',
      items: [item],
    );

    final loaded = await service.load(
      classId: 'class-pa',
      userId: 'teacher-1',
    );
    final otherClass = await service.load(
      classId: 'class-math',
      userId: 'teacher-1',
    );

    expect(loaded, hasLength(1));
    expect(loaded.single.text, contains('costume examples'));
    expect(loaded.single.remindAt, DateTime(2026, 4, 8));
    expect(otherClass, isEmpty);
  });
}
