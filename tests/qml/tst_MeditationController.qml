import QtQuick
import QtTest
import "../../Model.js" as Model
import "../.." as Plugin

TestCase {
  name: "MeditationController"

  readonly property var sampleCorpus: ({
    schemaVersion: 1,
    sources: [
      { id: "marcus-meditations", editionUrl: "https://standardebooks.org/marcus" },
      { id: "epictetus-enchiridion", editionUrl: "https://standardebooks.org/enchiridion" },
      { id: "epictetus-discourses", editionUrl: "https://standardebooks.org/discourses" }
    ],
    entries: [
      { id: "m1", sourceId: "marcus-meditations", text: "Marcus" },
      { id: "e1", sourceId: "epictetus-enchiridion", text: "Enchiridion" },
      { id: "d1", sourceId: "epictetus-discourses", text: "Discourses" }
    ],
    schedule: ["m1", "e1", "d1"]
  })

  Plugin.MeditationController {
    id: controller
    autoLoad: false
    autoTick: false
    currentDate: new Date(2026, 0, 1, 23, 30)
  }

  Plugin.MeditationController {
    id: bundledController
    autoLoad: true
    autoTick: false
  }

  function init() {
    controller.dayOffset = 0
    verify(controller.setCorpus(sampleCorpus))
  }

  function test_selection_is_stable_for_same_local_date() {
    var first = controller.currentEntry.id
    controller.currentDate = new Date(2026, 0, 1, 1, 15)
    compare(controller.currentEntry.id, first)
  }

  function test_bundled_corpus_loads_from_local_json() {
    tryCompare(bundledController, "status", "ready", 3000)
    verify(bundledController.currentEntry !== null)
    verify(bundledController.corpus.entries.length > 600)
  }

  function test_combined_schedule_is_canonical() {
    compare(controller.currentEntry.id, "m1")
    controller.next()
    compare(controller.currentEntry.id, "e1")
    controller.next()
    compare(controller.currentEntry.id, "d1")
  }

  function test_navigation_handles_dates_before_epoch() {
    compare(Model.positiveModulo(-1, 3), 2)
    controller.currentDate = new Date(2025, 11, 31)
    verify(controller.currentEntry !== null)
    controller.previous()
    compare(controller.dayOffset, -1)
    controller.next()
    compare(controller.dayOffset, 0)
  }

  function test_utc_ordinal_uses_calendar_date_across_dst_and_leap_day() {
    var beforeDst = new Date(2026, 2, 8, 1, 30)
    var afterDst = new Date(2026, 2, 9, 1, 30)
    compare(
      Model.utcOrdinalForLocalDate(afterDst) - Model.utcOrdinalForLocalDate(beforeDst),
      1
    )
    compare(
      Model.utcOrdinalForLocalDate(new Date(2028, 2, 1))
        - Model.utcOrdinalForLocalDate(new Date(2028, 1, 28)),
      2
    )
  }
}
