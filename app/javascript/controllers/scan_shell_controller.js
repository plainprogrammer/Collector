import { Controller } from "@hotwired/stimulus"

// Keeps the shell's state in its markup (spec 082 decision 19): `c-scan--result` while the pane has something to show (a result,
// a sentence in its region, a send failure); the after-add line shown while its text isn't empty; the status line shown while
// it has text and neither the after-add line nor the pane shows, and emptied whenever it hides, so the next sentence written to
// it is a change a screen reader announces (decision 10). A Turbo Stream that empties the result therefore returns the shell to
// the camera with no script of its own. Dispatches scan-shell:changed ({ result }) when the result state changes.
export default class extends Controller {
  static targets = [ "result", "paneStatus", "failure", "statusLine", "statusText", "added", "addedText" ]

  connect() {
    this.observer = new MutationObserver(() => this.sync())
    this.observer.observe(this.element, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: [ "hidden" ] })
    this.sync()
  }

  disconnect() {
    this.observer.disconnect()
  }

  sync() {
    const result = filled(this.resultTarget) || filled(this.paneStatusTarget) || !this.failureTarget.hidden
    const added = filled(this.addedTextTarget)
    this.element.classList.toggle("c-scan--result", result)
    setHidden(this.addedTarget, !added)
    if ((added || result) && filled(this.statusTextTarget)) this.statusTextTarget.textContent = ""
    setHidden(this.statusLineTarget, !filled(this.statusTextTarget) || added || result)
    if (result !== this.result) {
      this.result = result
      this.dispatch("changed", { detail: { result } })
    }
  }
}

// Text or any element: a result is markup, a region holds a paragraph.
function filled(element) {
  return element.textContent.trim() !== "" || element.childElementCount > 0
}

// Only a change is written: the observer watches `hidden`, and an unchanged write would still queue a record.
function setHidden(element, hidden) {
  if (element.hidden !== hidden) element.hidden = hidden
}
