import { Controller } from "@hotwired/stimulus"

// The selection pane's one small controller (spec 088 decision 6): it notes which card of the swipe row is centred and shows what
// that means. The server rendered everything else: every item, a panel for each (hidden unless centred) and, inside each panel, a
// <template> holding the band's icon and sentence. When the row's scrolling stops (about SETTLE ms after the last scroll event, so a
// fling is noted once) it takes the item nearest the row's centre, sets aria-current on it alone, shows its panel, copies the band
// in place (the one element's form class and children, so a live region announces the change: spec 080 decision 8), and disables
// Previous and Next at the ends, moving focus off a button that has just become disabled (spec 047). Previous, Next, the arrow
// keys and a tap on a neighbour do what a swipe does. When the frame renders again ("Show 20 more", "All printings") it restores
// the item the server marked, scrolling there at once. It holds no other state and sends nothing.
const SETTLE = 100

export default class extends Controller {
  static targets = [ "band", "row", "item", "panel", "prev", "next" ]

  disconnect() {
    clearTimeout(this.timer)
  }

  rowTargetConnected(row) {
    this.index = Math.max(0, this.itemTargets.findIndex((item) => item.getAttribute("aria-current") === "true"))
    this.apply(this.index)
    if (this.index > 0) this.scrollTo(this.index, "instant")
    if (row.dataset.selectionFocus) { // a frame request asked for focus on Next (the row when Next is disabled)
      delete row.dataset.selectionFocus
      this.focusOr(this.nextTarget, row)
    }
  }

  // The row went away (an add, "Scan again"): the band empties, unless the frame is only rendering again in the same batch.
  rowTargetDisconnected() {
    queueMicrotask(() => {
      if (this.hasRowTarget) return
      this.bandTarget.className = "c-band"
      this.bandTarget.replaceChildren()
    })
  }

  scrolled() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.settle(), SETTLE)
  }

  previous() { this.go(this.index - 1) }

  next() { this.go(this.index + 1) }

  key(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
    event.preventDefault()
    this.go(this.index + (event.key === "ArrowRight" ? 1 : -1))
  }

  tap(event) {
    const index = this.itemTargets.indexOf(event.target.closest(".c-scanpane__item"))
    if (index >= 0 && index !== this.index) this.go(index)
  }

  go(index) {
    if (index < 0 || index >= this.itemTargets.length) return
    this.apply(index)
    this.scrollTo(index)
  }

  settle() {
    if (!this.hasRowTarget) return // the row went away while the timer ran
    const row = this.rowTarget.getBoundingClientRect(), middle = row.left + row.width / 2
    let nearest = this.index, distance = Infinity
    this.itemTargets.forEach((item, index) => {
      const box = item.getBoundingClientRect(), apart = Math.abs(box.left + box.width / 2 - middle)
      if (apart < distance) { distance = apart; nearest = index }
    })
    if (nearest !== this.index) this.apply(nearest)
  }

  // Scrolls the item to the row's centre; without a behavior the row's own scroll-behavior decides (smooth, or at once under
  // prefers-reduced-motion).
  scrollTo(index, behavior) {
    const row = this.rowTarget, box = row.getBoundingClientRect(), item = this.itemTargets[index].getBoundingClientRect()
    row.scrollTo({ left: row.scrollLeft + (item.left + item.width / 2) - (box.left + box.width / 2), behavior })
  }

  apply(index) {
    const focused = document.activeElement
    this.index = index
    this.itemTargets.forEach((item, at) => (at === index ? item.setAttribute("aria-current", "true") : item.removeAttribute("aria-current")))
    this.panelTargets.forEach((panel, at) => { panel.hidden = at !== index })
    this.copyBand(this.panelTargets[index])
    this.prevTarget.disabled = index === 0
    this.nextTarget.disabled = index === this.itemTargets.length - 1
    if (focused === this.prevTarget && this.prevTarget.disabled) this.focusOr(this.nextTarget, this.rowTarget)
    if (focused === this.nextTarget && this.nextTarget.disabled) this.focusOr(this.prevTarget, this.rowTarget)
  }

  copyBand(panel) {
    const source = panel.querySelector("template[data-band]")
    this.bandTarget.className = `c-band ${source.dataset.band}`
    this.bandTarget.replaceChildren(source.content.cloneNode(true))
  }

  focusOr(button, fallback) {
    (button.disabled ? fallback : button).focus()
  }
}
