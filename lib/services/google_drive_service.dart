import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:gradeflow/services/google_auth_service.dart';

class DriveFile {
  final String id;
  final String name;
  final String mimeType;
  final List<String> parents;
  final DateTime? modifiedTime;
  final int? size;

  const DriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.parents = const [],
    this.modifiedTime,
    this.size,
  });

  factory DriveFile.fromJson(Map<String, dynamic> json) {
    final mt = json['modifiedTime'];
    DateTime? parsed;
    if (mt is String) {
      parsed = DateTime.tryParse(mt);
    }

    final sizeStr = json['size'];
    int? size;
    if (sizeStr is String) {
      size = int.tryParse(sizeStr);
    } else if (sizeStr is num) {
      size = sizeStr.toInt();
    }

    final parents = (json['parents'] is List)
        ? (json['parents'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    return DriveFile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      parents: parents,
      modifiedTime: parsed,
      size: size,
    );
  }

  bool get isFolder => mimeType == GoogleDriveService.folderMimeType;
}

class GoogleDriveService {
  GoogleDriveService({http.Client? httpClient, GoogleAuthService? authService})
      : _http = httpClient ?? http.Client(),
        _auth = authService ?? GoogleAuthService();

  final http.Client _http;
  final GoogleAuthService _auth;

  static const String googleSheetMimeType =
      'application/vnd.google-apps.spreadsheet';
  static const String folderMimeType = 'application/vnd.google-apps.folder';
  static const String exportXlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const String exportCsvMimeType = 'text/csv';

  Future<List<DriveFile>> listRecentFiles(
      {int pageSize = 25, bool interactiveAuth = true}) async {
    final auth = await _auth.ensureAccessTokenDetailed(
        interactive: interactiveAuth);
    if (!auth.ok) {
      throw StateError(auth.userMessage());
    }

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'pageSize': '$pageSize',
      'orderBy': 'modifiedTime desc',
      'q': 'trashed=false',
      'fields': 'files(id,name,mimeType,modifiedTime,size,parents)',
      'supportsAllDrives': 'true',
      'includeItemsFromAllDrives': 'true',
    });

    final resp = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer ${auth.accessToken}'},
    );

    if (resp.statusCode >= 400) {
      throw StateError('Drive list failed (${resp.statusCode}).');
    }

    final jsonBody = jsonDecode(resp.body);
    final files = (jsonBody is Map<String, dynamic>)
        ? (jsonBody['files'] as List<dynamic>? ?? const [])
        : const <dynamic>[];

    return files
        .whereType<Map<String, dynamic>>()
        .map(DriveFile.fromJson)
        .where((f) => f.id.isNotEmpty && f.name.isNotEmpty)
        .toList();
  }

  /// Lists the contents of a Drive folder.
  ///
  /// Use [interactiveAuth]=true only from a user gesture.
  Future<List<DriveFile>> listFolder(
      {String folderId = 'root',
      int pageSize = 200,
      bool interactiveAuth = false}) async {
    final auth = await _auth.ensureAccessTokenDetailed(
        interactive: interactiveAuth);
    if (!auth.ok) {
      throw StateError(auth.userMessage());
    }

    final q = "'$folderId' in parents and trashed=false";
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'pageSize': '$pageSize',
      'q': q,
      'fields': 'files(id,name,mimeType,modifiedTime,size,parents)',
      'supportsAllDrives': 'true',
      'includeItemsFromAllDrives': 'true',
    });

    final resp = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer ${auth.accessToken}'},
    );

    if (resp.statusCode >= 400) {
      throw StateError('Drive list failed (${resp.statusCode}).');
    }

    final jsonBody = jsonDecode(resp.body);
    final files = (jsonBody is Map<String, dynamic>)
        ? (jsonBody['files'] as List<dynamic>? ?? const [])
        : const <dynamic>[];

    final out = files
        .whereType<Map<String, dynamic>>()
        .map(DriveFile.fromJson)
        .where((f) => f.id.isNotEmpty && f.name.isNotEmpty)
        .toList();

    out.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return out;
  }

  Future<Uint8List> downloadFileBytesFor(DriveFile file,
      {String preferredExportMimeType = exportXlsxMimeType}) async {
    if (file.mimeType == googleSheetMimeType) {
      return exportFileBytes(file.id, preferredExportMimeType);
    }

    return downloadFileBytes(file.id);
  }

  Future<Uint8List> exportFileBytes(
      String fileId, String exportMimeType) async {
    final auth = await _auth.ensureAccessTokenDetailed();
    if (!auth.ok) {
      throw StateError(auth.userMessage());
    }

    final uri =
        Uri.https('www.googleapis.com', '/drive/v3/files/$fileId/export', {
      'mimeType': exportMimeType,
      'supportsAllDrives': 'true',
    });

    final resp = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer ${auth.accessToken}'},
    );

    if (resp.statusCode >= 400) {
      throw StateError('Drive export failed (${resp.statusCode}).');
    }

    return resp.bodyBytes;
  }

  Future<Uint8List> downloadFileBytes(String fileId) async {
    final auth = await _auth.ensureAccessTokenDetailed();
    if (!auth.ok) {
      throw StateError(auth.userMessage());
    }

    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {
      'alt': 'media',
      'supportsAllDrives': 'true',
    });

    final resp = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer ${auth.accessToken}'},
    );

    if (resp.statusCode >= 400) {
      throw StateError('Drive download failed (${resp.statusCode}).');
    }

    return resp.bodyBytes;
  }
}
