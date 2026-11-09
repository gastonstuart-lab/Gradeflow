import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/os/os_controller.dart';

void main() {
  group('GradeFlowOSController', () {
    test('surface changes close overlays and keep active class', () {
      final controller = GradeFlowOSController();

      controller.openLauncher();
      controller.setSurface(OSSurface.classWorkspace, classId: 'class-1');

      expect(controller.activeSurface, OSSurface.classWorkspace);
      expect(controller.activeClassId, 'class-1');
      expect(controller.launcherOpen, isFalse);
      expect(controller.shadeOpen, isFalse);
      expect(controller.assistantOpen, isFalse);
    });

    test('entering Teach Mode preserves activeClassId', () {
      final controller = GradeFlowOSController();

      controller.setSurface(OSSurface.classWorkspace, classId: 'class-1');
      controller.setSurface(OSSurface.teach);

      expect(controller.activeSurface, OSSurface.teach);
      expect(controller.activeClassId, 'class-1');
    });

    test('planner sits between home and teaching surfaces', () {
      final controller = GradeFlowOSController();

      expect(controller.swipeSurfaceSequence, [
        OSSurface.home,
        OSSurface.planner,
        OSSurface.teach,
      ]);
      expect(controller.adjacentSurface(1), OSSurface.planner);

      controller.setSurface(OSSurface.classWorkspace, classId: 'class-1');

      expect(controller.swipeSurfaceSequence, [
        OSSurface.home,
        OSSurface.planner,
        OSSurface.classWorkspace,
        OSSurface.teach,
      ]);
    });

    test('returning Home retains last class context but not active route', () {
      final controller = GradeFlowOSController();
      controller.setSurface(OSSurface.classWorkspace, classId: 'science-a');
      expect(controller.lastSelectedClassId, 'science-a');
      controller.setSurface(OSSurface.home);
      expect(controller.activeSurface, OSSurface.home);
      expect(controller.activeClassId, isNull);
      expect(controller.lastSelectedClassId, 'science-a');

      controller.setSurface(OSSurface.classWorkspace, classId: 'english-b');
      controller.setSurface(OSSurface.home);
      expect(controller.lastSelectedClassId, 'english-b');
    });

    test('Home dropdown changes context without rerouting or saving data', () {
      final controller = GradeFlowOSController();
      controller.rememberSelectedClass('class-one');
      expect(controller.activeSurface, OSSurface.home);
      expect(controller.activeClassId, isNull);
      expect(controller.lastSelectedClassId, 'class-one');

      controller.rememberSelectedClass('class-two');
      expect(controller.lastSelectedClassId, 'class-two');
      controller.setSurface(OSSurface.planner);
      controller.setSurface(OSSurface.home);
      expect(controller.lastSelectedClassId, 'class-two');
    });

    test('empty route class IDs never replace remembered class', () {
      final controller = GradeFlowOSController();
      controller.rememberSelectedClass('class-one');
      controller.setSurface(OSSurface.classWorkspace, classId: '');
      expect(controller.lastSelectedClassId, 'class-one');
    });

    test('changing signed-in teacher clears class navigation history', () {
      final controller = GradeFlowOSController();
      controller.bindSelectionToUser('teacher-a');
      controller.setSurface(
        OSSurface.classWorkspace, classId: 'teacher-a-class');
      controller.setSurface(OSSurface.home);
      expect(controller.lastSelectedClassId, 'teacher-a-class');

      controller.bindSelectionToUser('teacher-b');
      expect(controller.lastSelectedClassId, isNull);
      expect(controller.activeClassId, isNull);
      controller.rememberSelectedClass('teacher-b-class');
      expect(controller.lastSelectedClassId, 'teacher-b-class');

      controller.bindSelectionToUser(null);
      expect(controller.lastSelectedClassId, isNull);
    });

    test('same teacher retains class when route changes', () {
      final controller = GradeFlowOSController();
      controller.bindSelectionToUser('teacher-a');
      controller.setSurface(
        OSSurface.classWorkspace, classId: 'science');
      controller.setSurface(OSSurface.home);
      controller.bindSelectionToUser('teacher-a');
      expect(controller.lastSelectedClassId, 'science');
    });

    test('opening overlays is mutually exclusive', () {
      final controller = GradeFlowOSController();

      controller.openLauncher();
      expect(controller.launcherOpen, isTrue);

      controller.openShade();
      expect(controller.launcherOpen, isFalse);
      expect(controller.shadeOpen, isTrue);

      controller.openAssistant();
      expect(controller.shadeOpen, isFalse);
      expect(controller.assistantOpen, isTrue);
    });

    test('idle can be triggered and dismissed explicitly', () {
      final controller = GradeFlowOSController();

      controller.triggerIdle();
      expect(controller.idleActive, isTrue);

      controller.dismissIdle();
      expect(controller.idleActive, isFalse);
    });
  });
}
