#!/usr/bin/env python3
"""Configure the generated Android project for Termul POD Video.

Run from the repository root after flutter create. Safe to run repeatedly.
This script never reads, creates, replaces, or modifies a signing keystore.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
MANIFEST = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
MIN_SDK = 24

PERMISSIONS = (
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.RECORD_AUDIO",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
)
LEGACY_STORAGE_PERMISSION = (
    '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
    'android:maxSdkVersion="29" />'
)
FEATURES = (
    ('android.hardware.camera', '    <uses-feature android:name="android.hardware.camera" android:required="false" />'),
    ('android.hardware.location.gps', '    <uses-feature android:name="android.hardware.location.gps" android:required="false" />'),
)


def configure_manifest() -> None:
    if not MANIFEST.is_file():
        sys.exit(f"Android manifest not found: {MANIFEST}")

    source = MANIFEST.read_text(encoding="utf-8")
    additions = [
        f'    <uses-permission android:name="{permission}" />'
        for permission in PERMISSIONS
        if f'android:name="{permission}"' not in source
    ]
    additions.extend(
        element for name, element in FEATURES
        if f'android:name="{name}"' not in source
    )
    if 'android.permission.WRITE_EXTERNAL_STORAGE' not in source:
        additions.append(LEGACY_STORAGE_PERMISSION)

    if not additions:
        print("Manifest permissions/features already configured")
        return

    updated, count = re.subn(
        r"(\n\s*)(<application\b)",
        lambda match: "\n" + "\n".join(additions) + match.group(1) + match.group(2),
        source,
        count=1,
    )
    if count != 1:
        sys.exit("Could not locate <application> in AndroidManifest.xml")
    MANIFEST.write_text(updated, encoding="utf-8")
    print(f"Manifest updated with {len(additions)} permission/feature entries")


def configure_min_sdk() -> None:
    candidates = (
        ANDROID / "app" / "build.gradle.kts",
        ANDROID / "app" / "build.gradle",
    )
    gradle = next((path for path in candidates if path.is_file()), None)
    if gradle is None:
        sys.exit("android/app/build.gradle(.kts) not found")

    source = gradle.read_text(encoding="utf-8")
    updated = re.sub(
        r"minSdk\s*=\s*flutter\.minSdkVersion",
        f"minSdk = {MIN_SDK}",
        source,
    )
    updated = re.sub(
        r"minSdkVersion\s+flutter\.minSdkVersion",
        f"minSdkVersion {MIN_SDK}",
        updated,
    )
    updated = re.sub(
        r"minSdk\s*=\s*(\d+)",
        lambda match: f"minSdk = {max(int(match.group(1)), MIN_SDK)}",
        updated,
    )
    updated = re.sub(
        r"minSdkVersion\s+(\d+)",
        lambda match: f"minSdkVersion {max(int(match.group(1)), MIN_SDK)}",
        updated,
    )

    if not re.search(r"minSdk(?:Version)?\s*=?\s*\d+", updated):
        sys.exit("Could not set or verify minSdk; inspect the generated Gradle file")
    if updated != source:
        gradle.write_text(updated, encoding="utf-8")
    print(f"Gradle minSdk configured (minimum {MIN_SDK})")


if __name__ == "__main__":
    configure_manifest()
    configure_min_sdk()
