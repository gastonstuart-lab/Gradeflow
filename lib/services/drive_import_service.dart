import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:gradeflow/services/google_auth_service.dart';

class DriveImportService {
  /// Try to fetch bytes from a URL. If [useDriveAuth] is true, will request a Google access
  /// token and attach it as a Bearer header (for private Drive links).
  Future<Uint8List?> fetchBytesFromLink(String rawUrl, {bool useDriveAuth = false}) async {
    final directUrl = driveDirectDownloadUrl(rawUrl) ?? rawUrl;
    final uri = Uri.tryParse(directUrl);
    if (uri == null) return null;

    Map<String, String>? headers;
    if (useDriveAuth) {
      final result = await GoogleAuthService().ensureAccessTokenDetailed();
      if (!result.ok) {
        throw StateError(result.userMessage());
      }
      headers = {'Authorization': 'Bearer ${result.accessToken}'};
    }

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode >= 400) {
      throw StateError('Download failed (${resp.statusCode}). If this is a Drive link, confirm sharing permissions or sign-in.');
    }
    return resp.bodyBytes;
  }

  /// Converts common Google Drive sharing URLs to direct-download links.
  String? driveDirectDownloadUrl(String url) {
    final fileIdMatch = RegExp(r'd/([^/]+)/').firstMatch(url);
    if (fileIdMatch != null && fileIdMatch.groupCount >= 1) {
      final id = fileIdMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$id';
    }

    final queryId = Uri.tryParse(url)?.queryParameters['id'];
    if (queryId != null && queryId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$queryId';
    }

    return null;
  }
}
