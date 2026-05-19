import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/models/class_schedule_item.dart';
import 'package:gradeflow/services/class_schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('class schedule service scopes schedules per user', () async {
    final service = ClassScheduleService();

    await service.save(
      'shared-class-id',
      const [
        ClassScheduleItem(title: 'Teacher one schedule'),
      ],
      userId: 'teacher-1',
    );
    await service.save(
      'shared-class-id',
      const [
        ClassScheduleItem(title: 'Teacher two schedule'),
      ],
      userId: 'teacher-2',
    );

    final teacherOne = await service.load(
      'shared-class-id',
      userId: 'teacher-1',
    );
    final teacherTwo = await service.load(
      'shared-class-id',
      userId: 'teacher-2',
    );

    expect(teacherOne.single.title, 'Teacher one schedule');
    expect(teacherTwo.single.title, 'Teacher two schedule');
  });

  test('class schedule service migrates legacy class schedule keys', () async {
    final service = ClassScheduleService();

    await service.save(
      'legacy-class-id',
      const [
        ClassScheduleItem(title: 'Legacy schedule'),
      ],
    );

    final scoped = await service.load(
      'legacy-class-id',
      userId: 'teacher-restored',
    );
    final reloaded = await service.load(
      'legacy-class-id',
      userId: 'teacher-restored',
    );

    expect(scoped.single.title, 'Legacy schedule');
    expect(reloaded.single.title, 'Legacy schedule');
  });
}
