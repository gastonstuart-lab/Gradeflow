import 'dart:async';
import 'dart:math';

/// Classroom-only highlight animation. It never changes the saved room map,
/// seats, students, grades, or their ordering.
class ClassroomPickerAnimator {
  ClassroomPickerAnimator({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Set<String> _chosenStudents = <String>{};
  int _generation = 0;

  /// Cancel any pending animation, e.g. when changing class or leaving screen.
  void cancel({bool clearStudentHistory = false}) {
    _generation++;
    if (clearStudentHistory) _chosenStudents.clear();
  }

  /// Highlight several eligible IDs before returning a final choice.
  ///
  /// [nonRepeatingStudents] prevents a final student being selected twice
  /// until all seated students have been selected. Preview frames do not count.
  /// Tables remain independently random on each pick.
  Future<String?> animate({
    required List<String> candidateIds,
    required bool nonRepeatingStudents,
    required bool reduceMotion,
    required void Function(String id) onHighlight,
  }) async {
    final epoch = ++_generation;
    final candidates = candidateIds.toSet().toList();
    if (candidates.isEmpty) return null;

    var eligible = candidates;
    if (nonRepeatingStudents) {
      _chosenStudents.removeWhere((id) => !candidates.contains(id));
      eligible =
          candidates.where((id) => !_chosenStudents.contains(id)).toList();
      if (eligible.isEmpty) {
        _chosenStudents.clear();
        eligible = candidates;
      }
    }

    // Select the final outcome before the visual roulette; previews never
    // influence fairness or alter assignments.
    final chosen = eligible[_random.nextInt(eligible.length)];
    if (!reduceMotion && candidates.length > 1) {
      String? previous;
      for (var frame = 0; frame < 10; frame++) {
        if (epoch != _generation) return null;
        final alternatives =
            candidates.where((id) => id != previous).toList();
        final highlighted =
            alternatives[_random.nextInt(alternatives.length)];
        previous = highlighted;
        onHighlight(highlighted);
        await Future<void>.delayed(
          Duration(milliseconds: 70 + frame * 18),
        );
      }
    }

    if (epoch != _generation) return null;
    if (nonRepeatingStudents) _chosenStudents.add(chosen);
    onHighlight(chosen);
    return chosen;
  }
}
