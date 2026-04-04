import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/services/global_system_shell_service.dart';

void main() {
  group('GlobalSystemShellController', () {
    test('tracks active utility and studio return path', () {
      final controller = GlobalSystemShellController();

      controller.updateLocation('/classes');
      expect(controller.activeUtility, GlobalSystemUtility.classes);
      expect(controller.lastNonStudioLocation, '/classes');

      controller.updateLocation('/whiteboard');
      expect(controller.activeUtility, GlobalSystemUtility.studio);
      expect(controller.lastNonStudioLocation, '/classes');

      controller.updateLocation('/communication');
      expect(controller.activeUtility, GlobalSystemUtility.messages);
      expect(controller.lastNonStudioLocation, '/communication');
    });

    test('dismisses and restores notification ids locally', () async {
      final controller = GlobalSystemShellController();
      final items = ['alpha', 'beta', 'gamma'];

      await controller.dismissNotification('beta');

      expect(controller.isNotificationDismissed('beta'), isTrue);
      expect(
        controller.visibleNotifications(items, (item) => item),
        ['alpha', 'gamma'],
      );
      expect(controller.dismissedCountForIds(items), 1);

      await controller.restoreDismissedNotifications(ids: const ['beta']);

      expect(controller.isNotificationDismissed('beta'), isFalse);
      expect(
        controller.visibleNotifications(items, (item) => item),
        items,
      );
      expect(controller.dismissedCountForIds(items), 0);
    });
  });
}
