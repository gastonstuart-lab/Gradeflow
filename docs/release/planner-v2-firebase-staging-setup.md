# GradeFlow Planner V2 — Isolated Firebase Staging Setup

This is an engineering checklist, **not a claim that a staging Firebase project already exists**. The current source has production Firebase project `gradeflow-20260113`; staging MUST use a different Firebase project, and never access production user/student data.

## 1. Provision and restrict a dedicated project

Use a separate Firebase project with a different project ID, dedicated Web app, Firestore database, Firebase Authentication and appropriate App Check/security rules. Create **fictional test teacher accounts** and **fictional pupils** only. Never clone the live database or export real school records into staging. Restrict authorized auth domains and Firebase project members.

The plugin currently available to ChatGPT does not provide Firebase project provisioning. This is intentionally a documented external prerequisite—not something to guess or invent.

## 2. Configure the staging build

The authenticated app now selects its FirebaseOptions from `PlannerV2FirebaseConfig.currentPlatform`. Normal builds use the existing `DefaultFirebaseOptions`; V2 staging builds require **all** of these compile-time variables:

```text
GRADEFLOW_PLANNER_V2_STAGING=true
GRADEFLOW_STAGING_FIREBASE_PROJECT_ID=<staging project ID>
GRADEFLOW_STAGING_FIREBASE_API_KEY=<web app API key>
GRADEFLOW_STAGING_FIREBASE_APP_ID=<web app ID>
GRADEFLOW_STAGING_FIREBASE_SENDER_ID=<sender ID>
GRADEFLOW_STAGING_FIREBASE_AUTH_DOMAIN=<staging-id>.firebaseapp.com
GRADEFLOW_STAGING_FIREBASE_STORAGE_BUCKET=<staging bucket>
```

Use a secured CI deployment environment for build settings; keep any non-public secrets out of GitHub. Firebase web API key is not an admin secret, but should nevertheless be associated with restricted API access. **Never supply service-account credentials to the web application.**

Missing or mismatched values display a blocked staging screen before app providers or authentication begin. The staging flag never switches Firebase automatically to the production project.

## 3. Staging authentication protections

- No fallback to locally saved production/demo login if staging Firebase auth fails.
- No local account registration through the authenticated staging app.
- No local-to-Firestore automatic migration into staging.
- Firebase initialization failure blocks staging startup instead of silently loading local records.
- Real project security rules and role-isolation must still be audited; the client-side checks do not replace server-side authorization.

## 4. Acceptance checks before a staging URL

1. Confirm the staging project ID differs from `gradeflow-20260113`.
2. Verify Firebase Authentication initializes and accepts only authorized synthetic teacher accounts.
3. Verify Firestore access is denied for unauthorized users and cross-class records.
4. Create two fictional classes and distinct sets of synthetic students; ensure switching and editing one class cannot change the other.
5. Save chair and table positions, resizing, seat assignments, notes and grades; reload and confirm authorized persistence.
6. Test premium Home, Classroom, right sliding panel, picker, timer, random seating, zoom/fit, Present view and bottom navigation.
7. Verify offline/saving errors, logout, expired auth and inaccessible storage fail without showing old student data.
8. Perform desktop and Surface touch browser tests; compare visual screenshots and confirm no hidden canvas boundary.
9. Keep current independent synthetic preview Ready while tests run. Do not deploy to the live Firebase Hosting site until owner approval.

## 5. Rollout

Only after passing the real authenticated staging checks, prepare one consolidated release candidate (not a merge chain of individual drafts), with backups and a rollback path. Production rollout requires explicit owner approval.

## 6. Verified staging-only manual workflow

The **draft**, manual-only workflow is
`.github/workflows/gradeflow-online-staging-manual.yml`. It is a
**preparation artifact, not a live online staging site**. The workflow
deliberately cannot publish until all of these independently verified
conditions are met:

1. A real, separate Firebase project is created (never
   `gradeflow-20260113` or the local `demo-gradeflow-v2-staging`).
   Create its own Web app, Firebase Authentication, Firestore and Hosting
   site. Use fictional teacher/pupil records only.
2. Create GitHub Environment `gradeflow-staging` and add six web
   configuration values as environment secrets:
   `GRADEFLOW_STAGING_FIREBASE_API_KEY`,
   `GRADEFLOW_STAGING_FIREBASE_APP_ID`,
   `GRADEFLOW_STAGING_FIREBASE_SENDER_ID`,
   `GRADEFLOW_STAGING_FIREBASE_AUTH_DOMAIN`,
   `GRADEFLOW_STAGING_FIREBASE_STORAGE_BUCKET`, and
   `GRADEFLOW_STAGING_FIREBASE_SERVICE_ACCOUNT_JSON`.
   The last must contain an appropriately restricted, **staging-only**
   deploy service account. Never paste service-account JSON into a
   chat, source control, a website, or the Flutter build. Configure
   required environment deployment approval where available.
3. **Important GitHub activation limitation:** GitHub Actions requires
   a `workflow_dispatch` workflow file to exist on the repository's
   **default branch** before the manual Run workflow button appears.
   This integration branch deliberately does **not** write to `main`.
   The workflow therefore remains dormant until its *workflow-only*
   configuration is separately reviewed and promoted to the default
   branch. This does **not** authorize merging the GradeFlow application
   stack or deploying production.
4. Once activated and environment secrets are configured, run the
   workflow against the reviewed integration branch and enter the
   staging project ID explicitly. Start with `publish=false` to
   generate a reviewable build artifact without deploying.
5. Only after checking the build, choose `publish=true` manually. The
   workflow validates exact project identity, a matching deploy service
   account, canonical web app options, non-emulator release mode,
   `flutter analyze`, full `flutter test` and restrictive Firestore
   rules tests. It uses `firebase.staging.deploy.json` and passes an
   **explicit** `--project` argument to deploy only Hosting and
   staging Firestore rules. No Firebase Functions or production target
   are included.
6. Verify the hosted staging URL manually in desktop and touch browsers,
   with two fictional teacher accounts, two isolated classes, saved
   seating and grades, logout/session restoration, and an approved
   Classroom V2 appearance review.

The project-ID/configuration guard is
`staging-tests/online-project-guard.mjs` with standalone Node tests.
No stage can infer the intended project from `.firebaserc`, whose
default still points to production. A passing local emulator build is
not a substitute for the authenticated online staging acceptance tests.
