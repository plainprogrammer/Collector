import { Controller } from "@hotwired/stimulus"

// Closes a <details> menu on outside click or Escape; the menu works without it.
export default class extends Controller {
  connect() {
    this.close = this.close.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.onKeydown)
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
}
