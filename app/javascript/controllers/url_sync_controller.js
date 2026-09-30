import { Controller } from "@hotwired/stimulus"

// Keeps a GET filter form's fields in step with the URL. Turbo restores a page on Back from a
// snapshot that keeps whatever was typed, so after each visit the fields are reset from the query
// string (spec 004 AC-6.1, AC-11.4). The server already renders the right values without JS.
export default class extends Controller {
  connect() {
    this.sync = this.sync.bind(this)
    document.addEventListener("turbo:load", this.sync)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.sync)
  }

  sync() {
    const params = new URLSearchParams(window.location.search)
    for (const field of this.element.elements) {
      if (!field.name || [ "submit", "button", "hidden" ].includes(field.type)) continue
      field.value = params.get(field.name) ?? ""
      if (field.tagName === "SELECT" && field.selectedIndex === -1) field.selectedIndex = 0
    }
  }
}
