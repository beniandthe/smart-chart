# Smart Chart Sprint 55: Chord-First Product Polish

Status: implemented locally; placement/snapping and placement-evidence diagnostics slices ready for CI
Date: 2026-05-26
Source of truth: `docs/smart-chart-sprint-source-of-truth.md`

## Goal

Keep the product roadmap centered on chord work: write, recognize, snap, fix, render, and export chord symbols cleanly.

## Product Direction

The next sequence should prioritize chord-related features over general app-shell work:

- Placement and snapping: chords should land where the writer expects.
- Raster/render time: recognized chords should appear quickly after the commit decision.
- Accuracy and confidence: trust decisions should stay writer-agnostic and evidence-based.
- Confirmation and correction: wrong or ambiguous reads should recover without trapping the user.
- Export fidelity: exported charts should preserve structured chord placement, not card-like blocks.

## Sprint 55 Slice

Start with placement/snapping.

Reason: if a chord lands in the wrong rhythmic location, it feels wrong even when recognition is correct. Placement is also easier to improve with general geometry/rhythm evidence than handwriting-specific score tuning.

## Implementation

- Change rhythm-map placement snapping to choose the nearest playable rhythm-slot attack/start position, not the slot midpoint.
- This improves long-slot cases such as quarter, quarter, half where a chord written near beat 3 should snap to the half-note slot at beat 3 instead of the previous quarter slot.
- Record chord placement evidence in chord-entry diagnostics: start position, duration, rhythm placement, and mapped rhythm-slot index when available.
- Placement evidence lets the next real pass audit where a chord actually landed without expanding the handwriting fixture corpus or retuning recognition scores.
- Preserve recognition, trust, parser, correction-memory, PencilKit, fixture corpus, OCR, export, and chart mutation authority.

## Verification Plan

- Focused SwiftPM test: `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint55-placement --filter MeasureRhythmMappingTests`.
- Focused diagnostics test: `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint55-diagnostics --filter ChordEntryDiagnosticsTests`.
- `git diff --check`.
- App-target compile only if the touched model path triggers a SwiftUI/app compile risk.
- Required GitHub Actions after push.

## Verification Evidence

- Focused `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint55-placement --filter MeasureRhythmMappingTests` passed with `15` tests and `0` failures.
- XcodeBuildMCP iOS simulator compile-only build passed for the `SmartChart` scheme with `CODE_SIGNING_ALLOWED=NO`.
- `git diff --check` passed.
- GitHub Actions for `7740a3f Start sprint 55 chord placement polish` passed `SwiftPM tests`, `iOS simulator tests`, and `Analyze Swift` on 2026-05-26.
- Focused `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint55-diagnostics --filter ChordEntryDiagnosticsTests` passed with `8` tests and `0` failures.
- XcodeBuildMCP iOS simulator compile-only build passed for the `SmartChart` scheme with `CODE_SIGNING_ALLOWED=NO` after the editor diagnostics wiring.
- `git diff --check` passed after the placement-evidence diagnostics update.

## Acceptance Criteria

- Rhythm-aware chord insertion snaps to the nearest playable slot attack/start position.
- Long-duration rhythm slots no longer lose near-start chord writes to earlier short slots.
- Existing next-open-slot and explicit move/replace behaviors remain covered.
- Chord-entry diagnostics include placement evidence for committed, corrected, and reconciled rendered chords.
- No personal handwriting fixture expansion or score retuning.
