import { sourceCanvas } from "/canvas.js"
import { detectHand } from "/hand_detector.js"
import { warp, picture } from "/warp.js"
import { store } from "/output.js"

const status = document.getElementById("status")
const settings = await (await fetch("/settings.json")).json()
const detectors = { hand: async (source) => detectHand(source, settings.hand) }

// Runs one photo: fetch it, detect, straighten, build the 3:4 picture, store both PNGs, and answer with
// the small JSON the driver records. `scale` is null (full size) or a picture height (the live stand-in).
async function run({ path, detector, scale, run: runName, stem, art }) {
  status.textContent = `${runName}: ${stem} (${detector})`
  const blob = await (await fetch(`/corpus/${path}`)).blob()
  const bitmap = await createImageBitmap(blob) // applies EXIF orientation
  const source = sourceCanvas(bitmap, scale)
  const t0 = performance.now()
  const corners = await detectors[detector](source)
  const msDetect = performance.now() - t0
  const result = { path, detector, scale: scale || null, sourceWidth: source.width, sourceHeight: source.height, found: Boolean(corners), corners, msDetect }
  if (corners) {
    const t1 = performance.now()
    const card = warp(source, corners, settings.warp.width, settings.warp.height)
    result.msWarp = performance.now() - t1
    const framed = picture(card, settings.warp.fill)
    await store(runName, stem, "card.png", card)
    await store(runName, stem, "picture.png", framed)
    result.picture = { width: framed.width, height: framed.height }
    document.getElementById("preview").getContext("2d").drawImage(framed, 0, 0, 330, 440)
  }
  return result
}

window.__phase2 = { ready: true, settings, run }
status.textContent = "Ready"
