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
