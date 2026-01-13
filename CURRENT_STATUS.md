# Gradeflow - Current Status & Action Plan
**Date**: January 13, 2026

## ✅ WHAT'S WORKING
1. **Core Authentication** - Login/logout with Google works
2. **Class Management** - Create, view, edit classes
3. **Student Management** - Add, edit, delete students
4. **Gradebook** - Enter grades, calculate totals
5. **Export** - PDF export functionality
6. **Timetable Upload** - DOCX files with tables can be uploaded
7. **Timetable Viewer** - Edit timetable in a dialog (recently improved UI)
8. **Quick Links** - Manage attendance URL and custom links (fixed dialog)
9. **Desktop Layout** - Works well on wide screens (>720px)

## ❌ BROKEN/ISSUES

### Critical (Must Fix First)
1. **Responsive Layout Overflow** - Multiple layout overflows on narrow screens
   - Welcome card text overflow (24px)
   - Seating chart table overflow  
   - Timetable button placement inconsistent between narrow/wide layouts

2. **Calendar Import Errors** - User reports calendar upload doesn't work
   - Need to test XLSX/CSV calendar imports
   - Check error handling and user feedback

3. **OpenAI Integration** - Not connected
   - API key/endpoint need to be configured via environment variables
   - Currently checked but never set up
   - AI import features hidden when not configured (correct)

### Medium Priority
4. **Seating Chart Overflow** - Tables overflow when clicking "Assign"
   - Need to make seating grid responsive
   - Add horizontal scroll or better layout

5. **Timetable Button** - Missing from narrow layout Welcome card
   - Currently only in Quick Stats on narrow screens
   - Should be in Welcome card consistently

6. **Class Tools Overflow** - Minor overflow on very small screens
   - Already partially fixed with Flexible widgets
   - May need more refinement

### Low Priority  
7. **Unused Code** - `_promptEditAttendanceUrl` method not used
8. **Web Accessibility** - Missing viewport meta and lang attribute

## 🎯 ACTION PLAN (Priority Order)

### Phase 1: Fix Critical Responsive Issues (Today)
**Goal**: Make app work reliably on all screen sizes

1. **Fix Welcome Card Overflow**
   - Reduce font sizes appropriately for narrow screens
   - Add proper text overflow handling
   - Test on 500px, 720px, 1920px widths

2. **Fix Seating Chart**
   - Add SingleChildScrollView horizontally
   - Constrain table width properly
   - Test "Assign" button functionality

3. **Consolidate Timetable Button**
   - Put Timetable button in Welcome card for ALL layouts
   - Remove from Quick Stats entirely
   - Keep it simple and consistent

### Phase 2: Fix Calendar Import (Today)
**Goal**: Calendar uploads work without errors

1. **Test Current Calendar Import**
   - Try uploading test XLSX/CSV files
   - Document exact error messages
   - Check column detection logic

2. **Fix Calendar Import Issues**
   - Improve error messages
   - Add better column mapping
   - Handle edge cases

### Phase 3: OpenAI Setup (Later)
**Goal**: Document how to configure OpenAI

1. **Create Setup Instructions**
   - Document how to set OPENAI_PROXY_API_KEY
   - Document how to set OPENAI_PROXY_ENDPOINT
   - Add to README

2. **Test AI Import**
   - Once configured, test AI import feature
   - Verify error handling

### Phase 4: Polish (Later)
1. Remove unused code
2. Add web meta tags
3. Final responsive testing

## 🔍 TESTING CHECKLIST

### Must Test On
- [ ] Mobile (500px width)
- [ ] Tablet (768px width)  
- [ ] Desktop (1920px width)
- [ ] Chrome browser
- [ ] Resize behavior (shrink/expand window)

### Must Test Features
- [ ] Login/Logout
- [ ] Create class
- [ ] Add students
- [ ] Upload timetable (DOCX)
- [ ] View/Edit timetable
- [ ] Seating chart assign
- [ ] Calendar import (XLSX/CSV)
- [ ] Quick Links management
- [ ] Export to PDF

## 📝 NOTES
- Don't add new features until core issues fixed
- Keep changes minimal and focused
- Test after EACH change
- Prioritize making existing features work over adding new ones
- Responsive design is critical - must work on all devices
