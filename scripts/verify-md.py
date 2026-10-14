#!/usr/bin/env python3
"""General markdown-file verifier for the Hermes hardening guide.

Run from the repo root, passing one or more markdown files:

    python3 scripts/verify-md.py hermes-agent/README.md hermes-agent/pipelock.md

Checks performed for each file:
  - Relative markdown links and images resolve to real files/directories.
  - Fenced shell blocks (bash/sh/shell/zsh) parse with `bash -n`.
  - Common placeholders (e.g. <YOUR_KEY>, X.Y.Z, YOUR_*) are flagged.

Broken links/images cause a non-zero exit. Shell syntax warnings are printed
but do not fail the run unless --strict is used.
"""

import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent

LINK_RE = re.compile(r"!?\[(?:[^\]]*)\]\(([^)]+)\)")
FENCE_RE = re.compile(
    r"```(?:bash|sh|shell|zsh)\n(.*?)```",
    re.DOTALL | re.IGNORECASE,
)
PLACEHOLDER_RE = re.compile(r"<[^>\s]+>|YOUR_[A-Z_]+|X\.Y\.Z|x\.y\.z|\{\{[^}]+\}\}")


def _resolve_link(link: str, base_dir: pathlib.Path) -> pathlib.Path | None:
    """Resolve a relative link against the directory that contains the markdown file."""
    if not link or link.startswith(("http://", "https://", "mailto:", "#")):
        return None
    target_name = link.split("#")[0]
    if not target_name:
        return None
    return (base_dir / target_name).resolve()


def check_links(md_path: pathlib.Path, text: str) -> list[str]:
    """Verify every relative link/image resolves."""
    errors = []
    base_dir = md_path.parent
    for match in LINK_RE.finditer(text):
        link = match.group(1)
        target = _resolve_link(link, base_dir)
        if target is None:
            continue
        if not target.exists():
            errors.append(f"Broken link/image: {link}")
        elif link.endswith(".md") and not target.is_file():
            errors.append(f"Markdown link target is not a file: {link}")
    return errors


def _sanitize_for_bash(block: str) -> str:
    """Prepare a snippet so `bash -n` can check syntax.

    - Strips common prompts ($ or >) from the start of lines.
    - Replaces placeholder tokens like <YOUR_KEY> with a safe word so they
      are not misread as redirections or operators.
    """
    lines = []
    for raw_line in block.splitlines():
        line = raw_line.lstrip()
        if line.startswith(("$ ", "> ")):
            line = line[2:]
        elif line.startswith(("$", ">")):
            line = line[1:]
        # Replace placeholders, but keep the line structure.
        line = PLACEHOLDER_RE.sub("__PLACEHOLDER__", line)
        lines.append(line)
    return "\n".join(lines) + "\n"


def check_shell_blocks(md_path: pathlib.Path, text: str, strict: bool) -> tuple[list[str], list[str]]:
    """Run `bash -n` on every fenced shell block.

    Returns (warnings, errors). Errors only produced in strict mode.
    """
    warnings = []
    errors = []
    blocks = FENCE_RE.findall(text)
    for idx, raw_block in enumerate(blocks, start=1):
        sanitized = _sanitize_for_bash(raw_block)
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".sh", delete=False
        ) as tmp:
            tmp.write(sanitized)
            tmp_path = pathlib.Path(tmp.name)
        try:
            result = subprocess.run(
                ["bash", "-n", str(tmp_path)],
                capture_output=True,
                text=True,
            )
        finally:
            tmp_path.unlink(missing_ok=True)

        if result.returncode != 0:
            msg = (
                f"Shell block #{idx} syntax warning\n"
                f"  {result.stderr.strip() or '(unknown parse error)'}"
            )
            if strict:
                errors.append(msg)
            else:
                warnings.append(msg)
    return warnings, errors


def check_placeholders(md_path: pathlib.Path, text: str) -> list[str]:
    """Flag placeholders that a reader must fill in before running commands."""
    warnings = []
    for match in PLACEHOLDER_RE.finditer(text):
        warnings.append(f"Placeholder: {match.group(0)!r}")
    return warnings


def verify_file(md_path: pathlib.Path, strict: bool) -> dict:
    """Run all checks against a single markdown file and return results."""
    text = md_path.read_text()
    link_errors = check_links(md_path, text)
    shell_warnings, shell_errors = check_shell_blocks(md_path, text, strict)
    placeholder_warnings = check_placeholders(md_path, text)

    return {
        "link_errors": link_errors,
        "shell_warnings": shell_warnings,
        "shell_errors": shell_errors,
        "placeholder_warnings": placeholder_warnings,
    }


def _print_section(title: str, items: list[str]) -> None:
    if not items:
        print(f"  OK: {title}")
        return
    print(f"  {title}: {len(items)}")
    for item in items:
        # Indent multi-line items.
        for line in item.splitlines():
            print(f"    - {line}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify markdown files in the Hermes hardening guide."
    )
    parser.add_argument(
        "files",
        nargs="+",
        help="Markdown file paths (relative to repo root or absolute).",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat shell syntax warnings as errors.",
    )
    args = parser.parse_args(argv)

    total_link_errors = 0
    total_shell_errors = 0

    for file_arg in args.files:
        md_path = pathlib.Path(file_arg)
        if not md_path.is_absolute():
            md_path = ROOT / md_path
        md_path = md_path.resolve()

        if not md_path.exists():
            print(f"File not found: {file_arg}")
            return 1
        if not md_path.is_file():
            print(f"Not a file: {file_arg}")
            return 1

        rel_path = md_path.relative_to(ROOT)
        print(f"\n=== {rel_path} ===")
        results = verify_file(md_path, args.strict)

        _print_section("Broken links/images", results["link_errors"])
        _print_section("Shell syntax warnings", results["shell_warnings"])
        _print_section("Shell syntax errors", results["shell_errors"])
        _print_section("Placeholders to review", results["placeholder_warnings"])

        total_link_errors += len(results["link_errors"])
        total_shell_errors += len(results["shell_errors"])

    print("\n=== Summary ===")
    print(f"  Broken links/images: {total_link_errors}")
    print(f"  Shell syntax errors: {total_shell_errors}")

    if total_link_errors or total_shell_errors:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
