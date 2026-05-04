# Chord Recognition Pipeline v3

This pass makes chord recognition confirmation-first while the recognizer is still learning accidentals and chord qualities. The goal is to restore the clean, high-confidence loop from v1 and v2: recognize one clear layer at a time, ask when the structure is not proven, and only let confirmed examples influence future reads.

## Current Flow

1. User writes in the chord band.
2. Canvas creates a chord recognition scope from the written ink and target measure.
3. `ChordSymbolRecognizer` runs the recognition pipeline.
4. The pipeline gathers text candidates, learned natural-root candidates, visual root candidates, raster candidates, accidental-root candidates, and minor-quality candidates.
5. The report resolves candidates by symbol, applies close-race rules in a fixed order, then sorts by confidence and stable musical tie-breakers.
6. Decision policy decides whether the result can be placed automatically.
7. In v3, the policy always routes recognized candidates through confirmation before placement.
8. Confirmation stores the rendered chord and writes a learning example linked to the exact telemetry record.

```text
Chord ink
  -> scope to measure + beat fraction
  -> ChordSymbolRecognizer
  -> ChordRecognitionPipeline
     -> OCR exact text
     -> minor-quality suffix pass
     -> accidental-root pass
     -> natural-root fallback pass
     -> correction-pressure pass
  -> ChordRecognitionReport
     -> group candidates by symbol
     -> extract typed evidence: root / accidental / quality
     -> method-agreement boost
     -> confirmed-example close-race resolver
     -> natural-minor resolver
     -> Bb-minor resolver
     -> flat-minor direct-root resolver
     -> accidental-root resolver
  -> ChordRecognitionDecisionPolicy
  -> confirmation sheet
  -> rendered chord + linked learning example
```

## Confidence Model

High confidence is no longer treated as just one numeric score. A trustworthy chord needs three kinds of agreement:

- Structural agreement: root, accidental, and quality must be visibly supported when present.
- Method agreement: visual, text, raster, and learned examples should not contradict each other in close races.
- User-confirmed agreement: corrections become negative examples for the wrong symbol and positive examples for the chosen symbol.

Telemetry now records whether a candidate would have auto-accepted, whether confirmation was required, the confidence margin, and an intent audit summary such as root evidence, accidental evidence, and minor evidence.

Structural evidence is now tracked as typed component support instead of loose string checks. A candidate can carry `root`, `accidental`, or `quality` evidence from text, visual root geometry, visual accidental geometry, visual minor-suffix geometry, learned examples, learned boundaries, or raster templates. Learned whole-symbol matches are allowed to support the root, but they do not smuggle in sharp, flat, or minor quality unless the candidate also has explicit component evidence for those layers.

## Current File Boundaries

- `ChordRecognition.swift`: owns the recognizer internals, classifiers, candidate scoring, close-race resolvers, and the current compatibility shims for older `BasicMajor...` test names.
- `ChordRecognitionCompendium.swift`: owns supported chord spellings and OCR words. `BasicMajorChordCompendium` now remains only as a compatibility wrapper for older tests and call sites.
- `ChordRecognitionIntent.swift`: owns component evidence, intent warnings, and the confirmation-first decision policy.
- `ChordRecognitionLearning.swift`: owns confirmed examples, active learning compaction, bundled seeds, and positive/negative correction examples.
- `ChordRecognitionTelemetry.swift`: owns the observable record of what the recognizer suggested, what the user confirmed, and which candidates were raw versus resolved.

This is not the final split, but it gives us the first clean seam: intent policy is now separate from symbol classification. Future chord layers should plug into component evidence before they are allowed to influence rendered output.

## Full Flow Mockup

```text
Ink strokes in chord band
  -> Scope
     -> measure id
     -> written beat fraction
     -> local ink sample
  -> Recognition
     -> text candidates
     -> root candidates
     -> accidental candidates
     -> quality candidates
     -> learned candidates
  -> Evidence
     -> root support
     -> accidental support
     -> quality support
  -> Resolve
     -> group by rendered symbol
     -> apply method agreement
     -> apply learned positive/negative pressure
     -> handle close races
  -> Decide
     -> require confirmation in v3
     -> show top candidate plus alternatives
  -> Confirm
     -> render chord at snapped beat
     -> store positive example for chosen symbol
     -> store negative examples for wrong close candidates
     -> persist telemetry linked to the decision
```

## How We Got Back To Higher Confidence

The successful v1/v2 behavior came from separating the problem into small recognizers instead of trying to guess the whole chord at once. The v3 cleanup brings that idea back:

- First, natural root recognition regained stable C through B behavior through visual geometry, raster templates, confirmed examples, and close-race correction pressure.
- Next, sharps and flats became separate root attachments instead of being allowed to rewrite the base letter.
- Then minor quality became a suffix layer, standardized to `-`, with special handling for dash, `m`, and `min`.
- Finally, confirmation-first mode guarantees that every rendered chord can become training data instead of silently auto-accepting guesses.

## Continuing Forward

For extensions and richer chord structures, the rule should stay strict: add a recognizer for one component, add typed evidence for that component, and only then let recomposition produce a richer symbol. The next likely components are `extension` for `7`, `6`, `9`, `11`, `13`; `alteration` for `b9`, `#11`, and similar; and `slashBass` for bass notes after `/`.

## Why We Moved Back To Confirmation-First

The active learning cleanup reduced the recognition pool dramatically, but telemetry showed that many recognitions still bypassed the correction loop. That meant our learning data was only seeing the guesses that asked for confirmation, not all rendered guesses. For v3, every accepted chord must pass through confirmation so the data has ground truth again.

## Next Structure Layers

The next durable step is to split recognition into explicit sub-recognizers:

- Root recognizer: C through B, independent of suffix or accidental.
- Accidental recognizer: sharp or flat, attached to the root only when spatially and visually supported.
- Quality recognizer: major by absence, minor by dash, `m`, or `min`.
- Extension recognizer: future layer for 7, maj7, diminished, augmented, altered tensions, and slash bass.
- Recomposer: combines only compatible parts into a chord symbol.
- Decision policy: auto-accepts only after enough real-world confirmed telemetry proves the structure is stable.

This lets us add richer chord structures without every new symbol polluting every other symbol's confidence.
