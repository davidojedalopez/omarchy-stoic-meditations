# Stoic Podcast for Omarchy

An unofficial Omarchy Quattro plugin that plays the newest episode from the
public Daily Stoic podcast feed.

The plugin is a conventional podcast client. It reads minimal episode metadata
at runtime and streams the publisher-provided audio enclosure. It does not
bundle, proxy, mirror, archive, alter, transcribe, or republish podcast content.

## Content and affiliation

Daily Stoic, Ryan Holiday, associated marks, and podcast content belong to
their respective owners. This project is not affiliated with or endorsed by
Daily Stoic, Ryan Holiday, Backyard Ventures, or Penguin Random House.

The public RSS feed is used to identify and play an episode. Its availability
is not treated as a grant of a broader content license. If a rights holder asks
for a change or removal, distribution should pause while the request is
reviewed. Please report such concerns through this repository's issue tracker.

## Requirements

- Omarchy Quattro with third-party shell plugin support
- Python 3
- Qt 6 Multimedia QML support and the system MP3 playback backend
- `xdg-open` for the optional official-page action

The plugin has no install hook, package manager, privileged command, account,
API key, or third-party Python dependency.

## Install

Omarchy plugins run as unsandboxed code inside `omarchy-shell`. Review this
repository before installation, then run:

```bash
omarchy plugin add https://github.com/davidojedalopez/omarchy-stoic-podcast.git --enable
```

The permanent plugin ID is `dev.davidojeda.stoic-podcast`.

## Usage

1. Select the generic play icon in the bar.
2. Wait for the newest episode title and publication time.
3. Select **Play** to start streaming. The plugin never autoplays.
4. Use Pause, the 15-second seek controls, or the progress slider.
5. Select **Official episode page** to open the official podcast page.

Closing the panel does not stop audio because playback is owned by the
persistent bar widget. Disabling the plugin or restarting the shell stops it.
The progress controls are available only when the media backend reports that
the remote stream is seekable.

## Sources and data boundary

- Official podcast RSS: <https://rss.art19.com/the-daily-stoic>
- Official fallback page: <https://dailystoic.com/podcast/>

The helper reads only the first RSS item and returns:

- episode title;
- publication timestamp;
- duration when supplied;
- HTTPS audio enclosure URL;
- HTTPS episode link, or the official fallback page.

It does not return or display feed bodies, transcripts, images, author
biographies, or other long-form content. Test fixtures are synthetic and use
fictional titles and `example.test` URLs.

## Network access and privacy

The plugin fetches the RSS feed from `rss.art19.com` at startup and no more
often than every 30 minutes while idle. Audio is requested directly from the
enclosure URL in that feed. The enclosure can redirect through publisher or
distributor measurement hosts before reaching the audio CDN; those hosts can
change without a plugin release.

This code adds no analytics, cookies, accounts, telemetry, or user profiling.
As with any direct network client, remote servers receive the connection IP,
standard transport metadata, and the plugin's descriptive feed User-Agent.
No live RSS XML or audio is written to disk by the plugin.

## Development and validation

Run the deterministic checks without network access:

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 -m json.tool manifest.json >/dev/null
qmllint BarWidget.qml Panel.qml PodcastController.qml tests/qml/tst_PodcastController.qml
```

On an Omarchy Quattro machine, also run:

```bash
omarchy plugin validate .
qmltestrunner -import "$OMARCHY_PATH/shell" -import "$PWD" -input tests/qml
```

The QML test requires Omarchy's Quickshell import tree. CI intentionally does
not fetch the live podcast or try to emulate a full Omarchy shell session.

For a release smoke test, install from the final Git URL, confirm that playback
does not begin before user input, and verify Play, Pause, seeking, panel close
and reopen, the official-page action, offline Retry, keyboard focus, and Escape.

## Remove

```bash
omarchy plugin remove dev.davidojeda.stoic-podcast
```

## License

The MIT license covers this repository's source code only. It grants no rights
to third-party podcast content, names, marks, images, or audio.
