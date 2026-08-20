from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class QmlContractTest(unittest.TestCase):
    def test_controller_uses_feed_payload_field_and_preserves_active_playback(self):
        source = (ROOT / "PodcastController.qml").read_text(encoding="utf-8")

        self.assertIn("payload.published", source)
        self.assertIn("player.playbackState !== MediaPlayer.StoppedState", source)
        self.assertNotIn("if (audioUrl)\n      return\n    refresh()", source)
        self.assertIn('status = audioUrl ? "ready" : "error"', source)
        self.assertIn("property bool refreshing: false", source)

    def test_controller_parses_stdout_when_the_collector_finishes(self):
        source = (ROOT / "PodcastController.qml").read_text(encoding="utf-8")

        self.assertIn("onStreamFinished:", source)
        self.assertNotIn("if (feedStdout.text)", source)
        self.assertIn("id: feedWatchdog", source)
        self.assertIn("feedProcess.running = false", source)
        self.assertIn("feedTerminationPending", source)
        self.assertIn("retryAfterTermination", source)

    def test_bar_widget_owns_controller_and_nested_panel(self):
        source = (ROOT / "BarWidget.qml").read_text(encoding="utf-8")

        self.assertIn("PodcastController {", source)
        self.assertIn('Qt.resolvedUrl("Panel.qml")', source)
        self.assertIn("function open()", source)
        self.assertIn("function close()", source)
        self.assertIn("function togglePanel()", source)
        self.assertIn("target.podcast = podcast", source)
        self.assertIn('"Close Daily Stoic podcast controls"', source)
        self.assertIn('"Open Daily Stoic podcast controls"', source)

    def test_panel_exposes_playback_and_official_link_controls(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")

        self.assertIn("PanelSlider {", source)
        self.assertIn("podcast.togglePlayback()", source)
        self.assertIn("podcast.seekRelative(-15000)", source)
        self.assertIn("podcast.seekRelative(15000)", source)
        self.assertIn('Accessible.name: "Back 15 seconds"', source)
        self.assertIn('Accessible.name: "Forward 15 seconds"', source)
        self.assertIn('Quickshell.execDetached(["xdg-open", podcast.episodeUrl])', source)
        self.assertIn("Unofficial", source)
        self.assertNotIn("description", source.lower())
        self.assertNotIn("artwork", source.lower())

    def test_panel_treats_feed_titles_as_plain_text_and_scrolls_overflow(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")

        self.assertIn("textFormat: Text.PlainText", source)
        self.assertIn("Flickable {", source)
        self.assertIn("contentHeight: content.implicitHeight", source)
        self.assertIn("function ensureKeyboardCursorVisible()", source)

    def test_panel_buttons_are_keyboard_focusable(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")

        self.assertGreaterEqual(source.count("focusable: true"), 4)
        self.assertIn("PanelKeyCatcher {", source)
        self.assertIn("focusTarget: keyCatcher", source)
        self.assertIn("onMoveRequested:", source)
        self.assertIn("onActivateRequested:", source)
        self.assertIn("hasCursor:", source)
        self.assertIn("onCloseRequested: root.close()", source)
        self.assertIn("onTabRequested:", source)


if __name__ == "__main__":
    unittest.main()
