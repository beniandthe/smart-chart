# Smart Chart Sprint Source Of Truth

Status: active living sprint document
Created: 2026-05-20
Repo: `beniandthe/smart-chart`
Active branch: `codex/symbol-ledger-recognition`
Active baseline commit: Sprint 3 closeout commit containing this entry; previous checkpoint was `19b1b1e Close sprint two source of truth`
Trusted checkpoint reference: `c60bb46 Polish altered chord recognition trust`

## Purpose

This document is the working source of truth for Smart Chart sprint recovery and forward planning.

Use it before starting recognition, editor, simulator, or architecture work. After each sprint completes, update this file in place: move the finished sprint into the completed log, record verification evidence, and define the next sprint only after discussing the next priority.

If this document conflicts with older recognition or architecture planning docs, this document wins for current sprint execution. `docs/core-design-document.md` still wins for product intent.

## Current Baseline

The active app implementation state is the latest Sprint 3 checkpoint:

- branch: `codex/symbol-ledger-recognition`
- previous checkpoint: `19b1b1e Close sprint two source of truth`
- implementation state: Sprint 3 fixture-loader cleanup plus this closeout entry
- supporting audit: `docs/repo-github-recognition-audit-2026-05-20.md`
- latest local verification: `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint1` passed on 2026-05-21 with `310` tests, `1` skipped, `0` failures
- latest GitHub verification before the Sprint 3 push: draft PR [#4](https://github.com/beniandthe/smart-chart/pull/4) had Dependency Review, SwiftPM, and iOS simulator checks passing; CodeQL was still pending

`c60bb46` remains the trusted checkpoint reference. It represents the last known-good altered-chord trust polish baseline before the symbol-ledger drift/recovery work. Do not treat `c60bb46` as the active implementation baseline unless a future sprint explicitly chooses a reset.

Known drift after Sprint 3:

- `ChordInkRecognizer` is back to a narrower orchestration role, but the composer-owned semantic candidate layer is still large.
- `ChordInkSymbolLedger` is diagnostics-only by policy and is gated off by default on the live recognition path.
- `StrokeClusterer.swift`, `StrokeClustererSupport.swift`, `ChordInkCandidateComposer.swift`, and `ChordInkSemanticCandidateComposer.swift` contain the largest remaining recognition maintenance and performance risk.
- The old handwriting plan and current-architecture audit are explicitly marked historical/stale when they conflict with this file.
- `646` ink fixtures remain default-on in the regression path; decoded fixture data is now cached inside the test loader to avoid repeated file-system churn.
- Full critical/full fixture tiering is deferred unless CI runtime or local loop cost becomes a real blocker.
- PR [#4](https://github.com/beniandthe/smart-chart/pull/4) is the active GitHub review surface; recheck CodeQL and any rerun checks before choosing Sprint 4.
- No tracked cache/raster/direct-ink detour files remain in the current tree; remaining bloat is inside the current recognition path.

## Product North Star

The product workflow remains:

```text
open -> write -> recognize -> snap -> fix -> export
```

Product rules:

- Smart Chart is chord-first and rhythm-aware, not full notation software.
- Native Apple Pencil writing feel matters more than custom capture workarounds.
- Recognition proposes; structured chart objects decide.
- Correction speed matters more than perfect recognition.
- Raw ink should support reinterpretation, but the chart must not depend on raw ink alone.

## Source-Of-Truth Pipeline

The live chord-recognition pipeline must converge to:

```text
native PKCanvasView ink
-> PencilKitInkAdapter
-> StrokeClusterer
-> GestureTemplateRecognizer
-> ChordInkCandidateComposer
-> ChordRecognitionCompendium / ChordSymbolParser
-> ChordInkRecognitionPolicy plus optional trust sidecar
-> structured ChordEvent commit
```

Current sidecars:

- OCR sidecar: optional, ambiguity-only, compendium-gated.
- Symbol ledger: diagnostics-only evidence, not a renderer or final chord authority.
- Diagnostic recorder/audit script: tooling path for simulator and archived passes, not product behavior.

Deferred sidecars:

- Raster/classifier evidence.
- Incremental symbol cache/session state.
- Fixture corpus pruning or tiering.
- CoreML/HOMUS expansion.

## Authority Rules

These rules are hard boundaries for Sprint 1 and future recognition work:

- `ChordRecognitionCompendium` and `ChordSymbolParser` are the only final validators for accepted chord tokens.
- `ChordInkCandidateComposer` is the only layer that should compose glyph columns into final chord-string candidates.
- `ChordInkRecognizer` should orchestrate the pipeline and collect metrics; it should not keep growing new semantic candidate authorities.
- `ChordRecognitionTrustArbiter` may decorate or support a primary decision, but it must not bypass compendium validation.
- Raw OCR text must never render or appear as a trusted suggestion unless it normalizes through the compendium.
- `ChordInkSymbolLedger` may explain or audit a result, but it must not auto-render a different answer on its own.
- Recognition must not own beat placement. The editor/layout layer decides where a structured `ChordEvent` lands.
- Native `PKCanvasView` stays the writing renderer unless a future sprint explicitly proves a better native-feeling path.

## Active Sprint

### Next Sprint: Pending Selection

Status: waiting for post-Sprint 3 and PR decision.

Sprint 3 is complete locally: fixture JSON was not changed, the full corpus remains default-on, and repeated test fixture loading now uses a decoded corpus cache.

Do not start Sprint 4 from memory alone. First review this file, PR [#4](https://github.com/beniandthe/smart-chart/pull/4), the current branch state, and any new CI or CodeQL result.

## Completed Sprints Log

Append one entry here after each sprint completes. Each entry must include:

- sprint name
- commit range or final commit
- summary of what changed
- tests and live-pass evidence
- unresolved follow-up
- next sprint candidate

### Sprint 1: Code Cleanup First

- status: complete
- final commit: `e040332 Document and clean up recognition sprint one`
- summary: Recovered the streamlined recognition architecture without score retuning. Symbol-ledger diagnostics are opt-in, semantic candidate construction moved out of `ChordInkRecognizer` into composer-owned code, and `StrokeClusterer` support helpers were split into `StrokeClustererSupport.swift` as a behavior-preserving refactor.
- tests and evidence: `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint1` passed with `310` tests, `1` skipped, `0` failures; `python3 -m py_compile scripts/audit_chord_entry_diagnostics.py scripts/import_chord_fixture.py scripts/watch_simulator_chord_fixtures.py` passed; `xcodegen generate` completed; iOS simulator `SmartChart` scheme passed with `350` tests, `1` skipped, `0` failures using `OTHER_CODE_SIGN_FLAGS=--strip-disallowed-xattrs`; `git diff --check` passed.
- unresolved follow-up: `docs/handwriting-recognition-implementation-plan.md` and `docs/current-architecture-audit.md` remain historical/stale when they conflict with this file; no fresh user-facing `Chord Writing Test Chart` pass was run after cleanup because Sprint 1 was behavior-preserving and covered by existing recognition fixtures; branch still needs push/PR for GitHub checks.
- next sprint candidate: Sprint 2 is documentation authority cleanup plus PR/CodeQL hardening.

### Sprint 2: Documentation Authority And PR Hardening

- status: complete
- commit range: `2eedd48 Open sprint two authority cleanup` through `4ff784e Clarify sprint two doc authority`, plus the Sprint 2 closeout entry in this file
- summary: Marked stale planning docs as historical, split `README.md` authority links into active and historical groups, pushed `codex/symbol-ledger-recognition`, and opened draft PR [#4](https://github.com/beniandthe/smart-chart/pull/4) as the GitHub review surface for the recovery branch.
- tests and evidence: `git diff --check` passed; trailing whitespace scan found no hits; `python3 -m py_compile scripts/audit_chord_entry_diagnostics.py scripts/import_chord_fixture.py scripts/watch_simulator_chord_fixtures.py` passed; `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint1` passed with `310` tests, `1` skipped, `0` failures. PR [#4](https://github.com/beniandthe/smart-chart/pull/4) showed Dependency Review, SwiftPM, and iOS simulator checks passing before this closeout push; CodeQL was still pending at closeout.
- unresolved follow-up: PR [#4](https://github.com/beniandthe/smart-chart/pull/4) is draft and CodeQL/rerun checks need one final review before merge readiness. Sprint 3 is intentionally not selected yet.
- next sprint candidate: Review PR [#4](https://github.com/beniandthe/smart-chart/pull/4) status first, then choose between fixture tiering, composer scoring extraction, or product/editor polish.

### Sprint 3: Fixture Corpus Runtime Cleanup

- status: complete locally; PR checks must be rechecked after push
- commit range: `19b1b1e Close sprint two source of truth` through the Sprint 3 closeout commit containing this entry
- summary: Kept the full `646`-file ink fixture corpus default-on, added a decoded corpus cache to the test-only `InkFixtureLoader`, preserved deterministic fixture ordering and named fixture loading, and documented the fixture runtime policy in `SmartChartTests/Fixtures/Ink/README.md`.
- tests and evidence: focused `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint1 --filter InkFixtureLoaderTests` passed with `2` tests, `0` failures; full `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint1` passed with `310` tests, `1` skipped, `0` failures; `python3 -m py_compile scripts/audit_chord_entry_diagnostics.py scripts/import_chord_fixture.py scripts/watch_simulator_chord_fixtures.py` passed; `git diff --check` passed. No fixture JSON files changed.
- GitHub evidence before the Sprint 3 push: PR [#4](https://github.com/beniandthe/smart-chart/pull/4) had Dependency Review, SwiftPM, and iOS simulator checks passing; CodeQL was still pending.
- unresolved follow-up: recheck PR [#4](https://github.com/beniandthe/smart-chart/pull/4) after the Sprint 3 push; full critical/full fixture tiering remains deferred until test runtime becomes a proven blocker.
- next sprint candidate: Update the PR for any CodeQL/CI result first, otherwise choose between composer scoring extraction and product/editor polish.

## Next Sprint Backlog

Discuss and choose one item after Sprint 3 is complete:

- Update PR [#4](https://github.com/beniandthe/smart-chart/pull/4) based on any CodeQL or CI findings.
- Continue recognition cleanup by extracting composer scoring policy without retuning.
- Return to product/editor polish once the architecture boundary is stable.
- Revisit fixture tiering only if CI runtime or local loop cost becomes a real blocker.

## Retired Or Stale Docs

Current authority:

- `docs/smart-chart-sprint-source-of-truth.md`: active sprint execution and recovery plan.
- `docs/core-design-document.md`: product intent and design rules.
- `docs/developer-mvp-spec.md`: MVP scope, subordinate to the core design document.
- `docs/repo-github-recognition-audit-2026-05-20.md`: evidence snapshot for the current recovery plan.

Historical or stale context:

- `docs/handwriting-recognition-implementation-plan.md`: original recognition architecture plus historical pass notes. Use for background only until a future sprint rewrites it.
- `docs/current-architecture-audit.md`: stale because it predates live chord-entry recognition.
- `docs/architecture-reset-proposal.md`: useful historical proposal, not the active sprint plan.
- `docs/implementation-milestones.md`: older execution sequence; do not use it to override this document.

## Update Protocol

At sprint completion:

1. Run the required verification commands.
2. Record the final commit or commit range.
3. Move the active sprint summary into `Completed Sprints Log`.
4. Record any unresolved risks.
5. Discuss the next sprint before editing `Active Sprint`.
6. Keep prior completed entries intact.

Do not start a new recognition or editor sprint from memory alone. Reopen this document, the latest audit/pass evidence, and the current git state first.
