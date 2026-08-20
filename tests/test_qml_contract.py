from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class QmlContractTest(unittest.TestCase):
    def test_runtime_has_no_network_process_or_media_dependencies(self):
        runtime = "\n".join(
            (ROOT / name).read_text(encoding="utf-8")
            for name in ("BarWidget.qml", "Panel.qml", "MeditationController.qml")
        )
        self.assertNotIn("QtMultimedia", runtime)
        self.assertNotIn("Process {", runtime)
        self.assertNotIn("XMLHttpRequest", runtime)
        self.assertNotIn("http://", runtime)
        self.assertNotIn("rss", runtime.lower())
        self.assertIn("FileView {", runtime)
        self.assertIn('Qt.resolvedUrl("data/meditations.json")', runtime)

    def test_bar_widget_owns_controller_and_nested_panel(self):
        source = (ROOT / "BarWidget.qml").read_text(encoding="utf-8")
        self.assertIn("MeditationController {", source)
        self.assertIn('Qt.resolvedUrl("Panel.qml")', source)
        self.assertIn("target.meditation = meditation", source)
        self.assertIn('"Close Stoic Meditations"', source)
        self.assertIn('"Open Stoic Meditations"', source)

    def test_panel_displays_complete_plain_text_and_attribution(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("textFormat: Text.PlainText"), 3)
        self.assertIn("root.meditation.currentEntry.text", source)
        self.assertIn('root.meditation.currentEntry.translator + " translation"', source)
        self.assertIn("root.meditation.currentEntry.locator", source)
        self.assertIn('"— " + root.meditation.currentEntry.author', source)
        self.assertLess(
            source.index("Qt.formatDate(root.meditation.selectedDate"),
            source.index("root.meditation.currentEntry.text"),
        )
        self.assertLess(
            source.index("root.meditation.currentEntry.text"),
            source.index('"— " + root.meditation.currentEntry.author'),
        )
        self.assertLess(
            source.index('"— " + root.meditation.currentEntry.author'),
            source.index("root.meditation.currentEntry.work"),
        )
        self.assertNotIn('text: "STOIC MEDITATION"', source)
        self.assertNotIn("Offline · public-domain", source)
        self.assertNotIn("maximumLineCount", source)
        self.assertNotIn("Text.ElideRight", source)
        self.assertIn("Flickable {", source)
        self.assertIn("contentHeight: content.implicitHeight", source)

    def test_panel_has_date_navigation_and_safe_edition_controls(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.assertNotIn("toggleSource", source)
        self.assertNotIn("includeMarcusMeditations", source)
        self.assertIn("meditation.previous()", source)
        self.assertIn("meditation.today()", source)
        self.assertIn("meditation.next()", source)
        self.assertIn('url.indexOf("https://standardebooks.org/")', source)
        self.assertIn('Quickshell.execDetached(["xdg-open", url])', source)

    def test_navigation_buttons_share_height_without_tooltips(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn("id: navigationRow", source)
        self.assertIn("readonly property real buttonHeight: Math.max(", source)
        self.assertEqual(source.count("height: navigationRow.buttonHeight"), 3)
        self.assertNotIn('tooltipText: "Previous day"', source)
        self.assertNotIn('tooltipText: "Return to today\'s meditation"', source)
        self.assertNotIn('tooltipText: "Next day"', source)

    def test_panel_controls_are_keyboard_accessible(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.assertGreaterEqual(source.count("focusable: true"), 4)
        self.assertIn("PanelKeyCatcher {", source)
        self.assertIn("focusTarget: keyCatcher", source)
        self.assertIn("onMoveRequested:", source)
        self.assertIn("onActivateRequested:", source)
        self.assertIn("hasCursor:", source)
        self.assertIn("onCloseRequested: root.close()", source)
        self.assertIn("onTabRequested:", source)

    def test_long_readings_use_a_bounded_scrollable_surface(self):
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn(
            "contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))",
            source,
        )
        self.assertIn("ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }", source)
        self.assertIn("function resetReadingPosition()", source)
        self.assertIn("onSelectedDateKeyChanged:", source)
        self.assertIn("Qt.callLater(resetReadingPosition)", source)
        self.assertIn("if (dy !== 0) root.scrollReading(dy)", source)
        self.assertIn("else if (dx !== 0) root.moveKeyboardCursor(dx)", source)


if __name__ == "__main__":
    unittest.main()
