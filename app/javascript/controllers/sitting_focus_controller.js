import { Controller } from "@hotwired/stimulus"

// Puts keyboard focus back after a Set or an Undo redraws the sitting panel (spec 047). The server names where focus goes
// ("set" or "heading") on the redrawn panel; it is focused once, and the value is removed so a reconnect can't focus again.
// A page render and an add name nothing. The panel works without this: only the focus is lost.
export default class extends Controller {
  static targets = [ "heading", "set" ]
  static values = { to: String }

  connect() {
    const target = this.toValue === "heading" ? this.headingTargets[0] : this.toValue === "set" ? this.setTargets[0] : null
    if (target) target.focus()
    this.element.removeAttribute("data-sitting-focus-to-value")
  }
}
