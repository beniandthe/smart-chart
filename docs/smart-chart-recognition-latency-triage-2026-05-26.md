# Smart Chart Recognition Latency Triage

Status: Sprint 46 initial evidence gathered; behavior unchanged
Date: 2026-05-26
Source of truth: `docs/smart-chart-sprint-source-of-truth.md`
Trigger evidence: `docs/smart-chart-post-export-field-test-log-2026-05-26.md`

## Purpose

Sprint 46 investigates the couple-second delay after clear chord ink for `C` and `G/B`.

This is latency and trust routing work, not handwriting training. Do not add personal ink fixtures, score retuning, or corpus expansion before measuring where the live delay is spent.

## Current Timing Path

The live chord-entry path schedules recognition after a fixed idle delay:

```text
PKCanvasView drawing changed
-> scheduleChordInkRecognition()
-> LeadSheetChordInkRecognitionScheduling.idleDelay(...)
-> DispatchQueue.main.asyncAfter(default 1.2s)
-> ChordInkRecognitionSession.start(...)
-> ChordInkRecognizer.recognize(...)
-> optional OCR only when trust policy needs ambiguity evidence
-> LeadSheetChordInkRecognitionTimingLogger.log(...)
-> optional continuation-grace reschedule
-> onChordInkRecognitionProposal
```

Current configured delays in `LeadSheetCanvasHostView`:

- `chordInkIdleDelay`: `1.2` seconds
- `chordInkContinuationGraceDelay`: `1.2` seconds

## Initial Evidence

The first repo-local Sprint 46 test is `LeadSheetChordInkRecognitionSchedulingTests`.

It proves:

- `LeadSheetChordInkRecognitionScheduling.idleDelay` currently returns the configured default delay.
- A clear root like `C` can pay the initial `1.2s` idle delay plus a `1.2s` continuation-grace recheck before the proposal is sent.
- The same drawing data does not repeat continuation grace forever.
- `G/B` and `Db7(b9)` do not use that continuation-grace path because slash-bass and altered chords are outside the simple-continuation guard.

This means:

- At least part of the perceived `C` delay is intentional scheduler policy, not recognizer compute.
- `G/B` latency is likely the normal idle delay plus writing/user-perception/render handoff, not the root-continuation grace path.
- `Db7(b9)` behaving as confirmation-gated remains expected.

## Verification

- XcodeBuildMCP focused iOS simulator test `SmartChartTests/LeadSheetChordInkRecognitionSchedulingTests` passed with `4` tests, `0` failures on the configured `iPad Pro 13-inch (M5)` simulator.
- `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint46 --filter WritingToRenderPipelineReadinessTests` passed with `1` test, `0` failures; the bounded recognizer/readiness pass completed in `0.187s`, keeping recognizer compute well below the product-loop latency budget.
- `xcodegen generate` completed after adding the app-target scheduling test.

## Next Evidence To Gather

- Inspect whether the first-pass continuation grace can be made more selective for high-confidence root-only reads without making partially written extensions auto-render too early.
- Inspect existing debug timing logs from a live/simulator pass if available:
  - `delay`
  - `idle`
  - `recognition`
  - `ocrMs`
  - `best`
- Only after measuring, choose whether Sprint 46 should tune scheduler/debounce behavior or leave latency as a product tradeoff.

## Guardrails

- Do not expand fixture corpus.
- Do not tune recognition scores from this one writer's iPad pass.
- Do not enable symbol-ledger diagnostics by default.
- Do not make OCR run for clear `C` or `G/B` reads.
- Do not change export/share, PDF rendering, or chord ink clearing in this sprint.
