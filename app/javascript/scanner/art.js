// Art matching on the scanner page (spec 011 Story 5; ADR 0006, ADR 0007). A live capture's guide crop is fingerprinted
// with the same arithmetic and loop order as MTG::Art::Fingerprint, and the index the app built is searched on the
// device. Only the nearest artwork ids and their distances leave this module; a fingerprint never does (FR-5).
export const FORMAT_VERSION = 1
const MAGIC = "CART"
const HEADER = 28
const RECORD = 144

export function box(width, height, box, offset) {
  const inset = offset.inset || 0, dx = offset.dx || 0, dy = offset.dy || 0
  const bw = box.x1 - box.x0, bh = box.y1 - box.y0
  return [ (box.x0 + dx + inset * bw) * width, (box.y0 + dy + inset * bh) * height, (box.x1 + dx - inset * bw) * width, (box.y1 + dy - inset * bh) * height ]
}

export function areaResample(image, x0, y0, x1, y1, cols, rows) {
  const { data, width, height } = image
  const cellW = (x1 - x0) / cols, cellH = (y1 - y0) / rows
  const r = new Float64Array(cols * rows), g = new Float64Array(cols * rows), b = new Float64Array(cols * rows)
  const clamp = (v, max) => Math.min(max, Math.max(0, v))
  for (let j = 0; j < rows; j++) {
    const cy0 = y0 + j * cellH, cy1 = y0 + (j + 1) * cellH
    for (let i = 0; i < cols; i++) {
      const cx0 = x0 + i * cellW, cx1 = x0 + (i + 1) * cellW
      let sr = 0, sg = 0, sb = 0, weight = 0
      for (let py = clamp(Math.floor(cy0), height - 1); py <= clamp(Math.ceil(cy1) - 1, height - 1); py++) {
        const wy = Math.min(cy1, py + 1) - Math.max(cy0, py)
        if (wy <= 0) continue
        for (let px = clamp(Math.floor(cx0), width - 1); px <= clamp(Math.ceil(cx1) - 1, width - 1); px++) {
          const wx = Math.min(cx1, px + 1) - Math.max(cx0, px)
          if (wx <= 0) continue
          const w = wx * wy, p = (py * width + px) * 4
          sr += data[p] * w; sg += data[p + 1] * w; sb += data[p + 2] * w; weight += w
        }
      }
      const k = j * cols + i
      r[k] = sr / weight; g[k] = sg / weight; b[k] = sb / weight
    }
  }
  return [ r, g, b ]
}

function dhash(plane, cols, rows, out, offset) {
  let bit = 0
  for (let j = 0; j < rows; j++) {
    for (let i = 0; i < cols - 1; i++, bit++) {
      if (plane[j * cols + i + 1] > plane[j * cols + i]) out[offset + (bit >> 3)] |= 0x80 >> (bit & 7)
    }
  }
}

// One 128-byte fingerprint of a canvas holding the card (or a whole artwork image).
export function fingerprint(canvas, settings, offset) {
  const image = canvas.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, canvas.width, canvas.height)
  const [ cols, rows ] = settings.grid
  const [ x0, y0, x1, y1 ] = box(canvas.width, canvas.height, settings.box, offset)
  const [ r, g, b ] = areaResample(image, x0, y0, x1, y1, cols, rows)
  const grey = new Float64Array(r.length)
  for (let k = 0; k < r.length; k++) grey[k] = 0.299 * r[k] + 0.587 * g[k] + 0.114 * b[k]
  const out = new Uint8Array(128)
  ;[ grey, b, g, r ].forEach((plane, n) => dhash(plane, cols, rows, out, n * 32))
  return out
}

export function fingerprints(canvas, settings) {
  return settings.offsets.map((offset) => fingerprint(canvas, settings, offset))
}

// The guide rect cut from the frame at its own pixels, rounded outward and not resized (spec 010's replay crop, AC-5.3).
export function cropGuide(frame, guide) {
  const x0 = Math.max(0, Math.floor(guide.x)), y0 = Math.max(0, Math.floor(guide.y))
  const x1 = Math.min(frame.width, Math.ceil(guide.x + guide.width)), y1 = Math.min(frame.height, Math.ceil(guide.y + guide.height))
  const canvas = Object.assign(document.createElement("canvas"), { width: x1 - x0, height: y1 - y0 })
  canvas.getContext("2d", { willReadFrequently: true }).drawImage(frame, x0, y0, x1 - x0, y1 - y0, 0, 0, x1 - x0, y1 - y0)
  return canvas
}

// The index file (MTG::Art::Index): a 28-byte header (CART, format version, 3 zero bytes, the 16-character settings
// digest, the record count as uint32 big-endian), then 144-byte records (16-byte artwork id, 128-byte fingerprint).
export function parseIndex(bytes, digest) {
  if (bytes.length < HEADER) throw new Error("The art index is too short.")
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const text = (start, end) => String.fromCharCode(...bytes.subarray(start, end))
  const count = view.getUint32(24)
  if (text(0, 4) !== MAGIC || bytes[4] !== FORMAT_VERSION || text(8, 24) !== digest || bytes.length !== HEADER + count * RECORD) {
    throw new Error("The art index doesn't match this page.")
  }
  const ids = new Array(count), words = new Uint32Array(count * 32)
  for (let i = 0; i < count; i++) {
    const base = HEADER + i * RECORD
    const h = Array.from(bytes.subarray(base, base + 16), (byte) => byte.toString(16).padStart(2, "0")).join("")
    ids[i] = `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
    for (let w = 0; w < 32; w++) words[i * 32 + w] = view.getUint32(base + 16 + w * 4)
  }
  return { count, ids, words }
}

// Downloads (the browser's cache serves a repeat) and parses the index; the times are for measurement mode (AC-9.5).
export async function loadArtIndex(url, settings) {
  const started = performance.now()
  const response = await fetch(url, { credentials: "same-origin" })
  if (!response.ok) throw new Error(`The art index answered ${response.status}.`)
  const bytes = new Uint8Array(await response.arrayBuffer())
  const downloaded = performance.now()
  const index = parseIndex(bytes, settings.digest)
  return { index, downloadMs: Math.round(downloaded - started), readyMs: Math.round(performance.now() - downloaded) }
}

function popcount(v) {
  v = v - ((v >>> 1) & 0x55555555)
  v = (v & 0x33333333) + ((v >>> 2) & 0x33333333)
  return (((v + (v >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24
}

// Each artwork's distance is the smallest over the query's offset fingerprints; the nearest `limit`, nearest first,
// ties in index order (the spike's ranking).
export function search(index, hashes, limit = 10) {
  const queries = hashes.map((h) => { const v = new DataView(h.buffer, h.byteOffset, 128); return Array.from({ length: 32 }, (_, w) => v.getUint32(w * 4)) })
  const distances = new Uint16Array(index.count)
  for (let i = 0; i < index.count; i++) {
    let best = 1025
    for (const q of queries) {
      let d = 0
      for (let w = 0; w < 32 && d < best; w++) d += popcount(index.words[i * 32 + w] ^ q[w])
      if (d < best) best = d
    }
    distances[i] = best
  }
  const order = Array.from(distances.keys()).sort((p, q) => distances[p] - distances[q] || p - q).slice(0, limit)
  return order.map((i) => ({ id: index.ids[i], distance: distances[i] }))
}

// A live capture's nearest artworks: the guide crop, its six fingerprints, the search.
export function matchArtwork(index, frame, guide, fingerprintSettings, limit = 10) {
  return search(index, fingerprints(cropGuide(frame, guide), fingerprintSettings), limit)
}

export const hex = (bytes) => Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")
