import { Controller } from "@hotwired/stimulus"
import { guideInFrame, guideRect } from "scanner/geometry"

// Owns the scanner's camera (spec 007 Story 1). It asks for the rear camera, shows it with the card guide
// over it, offers the torch when the track has one, and stops every track when the page is left, cached or
// hidden, or the controller disconnects. Dispatches camera:ready and camera:unavailable ({ reason }).
export default class extends Controller {
  static targets = [ "stage", "video", "guide", "torch" ]

  connect() {
    this.stop = this.stop.bind(this)
    this.resume = (event) => { if (event.persisted) this.restart() }
    document.addEventListener("turbo:before-cache", this.stop)
    window.addEventListener("pagehide", this.stop)
    window.addEventListener("pageshow", this.resume)
    this.observer = new ResizeObserver(() => this.layoutGuide())
    this.observer.observe(this.stageTarget)
    this.start()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.stop)
    window.removeEventListener("pagehide", this.stop)
    window.removeEventListener("pageshow", this.resume)
    this.observer.disconnect()
    this.stop()
  }

  restart() {
    this.stop()
    this.start()
  }

  async start() {
    const attempt = this.attempt = Symbol("camera")
    await Promise.resolve() // let every controller on the element connect before the first event
    if (!window.isSecureContext) return this.unavailable("insecure")
    if (!navigator.mediaDevices?.getUserMedia) return this.unavailable("no-camera")
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: false, video: { facingMode: { ideal: "environment" }, width: { ideal: 1920 }, height: { ideal: 1080 } }
      })
      if (attempt !== this.attempt) return stream.getTracks().forEach((track) => track.stop()) // left meanwhile
      this.stream = stream
      this.track.addEventListener("ended", () => this.unavailable("lost"))
      this.videoTarget.srcObject = stream
      await this.videoTarget.play()
      this.stageTarget.hidden = false
      this.layoutGuide()
      this.torchTarget.hidden = !this.track.getCapabilities?.()?.torch
      this.dispatch("ready")
    } catch (error) {
      if (attempt === this.attempt) this.unavailable(this.reasonFor(error))
    }
  }

  stop() {
    this.dispatch("stopped")
    this.attempt = null
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
    this.torchOn = false
    if (this.hasVideoTarget) this.videoTarget.srcObject = null
    if (this.hasTorchTarget) this.torchTarget.setAttribute("aria-pressed", "false")
  }

  get track() {
    return this.stream?.getVideoTracks()[0]
  }

  // The current frame at the camera's full delivered resolution, and the guide mapped into it (AC-1.3).
  grab() {
    const video = this.videoTarget
    const image = Object.assign(document.createElement("canvas"), { width: video.videoWidth, height: video.videoHeight })
    image.getContext("2d").drawImage(video, 0, 0)
    const view = this.stageTarget.getBoundingClientRect()
    return { image, card: guideInFrame(image.width, image.height, view.width, view.height) }
  }

  async toggleTorch() {
    const on = !this.torchOn
    try {
      await this.track.applyConstraints({ advanced: [ { torch: on } ] })
      this.torchOn = on
      this.torchTarget.setAttribute("aria-pressed", String(on))
    } catch {
      this.torchTarget.hidden = true
    }
  }

  layoutGuide() {
    const view = this.stageTarget.getBoundingClientRect()
    const guide = guideRect(view.width, view.height)
    Object.assign(this.guideTarget.style, { left: `${guide.x}px`, top: `${guide.y}px`, width: `${guide.width}px`, height: `${guide.height}px` })
  }

  unavailable(reason) {
    this.stop()
    this.stageTarget.hidden = true
    this.torchTarget.hidden = true
    this.dispatch("unavailable", { detail: { reason } })
  }

  reasonFor(error) {
    if ([ "NotAllowedError", "SecurityError" ].includes(error.name)) return "denied"
    if ([ "NotFoundError", "OverconstrainedError" ].includes(error.name)) return "no-camera"
    return "failed"
  }
}
