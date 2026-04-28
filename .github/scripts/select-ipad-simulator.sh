#!/usr/bin/env bash
set -euo pipefail

destination="$(
  SIMCTL_JSON="$(xcrun simctl list devices available -j)" python3 - <<'PY'
import json
import os
import sys

payload = json.loads(os.environ["SIMCTL_JSON"])
candidates = []

for runtime, devices in payload.get("devices", {}).items():
    if "iOS" not in runtime:
        continue

    for device in devices:
        if not device.get("isAvailable", False):
            continue

        name = device.get("name", "")
        udid = device.get("udid")
        if "iPad" in name and udid:
            candidates.append((name, udid))

for preferred_name in ("iPad Air", "iPad Pro", "iPad"):
    for name, udid in candidates:
        if preferred_name in name:
            print(f"platform=iOS Simulator,id={udid}")
            sys.exit(0)

print("No available iPad simulator was found on this runner.", file=sys.stderr)
sys.exit(1)
PY
)"

echo "SIMULATOR_DESTINATION=$destination"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "SIMULATOR_DESTINATION=$destination" >> "$GITHUB_ENV"
fi
