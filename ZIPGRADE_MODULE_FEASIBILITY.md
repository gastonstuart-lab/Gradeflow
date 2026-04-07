# ZipGrade Module Feasibility

## Short Answer

Yes, a GradeFlow assessment scanning / quick marking module is feasible, but it should not be the next large implementation unless the product first tightens assessment structure, camera capture reliability, and teacher review workflows.

## Recommended Product Position

GradeFlow should not try to become a literal ZipGrade clone.

The stronger product move is:

- build a `quick marking and paper capture` module inside the broader teacher operating system
- anchor it around existing class, exam, and gradebook data
- treat scanning as one input path into assessment workflows, not as a disconnected standalone app

## Best Integration Point In GradeFlow

The cleanest future integration point is the existing class assessment stack:

- `ExamInputScreen`
- final exam / score services
- gradebook and export flows

That means scanning should likely live as a new assessment tool reachable from:

- class detail assessment/exam flows
- gradebook import/marking surfaces
- possibly a dashboard quick action for active classes

It should not be attached to the live dashboard rail or built as a dashboard-first feature.

## What Would Be Required

### 1. Structured Answer Sheet Model

GradeFlow would need a strong answer-sheet domain model:

- response grid definition
- question count and answer key
- multiple form variants
- scoring rules
- confidence / ambiguity flags

### 2. Reliable Capture Pipeline

For classroom use, scanning needs:

- camera capture on mobile/tablet
- perspective correction
- lighting normalization
- bubble detection / mark detection
- fallback manual correction flow

This is the hardest technical layer.

### 3. Teacher Review Workflow

A world-class version must include:

- confidence warnings
- side-by-side paper preview and interpreted answers
- one-tap correction for ambiguous detections
- batch review before publishing scores

Without that review layer, the feature becomes fragile and trust-eroding.

### 4. Assessment Data Integration

Scanned results should map directly into:

- class roster matching
- exam records
- score services
- export pipelines

That integration work is where GradeFlow can outperform a standalone scanner.

## What Should Come First

Before building scanning, GradeFlow should first strengthen:

1. exam / assessment object modeling
2. score review workflows
3. roster-to-assessment matching reliability
4. mobile/tablet capture UX standards

If those foundations are weak, scanning will create operational debt quickly.

## Technical Risks

- Camera capture quality varies widely across devices and lighting conditions.
- Bubble interpretation accuracy can create trust problems if confidence and correction tooling are weak.
- Web support is much less natural than native mobile/tablet capture.
- OCR / CV dependencies may increase package weight, platform complexity, and maintenance cost.

## Recommended Future Approach

Phase 1:

- create assessment template and answer-key models
- add manual quick-marking and batch review workflow

Phase 2:

- add photo capture import for answer sheets
- build confidence-scored detection with manual correction

Phase 3:

- add higher-speed batch scanning and analytics

## Bottom Line

GradeFlow should eventually have a quick marking / scanning module, but only after the assessment workflow itself is strengthened. The right long-term move is an integrated assessment capture system inside GradeFlow's class and gradebook architecture, not a rushed standalone scanner bolted onto the dashboard.
