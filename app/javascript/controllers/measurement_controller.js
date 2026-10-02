import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Measurement mode (spec 007 Story 5, development only): stores each capture's text and strip images against
// the manifest row chosen before the shutter, then shows the next row. A capture counts only once stored.
export default class extends Controller {
  static targets = [ "row", "status", "retry" ]
  static values = { capturesUrl: String }

  async store({ detail: { nameText, collectorText, ms, strips } }) {
    const body = new FormData()
    body.append("capture[file]", this.rowTarget.value)
    body.append("capture[name_text]", nameText)
    body.append("capture[collector_text]", collectorText)
    body.append("capture[ms]", String(ms))
    body.append("capture[user_agent]", navigator.userAgent)
    body.append("capture[name_strip]", await png(strips.name), "name.png")
    body.append("capture[collector_strip]", await png(strips.collector), "collector.png")
    this.pending = body
    await this.post()
  }

  retry() {
    if (this.pending) this.post()
  }

  async post() {
    this.retryTarget.hidden = true
    try {
      const response = await fetch(this.capturesUrlValue, { method: "POST", body: this.pending,
        headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content } })
      if (!response.ok && response.status !== 422) throw new Error(`HTTP ${response.status}`)
      Turbo.renderStreamMessage(await response.text())
    } catch {
      this.statusTarget.textContent = "The capture wasn't stored, so it doesn't count yet. Store it again."
      this.statusTarget.hidden = false
      this.retryTarget.hidden = false
    }
  }
}

function png(canvas) {
  return new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
}
