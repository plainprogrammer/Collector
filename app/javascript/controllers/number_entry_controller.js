import { Controller } from "@hotwired/stimulus"

// Number entry's line form (spec 026): a rejected number is focused and selected, so typing replaces it (AC-4.1), and
// Enter on the finish select adds the line, as it does in the text fields (AC-2.4).
export default class extends Controller {
  static targets = ["number"]

  numberTargetConnected(input) {
    if (input.dataset.select !== "true") return
    input.focus()
    input.select()
  }

  submit(event) {
    event.preventDefault()
    this.element.requestSubmit()
  }
}
