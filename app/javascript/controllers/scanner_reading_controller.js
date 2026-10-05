import { Controller } from "@hotwired/stimulus"

// Holds a reading's add buttons while one of its adds is in flight, so one reading adds one copy (spec 009 AC-1.4). The
// answer clears the reading when the add goes through; a refusal hands the buttons back. An add that fails on the network
// or the server keeps the reading and says so, and its button is the retry: the same reading key makes a retry safe
// (AC-1.5, Error Scenarios). Other printings that fail to load say so in place, and opening them is announced (NFR
// Accessibility).
const ADD_FAILED = "That card wasn't added. Check your connection, then tap its add button again."
const PRINTINGS_FAILED = "Other printings couldn't be loaded. Tap “Other printings” again."
const SIGN_IN_PATH = "/session/new"

export default class extends Controller {
  lock({ target }) {
    if (target.matches(".c-scanner__add")) this.buttons.forEach((button) => { button.disabled = true })
  }

  // success is undefined when Turbo cancelled this submission for a newer one, which is still in flight: keep the lock.
  unlock({ target, detail: { success, error } }) {
    if (!target.matches(".c-scanner__add")) return
    if (error) this.announce(ADD_FAILED, { alert: true })
    if (success === false) this.buttons.forEach((button) => { button.disabled = false })
  }

  // A server error's HTML page would otherwise replace the scanner, camera and all. For Other printings, a server error
  // whose body isn't HTML would otherwise leave the frame silently empty.
  inspect(event) {
    if (!event.detail.fetchResponse.serverError) return
    if (event.target.matches?.(".c-scanner__add")) {
      event.preventDefault()
      this.announce(ADD_FAILED, { alert: true })
    } else if (event.target.id === "scanner_printings") {
      event.preventDefault()
      this.printingsFailed(event.target)
    }
  }

  // An ended session answers Other printings with the sign-in page, which has no frame: show it, as an add would (Error
  // Scenarios, AC-3.3).
  printingsMissing(event) {
    if (event.target.id !== "scanner_printings") return
    const { response, visit } = event.detail
    event.preventDefault()
    if (response.redirected && new URL(response.url).pathname === SIGN_IN_PATH) visit(response)
    else this.printingsFailed(event.target)
  }

  printingsErrored({ target }) {
    if (target.id === "scanner_printings") this.printingsFailed(target)
  }

  printingsLoaded({ target }) {
    const heading = target.id === "scanner_printings" && target.querySelector("h2")
    if (heading) this.announce(`${heading.textContent} are below.`)
  }

  printingsFailed(frame) {
    frame.replaceChildren(this.message(PRINTINGS_FAILED, { alert: true }))
    this.announce(PRINTINGS_FAILED, { alert: true })
  }

  announce(text, { alert = false } = {}) {
    document.getElementById("status")?.replaceChildren(this.message(text, { alert }))
  }

  message(text, { alert }) {
    return Object.assign(document.createElement("p"), { className: `c-status__message${alert ? " c-status__message--alert" : ""}`, textContent: text })
  }

  get buttons() {
    return this.element.querySelectorAll(".c-scanner__add button")
  }
}
