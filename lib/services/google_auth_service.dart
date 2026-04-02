import 'package:google_sign_in/google_sign_in.dart';
import 'package:gradeflow/google/google_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:gradeflow/services/firebase_service.dart';

class GoogleAuthResult {
  GoogleAuthResult._(
      {this.accessToken,
      this.idToken,
      this.error,
      this.stackTrace,
      this.wasCanceled = false});

  final String? accessToken;
  final String? idToken;
  final Object? error;
  final StackTrace? stackTrace;
  final bool wasCanceled;

  bool get ok => accessToken != null && accessToken!.isNotEmpty;
  bool get hasIdToken => idToken != null && idToken!.isNotEmpty;

  String userMessage() {
    if (ok) return 'Signed in.';
    if (wasCanceled) return 'Google sign-in canceled.';

    final errString = '${error ?? ''}';
    final lower = errString.toLowerCase();
    final isPeopleApiDisabled =
        lower.contains('people api has not been used') ||
            (lower.contains('people.googleapis.com') &&
                (lower.contains('service_disabled') ||
                    lower.contains('permission_denied')));
    if (isPeopleApiDisabled) {
      return 'Google sign-in failed because Google People API is disabled for this project. Enable “People API” in Google Cloud Console (APIs & Services → Library), wait a minute, then try again.';
    }

    final err = error;
    if (err is PlatformException) {
      switch (err.code) {
        case 'popup_blocked_by_browser':
          return 'Google sign-in popup was blocked. Allow pop-ups for localhost and try again.';
        case 'popup_closed_by_user':
          return 'Google sign-in window was closed.';
        case 'network_error':
          return 'Network error during Google sign-in. Check connection and try again.';
        case 'sign_in_failed':
          return 'Google sign-in failed. This is often OAuth consent/test-user settings or a Workspace policy.';
        default:
          return 'Google sign-in error (${err.code}). ${err.message ?? ''}'
              .trim();
      }
    }

    return 'Google sign-in failed. ${err ?? 'Unknown error'}';
  }
}

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? client})
      : _googleSignIn = client ??
            GoogleSignIn(
              clientId: GoogleConfig.webClientId.isEmpty
                  ? null
                  : GoogleConfig.webClientId,
              scopes: const [
                'email',
                'profile',
                'https://www.googleapis.com/auth/drive.readonly',
              ],
            );

  final GoogleSignIn _googleSignIn;
  String? _cachedWebAccessToken;
  String? _cachedWebIdToken;
  DateTime? _cachedWebTokenAt;

  bool get _hasFreshWebToken {
    final token = _cachedWebAccessToken;
    final at = _cachedWebTokenAt;
    if (token == null || token.isEmpty || at == null) return false;
    return DateTime.now().difference(at) < const Duration(minutes: 50);
  }

  bool _isGoogleFirebaseUser(fb.User user) {
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  void _cacheWebTokens({required String accessToken, String? idToken}) {
    _cachedWebAccessToken = accessToken;
    _cachedWebIdToken = idToken;
    _cachedWebTokenAt = DateTime.now();
  }

  void cacheWebTokens({required String accessToken, String? idToken}) {
    if (accessToken.isEmpty) return;
    _cacheWebTokens(accessToken: accessToken, idToken: idToken);
  }

  Future<GoogleAuthResult> _ensureWithGoogleSignIn(
      {required bool interactive}) async {
    GoogleSignInAccount? user;
    try {
      user = await _googleSignIn.signInSilently();
      if (user == null) {
        if (!interactive) {
          return GoogleAuthResult._(error: 'not_signed_in');
        }
        user = await _googleSignIn.signIn();
      }
    } catch (e, st) {
      return GoogleAuthResult._(error: e, stackTrace: st);
    }

    if (user == null) {
      return GoogleAuthResult._(wasCanceled: true);
    }

    try {
      final auth = await user.authentication;
      final token = auth.accessToken;
      final idToken = auth.idToken;
      if (token == null || token.isEmpty) {
        return GoogleAuthResult._(
            error: 'No access token returned by Google.');
      }
      if (kIsWeb) {
        _cacheWebTokens(accessToken: token, idToken: idToken);
      }
      return GoogleAuthResult._(accessToken: token, idToken: idToken);
    } catch (e, st) {
      return GoogleAuthResult._(error: e, stackTrace: st);
    }
  }

  Future<GoogleAuthResult> _reauthenticateFirebaseGoogleUser(
      fb.User user) async {
    try {
      final provider = fb.GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile')
        ..addScope('https://www.googleapis.com/auth/drive.readonly');

      final cred = await user.reauthenticateWithPopup(provider);
      final authCred = cred.credential;
      if (authCred is! fb.OAuthCredential) {
        return GoogleAuthResult._(
            error: 'Unexpected credential type returned by FirebaseAuth.');
      }

      final accessToken = authCred.accessToken;
      final idToken = authCred.idToken;
      if (accessToken == null || accessToken.isEmpty) {
        return GoogleAuthResult._(
            error: 'No Google access token returned for Drive scope.');
      }

      _cacheWebTokens(accessToken: accessToken, idToken: idToken);
      return GoogleAuthResult._(accessToken: accessToken, idToken: idToken);
    } catch (e, st) {
      return GoogleAuthResult._(error: e, stackTrace: st);
    }
  }

  /// Ensures an access token is available.
  ///
  /// If [interactive] is false, this will only attempt silent sign-in.
  /// On Flutter web, interactive sign-in without a user gesture can be
  /// blocked by the browser popup blocker.
  Future<GoogleAuthResult> ensureAccessTokenDetailed(
      {bool interactive = true}) async {
    if (kIsWeb && _hasFreshWebToken) {
      return GoogleAuthResult._(
        accessToken: _cachedWebAccessToken,
        idToken: _cachedWebIdToken,
      );
    }

    if (kIsWeb && FirebaseService.isAvailable) {
      if (!interactive) {
        return GoogleAuthResult._(error: 'not_signed_in');
      }

      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser != null && _isGoogleFirebaseUser(currentUser)) {
        final result = await _reauthenticateFirebaseGoogleUser(currentUser);
        if (result.ok || result.wasCanceled) {
          return result;
        }
      }
    }

    return _ensureWithGoogleSignIn(interactive: interactive);
  }

  Future<String?> ensureAccessToken() async {
    final result = await ensureAccessTokenDetailed();
    return result.accessToken;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore
    }
    _cachedWebAccessToken = null;
    _cachedWebIdToken = null;
    _cachedWebTokenAt = null;
  }
}
