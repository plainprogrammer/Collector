import { Controller } from "@hotwired/stimulus"

// Puts keyboard focus back after a redraw (spec 047; spec 082 decision 15). The server names where ("set", "heading" or "main")
// on the redrawn part; it is focused once, and the value is removed so a reconnect can't focus again. "heading" is the list
// sheet's title while that sheet is open; an Undo from the after-add line leaves it closed, so focus goes to the main button,
// as it does after an add, whose button the redraw removed. A page render names nothing. Without script only focus is lost.
export default class extends Controller {
  static targets = [ "set" ]
  static values = { to: String }

  connect() {
    this.target?.focus()
    this.element.removeAttribute("data-sitting-focus-to-value")
  }

  get target() {
    const main = document.querySelector("[data-scan-main]")
    if (this.toValue === "set") return this.setTargets[0]
    if (this.toValue === "main") return main
    if (this.toValue === "heading") {
      const heading = document.getElementById("scanner-sitting-heading")
      return heading?.closest("dialog")?.open ? heading : main
    }
    return null
  }
}
