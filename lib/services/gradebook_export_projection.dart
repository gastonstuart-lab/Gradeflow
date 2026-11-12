import 'package:gradeflow/services/gradebook_workspace.dart';

/// Read-only projection of the Gradebook's *saved* calculation policy for an
/// XLSX summary. One row is a snapshot of GradebookWorkspace values; no
/// formulas here silently replace custom class/category weights with defaults.
///
/// The seven columns deliberately preserve the established All Classes
/// worksheet positions (H:N), so existing exports remain column-compatible.
class GradebookExportProjection {
  const GradebookExportProjection._();

  static const summaryHeaders = <String>[
    'Homework',
    'Quiz',
    'Classwork',
    'Participation',
    'Process Score (saved category weights)',
    'Exam Score',
    'Final Grade',
  ];

  static const categoryOrder = <String>[
    'Homework',
    'Quizzes',
    'Classwork',
    'Participation',
  ];

  /// Null values stay missing; zero is preserved as a real grade.
  static List<double?> calculatedValues(
    GradebookWorkspace book,
    String studentId,
  ) {
    double? categoryAverage(String canonicalName) {
      final categories = book.categories
          .where((c) => GradebookWorkspace.canonical(c.name) == canonicalName)
          .toList();
      return categories.length == 1
          ? book.average(studentId, categories.single.categoryId)
          : null;
    }

    return <double?>[
      for (final category in categoryOrder) categoryAverage(category),
      book.process(studentId),
      book.exam(studentId),
      book.finalGrade(studentId),
    ];
  }
}
