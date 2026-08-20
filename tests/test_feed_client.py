import io
import json
import unittest
from pathlib import Path

from scripts import feed_client

FIXTURES = Path(__file__).resolve().parent / "fixtures"


class FakeResponse:
    def __init__(self, body):
        self.stream = io.BytesIO(body)
        self.read_sizes = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self, size=-1):
        self.read_sizes.append(size)
        return self.stream.read(size)


class FeedParserTest(unittest.TestCase):
    def test_parse_feed_returns_minimal_latest_episode(self):
        episode = feed_client.parse_feed(
            (FIXTURES / "feed_valid.xml").read_bytes()
        )

        self.assertEqual(
            episode,
            {
                "title": "Practice the Next Right Action",
                "published": "2026-08-20T10:00:00+00:00",
                "durationSeconds": 157,
                "audioUrl": (
                    "https://media.example.test/next-right-action.mp3"
                ),
                "episodeUrl": (
                    "https://example.test/episodes/next-right-action"
                ),
            },
        )
        self.assertNotIn("description", episode)

    def test_parse_duration_accepts_mm_ss_and_hh_mm_ss(self):
        self.assertEqual(feed_client.parse_duration("02:37"), 157)
        self.assertEqual(feed_client.parse_duration("1:02:03"), 3723)

    def test_parse_duration_rejects_invalid_ranges(self):
        for value in ("", "9", "1:99", "1:02:99", "x:01"):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    feed_client.parse_duration(value)

    def test_missing_item_is_rejected(self):
        with self.assertRaisesRegex(feed_client.FeedError, "no episodes"):
            feed_client.parse_feed(b"<rss><channel /></rss>")

    def test_missing_enclosure_is_rejected(self):
        with self.assertRaisesRegex(feed_client.FeedError, "audio enclosure"):
            feed_client.parse_feed(
                (FIXTURES / "feed_missing_enclosure.xml").read_bytes()
            )

    def test_non_audio_enclosure_is_rejected(self):
        xml = self._single_item_xml(
            audio_url="https://media.example.test/episode.bin",
            media_type="application/octet-stream",
        )
        with self.assertRaisesRegex(feed_client.FeedError, "not audio"):
            feed_client.parse_feed(xml)

    def test_rejects_non_https_audio_url(self):
        with self.assertRaisesRegex(feed_client.FeedError, "audio URL"):
            feed_client.parse_feed(
                (FIXTURES / "feed_invalid_scheme.xml").read_bytes()
            )

    def test_rejects_non_https_episode_url(self):
        xml = self._single_item_xml(episode_url="http://example.test/episode")
        with self.assertRaisesRegex(feed_client.FeedError, "episode URL"):
            feed_client.parse_feed(xml)

    def test_missing_episode_link_uses_official_podcast_page(self):
        xml = self._single_item_xml(episode_url="")

        episode = feed_client.parse_feed(xml)

        self.assertEqual(episode["episodeUrl"], feed_client.OFFICIAL_PAGE_URL)

    def test_malformed_duration_falls_back_to_zero(self):
        xml = self._single_item_xml(duration="unknown")
        self.assertEqual(feed_client.parse_feed(xml)["durationSeconds"], 0)

    def test_rfc_2822_negative_zero_timezone_is_treated_as_utc(self):
        xml = self._single_item_xml().replace(b"+0000", b"-0000")

        episode = feed_client.parse_feed(xml)

        self.assertEqual(episode["published"], "2026-08-20T10:00:00+00:00")

    def test_malformed_xml_is_rejected_without_parser_details(self):
        with self.assertRaisesRegex(feed_client.FeedError, "invalid podcast feed"):
            feed_client.parse_feed(b"<rss><channel>")

    @staticmethod
    def _single_item_xml(
        *,
        audio_url="https://media.example.test/episode.mp3",
        episode_url="https://example.test/episode",
        media_type="audio/mpeg",
        duration="02:37",
    ):
        return f"""<?xml version="1.0"?>
<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel><item>
    <title>Example Episode</title>
    <link>{episode_url}</link>
    <pubDate>Thu, 20 Aug 2026 10:00:00 +0000</pubDate>
    <enclosure url="{audio_url}" type="{media_type}" />
    <itunes:duration>{duration}</itunes:duration>
  </item></channel>
</rss>""".encode()


class FeedFetchTest(unittest.TestCase):
    def test_fetch_uses_fixed_url_headers_timeout_and_byte_limit(self):
        response = FakeResponse((FIXTURES / "feed_valid.xml").read_bytes())
        captured = {}

        def opener(request, timeout):
            captured["request"] = request
            captured["timeout"] = timeout
            return response

        episode = feed_client.fetch_latest_episode(opener=opener)

        self.assertEqual(captured["request"].full_url, feed_client.FEED_URL)
        self.assertIn(
            "omarchy-stoic-podcast",
            captured["request"].get_header("User-agent"),
        )
        self.assertIn(
            "github.com/davidojeda/omarchy-stoic-podcast",
            captured["request"].get_header("User-agent"),
        )
        self.assertEqual(captured["timeout"], 10)
        self.assertTrue(response.read_sizes)
        self.assertLessEqual(max(response.read_sizes), feed_client.READ_CHUNK_BYTES)
        self.assertEqual(episode["title"], "Practice the Next Right Action")

    def test_fetch_rejects_oversize_response(self):
        response = FakeResponse(
            b"<rss><channel>"
            + b" " * (feed_client.MAX_FEED_BYTES + 1)
            + b"</channel></rss>"
        )

        with self.assertRaisesRegex(feed_client.FeedError, "too large"):
            feed_client.fetch_latest_episode(
                opener=lambda request, timeout: response
            )

    def test_fetch_stops_after_first_item_in_a_large_feed(self):
        xml = (FIXTURES / "feed_valid.xml").read_bytes()
        xml = xml.replace(
            b"</channel>",
            b" " * (feed_client.MAX_FEED_BYTES + 1) + b"</channel>",
        )
        response = FakeResponse(xml)

        episode = feed_client.fetch_latest_episode(
            opener=lambda request, timeout: response
        )

        self.assertEqual(episode["title"], "Practice the Next Right Action")
        self.assertLess(response.stream.tell(), feed_client.MAX_FEED_BYTES)

    def test_main_prints_one_success_json_object(self):
        output = io.StringIO()
        exit_code = feed_client.main(
            stdout=output,
            fetcher=lambda: {"title": "Synthetic episode"},
        )

        self.assertEqual(exit_code, 0)
        self.assertEqual(
            json.loads(output.getvalue()),
            {"ok": True, "title": "Synthetic episode"},
        )
        self.assertEqual(output.getvalue().count("\n"), 1)

    def test_main_prints_safe_error_without_traceback(self):
        output = io.StringIO()

        def fail():
            raise feed_client.FeedError("podcast feed unavailable")

        exit_code = feed_client.main(stdout=output, fetcher=fail)

        self.assertEqual(exit_code, 1)
        self.assertEqual(
            json.loads(output.getvalue()),
            {"ok": False, "error": "podcast feed unavailable"},
        )
        self.assertNotIn("Traceback", output.getvalue())


if __name__ == "__main__":
    unittest.main()
