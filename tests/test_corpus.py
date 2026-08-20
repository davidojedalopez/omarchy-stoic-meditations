import json
import re
import unittest
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CORPUS = json.loads((ROOT / "data" / "meditations.json").read_text())


class CorpusTest(unittest.TestCase):
    def test_corpus_is_large_and_contains_every_planned_source(self):
        counts = Counter(entry["sourceId"] for entry in CORPUS["entries"])
        self.assertGreater(counts["marcus-meditations"], 400)
        self.assertGreater(counts["epictetus-enchiridion"], 40)
        self.assertGreater(counts["epictetus-discourses"], 150)
        self.assertGreater(len(CORPUS["entries"]), 600)

    def test_entries_are_complete_bounded_plain_text_units(self):
        maximum = CORPUS["maximumCharacters"]
        for entry in CORPUS["entries"]:
            with self.subTest(entry=entry["id"]):
                text = entry["text"]
                self.assertTrue(text)
                self.assertLessEqual(len(text), maximum)
                self.assertNotRegex(text, r"[,:—]$")
                first = text.lstrip("“‘\"'(")[:1]
                self.assertFalse(first.islower())
                self.assertNotIn("<", text)
                self.assertNotIn(">", text)

    def test_ids_and_schedule_form_one_no_repeat_cycle(self):
        ids = [entry["id"] for entry in CORPUS["entries"]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(CORPUS["schedule"]), len(ids))
        self.assertEqual(set(CORPUS["schedule"]), set(ids))

    def test_sources_are_reproducibly_pinned_and_independently_linked(self):
        self.assertEqual(len(CORPUS["sources"]), 3)
        for source in CORPUS["sources"]:
            self.assertRegex(source["pinnedCommit"], r"^[0-9a-f]{40}$")
            self.assertTrue(
                source["editionUrl"].startswith("https://standardebooks.org/")
            )
            self.assertTrue(
                source["upstreamRepository"].startswith("https://github.com/standardebooks/")
            )
            self.assertEqual(source["translator"], "George Long")


if __name__ == "__main__":
    unittest.main()
