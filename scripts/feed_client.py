#!/usr/bin/env python3
"""Fetch minimal playback metadata from the official podcast RSS feed."""

from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import timezone
from email.utils import parsedate_to_datetime
from typing import Any, Callable, TextIO

FEED_URL = "https://rss.art19.com/the-daily-stoic"
OFFICIAL_PAGE_URL = "https://dailystoic.com/podcast/"
MAX_FEED_BYTES = 4 * 1024 * 1024
READ_CHUNK_BYTES = 64 * 1024
REQUEST_TIMEOUT_SECONDS = 10
TOTAL_FETCH_DEADLINE_SECONDS = 15
USER_AGENT = (
    "omarchy-stoic-podcast/0.1 "
    "(+https://github.com/davidojedalopez/omarchy-stoic-podcast)"
)
ITUNES_NAMESPACE = "http://www.itunes.com/dtds/podcast-1.0.dtd"


class FeedError(ValueError):
    """A safe, user-facing podcast feed error."""


def parse_duration(value: str) -> int:
    """Convert an iTunes podcast duration to seconds."""
    parts = value.strip().split(":")
    if len(parts) not in (1, 2, 3) or any(not part.isdigit() for part in parts):
        raise ValueError("unsupported podcast duration")

    numbers = [int(part) for part in parts]
    if len(numbers) == 1:
        return numbers[0]
    if len(numbers) == 2:
        minutes, seconds = numbers
        if seconds >= 60:
            raise ValueError("unsupported podcast duration")
        return minutes * 60 + seconds

    hours, minutes, seconds = numbers
    if minutes >= 60 or seconds >= 60:
        raise ValueError("unsupported podcast duration")
    return hours * 3600 + minutes * 60 + seconds


def require_https(value: str, field: str) -> str:
    """Return a normalized HTTPS URL or reject it."""
    url = value.strip()
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc:
        raise FeedError(f"{field} must use HTTPS")
    return url


def require_audio_type(value: str) -> None:
    """Reject RSS enclosures not identified as audio."""
    if not value.strip().lower().startswith("audio/"):
        raise FeedError("feed enclosure is not audio")


def _required_text(item: ET.Element, tag: str, label: str) -> str:
    value = item.findtext(tag, default="").strip()
    if not value:
        raise FeedError(f"podcast episode has no {label}")
    return value


def _episode_from_item(item: ET.Element) -> dict[str, object]:
    """Extract the allowed metadata from one RSS item."""
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise FeedError("podcast episode has no audio enclosure")

    media_type = enclosure.get("type", "")
    require_audio_type(media_type)
    audio_url = require_https(enclosure.get("url", ""), "audio URL")
    episode_url = require_https(
        (item.findtext("link", default="") or "").strip() or OFFICIAL_PAGE_URL,
        "episode URL",
    )

    published_text = _required_text(item, "pubDate", "publication date")
    try:
        published = parsedate_to_datetime(published_text)
    except (TypeError, ValueError, OverflowError):
        raise FeedError("podcast episode has an invalid publication date") from None
    if published.tzinfo is None and published_text.endswith(" -0000"):
        published = published.replace(tzinfo=timezone.utc)
    if published.tzinfo is None:
        raise FeedError("podcast episode has an invalid publication date")

    duration_text = item.findtext(
        f"{{{ITUNES_NAMESPACE}}}duration", default=""
    )
    try:
        duration_seconds = parse_duration(duration_text)
    except ValueError:
        duration_seconds = 0

    return {
        "title": _required_text(item, "title", "title"),
        "published": published.isoformat(),
        "durationSeconds": duration_seconds,
        "audioUrl": audio_url,
        "episodeUrl": episode_url,
    }


def parse_feed(xml_bytes: bytes) -> dict[str, object]:
    """Parse only the metadata needed to identify and play the newest item."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        raise FeedError("invalid podcast feed") from None

    item = root.find("./channel/item")
    if item is None:
        raise FeedError("podcast feed has no episodes")
    return _episode_from_item(item)


def _parse_first_item_stream(
    response: Any,
    *,
    deadline: float,
    clock: Callable[[], float],
) -> dict[str, object]:
    """Stop parsing once the first RSS item is complete."""
    parser = ET.XMLPullParser(events=("end",))
    total_bytes = 0

    while True:
        if clock() > deadline:
            raise FeedError("podcast feed timed out")
        chunk = response.read(
            min(READ_CHUNK_BYTES, MAX_FEED_BYTES - total_bytes + 1)
        )
        if clock() > deadline:
            raise FeedError("podcast feed timed out")
        if not chunk:
            try:
                parser.close()
            except ET.ParseError:
                raise FeedError("invalid podcast feed") from None
            raise FeedError("podcast feed has no episodes")

        total_bytes += len(chunk)
        if total_bytes > MAX_FEED_BYTES:
            raise FeedError("podcast feed is too large")

        try:
            parser.feed(chunk)
            events: Any = parser.read_events()
            for _event, element in events:
                if element.tag.rsplit("}", 1)[-1] == "item":
                    return _episode_from_item(element)
        except ET.ParseError:
            raise FeedError("invalid podcast feed") from None


def fetch_latest_episode(
    opener: Callable[..., Any] = urllib.request.urlopen,
    clock: Callable[[], float] = time.monotonic,
) -> dict[str, object]:
    """Fetch and parse the official feed with strict time and size bounds."""
    request = urllib.request.Request(
        FEED_URL,
        headers={"User-Agent": USER_AGENT, "Accept": "application/rss+xml, application/xml"},
    )
    deadline = clock() + TOTAL_FETCH_DEADLINE_SECONDS
    try:
        with opener(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            return _parse_first_item_stream(
                response,
                deadline=deadline,
                clock=clock,
            )
    except (urllib.error.URLError, OSError, TimeoutError):
        raise FeedError("podcast feed unavailable") from None


def main(
    *,
    stdout: TextIO = sys.stdout,
    fetcher: Callable[[], dict[str, object]] = fetch_latest_episode,
) -> int:
    """Print one JSON object for the QML controller."""
    try:
        payload = {"ok": True, **fetcher()}
        exit_code = 0
    except FeedError as error:
        payload = {"ok": False, "error": str(error)}
        exit_code = 1

    json.dump(payload, stdout, ensure_ascii=False, separators=(",", ":"))
    stdout.write("\n")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
