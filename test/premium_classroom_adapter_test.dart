import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradeflow/components/seating/seating_canvas.dart';
import 'package:gradeflow/components/classroom/classroom_materials.dart';
import 'package:gradeflow/models/seating_layout.dart';
import 'package:gradeflow/models/student.dart';

void main(){
  testWidgets('premium material adapter preserves seat bounds, IDs and notes', (tester)async{
    final now=DateTime(2026);
    final table=SeatingTable(tableId:'irregular-table',type:SeatingTableType.rectangular,label:'Existing table',x:235,y:153,seatCount:1,width:181,height:93);
    final seat=SeatingSeat(seatId:'existing-seat',tableId:table.tableId,x:32,y:94,studentId:'existing-student',note:'Keep this note',reminder:true,statusColor:SeatStatusColor.none);
    final student=Student(studentId:'existing-student',classId:'class-a',chineseName:'測試',englishFirstName:'Synthetic',englishLastName:'Student',createdAt:now,updatedAt:now);
    String? selected;
    Widget view(bool premium)=>MaterialApp(home:Scaffold(body:Center(child:TableWidget(table:table,seats:[seat],studentsById:{student.studentId:student},designMode:false,interactive:true,presentationMode:false,premiumAppearance:premium,onSeatTap:(id)=>selected=id))));
    final originalSeat=seat.toJson(),originalTable=table.toJson();
    await tester.pumpWidget(view(false));await tester.pumpAndSettle();
    final before=tester.getRect(find.byType(SeatWidget));
    await tester.pumpWidget(view(true));await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SeatWidget)),before);
    expect(find.byWidgetPredicate((w)=>w is CustomPaint&&w.painter is ClassroomOakPainter),findsOneWidget);
    await tester.tap(find.text('Synthetic'));expect(selected,seat.seatId);
    expect(seat.toJson(),originalSeat);expect(table.toJson(),originalTable);
    expect(find.byIcon(Icons.notifications_active_outlined),findsOneWidget);
  });
}
