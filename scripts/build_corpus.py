#!/usr/bin/env python3
"""Build the checked-in, offline Stoic meditation corpus.

Runtime QML never uses the network. This script is only for maintainers who
want to reproduce or update data/meditations.json from pinned upstream texts.
"""

from __future__ import annotations

import argparse
import json
import re
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "data" / "meditations.json"
MAX_CHARACTERS = 1200
XHTML = "{http://www.w3.org/1999/xhtml}"
EPUB_TYPE = "{http://www.idpf.org/2007/ops}type"


@dataclass(frozen=True)
class Source:
    id: str
    author: str
    work: str
    translator: str
    repository: str
    commit: str
    edition_url: str
    files: tuple[str, ...]

    @property
    def raw_base_url(self) -> str:
        return f"https://raw.githubusercontent.com/{self.repository}/{self.commit}/"


SOURCES = (
    Source(
        id="marcus-meditations",
        author="Marcus Aurelius",
        work="Meditations",
        translator="George Long",
        repository="standardebooks/marcus-aurelius_meditations_george-long",
        commit="419c4faaa7a83b2a37988f1a516c84afefde579c",
        edition_url="https://standardebooks.org/ebooks/marcus-aurelius/meditations/george-long",
        files=tuple(f"src/epub/text/book-{book}.xhtml" for book in range(1, 13)),
    ),
    Source(
        id="epictetus-enchiridion",
        author="Epictetus",
        work="The Enchiridion",
        translator="George Long",
        repository="standardebooks/epictetus_short-works_george-long",
        commit="8c154d40a6f85e32a5711001a28c1b55ab56d3c8",
        edition_url="https://standardebooks.org/ebooks/epictetus/short-works/george-long",
        files=("src/epub/text/the-enchiridion.xhtml",),
    ),
    Source(
        id="epictetus-discourses",
        author="Epictetus",
        work="Discourses",
        translator="George Long",
        repository="standardebooks/epictetus_discourses_george-long",
        commit="218406b563346743af3ece4a22723a245b0ccb22",
        edition_url="https://standardebooks.org/ebooks/epictetus/discourses/george-long",
        files=tuple(f"src/epub/text/book-{book}.xhtml" for book in range(1, 5)),
    ),
)

STRUCTURAL_TEXT = {
    "And⁠—",
    "And again⁠—",
    "And other things of the same kind.",
    "Among the Quadi at the Granua.",
    "This in Carnuntum.",
}


def fetch(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "omarchy-stoic-meditations corpus builder"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def normalized_text(element: ET.Element) -> str:
    """Return plain text while omitting Standard Ebooks endnote markers."""

    pieces: list[str] = []

    def visit(node: ET.Element) -> None:
        if node.text:
            pieces.append(node.text)
        for child in node:
            if not (child.tag == f"{XHTML}a" and child.get(EPUB_TYPE) == "noteref"):
                visit(child)
            if child.tail:
                pieces.append(child.tail)

    visit(element)
    return re.sub(r"\s+", " ", "".join(pieces)).strip()


def eligible(text: str) -> bool:
    if not text or text in STRUCTURAL_TEXT or len(text) > MAX_CHARACTERS:
        return False
    first = text.lstrip("“‘\"'(")[:1]
    return bool(first) and not first.islower() and not text.endswith((":", ",", "—"))


def direct_paragraphs(section: ET.Element) -> list[ET.Element]:
    return [child for child in section if child.tag == f"{XHTML}p"]


def base_entry(source: Source, entry_id: str, locator: str, text: str) -> dict:
    return {
        "id": entry_id,
        "sourceId": source.id,
        "author": source.author,
        "work": source.work,
        "locator": locator,
        "translator": source.translator,
        "text": text,
    }


def parse_marcus(source: Source, documents: Iterable[bytes]) -> list[dict]:
    entries: list[dict] = []
    for book, document in enumerate(documents, 1):
        root = ET.fromstring(document)
        paragraphs = root.findall(f".//{XHTML}body/{XHTML}section/{XHTML}p")
        for paragraph, element in enumerate(paragraphs, 1):
            text = normalized_text(element)
            if eligible(text):
                entries.append(
                    base_entry(
                        source,
                        f"marcus-meditations-{book:02d}-{paragraph:03d}",
                        f"Book {book}, section {paragraph}",
                        text,
                    )
                )
    return entries


def parse_enchiridion(source: Source, document: bytes) -> list[dict]:
    entries: list[dict] = []
    root = ET.fromstring(document)
    chapters = root.findall(f".//{XHTML}section[@{EPUB_TYPE}='chapter']")
    for chapter, section in enumerate(chapters, 1):
        paragraphs = direct_paragraphs(section)
        text = "\n\n".join(normalized_text(item) for item in paragraphs)
        if eligible(text):
            entries.append(
                base_entry(
                    source,
                    f"epictetus-enchiridion-{chapter:03d}",
                    f"Section {chapter}",
                    text,
                )
            )
    return entries


def parse_discourses(source: Source, documents: Iterable[bytes]) -> list[dict]:
    entries: list[dict] = []
    for book, document in enumerate(documents, 1):
        root = ET.fromstring(document)
        chapters = [
            section
            for section in root.findall(f".//{XHTML}section")
            if section.get("id", "").startswith("chapter-")
        ]
        for chapter, section in enumerate(chapters, 1):
            for paragraph, element in enumerate(direct_paragraphs(section), 1):
                text = normalized_text(element)
                if eligible(text):
                    entries.append(
                        base_entry(
                            source,
                            f"epictetus-discourses-{book:02d}-{chapter:03d}-{paragraph:03d}",
                            f"Book {book}, chapter {chapter}, paragraph {paragraph}",
                            text,
                        )
                    )
    return entries


def interleaved_schedule(entries: list[dict]) -> list[str]:
    """Spread every source proportionally over one deterministic cycle."""

    by_source: dict[str, list[dict]] = {source.id: [] for source in SOURCES}
    for entry in entries:
        by_source[entry["sourceId"]].append(entry)

    ranked: list[tuple[float, int, int, str]] = []
    for source_order, source in enumerate(SOURCES):
        source_entries = by_source[source.id]
        for index, entry in enumerate(source_entries):
            position = (index + 0.5) / len(source_entries)
            ranked.append((position, source_order, index, entry["id"]))
    ranked.sort()
    return [item[3] for item in ranked]


def build() -> dict:
    documents = {
        source.id: [fetch(source.raw_base_url + path) for path in source.files]
        for source in SOURCES
    }
    entries = [
        *parse_marcus(SOURCES[0], documents[SOURCES[0].id]),
        *parse_enchiridion(SOURCES[1], documents[SOURCES[1].id][0]),
        *parse_discourses(SOURCES[2], documents[SOURCES[2].id]),
    ]
    source_metadata = [
        {
            "id": source.id,
            "author": source.author,
            "work": source.work,
            "translator": source.translator,
            "editionUrl": source.edition_url,
            "upstreamRepository": f"https://github.com/{source.repository}",
            "pinnedCommit": source.commit,
        }
        for source in SOURCES
    ]
    return {
        "schemaVersion": 1,
        "corpusVersion": "2026-08-20",
        "maximumCharacters": MAX_CHARACTERS,
        "rights": (
            "Source texts are public-domain editions in the United States; "
            "Standard Ebooks contributor work is dedicated to the public domain under CC0."
        ),
        "sources": source_metadata,
        "entries": entries,
        "schedule": interleaved_schedule(entries),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    corpus = build()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(corpus, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(corpus['entries'])} entries to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
