import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'participation_ledger_repository.dart';

/// Device-local synthetic review adapter, NOT a multi-tab or cloud
/// transaction guarantee. The static queue serializes same-isolate writers.
/// A production adapter needs trusted authorization and server-side CAS.
class SyntheticParticipationLocalStore implements ParticipationSnapshotStore {
  SyntheticParticipationLocalStore({required bool syntheticOnly}) {
    if (!syntheticOnly) throw StateError('Fictional preview storage only');
  }

  static Future<void> _tail = Future.value();

  static Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return result;
  }

  String _checkedKey(String key) {
    if (!key.startsWith('participation-draft:v1:')) {
      throw StateError('Invalid isolated participation key');
    }
    return 'synthetic-review:$key';
  }

  @override
  Future<String?> read(String key) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_checkedKey(key));
  });

  @override
  Future<bool> compareAndSet(String key, {required String? expected, required String value}) =>
      _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final scopedKey = _checkedKey(key);
        await prefs.reload();
        if (prefs.getString(scopedKey) != expected) return false;
        try {
          if (!await prefs.setString(scopedKey, value)) {
            throw StateError('Local participation save unconfirmed');
          }
          await prefs.reload();
          if (prefs.getString(scopedKey) != value) {
            throw StateError('Local participation readback differs');
          }
          return true;
        } catch (_) {
          await prefs.reload();
          rethrow;
        }
      });
}
