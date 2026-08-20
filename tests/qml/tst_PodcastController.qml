import QtQuick
import QtTest
import "../.." as Plugin

TestCase {
  name: "PodcastController"

  Plugin.PodcastController {
    id: controller
    autoRefresh: false
  }

  function cleanup() {
    controller.resetForTest()
  }

  function test_rejects_insecure_audio_url() {
    controller.applyPayload(JSON.stringify({
      ok: true,
      title: "A lesson",
      publishedAt: "2026-08-20T07:00:00+00:00",
      durationSeconds: 120,
      audioUrl: "http://example.com/lesson.mp3",
      episodeUrl: "https://dailystoic.com/podcast/"
    }))

    compare(controller.status, "error")
    verify(controller.errorMessage.length > 0)
    compare(controller.audioUrl, "")
  }

  function test_accepts_valid_metadata_without_autoplay() {
    controller.applyPayload(JSON.stringify({
      ok: true,
      title: "A lesson",
      publishedAt: "2026-08-20T07:00:00+00:00",
      durationSeconds: 120,
      audioUrl: "https://example.com/lesson.mp3",
      episodeUrl: "https://dailystoic.com/podcast/"
    }))

    compare(controller.status, "ready")
    compare(controller.title, "A lesson")
    compare(controller.duration, 120000)
    compare(controller.playing, false)
  }

  function test_rejects_invalid_json() {
    controller.applyPayload("not-json")

    compare(controller.status, "error")
    verify(controller.errorMessage.length > 0)
  }

  function test_clamps_seek_position() {
    compare(controller.clampPosition(-1, 1000), 0)
    compare(controller.clampPosition(400, 1000), 400)
    compare(controller.clampPosition(1200, 1000), 1000)
  }
}
