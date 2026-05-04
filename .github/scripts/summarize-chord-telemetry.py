#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import subprocess
from pathlib import Path


BOUNDARY_GRID_SIZE = 16
MINIMUM_BOUNDARY_EXAMPLES = 5
NATURAL_SYMBOLS = ["C", "D", "E", "F", "G", "A", "B"]


def simulator_id() -> str:
    destination = subprocess.check_output(
        [".github/scripts/select-ipad-simulator.sh"],
        text=True,
    ).strip()
    return destination.removeprefix("SIMULATOR_DESTINATION=platform=iOS Simulator,id=")


def default_telemetry_path() -> Path:
    sim_id = simulator_id()
    container = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", sim_id, "com.smartchart.app", "data"],
        text=True,
    ).strip()
    return Path(container) / "Library/Application Support/SmartChart/Debug/chord-recognition-telemetry.jsonl"


def default_learning_path() -> Path:
    sim_id = simulator_id()
    container = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", sim_id, "com.smartchart.app", "data"],
        text=True,
    ).strip()
    return Path(container) / "Library/Application Support/SmartChart/Learning/chord-recognition-confirmed-examples.jsonl"


def load_records(path: Path) -> list[dict]:
    if not path.exists():
        return []

    records = []
    for line in path.read_text().splitlines():
        if line.strip():
            records.append(json.loads(line))
    return records


def counter_line(title: str, counter: collections.Counter) -> None:
    print(title)
    if not counter:
        print("  none")
        return

    for key, value in counter.most_common():
        print(f"  {key}: {value}")


def is_correction(record: dict) -> bool:
    if record.get("wasCorrection") is not None:
        return bool(record.get("wasCorrection"))

    suggestion = record.get("suggestedDisplayText")
    return bool(suggestion and suggestion != record.get("displayText"))


def effective_weight(record: dict) -> float:
    if record.get("effectiveWeight") is not None:
        return max(0.25, min(3.0, float(record["effectiveWeight"])))

    if record.get("correctionWeight") is not None:
        return max(0.25, min(3.0, float(record["correctionWeight"])))

    return 2.5 if is_correction(record) else 1.0


def occupied_cells(ink: dict, grid_size: int = BOUNDARY_GRID_SIZE) -> set[int]:
    cells = set()
    for stroke in ink.get("sampledNormalizedStrokes", []):
        if not stroke:
            continue

        cells.add(cell_for_point(stroke[0], grid_size))
        for start, end in zip(stroke, stroke[1:]):
            dx = float(end["x"]) - float(start["x"])
            dy = float(end["y"]) - float(start["y"])
            segment_length = (dx * dx + dy * dy) ** 0.5
            steps = max(1, int(segment_length * grid_size * 2 + 0.999))
            for step in range(steps + 1):
                t = step / steps
                cells.add(
                    cell_for_point(
                        {
                            "x": float(start["x"]) + dx * t,
                            "y": float(start["y"]) + dy * t,
                        },
                        grid_size,
                    )
                )

    return cells


def cell_for_point(point: dict, grid_size: int) -> int:
    x = min(grid_size - 1, max(0, int(float(point["x"]) * grid_size)))
    y = min(grid_size - 1, max(0, int(float(point["y"]) * grid_size)))
    return y * grid_size + x


def dilated_cells(cells: set[int], grid_size: int = BOUNDARY_GRID_SIZE) -> set[int]:
    dilated = set(cells)
    for cell in cells:
        x = cell % grid_size
        y = cell // grid_size
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                next_x = x + dx
                next_y = y + dy
                if 0 <= next_x < grid_size and 0 <= next_y < grid_size:
                    dilated.add(next_y * grid_size + next_x)
    return dilated


def boundary_model(records: list[dict], grid_size: int = BOUNDARY_GRID_SIZE) -> dict | None:
    if len(records) < MINIMUM_BOUNDARY_EXAMPLES:
        return None

    frequency = collections.Counter()
    total_weight = 0.0
    aspect_total = 0.0
    aspect_weight = 0.0
    for record in records:
        weight = effective_weight(record)
        total_weight += weight
        for cell in occupied_cells(record.get("ink", {}), grid_size):
            frequency[cell] += weight
        aspect_ratio = float(record.get("ink", {}).get("aspectRatio") or 1.0)
        aspect_total += aspect_ratio * weight
        aspect_weight += weight

    if total_weight <= 0:
        return None

    inner_threshold = max(2.0, total_weight * 0.18)
    outer_threshold = max(1.0, total_weight * 0.035)
    inner = {cell for cell, value in frequency.items() if value >= inner_threshold}
    raw_outer = {cell for cell, value in frequency.items() if value >= outer_threshold}
    if not inner or not raw_outer:
        return None

    outer = dilated_cells(raw_outer, grid_size)
    return {
        "inner": inner,
        "outer": outer,
        "ambiguous": outer.difference(inner),
        "correctedNegative": set(),
        "competitiveNegative": set(),
        "density": {cell: value / total_weight for cell, value in frequency.items()},
        "averageAspectRatio": aspect_total / max(1.0, aspect_weight),
    }


def apply_negative_evidence(models: dict[str, dict], grouped: dict[str, list[dict]]) -> None:
    all_records = [
        record
        for records in grouped.values()
        for record in records
    ]
    for symbol, model in models.items():
        false_positives = [
            record
            for record in all_records
            if record.get("displayText") != symbol
            and record.get("suggestedDisplayText") == symbol
        ]
        model["correctedNegative"] = corrected_negative_cells(false_positives, model)
        model["competitiveNegative"] = competitive_negative_cells(symbol, model, models)


def corrected_negative_cells(records: list[dict], model: dict) -> set[int]:
    if not records:
        return set()

    frequency = collections.Counter()
    total_weight = 0.0
    for record in records:
        weight = effective_weight(record)
        total_weight += weight
        for cell in occupied_cells(record.get("ink", {})):
            frequency[cell] += weight
    if total_weight <= 0:
        return set()

    return {
        cell
        for cell, value in frequency.items()
        if value / total_weight >= 0.15
        and value / total_weight - model["density"].get(cell, 0.0) >= 0.06
    }


def competitive_negative_cells(symbol: str, model: dict, models: dict[str, dict]) -> set[int]:
    cells = set()
    for cell in range(BOUNDARY_GRID_SIZE * BOUNDARY_GRID_SIZE):
        own_density = model["density"].get(cell, 0.0)
        competing_density = max(
            (
                other_model["density"].get(cell, 0.0)
                for other_symbol, other_model in models.items()
                if other_symbol != symbol
            ),
            default=0.0,
        )
        if competing_density >= 0.22 and competing_density - own_density >= 0.12:
            cells.add(cell)
    return cells


def score_boundary(record: dict, model: dict, grid_size: int = BOUNDARY_GRID_SIZE) -> dict:
    input_cells = occupied_cells(record.get("ink", {}), grid_size)
    if not input_cells:
        return {
            "accuracy": 0.0,
            "innerHit": 0.0,
            "outerContainment": 0.0,
            "contrast": 0.0,
            "correctedNegativeHit": 0.0,
        }

    inner = model["inner"]
    outer = model["outer"]
    ambiguous = model["ambiguous"]
    corrected_negative = model["correctedNegative"]
    competitive_negative = model["competitiveNegative"]
    inner_hit = len(input_cells.intersection(inner)) / max(1, len(inner))
    inner_precision = len(input_cells.intersection(inner)) / max(1, len(input_cells))
    outer_containment = len(input_cells.intersection(outer)) / max(1, len(input_cells))
    stray_penalty = len(input_cells.difference(outer)) / max(1, len(input_cells))
    ambiguous_penalty = len(input_cells.intersection(ambiguous)) / max(1, len(input_cells))
    corrected_negative_hit = len(input_cells.intersection(corrected_negative)) / max(1, len(input_cells))
    competitive_negative_hit = len(input_cells.intersection(competitive_negative)) / max(1, len(input_cells))
    aspect_ratio = float(record.get("ink", {}).get("aspectRatio") or model["averageAspectRatio"])
    aspect_fit = max(0.0, 1.0 - abs(aspect_ratio - model["averageAspectRatio"]) / 1.15)
    accuracy = min(
        1.0,
        max(
            0.0,
            inner_hit * 0.44
            + inner_precision * 0.10
            + outer_containment * 0.30
            + aspect_fit * 0.15
            - stray_penalty * 0.16
            - ambiguous_penalty * 0.04
            - corrected_negative_hit * 0.14
            - competitive_negative_hit * 0.06,
        ),
    )
    return {
        "accuracy": accuracy,
        "innerHit": inner_hit,
        "outerContainment": outer_containment,
        "contrast": max(0.0, outer_containment - stray_penalty - corrected_negative_hit),
        "correctedNegativeHit": corrected_negative_hit,
    }


def percent(value: float) -> str:
    return f"{value * 100:.1f}%"


def average(values: list[float]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)


def print_boundary_summary(learning_records: list[dict]) -> None:
    grouped = collections.defaultdict(list)
    for record in learning_records:
        display_text = record.get("displayText")
        if display_text in NATURAL_SYMBOLS:
            grouped[display_text].append(record)

    models = {
        symbol: model
        for symbol in NATURAL_SYMBOLS
        if (model := boundary_model(grouped[symbol])) is not None
    }
    if not models:
        return
    apply_negative_evidence(models, grouped)

    print("Boundary hit model:")
    print("  accuracy combines innerHit, outerContainment, aspectFit, stray-ink penalty, and corrected negative hits")
    for symbol in NATURAL_SYMBOLS:
        records = grouped[symbol]
        model = models.get(symbol)
        if not records or model is None:
            continue

        own_scores = [score_boundary(record, model) for record in records]
        competing_high_scores = []
        for record in records:
            competing_scores = [
                score_boundary(record, competing_model)["accuracy"]
                for competing_symbol, competing_model in models.items()
                if competing_symbol != symbol
            ]
            if competing_scores:
                competing_high_scores.append(max(competing_scores))

        print(
            "  "
            f"{symbol}: "
            f"samples={len(records)} "
            f"innerCells={len(model['inner'])} "
            f"outerCells={len(model['outer'])} "
            f"negativeCells={len(model['correctedNegative'])} "
            f"ownAvg={percent(average([score['accuracy'] for score in own_scores]))} "
            f"ownLow={percent(min(score['accuracy'] for score in own_scores))} "
            f"innerAvg={percent(average([score['innerHit'] for score in own_scores]))} "
            f"outerAvg={percent(average([score['outerContainment'] for score in own_scores]))} "
            f"negativeAvg={percent(average([score['correctedNegativeHit'] for score in own_scores]))} "
            f"competeAvg={percent(average(competing_high_scores))} "
            f"competeHigh={percent(max(competing_high_scores or [0.0]))}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Summarize Smart Chart chord recognition telemetry.")
    parser.add_argument("--path", type=Path, default=None, help="Optional telemetry JSONL path.")
    parser.add_argument("--learning-path", type=Path, default=None, help="Optional confirmed learning examples JSONL path.")
    parser.add_argument("--recent", type=int, default=8, help="Recent attempts to print.")
    args = parser.parse_args()

    path = args.path or default_telemetry_path()
    records = load_records(path)
    print(f"Telemetry: {path}")
    print(f"Attempts: {len(records)}")
    if not records:
        return

    counter_line("Outcomes:", collections.Counter(record.get("outcome", "unknown") for record in records))
    counter_line("Best symbols:", collections.Counter(record.get("bestDisplayText") or "none" for record in records))
    counter_line("Winning methods:", collections.Counter(record.get("bestMethod") or "none" for record in records))

    method_candidates = collections.Counter()
    method_symbol_candidates = collections.Counter()
    correction_penalty_attempts = 0
    correction_penalty_candidates = collections.Counter()
    for record in records:
        record_has_correction_penalty = False
        for candidate in record.get("methodCandidates", []):
            method = candidate.get("method", "unknown")
            display_text = candidate.get("displayText") or "none"
            method_candidates[method] += 1
            method_symbol_candidates[f"{method}:{display_text}"] += 1
            if "learnedCorrectionPenalty=" in (candidate.get("debugSummary") or ""):
                record_has_correction_penalty = True
                correction_penalty_candidates[f"{method}:{display_text}"] += 1
        if record_has_correction_penalty:
            correction_penalty_attempts += 1
    counter_line("Candidate emissions:", method_candidates)
    counter_line("Candidate symbols:", method_symbol_candidates)
    print(f"Learned correction penalty attempts: {correction_penalty_attempts}")
    counter_line("Learned correction penalty candidates:", correction_penalty_candidates)

    print("Recent attempts:")
    for record in records[-args.recent:]:
        confidence = record.get("bestConfidence")
        confidence_text = "none" if confidence is None else f"{confidence:.2f}"
        print(
            "  "
            f"{record.get('timestamp')} "
            f"outcome={record.get('outcome')} "
            f"best={record.get('bestDisplayText') or 'none'} "
            f"method={record.get('bestMethod') or 'none'} "
            f"confidence={confidence_text} "
            f"summary={record.get('reportSummary', 'none')}"
        )

    learning_path = args.learning_path or default_learning_path()
    learning_records = load_records(learning_path)
    print(f"Confirmed learning examples: {learning_path}")
    print(f"Examples: {len(learning_records)}")
    counter_line("Example symbols:", collections.Counter(record.get("displayText") or "none" for record in learning_records))
    correction_records = [
        record
        for record in learning_records
        if record.get("wasCorrection") or (
            record.get("suggestedDisplayText")
            and record.get("suggestedDisplayText") != record.get("displayText")
        )
    ]
    print(f"Corrections: {len(correction_records)}")
    counter_line("Correction targets:", collections.Counter(record.get("displayText") or "none" for record in correction_records))
    counter_line(
        "Wrong guesses:",
        collections.Counter(
            f"{record.get('suggestedDisplayText') or 'none'} -> {record.get('displayText') or 'none'}"
            for record in correction_records
        ),
    )
    print_boundary_summary(learning_records)
    if learning_records:
        print("Recent examples:")
        for record in learning_records[-args.recent:]:
            confidence = record.get("sourceConfidence")
            confidence_text = "none" if confidence is None else f"{confidence:.2f}"
            correction_text = " correction" if record.get("wasCorrection") else ""
            print(
                "  "
                f"{record.get('createdAt')} "
                f"symbol={record.get('displayText') or 'none'} "
                f"suggested={record.get('suggestedDisplayText') or 'none'} "
                f"sourceMethod={record.get('sourceMethod') or 'none'} "
                f"sourceConfidence={confidence_text}"
                f"{correction_text}"
            )


if __name__ == "__main__":
    main()
