import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Measurement mode (spec 007 Story 5, development only): stores each capture's text, strip images, reading key, outline and
// detector timings against the manifest row chosen before the shutter, then shows the next row. A capture counts only once
// stored. For spec 009's live sitting it also records what the collector did with each reading (AC-9.2): adds with the
// candidate's rank, Undo, and opening a copy's details. The add and Undo requests themselves never carry a rank.
export default class extends Controller {
  static targets = [ "row", "status", "retry" ]
  static values = { capturesUrl: String, eventsUrl: String }

  async store({ detail: { nameText, collectorText, ms, key, outline, detectMs, warpMs, strips } }) {
    const body = new FormData()
    body.append("capture[file]", this.rowTarget.value)
    body.append("capture[name_text]", nameText)
    body.append("capture[collector_text]", collectorText)
    body.append("capture[ms]", String(ms))
    body.append("capture[user_agent]", navigator.userAgent)
    body.append("capture[reading_key]", key || "")
    body.append("capture[outline]", outline || "")
    body.append("capture[detect_ms]", detectMs ?? "")
    body.append("capture[warp_ms]", warpMs ?? "")
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
        headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": csrfToken() } })
      if (!response.ok && response.status !== 422) throw new Error(`HTTP ${response.status}`)
      Turbo.renderStreamMessage(await response.text())
    } catch {
      this.statusTarget.textContent = "The capture wasn't stored, so it doesn't count yet. Store it again."
      this.statusTarget.hidden = false
      this.retryTarget.hidden = false
    }
  }

  submitted({ target, detail: { success } }) {
    const kind = target.dataset?.scannerEvent
    if (!success || !kind) return
    const key = target.querySelector("input[name='entry[reading_key]']")?.value || target.dataset.readingKey
    this.event({ kind, rank: target.dataset.rank || "", reading_key: key || "" })
  }

  clicked({ target }) {
    const link = target.closest?.("a[data-scanner-event]")
    if (link) this.event({ kind: link.dataset.scannerEvent, rank: "", reading_key: link.dataset.readingKey || "" })
  }

  event(fields) {
    const body = new FormData()
    Object.entries(fields).forEach(([ name, value ]) => body.append(`event[${name}]`, value))
    fetch(this.eventsUrlValue, { method: "POST", body, keepalive: true, headers: { "X-CSRF-Token": csrfToken() } }).catch(() => {})
  }
}

function png(canvas) {
  return new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
}

function csrfToken() {
  return document.querySelector("meta[name=csrf-token]")?.content
}
