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


if __name__ == "__main__":
    unittest.main()
