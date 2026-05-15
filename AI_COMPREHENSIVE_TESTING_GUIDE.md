# Gradeflow - AI Testing Agent Prompt

## Quick Access
**🔗 APP URL**: http://localhost:57473/dashboard  
**📱 Device**: Any browser (desktop recommended)  
**⏱️ Estimated Test Time**: 45-60 minutes for full test pass  

---

## What You're Testing

**Gradeflow** is a Flutter-based classroom management system that helps teachers manage classes, students, grades, attendance, and interactive classroom activities. The app uses Firebase for data storage. Any future OpenAI API usage must go through Firebase Functions/server-side secrets only.

### Current Status
- **Completion**: 95%
- **Recent Fixes** (today):
  1. Timer/stopwatch fullscreen layout fixed
  2. Participation minus button added to fullscreen
  3. Seating designer toolbar no longer overflows
  4. Seating table header layout improved (prevents render overflow)
  5. Better error messages for AI features

---

## Your Testing Objectives

You are testing for:
1. ✅ **Functionality**: All features work as described
2. ✅ **UI/UX**: No layout issues, overflow, or visual bugs
3. ✅ **Data Persistence**: Changes save correctly
4. ✅ **Error Handling**: Graceful failures with helpful messages
5. ✅ **Responsive Design**: Works on different screen sizes
6. ✅ **AI Integration**: Features degrade gracefully if API unavailable

---

## Critical Path Tests (Test These First)

### 1. Login & Initial Load
```
Goal: Verify app boots and displays demo data
Expected: Dashboard with 3 classes (Grade 10A, 11B, 12C), 25+ demo students
Steps:
  1. Open http://localhost:57473/dashboard
  2. Google Sign-In should appear (may already be logged in)
  3. After login, dashboard loads with demo data
  4. Can see class list, student count, grade statistics
Status: __ PASS __ FAIL __ PARTIAL
Notes:
```

### 2. Timer & Stopwatch (Recently Fixed)
```
Goal: Verify fullscreen timer works without layout issues
Steps:
  1. Select a class from dropdown
  2. Click "Present on Projector" button
  3. Select "Timer" tool tab
  4. Verify layout displays properly:
     - Stopwatch section visible
     - Time displays in large font
     - Start/Pause buttons work
     - Reset button works
     - Countdown section visible
     - All buttons visible (no overflow)
  5. Click Close button

Critical: NO YELLOW/BLACK OVERFLOW STRIPES SHOULD APPEAR
Status: __ PASS __ FAIL __ PARTIAL
Notes:
```

### 3. Participation Points
```
Goal: Verify participation tracking in both normal and fullscreen
Steps:
  NORMAL VIEW:
  1. Select class
  2. Click "Participation" tool
  3. Verify student list with points appears
  4. Click "+" button next to student → points increase
  5. Click "-" button next to student → points decrease (not below 0)
  6. "Cold Call" button picks random student
  
  FULLSCREEN VIEW:
  1. Click "Present on Projector"
  2. Select "Participation" tab
  3. Verify large layout with students
  4. Click "Add" button → points increase
  5. Click "Remove" button → points decrease
  
Status: __ PASS __ FAIL __ PARTIAL
Notes: Both add and remove buttons must be visible and functional
```

### 4. Seating Designer
```
Goal: Verify seating tool with no overflow errors
Steps:
  1. Select class
  2. Click "Seating" tool
  3. Verify toolbar buttons display without overflow:
     - Seats per table dropdown
     - Add table button
     - Randomize button
     - Clear assignments button
     - Auto-arrange icon button
     - Clear layout icon button
  4. Click "Add table" → table appears on canvas
  5. Drag table around → moves smoothly
  6. Click "Randomize" → students assigned to seats
  7. Toggle between "Design" and "Assign" modes
  8. Click "Assign" mode → click on seat → select student
  
Status: __ PASS __ FAIL __ PARTIAL
Notes: Watch for yellow/black overflow stripes. Toolbar buttons should wrap to next line if needed.
```

### 5. Grades View & Entry
```
Goal: Verify grading interface works
Steps:
  1. Select class
  2. Click "Grades" or grading interface
  3. Spreadsheet-like view appears with students × assignments
  4. Click on a cell and enter a grade
  5. Grade saves automatically
  6. Refresh page → grade still there (persistence check)
  
Status: __ PASS __ FAIL __ PARTIAL
Notes:
```

### 6. Attendance Marking
```
Goal: Verify attendance functionality
Steps:
  1. Select class
  2. Click "Attendance" tool
  3. See student list with checkboxes
  4. Check/uncheck boxes to mark present/absent
  5. Click "Save" or auto-saves
  6. Reload page → attendance saved
  
Status: __ PASS __ FAIL __ PARTIAL
Notes:
```

---

## All 8 Class Tools - Extended Testing

Test each tool in both **normal view** and **fullscreen mode** (via "Present on Projector"):

### Tool 0: Name Picker
**Description**: Random student selector for cold calling
- [ ] "Pick Random" button selects a name
- [ ] Name displays clearly
- [ ] Works in fullscreen with large text
- [ ] "Next Student" button in fullscreen works
- [ ] Names are from current class students

### Tool 1: Group Maker
**Description**: Creates random groups
- [ ] Set group size (2, 3, 4, 5, 6, 8, 10) from dropdown
- [ ] Click "Generate Groups" → groups appear
- [ ] "Pairs" button makes groups of 2
- [ ] "Randomize" regenerates
- [ ] Fullscreen shows all groups in scrollable layout
- [ ] Each group displays student names

### Tool 2: Seating Designer  
**Description**: Visual seating chart creator
- Already tested in critical path
- [ ] Toggle between Design and Assign modes
- [ ] Design mode: drag tables, add/remove, adjust capacity
- [ ] Assign mode: click seat → pick student
- [ ] Unassigned students in tray at bottom

### Tool 3: Participation
**Description**: Track engagement
- Already tested in critical path

### Tool 4: Schedule
**Description**: Shows weekly timetable
- [ ] Displays day × period grid
- [ ] Shows class schedule
- [ ] Can click periods for details

### Tool 5: Quick Poll
**Description**: Live poll with A/B/C/D options
- [ ] Question input field visible
- [ ] 4 answer option fields (A, B, C, D) visible
- [ ] Can enter poll question and options
- [ ] Buttons to submit votes
- [ ] Results display as counts or bars
- [ ] Fullscreen shows large vote buttons

### Tool 6: Timer & Stopwatch
**Description**: Classroom timing tool
- Already tested in critical path

### Tool 7: QR Code
**Description**: Generate QR codes for student access
- [ ] Text/URL input field
- [ ] QR code displays and updates as you type
- [ ] "Full screen" button opens large QR
- [ ] QR is scannable with phone camera
- [ ] "Copy text" copies to clipboard
- [ ] "Open link" works if URL entered

---

## File Management Tests

### Import Students
```
Goal: Test student import with AI fallback
Steps:
  1. Go to Classes → Select a class → "Import Students"
  2. Upload CSV with: Name, StudentID, Email, PhoneNumber
  3. Students appear in list
  4. If parsing fails, "Analyze with AI" button appears
  5. Click "Analyze with AI"
  6. Select file again
  7. AI parses and shows results
  8. Confirm → students added to class

Status: __ PASS __ FAIL __ PARTIAL
Notes: Test with messy CSV format to trigger AI fallback
```

### Import Grades (Exam Scores)
```
Goal: Test grade import with AI
Steps:
  1. Grades view → "Import" or "Analyze with AI"
  2. Upload file with exam scores (CSV or XLSX)
  3. If parsing works: grades populate spreadsheet
  4. If parsing fails: "Analyze with AI" appears
  5. Click AI button → parses data
  6. Confirm → grades added

Status: __ PASS __ FAIL __ PARTIAL
Notes:
```

### Import Calendar Events
```
Goal: Test calendar import with AI and error handling
Steps:
  1. Dashboard → Calendar section → "Import from file"
  2. Upload XLSX with events (Date, Title columns)
  3. Events imported as reminders
  4. Check reminders appear in "This Week's To-Dos"
  
  ERROR HANDLING:
  1. Try local or placeholder AI flows without configuring a frontend API key
  2. Should see helpful error message (not crash)
  3. Local features still work without API
  
Status: __ PASS __ FAIL __ PARTIAL
Notes: Test with both valid and invalid file formats
```

### Timetable Upload
```
Goal: Test timetable import and viewing
Steps:
  1. Dashboard → "Upload Timetable" or "Timetable" button
  2. Upload XLSX or image of timetable
  3. Click "View/Edit" on timetable
  4. Grid displays with:
     - Day names (Monday-Sunday) in header row
     - Time periods in first column
     - Class names in cells
     - Horizontal scroll works properly
  5. Can click cells to edit
  6. "Manage" button allows adding/removing
  7. Changes persist after save

Status: __ PASS __ FAIL __ PARTIAL
Notes: Period merging should consolidate consecutive periods into single row
```

### Export Data
```
Goal: Test exporting grades and other data
Steps:
  1. Grades view → "Export" button
  2. Choose format: CSV or XLSX
  3. File downloads
  4. Open file → data intact
  5. Test with attendance export
  6. Test with student roster export

Status: __ PASS __ FAIL __ PARTIAL
Notes:
```

---

## Data Persistence Tests

```
Goal: Verify data saves and persists correctly
Steps:
  1. Add a class → Hard refresh (Ctrl+Shift+R) → Class still there
  2. Add student to class → Refresh → Student persists
  3. Enter grade → Refresh → Grade saved
  4. Set participation points → Switch classes → Back to original class → Points preserved
  5. Create seating arrangement → Close browser tab → Reopen → Layout intact

Expected: Zero data loss on refresh
Status: __ PASS __ FAIL __ PARTIAL
Notes:
```

---

## Error Handling & Edge Cases

### Invalid Inputs
```
- [ ] Empty class name → Validation message
- [ ] Duplicate student names → Shows warning
- [ ] Non-numeric grades → Rejected or highlighted
- [ ] Negative participation → Prevented
- [ ] Non-numeric group size → Validation
```

### Network Issues
```
- [ ] Try to import with AI → Timeout → Shows error
- [ ] Quota exceeded error → Helpful message about API limit
- [ ] Connection error → Offers retry option
- [ ] Offline mode → App still works with cached data
```

### File Errors
```
- [ ] Corrupted CSV → Error with details
- [ ] Wrong file type → Appropriate error
- [ ] Very large file → Size limit or handling
- [ ] Empty file → Clear error message
```

---

## Responsive Design Check

Test at different viewport sizes:

```
DESKTOP (1920x1080):
- [ ] Full layout displays
- [ ] All buttons visible
- [ ] No overflow

TABLET (768x1024):
- [ ] 2-column layout
- [ ] Buttons stack as needed
- [ ] Scrolling works

MOBILE (375x812):
- [ ] Single column stack
- [ ] Hamburger menu works
- [ ] Touch targets adequate size
- [ ] Horizontal scroll for tables

LARGE SCREEN (2560x1440):
- [ ] Properly scaled
- [ ] No massive gaps

Resize Browser Window:
- [ ] Seating toolbar wraps buttons
- [ ] Timetable scrolls horizontally
- [ ] Modals readable
```

---

## Known Good Features (Already Verified)

✅ Google Sign-In authentication  
✅ Class management (add, edit, delete)  
✅ Student roster management  
✅ Attendance tracking  
✅ Grade entry and viewing  
✅ Participation points tracking  
✅ Seating designer with drag-and-drop  
✅ Random name picker  
✅ Group maker (all sizes)  
✅ Poll tool  
✅ Timetable upload and parsing  
✅ File import/export (CSV, XLSX)  
✅ Firebase data persistence  
✅ Responsive Material Design 3 UI  

---

## Recently Fixed (Watch For Regressions)

1. **Timer & Stopwatch Fullscreen**
   - Fixed: Wraps with SingleChildScrollView
   - Issue: Used to have layout overflow
   - Test: All buttons visible, centered, scrollable

2. **Participation Minus Button**
   - Fixed: Added Remove button to fullscreen view
   - Issue: Only had Add button
   - Test: Both Add and Remove work in fullscreen

3. **Seating Designer Toolbar**
   - Fixed: Changed from Row to Wrap layout
   - Issue: Buttons overflowed on small screens
   - Test: Buttons wrap to next line, no yellow/black stripes

4. **Seating Table Header**
   - Fixed: Split header into two rows (info and controls)
   - Issue: All elements didn't fit in one row
   - Test: No overflow when capacity buttons visible

5. **Timetable Day Headers**
   - Fixed: Shows day names (Monday-Sunday)
   - Issue: Empty header row
   - Test: Day names display correctly

6. **Error Messages**
   - Fixed: Better distinction between quota and connection errors
   - Test: Clear, helpful error messages

---

## Test Report Template

For each major feature, document:

```
**Feature**: [Name]
**Test Date**: [Date]
**Tester**: AI Agent
**Status**: ✅ PASS / ⚠️ PARTIAL / ❌ FAIL

**What Worked**:
- 

**What Didn't Work**:
- 

**Errors/Warnings**:
- 

**Severity**: Critical / High / Medium / Low
**Reproduction Steps**:
1.
2.
3.

**Screenshots** (if applicable):

**Notes**:
```

---

## Success Criteria

App is **PRODUCTION READY** when:
- ✅ All critical path tests PASS
- ✅ No console errors (browser F12)
- ✅ No render overflow (yellow/black stripes)
- ✅ Timer works flawlessly in fullscreen
- ✅ Data persists across page reloads
- ✅ All 8 tools work in normal and fullscreen
- ✅ File import/export works
- ✅ Responsive at all viewport sizes
- ✅ AI features gracefully degrade if API unavailable

---

## Troubleshooting

**If app doesn't load:**
- [ ] Check URL: http://localhost:57473/dashboard
- [ ] Hard refresh: Ctrl+Shift+R
- [ ] Check terminal for error messages

**If you get quota errors on AI:**
- [ ] This is expected (free tier limit)
- [ ] Use local features (they work perfectly)
- [ ] Do not test with a frontend OpenAI API key

**If data doesn't persist:**
- [ ] Check browser console (F12) for errors
- [ ] Check that you're waiting for save (there's usually a brief save indicator)

**If buttons overflow:**
- [ ] This was fixed recently
- [ ] If you see yellow/black stripes, screenshot and report
- [ ] Try hard refresh first

---

## Key File Locations (For Context)

- `lib/main.dart` - App setup and routing
- `lib/screens/teacher_dashboard_screen.dart` - All 8 tools (5000+ lines)
- `lib/screens/class_list_screen.dart` - Class management
- `lib/screens/student_list_screen.dart` - Student management
- AI imports - legacy frontend AI import service removed; future AI imports
  must use Firebase Functions/server-side secrets only
- `lib/services/file_import_service.dart` - File parsing

---

## Time Estimates

- **Critical Path Only**: 20-30 minutes
- **Critical Path + Tool Testing**: 45-60 minutes
- **Full Comprehensive Test**: 90-120 minutes

---

## Questions Before You Start

1. Should you test the current placeholder/local flows only? Do not configure OpenAI keys in Flutter/web.
2. Do you need to test on mobile devices or is desktop sufficient?
3. Should you test extremely large files (10MB+) for import?
4. Do you need to test concurrent user scenarios?

---

## Final Notes

- This is a **professional-grade app** at 95% completion
- Recent fixes specifically addressed UI issues you're testing
- The app works **with or without AI** - local fallbacks are strong
- Data is stored in **Firebase** - changes are persistent
- The codebase is **well-structured** with good error handling

**Your job is to verify everything works as described and nothing broke.**

Good luck! 🚀

---

**Last Updated**: January 13, 2026  
**Prompt Version**: 2.0 (Comprehensive with all recent fixes documented)
