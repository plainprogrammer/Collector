// Phase 0 OCR spike (spec 005): fixed card guide, two strips, Tesseract.js served from this origin.
// Strip boxes are fractions of the card; tuned on the pilot photos, then frozen before measured runs.
const GUIDE_HEIGHT = 0.9 // card height as a share of the image height, centred
const CARD_ASPECT = 63 / 88
const STRIPS = {
  name: { x: 0.06, y: 0.035, w: 0.7, h: 0.06, psm: "7" },
  collector: { x: 0.03, y: 0.905, w: 0.55, h: 0.075, psm: "6" }
}
const ASSETS = "/ocr/v7.0.0"
const mode = new URLSearchParams(location.search).get("mode") || "device"
const status = document.getElementById("status")
const results = []
window.__spike = { results, done: false, error: null, ready: null }

function guideRect(image) {
  const height = image.height * GUIDE_HEIGHT
  const width = height * CARD_ASPECT
  return { x: (image.width - width) / 2, y: (image.height - height) / 2, width, height }
}

function crop(image, card, strip) {
  const canvas = document.createElement("canvas")
  canvas.width = Math.round(card.width * strip.w)
  canvas.height = Math.round(card.height * strip.h)
  canvas.getContext("2d").drawImage(image, card.x + card.width * strip.x, card.y + card.height * strip.y,
    canvas.width, canvas.height, 0, 0, canvas.width, canvas.height)
  return canvas
}

function addRow(result) {
  const row = document.createElement("tr")
  for (const value of [result.file, result.name_text, result.collector_text, result.ms]) {
    const cell = document.createElement("td")
    cell.textContent = value
    row.append(cell)
  }
  document.getElementById("rows").append(row)
}

async function loadWorker() {
  const worker = await Tesseract.createWorker("eng", 1, {
    workerPath: `${ASSETS}/worker.min.js`, corePath: `${ASSETS}/core`, langPath: `${ASSETS}/lang`
  })
  window.__spike.ready = performance.now()
  status.textContent = `Ready ${Math.round(window.__spike.ready)} ms after page load`
  return worker
}

async function recognise(worker, file, blob) {
  const image = await createImageBitmap(blob) // applies EXIF orientation
  const card = guideRect(image)
  const started = performance.now()
  const strips = {}
  for (const [key, strip] of Object.entries(STRIPS)) {
    const canvas = crop(image, card, strip)
    await worker.setParameters({ tessedit_pageseg_mode: strip.psm })
    const { data } = await worker.recognize(canvas)
    strips[key] = { text: data.text.trim(), confidence: data.confidence,
      png: mode === "replay" ? canvas.toDataURL("image/png") : null }
  }
  const result = { file, name_text: strips.name.text, collector_text: strips.collector.text,
    name_confidence: strips.name.confidence, collector_confidence: strips.collector.confidence,
    ms: Math.round(performance.now() - started), crops: { name: strips.name.png, collector: strips.collector.png } }
  results.push(result)
  addRow(result)
}

async function replay(worker) {
  const files = await (await fetch("/corpus/index.json")).json()
  for (const [index, file] of files.entries()) {
    status.textContent = `Replaying ${index + 1}/${files.length}: ${file}`
    await recognise(worker, file, await (await fetch(`/corpus/${encodeURIComponent(file)}`)).blob())
  }
}

function device(worker) {
  const input = document.getElementById("photos")
  input.disabled = false
  input.addEventListener("change", async () => {
    for (const file of input.files) await recognise(worker, file.name, file)
    const body = JSON.stringify({ user_agent: navigator.userAgent, ready_ms: Math.round(window.__spike.ready),
      results: results.map(({ crops, ...rest }) => rest) })
    const response = await fetch("/timings", { method: "POST", headers: { "content-type": "application/json" }, body })
    status.textContent = `Sent ${results.length} timings (${response.status})`
  })
}

try {
  const worker = await loadWorker()
  if (mode === "replay") await replay(worker)
  else device(worker)
} catch (error) {
  window.__spike.error = String(error)
  status.textContent = `Error: ${error}`
} finally {
  if (mode === "replay") window.__spike.done = true
}
