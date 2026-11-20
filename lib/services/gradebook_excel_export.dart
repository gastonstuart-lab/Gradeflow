import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:gradeflow/repositories/data_repository.dart';
import 'package:gradeflow/services/gradebook_export_projection.dart';
import 'package:gradeflow/services/gradebook_workspace.dart';

/// Read each class once so summary and assessment sheets agree even if another
/// device saves a score while this workbook is being assembled. Repository
/// reads remain sequential; this does not provide a database transaction.
class GradebookExcelExport {
  const GradebookExcelExport._();

  static Future<Uint8List> build(DataRepository repository) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final summary = excel['All Classes'];
    summary.appendRow(
      [
        'Class',
        'Subject',
        'School Year',
        'Term',
        'Student ID',
        'Chinese Name',
        'English Name',
        ...GradebookExportProjection.summaryHeaders,
      ].map(TextCellValue.new).toList(),
    );
    final detail = excel['Assessments'];
    detail.appendRow(
      [
        'Class ID',
        'Student ID',
        'Student',
        'Category',
        'Assessment',
        'Maximum',
        'Score',
      ].map(TextCellValue.new).toList(),
    );

    final classes = await repository.loadClasses();
    for (final c in classes.where((c) => !c.isArchived)) {
      final book = GradebookWorkspace(repository, c.classId);
      try {
        await book.load();
        for (final student in book.students) {
          summary.appendRow([
            TextCellValue(c.className),
            TextCellValue(c.subject),
            TextCellValue(c.schoolYear),
            TextCellValue(c.term),
            TextCellValue(student.studentId),
            TextCellValue(student.chineseName),
            TextCellValue(student.englishFullName),
            ...GradebookExportProjection.calculatedValues(
              book,
              student.studentId,
            ).map((value) => value == null ? null : DoubleCellValue(value)),
          ]);
          for (final item in book.items) {
            final value = book.score(student.studentId, item.gradeItemId);
            detail.appendRow([
              TextCellValue(c.classId),
              TextCellValue(student.studentId),
              TextCellValue(student.englishFullName),
              TextCellValue(
                book.categories
                        .where((c) => c.categoryId == item.categoryId)
                        .firstOrNull
                        ?.name ??
                    '',
              ),
              TextCellValue(item.name),
              DoubleCellValue(item.maxScore),
              value == null ? null : DoubleCellValue(value),
            ]);
          }
        }
      } finally {
        book.dispose();
      }
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Could not create the Excel workbook.');
    return Uint8List.fromList(bytes);
  }
}
