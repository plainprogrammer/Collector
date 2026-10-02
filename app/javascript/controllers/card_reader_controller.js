import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { cropStrips, guideInFrame, STAGE_ASPECT } from "scanner/geometry"
import { loadEngine, readStrips } from "scanner/recognition"

// Turns a captured frame or a picked photo into what the card says (spec 007 Stories 2–4). It cuts the
// strips, reads them on the device, sends only the text, and shows the Turbo Stream answer. One reading at
// a time. Dispatches card-reader:read ({ nameText, collectorText, ms, strips }) for measurement mode.
const REASONS = {
  insecure: "The live camera needs this page to be served over HTTPS. You can use a photo instead.",
  denied: "The camera is blocked for this site. Allow it in your browser's settings, or use a photo instead.",
  "no-camera": "No camera was found. You can use a photo instead.",
  failed: "The camera didn't start. Try again, or use a photo instead.",
  lost: "The camera stopped. Try again, or use a photo instead."
}

export default class extends Controller {
  static targets = [ "status", "shutter", "picker", "result", "unavailable", "reason", "retry", "engineRetry",
    "failure", "failureMessage", "failureName", "failureCollector", "signIn", "resend" ]
  static values = { readingsUrl: String, enginePath: String }

  connect() {
    this.cameraLive = false
    this.startEngine()
  }

  async startEngine() {
    this.engineReady = false
    this.busy = true
    this.engineRetryTarget.hidden = true
    this.render()
    this.say("Loading the scanner…")
    try {
      await loadEngine(this.enginePathValue)
      this.engineReady = true
      this.say(this.cameraLive ? "Ready. Line the card up with the guide, then capture." : "Ready.")
    } catch {
      this.engineRetryTarget.hidden = false
      this.say("The scanner couldn't load, so neither the camera nor a photo can be read. Check your connection and load it again.")
    } finally {
      this.busy = false
      this.render()
    }
  }

  retryEngine() {
    this.startEngine()
  }

  cameraReady() {
    this.cameraLive = true
    this.unavailableTarget.hidden = true
    if (this.engineReady) this.say("Ready. Line the card up with the guide, then capture.")
    this.render()
  }

  cameraStopped() {
    this.cameraLive = false
    this.render()
  }

  cameraUnavailable({ detail: { reason } }) {
    this.cameraLive = false
    this.reasonTarget.textContent = REASONS[reason]
    this.retryTarget.hidden = reason === "insecure"
    this.unavailableTarget.hidden = false
    this.render()
  }

  retryCamera() {
    this.camera.restart()
  }

  capture() {
    if (!this.engineReady || !this.cameraLive || this.busy) return
    const { image, card } = this.camera.grab()
    this.read(image, card)
  }

  async pick() {
    const file = this.pickerTarget.files[0]
    this.pickerTarget.value = ""
    if (!file || !this.engineReady || this.busy) return
    const image = await createImageBitmap(file) // applies the photo's orientation
    this.read(image, guideInFrame(image.width, image.height, STAGE_ASPECT, 1))
  }

  async read(image, card) {
    if (this.busy) return
    this.busy = true
    this.render()
    this.say("Reading the card…")
    try {
      const strips = cropStrips(image, card)
      const reading = await readStrips(this.enginePathValue, strips)
      if (!this.element.isConnected) return
      this.dispatch("read", { detail: { ...reading, strips } })
      this.lastReading = reading
      await this.send(reading)
    } catch {
      this.say("The card couldn't be read. Line it up with the guide and try again.")
    } finally {
      this.busy = false
      this.render()
    }
  }

  resend() {
    if (this.lastReading) this.send(this.lastReading)
  }

  async send({ nameText, collectorText }) {
    this.failureTarget.hidden = true
    const body = new FormData()
    body.append("reading[name_text]", nameText)
    body.append("reading[collector_text]", collectorText)
    let response
    try {
      response = await fetch(this.readingsUrlValue, { method: "POST", body, redirect: "manual",
        headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content } })
    } catch {
      return this.failed("The text couldn't be sent. Check your connection, then send it again.", { signedOut: false })
    }
    if (response.type === "opaqueredirect") return this.failed("Your session has ended. Sign in again, then capture the card again.", { signedOut: true })
    if (!response.ok && response.status !== 422) return this.failed("The scanner had a problem with that card. Send it again.", { signedOut: false })
    Turbo.renderStreamMessage(await response.text())
    this.say("Done. What the scanner read and its candidates are below.")
  }

  failed(message, { signedOut }) {
    this.failureMessageTarget.textContent = message
    this.failureNameTarget.textContent = this.lastReading?.nameText || "Nothing read"
    this.failureCollectorTarget.textContent = this.lastReading?.collectorText || "Nothing read"
    this.resendTarget.hidden = signedOut
    this.signInTarget.hidden = !signedOut
    this.failureTarget.hidden = false
    this.say(message)
  }

  render() {
    this.shutterTarget.disabled = !(this.engineReady && this.cameraLive) || this.busy
    this.shutterTarget.setAttribute("aria-busy", String(this.busy || !this.engineReady))
    this.pickerTarget.disabled = !this.engineReady || this.busy
  }

  say(message) {
    this.statusTarget.textContent = message
  }

  get camera() {
    return this.application.getControllerForElementAndIdentifier(this.element, "camera")
  }
}
