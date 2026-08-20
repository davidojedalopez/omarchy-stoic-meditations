from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class QmlContractTest(unittest.TestCase):
    def test_controller_uses_feed_payload_field_and_skips_timed_refresh_while_playing(self):
        source = (ROOT / "PodcastController.qml").read_text(encoding="utf-8")

        self.assertIn("payload.published", source)
        self.assertIn("if (playing && audioUrl)", source)

    def test_bar_widget_owns_controller_and_nested_panel(self):
        source = (ROOT / "BarWidget.qml").read_text(encoding="utf-8")

        self.assertIn("PodcastController {", source)
        self.assertIn('Qt.resolvedUrl("Panel.qml")', source)
        self.assertIn("function open()", source)
        self.assertIn("function close()", source)
        self.assertIn("function togglePanel()", source)
        self.assertIn("target.podcast = podcast", source)

    def test_panel_exposes_playback_and_official_link_controls(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")

        self.assertIn("PanelSlider {", source)
        self.assertIn("podcast.togglePlayback()", source)
        self.assertIn("podcast.seekRelative(-15000)", source)
        self.assertIn("podcast.seekRelative(15000)", source)
        self.assertIn('Quickshell.execDetached(["xdg-open", podcast.episodeUrl])', source)
        self.assertIn("Unofficial", source)
        self.assertNotIn("description", source.lower())
        self.assertNotIn("artwork", source.lower())

    def test_panel_buttons_are_keyboard_focusable(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")

        self.assertGreaterEqual(source.count("focusable: true"), 4)
        self.assertIn("PanelKeyCatcher {", source)
        self.assertIn("onCloseRequested: root.close()", source)
        self.assertIn("onTabRequested:", source)


if __name__ == "__main__":
    unittest.main()
