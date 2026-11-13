import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { cropStrips, guideInFrame, DETECTED_STRIPS, STAGE_ASPECT, STRIPS } from "scanner/geometry"
import { findCard } from "scanner/detector"
import { loadEngine, readStrips } from "scanner/recognition"
import { loadArtIndex, matchArtwork } from "scanner/art"

// Turns a captured frame or a picked photo into what the card says (spec 007 Stories 2–4). A picked photo is first searched
// for the card, which is straightened into the guide's box (spec 009 Story 7); live frames aren't (AC-7.6). It cuts the
// strips, reads them on the device, sends only the text and a reading key, and shows the Turbo Stream answer. One reading at
// a time. With art matching on (spec 011 Story 5) it loads the art index once the scanner has started, and a live capture
// also sends its 10 nearest artworks (ids and distances, never a fingerprint). Dispatches card-reader:read ({ nameText,
// collectorText, ms, key, outline, detectMs, warpMs, artworks, artMs, art, readyMs, strips, frame }) for measurement mode,
// where outline is "live", "found" or "not_found". frame is { image, guide } for live captures, else null; sizes is the video's
// and the stage's sizes for a live capture, else null. On the one-screen page (spec 082) a capture freezes on its frame (a
// canvas, decision 11), the answer opens the pane, and the main button reads "Scan again" while a result shows (decision 13); a
// sentence about a result is written to the pane's region once the pane shows (decision 10).
const REASONS = {
  insecure: "The live camera needs this page to be served over HTTPS. You can use a photo instead.",
  denied: "The camera is blocked for this site. Allow it in your browser's settings, or use a photo instead.",
  "no-camera": "No camera was found. You can use a photo instead.",
  failed: "The camera didn't start. Try again, or use a photo instead.",
  lost: "The camera stopped. Try again, or use a photo instead."
}
const READY_LIVE = "Ready. Line the card up with the guide, then capture."
const SHOWING = "Done. What the scanner read and its candidates are showing."
const COULD_NOT_READ = "The card couldn't be read. Line it up with the guide and try again."
const NO_EDGE = "No card edge was found, so the photo was read as if framed like the guide. For a better reading, photograph the whole card, upright, filling most of the photo, on a plain background."

export default class extends Controller {
  static targets = [ "status", "main", "picker", "result", "unavailable", "reason", "retry", "engineRetry", "engineFailed",
    "frozen", "paneStatus", "added", "addedText", "failure", "failureName", "failureCollector", "signIn", "resend", "artStatus" ]
  static values = { readingsUrl: String, enginePath: String, artIndexUrl: String, artSettings: Object }

  connect() {
    this.cameraLive = false
    this.paneSaid = 0
    this.startEngine()
  }

  async startEngine() {
    this.engineReady = false
    this.busy = true
    this.engineRetryTarget.hidden = true
    this.engineFailedTarget.hidden = true
    this.render()
    this.say("Loading the scanner…")
    try {
      await loadEngine(this.enginePathValue)
      this.engineReady = true
      this.readyMs = Math.round(performance.now())
      this.loadArt()
      if (!this.resultShowing) this.say(this.cameraLive ? READY_LIVE : "Ready.")
    } catch {
      this.engineRetryTarget.hidden = false
      this.engineFailedTarget.hidden = false
      this.say("The scanner couldn't load, so neither the camera nor a photo can be read. Check your connection and load it again.")
    } finally {
      this.busy = false
      this.render()
    }
  }

  retryEngine() {
    this.startEngine()
  }

  // Spec 011 AC-5.2: the art index loads once the scanner has started, never delaying the camera or text recognition.
  async loadArt() {
    if (!this.artIndexUrlValue || this.artLoading) return
    this.artLoading = true
    try {
      const { index, downloadMs, readyMs } = await loadArtIndex(this.artIndexUrlValue, this.artSettingsValue)
      this.artIndex = index
      this.artTimings = { downloadMs, readyMs }
      this.sayArt("Artwork matching is on")
    } catch {
      this.sayArt("Artwork matching isn't available. The scanner is reading text only.")
    }
  }

  // A live capture's nearest artworks (AC-5.3), or null before the index is ready, after it failed, or on error.
  matchArt(image, card) {
    if (!this.artIndex) return null
    const started = performance.now()
    try {
      const artworks = matchArtwork(this.artIndex, image, card, this.artSettingsValue.fingerprint)
      return { artworks, artMs: Math.round(performance.now() - started) }
    } catch {
      return null
    }
  }

  sayArt(message) {
    if (this.hasArtStatusTarget) this.artStatusTarget.textContent = message
  }

  cameraReady() {
    this.cameraLive = true
    this.unavailableTarget.hidden = true
    if (this.engineReady && !this.resultShowing) this.say(READY_LIVE)
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

  // The main button's action: "Scan again" while a result shows, else capture (spec 082 decision 13).
  main() {
    if (this.resultShowing) this.scanAgain()
    else this.capture()
  }

  get resultShowing() {
    return this.element.classList.contains("c-scan--result")
  }

  capture() {
    if (!this.engineReady || !this.cameraLive || this.busy) return
    let grabbed
    try { grabbed = this.camera.grab() } catch { return this.say(COULD_NOT_READ) }
    const { image, card } = grabbed
    this.freeze(image)
    this.read(() => ({ image, card, layout: STRIPS, outline: "live", sizes: this.camera.sizes() }))
  }

  // The captured frame, drawn on the stage's canvas and cropped as the video is (object-fit: cover), so the collector sees
  // what is being read (spec 082 decision 11). Nothing leaves the page.
  freeze(image) {
    Object.assign(this.frozenTarget, { width: image.width, height: image.height })
    this.frozenTarget.getContext("2d").drawImage(image, 0, 0)
    this.frozenTarget.hidden = false
  }

  // Spec 082 decision 13: discards the reading and its key, empties the pane, and returns to the camera (or to the stage notice
  // when the camera is unavailable). Nothing is sent.
  scanAgain() {
    this.clearResult()
    this.say(this.cameraLive ? READY_LIVE : "Ready.")
  }

  // What "Scan again" and a photo picked while a result shows have in common: the result, its reading and key, the pane's
  // sentences, the failure block and the frozen frame go. It says nothing on the status line; each caller says its own.
  clearResult() {
    this.paneSaid += 1
    this.lastReading = null
    this.resultTarget.replaceChildren()
    this.paneStatusTarget.replaceChildren()
    this.failureTarget.hidden = true
    this.frozenTarget.hidden = true
  }

  // The pane closed (an add cleared the result) or opened: the frozen frame goes with the result, and the main button follows.
  shellChanged({ detail: { result } }) {
    if (!result) this.paneSaid += 1
    if (!result && !this.busy) this.frozenTarget.hidden = true
    this.render()
  }

  pick(event) {
    const file = event.target.files[0]
    event.target.value = ""
    if (!file || !this.engineReady || this.busy) return
    event.target.closest("dialog")?.close()
    if (this.resultShowing) this.clearResult() // the old result and its frozen frame go; the new reading says "Reading the card…"
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
    this.paneSaid += 1
    this.addedTextTarget.textContent = ""
    this.addedTarget.classList.remove("c-scan__line--alert") // a page-load alert flash styled the line; the next sentence is not one
    this.render()
    this.say("Reading the card…")
    try {
      const { image, card, layout, ...source } = await prepare()
      // Spec 011: art runs on live captures only (AC-5.4), before OCR, about 35 ms on the phone.
      const art = source.outline === "live" ? this.matchArt(image, card) : null
      const strips = cropStrips(image, card, layout)
      const reading = { ...(await readStrips(this.enginePathValue, strips)), key: readingKey(), ...source, ...(art || {}) }
      if (!this.element.isConnected) return
      // Spec 010: a live capture's frame and guide rect travel with the event, in memory, for measurement mode only.
      const frame = source.outline === "live" ? { image, guide: card } : null
      this.dispatch("read", { detail: { ...reading, sizes: source.sizes || null, strips, frame, art: this.artTimings || null, readyMs: this.readyMs } })
      this.lastReading = reading
      if (await this.send(reading) && reading.outline === "not_found") this.paneSay(NO_EDGE)
    } catch {
      this.frozenTarget.hidden = true
      this.say(COULD_NOT_READ)
    } finally {
      this.busy = false
      this.render()
    }
  }

  resend() {
    if (this.lastReading) this.send(this.lastReading)
  }

  // Sends the text, the reading key (spec 009 FR-5) and a live capture's nearest artworks (spec 011 FR-5), never the
  // outline, timings or a fingerprint; true when the answer was shown.
  async send({ nameText, collectorText, key, artworks }) {
    this.failureTarget.hidden = true
    const body = new FormData()
    body.append("reading[name_text]", nameText)
    body.append("reading[collector_text]", collectorText)
    body.append("reading[key]", key)
    ;(artworks || []).forEach(({ id, distance }) => {
      body.append("reading[artworks][][id]", id)
      body.append("reading[artworks][][distance]", String(distance))
    })
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
    this.paneSay(SHOWING)
    return true
  }

  failed(message, { signedOut }) {
    this.failureNameTarget.textContent = this.lastReading?.nameText || "Nothing read"
    this.failureCollectorTarget.textContent = this.lastReading?.collectorText || "Nothing read"
    this.resendTarget.hidden = signedOut
    this.signInTarget.hidden = !signedOut
    this.failureTarget.hidden = false
    this.paneSay(message, { alert: true })
    return false
  }

  render() {
    const result = this.resultShowing
    this.mainTarget.textContent = result ? "Scan again" : "Capture"
    this.mainTarget.classList.toggle("c-btn--primary", !result)
    this.mainTarget.classList.toggle("c-btn--secondary", result)
    this.mainTarget.disabled = result ? this.busy : !(this.engineReady && this.cameraLive) || this.busy
    this.mainTarget.setAttribute("aria-busy", String(this.busy || !this.engineReady))
    this.pickerTargets.forEach((picker) => { picker.disabled = !this.engineReady || this.busy })
  }

  say(message) {
    this.statusTarget.textContent = message
  }

  // Writes a sentence to the pane's live region once the pane shows: a region filled while hidden and then shown is not
  // announced (spec 080 decision 8; spec 082 decision 10). Waits for `c-scan--result` (set by scan-shell from the answer), at
  // most about two seconds, then one more frame.
  // It replaces only its own sentence: a child marked `data-pane-keep` (measurement mode's "capture wasn't stored") stays.
  // A sentence for a reading the collector has since discarded ("Scan again", an add, a new reading bump `paneSaid`) is dropped,
  // so a late write can never reopen the pane.
  async paneSay(message, { alert = false } = {}) {
    const said = this.paneSaid
    for (let frame = 0; frame < 120 && !this.resultShowing; frame++) await nextFrame()
    await nextFrame()
    if (said !== this.paneSaid) return
    const paragraph = Object.assign(document.createElement("p"), { className: `c-status__message${alert ? " c-status__message--alert" : ""}`, textContent: message })
    const kept = [ ...this.paneStatusTarget.children ].filter((child) => child.hasAttribute("data-pane-keep"))
    this.paneStatusTarget.replaceChildren(...kept, paragraph)
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

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve))
