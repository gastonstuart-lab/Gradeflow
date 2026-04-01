import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/seating_designer_view.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/repositories/repository_factory.dart';
import 'package:gradeflow/services/seating_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RepositoryFactory.useLocal();
  });

  testWidgets(
      'presentation-style seating designer stays interactive without roster panel',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = SeatingService();
    await service.loadLayouts('class-a');
    await service.addTable(
      'class-a',
      SeatingTableType.singleDesk,
      seatCount: 1,
    );
    await service.renameLayout(
      'class-a',
      service.activeLayout('class-a')!.layoutId,
      'Room',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 900,
              child: SeatingDesignerView(
                classId: 'class-a',
                students: [],
                autoLoad: false,
                presentationMode: true,
                showStudentPanel: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Students'), findsNothing);

    await tester.tap(find.byIcon(Icons.event_seat_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Empty seat'), findsOneWidget);
    expect(find.text('Add note or reminder'), findsOneWidget);
  });
}
