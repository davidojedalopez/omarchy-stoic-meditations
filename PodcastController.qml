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
  property bool refreshing: false
  property bool feedTimedOut: false
  property bool feedTerminationPending: false
  property bool retryAfterTermination: false

  readonly property bool loading: status === "loading" || refreshing
  readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
  readonly property bool paused: player.playbackState === MediaPlayer.PausedState
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

  function failFeed(message) {
    refreshing = false
    errorMessage = message || "Unable to load the latest episode."
    playWhenReady = false
    status = audioUrl ? "ready" : "error"
  }

  function failPlayback(message) {
    refreshing = false
    player.stop()
    status = "error"
    errorMessage = message || "Audio playback failed."
    playWhenReady = false
  }

  function refresh() {
    if (feedTerminationPending) {
      retryAfterTermination = true
      return
    }
    if (feedProcess.running)
      return

    refreshing = Boolean(audioUrl)
    if (!audioUrl)
      status = "loading"
    errorMessage = ""
    feedTimedOut = false
    feedProcess.command = ["python3", scriptPath()]
    feedWatchdog.restart()
    feedProcess.running = true
  }

  function scheduledRefresh() {
    if (player.playbackState !== MediaPlayer.StoppedState)
      return
    refresh()
  }

  function applyPayload(text) {
    var payload
    try {
      payload = JSON.parse(String(text || ""))
    } catch (error) {
      failFeed("The podcast feed returned invalid data.")
      return
    }

    if (!payload || payload.ok !== true) {
      failFeed(payload && payload.error ? String(payload.error) : "Unable to load the latest episode.")
      return
    }

    if (typeof payload.title !== "string" || payload.title.length === 0
        || !isHttps(payload.audioUrl)
        || (payload.episodeUrl && !isHttps(payload.episodeUrl))) {
      failFeed("The podcast feed returned unsafe or incomplete data.")
      return
    }

    var seconds = Number(payload.durationSeconds || 0)
    if (!isFinite(seconds) || seconds < 0) {
      failFeed("The podcast feed returned an invalid duration.")
      return
    }

    if (audioUrl && audioUrl !== payload.audioUrl
        && player.playbackState !== MediaPlayer.StoppedState) {
      refreshing = false
      errorMessage = ""
      status = "ready"
      return
    }

    title = payload.title
    publishedAt = typeof payload.published === "string" ? payload.published : ""
    feedDurationMs = Math.round(seconds * 1000)
    audioUrl = payload.audioUrl
    episodeUrl = payload.episodeUrl || "https://dailystoic.com/podcast/"
    refreshing = false
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
    feedWatchdog.stop()
    player.stop()
    status = "idle"
    errorMessage = ""
    title = ""
    publishedAt = ""
    feedDurationMs = 0
    audioUrl = ""
    episodeUrl = "https://dailystoic.com/podcast/"
    playWhenReady = false
    refreshing = false
    feedTimedOut = false
    feedTerminationPending = false
    retryAfterTermination = false
  }

  MediaPlayer {
    id: player
    source: root.audioUrl
    audioOutput: AudioOutput {}

    onErrorOccurred: function(error, errorString) {
      root.failPlayback(errorString || "Audio playback failed.")
    }
  }

  Process {
    id: feedProcess

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        feedWatchdog.stop()
        if (root.feedTimedOut) {
          root.feedTimedOut = false
          root.feedTerminationPending = false
          if (root.retryAfterTermination) {
            root.retryAfterTermination = false
            Qt.callLater(root.refresh)
          }
          return
        }
        var output = String(text || "").trim()
        if (output)
          root.applyPayload(output)
        else
          root.failFeed("Unable to fetch the podcast feed.")
      }
    }

    stderr: StdioCollector {
      waitForEnd: true
    }
  }

  Timer {
    id: feedWatchdog
    interval: 20 * 1000
    repeat: false
    onTriggered: {
      if (!feedProcess.running) return
      root.feedTimedOut = true
      root.feedTerminationPending = true
      feedProcess.running = false
      root.failFeed("The podcast feed request timed out.")
    }
  }

  Timer {
    interval: 30 * 60 * 1000
    repeat: true
    running: root.autoRefresh
    onTriggered: root.scheduledRefresh()
  }

  Component.onCompleted: {
    if (autoRefresh)
      Qt.callLater(refresh)
  }
}
