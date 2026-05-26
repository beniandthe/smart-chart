# Smart Chart Sprint 47 Confidence And Performance Triage

Status: active planning artifact
Date: 2026-05-26
Source of truth: `docs/smart-chart-sprint-source-of-truth.md`
Prior evidence: `docs/smart-chart-sprint-46-latency-repeat-log-2026-05-26.md`

## Purpose

Sprint 47 separates the two remaining real-device hurdles:

- confidence/ink accuracy: `C` and `G/B` can still fall into low-confidence handling on real Pencil input
- conflict/performance/render time: the user-visible delay may include candidate conflict handling, trust routing, proposal UI, commit, ink clearing, or render handoff

This sprint is measurement-first. Do not retune scores, expand personal fixtures, or add a training loop from one writer's pass.

## Product Evidence

The Sprint 46 repeat pass found:

- `C` and `G/B` were low confidence and still took time.
- `Db7(b9)` was extremely quick.
- PDF export completed without issues.

This means the scheduler-only fix is not the whole answer. The next bottleneck is confidence/trust routing or render handoff, not export/share and not the altered-chord confirmation path.

## Working Hypotheses

1. `C` and `G/B` are slow because low confidence causes extra confirmation/trust routing or delayed proposal behavior.
2. The recognizer may be fast, but the UI may spend visible time in proposal, commit, ink clearing, or re-render.
3. Candidate conflict may be making common clear cases feel slower than a more complex altered chord when the altered chord's route is decisive.
4. Any fix must be writer-agnostic and should help general chord-shape interpretation, not memorize this tester's ink.

## First Tasks

- Inspect the live timing/logger path for low-confidence decisions and confirm which fields already capture delay, recognition time, OCR time, best candidate, confidence, and decision route.
- Add or tighten a bounded timing/debug surface only if existing logs cannot separate recognition compute from trust routing and render handoff.
- Audit the `C` and `G/B` path through `ChordInkRecognitionPolicy`, `ChordRecognitionTrustArbiter`, proposal routing, `Chart.commitRecognizedChordInk`, chord ink clearing, and page re-render.
- Keep `Db7(b9)` as a fast confirmation-gated control case.
- Use repo-local, writer-agnostic fixtures only for regression protection if a general bug is found. Do not import the latest iPad metadata as training data.

## Acceptance Criteria

- Sprint 47 identifies whether the remaining delay is primarily confidence/trust routing, candidate conflict, recognizer compute, UI proposal/commit, ink clearing, or render handoff.
- Any code change is backed by timing evidence and preserves writer-agnostic recognition.
- `Db7(b9)` remains confirmation-gated and quick.
- Export/share remains unchanged and working.
- No personal fixture expansion, score retuning from one pass, default OCR expansion, or symbol-ledger diagnostics cost.

## Non-Goals

- No broad recognition quality retuning.
- No new handwriting corpus or repeated-pass training loop.
- No StoreKit/export sprint unless a fresh export regression appears.
- No attempt to make all low-confidence reads auto-render; correction trust remains more important than guessing fast.
