#!/usr/bin/env python3
"""Verify reviewed Dart defines match both native Firebase applications."""

from __future__ import annotations

import argparse
import json
import plistlib
from pathlib import Path


def require(defines: dict[str, object], key: str) -> str:
    value = str(defines.get(key, "")).strip()
    if not value or "YOUR_" in value or "PLACEHOLDER" in value:
        raise SystemExit(f"{key} is missing or is a placeholder.")
    return value


def assert_equal(label: str, actual: object, expected: str) -> None:
    if str(actual or "").strip() != expected:
        raise SystemExit(f"{label} does not match the reviewed release config.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    args = parser.parse_args()

    # PowerShell's JSON writers may emit a UTF-8 BOM. Accept it while keeping
    # ordinary UTF-8 configuration files valid.
    defines = json.loads(args.config.read_text(encoding="utf-8-sig"))
    android = json.loads(
        Path("android/app/google-services.json").read_text(encoding="utf-8")
    )
    with Path("ios/Runner/GoogleService-Info.plist").open("rb") as stream:
        ios = plistlib.load(stream)

    project = android["project_info"]
    clients = [
        client
        for client in android["client"]
        if client["client_info"]["android_client_info"]["package_name"]
        == "com.silarah.app"
    ]
    if len(clients) != 1:
        raise SystemExit("Expected one com.silarah.app Firebase Android client.")
    client = clients[0]

    assert_equal(
        "Android project ID", project["project_id"], require(defines, "FIREBASE_PROJECT_ID")
    )
    assert_equal(
        "Android sender ID",
        project["project_number"],
        require(defines, "FIREBASE_MESSAGING_SENDER_ID"),
    )
    assert_equal(
        "Android storage bucket",
        project["storage_bucket"],
        require(defines, "FIREBASE_STORAGE_BUCKET"),
    )
    assert_equal(
        "Android app ID",
        client["client_info"]["mobilesdk_app_id"],
        require(defines, "FIREBASE_ANDROID_APP_ID"),
    )
    assert_equal(
        "Android API key",
        client["api_key"][0]["current_key"],
        require(defines, "FIREBASE_ANDROID_API_KEY"),
    )
    assert_equal("iOS project ID", ios["PROJECT_ID"], require(defines, "FIREBASE_PROJECT_ID"))
    assert_equal(
        "iOS sender ID",
        ios["GCM_SENDER_ID"],
        require(defines, "FIREBASE_MESSAGING_SENDER_ID"),
    )
    assert_equal(
        "iOS storage bucket",
        ios["STORAGE_BUCKET"],
        require(defines, "FIREBASE_STORAGE_BUCKET"),
    )
    assert_equal("iOS app ID", ios["GOOGLE_APP_ID"], require(defines, "FIREBASE_IOS_APP_ID"))
    assert_equal("iOS API key", ios["API_KEY"], require(defines, "FIREBASE_IOS_API_KEY"))
    assert_equal(
        "iOS bundle ID",
        ios["BUNDLE_ID"],
        require(defines, "FIREBASE_IOS_BUNDLE_ID"),
    )
    print("Firebase Dart and native configurations match.")


if __name__ == "__main__":
    main()
