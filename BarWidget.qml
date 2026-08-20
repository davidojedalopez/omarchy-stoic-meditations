import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "dev.davidojeda.stoic-meditations"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false
  readonly property real openPanelIndicatorWidth: button.labelWidth

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    target.meditation = meditation
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  MeditationController {
    id: meditation
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰂺"
    active: root.opened
    tooltipText: meditation.currentEntry
      ? "Stoic Meditations — " + meditation.currentEntry.author
      : "Stoic Meditations"
    Accessible.role: Accessible.Button
    Accessible.name: root.opened
      ? "Close Stoic Meditations"
      : "Open Stoic Meditations"

    onPressed: function(button) {
      if (button === Qt.LeftButton) root.togglePanel()
    }
  }
}
