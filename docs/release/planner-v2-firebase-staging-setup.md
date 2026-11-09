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
