import importlib.util
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify-bundle.py"
spec = importlib.util.spec_from_file_location("verify_bundle", SCRIPT)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.info = {"UIFileSharingEnabled": True, "LSSupportsOpeningDocumentsInPlace": True,
                     "CFBundleIdentifier": "app.carambola5307.spinach7929",
                     "CFBundleShortVersionString": "0.7.1", "CFBundleVersion": "12",
                     "ServerIDEReleaseMarker": "PROJECT-PDF-20260829-C",
                     "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconName": "AppIcon"}}}

    def test_flags_are_required_booleans(self):
        validator.validate(self.info)
        for key in ("UIFileSharingEnabled", "LSSupportsOpeningDocumentsInPlace"):
            for bad in (None, False, "YES", 1):
                with self.assertRaises(ValueError):
                    validator.validate(dict(self.info, **{key: bad}))

    def test_bundle_and_icon_required(self):
        for key, value in (("CFBundleIdentifier", "wrong"), ("CFBundleIcons", {})):
            with self.assertRaises(ValueError):
                validator.validate(dict(self.info, **{key: value}))

    def test_exact_release_is_required(self):
        for key, value in (("CFBundleShortVersionString", "0.7.0"),
                           ("CFBundleVersion", "11"),
                           ("ServerIDEReleaseMarker", "OLD")):
            with self.assertRaises(ValueError):
                validator.validate(dict(self.info, **{key: value}))

    def test_reads_main_app_from_ipa(self):
        with tempfile.TemporaryDirectory(prefix="serveride-ipa-test-") as directory:
            path = Path(directory) / "test.ipa"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("Payload/ServerIDE.app/Info.plist", plistlib.dumps(self.info))
                archive.writestr("Payload/ServerIDE.app/Frameworks/Test.framework/Info.plist", b"not the main plist")
            validator.check(path)


if __name__ == "__main__":
    unittest.main()
