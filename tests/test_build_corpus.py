import unittest
import xml.etree.ElementTree as ET

from scripts import build_corpus


class CorpusBuilderTest(unittest.TestCase):
    def test_normalized_text_removes_endnote_marker_but_keeps_tail(self):
        element = ET.fromstring(
            '<p xmlns="http://www.w3.org/1999/xhtml" '
            'xmlns:epub="http://www.idpf.org/2007/ops">'
            'Keep<a epub:type="noteref">12</a> the tail.</p>'
        )
        self.assertEqual(
            build_corpus.normalized_text(element), "Keep the tail."
        )

    def test_eligibility_keeps_short_complete_units_only(self):
        self.assertTrue(build_corpus.eligible("Act according to nature."))
        self.assertFalse(build_corpus.eligible("and this continues elsewhere."))
        self.assertFalse(build_corpus.eligible("He introduced the lesson:"))
        self.assertFalse(build_corpus.eligible("x" * 1201))
        self.assertFalse(build_corpus.eligible("This in Carnuntum."))

    def test_schedule_spreads_each_source_across_cycle(self):
        entries = []
        for source, count in zip(build_corpus.SOURCES, (6, 2, 3)):
            for index in range(count):
                entries.append({"id": f"{source.id}-{index}", "sourceId": source.id})
        schedule = build_corpus.interleaved_schedule(entries)
        enchiridion_positions = [
            index for index, value in enumerate(schedule)
            if value.startswith("epictetus-enchiridion-")
        ]
        self.assertEqual(len(schedule), len(entries))
        self.assertEqual(set(schedule), {entry["id"] for entry in entries})
        self.assertGreater(enchiridion_positions[-1] - enchiridion_positions[0], 3)


if __name__ == "__main__":
    unittest.main()
