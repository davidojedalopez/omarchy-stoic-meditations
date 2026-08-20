import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  visible: false
  width: 0
  height: 0

  property bool autoLoad: true
  property bool autoTick: true
  property int dayOffset: 0
  property date currentDate: new Date()
  property var corpus: null
  property string status: "idle"
  property string errorMessage: ""

  readonly property bool loaded: status === "ready" && corpus !== null
  readonly property var currentEntry: loaded
    ? Model.selectEntry(corpus, currentDate, dayOffset)
    : null
  readonly property var currentSource: currentEntry
    ? Model.sourceById(corpus, currentEntry.sourceId)
    : null
  readonly property date selectedDate: Model.shiftedLocalDate(currentDate, dayOffset)

  function setCorpus(value) {
    if (!value || value.schemaVersion !== 1
        || !(value.sources instanceof Array)
        || !(value.entries instanceof Array)
        || !(value.schedule instanceof Array)
        || value.entries.length === 0
        || value.schedule.length === 0) {
      corpus = null
      status = "error"
      errorMessage = "The bundled meditation corpus is invalid."
      return false
    }
    corpus = value
    status = "ready"
    errorMessage = ""
    return true
  }

  function load() {
    if (status === "loading") return
    status = "loading"
    errorMessage = ""
    corpusFile.reload()
  }

  function corpusPath() {
    var value = Qt.resolvedUrl("data/meditations.json").toString()
    if (value.indexOf("file://") === 0) value = value.slice(7)
    return decodeURIComponent(value)
  }

  function previous() { dayOffset -= 1 }
  function next() { dayOffset += 1 }
  function today() {
    currentDate = new Date()
    dayOffset = 0
  }

  Timer {
    interval: 60 * 1000
    repeat: true
    running: root.autoTick
    onTriggered: root.currentDate = new Date()
  }

  FileView {
    id: corpusFile
    path: root.corpusPath()
    watchChanges: false
    printErrors: false

    onLoaded: {
      try {
        root.setCorpus(JSON.parse(text()))
      } catch (error) {
        root.corpus = null
        root.status = "error"
        root.errorMessage = "The bundled meditation corpus could not be parsed."
      }
    }

    onLoadFailed: function(error) {
      root.corpus = null
      root.status = "error"
      root.errorMessage = "Unable to read the bundled meditation corpus."
    }
  }

  Component.onCompleted: if (autoLoad) Qt.callLater(load)
}
