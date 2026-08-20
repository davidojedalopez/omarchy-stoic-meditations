import QtQuick
import QtMultimedia
import Quickshell.Io

Item {
  id: root

  visible: false
  width: 0
  height: 0

  property bool autoRefresh: true
  property string status: "idle"
  property string errorMessage: ""
  property string title: ""
  property string publishedAt: ""
  property int feedDurationMs: 0
  property string audioUrl: ""
  property string episodeUrl: "https://dailystoic.com/podcast/"
  property bool playWhenReady: false

  readonly property bool loading: status === "loading"
  readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
  readonly property int position: player.position
  readonly property int duration: player.duration > 0 ? player.duration : feedDurationMs
  readonly property bool seekable: player.seekable

  function scriptPath() {
    var value = Qt.resolvedUrl("scripts/feed_client.py").toString()
    if (value.indexOf("file://") === 0)
      value = value.slice(7)
    return decodeURIComponent(value)
  }

  function isHttps(value) {
    return typeof value === "string" && value.indexOf("https://") === 0
  }

  function fail(message) {
    status = "error"
    errorMessage = message || "Unable to load the latest episode."
    playWhenReady = false
  }

  function refresh() {
    if (feedProcess.running)
      return

    status = "loading"
    errorMessage = ""
    feedProcess.command = ["python3", scriptPath()]
    feedProcess.running = true
  }

  function applyPayload(text) {
    var payload
    try {
      payload = JSON.parse(String(text || ""))
    } catch (error) {
      fail("The podcast feed returned invalid data.")
      return
    }

    if (!payload || payload.ok !== true) {
      fail(payload && payload.error ? String(payload.error) : "Unable to load the latest episode.")
      return
    }

    if (typeof payload.title !== "string" || payload.title.length === 0
        || !isHttps(payload.audioUrl)
        || (payload.episodeUrl && !isHttps(payload.episodeUrl))) {
      fail("The podcast feed returned unsafe or incomplete data.")
      return
    }

    var seconds = Number(payload.durationSeconds || 0)
    if (!isFinite(seconds) || seconds < 0) {
      fail("The podcast feed returned an invalid duration.")
      return
    }

    if (audioUrl && audioUrl !== payload.audioUrl)
      player.stop()

    title = payload.title
    publishedAt = typeof payload.publishedAt === "string" ? payload.publishedAt : ""
    feedDurationMs = Math.round(seconds * 1000)
    audioUrl = payload.audioUrl
    episodeUrl = payload.episodeUrl || "https://dailystoic.com/podcast/"
    status = "ready"
    errorMessage = ""

    if (playWhenReady) {
      playWhenReady = false
      player.play()
    }
  }

  function togglePlayback() {
    if (!audioUrl || status === "idle" || status === "error") {
      playWhenReady = true
      refresh()
      return
    }

    playWhenReady = false
    if (playing)
      player.pause()
    else
      player.play()
  }

  function retry() {
    playWhenReady = false
    refresh()
  }

  function clampPosition(value, maximum) {
    return Math.max(0, Math.min(Number(value) || 0, Math.max(0, Number(maximum) || 0)))
  }

  function seekTo(value) {
    if (!seekable)
      return
    player.position = clampPosition(value, duration)
  }

  function seekRelative(delta) {
    seekTo(position + Number(delta || 0))
  }

  function resetForTest() {
    if (feedProcess.running)
      feedProcess.running = false
    player.stop()
    status = "idle"
    errorMessage = ""
    title = ""
    publishedAt = ""
    feedDurationMs = 0
    audioUrl = ""
    episodeUrl = "https://dailystoic.com/podcast/"
    playWhenReady = false
  }

  MediaPlayer {
    id: player
    source: root.audioUrl
    audioOutput: AudioOutput {}

    onErrorOccurred: function(error, errorString) {
      root.fail(errorString || "Audio playback failed.")
    }
  }

  Process {
    id: feedProcess

    stdout: StdioCollector {
      id: feedStdout
      waitForEnd: true
    }

    stderr: StdioCollector {
      id: feedStderr
      waitForEnd: true
    }

    onExited: function(exitCode) {
      if (feedStdout.text)
        root.applyPayload(feedStdout.text)
      else if (exitCode !== 0)
        root.fail("Unable to fetch the podcast feed.")
      else
        root.fail("The podcast feed returned no data.")
    }
  }

  Timer {
    interval: 30 * 60 * 1000
    repeat: true
    running: root.autoRefresh
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    if (autoRefresh)
      Qt.callLater(refresh)
  }
}
