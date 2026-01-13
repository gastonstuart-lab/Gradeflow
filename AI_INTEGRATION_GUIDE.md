# AI Integration Guide

## Current Status

### ✅ AI Already Integrated
- **Exam Scores Import** (`exam_input_screen.dart`) - Full AI support with AiAnalyzeImportDialog
- **Calendar Import** (`teacher_dashboard_screen.dart`) - AI option in diagnostics dialog

### 🟡 AI Service Ready, Not Integrated in UI
The `AiImportService` already has methods for:
- `inferFromRows()` - Student roster import (with smart local fallback)
- `analyzeClassesFromRows()` - Class list import
- `analyzeTimetableFromRows()` - Timetable import
- `analyzeSchoolCalendarFromRows()` - Calendar import (already used)
- `analyzeExamScoresFromRows()` - Exam scores (already used)

## Integration Pattern

All AI imports follow this pattern:

```dart
// 1. Check if AI is configured
if (!OpenAIConfig.isConfigured) {
  _showError('AI not configured. Set OPENAI_PROXY_ENDPOINT and OPENAI_PROXY_API_KEY.');
  return;
}

// 2. Convert file bytes to rows
final rows = FileImportService().rowsFromAnyBytes(bytes);

// 3. Show AI analyze dialog
final result = await showDialog<Map<String, dynamic>>(
  context: context,
  builder: (ctx) => AiAnalyzeImportDialog(
    title: 'Analyze [type] with AI',
    filename: filename,
    confirmLabel: 'Import [items]',
    analyze: () => AiImportService().[methodName](rows, filename: filename),
  ),
);

// 4. Process result
if (result == null || !mounted) return;
// Extract and use data...
```

## Pending Integrations

### 1. Student List Import (`student_list_screen.dart`)

**Location**: `_showImportDialog()` method (line ~50)

**Current Flow**:
- FilePicker → parse locally → show preview → import

**Add AI**:
Add "Try AI" button to the error dialog (where it shows diagnostics):

```dart
// In the diagnostic dialog actions (around line 100):
if (OpenAIConfig.isConfigured)
  FilledButton(
    onPressed: () async {
      Navigator.pop(ctx); // Close diagnostics
      
      final rows = _importService.rowsFromAnyBytes(bytes);
      final aiResult = await showDialog<AiImportOutput>(
        context: context,
        builder: (_) => AiAnalyzeImportDialog(
          title: 'Analyze student roster with AI',
          filename: result.files.single.name,
          confirmLabel: 'Import students',
          analyze: () async {
            final output = await AiImportService()
                .inferFromRows(rows, filename: result.files.single.name);
            if (output == null) {
              return {'error': 'AI could not parse the file'};
            }
            // Convert AiImportOutput to Map for dialog
            return {
              'classes': output.classesMeta,
              'students': output.byClass,
              'errors': output.errors,
            };
          },
        ),
      );
      
      if (aiResult == null) return;
      // Process AI-parsed students...
    },
    child: const Text('Try AI'),
  ),
```

### 2. Class Import (`class_list_screen.dart`)

**Location**: Multiple import methods around line 163+

**Current Flow**:
- FilePicker → parse locally → create classes

**Add AI**:
Similar pattern - add AI button to error/diagnostics dialogs using `analyzeClassesFromRows()`.

### 3. Timetable Import (DOCX)

**Location**: `teacher_dashboard_screen.dart`, timetable upload (line ~1696)

**Current**: Uses `extractDocxBestTableGrid()` + `cleanTimetableGrid()` (newly added)

**Add AI Enhancement**:
If the cleaned grid still looks messy, offer AI option:

```dart
// After cleaning, check if result is still problematic
if (grid != null && (grid.length > 15 || _hasEmptyCells(grid))) {
  // Show option to use AI to further clean/interpret
  final useAI = await showDialog<bool>(...);
  if (useAI && OpenAIConfig.isConfigured) {
    final rows = grid; // Use cleaned grid as input
    final aiResult = await AiImportService()
        .analyzeTimetableFromRows(rows, filename: name);
    // Rebuild grid from AI output...
  }
}
```

## Configuration

To enable AI, the app needs OpenAI proxy configuration:

### Flutter Run/Build Commands:
```bash
flutter run -d chrome --dart-define=OPENAI_PROXY_ENDPOINT=https://your-endpoint --dart-define=OPENAI_PROXY_API_KEY=your-key

flutter build web --dart-define=OPENAI_PROXY_ENDPOINT=https://your-endpoint --dart-define=OPENAI_PROXY_API_KEY=your-key
```

### Environment Setup:
Or use environment files (requires flutter_dotenv or similar):
```
OPENAI_PROXY_ENDPOINT=https://api.openai.com/v1
OPENAI_PROXY_API_KEY=sk-...
```

## Testing AI Integration

1. **Without Configuration** (default):
   - AI buttons should be hidden (check `OpenAIConfig.isConfigured`)
   - Local parsers work as fallback
   
2. **With Configuration**:
   - AI buttons appear in import dialogs
   - Clicking shows loading state
   - Results display in preview dialog
   - User can confirm or cancel

## Benefits of AI Integration

- **Handles non-standard formats**: AI can interpret messy spreadsheets
- **Multilingual support**: Works with Chinese/English mixed content
- **Smart inference**: Guesses column meanings even without headers
- **Error correction**: Can fix common data entry mistakes
- **User feedback**: Shows what AI interpreted before importing

## Implementation Priority

1. ✅ **Timetable cleanup** (COMPLETED - uses smart local logic)
2. 🔄 **Student import AI** (HIGH - most frequently used)
3. 🔄 **Class import AI** (MEDIUM - less frequent, but useful)
4. 🔄 **Timetable AI enhancement** (LOW - local cleanup works well)

## Code Quality Notes

- Always check `OpenAIConfig.isConfigured` before showing AI options
- Provide clear error messages when AI fails
- Always have local parser fallback
- Test both AI and non-AI paths
- Handle network errors gracefully
