# GradeFlow Slice 3 synthetic preview

Built from the application source at commit `0aa095296c042f202f725d14b743d01dc20160fe` in GradeFlow draft PR #185. The preview seeds 12 fictional students, an active December period, and a sealed November period. It uses Firebase web libraries and local Auth and Firestore emulators for the demo project.

Extract the artifact. Use Java 21, Firebase CLI 14.27.0, Python 3, and Chrome or Chromium. Allow network access for the Firebase web SDK and the emulator's first-run download.

Run these commands in separate terminals from the extracted directory on Linux x86-64.

```sh
firebase emulators:start --only firestore,auth --project demo-gradeflow-periods --config emulator/firebase.json
```

```sh
chmod +x coordinator-linux-x64
GRADEFLOW_COORDINATOR_PROJECT=demo-gradeflow-periods ./coordinator-linux-x64
```

```sh
python3 -m http.server 7357 --bind 127.0.0.1 --directory web
```

Open http://127.0.0.1:7357/. On other platforms, run the coordinator from a checkout of the exact commit with Flutter 3.38.7 and its bundled Dart. Run `flutter pub get --enforce-lockfile` in that checkout, set `GRADEFLOW_COORDINATOR_PROJECT` to `demo-gradeflow-periods`, and run `dart run tool/grading_period_coordinator.dart`. Serve the extracted web build as above.

Edit an assessment score in December and reload to check persistence. Choose November from the Grading period menu to view archived grades or download Historical Excel. Choose December again and start a new period to see the default assessments. A fresh emulator session with no imported data starts with the original fixture.
