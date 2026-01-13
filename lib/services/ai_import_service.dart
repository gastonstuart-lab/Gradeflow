import 'package:flutter/foundation.dart';
import 'package:gradeflow/services/file_import_service.dart';
import 'package:gradeflow/openai/openai_config.dart';

class AiImportOutput {
  final List<ImportedClass> classesMeta; // May have null subject/year/term
  final Map<String, List<ImportedStudent>> byClass; // key is className/classCode
  final List<String> errors;

  AiImportOutput({required this.classesMeta, required this.byClass, required this.errors});
}

class AiImportService {
  final OpenAIClient _client = const OpenAIClient();
  final FileImportService _fileImportService = FileImportService();

  static const String defaultModel = 'gpt-4o';

  Future<AiImportOutput?> inferFromRows(List<List<String>> rows, {String? filename}) async {
    // Try AI first if configured
    try {
      if (rows.isEmpty) return null;
      final firstCols = rows.isNotEmpty ? rows.first.length : 0;
      debugPrint('AI Import: rows=${rows.length}, cols(first)=$firstCols, file=${filename ?? 'unknown'}');
      final sample = _csvFromRows(rows.take(120).toList());
      final messages = [
        {
          'role': 'system',
          'content': 'You are a strict data normalizer for school class rosters. Always respond with a single valid JSON object. Do not include any commentary.'
        },
        {
          'role': 'user',
          'content': _buildPrompt(sample, filename: filename),
        }
      ];
      final jsonObj = await _client.chatJson(model: defaultModel, messages: messages);
      return parseRosterJson(jsonObj);
    } catch (e) {
      debugPrint('AI import failed: $e');
      debugPrint('AI Import: AI could not interpret file "${filename ?? 'unknown'}". Falling back to local parser.');
      // Fall back to smart local parser
      return _localParse(rows, filename: filename);
    }
  }

  Future<Map<String, dynamic>> analyzeSchoolCalendarFromRows(
    List<List<String>> rows, {
    String? filename,
  }) async {
    if (rows.isEmpty) {
      return {
        'events': <Object?>[],
        'errors': ['No rows found'],
      };
    }

    final sample = _csvFromRows(rows.take(180).toList());
    final messages = [
      {
        'role': 'system',
        'content':
            'You extract SCHOOL CALENDAR events from spreadsheet-like data. Always respond with a single valid JSON object and no commentary.'
      },
      {
        'role': 'user',
        'content': _buildCalendarPrompt(sample, filename: filename),
      },
    ];

    return _client.chatJson(model: defaultModel, messages: messages);
  }

  Future<Map<String, dynamic>> analyzeExamScoresFromRows(
    List<List<String>> rows, {
    String? filename,
  }) async {
    if (rows.isEmpty) {
      return {
        'scores': <Object?>[],
        'errors': ['No rows found'],
      };
    }

    final sample = _csvFromRows(rows.take(180).toList());
    final messages = [
      {
        'role': 'system',
        'content':
            'You extract FINAL EXAM scores from spreadsheet-like data. Always respond with a single valid JSON object and no commentary.'
      },
      {
        'role': 'user',
        'content': _buildExamPrompt(sample, filename: filename),
      },
    ];

    return _client.chatJson(model: defaultModel, messages: messages);
  }

  Future<Map<String, dynamic>> analyzeClassesFromRows(
    List<List<String>> rows, {
    String? filename,
  }) async {
    if (rows.isEmpty) {
      return {
        'classes': <Object?>[],
        'errors': ['No rows found'],
      };
    }

    final sample = _csvFromRows(rows.take(180).toList());
    final messages = [
      {
        'role': 'system',
        'content':
            'You extract CLASS records from spreadsheet-like data. Always respond with a single valid JSON object and no commentary.'
      },
      {
        'role': 'user',
        'content': _buildClassesPrompt(sample, filename: filename),
      },
    ];

    return _client.chatJson(model: defaultModel, messages: messages);
  }

  Future<Map<String, dynamic>> analyzeTimetableFromRows(
    List<List<String>> rows, {
    String? filename,
  }) async {
    if (rows.isEmpty) {
      return {
        'timetable': {'entries': <Object?>[]},
        'errors': ['No rows found'],
      };
    }

    final sample = _csvFromRows(rows.take(220).toList());
    final messages = [
      {
        'role': 'system',
        'content':
            'You extract a TEACHER TIMETABLE from spreadsheet-like data. Always respond with a single valid JSON object and no commentary.'
      },
      {
        'role': 'user',
        'content': _buildTimetablePrompt(sample, filename: filename),
      },
    ];

    return _client.chatJson(model: defaultModel, messages: messages);
  }
  
  // Smart local parser that doesn't require AI
  AiImportOutput? _localParse(List<List<String>> rows, {String? filename}) {
    try {
      if (rows.isEmpty) return null;
      
      debugPrint('Local Parser: Processing ${rows.length} rows from ${filename ?? 'unknown'}');
      
      // Convert to CSV format for existing parser
      final csvContent = _csvFromRows(rows);
      final students = _fileImportService.parseCSV(csvContent);
      
      if (students.isEmpty) {
        debugPrint('Local Parser: No valid students found');
        return null;
      }
      
      // Group by class code
      final byClass = <String, List<ImportedStudent>>{};
      for (final student in students) {
        final classKey = student.classCode?.isNotEmpty == true ? student.classCode! : 'Default Class';
        byClass.putIfAbsent(classKey, () => []).add(student);
      }
      
      // Create class metadata
      final classesMeta = byClass.keys.map((className) => ImportedClass(
        className: className,
        subject: null,
        groupNumber: null,
        schoolYear: null,
        term: null,
        isValid: true,
      )).toList();
      
      final validCount = students.where((s) => s.isValid).length;
      final invalidCount = students.length - validCount;
      
      debugPrint('Local Parser: Found ${byClass.length} classes, $validCount valid students, $invalidCount with errors');
      
      return AiImportOutput(
        classesMeta: classesMeta,
        byClass: byClass,
        errors: invalidCount > 0 ? ['$invalidCount students skipped due to missing required fields'] : [],
      );
    } catch (e) {
      debugPrint('Local parser failed: $e');
      return null;
    }
  }

  String _csvFromRows(List<List<String>> rows) {
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    return rows.map((r) => r.map((c) => esc(c)).join(',')).join('\n');
  }

  String _buildPrompt(String csvSample, {String? filename}) {
    return '''Infer class roster structure from the CSV/XLSX sample below and output JSON following this schema exactly:
{
  "classes": [
    {
      "className": "string (required)",
      "subject": "string|null",
      "schoolYear": "string|null",
      "term": "string|null",
      "students": [
        {"studentId":"string (required)", "chineseName":"string (required)", "englishFirstName":"string (required)", "englishLastName":"string (required)", "seatNo":"string|null"}
      ]
    }
  ],
  "errors": ["string"]
}
Rules:
- Accept header synonyms and multilingual headers. Common headers: StudentID/Student No/學號; ChineseName/姓名; FirstName/GivenName; LastName/Surname; EnglishName (split into first/last if needed); SeatNo/座號; ClassCode/Class/ClassName.
- If names are in one column, split by spaces: last token is last name, the rest are first name. If only one token, duplicate it to both first and last.
- Group rows into classes by the most reliable column: ClassCode > Class > ClassName. Use that as className.
- Keep values as strings. Trim whitespace. Do not fabricate data. If a required field is missing, put a short message into errors and skip that row.
- Attempt to infer subject/schoolYear/term only if explicit columns exist; otherwise set them to null.
- Do not include any text outside the JSON.
Filename: ${filename ?? 'unknown'}
CSV_SAMPLE_START
$csvSample
CSV_SAMPLE_END''';
  }

  static AiImportOutput parseRosterJson(Map<String, dynamic> obj) {
    final errors = <String>[];
    final classesMeta = <ImportedClass>[];
    final byClass = <String, List<ImportedStudent>>{};

    try {
      final classes = (obj['classes'] as List?) ?? const [];
      for (final c in classes) {
        if (c is! Map) continue;
        final className = (c['className'] ?? '').toString().trim();
        if (className.isEmpty) continue;
        final subject = (c['subject']?.toString().trim().isEmpty ?? true) ? null : c['subject'].toString().trim();
        final schoolYear = (c['schoolYear']?.toString().trim().isEmpty ?? true) ? null : c['schoolYear'].toString().trim();
        final term = (c['term']?.toString().trim().isEmpty ?? true) ? null : c['term'].toString().trim();

        classesMeta.add(ImportedClass(
          className: className,
          subject: subject,
          groupNumber: null,
          schoolYear: schoolYear,
          term: term,
          isValid: className.isNotEmpty,
        ));

        final students = <ImportedStudent>[];
        final rawStudents = (c['students'] as List?) ?? const [];
        for (final s in rawStudents) {
          if (s is! Map) continue;
          final studentId = (s['studentId'] ?? '').toString().trim();
          final chineseName = (s['chineseName'] ?? '').toString().trim();
          final firstName = (s['englishFirstName'] ?? '').toString().trim();
          final lastName = (s['englishLastName'] ?? '').toString().trim();
          final seatNo = (s['seatNo']?.toString().trim().isEmpty ?? true) ? null : s['seatNo'].toString().trim();

          final isValid = studentId.isNotEmpty && chineseName.isNotEmpty && firstName.isNotEmpty && lastName.isNotEmpty;
          students.add(ImportedStudent(
            studentId: studentId,
            chineseName: chineseName,
            englishFirstName: firstName,
            englishLastName: lastName,
            seatNo: seatNo,
            classCode: className,
            isValid: isValid,
            error: isValid ? null : 'Missing required fields',
          ));
        }
        byClass[className] = students;
      }
    } catch (e) {
      errors.add('Failed to parse AI JSON: $e');
      debugPrint('AI JSON parse error: $e');
    }

    final errs = (obj['errors'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    errors.addAll(errs);
    return AiImportOutput(classesMeta: classesMeta, byClass: byClass, errors: errors);
  }

  String _buildCalendarPrompt(String csvSample, {String? filename}) {
    return '''Extract SCHOOL CALENDAR events from the spreadsheet sample below and output JSON following this schema exactly:
{
  "events": [
    {
      "date": "YYYY-MM-DD (required)",
      "title": "string (required)",
      "details": "string|null"
    }
  ],
  "errors": ["string"]
}
Rules:
- This is a school calendar, not a class roster.
- If dates are given as M/D, infer the year from the filename if it contains a year; otherwise leave the event out and add an error.
- If a row contains multiple events, output multiple entries.
- Do not invent events. Ignore empty cells.
- Keep titles concise.
- Do not include any text outside the JSON.
Filename: ${filename ?? 'unknown'}
CSV_SAMPLE_START
$csvSample
CSV_SAMPLE_END''';
  }

  String _buildExamPrompt(String csvSample, {String? filename}) {
    return '''Extract FINAL EXAM scores from the spreadsheet sample below and output JSON following this schema exactly:
{
  "scores": [
    {"studentId": "string (required)", "score": "number 0-100 (required)"}
  ],
  "errors": ["string"]
}
Rules:
- Accept header variants like Student ID/學號/ID and Score/Exam Score/Final Exam/成績.
- Do not invent scores.
- If a score is not numeric, skip it.
- If a file has multiple score columns, pick the one that most looks like final exam.
- Do not include any text outside the JSON.
Filename: ${filename ?? 'unknown'}
CSV_SAMPLE_START
$csvSample
CSV_SAMPLE_END''';
  }

  String _buildClassesPrompt(String csvSample, {String? filename}) {
    return '''Extract CLASSES from the spreadsheet sample below and output JSON following this schema exactly:
{
  "classes": [
    {
      "className": "string (required)",
      "subject": "string|null",
      "groupNumber": "string|null",
      "schoolYear": "string|null",
      "term": "string|null"
    }
  ],
  "errors": ["string"]
}
Rules:
- Accept header variants like Class/Class Name/Section/班級 and Subject/科目.
- Do not fabricate missing metadata; use null.
- Do not include any text outside the JSON.
Filename: ${filename ?? 'unknown'}
CSV_SAMPLE_START
$csvSample
CSV_SAMPLE_END''';
  }

  String _buildTimetablePrompt(String csvSample, {String? filename}) {
    return '''Extract a TEACHER TIMETABLE from the spreadsheet sample below and output JSON following this schema exactly:
{
  "timetable": {
    "name": "string|null",
    "entries": [
      {
        "day": "Mon|Tue|Wed|Thu|Fri|Sat|Sun (required)",
        "startTime": "HH:MM 24h (required)",
        "endTime": "HH:MM 24h (required)",
        "title": "string (required)",
        "location": "string|null"
      }
    ]
  },
  "errors": ["string"]
}
Rules:
- Timetables are usually a grid: days across, periods/times down.
- Infer times if explicit time ranges exist; otherwise use period numbers as approximate times by leaving them out and add an error (do not invent).
- Do not include any text outside the JSON.
Filename: ${filename ?? 'unknown'}
CSV_SAMPLE_START
$csvSample
CSV_SAMPLE_END''';
  }
}
