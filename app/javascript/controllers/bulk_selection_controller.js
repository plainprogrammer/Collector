import { Controller } from "@hotwired/stimulus"

// Bulk mode's live count, mixed header and Esc (spec 006 AC-5.8, AC-4.6). Nothing is submitted here:
// the bulk form carries the ticks, their baselines and any header toggle with the next control pressed (FR-4).
// base = the server's selected copies not on this page; the count adds this page's ticked rows.
export default class extends Controller {
  static targets = ["count", "header", "row", "baseline", "toggled", "done"]
  static values = { matching: Number, base: Number }

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    // Capture phase: an open menu is still open here, before the menu controller closes it on Esc.
    document.addEventListener("keydown", this.onKeydown, true)
    this.render()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown, true)
  }

  toggle(event) {
    event.target.closest("tr")?.setAttribute("aria-selected", String(event.target.checked))
    this.render()
  }

  toggleAll() {
    const checked = this.headerTarget.checked
    this.rowTargets.forEach((row) => {
      row.checked = checked
      row.closest("tr")?.setAttribute("aria-selected", String(checked))
    })
    // Rows and baselines render in the same order: after a toggle every shown row matches the header,
    // so a later tick or untick on this page reaches the server as a change (spec v5.0.0 FR-4, AC-5.10).
    this.baselineTargets.forEach((baseline) => { baseline.disabled = !checked })
    this.toggledTarget.value = "1"
    this.baseValue = checked ? this.matchingValue - this.sum(this.rowTargets) : 0
    this.render()
  }

  render() {
    const count = this.baseValue + this.sum(this.rowTargets.filter((row) => row.checked))
    const all = this.hasHeaderTarget && this.headerTarget.checked
    if (this.hasHeaderTarget) this.headerTarget.indeterminate = all && count < this.matchingValue
    const format = (value) => new Intl.NumberFormat("en").format(value)
    const parts = all && count === this.matchingValue && count > 0
      ? [ "All ", this.number(format(count)), ` ${count === 1 ? "item" : "items"} selected` ]
      : [ this.number(format(count)), ` of ${format(this.matchingValue)} selected` ]
    this.countTarget.replaceChildren(...parts)
  }

  onKeydown(event) {
    if (event.key !== "Escape" || document.querySelector("details[open], dialog[open]")) return
    this.doneTarget.form.requestSubmit(this.doneTarget)
  }

  sum(rows) {
    return rows.reduce((total, row) => total + Number(row.dataset.quantity), 0)
  }

  number(text) {
    const span = document.createElement("span")
    span.textContent = text
    return span
  }
}
