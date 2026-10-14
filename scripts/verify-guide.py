#!/usr/bin/env python3
"""Quick sanity checks for the Hermes hardening guide.

Run from the repo root:
    python3 scripts/verify-guide.py
"""

import json
import pathlib
import py_compile
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HERMES_DIR = ROOT / "hermes-agent"
ASSETS = HERMES_DIR / "assets"


def check_json_assets() -> list[str]:
    errors = []
    for path in ASSETS.glob("*.json"):
        try:
            json.loads(path.read_text())
        except json.JSONDecodeError as exc:
            errors.append(f"Invalid JSON in {path.relative_to(ROOT)}: {exc}")
    return errors


def check_yaml_assets() -> list[str]:
    errors = []
    # We only check that YAML files parse if PyYAML is available.
    try:
        import yaml
    except ImportError:
        print("PyYAML not installed; skipping YAML parse checks")
        return errors

    for path in ASSETS.glob("*.yaml"):
        try:
            yaml.safe_load(path.read_text())
        except yaml.YAMLError as exc:
            errors.append(f"Invalid YAML in {path.relative_to(ROOT)}: {exc}")
    return errors


def check_merge_snippet() -> list[str]:
    """Verify the Python merge script for daemon.json compiles."""
    errors = []
    script_path = ASSETS / "merge-docker-daemon-config.py"
    if not script_path.exists():
        errors.append(f"Merge script not found: {script_path.relative_to(ROOT)}")
        return errors

    try:
        py_compile.compile(str(script_path), doraise=True)
    except py_compile.PyCompileError as exc:
        errors.append(f"Merge script does not compile: {exc}")
    return errors


def check_internal_links() -> list[str]:
    errors = []
    link_pattern = re.compile(r"\]\(([^)]+)\)")
    for md_path in HERMES_DIR.rglob("*.md"):
        text = md_path.read_text()
        for link in link_pattern.findall(text):
            # Skip external links and anchors.
            if link.startswith(("http://", "https://", "#", "mailto:")):
                continue
            # Strip anchor.
            target_name = link.split("#")[0]
            # Resolve relative to the directory containing the markdown file.
            target = md_path.parent / target_name
            if not target.exists():
                errors.append(
                    f"Broken link in {md_path.relative_to(ROOT)}: {link}"
                )
    return errors


def check_version_placeholders() -> list[str]:
    """Flag leftover inconsistent HERMES_VERSION placeholders."""
    errors = []
    expected = r"HERMES_VERSION\s*=\s*X\.Y\.Z"
    bad_patterns = [
        r"HERMES_VERSION\s*=\s*0\.\d+\.\d+",
        r"HERMES_VERSION\s*=\s*1\.x\.y",
        r"HERMES_VERSION=<scanned-tag>",
        r"VLLM_VERSION\s*=\s*0\.x\.y",
    ]
    for md_path in HERMES_DIR.glob("*.md"):
        text = md_path.read_text()
        for pattern in bad_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                errors.append(
                    f"Inconsistent version placeholder in {md_path.relative_to(ROOT)}: {pattern}"
                )
    return errors


def main() -> int:
    checks = [
        ("JSON assets", check_json_assets),
        ("YAML assets", check_yaml_assets),
        ("Merge snippet compiles", check_merge_snippet),
        ("Internal markdown links", check_internal_links),
        ("Version placeholders", check_version_placeholders),
    ]

    all_errors = []
    for name, fn in checks:
        errors = fn()
        status = "OK" if not errors else f"{len(errors)} error(s)"
        print(f"[{status}] {name}")
        all_errors.extend(errors)

    if all_errors:
        print("\nDetails:")
        for err in all_errors:
            print(f"  - {err}")
        return 1

    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
