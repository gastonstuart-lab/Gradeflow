# Gradeflow release checklist

## 0) Pre-flight
- [ ] `git status` is clean
- [ ] You’re on the branch you intend to release from
- [ ] You can sign in with Google (web + at least one device)

## 1) Automated validation (must be green)
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `npm run e2e`

## 2) Build outputs
- [ ] Web: `flutter build web --release`
- [ ] Android: `flutter build appbundle` (preferred) or `flutter build apk`

## 3) Firebase / Firestore
- [ ] Firebase project is selected (`firebase use`)
- [ ] `firestore.rules` match intended access control
- [ ] `firestore.indexes.json` deployed
- [ ] Hosting rewrites are correct for Flutter web routes
- [ ] Deploy: `firebase deploy`

## 4) Smoke test (2–5 minutes)
- [ ] Login
- [ ] Create/open a class
- [ ] Edit a score → verify it persists after refresh/restart
- [ ] Undo last score change
- [ ] Export (CSV/XLSX/PDF where applicable)

## 5) Post-deploy
- [ ] Verify production site loads and deep links work
- [ ] Verify Firestore writes are attributed to the signed-in user
