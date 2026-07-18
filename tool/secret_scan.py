#!/usr/bin/env python3
"""Fail CI when live project config is committed to the repository."""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]

SKIP_DIRS = {
    ".git",
    ".dart_tool",
    ".idea",
    ".vscode",
    "build",
    "node_modules",
    ".next",
    ".vercel",
    "coverage",
}

# Firebase's mobile client configuration is intentionally shipped inside the
# application. These identifiers are not server credentials; access is
# controlled with Firebase rules, API restrictions, App Check and SHA-bound
# Android clients. Keep them out of generic secret findings while continuing to
# scan every other committed source file.
PUBLIC_MOBILE_CONFIG = {
    pathlib.Path("android/app/google-services.json"),
    pathlib.Path("ios/Runner/GoogleService-Info.plist"),
    pathlib.Path("lib/firebase_options.dart"),
}

PATTERNS = {
    "supabase_project_url": re.compile(r"https://[a-z0-9]{20}\.supabase\.co"),
    "supabase_jwt": re.compile(r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"),
    "firebase_api_key": re.compile(r"AIza[0-9A-Za-z_-]{35}"),
    "revenuecat_public_key": re.compile(r"\b(?:goog|appl)_[0-9A-Za-z]{16,}\b"),
}

ALLOWLIST_SUBSTRINGS = {
    "YOUR_PROJECT_REF",
    "YOUR_SUPABASE_ANON_KEY",
    "YOUR_FIREBASE",
    "YOUR_REVENUECAT",
    "https://*.supabase.co",
    "project-ref.supabase.co",
}


def should_skip(path: pathlib.Path) -> bool:
    relative = path.relative_to(ROOT)
    return any(part in SKIP_DIRS for part in relative.parts)


def is_binary(path: pathlib.Path) -> bool:
    try:
      chunk = path.read_bytes()[:1024]
    except OSError:
      return True
    return b"\0" in chunk


def main() -> int:
    findings: list[str] = []
    tracked = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout.split(b"\0")
    for raw_relative in tracked:
        if not raw_relative:
            continue
        relative = pathlib.Path(raw_relative.decode("utf-8"))
        path = ROOT / relative
        if (
            relative in PUBLIC_MOBILE_CONFIG
            or not path.is_file()
            or should_skip(path)
            or is_binary(path)
        ):
            continue

        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        for line_no, line in enumerate(text.splitlines(), start=1):
            if any(token in line for token in ALLOWLIST_SUBSTRINGS):
                continue
            for name, pattern in PATTERNS.items():
                if pattern.search(line):
                    findings.append(f"{path.relative_to(ROOT)}:{line_no}: {name}")

    if findings:
        print("Potential committed live config/secrets found:")
        print("\n".join(findings))
        return 1

    print("Secret scan passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
