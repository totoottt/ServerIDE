"""Integration tests for the exact Python helper bundled into ServerIDE."""
import base64
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
sys.dont_write_bytecode = True

HELPER = Path(__file__).resolve().parents[1] / "ServerIDE/Resources/remote_files.py"
spec = importlib.util.spec_from_file_location("remote_files", HELPER)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class RemoteFileTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="serveride-tests-")
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def operation(self, op, path, **kwargs):
        return helper.operate(dict(op=op, path=str(path), **kwargs))

    def test_listing_unicode_hidden_newline_and_metadata(self):
        names = ["hello.py", ".hidden", "اسم عربي ' file.txt", "line\nbreak.txt"]
        for name in names:
            (self.root / name).write_text("hello", encoding="utf-8")
        (self.root / "folder").mkdir()
        reply = self.operation("list", self.root)
        self.assertEqual(reply["path"], str(self.root.resolve()))
        by_name = {f["name"]: f for f in reply["files"]}
        self.assertEqual(set(by_name), set(names + ["folder"]))
        self.assertTrue(by_name["folder"]["isDirectory"])
        self.assertEqual(by_name["hello.py"]["size"], 5)
        self.assertIn("permissions", by_name["hello.py"])

    def test_create_never_overwrites(self):
        target = self.root / "existing"
        target.write_bytes(b"keep me")
        with self.assertRaises(FileExistsError):
            self.operation("create", target)
        self.assertEqual(target.read_bytes(), b"keep me")

    def test_mkdir_and_empty_delete(self):
        folder = self.root / "new"
        self.operation("mkdir", folder)
        self.assertTrue(folder.is_dir())
        self.operation("delete", folder)
        self.assertFalse(folder.exists())

    def test_nonempty_directory_not_deleted(self):
        folder = self.root / "full"
        folder.mkdir()
        (folder / "keep").write_text("keep")
        with self.assertRaises(OSError):
            self.operation("delete", folder)
        self.assertTrue((folder / "keep").exists())

    def test_rename_never_overwrites(self):
        old, destination = self.root / "a", self.root / "b"
        old.write_text("a")
        destination.write_text("b")
        with self.assertRaises(FileExistsError):
            self.operation("rename", old, destination=str(destination))
        self.assertEqual(old.read_text(), "a")
        self.assertEqual(destination.read_text(), "b")

    def test_rename_file_and_directory(self):
        old, destination = self.root / "a", self.root / "b"
        old.write_text("a")
        self.operation("rename", old, destination=str(destination))
        self.assertEqual(destination.read_text(), "a")
        folder = self.root / "folder"
        folder.mkdir()
        self.operation("rename", folder, destination=str(self.root / "renamed"))
        self.assertTrue((self.root / "renamed").is_dir())

    def test_multichunk_binary_roundtrip(self):
        staging = self.root / ".serveride-upload-test"
        destination = self.root / "binary"
        data = bytes(range(256)) * 300
        self.operation("uploadStart", staging)
        for offset in range(0, len(data), 24576):
            self.operation("uploadChunk", staging, data=base64.b64encode(data[offset:offset+24576]).decode())
        self.operation("uploadFinish", staging, destination=str(destination), size=len(data))
        self.assertFalse(staging.exists())
        self.assertEqual(destination.read_bytes(), data)
        self.assertEqual(base64.b64decode(self.operation("read", destination)["data"]), data)

    def test_upload_collision_preserves_destination(self):
        staging = self.root / ".serveride-upload-test"
        destination = self.root / "target"
        destination.write_text("original")
        self.operation("uploadStart", staging)
        with self.assertRaises(FileExistsError):
            self.operation("uploadFinish", staging, destination=str(destination), size=0)
        self.assertEqual(destination.read_text(), "original")
        self.operation("uploadCancel", staging)
        self.assertFalse(staging.exists())

    def test_reject_wrong_upload_size(self):
        staging = self.root / ".serveride-upload-test"
        self.operation("uploadStart", staging)
        with self.assertRaises(ValueError):
            self.operation("uploadFinish", staging, destination=str(self.root/"target"), size=99)
        self.assertFalse((self.root/"target").exists())

    def test_read_limit(self):
        target = self.root / "large"
        with target.open("wb") as stream:
            stream.truncate(helper.MAX_FILE + 1)
        with self.assertRaises(ValueError):
            self.operation("read", target)

    def test_read_range_supports_resume_and_rejects_invalid_ranges(self):
        target = self.root / "resume.bin"
        data = bytes(range(256)) * 2048
        target.write_bytes(data)
        first = self.operation("readRange", target, offset=0, count=384 * 1024)
        second = self.operation("readRange", target, offset=len(base64.b64decode(first["data"])), count=384 * 1024)
        self.assertEqual(first["size"], len(data))
        self.assertEqual(base64.b64decode(first["data"]) + base64.b64decode(second["data"]), data[:len(data)])
        with self.assertRaises(ValueError):
            self.operation("readRange", target, offset=-1, count=1)
        with self.assertRaises(ValueError):
            self.operation("readRange", target, offset=0, count=512 * 1024 + 1)

    def test_staging_symlink_cannot_be_written(self):
        target = self.root / "target"
        target.write_text("original")
        staging = self.root / ".serveride-upload-link"
        staging.symlink_to(target)
        with self.assertRaises(OSError):
            self.operation("uploadChunk", staging, data="YQ==")
        self.assertEqual(target.read_text(), "original")

    def test_invalid_staging_and_chunk(self):
        with self.assertRaises(ValueError):
            self.operation("uploadStart", self.root / "ordinary")
        staging = self.root / ".serveride-upload-test"
        self.operation("uploadStart", staging)
        with self.assertRaises(ValueError):
            self.operation("uploadChunk", staging, data=base64.b64encode(b"a"*24577).decode())

    def test_finish_rejects_symlink(self):
        target = self.root / "real"
        target.write_text("data")
        staging = self.root / ".serveride-upload-link"
        staging.symlink_to(target)
        with self.assertRaises(ValueError):
            self.operation("uploadFinish", staging, destination=str(self.root/"new"), size=4)
        self.assertFalse((self.root/"new").exists())

    def test_shell_transport_with_unicode_and_quotes(self):
        import shlex
        target = self.root / "ملف ' quoted ; $(echo nope).txt"
        request = base64.b64encode(json.dumps({"op":"create","path":str(target)}).encode()).decode()
        command = "python3 -c " + shlex.quote(HELPER.read_text()) + " " + shlex.quote(request)
        result = subprocess.run(["sh", "-c", command], capture_output=True, text=True, check=True)
        self.assertTrue(json.loads(result.stdout)["ok"])
        self.assertTrue(target.exists())

    def test_delete_symlink_not_target(self):
        target = self.root / "target"
        target.mkdir()
        (target/"keep").touch()
        link = self.root/"link"
        link.symlink_to(target, target_is_directory=True)
        self.operation("delete", link)
        self.assertTrue((target/"keep").exists())
        self.assertFalse(link.is_symlink())

    def test_cli_protocol_and_injection_names(self):
        name = "literal $(echo nope) ; ' العربية"
        payload = base64.b64encode(json.dumps({"op":"create","path":str(self.root/name)}).encode()).decode()
        result = subprocess.run([sys.executable, str(HELPER), payload], capture_output=True, text=True, check=True)
        self.assertTrue(json.loads(result.stdout)["ok"])
        self.assertTrue((self.root/name).exists())
        payload = base64.b64encode(json.dumps({"op":"list","path":str(self.root/"missing")}).encode()).decode()
        result = subprocess.run([sys.executable,str(HELPER),payload], capture_output=True,text=True,check=True)
        self.assertFalse(json.loads(result.stdout)["ok"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
