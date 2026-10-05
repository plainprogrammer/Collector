import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { cropStrips, guideInFrame, DETECTED_STRIPS, STAGE_ASPECT, STRIPS } from "scanner/geometry"
import { findCard } from "scanner/detector"
import { loadEngine, readStrips } from "scanner/recognition"

// Turns a captured frame or a picked photo into what the card says (spec 007 Stories 2–4). A picked photo is first searched
// for the card, which is straightened into the guide's box (spec 009 Story 7); live frames aren't (AC-7.6). It cuts the
// strips, reads them on the device, sends only the text and a reading key, and shows the Turbo Stream answer. One reading at
// a time. Dispatches card-reader:read ({ nameText, collectorText, ms, key, outline, detectMs, warpMs, strips, frame }) for
// measurement mode, where outline is "live", "found" or "not_found". frame is { image, guide } for live captures, else null.
const REASONS = {
  insecure: "The live camera needs this page to be served over HTTPS. You can use a photo instead.",
  denied: "The camera is blocked for this site. Allow it in your browser's settings, or use a photo instead.",
  "no-camera": "No camera was found. You can use a photo instead.",
  failed: "The camera didn't start. Try again, or use a photo instead.",
  lost: "The camera stopped. Try again, or use a photo instead."
}
const NO_EDGE = "No card edge was found, so the photo was read as if framed like the guide. For a better reading, photograph the whole card, upright, filling most of the photo, on a plain background."

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
    this.read(() => ({ image, card, layout: STRIPS, outline: "live" }))
  }

  pick() {
    const file = this.pickerTarget.files[0]
    this.pickerTarget.value = ""
    if (!file || !this.engineReady || this.busy) return
    this.read(async () => {
      const photo = await createImageBitmap(file) // applies the photo's orientation
      const found = findCard(photo)
      if (!found.found) {
        return { image: photo, card: guideInFrame(photo.width, photo.height, STAGE_ASPECT, 1), layout: STRIPS, outline: "not_found", detectMs: found.detectMs }
      }
      const { picture, detectMs, warpMs } = found
      return { image: picture, card: guideInFrame(picture.width, picture.height, STAGE_ASPECT, 1), layout: DETECTED_STRIPS, outline: "found", detectMs, warpMs }
    })
  }

  async read(prepare) {
    if (this.busy) return
    this.busy = true
    this.render()
    this.say("Reading the card…")
    try {
      const { image, card, layout, ...source } = await prepare()
      const strips = cropStrips(image, card, layout)
      const reading = { ...(await readStrips(this.enginePathValue, strips)), key: readingKey(), ...source }
      if (!this.element.isConnected) return
      // Spec 010: a live capture's frame and guide rect travel with the event, in memory, for measurement mode only.
      const frame = source.outline === "live" ? { image, guide: card } : null
      this.dispatch("read", { detail: { ...reading, strips, frame } })
      this.lastReading = reading
      if (await this.send(reading) && reading.outline === "not_found") this.say(NO_EDGE)
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

  // Sends the text and the reading key (spec 009 FR-5), never the outline or timings; true when the answer was shown.
  async send({ nameText, collectorText, key }) {
    this.failureTarget.hidden = true
    const body = new FormData()
    body.append("reading[name_text]", nameText)
    body.append("reading[collector_text]", collectorText)
    body.append("reading[key]", key)
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
    return true
  }

  failed(message, { signedOut }) {
    this.failureMessageTarget.textContent = message
    this.failureNameTarget.textContent = this.lastReading?.nameText || "Nothing read"
    this.failureCollectorTarget.textContent = this.lastReading?.collectorText || "Nothing read"
    this.resendTarget.hidden = signedOut
    this.signInTarget.hidden = !signedOut
    this.failureTarget.hidden = false
    this.say(message)
    return false
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

// An opaque key for one reading (spec 009 AC-1.5): random, never derived from the text. getRandomValues also works where
// the page isn't a secure context (the photo path over plain HTTP), unlike randomUUID.
function readingKey() {
  return Array.from(crypto.getRandomValues(new Uint8Array(16)), (byte) => byte.toString(16).padStart(2, "0")).join("")
}
