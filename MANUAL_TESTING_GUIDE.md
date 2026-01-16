# Gradeflow - Comprehensive Testing Guide
**Date:** January 16, 2026  
**Status:** Ready for Manual Testing  

## Prerequisites

### 1. Environment Setup
```powershell
# Set OpenAI API key (if testing AI features)
Set-Item -Path Env:OPENAI_PROXY_API_KEY -Value "sk-your-actual-key"
Set-Item -Path Env:OPENAI_PROXY_ENDPOINT -Value "https://api.openai.com/v1"

# Run with AI config
flutter run -d chrome
```

### 2. Test Browsers
- ✅ Chrome (latest)
- ✅ Firefox (latest)
- ✅ Safari (if on Mac)

---

## Section 1: Authentication & Basic Flow

### Test 1.1: Demo Account Login
**Expected:** Quick login to dashboard
1. Open https://gradeflow-20260113.web.app
2. Click "Try Demo Account"
3. Should see dashboard with teacher tools

**Pass/Fail:** ________

### Test 1.2: URL Routing
**Expected:** Direct URL navigation works
1. Open https://gradeflow-20260113.web.app/#/dashboard
2. Should load dashboard (not 404)
3. Navigate to https://gradeflow-20260113.web.app/#/classes
4. Should load classes list

**Pass/Fail:** ________
**Notes:** ________________________________________

---

## Section 2: Grade Management

### Test 2.1: Quick Gradebook Editing
**Expected:** Can edit grades and undo
1. Dashboard → Select "Grade 10A"
2. Click "Gradebook"
3. Select "Homework" → "Homework 1"
4. Click "Quick grade" on first student
5. Adjust slider to score 75
6. Click "Done"
7. Go back and re-enter gradebook
8. Verify score persisted as 75

**Pass/Fail:** ________
**Notes:** ________________________________________

### Test 2.2: Undo Functionality
**Expected:** Undo reverts grade changes
1. In gradebook, click "Undo last score change"
2. Re-enter quick grade
3. Verify score reverted to original

**Pass/Fail:** ________

---

## Section 3: Export & Download

### Test 3.1: Grade Export CSV (Chrome)
**Expected:** CSV downloads automatically
1. Dashboard → Grade 10A → Gradebook
2. Look for "Export" or download button
3. Click and wait for download
4. Check ~/Downloads for Grade10A_Grades.csv
5. Open F12 Console - check for errors

**Browser:** Chrome  
**Pass/Fail:** ________  
**Console Errors:** ________________________________________

### Test 3.2: Grade Export CSV (Firefox)
Same as 3.1 but in Firefox

**Browser:** Firefox  
**Pass/Fail:** ________  
**Console Errors:** ________________________________________

### Test 3.3: Grade Export CSV (Safari)
Same as 3.1 but in Safari (Mac only)

**Browser:** Safari  
**Pass/Fail:** ________  
**Console Errors:** ________________________________________

---

## Section 4: File Imports

### Test 4.1: CSV Student Import
**Expected:** Can import CSV file
1. Go to Grade 10A → Students tab
2. Click "Import" button
3. Select test file: `test_roster.csv` (see below for format)
4. Should show preview with valid/invalid students
5. Click "Import"
6. Verify students appear in list

**Test File:**
```csv
Name,Student ID,Email
Test Student,TEST-001,test@example.com
Jane Doe,TEST-002,jane@example.com
```

**Pass/Fail:** ________
**Issues:** ________________________________________

### Test 4.2: Tab-Separated File Import
**Expected:** Handles TSV format
1. Create file with tab-separated columns
2. Try to import
3. Should auto-detect TSV and import

**Pass/Fail:** ________

### Test 4.3: Wrong File Type Detection
**Expected:** Shows helpful error for calendar file
1. Try to import a calendar file (XLSX/Calendar format)
2. Should show: "This looks like a school calendar..."
3. Should NOT crash

**Pass/Fail:** ________

---

## Section 5: AI Features (If API Key Configured)

### Test 5.1: AI Exam Score Import
**Expected:** AI can parse messy exam file
1. Go to Grade 10A → Exam Scores
2. Create messy test file with confusing format
3. Try to import
4. If local parse fails, click "Analyze with AI"
5. AI should extract scores and show preview
6. Confirm and import

**Pass/Fail:** ________
**AI Response Time:** ________ seconds
**Issues:** ________________________________________

### Test 5.2: AI Calendar Import
**Expected:** AI interprets calendar events
1. Go to Dashboard → Calendar
2. Create test calendar file (XLSX or CSV)
3. Try to import
4. If fails, click "Analyze with AI"
5. AI should extract dates and events

**Pass/Fail:** ________
**Issues:** ________________________________________

### Test 5.3: AI Student Import
**Expected:** AI can infer student columns
1. Create CSV with unusual column names: StudentName, StudentCode, ContactEmail
2. Try to import to students
3. Should match columns (Student Name → Name, etc.)

**Pass/Fail:** ________
**Issues:** ________________________________________

---

## Section 6: Navigation & UX

### Test 6.1: Tab Scrolling
**Expected:** Can find Schedule tool via scroll
1. Go to Dashboard
2. Look at tool tabs (top of screen)
3. Should see scrollbar indicator
4. Scroll right to find "Schedule" tab
5. Click Schedule

**Pass/Fail:** ________
**Scrollbar Visible:** ________ (Yes/No)

### Test 6.2: Back Button Navigation
**Expected:** Back button works correctly
1. Navigate: Dashboard → Classes → Grade 10A → Gradebook
2. Click back button 2 times
3. Should be back at Classes view

**Pass/Fail:** ________

---

## Section 7: Error Scenarios

### Test 7.1: Invalid CSV (No Headers)
**Expected:** Shows error with diagnostics
1. Create CSV with no headers
2. Try to import
3. Should show diagnostics dialog

**Pass/Fail:** ________
**Error Message:** ________________________________________

### Test 7.2: Empty File
**Expected:** Shows "No data found"
1. Create empty CSV file
2. Try to import
3. Should show helpful error

**Pass/Fail:** ________

### Test 7.3: Network Offline (AI Only)
**Expected:** Shows network error
1. Disable internet
2. Try AI import
3. Should show "Network error" (not crash)

**Pass/Fail:** ________
**Error Message:** ________________________________________

---

## Section 8: Performance

### Test 8.1: Dashboard Load Time
**Expected:** < 3 seconds
1. Open dashboard
2. Note load time
3. Time: ________ seconds

**Pass/Fail:** ________

### Test 8.2: Gradebook Load Time
**Expected:** < 2 seconds for 50 students
1. Open Grade 10A Gradebook
2. Note load time
3. Time: ________ seconds

**Pass/Fail:** ________

### Test 8.3: Export Generation
**Expected:** < 5 seconds for CSV
1. Click export
2. Note time to file download
3. Time: ________ seconds

**Pass/Fail:** ________

---

## Section 9: Console & Errors

### Test 9.1: No Critical Console Errors
1. Open F12 DevTools → Console
2. Navigate through app (5 screens)
3. Check for red errors (ignore warnings/404s)

**Critical Errors Found:** ________  
**Error Messages:** ________________________________________

### Test 9.2: Network Tab (API Calls)
1. Open DevTools → Network
2. Do actions: login, navigate, export, import
3. Check all API calls return success (200/201)

**Failed Requests:** ________  
**Details:** ________________________________________

---

## Section 10: Cross-Browser Consistency

| Feature | Chrome | Firefox | Safari |
|---------|--------|---------|--------|
| Login | ✓/✗ | ✓/✗ | ✓/✗ |
| Gradebook Edit | ✓/✗ | ✓/✗ | ✓/✗ |
| Export Download | ✓/✗ | ✓/✗ | ✓/✗ |
| CSV Import | ✓/✗ | ✓/✗ | ✓/✗ |
| AI Features | ✓/✗ | ✓/✗ | ✓/✗ |
| Tab Scroll | ✓/✗ | ✓/✗ | ✓/✗ |
| No Console Errors | ✓/✗ | ✓/✗ | ✓/✗ |

---

## Section 11: Summary

### Overall Status
- **Pass:** ____ / 30 tests
- **Fail:** ____ / 30 tests
- **Skip:** ____ / 30 tests

### Critical Issues (Blockers)
1. ________________________________________
2. ________________________________________
3. ________________________________________

### Minor Issues (Polish)
1. ________________________________________
2. ________________________________________

### Ready for Production?
- [ ] Yes - all tests pass, no blockers
- [ ] No - see critical issues above
- [ ] Partial - some features work, some need fixes

---

## Tester Information
**Date:** ________________  
**Tester Name:** ________________  
**Browser/OS:** ________________  
**Email:** ________________  

---

## Sign-Off
- [ ] All tests completed
- [ ] Results documented
- [ ] Issues reported
- [ ] Ready for developer review
