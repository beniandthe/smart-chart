# Smart Chart V1 Readiness Matrix

Date: 2026-05-31
Sprint: 69 V1 readiness / recursive closeout audit
Branch: `codex/rhythm-section-core-authoring`
Source of truth: `docs/smart-chart-sprint-source-of-truth.md`

## Summary

The current V1 product should focus on two active chart styles:

- Simple Chord Sheet: handwritten/iReal-style chord-grid authoring.
- Rhythm Section Sheet: structured staff-based hit/rhythm chart authoring.

Lead Sheet is preserved as a post-V1 archive and compatibility surface, not an active V1 release target.

The code/doc audit does not currently expose a hidden V1 implementation blocker. The main remaining release gates are fresh app-surface proof and ranked polish, especially Rhythm Section cohesion now that Simple has a credible core loop.

## Matrix

| Area | Status | Evidence | V1 Decision |
| --- | --- | --- | --- |
| New Chart layout picker | Done | `ChartLayoutStyle`, layout profiles, setup-policy tests, library row style copy | Keep |
| One-measure minimum | Done | Model guards and tests for zero-measure sanitization and delete minimum | Keep |
| Simple chord authoring loop | Done | Live milestone at `4dff695`; tests for beat-1/beat-3 append, move-to-beat, later-beat append order, adaptive chord layout, semantic typography | Keep as V1 core |
| Simple manual rows | Done | Menu-owned row breaks, row cap, equal default rows, proportional manual width weighting, layout tests | Keep as V1 core |
| Simple floating freehand | Done | `FreehandSymbolLane.chartArea`, move/delete model tests, layout tests, active-tool scroll protection tests | Keep as V1 core |
| Role-based typography | Done | `ChartTypographySettings`, resolver tests, MuseJazz bundled from official source, semantic chord token tests | Keep as V1 core |
| Section labels | Done | Measure-attached model, layout/export coverage, delete-with-measure behavior | Keep as structured objects |
| Roadmap repeats/endings/markers | Done | Repeat spans, first/second endings, coda/segno/D.S./D.C./Fine/N.C. point markers, layout/export coverage | Keep; vamp count stays out |
| Cue text | Done | Measure-attached typed text, above/below positions, layout/export coverage, delete-with-measure behavior | Keep as typed/manual-first |
| Persistence | Hardened in Sprint 69 | Added V1-shaped Simple snapshot test covering typography, manual row break, manual width, roadmap, cue, freehand, and chords | Keep; still needs app-surface save/reopen pass |
| PDF/export | Done for structured proof | Simple and Rhythm Section export-proof tests cover structured objects and reject editor placeholders | Keep; still needs export from fresh app state |
| Rhythm Section core authoring | Done | V4 rhythm-recognition gate, exact-fit map authority, chord snap tests, below-staff freehand lane, layout/export coverage | Keep as V1 core |
| Rhythm Section visual cohesion | V1 polish | Current model/layout is solid, but Simple polish has moved ahead visually | Make next polish lane unless live pass finds a blocker |
| Toolstrip semantics | Mostly done | Page/Export/fonts/engraving grouping, Roadmap coda icon, Text, Chord pencil label, Simple hides Rhythmic Notation, legacy tabs hidden | Verify in simulator pass |
| Save/reopen app flow | Release gate | Repository tests exist; Sprint 69 added richer Simple persistence proof | Must pass live app check before V1 |
| Fresh simulator install flow | Release gate | Prior fresh launches passed, but post-typography/core-loop app proof should be renewed | Must pass before choosing release candidate |
| Lead Sheet | Post-V1 | Archived under `docs/post-v1/lead-sheet/` | Preserve compatibility only |
| Rhythm-object editing | Post-V1 | Explicitly deferred in Rhythm Section plan | Do not block V1 |
| Handwritten section/cue/articulation recognition | Intentionally deferred | Structured typed/manual paths exist | Do not block V1 |
| Vamp count | Intentionally deferred | Explicitly skipped by user | Do not block V1 |
| OCR expansion, score retuning, personal handwriting training, default diagnostics | Intentionally deferred / prohibited | Recognition guardrails | Do not do |

## V1 Blockers

No code/doc-audit blocker is currently confirmed.

Release gates still required before calling V1 ready:

- Fresh Simple Chord Sheet app pass: create, write one/two/three-plus chord measures, move chords, change chord font role, add row break, freehand, section/roadmap/cue, save/reopen, export.
- Fresh Rhythm Section Sheet app pass: create, write slashes/quarters/beamed eighths, confirm chord snapping with and without rhythm maps, add below-staff freehand, section/roadmap/cue, save/reopen, export.
- Fresh simulator build/run from a clean installed app state.

## V1 Polish Queue

1. Rhythm Section cohesion pass: make the sheet feel like a professional rhythm/hit chart while keeping automatic wrapping for now.
2. App-level save/reopen/export UX pass: make sure the user can confidently find and verify saved charts and exported PDFs.
3. Toolstrip and menu affordance pass: clean any remaining naming, hit-target, and menu-state contradictions found in live passes.
4. Simple export visual proof from app-created state: compare rendered output against the accepted Simple live canvas feel.

## Post-V1 Queue

- Lead Sheet pitched-note authoring, ledger lines, key-aware note spelling, and full lead-sheet export polish.
- Rhythm-object editing after recognition commit.
- Rhythm Section manual row/system controls if real chart layout pressure proves automatic wrapping insufficient.
- Handwritten recognition for section labels, cue text, and freehand articulations.
- Vamp count and deeper playback/navigation roadmap semantics.

## Audit Notes

- Sprint 68 is complete enough for the current V1 direction; remaining ideas are now classified rather than recursively reopened.
- The next implementation lane should come from the live Sprint 69 passes. If no blocker appears, Rhythm Section visual cohesion is the highest-value next polish lane.
- Personal live passes remain validation evidence only. They are not recognizer training data.
