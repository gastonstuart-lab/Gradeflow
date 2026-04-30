import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/command_surface.dart';
import 'package:gradeflow/theme.dart';

void main() {
  testWidgets('CommandSurfaceCard can host an expanded viewport child', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              height: 280,
              child: DefaultTabController(
                length: 2,
                child: CommandSurfaceCard(
                  surfaceType: SurfaceType.stage,
                  padding: EdgeInsets.zero,
                  expandChild: true,
                  child: TabBarView(
                    children: [
                      Container(color: Colors.red),
                      Container(color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
