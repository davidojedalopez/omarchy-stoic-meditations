import QtQuick
import Quickshell

ShellRoot {
  MeditationController {
    id: meditation
    autoTick: false

    onStatusChanged: {
      if (status === "ready") {
        verifyLoaded.restart()
      } else if (status === "error") {
        console.error("Stoic meditation runtime smoke test failed:", errorMessage)
        Qt.exit(1)
      }
    }
  }

  Timer {
    id: verifyLoaded
    interval: 0
    onTriggered: {
      if (!meditation.currentEntry || meditation.corpus.entries.length < 600) {
        console.error("Stoic meditation runtime smoke test loaded incomplete data")
        Qt.exit(1)
        return
      }
      console.info(
        "Stoic meditation runtime smoke test loaded",
        meditation.corpus.entries.length,
        "entries"
      )
      Qt.exit(0)
    }
  }

  Timer {
    interval: 5000
    running: true
    onTriggered: {
      console.error("Stoic meditation runtime smoke test timed out")
      Qt.exit(1)
    }
  }
}
