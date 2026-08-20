import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dev.davidojeda.stoic-meditations"
  ipcTarget: "dev.davidojeda.stoic-meditations"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var meditation: null
  property int keyboardIndex: 0
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var keyboardActions: meditation && meditation.status === "error"
    ? ["retry"]
    : ["previous", "today", "next", "edition"]
  readonly property string currentKeyboardAction: keyboardActions.length > 0
    ? keyboardActions[Math.min(keyboardIndex, keyboardActions.length - 1)]
    : ""
  readonly property string selectedDateKey: meditation
    ? Qt.formatDate(meditation.selectedDate, "yyyy-MM-dd")
    : ""

  function resetKeyboardCursor() {
    keyboardIndex = meditation && meditation.status === "error" ? 0 : 1
  }

  function moveKeyboardCursor(delta) {
    var count = keyboardActions.length
    if (count === 0 || delta === 0) return
    keyboardIndex = (keyboardIndex + (delta > 0 ? 1 : -1) + count) % count
    Qt.callLater(ensureKeyboardCursorVisible)
  }

  function keyboardActionItem(name) {
    if (name === "previous") return previousButton
    if (name === "today") return todayButton
    if (name === "next") return nextButton
    if (name === "edition") return editionButton
    if (name === "retry") return retryButton
    return null
  }

  function ensureKeyboardCursorVisible() {
    var item = keyboardActionItem(currentKeyboardAction)
    if (!item || !contentFlick || !contentFlick.contentItem) return
    var point = item.mapToItem(contentFlick.contentItem, 0, 0)
    var margin = Style.space(6)
    var top = point.y
    var bottom = top + item.height
    var maximum = Math.max(0, contentFlick.contentHeight - contentFlick.height)
    if (top < contentFlick.contentY + margin)
      contentFlick.contentY = Math.max(0, top - margin)
    else if (bottom > contentFlick.contentY + contentFlick.height - margin)
      contentFlick.contentY = Math.min(maximum, bottom + margin - contentFlick.height)
  }

  function resetReadingPosition() {
    if (contentFlick) contentFlick.contentY = 0
  }

  function scrollReading(delta) {
    if (!contentFlick || delta === 0) return
    var maximum = Math.max(0, contentFlick.contentHeight - contentFlick.height)
    contentFlick.contentY = Math.max(0, Math.min(
      maximum,
      contentFlick.contentY + delta * Style.space(56)))
  }

  function actionSelected(name) {
    return currentKeyboardAction === name
  }

  function openEdition() {
    var source = meditation ? meditation.currentSource : null
    var url = source && source.editionUrl ? String(source.editionUrl) : ""
    if (url.indexOf("https://standardebooks.org/") === 0)
      Quickshell.execDetached(["xdg-open", url])
  }

  function activateKeyboardAction() {
    if (!meditation) return
    if (currentKeyboardAction === "previous") meditation.previous()
    else if (currentKeyboardAction === "today") meditation.today()
    else if (currentKeyboardAction === "next") meditation.next()
    else if (currentKeyboardAction === "edition") openEdition()
    else if (currentKeyboardAction === "retry") meditation.load()
  }

  function open() {
    resetKeyboardCursor()
    root.controller.show()
    Qt.callLater(resetReadingPosition)
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  Connections {
    target: root.meditation
    function onStatusChanged() { root.resetKeyboardCursor() }
  }

  onSelectedDateKeyChanged: {
    resetKeyboardCursor()
    Qt.callLater(resetReadingPosition)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.scrollReading(dy)
        else if (dx !== 0) root.moveKeyboardCursor(dx)
      }
      onActivateRequested: root.activateKeyboardAction()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!root.meditation) return
        if (text === "t" || text === "T") root.meditation.today()
        else if (text === "r" || text === "R") root.meditation.load()
      }

      Flickable {
        id: contentFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: contentFlick.width
          spacing: Style.space(12)

          Text {
            width: parent.width
            text: root.meditation
              ? Qt.formatDate(root.meditation.selectedDate, "dddd, d MMMM yyyy")
              : ""
            color: Qt.darker(root.contentForeground, 1.45)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
          }

          Text {
            visible: root.meditation && root.meditation.status === "loading"
            width: parent.width
            text: "Opening the bundled readings…"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          Column {
            visible: root.meditation && root.meditation.status === "error"
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: root.meditation ? root.meditation.errorMessage : "Unable to open the readings."
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
            }

            Button {
              id: retryButton
              text: "Retry"
              iconText: "󰑓"
              focusable: true
              hasCursor: root.actionSelected("retry")
              bordered: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.meditation) root.meditation.load()
            }
          }

          Column {
            visible: root.meditation && root.meditation.currentEntry !== null
            width: parent.width
            spacing: Style.space(16)

            Text {
              width: parent.width
              text: root.meditation && root.meditation.currentEntry
                ? root.meditation.currentEntry.text
                : ""
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.heading
              font.weight: Font.Medium
              lineHeight: 1.45
              lineHeightMode: Text.ProportionalHeight
              wrapMode: Text.Wrap
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Text {
                width: parent.width
                text: root.meditation && root.meditation.currentEntry
                  ? "— " + root.meditation.currentEntry.author
                  : ""
                textFormat: Text.PlainText
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
              }

              Text {
                width: parent.width
                text: root.meditation && root.meditation.currentEntry
                  ? root.meditation.currentEntry.work + " · "
                    + root.meditation.currentEntry.locator + "\n"
                    + root.meditation.currentEntry.translator + " translation"
                  : ""
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.45)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                lineHeight: 1.35
                lineHeightMode: Text.ProportionalHeight
                wrapMode: Text.Wrap
              }
            }
          }

          Row {
            id: navigationRow
            visible: root.meditation && root.meditation.currentEntry !== null
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(2)
            readonly property real buttonHeight: Math.max(
              previousButton.implicitHeight,
              todayButton.implicitHeight,
              nextButton.implicitHeight)

            Button {
              id: previousButton
              text: "Previous"
              iconText: "󰁍"
              height: navigationRow.buttonHeight
              focusable: true
              hasCursor: root.actionSelected("previous")
              bordered: false
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.meditation) root.meditation.previous()
            }

            Button {
              id: todayButton
              text: "Today"
              height: navigationRow.buttonHeight
              focusable: true
              hasCursor: root.actionSelected("today")
              bordered: false
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.meditation) root.meditation.today()
            }

            Button {
              id: nextButton
              text: "Next"
              iconText: "󰁔"
              height: navigationRow.buttonHeight
              focusable: true
              hasCursor: root.actionSelected("next")
              bordered: false
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.meditation) root.meditation.next()
            }
          }

          Row {
            visible: root.meditation && root.meditation.currentEntry !== null
            width: parent.width

            Button {
              id: editionButton
              text: "View source edition"
              iconText: "󰏌"
              focusable: true
              hasCursor: root.actionSelected("edition")
              bordered: false
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.openEdition()
            }
          }
        }
      }
    }
  }
}
