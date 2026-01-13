# GRADEFLOW COMPREHENSIVE TESTING PROMPT FOR CHATGPT

## 🎯 YOUR MISSION
Test a complete classroom management application called **Gradeflow**. Follow the test cases below systematically and report all findings.

## 🔗 ACCESS
**Live Web App**: https://gradeflow-20260113.web.app

Log in with any Google account. Demo data is pre-loaded with 3 sample classes and 25+ students.

---

## ✅ CRITICAL PATH TESTS (Do These First - 20 min)

### TEST 1: Login & Demo Data Load
```
Steps:
1. Go to [APP_URL]
2. Click Google Sign-In
3. Use any Google account to authenticate
4. Verify you land on the Teacher Dashboard
5. Check that 3 classes appear: Grade 10A, Grade 11B, Grade 12C
6. Verify dashboard shows class count, student count, stats

Expected: Dashboard loads with demo data visible
Status: PASS / FAIL
Issues/Notes:
```

### TEST 2: Timer & Stopwatch (Recently Fixed)
```
Steps:
1. Select any class from the dropdown
2. Click "Present on Projector" button
3. Click "Timer" tab
4. Verify layout:
   - Stopwatch section visible with large time display
   - Start/Pause buttons work
   - Reset button works
   - Countdown section visible
   - Start/Stop buttons work
   - ALL buttons visible (no cutoff or overlap)
5. Click Close button

CRITICAL: Watch for yellow/black striped overflow boxes

Status: PASS / FAIL
Issues/Notes:
```

### TEST 3: Participation Points
```
Steps:
NORMAL VIEW:
1. Click "Participation" tool
2. See student list with points (should start at 0)
3. Click "+" button → points increase
4. Click "-" button → points decrease (cannot go below 0)

FULLSCREEN VIEW:
1. Click "Present on Projector"
2. Click "Participation" tab
3. Large layout with students visible
4. "Add" button increases points
5. "Remove" button decreases points (both visible and functional)

Status: PASS / FAIL
Issues/Notes:
```

### TEST 4: Seating Designer (Recently Fixed)
```
Steps:
1. Click "Seating" tool
2. Verify toolbar at top with buttons:
   - Seats per table dropdown
   - Add table button
   - Randomize button
   - Clear assignments button
   - Auto-arrange button
   - Clear layout button
   
   CRITICAL: Buttons should NOT overflow or be cut off
   
3. Click "Add table" → table appears on canvas
4. Drag table around → moves smoothly
5. Click "Randomize" → students assigned to seats
6. Toggle "Design" vs "Assign" mode

Status: PASS / FAIL
Issues/Notes:
```

### TEST 5: Grades Entry
```
Steps:
1. Select a class
2. Find and click Grades/Grading interface
3. See spreadsheet-like grid (students × assignments)
4. Click a cell and enter a number (e.g., 85)
5. Grade should auto-save
6. Refresh the page (Ctrl+R)
7. Verify grade is still there

Expected: Grade persists after refresh
Status: PASS / FAIL
Issues/Notes:
```

### TEST 6: Attendance Marking
```
Steps:
1. Select class
2. Click Attendance tool
3. See student list with checkboxes
4. Check a box to mark present
5. Uncheck a box to mark absent
6. Click Save or observe auto-save
7. Refresh page
8. Verify attendance is saved

Expected: Attendance persists
Status: PASS / FAIL
Issues/Notes:
```

---

## 🔧 ALL 8 CLASS TOOLS (Do After Critical Path - 30 min)

### Tool 0: Name Picker
```
Description: Random student selector for cold calling

Test Steps:
- Click "Name Picker"
- Click "Pick Random" button
- Verify a student name displays
- Test in fullscreen mode ("Present on Projector")
- Verify name displays large and clearly

Expected: Random student selected from current class
Status: PASS / FAIL
Issues/Notes:
```

### Tool 1: Group Maker
```
Description: Create groups of specified size

Test Steps:
- Click "Group Maker"
- Select group size from dropdown (try 2, then 4)
- Click "Generate Groups"
- Verify groups display with student names
- Click "Randomize" to regenerate
- Click "Pairs" to create groups of 2
- Test in fullscreen mode

Expected: Groups display correctly, students distributed evenly
Status: PASS / FAIL
Issues/Notes:
```

### Tool 2: Seating Designer
```
Description: Visual seating arrangement tool

Already tested in Critical Path #4
Additional checks:
- [ ] Can drag tables with the drag handle
- [ ] Can adjust table capacity (+ and - buttons)
- [ ] Can delete tables
- [ ] Unassigned students shown in tray at bottom
- [ ] Design mode vs Assign mode toggle works

Status: PASS / FAIL
Issues/Notes:
```

### Tool 3: Participation
```
Description: Track student engagement

Already tested in Critical Path #3
Additional checks:
- [ ] "Cold Call" button picks random student
- [ ] "Reset" button clears all points
- [ ] Points persist when switching classes

Status: PASS / FAIL
Issues/Notes:
```

### Tool 4: Schedule
```
Description: Weekly timetable display

Test Steps:
- Click "Schedule" tool
- Verify grid displays with days and time periods
- Check that it shows the timetable
- Click periods to see details (if available)

Expected: Schedule grid displays properly
Status: PASS / FAIL
Issues/Notes:
```

### Tool 5: Quick Poll
```
Description: Live A/B/C/D poll

Test Steps:
- Click "Quick Poll"
- Enter a question in the question field
- Enter answer options (A, B, C, D)
- Click on answer buttons to vote
- Verify vote counts increase
- Test in fullscreen mode

Expected: Poll question and options visible, voting works
Status: PASS / FAIL
Issues/Notes:
```

### Tool 6: Timer & Stopwatch
```
Description: Classroom timing tool

Already tested in Critical Path #2
Additional checks:
- [ ] Timer runs continuously for several minutes
- [ ] Pause and resume maintains correct time
- [ ] Can reset to zero
- [ ] Countdown timer with custom duration works
- [ ] No performance issues or freezing

Status: PASS / FAIL
Issues/Notes:
```

### Tool 7: QR Code
```
Description: Generate QR codes for student access

Test Steps:
- Click "QR Code"
- Enter a URL (e.g., https://google.com)
- Verify QR code generates
- Update the text/URL
- Verify QR code updates
- Click "Full screen" button
- Verify QR code displays large and clear
- Try scanning with phone camera (optional)

Expected: QR code generates and updates in real-time
Status: PASS / FAIL
Issues/Notes:
```

---

## 📁 FILE OPERATIONS (15 min)

### Test Student Import
```
Steps:
1. Go to Classes → Select a class → Click "Import Students"
2. Upload a CSV with columns: Name, StudentID, Email
3. Verify students appear in list
4. Check that importing works
5. If available, test "Analyze with AI" fallback

Expected: Students successfully imported
Status: PASS / FAIL
Issues/Notes:
```

### Test Grade Export
```
Steps:
1. Enter some grades in the Grades view
2. Click "Export" button
3. Choose CSV format
4. Verify file downloads
5. Open file and check data integrity

Expected: Grades export correctly with headers
Status: PASS / FAIL
Issues/Notes:
```

### Test Timetable Upload
```
Steps:
1. Dashboard → Click "Upload Timetable" or "Timetable" button
2. Upload an XLSX file with a timetable grid
3. Click "View/Edit" on the uploaded timetable
4. Verify:
   - Day names display in header (Mon, Tue, etc.)
   - Time periods display in rows
   - Class names show in cells
   - Horizontal scrolling works
   - Can edit cells

Expected: Timetable displays and is editable
Status: PASS / FAIL
Issues/Notes:
```

---

## 💾 DATA PERSISTENCE (10 min)

```
Tests:
1. Add a class → Refresh page (Ctrl+R) → Class still exists?
2. Add student → Refresh → Student still there?
3. Enter grade → Refresh → Grade persists?
4. Set participation points → Switch classes → Back → Points saved?
5. Create seating arrangement → Refresh → Layout intact?

Expected: Zero data loss on refresh
Status: PASS / FAIL
Issues/Notes:
```

---

## 📱 RESPONSIVE DESIGN (10 min)

```
Test at Different Sizes:

Desktop (1920x1080):
- [ ] All content visible
- [ ] No overflow
- [ ] Buttons accessible

Tablet (resize to 768px width):
- [ ] Layout adapts
- [ ] Buttons still clickable
- [ ] Text readable

Mobile (resize to 375px width):
- [ ] Single column layout
- [ ] Touch targets adequate
- [ ] Horizontal scroll for tables works

Status: PASS / FAIL
Issues/Notes:
```

---

## ⚠️ ERROR HANDLING

```
Test These Scenarios:

1. Empty Input:
   - Try to create class with no name
   - Try to import with no file selected
   Expected: Validation message
   Status: PASS / FAIL

2. Invalid Data:
   - Try to enter non-numeric grade
   - Try to create negative participation points
   Expected: Validation or rejection
   Status: PASS / FAIL

3. Network Issues (optional):
   - Disable internet / reload page
   Expected: Graceful degradation or offline message
   Status: PASS / FAIL

Issues/Notes:
```

---

## 🎯 RED FLAGS - If You See Any Of These, Report Them

- ❌ Yellow and black striped boxes (layout overflow)
- ❌ Buttons cut off or overlapping text
- ❌ Missing elements on page
- ❌ Data lost after refresh
- ❌ Buttons unresponsive or slow
- ❌ Unhelpful error messages
- ❌ Layout breaking when you resize window
- ❌ Console errors (open F12 to check)

---

## 📊 TEST SUMMARY TEMPLATE

When complete, provide a summary:

```
GRADEFLOW TEST REPORT
Date: [TODAY]
Tester: [YOUR_NAME]

CRITICAL PATH RESULTS:
- Login & Demo Data: PASS / FAIL
- Timer/Stopwatch: PASS / FAIL
- Participation: PASS / FAIL
- Seating Designer: PASS / FAIL
- Grades: PASS / FAIL
- Attendance: PASS / FAIL

TOOL RESULTS:
- Tool 0 (Name Picker): PASS / FAIL
- Tool 1 (Groups): PASS / FAIL
- Tool 2 (Seating): PASS / FAIL
- Tool 3 (Participation): PASS / FAIL
- Tool 4 (Schedule): PASS / FAIL
- Tool 5 (Poll): PASS / FAIL
- Tool 6 (Timer): PASS / FAIL
- Tool 7 (QR): PASS / FAIL

FILE OPERATIONS: PASS / FAIL
DATA PERSISTENCE: PASS / FAIL
RESPONSIVE DESIGN: PASS / FAIL
ERROR HANDLING: PASS / FAIL

CRITICAL ISSUES (Blocks Production):
1. [Issue]
2. [Issue]

HIGH PRIORITY ISSUES (Affects UX):
1. [Issue]
2. [Issue]

MEDIUM PRIORITY (Nice to Fix):
1. [Issue]
2. [Issue]

OVERALL STATUS: READY FOR PRODUCTION / NEEDS FIXES
```

---

## 📝 NOTES

- **Demo Data**: App loads with 3 classes, 25+ students, and sample grades
- **No Setup Needed**: Just login and start testing
- **Time Budget**: 45-90 minutes for full test
- **Critical First**: Do Critical Path tests first (20 min), then extended tests if time allows
- **Error Reporting**: Be specific - exact steps, what you expected, what you saw

**Let's make this quick and thorough! Start with Critical Path tests.**
