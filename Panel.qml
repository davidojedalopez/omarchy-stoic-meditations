import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "dev.davidojeda.stoic-podcast"
  ipcTarget: "dev.davidojeda.stoic-podcast"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var podcast: null
  property int keyboardIndex: 0
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var keyboardActions: {
    if (podcast && podcast.status === "error") return ["retry", "page", "refresh"]
    if (podcast && (podcast.status === "ready" || podcast.playing))
      return ["back", "play", "forward", "page", "refresh"]
    return ["page", "refresh"]
  }
  readonly property string currentKeyboardAction: keyboardActions.length > 0
    ? keyboardActions[Math.min(keyboardIndex, keyboardActions.length - 1)]
    : ""

  function resetKeyboardCursor() {
    keyboardIndex = podcast && (podcast.status === "ready" || podcast.playing) ? 1 : 0
    Qt.callLater(ensureKeyboardCursorVisible)
  }

  function moveKeyboardCursor(delta) {
    var count = keyboardActions.length
    if (count === 0 || delta === 0) return
    keyboardIndex = (keyboardIndex + (delta > 0 ? 1 : -1) + count) % count
    Qt.callLater(ensureKeyboardCursorVisible)
  }

  function keyboardActionItem(name) {
    if (name === "retry") return retryButton
    if (name === "back") return backButton
    if (name === "play") return playButton
    if (name === "forward") return forwardButton
    if (name === "page") return pageButton
    if (name === "refresh") return refreshButton
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

  function actionSelected(name) {
    return currentKeyboardAction === name
  }

  function activateKeyboardAction() {
    if (!podcast) return
    if (currentKeyboardAction === "retry") podcast.retry()
    else if (currentKeyboardAction === "back") podcast.seekRelative(-15000)
    else if (currentKeyboardAction === "play") podcast.togglePlayback()
    else if (currentKeyboardAction === "forward") podcast.seekRelative(15000)
    else if (currentKeyboardAction === "page") openEpisodePage()
    else if (currentKeyboardAction === "refresh") podcast.refresh()
  }

  function open() {
    resetKeyboardCursor()
    root.controller.show()
    if (podcast && podcast.status === "idle") podcast.refresh()
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

  function formatTime(milliseconds) {
    var total = Math.max(0, Math.floor(Number(milliseconds || 0) / 1000))
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    var seconds = total % 60
    var tail = String(minutes).padStart(hours > 0 ? 2 : 1, "0") + ":" + String(seconds).padStart(2, "0")
    return hours > 0 ? hours + ":" + tail : tail
  }

  function formatPublished(value) {
    if (!value) return ""
    var date = new Date(value)
    if (isNaN(date.getTime())) return ""
    return Qt.formatDateTime(date, "ddd d MMM · HH:mm")
  }

  function openEpisodePage() {
    if (podcast && podcast.episodeUrl.indexOf("https://") === 0)
      Quickshell.execDetached(["xdg-open", podcast.episodeUrl])
  }

  Connections {
    target: root.podcast
    function onStatusChanged() { root.resetKeyboardCursor() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        root.moveKeyboardCursor(dx !== 0 ? dx : dy)
      }
      onActivateRequested: root.activateKeyboardAction()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!root.podcast) return
        if (text === "r" || text === "R") root.podcast.refresh()
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

        Column {
          id: content
          width: contentFlick.width
          spacing: Style.space(12)

        Text {
          width: parent.width
          text: "DAILY STOIC PODCAST"
          color: Qt.darker(root.contentForeground, 1.35)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1
          wrapMode: Text.Wrap
        }

        Text {
          visible: root.podcast && root.podcast.status === "loading"
          width: parent.width
          text: "Loading the latest episode…"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        Text {
          visible: root.podcast && root.podcast.status === "ready" && root.podcast.errorMessage.length > 0
          width: parent.width
          text: root.podcast ? root.podcast.errorMessage : ""
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }

        Column {
          visible: root.podcast && root.podcast.status === "error"
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: parent.width
            text: root.podcast ? root.podcast.errorMessage : "Unable to load the podcast."
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
            onClicked: if (root.podcast) root.podcast.retry()
          }
        }

        Column {
          visible: root.podcast && (root.podcast.status === "ready" || root.podcast.playing)
          width: parent.width
          spacing: Style.space(10)

          Text {
            width: parent.width
            text: root.podcast ? root.podcast.title : ""
            textFormat: Text.PlainText
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: root.podcast ? root.formatPublished(root.podcast.publishedAt) : ""
            color: Qt.darker(root.contentForeground, 1.45)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          PanelSlider {
            bar: root.bar
            width: parent.width
            minimum: 0
            maximum: Math.max(1, root.podcast ? root.podcast.duration : 0)
            step: 15000
            value: root.podcast ? root.podcast.position : 0
            onMoved: function(value) { if (root.podcast) root.podcast.seekTo(value) }
          }

          Row {
            width: parent.width

            Text {
              width: parent.width / 2
              text: root.formatTime(root.podcast ? root.podcast.position : 0)
              color: Qt.darker(root.contentForeground, 1.45)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              width: parent.width / 2
              text: root.formatTime(root.podcast ? root.podcast.duration : 0)
              horizontalAlignment: Text.AlignRight
              color: Qt.darker(root.contentForeground, 1.45)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            Button {
              id: backButton
              iconText: "󰒮"
              tooltipText: "Back 15 seconds"
              Accessible.role: Accessible.Button
              Accessible.name: "Back 15 seconds"
              focusable: true
              hasCursor: root.actionSelected("back")
              bordered: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.podcast) root.podcast.seekRelative(-15000)
            }

            Button {
              id: playButton
              iconText: root.podcast && root.podcast.playing ? "󰏤" : "󰐊"
              text: root.podcast && root.podcast.playing ? "Pause" : "Play"
              focusable: true
              hasCursor: root.actionSelected("play")
              bordered: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.podcast) root.podcast.togglePlayback()
            }

            Button {
              id: forwardButton
              iconText: "󰒭"
              tooltipText: "Forward 15 seconds"
              Accessible.role: Accessible.Button
              Accessible.name: "Forward 15 seconds"
              focusable: true
              hasCursor: root.actionSelected("forward")
              bordered: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.podcast) root.podcast.seekRelative(15000)
            }
          }
        }

        Row {
          spacing: Style.space(8)

          Button {
            id: pageButton
            text: "Official episode page"
            iconText: "󰏌"
            focusable: true
            hasCursor: root.actionSelected("page")
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.openEpisodePage()
          }

          Button {
            id: refreshButton
            text: root.podcast && root.podcast.refreshing ? "Refreshing…" : "Refresh"
            iconText: "󰑐"
            enabled: !root.podcast || !root.podcast.refreshing
            focusable: true
            hasCursor: root.actionSelected("refresh")
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (root.podcast) root.podcast.refresh()
          }
        }

        Text {
          width: parent.width
          text: "Unofficial client. Audio streams directly from the publisher-provided RSS enclosure. Not affiliated with or endorsed by Daily Stoic."
          color: Qt.darker(root.contentForeground, 1.6)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }
        }
      }
    }
  }
}
