import { Controller } from "@hotwired/stimulus"

// Opens a page's sheets (spec 080 decision 2, spec 082 decision 9): a native dialog opened as a modal, so focus moves into it and
// returns to its opener on closing, and Escape closes it; the element does both. A tap on the backdrop is a click whose target
// is the dialog itself (its children cover the rest), and closes it. On closing, the sheet's live regions are emptied, so a
// sentence is never shown stale the next time it opens (spec 082 decision 10).
export default class extends Controller {
  open({ params: { id } }) {
    const sheet = document.getElementById(id)
    if (sheet && !sheet.open) sheet.showModal()
  }

  backdrop(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }

  // The element's own focus return fails when an answer replaced the opener while the sheet was open (a "Set" redraws the
  // destination, an Undo the count), so focus would fall to the body: the opener of the same name is focused instead.
  closed({ currentTarget }) {
    currentTarget.querySelectorAll("[data-sheet-status]").forEach((region) => region.replaceChildren())
    const active = document.activeElement
    if (!active || active === document.body || !active.isConnected || currentTarget.contains(active)) {
      document.querySelector(`[data-sheets-id-param="${currentTarget.id}"]`)?.focus()
    }
  }
}
