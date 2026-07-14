#!/usr/bin/env python3
"""Validate Supabase migration hygiene before CI/deploy."""

from __future__ import annotations

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
MIGRATIONS_DIR = ROOT / "supabase" / "migrations"

FILENAME_PATTERN = re.compile(r"^(?P<number>\d{3})_[a-z0-9_]+\.sql$")
FORBIDDEN_PATTERNS = {
    "live_supabase_project_url": re.compile(r"https://[a-z0-9]{20}\.supabase\.co"),
    "supabase_jwt": re.compile(
        r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"
    ),
    "firebase_api_key": re.compile(r"AIza[0-9A-Za-z_-]{35}"),
    "revenuecat_public_key": re.compile(r"\b(?:goog|appl)_[0-9A-Za-z]{16,}\b"),
}


def main() -> int:
    if not MIGRATIONS_DIR.exists():
        print(f"Missing migrations directory: {MIGRATIONS_DIR.relative_to(ROOT)}")
        return 1

    findings: list[str] = []
    seen_numbers: dict[str, str] = {}

    migration_files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if not migration_files:
        findings.append("supabase/migrations has no SQL migrations.")

    for path in migration_files:
        relative = path.relative_to(ROOT)
        match = FILENAME_PATTERN.match(path.name)
        if not match:
            findings.append(f"{relative}: filename must match NNN_snake_case.sql")
            continue

        number = match.group("number")
        previous = seen_numbers.get(number)
        if previous is not None:
            findings.append(f"{relative}: duplicate migration number {number}; first used by {previous}")
        seen_numbers[number] = str(relative)

        text = path.read_text(encoding="utf-8")
        for line_no, line in enumerate(text.splitlines(), start=1):
            for label, pattern in FORBIDDEN_PATTERNS.items():
                if pattern.search(line):
                    findings.append(f"{relative}:{line_no}: forbidden {label}")

    numeric_order = [int(path.name.split("_", 1)[0]) for path in migration_files if FILENAME_PATTERN.match(path.name)]
    if numeric_order != sorted(numeric_order):
        findings.append("Migration files are not sorted by ascending numeric prefix.")

    if findings:
        print("Supabase migration validation failed:")
        print("\n".join(findings))
        return 1

    print(f"Supabase migration validation passed ({len(migration_files)} files).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
