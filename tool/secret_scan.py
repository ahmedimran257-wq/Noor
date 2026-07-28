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
    ".open-next",
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


def git_ignored_paths(paths: list[pathlib.Path]) -> set[str]:
    """Return ignored paths while preserving scans of untracked source files."""
    if not paths:
        return set()
    relative_paths = [str(path.relative_to(ROOT)).replace("\\", "/") for path in paths]
    try:
        result = subprocess.run(
            ["git", "check-ignore", "-z", "--stdin"],
            cwd=ROOT,
            input=b"\0".join(path.encode("utf-8") for path in relative_paths),
            capture_output=True,
            check=False,
        )
    except OSError:
        # Archive/CI environments without Git still receive the directory-based
        # scanner rather than silently skipping the security check.
        return set()
    return {
        raw_path.decode("utf-8").replace("\\", "/")
        for raw_path in result.stdout.split(b"\0")
        if raw_path
    }


def main() -> int:
    findings: list[str] = []
    # Walk the checked-out workspace, not only Git's index. This catches a
    # generated or newly added secret before it is staged and makes the scanner
    # equally useful for archives and CI workspaces.
    candidates = [
        path
        for path in ROOT.rglob("*")
        if path.is_file() and not should_skip(path)
    ]
    ignored_paths = git_ignored_paths(candidates)
    for path in candidates:
        relative = path.relative_to(ROOT)
        if (
            relative in PUBLIC_MOBILE_CONFIG
            or relative.as_posix() in ignored_paths
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
        print("Potential live config/secrets found in workspace:")
        print("\n".join(findings))
        return 1

    print("Secret scan passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
