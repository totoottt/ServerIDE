import subprocess
import unittest
from pathlib import Path


class SourceValidationTests(unittest.TestCase):
    def test_release_source_is_exact_and_at_repository_root(self):
        root = Path(__file__).resolve().parents[1]
        result = subprocess.run(
            ["python3", "scripts/verify-source.py"],
            cwd=root,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("RESUMABLE-DOWNLOAD-20260830-E", result.stdout)


if __name__ == "__main__":
    unittest.main()
