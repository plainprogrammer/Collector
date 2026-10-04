import { Controller } from "@hotwired/stimulus"
import { readStrips } from "scanner/recognition"
import { refineStrip } from "scanner/geometry"

// Replays a measured run's stored strips through the page's own recognition code (spec 007 AC-5.6), then
// stores what it read. script/scanner/replay.rb drives it in headless Firefox and waits on window.__replay.
export default class extends Controller {
  static targets = [ "status" ]
  static values = { enginePath: String, files: Array, stripUrl: String, resultsUrl: String, label: String, refine: Boolean }

  async connect() {
    window.__replay = { done: false, error: null, count: 0 }
    try {
      const results = []
      for (const file of this.filesValue) {
        const strips = { name: await this.strip(file, "name"), collector: await this.strip(file, "collector") }
        if (this.refineValue) Object.keys(strips).forEach((key) => { strips[key] = refineStrip(key, strips[key]) })
        const { nameText, collectorText } = await readStrips(this.enginePathValue, strips)
        results.push({ file, name_text: nameText, collector_text: collectorText })
        window.__replay.count = results.length
        this.statusTarget.textContent = `Read ${results.length} of ${this.filesValue.length}`
      }
      const response = await fetch(this.resultsUrlValue, { method: "POST", body: JSON.stringify({ label: this.labelValue, results }),
        headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      this.statusTarget.textContent = `Stored ${results.length} replayed captures as ${this.labelValue}`
    } catch (error) {
      window.__replay.error = String(error)
      this.statusTarget.textContent = `The replay failed: ${error}`
    } finally {
      window.__replay.done = true
    }
  }

  async strip(file, name) {
    const response = await fetch(`${this.stripUrlValue.replace("FILE", encodeURIComponent(file))}?strip=${name}`)
    if (!response.ok) throw new Error(`${file} ${name}: HTTP ${response.status}`)
    const image = await createImageBitmap(await response.blob())
    const canvas = Object.assign(document.createElement("canvas"), { width: image.width, height: image.height })
    canvas.getContext("2d").drawImage(image, 0, 0)
    return canvas
  }
}
