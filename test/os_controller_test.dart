import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/os/os_controller.dart';

void main() {
  group('GradeFlowOSController', () {
    test('working class survives Planner, Home, other and Teach navigation',
        () {
      final controller = GradeFlowOSController();
      addTearDown(controller.dispose);
      controller.setSurface(OSSurface.classWorkspace, classId: 'class-a');
      for (final surface in [
        OSSurface.planner,
        OSSurface.home,
        OSSurface.other,
        OSSurface.teach,
      ]) {
        controller.setSurface(surface);
        expect(controller.activeSurface, surface);
        expect(controller.activeClassId, 'class-a');
      }
      controller.setSurface(OSSurface.classWorkspace, classId: 'class-b');
      controller.setSurface(OSSurface.home);
      controller.setSurface(OSSurface.teach);
      expect(controller.activeClassId, 'class-b');
    });

    test('explicit selection and release do not navigate', () {
      final controller = GradeFlowOSController();
      addTearDown(controller.dispose);
      controller.setSurface(OSSurface.planner);
      controller.selectWorkingClass('class-b');
      expect(controller.activeSurface, OSSurface.planner);
      expect(controller.activeClassId, 'class-b');
      controller.openAssistant();
      controller.closeAssistant();
      expect(controller.activeClassId, 'class-b');
      controller.clearWorkingClass();
      expect(controller.activeClassId, isNull);
      expect(controller.activeSurface, OSSurface.planner);
      controller.setSurface(OSSurface.teach);
      expect(controller.activeClassId, isNull);
      expect(() => controller.selectWorkingClass(' '), throwsArgumentError);
    });

    test('identity restoration and same-user updates preserve working context',
        () {
      final controller = GradeFlowOSController();
      addTearDown(controller.dispose);
      controller.syncTeacherIdentity('teacher-a', isResolved: true);
      controller.selectWorkingClass('class-a');
      controller.openShade();
      controller.syncTeacherIdentity(null, isResolved: false);
      controller.syncTeacherIdentity('teacher-a', isResolved: true);
      expect(controller.activeClassId, 'class-a');
      expect(controller.shadeOpen, isTrue);
    });

    test('switching teacher or logout clears transient working context', () {
      final controller = GradeFlowOSController();
      addTearDown(controller.dispose);
      controller.syncTeacherIdentity('teacher-a', isResolved: true);
      controller.selectWorkingClass('class-a');
      controller.setHomePageIndex(2);
      controller.openLauncher();
      controller.triggerIdle();
      final previousStorage = controller.pageStorageBucket;
      controller.syncTeacherIdentity('teacher-b', isResolved: true);
      expect(controller.activeClassId, isNull);
      expect(controller.homePageIndex, 0);
      expect(controller.launcherOpen, isFalse);
      expect(controller.idleActive, isFalse);
      expect(controller.pageStorageBucket, isNot(same(previousStorage)));
      controller.selectWorkingClass('class-b');
      controller.openAssistant();
      controller.syncTeacherIdentity(null, isResolved: true);
      expect(controller.activeClassId, isNull);
      expect(controller.assistantOpen, isFalse);
    });

    test('first resolved identity releases unowned class context', () {
      final controller = GradeFlowOSController();
      addTearDown(controller.dispose);
      controller.selectWorkingClass('unowned-class');
      controller.syncTeacherIdentity('teacher-a', isResolved: true);
      expect(controller.activeClassId, isNull);
    });

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
