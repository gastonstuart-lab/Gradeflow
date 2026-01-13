# Remaining Issues - Testing Checklist & Guidance

**Date:** January 13, 2026  
**Status:** Ready for User Testing

---

## 1. Grade Export Download Testing

### What to Test:
Download a CSV export of grades on three browsers

### ✅ Code Verification:
- **File:** [lib/screens/export_screen.dart](lib/screens/export_screen.dart#L870-L920)
- **Method:** `_downloadBytesWeb()`
- **Key Details:**
  - Creates Blob with proper MIME type
  - Attaches anchor element to DOM (required for download)
  - Clicks anchor to trigger download
  - **1-second delay** before revoking blob URL (essential for Chrome/Firefox/Safari)
  - Proper error handling with debug logs

### Test Procedure:

#### Chrome:
1. Open app at https://gradeflow-20260113.web.app
2. Login (Demo Account)
3. Select a class → Gradebook tab
4. Click "Export as CSV"
5. Confirm file downloads to ~/Downloads
6. Open F12 Developer Tools → Console
7. Expected: No errors (only "Download triggered successfully..." logs)

#### Firefox:
1. Same steps as Chrome
2. Firefox may show download notification (normal)
3. Check Console for errors

#### Safari:
1. Same steps
2. Safari may require "Allow pop-ups" for downloads
3. Check Console (View → Developer → Show JavaScript Console)

### Success Criteria:
✅ CSV file downloads automatically in all browsers  
✅ No error messages in console  
✅ File is valid CSV (can open in Excel)  
✅ Filename is correct (e.g., "Grade10A_Grades.csv")

### If Download Fails:
1. **Check Console Errors** - Screenshot and share any errors
2. **Check Pop-up Blocker** - Temporarily disable
3. **Check Downloads Folder** - May be redirected
4. **Clear Browser Cache** - Ctrl+Shift+Delete (Chrome/Firefox)

---

## 2. Google Sign-In Investigation

### What to Check:
Firebase console OAuth configuration

### Step 1: Verify Authorized Domains

1. Go to: https://console.firebase.google.com
2. Select Project: **gradeflow-20260113**
3. Navigate: **Authentication** → **Settings**
4. Look for **"Authorized domains"** section
5. Check that `gradeflow-20260113.web.app` is in the list

**Expected State:**
```
Authorized domains:
- gradeflow-20260113.web.app
- localhost (for local testing)
```

### Step 2: Enable Google Sign-In Method

1. Still in Authentication section
2. Click **"Sign-in method"** tab
3. Look for **"Google"** provider
4. Verify it's **"Enabled"** (toggle is ON)
5. If disabled, click it and enable

**Expected State:**
```
Google ✓ Enabled
```

### Step 3: Verify Google Cloud Console

1. Go to: https://console.cloud.google.com
2. Select Project: **Gradeflow** (should match Firebase project)
3. Navigate: **APIs & Services** → **OAuth 2.0 Client IDs**
4. Look for Web application client
5. Check **Authorized JavaScript origins** includes:
   - `https://gradeflow-20260113.web.app`
   - `http://localhost:8080` (for local testing)

### Step 4: Test the Sign-In

1. Open https://gradeflow-20260113.web.app in incognito/private window
2. Click **"Sign in with Google"** button
3. Complete Google sign-in flow
4. Expected: Redirected to dashboard

### If Sign-In Still Fails:

1. **Capture Error Message:**
   - Right-click on error → Inspect Element (F12)
   - Look for error text
   - Screenshot the error

2. **Check Console Logs:**
   - F12 → Console tab
   - Look for messages from `[GSI_LOGGER]` or similar
   - Screenshot any errors

3. **Common Issues:**
   - Domain not in authorized list → Add it in Firebase
   - OAuth consent screen not configured → Configure in Google Cloud
   - Pop-up blocker blocking sign-in window → Disable temporarily

---

## 3. CSV Import Testing

### Test Files to Create:

#### Test 1: Simple Roster (UTF-8)
```
Name,Student ID,Email
John Smith,12345,john@example.com
Alice Johnson,12346,alice@example.com
```
**Expected:** ✅ Imports successfully

#### Test 2: With UTF-8 BOM
Save above as "UTF-8 with BOM" encoding in any text editor
**Expected:** ✅ BOM stripped, imports successfully

#### Test 3: Tab-Separated
```
Name	Student ID	Email
John Smith	12345	john@example.com
```
**Expected:** ✅ Delimiter auto-detected as TAB

#### Test 4: Column Name Variations
```
StudentName,Student_ID,Contact_Email
John Smith,12345,john@example.com
```
**Expected:** ✅ Columns matched correctly despite naming variations

#### Test 5: Wrong File Type
Upload your calendar file (2025-F Calendar.xlsx)
**Expected:** ✅ Shows error: "This looks like a school calendar. Import in Teacher Dashboard..."

### Success Criteria:
✅ All valid CSV files import  
✅ Column names matched despite variations  
✅ Wrong file types show helpful guidance  
✅ No "Could not read this file" errors for valid data  
✅ UTF-8 BOM handled transparently

---

## 4. URL Routing Verification

### What to Test:
App stability when URL changes

### ✅ Verification (Already Complete)
**File:** [firebase.json](firebase.json#L10-L17)

```json
"rewrites": [
  {
    "source": "**",
    "destination": "/index.html"
  }
]
```

**Result:** ✅ All URLs route correctly to /index.html for SPA routing

### Manual Test (Optional):
1. Open https://gradeflow-20260113.web.app/dashboard
2. Should show dashboard (not 404)
3. Click around and navigate
4. Refresh page (Ctrl+R) while on any route
5. Expected: Should stay on that page (not redirect to home)

**Success Criteria:**
✅ Direct navigation to any route works  
✅ Page refresh doesn't lose state  
✅ Browser back/forward work correctly

---

## 5. Schedule Tool Discoverability

### What to Test:
Can users easily find Schedule tool?

### ✅ Improvement Already Made:
**File:** [lib/screens/teacher_dashboard_screen.dart](lib/screens/teacher_dashboard_screen.dart#L1191-L1206)

- Added visible **Scrollbar** with `thumbVisibility: true`
- Users can see scroll indicator on tool tabs
- Schedule is 5th tab (visible after scroll)
- QR Code is 8th tab (visible with scrollbar)

### Test Procedure:
1. Open app → Teacher Dashboard
2. Look at tool tabs row
3. See small scrollbar indicator on right side
4. Scroll horizontally to find Schedule tab
5. Click Schedule → See "Upload" button

**Success Criteria:**
✅ Scrollbar is visible (dark indicator on right)  
✅ Users understand more tabs exist  
✅ Schedule tool is easily accessible  
✅ Upload button is visible in Schedule tab

---

## Summary of Ready-to-Test Features

| Feature | Status | Test Required | Notes |
|---------|--------|----------------|-------|
| Smart File Import | ✅ Deployed | ✅ Manual test | Detects calendar/timetable/exam/roster |
| Tab Scrollbar | ✅ Deployed | ✅ Visual check | Makes QR/Schedule discoverable |
| URL Routing | ✅ Verified | ⏳ Optional | Firebase config correct |
| CSV Robustness | ✅ Enhanced | ✅ CSV test | UTF-8 BOM, fuzzy matching added |
| Export Download | ✅ Deployed | ✅ Chrome/FF/Safari | 1-second delay implemented |
| Google Sign-In | ⏳ Investigate | ✅ Firebase check | Needs domain verification |

---

## How to Share Test Results

When testing, please provide:

1. **For CSV Import:**
   - File format tested (Excel, Google Sheets, etc.)
   - Column names used
   - Error message (if any)
   - Screenshot of result

2. **For Export Download:**
   - Browser name and version
   - Whether file downloaded
   - Console error messages (if any)

3. **For Google Sign-In:**
   - Error message shown to user
   - Browser console errors
   - Screenshot of error

4. **For URL Routing:**
   - Any 404 errors?
   - Does refresh maintain state?

This information helps narrow down the issue and implement a precise fix.

---

## Next Steps After Testing

1. **Collect all test results** from different browsers/devices
2. **Identify any failing scenarios** with specific error messages
3. **Share stack traces** from browser console (F12)
4. **I'll implement targeted fixes** for any issues found
5. **Deploy updated version** and re-test

**Timeline:** Each fix typically takes 10-15 minutes + 1 minute deployment
