import base64
import hashlib
import os
import stat
import tempfile
import unittest
from pathlib import Path
from test_remote_files import helper


class EditorSaveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="serveride-save-")
        self.root = Path(self.temp.name)
        self.target = self.root / "ملف ' quoted.py"
        self.target.write_bytes(b"original\n")
        self.target.chmod(0o750)
        self.staging = self.root / ".serveride-upload-edit"
        self.backup = self.root / ".serveride-backup-test"
        self.original_hash = hashlib.sha256(self.target.read_bytes()).hexdigest()

    def tearDown(self):
        self.temp.cleanup()

    def stage(self, data):
        helper.operate(dict(op="uploadStart", path=str(self.staging)))
        for offset in range(0, len(data), 12288):
            helper.operate(dict(op="uploadChunk", path=str(self.staging), data=base64.b64encode(data[offset:offset+12288]).decode()))
        return dict(op="uploadReplace", path=str(self.staging), destination=str(self.target),
                    backup=str(self.backup), size=len(data), expectedSHA256=self.original_hash)

    def test_large_unicode_save_backup_and_mode(self):
        data = ("print('مرحبا')\n" * 30000).encode()
        reply = helper.operate(self.stage(data))
        self.assertEqual(self.target.read_bytes(), data)
        self.assertEqual(self.backup.read_bytes(), b"original\n")
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o750)
        self.assertEqual(stat.S_IMODE(self.backup.stat().st_mode), 0o600)
        self.assertEqual(reply["path"], str(self.backup))
        self.assertFalse(self.staging.exists())

    def test_changed_original_is_preserved(self):
        request = self.stage(b"draft")
        self.target.write_bytes(b"changed externally")
        with self.assertRaisesRegex(ValueError, "changed"):
            helper.operate(request)
        self.assertEqual(self.target.read_bytes(), b"changed externally")
        self.assertFalse(self.backup.exists())

    def test_symlink_destination_rejected(self):
        request = self.stage(b"draft")
        link = self.root / "link"
        link.symlink_to(self.target)
        request["destination"] = str(link)
        with self.assertRaises(OSError):
            helper.operate(request)
        self.assertEqual(self.target.read_bytes(), b"original\n")

    def test_size_mismatch_preserves_original(self):
        request = self.stage(b"draft")
        request["size"] += 1
        with self.assertRaises(ValueError):
            helper.operate(request)
        self.assertEqual(self.target.read_bytes(), b"original\n")

    def test_backup_collision_preserves_both_files(self):
        request = self.stage(b"draft")
        self.backup.write_bytes(b"previous backup")
        with self.assertRaises(FileExistsError):
            helper.operate(request)
        self.assertEqual(self.backup.read_bytes(), b"previous backup")
        self.assertEqual(self.target.read_bytes(), b"original\n")

    def test_empty_save_is_valid(self):
        helper.operate(self.stage(b""))
        self.assertEqual(self.target.read_bytes(), b"")
        self.assertEqual(self.backup.read_bytes(), b"original\n")

    def test_hardlinked_original_rejected(self):
        request = self.stage(b"draft")
        os.link(self.target, self.root / "hardlink")
        with self.assertRaises(ValueError):
            helper.operate(request)
        self.assertEqual(self.target.read_bytes(), b"original\n")

    def test_staging_symlink_rejected(self):
        request = self.stage(b"original\n")
        self.staging.unlink()
        self.staging.symlink_to(self.target)
        with self.assertRaises(OSError):
            helper.operate(request)
        self.assertEqual(self.target.read_bytes(), b"original\n")

    def test_read_returns_revision(self):
        reply = helper.operate(dict(op="read", path=str(self.target)))
        self.assertEqual(reply["sha256"], self.original_hash)

    def test_save_preserves_extended_attributes(self):
        os.setxattr(self.target, "user.serveride-test", b"keep")
        helper.operate(self.stage(b"draft"))
        self.assertEqual(os.getxattr(self.target, "user.serveride-test"), b"keep")

    def test_chunk_command_transport_stays_bounded(self):
        import json
        import shlex
        import subprocess
        script = Path(helper.__file__).read_text()
        helper.operate(dict(op="uploadStart", path=str(self.staging)))
        arguments = dict(op="uploadChunk", path=str(self.staging), data=base64.b64encode(b"x" * 12288).decode())
        payload = base64.b64encode(json.dumps(arguments).encode()).decode()
        command = "python3 -c " + shlex.quote(script) + " " + shlex.quote(payload)
        self.assertLess(len(command.encode()), 32768)
        output = subprocess.check_output(["sh", "-c", command], text=True)
        self.assertTrue(json.loads(output)["ok"])


if __name__ == "__main__":
    unittest.main()
