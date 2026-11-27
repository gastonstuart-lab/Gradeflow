# Release 1 synthetic preservation fixtures

Run from the repository root:

```powershell
flutter test --no-pub docs/fixtures/release1/preservation_test.dart --reporter expanded
```

This executable fixture uses the **existing** calculation, export, grading and local repository code with `SharedPreferences.setMockInitialValues`. It does not initialize Firebase, log in, use a real preferences store, implement a period repository, or change application behavior. All identities are synthetic. The snapshot is a JSON copy used to validate the proposed data contents, not an archive implementation. Assertions documenting unsafe baseline behavior are intentionally passing characterization checks, not claims that those risks are fixed.

Fixtures cover absent versus null scores, non-100 maxima, unequal weights, every aggregation method, inactive assessments, absent exams, historical labels, 20 editable proposed defaults, local legacy precedence, mock backup/restore and 1,000 synthetic students. XLSX checks decode and compare cell contents and types; ZIP bytes can differ between encodes. No existing focused XLSX or repository test file was found under `test/`; these fixtures supply that baseline evidence. Future rollover, rules, concurrency and browser tests remain acceptance gates in the design report.
