import { Controller } from "@hotwired/stimulus"

// "/" focuses the search field unless you're already typing somewhere (spec 004 AC-6.7).
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    const typing = event.target.closest("input, textarea, select, [contenteditable]")
    if (event.key !== "/" || typing || event.metaKey || event.ctrlKey || event.altKey) return
    event.preventDefault()
    this.inputTarget.focus()
  }
}
