// The on-device OCR engine (spec 007 Story 2, ADR 0001): one Tesseract worker per page session, kept across
// Turbo visits, reading each strip with its own settings. Only the text leaves this module.
// Page segmentation per strip, frozen before the measured run (spec 007 AC-6.1).
export const SETTINGS = { name: { tessedit_pageseg_mode: "7" }, collector: { tessedit_pageseg_mode: "6" } }
let engine = null

export function loadEngine(path) {
  engine ||= window.Tesseract.createWorker("eng", 1, {
    workerPath: `${path}/worker.min.js`, corePath: `${path}/core`, langPath: `${path}/lang`
  }).catch((error) => { engine = null; throw error })
  return engine
}

export async function readStrips(path, strips) {
  const worker = await loadEngine(path)
  const started = performance.now()
  const text = {}
  for (const [ key, canvas ] of Object.entries(strips)) {
    await worker.setParameters(SETTINGS[key])
    const { data } = await worker.recognize(canvas)
    text[key] = data.text.trim()
  }
  return { nameText: text.name, collectorText: text.collector, ms: Math.round(performance.now() - started) }
}
