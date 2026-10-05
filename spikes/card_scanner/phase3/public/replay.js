import { detectCard, warp, WARP } from "scanner/detector"
import { fingerprints, hex } from "/phase2/fingerprint.js"
import { loadIndex, search } from "/phase2/search.js"

// Spec 010 Story 4: one stored frame or photo through one path. "guide" crops the guide rect from the frame at native
// pixels (rounded outward, no resize) and takes it as the card; "detected" and "photo" find the card with the app's
// shipped detector and straighten it (spec 008's warp size). Every job also measures the right artwork's distance directly.
const settings = (await (await fetch("/settings.json")).json()).fingerprint
const index = await loadIndex("/work/index/art_index.bin")
const status = document.getElementById("status")

const popcount = (v) => { v -= (v >>> 1) & 0x55555555; v = (v & 0x33333333) + ((v >>> 2) & 0x33333333); return (((v + (v >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24 }

function canvasOf(width, height) {
  const canvas = Object.assign(document.createElement("canvas"), { width, height })
  return { canvas, context: canvas.getContext("2d", { willReadFrequently: true }) }
}

async function source(path) {
  const bitmap = await createImageBitmap(await (await fetch(`/corpus/${path}`)).blob()) // applies a photo's EXIF orientation
  const { canvas, context } = canvasOf(bitmap.width, bitmap.height)
  context.drawImage(bitmap, 0, 0)
  return canvas
}

function crop(frame, guide) {
  const x0 = Math.max(0, Math.floor(guide.x)), y0 = Math.max(0, Math.floor(guide.y))
  const x1 = Math.min(frame.width, Math.ceil(guide.x + guide.width)), y1 = Math.min(frame.height, Math.ceil(guide.y + guide.height))
  const { canvas, context } = canvasOf(x1 - x0, y1 - y0)
  context.drawImage(frame, x0, y0, x1 - x0, y1 - y0, 0, 0, x1 - x0, y1 - y0)
  return { canvas, rect: { x: x0, y: y0, width: x1 - x0, height: y1 - y0 } }
}

function distanceTo(id, hashes) {
  const i = index.ids.indexOf(id)
  if (i < 0) return null
  let best = 1025
  for (const h of hashes) {
    const v = new DataView(h.buffer, h.byteOffset, 128)
    let d = 0
    for (let w = 0; w < 32; w++) d += popcount(index.words[i * 32 + w] ^ v.getUint32(w * 4))
    best = Math.min(best, d)
  }
  return best
}

async function run({ path, kind, guide, right }) {
  const frame = await source(path)
  let card, extra
  if (kind === "guide") {
    const cropped = crop(frame, guide)
    card = cropped.canvas
    extra = { crop: cropped.rect }
  } else {
    const corners = detectCard(frame)
    if (!corners) return { kind, found: false, top: [], rightDistance: null }
    card = warp(frame, corners, WARP.width, WARP.height)
    extra = { found: true, corners }
  }
  const hashes = fingerprints(card, settings)
  const started = performance.now()
  const top = search(index, hashes, 10)
  return { kind, ...extra, hashes: hashes.map(hex), top, rightDistance: right ? distanceTo(right, hashes) : null, searchMs: performance.now() - started }
}

status.textContent = `Ready: ${index.count} artworks`
window.__phase3 = { ready: true, run, count: index.count }
