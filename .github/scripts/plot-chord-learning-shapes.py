#!/usr/bin/env python3
import argparse
import collections
import html
import json
import subprocess
from pathlib import Path


NATURAL_SYMBOLS = ["C", "D", "E", "F", "G", "A", "B"]
BOUNDARY_GRID_SIZE = 16


def simulator_id() -> str:
    destination = subprocess.check_output(
        [".github/scripts/select-ipad-simulator.sh"],
        text=True,
    ).strip()
    return destination.removeprefix("SIMULATOR_DESTINATION=platform=iOS Simulator,id=")


def default_learning_path() -> Path:
    sim_id = simulator_id()
    container = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", sim_id, "com.smartchart.app", "data"],
        text=True,
    ).strip()
    return Path(container) / "Library/Application Support/SmartChart/Learning/chord-recognition-confirmed-examples.jsonl"


def load_examples(path: Path) -> list[dict]:
    if not path.exists():
        return []

    return [
        json.loads(line)
        for line in path.read_text().splitlines()
        if line.strip()
    ]


def is_correction(record: dict) -> bool:
    if record.get("wasCorrection") is not None:
        return bool(record.get("wasCorrection"))

    suggestion = record.get("suggestedDisplayText")
    return bool(suggestion and suggestion != record.get("displayText"))


def correction_weight(record: dict) -> float:
    if record.get("correctionWeight") is not None:
        return max(0.25, min(3.0, float(record["correctionWeight"])))

    return 2.5 if is_correction(record) else 1.0


def occupied_cells(ink: dict, grid_size: int = BOUNDARY_GRID_SIZE) -> set[int]:
    cells = set()
    for stroke in ink.get("sampledNormalizedStrokes", []):
        if not stroke:
            continue

        def cell(point: dict) -> int:
            x = min(grid_size - 1, max(0, int(float(point["x"]) * grid_size)))
            y = min(grid_size - 1, max(0, int(float(point["y"]) * grid_size)))
            return y * grid_size + x

        cells.add(cell(stroke[0]))
        for start, end in zip(stroke, stroke[1:]):
            dx = float(end["x"]) - float(start["x"])
            dy = float(end["y"]) - float(start["y"])
            segment_length = (dx * dx + dy * dy) ** 0.5
            steps = max(1, int(segment_length * grid_size * 2 + 0.999))
            for step in range(steps + 1):
                t = step / steps
                cells.add(
                    cell(
                        {
                            "x": float(start["x"]) + dx * t,
                            "y": float(start["y"]) + dy * t,
                        }
                    )
                )
    return cells


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


def boundary_cells(records: list[dict], grid_size: int = BOUNDARY_GRID_SIZE) -> tuple[set[int], set[int], dict[int, float]]:
    if not records:
        return set(), set(), {}

    frequency = collections.Counter()
    total_weight = 0.0
    for record in records:
        weight = correction_weight(record)
        total_weight += weight
        for cell in occupied_cells(record.get("ink", {}), grid_size):
            frequency[cell] += weight

    inner_threshold = max(2.0, total_weight * 0.18)
    outer_threshold = max(1.0, total_weight * 0.035)
    inner = {
        cell
        for cell, value in frequency.items()
        if value >= inner_threshold
    }
    outer = {
        cell
        for cell, value in frequency.items()
        if value >= outer_threshold
    }
    density = {
        cell: value / total_weight
        for cell, value in frequency.items()
    }
    return dilated_cells(outer, grid_size), inner, density


def corrected_negative_cells(
    symbol: str,
    records: list[dict],
    own_density: dict[int, float],
    grid_size: int = BOUNDARY_GRID_SIZE
) -> set[int]:
    false_positive_records = [
        record
        for record in records
        if record.get("displayText") != symbol
        and record.get("suggestedDisplayText") == symbol
    ]
    if not false_positive_records:
        return set()

    frequency = collections.Counter()
    total_weight = 0.0
    for record in false_positive_records:
        weight = correction_weight(record)
        total_weight += weight
        for cell in occupied_cells(record.get("ink", {}), grid_size):
            frequency[cell] += weight
    if total_weight <= 0:
        return set()

    return {
        cell
        for cell, value in frequency.items()
        if value / total_weight >= 0.15
        and value / total_weight - own_density.get(cell, 0.0) >= 0.06
    }


def point_path(stroke: list[dict], x: float, y: float, size: float, padding: float) -> str:
    usable = size - padding * 2
    points = []
    for point in stroke:
        px = x + padding + float(point["x"]) * usable
        py = y + padding + float(point["y"]) * usable
        points.append(f"{px:.2f},{py:.2f}")
    return " ".join(points)


def panel_stats(records: list[dict]) -> tuple[str, str]:
    corrections = [record for record in records if is_correction(record)]
    wrong_guesses = collections.Counter(
        record.get("suggestedDisplayText")
        for record in corrections
        if record.get("suggestedDisplayText")
    )
    weighted_total = sum(correction_weight(record) for record in records)

    summary = f"{len(records)} samples | {len(corrections)} corrected | weight {weighted_total:.1f}"
    if wrong_guesses:
        confusion = ", ".join(
            f"{symbol}:{count}"
            for symbol, count in wrong_guesses.most_common(4)
        )
    else:
        confusion = "no wrong-guess data yet"

    return summary, confusion


def render_svg(records: list[dict], symbols: list[str], output: Path) -> None:
    grouped = collections.defaultdict(list)
    for record in records:
        grouped[record.get("displayText")].append(record)

    panel_size = 220
    gutter = 24
    label_height = 58
    columns = min(4, max(1, len(symbols)))
    rows = (len(symbols) + columns - 1) // columns
    width = columns * panel_size + (columns + 1) * gutter
    height = rows * (panel_size + label_height) + (rows + 1) * gutter

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        "<style>",
        "text { font-family: -apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif; }",
        ".title { font-size: 24px; font-weight: 800; }",
        ".stat { font-size: 12px; fill: #45515f; }",
        ".hint { font-size: 11px; fill: #7c8795; }",
        ".panel { fill: #f8fafc; stroke: #d7dde6; stroke-width: 1.25; }",
        ".grid { stroke: #e6eaf0; stroke-width: 1; }",
        "</style>",
        '<rect x="0" y="0" width="100%" height="100%" fill="#ffffff"/>',
    ]

    for index, symbol in enumerate(symbols):
        column = index % columns
        row = index // columns
        x = gutter + column * (panel_size + gutter)
        y = gutter + row * (panel_size + label_height + gutter)
        symbol_records = grouped.get(symbol, [])
        summary, confusion = panel_stats(symbol_records)
        outer_cells, inner_cells, own_density = boundary_cells(symbol_records)
        negative_cells = corrected_negative_cells(symbol, records, own_density)

        parts.append(f'<rect class="panel" x="{x}" y="{y + label_height}" width="{panel_size}" height="{panel_size}" rx="16"/>')
        parts.append(f'<text class="title" x="{x}" y="{y + 24}">{html.escape(symbol)}</text>')
        parts.append(f'<text class="stat" x="{x + 34}" y="{y + 20}">{html.escape(summary)} | neg {len(negative_cells)}</text>')
        parts.append(f'<text class="hint" x="{x + 34}" y="{y + 39}">misread as {html.escape(confusion)}</text>')

        graph_y = y + label_height
        usable = panel_size - 44
        cell_size = usable / BOUNDARY_GRID_SIZE
        for cell in outer_cells:
            cell_x = cell % BOUNDARY_GRID_SIZE
            cell_y = cell // BOUNDARY_GRID_SIZE
            parts.append(
                f'<rect x="{x + 22 + cell_x * cell_size:.2f}" '
                f'y="{graph_y + 22 + cell_y * cell_size:.2f}" '
                f'width="{cell_size + 0.15:.2f}" height="{cell_size + 0.15:.2f}" '
                f'fill="#38bdf8" opacity="0.13"/>'
            )
        for cell in inner_cells:
            cell_x = cell % BOUNDARY_GRID_SIZE
            cell_y = cell // BOUNDARY_GRID_SIZE
            parts.append(
                f'<rect x="{x + 22 + cell_x * cell_size:.2f}" '
                f'y="{graph_y + 22 + cell_y * cell_size:.2f}" '
                f'width="{cell_size + 0.15:.2f}" height="{cell_size + 0.15:.2f}" '
                f'fill="#f59e0b" opacity="0.24"/>'
            )
        for cell in negative_cells:
            cell_x = cell % BOUNDARY_GRID_SIZE
            cell_y = cell // BOUNDARY_GRID_SIZE
            parts.append(
                f'<rect x="{x + 22 + cell_x * cell_size:.2f}" '
                f'y="{graph_y + 22 + cell_y * cell_size:.2f}" '
                f'width="{cell_size + 0.15:.2f}" height="{cell_size + 0.15:.2f}" '
                f'fill="#ef4444" opacity="0.22"/>'
            )

        for grid_index in range(1, 4):
            grid_x = x + panel_size * grid_index / 4
            grid_y = graph_y + panel_size * grid_index / 4
            parts.append(f'<line class="grid" x1="{grid_x:.2f}" y1="{graph_y}" x2="{grid_x:.2f}" y2="{graph_y + panel_size}"/>')
            parts.append(f'<line class="grid" x1="{x}" y1="{grid_y:.2f}" x2="{x + panel_size}" y2="{grid_y:.2f}"/>')

        for record in symbol_records:
            ink = record.get("ink", {})
            color = "#dc2626" if is_correction(record) else "#0f172a"
            opacity = 0.18 if is_correction(record) else 0.12
            weight = correction_weight(record)
            stroke_width = 1.25 + max(0, weight - 1) * 0.45
            for stroke in ink.get("sampledNormalizedStrokes", []):
                if len(stroke) < 2:
                    continue
                points = point_path(stroke, x, graph_y, panel_size, 22)
                parts.append(
                    f'<polyline points="{points}" fill="none" stroke="{color}" '
                    f'stroke-width="{stroke_width:.2f}" stroke-linecap="round" '
                    f'stroke-linejoin="round" opacity="{opacity:.2f}"/>'
                )

    parts.append("</svg>")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(parts))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Render confirmed Smart Chart chord handwriting examples as per-letter SVG shape clouds."
    )
    parser.add_argument("--learning-path", type=Path, default=None)
    parser.add_argument("--out", type=Path, default=Path("/tmp/smartchart-chord-learning-shapes.svg"))
    parser.add_argument("--symbols", default=",".join(NATURAL_SYMBOLS))
    args = parser.parse_args()

    learning_path = args.learning_path or default_learning_path()
    symbols = [symbol.strip() for symbol in args.symbols.split(",") if symbol.strip()]
    records = load_examples(learning_path)
    render_svg(records, symbols, args.out)
    print(f"Learning examples: {learning_path}")
    print(f"Rendered {len(records)} examples to {args.out}")


if __name__ == "__main__":
    main()
