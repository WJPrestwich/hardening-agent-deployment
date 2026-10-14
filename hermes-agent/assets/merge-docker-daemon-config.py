#!/usr/bin/env python3
"""Merge the hardening daemon.json asset into an existing /etc/docker/daemon.json.

This preserves existing keys (especially the NVIDIA runtime block) and adds any
missing keys from the asset. It backs up the existing config before writing."""

import argparse
import json
import pathlib
import shutil
import sys
from datetime import datetime, timezone


def merge(base: dict, update: dict) -> dict:
    """Recursively merge update into base without overwriting existing values."""
    for key, value in update.items():
        if isinstance(value, dict) and key in base and isinstance(base[key], dict):
            merge(base[key], value)
        elif key not in base:
            base[key] = value
    return base


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Merge Hermes hardening keys into /etc/docker/daemon.json"
    )
    parser.add_argument(
        "--target",
        default="/etc/docker/daemon.json",
        help="Path to the existing daemon.json (default: /etc/docker/daemon.json)",
    )
    parser.add_argument(
        "--asset",
        default="hermes-agent/assets/daemon.json",
        help="Path to the hardening daemon.json asset",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the merged config instead of writing it",
    )
    args = parser.parse_args()

    target_path = pathlib.Path(args.target)
    asset_path = pathlib.Path(args.asset)

    if not target_path.exists():
        print(f"ERROR: target file does not exist: {target_path}", file=sys.stderr)
        return 1
    if not asset_path.exists():
        print(f"ERROR: asset file does not exist: {asset_path}", file=sys.stderr)
        return 1

    try:
        existing = json.loads(target_path.read_text())
    except json.JSONDecodeError as exc:
        print(f"ERROR: existing daemon.json is invalid JSON: {exc}", file=sys.stderr)
        return 1

    try:
        asset = json.loads(asset_path.read_text())
    except json.JSONDecodeError as exc:
        print(f"ERROR: asset daemon.json is invalid JSON: {exc}", file=sys.stderr)
        return 1

    merged = merge(existing, asset)

    # Sanity check: the NVIDIA runtime should still be present.
    if "runtimes" not in merged or "nvidia" not in merged.get("runtimes", {}):
        print(
            "ERROR: merged config would lose the NVIDIA runtime. Aborting.",
            file=sys.stderr,
        )
        return 1

    if args.dry_run:
        print(json.dumps(merged, indent=2))
        return 0

    backup_name = (
        f"{target_path}.bak."
        f"{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}"
    )
    shutil.copy2(target_path, backup_name)
    print(f"Backed up existing config to {backup_name}")

    target_path.write_text(json.dumps(merged, indent=2) + "\n")
    print(f"Merged config written to {target_path}")

    # Final validation
    try:
        json.loads(target_path.read_text())
        print("JSON validation: OK")
    except json.JSONDecodeError as exc:
        print(f"ERROR: written config is invalid JSON: {exc}", file=sys.stderr)
        return 1

    if "nvidia" in merged.get("runtimes", {}):
        print("NVIDIA runtime preserved: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
