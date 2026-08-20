import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ManifestTest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / "manifest.json").read_text())

    def test_manifest_declares_offline_meditations_widget(self):
        self.assertEqual(self.manifest["schemaVersion"], 1)
        self.assertEqual(
            self.manifest["id"], "dev.davidojeda.stoic-meditations"
        )
        self.assertEqual(self.manifest["kinds"], ["bar-widget"])
        self.assertEqual(
            self.manifest["entryPoints"], {"barWidget": "BarWidget.qml"}
        )
        self.assertFalse(self.manifest["barWidget"]["allowMultiple"])
        self.assertEqual(self.manifest["barWidget"]["defaultSection"], "right")

    def test_manifest_has_no_source_selector_settings(self):
        widget = self.manifest["barWidget"]
        self.assertNotIn("defaults", widget)
        self.assertNotIn("schema", widget)

    def test_runtime_files_exist_and_repository_contains_no_symlinks(self):
        required = [
            "BarWidget.qml",
            "Panel.qml",
            "MeditationController.qml",
            "Model.js",
            "data/meditations.json",
        ]
        for relative_path in required:
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)

        symlinks = [
            str(path.relative_to(ROOT))
            for path in ROOT.rglob("*")
            if path.is_symlink()
        ]
        self.assertEqual(symlinks, [])


if __name__ == "__main__":
    unittest.main()
