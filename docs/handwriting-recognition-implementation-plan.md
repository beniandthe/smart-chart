# Handwriting Recognition Implementation Plan

Status: Implementation plan
Date: 2026-05-06
Target repo: `beniandthe/smart-chart`

## Purpose

Smart Chart should convert Apple Pencil input into clean, editable chord-chart objects without making handwriting recognition the fragile center of the app.

The goal is not full OCR. The goal is a constrained, testable recognition pipeline for common chord-chart tokens: chord roots, accidentals, minor marks, extensions, alterations, slash bass, and a small set of notation marks.

This plan assumes the GitHub `main` branch is the source of truth.

## Current Repo Starting Point

Relevant existing files:

- `SmartChart/Services/ChordRecognitionCompendium.swift`
- `SmartChart/Services/ChartParsers.swift`
- `SmartChart/Models/MusicTheory.swift`
- `SmartChart/Models/ChordEvent.swift`
- `SmartChart/Models/Chart.swift`
- `SmartChartTests/ChordSymbolParserTests.swift`
- `docs/architecture-reset-proposal.md`

The current `ChordRecognitionCompendium` already handles symbolic/OCR-like chord strings such as:

- `F sharp` -> `F#`
- `D flat` -> `Db`
- Unicode accidentals such as `B♭`
- minor aliases such as `Cm`, `Cmin`, `C minor`, and `C-`
- rejection of unsupported major suffix aliases such as `Cmaj`, `CM`, and `C major`

That means the missing layer is not primarily the chord parser. The missing layer is the ink-to-candidate pipeline that turns PencilKit strokes into ranked candidate strings before calling `ChordRecognitionCompendium.match(candidates:)`.

## Core Principle

Recognize small musical glyphs, compose those glyphs into candidate chord strings, then let the existing chord compendium validate the final result.

Do not try to recognize a complete handwritten chord symbol as arbitrary text in one step.

Preferred flow:

```text
PKDrawing
-> raw strokes
-> stroke groups / clusters
-> per-cluster glyph candidates
-> composed chord-string candidates
-> ChordRecognitionCompendium.match(candidates:)
-> ChordSymbol / ChordEvent suggestion
```

Recognition should propose. The structured chart model should decide.

## Third-Party References

### Primary candidate: DollarGestureRecognizer

Repository: https://github.com/DanielCardonaRojas/DollarGestureRecognizer

Why it fits:

- Swift/iOS implementation.
- MIT licensed.
- Exposes dollar-family recognizers through UIKit gesture recognizers.
- Includes single-stroke and multi-stroke recognizer approaches (`$1`, `$Q`, `$P`, `$N`).
- Multi-stroke matching is useful for accidentals such as `#`, flat-like marks, natural signs, slashes, and compound glyphs.

Recommended use:

- Treat this as either a vendored dependency under `ThirdParty/` or a porting reference.
- For product stability, prefer copying/porting only the small recognizer core we need into `SmartChart/Recognition` with license attribution, instead of making the editor depend directly on a large external UI surface.

### Useful reference: DollarP-ObjC

Repository/page: https://fe9lix.github.io/DollarP_ObjC/

Why it matters:

- Clear Objective-C reference for `$P` point-cloud matching.
- Useful if we want to implement a minimal Swift point-cloud recognizer ourselves.

### Music-symbol data: HOMUS

Dataset page: https://grfia.dlsi.ua.es/homus/

Why it matters:

- Handwritten online music-symbol dataset.
- 15,200 samples from 100 musicians.
- Includes accidentals, notes, rests, time signatures, clefs, dots, and barlines.
- Stores strokes as 2D point sequences, which maps well to PencilKit-style input.

Recommended use:

- Do not depend on HOMUS in the app bundle initially.
- Use it later for evaluation, tests, and optional model/template expansion.
- Start with Smart Chart-specific user samples first because chord-chart handwriting differs from formal staff notation.

### CoreML reference: DeTeXt

Repository: https://github.com/venkatasg/DeTeXt

Why it matters:

- iOS app using PencilKit, SwiftUI, Combine, and CoreML for drawn-symbol classification.
- Good architecture reference if template matching hits a ceiling.

Recommended use:

- Phase-two reference only.
- Do not start with CoreML unless template recognition cannot get reliable enough.

## Proposed Module Map

Add:

```text
SmartChart/Recognition/
  InkPoint.swift
  InkStroke.swift
  InkCluster.swift
  InkStrokeExtractor.swift
  StrokeClusterer.swift
  GestureTemplate.swift
  GestureTemplateRecognizer.swift
  GlyphCandidate.swift
  ChordInkCandidateComposer.swift
  ChordInkRecognizer.swift
  RecognitionVocabulary.swift
  RecognitionDebugFormatter.swift

SmartChartTests/Recognition/
  InkStrokeExtractorTests.swift
  StrokeClustererTests.swift
  GestureTemplateRecognizerTests.swift
  ChordInkCandidateComposerTests.swift
  ChordInkRecognizerTests.swift

SmartChartTests/Fixtures/Ink/
  README.md
  C.json
  Bb.json
  FSharp.json
  CMinor.json
  Db7b9.json
```

Optional later:

```text
ThirdParty/DollarGestureRecognizer/
  LICENSE
  Sources/...
```

or:

```text
SmartChart/Recognition/Dollar/
  DollarPointCloudRecognizer.swift
  DollarRecognizerLicense.md
```

## Data Types

Start with pure Swift structs so the recognition layer can be tested without UIKit/PencilKit.

```swift
struct InkPoint: Codable, Hashable {
    var x: Double
    var y: Double
    var timeOffset: TimeInterval?
}

struct InkStroke: Codable, Hashable {
    var points: [InkPoint]
    var bounds: InkBounds
}

struct InkCluster: Codable, Hashable {
    var strokes: [InkStroke]
    var bounds: InkBounds
    var startTimeOffset: TimeInterval?
    var endTimeOffset: TimeInterval?
}

struct GlyphCandidate: Hashable {
    var text: String
    var confidence: Double
    var source: RecognitionSource
}

struct ChordInkRecognitionResult: Hashable {
    var rawCandidates: [String]
    var glyphCandidates: [[GlyphCandidate]]
    var match: ChordRecognitionMatch?
    var confidence: Double
}
```

Keep these independent from `PKStroke` and `PKDrawing`. UIKit/PencilKit adapters should sit at the edge.

## Layer 1: Parser And Compendium Lockdown

Before adding ink recognition, make the existing symbolic layer harder to regress.

Expand `SmartChartTests/ChordSymbolParserTests.swift` with tests for:

- every root plus accidental spelling: `C`, `C#`, `Cb`, `D`, `D#`, `Db`, etc.
- enharmonic spellings that should be preserved on zero transposition: `Cb`, `E#`, `Fb`, `B#`
- OCR-like variants: `F sharp`, `D flat`, `B♭`
- minor aliases: `Cm`, `Cmin`, `C minor`, `C-`
- rejected major aliases: `Cmaj`, `CM`, `C major`
- candidate ordering: if candidates are `['8b', 'Bb']`, the compendium should eventually choose `Bb`

Acceptance criteria:

- The existing compendium remains the only authority for accepted chord tokens.
- Recognition code never bypasses `ChordRecognitionCompendium.match(candidates:)` when creating a chord symbol.

## Layer 2: Stroke Extraction

Add a small adapter to convert PencilKit data to recognition-native strokes.

Responsibilities:

- Convert each PencilKit stroke into `InkStroke`.
- Preserve point order.
- Preserve timing if available.
- Normalize coordinates only inside the recognizer, not at extraction time.
- Keep the original `PKDrawing.dataRepresentation()` persisted in the chart model.

Integration point:

- `Chart.pageHandwrittenChordData`
- `Chart.pageHandwrittenNotationData`

Acceptance criteria:

- Unit tests can load JSON fixtures into `InkStroke` without PencilKit.
- UI integration can convert a fresh `PKDrawing` into the same `InkStroke` representation.

## Layer 3: Stroke Grouping

Most recognition regressions will come from grouping, not glyph classification.

Implement `StrokeClusterer` before doing anything clever.

Grouping heuristics:

- group strokes by short time gaps
- group strokes whose bounding boxes overlap or nearly touch
- group small modifiers with nearby roots when they are spatially close
- split left-to-right when there is a clear horizontal gap
- treat slash-bass regions separately after a slash-like stroke

Inputs:

```swift
struct StrokeClustererConfiguration {
    var maxTimeGap: TimeInterval
    var maxHorizontalGapRatio: Double
    var maxVerticalOverlapMissRatio: Double
    var smallModifierSizeRatio: Double
}
```

Important cases:

- `Bb` should group as `B` + flat modifier.
- `F#` should group as `F` + sharp modifier.
- `C-` should group as root + minor mark.
- `Db7b9` should split into usable glyph clusters but compose into one chord candidate.
- Slash bass such as `G/B` should preserve the slash as a separator.

Acceptance criteria:

- Fixture tests prove grouping for `Bb`, `F#`, `C-`, and `Db7b9`.
- Clusterer output is deterministic.
- Clusterer has no knowledge of `ChordSymbol`; it only returns geometry/time clusters.

## Layer 4: Gesture/Glyph Recognition

Implement `GestureTemplateRecognizer` as a constrained recognizer for a small vocabulary.

Initial glyph vocabulary:

- roots: `A`, `B`, `C`, `D`, `E`, `F`, `G`
- accidentals: `#`, `b`
- optional later accidental: natural
- qualities: `m`, `-`
- digits: `7`, `9`, `1`, `3`
- separators: `/`

Template matching approach:

- resample points to a fixed count
- scale to a normalized bounding box while preserving useful aspect-ratio features
- translate to origin/centroid
- compare to templates with a point-cloud or path-distance metric
- return ranked `GlyphCandidate` values, not just one answer

Important detail:

- Keep aspect ratio, width, height, and stroke count as features. A flat, lowercase `b`, and uppercase `B` can look dangerously similar if normalized too aggressively.

Acceptance criteria:

- For every glyph fixture, the expected glyph appears in the top 3.
- Confidence values are stable enough to sort alternatives, but not treated as absolute truth.
- The recognizer can return ambiguity instead of forcing a bad answer.

## Layer 5: Chord Candidate Composition

Add `ChordInkCandidateComposer` to combine glyph candidates into valid chord-string candidates.

Responsibilities:

- Compose root + accidental + quality + extensions + alterations + slash bass.
- Generate multiple candidate strings from ambiguous glyphs.
- Prefer valid chord grammar over raw glyph confidence when appropriate.
- Defer final validation to `ChordRecognitionCompendium` and `ChordSymbolParser`.

Example:

```text
Glyph candidates:
  [B, 8]
  [b, 6]

Composed candidates:
  Bb
  B6
  8b

Compendium result:
  Bb
```

Ranking rules:

- root letters must start a chord candidate
- accidental directly after root is preferred over accidental later
- slash must introduce a bass pitch candidate
- unsupported major suffixes stay rejected by the existing parser/compendium
- candidate strings that parse successfully outrank non-parsing strings

Acceptance criteria:

- `Bb` beats `8b` when both are plausible.
- `F#` beats `F` when a nearby sharp cluster is present with reasonable confidence.
- `C-` and `Cm` normalize to the same minor symbol.
- `Db7b9` can be composed and parsed.

## Layer 6: ChordInkRecognizer Facade

Add `ChordInkRecognizer` as the main API used by the editor.

```swift
protocol ChordInkRecognizing {
    func recognize(strokes: [InkStroke]) -> ChordInkRecognitionResult
}
```

Responsibilities:

- run clustering
- run glyph recognition
- compose chord candidates
- call `ChordRecognitionCompendium.match(candidates:)`
- return best match plus alternatives/debug data

Acceptance criteria:

- Editor code calls one facade.
- Tests can run recognition from JSON fixtures without UI.
- Debug output can explain why a candidate won.

## Layer 7: PencilKit UI Integration

Integrate recognition only after pure Swift tests are useful.

Recommended editor behavior:

- Use `PKCanvasView` for chord-entry overlay.
- Persist raw `PKDrawing.dataRepresentation()` into chart data.
- On stroke completion or short idle timeout, recognize the newest stroke group.
- Show a lightweight candidate popover near the ink.
- Do not immediately mutate the chart model unless confidence is very high and the user has enabled fast entry.

Candidate UI actions:

- accept best candidate
- choose alternate
- edit text manually
- keep as raw ink
- delete/retry

Acceptance criteria:

- A wrong recognition is cheap to correct.
- Raw ink remains available for reinterpretation.
- Committed output is always a structured `ChordEvent` or explicit annotation, not untracked text.

## Layer 8: Committing To The Chart Model

When the user accepts a candidate:

- create or update a `ChordEvent`
- set `rawInput` to the original recognized string or the user-edited text
- preserve the raw PencilKit data separately
- use current measure/beat hit-testing to assign `startPosition`
- use existing measure timing suggestions when available

Do not let recognition own beat placement. Recognition produces musical tokens; layout/editor logic decides where they belong.

Acceptance criteria:

- Accepted chord appears in the chart as structured data.
- Transposition and export use the existing domain model.
- Undo/redo can eventually treat acceptance as a normal editing command.

## Testing Strategy

### Unit tests

Add tests for:

- point normalization
- stroke bounds
- cluster splitting/grouping
- glyph candidate ranking
- chord candidate composition
- final compendium matching

### Fixture tests

Use JSON fixtures under `SmartChartTests/Fixtures/Ink/`.

Each fixture should include:

- name
- strokes
- expected clusters
- expected top glyphs
- expected final display text

Example fixture metadata:

```json
{
  "name": "Bb",
  "expectedDisplayText": "Bb",
  "strokes": []
}
```

### Regression tests

Whenever recognition fails on real iPad input:

1. export the strokes as a fixture
2. add a failing test
3. fix grouping/composition/template logic
4. keep the fixture forever

This is the main guardrail against recurring regressions.

## Milestones

### Milestone 1: Stabilize symbolic recognition

- Expand compendium/parser tests.
- Confirm existing chord spellings and aliases are stable.
- No UI changes.

### Milestone 2: Add pure Swift ink model

- Add `InkPoint`, `InkStroke`, `InkCluster`, and bounds utilities.
- Add JSON fixture loading.
- Add basic tests.

### Milestone 3: Add stroke clustering

- Implement deterministic grouping heuristics.
- Prove grouping with synthetic and captured fixtures.

### Milestone 4: Add glyph templates

- Add minimal glyph recognizer.
- Add templates for roots, accidentals, minor marks, digits, and slash.
- Return ranked candidates.

### Milestone 5: Compose chord candidates

- Convert glyph sequences into chord-string candidates.
- Validate through `ChordRecognitionCompendium.match(candidates:)`.
- Add tests for ambiguous cases.

### Milestone 6: Add PencilKit capture

- Add a chord-entry overlay.
- Persist raw drawing data.
- Recognize new stroke groups after idle timeout.

### Milestone 7: Add candidate UI

- Show best match and alternates.
- Allow accept, alternate selection, manual edit, keep ink, and retry.

### Milestone 8: Commit accepted candidates

- Create/update `ChordEvent` from accepted candidates.
- Preserve raw input and raw ink.
- Use existing transposition/export paths.

### Milestone 9: Expand from real samples

- Record real writing samples from iPad.
- Add fixtures for every failure.
- Add HOMUS-derived accidental tests if useful.

### Milestone 10: Evaluate CoreML only if needed

- If templates cannot handle real-world variation, prototype image/glyph classification.
- Use DeTeXt-style PencilKit -> image -> CoreML flow as a reference.
- Keep the compendium as the final validator even if CoreML is added.

## Non-Goals For The First Pass

Do not implement these initially:

- full handwriting-to-text OCR
- full staff-based music notation recognition
- melody or pitched-note entry
- automatic correction that mutates chart data without user visibility
- cloud-dependent recognition
- OpenAI-dependent live editing
- CoreML training pipeline before simple templates are evaluated

## Risk Areas

### Root vs accidental confusion

`B`, `b`, flat marks, and handwritten `6` can collide. Preserve aspect ratio, relative size, and context.

### Over-normalization

If every glyph is forced into the same square without extra features, musically different marks can become identical. Keep width, height, stroke count, and relative placement.

### Bad grouping

A good glyph recognizer will still fail if the wrong strokes are grouped. Invest in cluster fixtures early.

### Premature auto-commit

Auto-committing wrong symbols makes the app feel untrustworthy. Start with candidate confirmation and add fast entry later.

### Mixing recognition with layout

Recognition should identify tokens. Beat placement, snapping, and page layout should remain deterministic editor responsibilities.

## First Implementation Checklist

- [ ] Add this plan to the repo.
- [ ] Expand `ChordSymbolParserTests` around compendium behavior.
- [ ] Add `SmartChart/Recognition` folder.
- [ ] Add pure Swift ink data types.
- [ ] Add fixture loader for recognition tests.
- [ ] Add `StrokeClusterer` with deterministic heuristics.
- [ ] Add a minimal point-cloud glyph recognizer.
- [ ] Add initial glyph templates.
- [ ] Add `ChordInkCandidateComposer`.
- [ ] Add `ChordInkRecognizer` facade.
- [ ] Wire final matching through `ChordRecognitionCompendium.match(candidates:)`.
- [ ] Add PencilKit capture overlay.
- [ ] Add candidate UI.
- [ ] Commit accepted candidates into `ChordEvent`.
- [ ] Add real iPad handwriting samples as fixtures.

## Success Criteria

The first successful implementation should let a user write simple chord symbols such as:

- `C`
- `Bb`
- `F#`
- `C-`
- `Cm7`
- `Db7b9`
- `G/B`

and receive a structured candidate that can be accepted, corrected, transposed, saved, and exported through the existing Smart Chart model.

The app does not need perfect recognition to feel good. It needs stable recognition, clear alternatives, and fast correction.
