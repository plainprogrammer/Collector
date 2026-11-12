import { Controller } from "@hotwired/stimulus"

// Closes a <details> menu on outside click or Escape; the menu works without it. On a phone it also scrolls an opened
// menu's list clear of the fixed tab bar (spec 074).
export default class extends Controller {
  connect() {
    this.close = this.close.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    this.reveal = this.reveal.bind(this)
    this.closeForCache = this.closeForCache.bind(this)
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.onKeydown)
    // `toggle` does not bubble, so the listener is on the <details> itself (no view carries a data-action for it).
    this.element.addEventListener("toggle", this.reveal)
    document.addEventListener("turbo:before-cache", this.closeForCache)
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.onKeydown)
    this.element.removeEventListener("toggle", this.reveal)
    document.removeEventListener("turbo:before-cache", this.closeForCache)
  }

  close(event) {
    if (!this.element.contains(event.target)) this.element.open = false
  }

  onKeydown(event) {
    if (event.key === "Escape" && this.element.open) {
      this.element.open = false
      this.element.querySelector("summary")?.focus()
    }
  }

  // Turbo caches the page as the collector leaves it, and a <details> restored with its `open` attribute fires `toggle` again, which
  // would scroll the page on Back. Closing the menu before the snapshot is taken restores the page with every menu closed (AC-1.13).
  closeForCache() {
    this.element.open = false
  }

  // When the <details> opens and its list would end behind the tab bar, scrolls the page just far enough (the list's
  // scroll margins in additions.css say how far). It does nothing where no tab bar is drawn (640px and wider, a page with
  // none) and nothing when the list is already clear, so the account menu in the sticky app bar never moves a page. The
  // reduced-motion preference is read now, not when the controller connects. `toggle` fires on close too, hence the check.
  reveal() {
    if (!this.element.open) return
    const bar = document.querySelector(".c-shell > .c-tabbar")
    if (!bar || getComputedStyle(bar).display === "none") return
    const list = this.element.querySelector(".c-menu__list")
    if (!list) return
    const margin = parseFloat(getComputedStyle(list).scrollMarginBottom) || 0
    if (list.getBoundingClientRect().bottom + margin <= window.innerHeight) return
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    list.scrollIntoView({ block: "nearest", behavior: reduced ? "instant" : "smooth" })
  }
}
