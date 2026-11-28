import 'dart:convert';
import '../components/time_slot_timetable.dart';
import 'home_weekly_timetable_service.dart';
import 'timetable_import_plan.dart';

/// A minimized, versioned sync payload. The original workbook, its grid,
/// staff tabs and student data are deliberately not included.
class SyncedTimetableVersion {
  SyncedTimetableVersion({required this.id, required this.name,
    required this.uploadedAt, required List<TimeSlotClass> lessons})
      : lessons = List.unmodifiable(lessons) {
    if (id.trim().isEmpty || id.length > 128 || name.trim().isEmpty ||
        name.length > 200 || !uploadedAt.isUtc || lessons.length > 100 ||
        lessons.any((l) => l.title.length > 200 || (l.room?.length ?? 0) > 100 ||
            l.classId == null || l.classId!.trim().isEmpty || l.classId!.length > 200)) {
      throw const FormatException('Invalid confirmed timetable version');
    }
    TimetableImportPlan.validate(lessons);
  }
  final String id, name;
  final DateTime uploadedAt;
  final List<TimeSlotClass> lessons;
  Map<String, dynamic> toJson() => {'id':id,'name':name,
    'uploadedAt':uploadedAt.toIso8601String(),
    'lessons':lessons.map(HomeWeeklyTimetableService.lessonToJson).toList()};
  factory SyncedTimetableVersion.fromJson(Map<String,dynamic> json) {
    if (!json.keys.toSet().containsAll({'id','name','uploadedAt','lessons'}) ||
        json.length != 4) throw const FormatException('Unexpected timetable fields');
    return SyncedTimetableVersion(id:json['id'] as String,name:json['name'] as String,
        uploadedAt:DateTime.parse(json['uploadedAt'] as String),
        lessons:(json['lessons'] as List).map((v)=>HomeWeeklyTimetableService.lessonFromJson(
            Map<String,dynamic>.from(v as Map))).toList());
  }
}
class TeacherTimetableSnapshot {
  TeacherTimetableSnapshot({required this.ownerId, required this.selectedId,
    required List<SyncedTimetableVersion> versions}) : versions = List.unmodifiable(versions) {
    if (ownerId.trim().isEmpty || ownerId.contains('/') || versions.length > 12 ||
        versions.map((v)=>v.id).toSet().length != versions.length ||
        (versions.isEmpty ? selectedId != null :
          !versions.any((v)=>v.id==selectedId))) {
      throw const FormatException('Invalid timetable owner or selection');
    }
    if (utf8.encode(encode()).length > 180000) {
      throw const FormatException('Confirmed timetable payload exceeds 180 KB');
    }
  }
  final String ownerId;
  final String? selectedId;
  final List<SyncedTimetableVersion> versions;
  String encode()=>jsonEncode({'schemaVersion':1,'ownerId':ownerId,
      'selectedId':selectedId,'versions':versions.map((v)=>v.toJson()).toList()});
  factory TeacherTimetableSnapshot.decode(String payload) {
    if (utf8.encode(payload).length>180000) throw const FormatException('Timetable payload too large');
    final json=jsonDecode(payload) as Map<String,dynamic>;
    if(json['schemaVersion']!=1 || json.length!=4 ||
        !json.keys.toSet().containsAll({'schemaVersion','ownerId','selectedId','versions'})) {
      throw const FormatException('Unsupported timetable payload');
    }
    return TeacherTimetableSnapshot(ownerId:json['ownerId'] as String,
        selectedId:json['selectedId'] as String?,
        versions:(json['versions'] as List).map((v)=>SyncedTimetableVersion.fromJson(
            Map<String,dynamic>.from(v as Map))).toList());
  }
  void checkScope(String owner, Set<String> ownedClassIds) {
    if (owner != ownerId || versions.any((v)=>v.lessons.any((l)=>!ownedClassIds.contains(l.classId)))) {
      throw StateError('Timetable contains another account or an unconfirmed class');
    }
  }

  /// Opt-in selection of confirmed local versions. No implicit migration
  /// and no original workbook bytes are exposed to the cloud adapter.
  factory TeacherTimetableSnapshot.fromLocal({
    required String ownerId, required String? selectedId,
    required List<Map<String,dynamic>> versions,
    required Set<String> ownedClassIds,
  }) {
    final value = TeacherTimetableSnapshot(ownerId:ownerId,selectedId:selectedId,
      versions: [
        for(final v in versions) SyncedTimetableVersion(
          id:v['id'] as String,name:v['name'] as String,
          uploadedAt:DateTime.parse(v['uploadedAt'] as String).toUtc(),
          lessons:(v['lessons'] as List).map((l)=>HomeWeeklyTimetableService.lessonFromJson(
              Map<String,dynamic>.from(l as Map))).toList(),
        ),
      ]);
    value.checkScope(ownerId,ownedClassIds);
    return value;
  }

  /// A receiving device can render the selected schedule without storing
  /// the source document. Generate a safe grid from these same lessons.
  List<Map<String,dynamic>> toDeviceVersions() => [
    for(final v in versions) {
      ...v.toJson(),
      'selected':v.id==selectedId,
      'grid':[
        ['Day','Start','End','Class','Class ID','Room'],
        for(final l in v.lessons) [
          TimetableImportPlan.weekdays[l.dayOfWeek],
          _clock(l.startMinutes),_clock(l.endMinutes),l.title,l.classId!,l.room??'',
        ],
      ],
    }
  ];
  static String _clock(int minutes) =>
      '${(minutes~/60).toString().padLeft(2,'0')}:${(minutes%60).toString().padLeft(2,'0')}';
}
class TimetableSyncConflict implements Exception {
  const TimetableSyncConflict();
  @override
  String toString()=>'Timetable changed on another device. Reload and review before replacing.';
}
class TimetableSyncRevision {
  const TimetableSyncRevision({required this.revision,required this.operationId,required this.snapshot});
  final int revision;
  final String operationId;
  final TeacherTimetableSnapshot snapshot;
}
