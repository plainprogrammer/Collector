import { Controller } from "@hotwired/stimulus"

// Holds a reading's add buttons while one of its adds is in flight, so one reading adds one copy (spec 009 AC-1.4). The answer
// clears the reading when the add goes through; a refusal hands the buttons back. An add that fails on the network or the server
// keeps the reading and says so, and its button is the retry: the same reading key makes a retry safe (AC-1.5, Error Scenarios).
// The selection frame's links ("All printings", "Show 20 more") that fail say so in the pane's region and leave the row as it was
// (spec 088 AC-3.11); `remember` notes which link was used, since a failed frame request does not say.
const ADD_FAILED = "That card wasn't added. Check your connection, then tap its add button again."
const PRINTINGS_FAILED = "The card's printings couldn't be loaded. Tap “All printings” again."
const SIGN_IN_PATH = "/session/new"
const ADD = ".c-scanpane__add"

export default class extends Controller {
  lock({ target }) {
    if (target.matches(ADD)) this.buttons.forEach((button) => { button.disabled = true })
  }

  // success is undefined when Turbo cancelled this submission for a newer one, which is still in flight: keep the lock.
  unlock({ target, detail: { success, error } }) {
    if (!target.matches(ADD)) return
    if (error) this.announce(ADD_FAILED, { alert: true })
    if (success === false) this.buttons.forEach((button) => { button.disabled = false })
  }

  // The link the collector used, so a failure can name its button.
  remember({ currentTarget }) {
    this.failureMessage = currentTarget.dataset.failureMessage
  }

  // A server error's HTML page would otherwise replace the scanner, camera and all; for the selection frame, one whose body isn't
  // HTML would leave the frame silently unchanged.
  inspect(event) {
    if (!event.detail.fetchResponse.serverError) return
    if (event.target.matches?.(ADD)) {
      event.preventDefault()
      this.announce(ADD_FAILED, { alert: true })
    } else if (event.target.id === "scanner_selection") {
      event.preventDefault()
      this.printingsFailed()
    }
  }

  // An ended session answers the selection frame with the sign-in page, which has no frame: show it, as an add would.
  printingsMissing(event) {
    if (event.target.id !== "scanner_selection") return
    const { response, visit } = event.detail
    event.preventDefault()
    if (response.redirected && new URL(response.url).pathname === SIGN_IN_PATH) visit(response)
    else this.printingsFailed()
  }

  printingsErrored({ target }) {
    if (target.id === "scanner_selection") this.printingsFailed()
  }

  printingsFailed() {
    this.announce(this.failureMessage || PRINTINGS_FAILED, { alert: true, printings: true })
  }

  // A retry that loads: the "couldn't be loaded" alert is stale, and only that one (an add's failure alert stays until it is
  // answered). The frame event bubbles from the frame, so the action sits on `#scanner_result`.
  printingsLoaded({ target }) {
    if (target.id === "scanner_selection") document.querySelectorAll("#status [data-printings-failed]").forEach((alert) => alert.remove())
  }

  // Replaces the region's sentence, but not a child marked `data-pane-keep` (measurement mode's "capture wasn't stored" note),
  // as `card-reader#paneSay` does.
  announce(text, { alert = false, printings = false } = {}) {
    const region = document.getElementById("status")
    if (!region) return
    const kept = [ ...region.children ].filter((child) => child.hasAttribute("data-pane-keep"))
    const paragraph = this.message(text, { alert })
    if (printings) paragraph.setAttribute("data-printings-failed", "")
    region.replaceChildren(...kept, paragraph)
  }

  message(text, { alert }) {
    return Object.assign(document.createElement("p"), { className: `c-status__message${alert ? " c-status__message--alert" : ""}`, textContent: text })
  }

  get buttons() {
    return this.element.querySelectorAll(`${ADD} button`)
  }
}
