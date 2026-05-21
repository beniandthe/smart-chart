# Smart Chart Sprint Source Of Truth

Status: active living sprint document
Created: 2026-05-20
Repo: `beniandthe/smart-chart`
Active branch: `codex/symbol-ledger-recognition`
Active baseline commit: `e040332 Document and clean up recognition sprint one`
Trusted checkpoint reference: `c60bb46 Polish altered chord recognition trust`

## Purpose

This document is the working source of truth for Smart Chart sprint recovery and forward planning.

Use it before starting recognition, editor, simulator, or architecture work. After each sprint completes, update this file in place: move the finished sprint into the completed log, record verification evidence, and define the next sprint only after discussing the next priority.

If this document conflicts with older recognition or architecture planning docs, this document wins for current sprint execution. `docs/core-design-document.md` still wins for product intent.

## Current Baseline

The active app implementation state is the latest code checkpoint:

- branch: `codex/symbol-ledger-recognition`
- commit: `e040332 Document and clean up recognition sprint one`
- supporting audit: `docs/repo-github-recognition-audit-2026-05-20.md`
- latest local verification: `swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint1` passed on 2026-05-21 with `310` tests, `1` skipped, `0` failures
- latest GitHub CI noted in the audit: success for `9479a94`

`c60bb46` remains the trusted checkpoint reference. It represents the last known-good altered-chord trust polish baseline before the symbol-ledger drift/recovery work. Do not treat `c60bb46` as the active implementation baseline unless a future sprint explicitly chooses a reset.

Known drift after Sprint 1:

- `ChordInkRecognizer` is back to a narrower orchestration role, but the composer-owned semantic candidate layer is still large.
- `ChordInkSymbolLedger` is diagnostics-only by policy and is gated off by default on the live recognition path.
- `StrokeClusterer.swift`, `StrokeClustererSupport.swift`, `ChordInkCandidateComposer.swift`, and `ChordInkSemanticCandidateComposer.swift` contain the largest remaining recognition maintenance and performance risk.
- The old handwriting plan mixes original design, historical pass notes, checkpoint evidence, and current backlog.
- `docs/current-architecture-audit.md` is stale because it says chord interpretation is outside the live path.
- `codex/symbol-ledger-recognition` has not yet been pushed after Sprint 1, and no PR exists for CodeQL coverage of the recovery branch.
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

### Sprint 2: Documentation Authority Cleanup And PR Hardening

Status: active.

Goal:

Make the living source-of-truth unquestionably authoritative, retire stale/conflicting docs from active planning, and prepare the recovered branch for GitHub review and CodeQL coverage.

Starting point:

- branch: `codex/symbol-ledger-recognition`
- baseline: `e040332`
- trusted checkpoint reference: `c60bb46`

Non-goals:

- Do not retune recognition scores.
- Do not add raster/classifier authority.
- Do not touch recognition runtime code unless a docs-only rename/reference requires it.
- Do not rewrite the entire historical plan into a new architecture spec in one sweep.
- Do not prune fixtures or split fixture tiers yet.
- Do not start editor/product polish until the authority cleanup is committed and the branch is ready for PR checks.

Implementation tasks:

1. Retire stale recognition-plan authority.
   - Add a top-of-file historical-status notice to `docs/handwriting-recognition-implementation-plan.md`.
   - Point readers to this living doc for current sprint authority and to `docs/repo-github-recognition-audit-2026-05-20.md` for the evidence snapshot.
   - Preserve useful historical architecture context rather than deleting the file.

2. Resolve stale architecture-audit conflict.
   - Mark `docs/current-architecture-audit.md` stale or replace its live-recognition claims with current status.
   - Ensure it cannot be mistaken for the active architecture plan.

3. Tighten README source-of-truth order.
   - Keep `docs/smart-chart-sprint-source-of-truth.md` first.
   - Make historical docs clearly subordinate where listed.

4. Prepare branch for GitHub review.
   - Run final local checks.
   - Push `codex/symbol-ledger-recognition`.
   - Open a PR to `main` so CodeQL and CI run against the recovered branch.

5. Update this living doc after PR creation.
   - Record the Sprint 2 commit or commit range.
   - Record PR URL and check status.
   - Move Sprint 2 to the completed log only after local verification and PR creation are done.

Progress notes:

- 2026-05-21: Sprint 2 opened after Sprint 1 commit `e040332`.

Acceptance criteria:

- Stale docs clearly defer to this living source-of-truth for current sprint authority.
- `docs/handwriting-recognition-implementation-plan.md` remains available as historical context.
- `docs/current-architecture-audit.md` no longer contradicts the live recognition pipeline without a stale warning.
- README points readers to the living doc first and labels historical docs appropriately.
- Branch is pushed and a PR exists for GitHub CI/CodeQL coverage.
- No runtime recognition files change during Sprint 2 unless explicitly approved.

Required verification:

```bash
swift test --scratch-path /tmp/SmartChartSwiftBuild-sprint1
python3 -m py_compile scripts/audit_chord_entry_diagnostics.py scripts/import_chord_fixture.py scripts/watch_simulator_chord_fixtures.py
git diff --check
```

Additional verification if editor/PencilKit code changes:

```bash
xcodegen generate
xcodebuild test -scheme SmartChart -destination "$SIMULATOR_DESTINATION" OTHER_CODE_SIGN_FLAGS=--strip-disallowed-xattrs
```

Do not use `CODE_SIGNING_ALLOWED=NO` for simulator test verification on this branch; it can build but fail app preflight launch.

For live simulator confidence after code cleanup:

```bash
scripts/audit_chord_entry_diagnostics.py --strict --details --scores 3
```

Use the disposable `Chord Writing Test Chart` only if Sprint 2 unexpectedly changes recognition or editor behavior.

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

## Next Sprint Backlog

Discuss and choose one item after Sprint 2 is complete:

- Decide whether to keep all fixture tests always-on or split critical CI fixtures from full corpus checks.
- Continue recognition cleanup by extracting composer scoring policy without retuning.
- Return to product/editor polish once the architecture boundary is stable.
- Update the PR based on CI/CodeQL findings, if any.

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
