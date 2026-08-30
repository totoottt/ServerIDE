#!/usr/bin/env python3
"""Check the shipped app, not only XcodeGen source settings. Accept .app or .ipa."""
import plistlib
import sys
import zipfile
from pathlib import Path


def validate(info):
    for key in ("UIFileSharingEnabled", "LSSupportsOpeningDocumentsInPlace"):
        if info.get(key) is not True:
            raise ValueError(f"Built Info.plist is missing boolean {key}=true")
    if info.get("CFBundleIdentifier") != "app.carambola5307.spinach7929":
        raise ValueError("Built Bundle ID does not match BOOS signing profile")
    if info.get("CFBundleShortVersionString") != "0.7.3" or info.get("CFBundleVersion") != "14":
        raise ValueError("Built app is not ServerIDE 0.7.3 (14)")
    if info.get("ServerIDEReleaseMarker") != "RESUMABLE-DOWNLOAD-20260830-E":
        raise ValueError("Built app is missing the resumable download release marker")
    primary = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    if not primary.get("CFBundleIconFiles") and not primary.get("CFBundleIconName"):
        raise ValueError("Built app has no primary app icon")


def check(path):
    if path.suffix == ".ipa":
        with zipfile.ZipFile(path) as archive:
            matches = [name for name in archive.namelist()
                       if name.startswith("Payload/") and name.count("/") == 2
                       and name.endswith(".app/Info.plist")]
            if len(matches) != 1:
                raise ValueError("Expected exactly one main app in IPA")
            info = plistlib.loads(archive.read(matches[0]))
    else:
        with (path / "Info.plist").open("rb") as f:
            info = plistlib.load(f)
    validate(info)
    print(f"PASS: {path.name}: ServerIDE 0.7.3 (14), resumable downloads, Files integration, Bundle ID and app icon")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Pass at least one built .app or .ipa")
    for name in sys.argv[1:]:
        check(Path(name))
