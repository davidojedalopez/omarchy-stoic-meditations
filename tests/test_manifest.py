import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ManifestTest(unittest.TestCase):
    def test_manifest_declares_publishable_bar_widget(self):
        manifest = json.loads((ROOT / "manifest.json").read_text())

        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["id"], "dev.davidojeda.stoic-podcast")
        self.assertEqual(manifest["kinds"], ["bar-widget"])
        self.assertEqual(
            manifest["entryPoints"], {"barWidget": "BarWidget.qml"}
        )
        self.assertFalse(manifest["barWidget"]["allowMultiple"])
        self.assertEqual(manifest["barWidget"]["defaultSection"], "right")

    def test_manifest_entry_points_exist(self):
        manifest = json.loads((ROOT / "manifest.json").read_text())
        for entry_point in manifest["entryPoints"].values():
            self.assertTrue((ROOT / entry_point).is_file(), entry_point)

    def test_runtime_files_exist_and_repository_contains_no_symlinks(self):
        required = [
            "BarWidget.qml",
            "Panel.qml",
            "PodcastController.qml",
            "scripts/feed_client.py",
        ]
        for relative_path in required:
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)

        symlinks = [str(path.relative_to(ROOT)) for path in ROOT.rglob("*") if path.is_symlink()]
        self.assertEqual(symlinks, [])


if __name__ == "__main__":
    unittest.main()
