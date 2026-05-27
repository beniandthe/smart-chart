# Smart Chart Sprint 61 Raster Render Handoff Polish

Status: active evidence audit
Date: 2026-05-27
Source of truth: `docs/smart-chart-sprint-source-of-truth.md`

## Goal

Keep the writing-to-render handoff feeling immediate without premature rendering, unnecessary raster work, or a speculative renderer rewrite.

## Evidence Gathered

Sprint 61 started by checking the current timing and render-handoff surfaces before changing behavior:

- `LeadSheetChordInkRecognitionScheduling` owns the idle/continuation wait policy.
- `ChordInkRecognitionTiming` captures requested delay, idle time, recognition time, and total scheduled-to-recognition-finished time.
- `EditorView.commitChordInkCandidate` measures structured chart commit mutation time.
- `EditorView.recordPendingChordRenderHandoff` measures the time from commit observation to SwiftUI chart-change/render handoff and replaces the latest matching diagnostic row.
- `Chart.commitRecognizedChordInk` remains the model-level commit contract: append structured `ChordEvent`, store source ink evidence, and clear active chord ink only after a successful append.
- `scripts/audit_chord_entry_diagnostics.py` can print persisted timing evidence.
- `scripts/analyze_chord_timing_logs.py` can classify console timing logs by scheduler, recognition, proposal, commit, render handoff, OCR, and trust route.

## Current Finding

The strongest existing timing evidence still comes from Sprint 50:

| Case | Scheduled-to-finished | Recognition | Render handoff | Classification |
| --- | ---: | ---: | ---: | --- |
| `C` | `405ms` | `0ms` | `7ms` | root-continuation scheduler wait dominated |
| `G/B` | `782ms` | `2ms` | `13ms` | idle scheduler wait dominated |
| `Db7(b9)` | `813ms` | `28ms` | `6ms` | trust/candidate route dominated, not render |

Current booted simulator app data was also inspected with:

```bash
python3 scripts/audit_chord_entry_diagnostics.py --app-data "$APP_DATA" --details --scores 5
```

The active simulator chart had six rendered auto-render diagnostics but no timing evidence on those rows, so it is not enough to justify a render-path change.

## Decision

Do not rewrite renderer/raster behavior from current evidence. The existing data says render handoff is small compared with scheduler/idle and recognition/trust routing. Sprint 61 should either:

- run one clean timing capture on the current app build, or
- make only a tiny measurement/tooling improvement if current timing evidence is missing when it should be present.

## Guardrails

- No personal handwriting fixture expansion.
- No recognition score retuning.
- No default OCR expansion.
- No symbol-ledger diagnostics cost.
- No export behavior change unless a measured export/raster issue is found.
- No change to accepted-chord ink clearing.
