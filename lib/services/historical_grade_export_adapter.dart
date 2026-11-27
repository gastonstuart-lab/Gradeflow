import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'grading_period_calculation.dart';
import '../models/grading_period.dart';
import 'calculation_service.dart';
import 'export_service.dart';

/// Computes from a self-contained snapshot only. Never reads live services.
class HistoricalGradeExportAdapter {
  final CalculationService _calculation;
  final ExportService _export;
  HistoricalGradeExportAdapter(
      {CalculationService? calculation, ExportService? export})
      : _calculation = calculation ?? CalculationService(),
        _export = export ?? ExportService();

  Map<String, Map<String, double?>> calculate(GradingPeriod period) =>
      GradingPeriodCalculation(calculation: _calculation).calculate(period);

  Uint8List generateXlsx(
    GradingPeriod archive, {
    required String ownerId,
    required String classId,
    String? studentId,
  }) {
    if (!archive.isSealed)
      throw StateError('Historical export requires a sealed period');
    if (archive.dataset.ownerId != ownerId ||
        archive.dataset.classId != classId) {
      throw StateError('Historical export scope mismatch');
    }
    final data = archive.dataset;
    final students = data.students
        .where((s) => studentId == null || s.studentId == studentId)
        .toList();
    if (studentId != null && students.isEmpty)
      throw ArgumentError('Unknown archived student');
    final excel = Excel.decodeBytes(_export.generateXlsx(students,
        data.categories.where((c) => c.isActive).toList(), calculate(archive)));
    _metadata(excel, [archive]);
    return Uint8List.fromList(excel.encode()!);
  }

  /// Mirrors ExportScreen's combined summary layout using only frozen inputs.
  /// Duplicate category labels within a class are rejected rather than silently
  /// dropping a category through the legacy name-to-ID map.
  Uint8List generateCombinedXlsx(
    List<GradingPeriod> archives, {
    required String ownerId,
    required Set<String> classIds,
  }) {
    final names = <String>{};
    final identities = <(String, String)>{};
    for (final archive in archives) {
      final data = archive.dataset;
      if (!archive.isSealed ||
          data.ownerId != ownerId ||
          !classIds.contains(data.classId) ||
          !identities.add((data.classId, archive.periodId))) {
        throw StateError('Invalid combined historical export scope');
      }
      final active = data.categories.where((c) => c.isActive).toList();
      if (active.map((c) => c.name).toSet().length != active.length) {
        throw StateError('Ambiguous category labels in combined export');
      }
      names.addAll(active.map((c) => c.name));
    }
    final excel = Excel.createExcel();
    final sheet = excel.sheets[excel.getDefaultSheet()]!;
    void append(List<String> values) => sheet
        .appendRow(values.map<CellValue?>((v) => TextCellValue(v)).toList());
    append([
      'Class',
      'Subject',
      'School Year',
      'Term',
      'Student ID',
      'Chinese Name',
      'English Name',
      ...names,
      'Process Score (40%)',
      'Exam Score (60%)',
      'Final Grade'
    ]);
    for (final archive in archives) {
      final data = archive.dataset;
      final grades = calculate(archive);
      final ids = {
        for (final c in data.categories.where((c) => c.isActive))
          c.name: c.categoryId
      };
      String format(double? v) => v?.toStringAsFixed(2) ?? '';
      for (final student in data.students) {
        final row = grades[student.studentId]!;
        append([
          data.className,
          data.subject,
          data.schoolYear,
          data.term,
          student.studentId,
          student.chineseName,
          student.englishFullName,
          for (final name in names) format(row[ids[name]]),
          format(row['processScore']),
          format(row['examScore']),
          format(row['finalGrade'])
        ]);
      }
    }
    _metadata(excel, archives);
    return Uint8List.fromList(excel.encode()!);
  }

  void _metadata(Excel excel, List<GradingPeriod> archives) {
    // Summary retains legacy cells; identity/period labels remain unambiguous.
    final metadata = excel['Periods'];
    metadata.appendRow([
      'Class ID',
      'Period ID',
      'Period',
      'Calculation policy',
      'Class',
      'Subject',
      'School Year',
      'Term'
    ].map<CellValue?>((v) => TextCellValue(v)).toList());
    for (final p in archives) {
      metadata.appendRow([
        p.dataset.classId,
        p.periodId,
        p.label,
        p.policyVersion,
        p.dataset.className,
        p.dataset.subject,
        p.dataset.schoolYear,
        p.dataset.term
      ].map<CellValue?>((v) => TextCellValue(v)).toList());
    }
  }
}
