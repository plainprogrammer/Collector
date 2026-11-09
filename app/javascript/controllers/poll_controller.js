import { Controller } from "@hotwired/stimulus"

// Keeps a page current while work is in flight (spec 015 FR-4, ADR 0015): every interval it asks Turbo to refresh the
// page, which morphs in what changed and keeps the scroll position. The server renders this controller only while
// something is queued or running, so when the work ends the refreshed page has no controller and the polling stops.
// It waits while the tab is hidden, while Turbo is busy, and while a menu is open (a refresh would close it); the
// menu pause is page-wide, any open <details>. A tab shown again refreshes at once instead of at the next tick, under
// the same pauses (#111).
export default class extends Controller {
  static values = { interval: { type: Number, default: 2000 } }

  connect() {
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
    this.shown = () => { if (!document.hidden) this.refresh() }
    document.addEventListener("visibilitychange", this.shown)
  }

  disconnect() {
    clearInterval(this.timer)
    document.removeEventListener("visibilitychange", this.shown)
  }

  refresh() {
    if (document.hidden || document.documentElement.hasAttribute("aria-busy")) return
    if (document.querySelector("details[open]")) return
    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
