# Smart Chart Real Pencil Field Test Log

Status: Sprint 43 field-test evidence started
Date: 2026-05-26
Protocol: `docs/smart-chart-real-life-testing-readiness-2026-05-25.md`
Source of truth: `docs/smart-chart-sprint-source-of-truth.md`

## Purpose

Use this file to record the first bounded real Apple Pencil validation pass after Sprint 42.

This is product evidence for the writing-to-render loop:

```text
open -> write -> recognize -> snap -> fix -> export
```

This is not a handwriting training session. Do not add fixtures, tune scores, or expand the corpus from this pass unless the observation proves a transferable product regression.

## Test Setup

- tester: Beni
- device model: not yet recorded from tester; exported artifact was found in the configured iOS simulator Preview/export containers
- iPadOS version: not yet recorded from tester; exported PDF metadata reports iOS Version 26.5 (Build 23F77)
- Apple Pencil model: not yet recorded
- app build/commit: `56ef6ae Set up real Pencil field test`
- date/time: user-reported pass complete on 2026-05-25; exported PDF metadata timestamp `2026-05-26T03:01:32Z` (`2026-05-25 20:01:32 PDT`)
- chart title: `Untitled Chart`
- notes on input environment: user reported the pass was completed and exported to Preview; local evidence currently proves the Preview/export PDF artifact, not physical device identity or subjective Pencil feel

## Preflight

- [ ] App opens to Projects/Library.
- [ ] Clean chart is created or opened.
- [ ] Chord-writing mode is reachable.
- [ ] Apple Pencil writes native ink without obvious lag before recognition starts.
- [x] Export path is reachable.

## Bounded Test Cases

| Case | Expected route | Actual route | Pencil feel | Correction friction | Export result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `C` | Auto-render or clear correction path | Rendered into exported PDF; route details not yet recorded | not yet recorded | not yet recorded | Pass: visible in M1 | Visual export proof shows label and beat subtitle legibly rendered |
| `G/B` | Auto-render slash chord | Rendered into exported PDF; route details not yet recorded | not yet recorded | not yet recorded | Pass: visible in M2 | Slash chord label rendered without clipping |
| `Db7(b9)` | Confirmation, not blind auto-render | Rendered into exported PDF; confirmation behavior not yet recorded | not yet recorded | not yet recorded | Pass: visible in M3 | Altered chord label rendered without clipping |

## Product Observations

### Writing Feel

- latency: not yet recorded from tester
- stroke fragmentation: not yet recorded from tester
- pressure/visual feel: not yet recorded from tester
- accidental mode/tool friction: not yet recorded from tester

### Recognition Trust

- auto-render felt correct when: not yet recorded from tester
- confirmation felt necessary when: not yet recorded from tester
- surprising result: not yet recorded from tester

### Correction Flow

- suggestion clarity: not yet recorded from tester
- manual edit friction: not yet recorded from tester
- recovery from wrong/unsupported chord: not yet recorded from tester

### Ink Lifecycle

- chord ink cleared after accepted render: not yet recorded from tester
- unexpected ink left behind: not visible in exported PDF; live canvas state not yet recorded
- unexpected ink cleared too early: not yet recorded from tester

### Export

- PDF readability: pass. Rendered PNG proof is legible at `792x612`; white page background is stable.
- chord placement: pass. `C`, `G/B`, and `Db7(b9)` appear in M1, M2, and M3 respectively with no visible clipping; M4 remains empty.
- title/header/layout: pass. Header shows `Untitled Chart`, `C major`, `Concert`, `4/4`, `4 measures`, and `Page 1`.
- share/export friction: user reported export to Preview succeeded; exact tap path and any friction are not yet recorded.

## Evidence

Attach or reference only product-useful evidence:

- screenshots:
- screen recording:
- exported PDF:
  - Preview/export cache path: `/Users/benirossman/Library/Developer/CoreSimulator/Devices/42254D11-2E65-4586-AEBE-C6317AF2DD10/data/Containers/Data/Application/40BBB488-7B7B-430E-864C-1FF6A81B0005/Library/Caches/SmartChartExports/untitled-chart-concert.pdf`
  - Preview documents path: `/Users/benirossman/Library/Developer/CoreSimulator/Devices/42254D11-2E65-4586-AEBE-C6317AF2DD10/data/Containers/Data/Application/16C71DA8-5ED6-467B-944B-BD84EE5B0698/Documents/untitled-chart-concert.pdf`
  - size: `23824` bytes
  - SHA-256: `0e73bc58afdffcdf82393a300a61b60274effe235b3f98d80aa160199e8e80aa`
  - PDF metadata: creator `Smart Chart`, title `Untitled Chart`, producer `iOS Version 26.5 (Build 23F77) Quartz PDFContext`, creation/modification timestamp `2026-05-26T03:01:32Z`
- rendered QA image: `/tmp/SmartChartRealPencilFieldTest/untitled-chart-concert.png`
- visual QA notes: first page renders as a clean landscape chart with four visible measures; `C`, `G/B`, and `Db7(b9)` are legible and not clipped.
- console/log notes:

Do not save repeated personal handwriting samples unless a specific transferable regression needs a fixture later.

## Decision

Choose the next sprint from the observed product friction:

- [ ] Pencil/input feel sprint
- [ ] recognition trust routing sprint
- [ ] correction UX sprint
- [ ] renderer/export sprint
- [ ] beta/readiness polish sprint
- [ ] no code change; repeat field test with another writer/device

Decision notes:

The first evidence capture confirms the write-to-render-to-export output can produce a legible Preview PDF for the bounded Sprint 42/43 chord set. The remaining Sprint 43 decision should be driven by the tester's live notes on Pencil feel, route trust, correction friction, and ink-clearing behavior rather than by adding more one-writer ink samples.
