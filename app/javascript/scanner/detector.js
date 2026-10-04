import { CARD_ASPECT, GUIDE, STAGE_ASPECT } from "scanner/geometry"

// Finds the card in a picked photo and straightens it (spec 009 Story 7, ADR 0005). This is the Phase 2 spike's
// hand-written detector (spikes/card_scanner/phase2/public/hand_detector.js and warp.js at 39cdc6e), moved onto page
// canvases, plus outline completion (AC-6.6). It takes the two strongest near-horizontal and near-vertical edge lines in a
// downscaled copy of the photo, intersects them for the corners, and maps the card onto a 3:4 picture with the card exactly
// in the guide's box. Cards are treated as upright. It runs on the device; nothing it makes leaves it (FR-4).

// Frozen in the spike at 39cdc6e (spec 008 settings.json "hand" and "warp"). completeTolerance is spec 009's outline
// completion (AC-6.6): null is off, as in the spike. Frozen at 0.08 after the development photos (2026-10-04): exact printing
// 20/46 → 22/46 with the same top 3 (43/52); combined with DETECTED_STRIPS.name.y, top 3 46/52 (biased, development).
export const SETTINGS = { workWidth: 480, blur: 2, edgePercentile: 0.55, thetaRangeDeg: 6, minSeparation: 0.65, minArea: 0.15,
  aspectRange: [ 0.5, 0.9 ], completeTolerance: 0.08 }
export const WARP = { width: 1008, height: 1408, fill: "#808080" }

// { found: true, corners, picture, detectMs, warpMs }, or { found: false, detectMs }. corners are in the photo's pixels
// (top-left, top-right, bottom-right, bottom-left); picture is the canvas the shipped strips are cut from.
export function findCard(photo, settings = SETTINGS) {
  const source = canvasOf(photo.width, photo.height)
  source.context.drawImage(photo, 0, 0)
  const started = performance.now()
  const corners = detectCard(source.canvas, settings)
  const detectMs = Math.round(performance.now() - started)
  if (!corners) return { found: false, detectMs }
  const warpStarted = performance.now()
  const picture = framed(warp(source.canvas, corners, WARP.width, WARP.height), WARP.fill)
  return { found: true, corners, picture, detectMs, warpMs: Math.round(performance.now() - warpStarted) }
}

export function detectCard(source, settings = SETTINGS) {
  const scale = settings.workWidth / source.width
  const w = settings.workWidth, h = Math.round(source.height * scale)
  const work = canvasOf(w, h)
  work.context.drawImage(source, 0, 0, w, h)
  const gray = toGray(work.context.getImageData(0, 0, w, h))
  const smooth = settings.blur > 0 ? boxBlur(gray, w, h, settings.blur) : gray
  const { mag, gx, gy } = sobel(smooth, w, h)
  const threshold = percentile(mag, settings.edgePercentile)
  const horizontal = twoPeaks(hough(mag, gx, gy, w, h, threshold, "horizontal", settings.thetaRangeDeg), h * settings.minSeparation)
  const vertical = twoPeaks(hough(mag, gx, gy, w, h, threshold, "vertical", settings.thetaRangeDeg), w * settings.minSeparation)
  if (!horizontal || !vertical) return null
  const corners = orderCorners([
    intersect(horizontal[0], vertical[0]), intersect(horizontal[0], vertical[1]),
    intersect(horizontal[1], vertical[0]), intersect(horizontal[1], vertical[1])
  ])
  if (!corners || !validQuad(corners, w, h, settings)) return null
  return completeOutline(corners, settings).map(([ x, y ]) => [ x / scale, y / scale ])
}

export function boxBlur(gray, w, h, radius) {
  const out = new Float32Array(gray.length)
  const size = 2 * radius + 1
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let sum = 0
      for (let dy = -radius; dy <= radius; dy++) {
        const yy = Math.min(h - 1, Math.max(0, y + dy))
        for (let dx = -radius; dx <= radius; dx++) sum += gray[yy * w + Math.min(w - 1, Math.max(0, x + dx))]
      }
      out[y * w + x] = sum / (size * size)
    }
  }
  return out
}

export function sobel(gray, w, h) {
  const gx = new Float32Array(gray.length), gy = new Float32Array(gray.length), mag = new Float32Array(gray.length)
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const i = y * w + x
      const sx = -gray[i - w - 1] + gray[i - w + 1] - 2 * gray[i - 1] + 2 * gray[i + 1] - gray[i + w - 1] + gray[i + w + 1]
      const sy = -gray[i - w - 1] - 2 * gray[i - w] - gray[i - w + 1] + gray[i + w - 1] + 2 * gray[i + w] + gray[i + w + 1]
      gx[i] = sx; gy[i] = sy; mag[i] = Math.hypot(sx, sy)
    }
  }
  return { mag, gx, gy }
}

export function percentile(values, share) {
  const sorted = Float32Array.from(values).sort()
  return sorted[Math.min(sorted.length - 1, Math.floor(share * sorted.length))]
}

// Accumulates rho = x cos(theta) + y sin(theta) over edge pixels whose gradient points the right way: near-vertical
// gradients vote for horizontal lines (theta about 90 degrees), near-horizontal ones for vertical lines (theta about 0).
export function hough(mag, gx, gy, w, h, threshold, direction, rangeDeg) {
  const centre = direction === "horizontal" ? 90 : 0
  const thetas = []
  for (let d = -rangeDeg; d <= rangeDeg; d++) thetas.push(((centre + d) * Math.PI) / 180)
  const diag = Math.ceil(Math.hypot(w, h))
  const rhoBins = 2 * diag + 1
  const acc = new Uint32Array(thetas.length * rhoBins)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x
      if (mag[i] < threshold) continue
      const horizontalEdge = Math.abs(gy[i]) >= Math.abs(gx[i])
      if ((direction === "horizontal") !== horizontalEdge) continue
      for (let t = 0; t < thetas.length; t++) {
        const rho = Math.round(x * Math.cos(thetas[t]) + y * Math.sin(thetas[t])) + diag
        acc[t * rhoBins + rho]++
      }
    }
  }
  return { acc, thetas, rhoBins, diag }
}

// The strongest line, then the strongest line at least minSeparation away in rho; null if the second is weaker than a
// third of the first (no second edge of the card was found).
export function twoPeaks({ acc, thetas, rhoBins, diag }, minSeparation) {
  const peak = (exclude) => {
    let best = -1, bestValue = 0
    for (let i = 0; i < acc.length; i++) {
      if (acc[i] <= bestValue) continue
      const rho = (i % rhoBins) - diag
      if (exclude !== null && Math.abs(rho - exclude) < minSeparation) continue
      best = i; bestValue = acc[i]
    }
    return best < 0 ? null : { rho: (best % rhoBins) - diag, theta: thetas[Math.floor(best / rhoBins)], votes: bestValue }
  }
  const first = peak(null)
  if (!first) return null
  const second = peak(first.rho)
  if (!second || second.votes < first.votes / 3) return null
  return [ first, second ]
}

export function intersect(a, b) {
  const det = Math.cos(a.theta) * Math.sin(b.theta) - Math.sin(a.theta) * Math.cos(b.theta)
  if (Math.abs(det) < 1e-9) return null
  return [
    (a.rho * Math.sin(b.theta) - b.rho * Math.sin(a.theta)) / det,
    (b.rho * Math.cos(a.theta) - a.rho * Math.cos(b.theta)) / det
  ]
}

export function orderCorners(points) {
  if (points.some((p) => p === null)) return null
  const byY = [ ...points ].sort((p, q) => p[1] - q[1])
  const top = byY.slice(0, 2).sort((p, q) => p[0] - q[0]), bottom = byY.slice(2).sort((p, q) => p[0] - q[0])
  return [ top[0], top[1], bottom[1], bottom[0] ]
}

export function validQuad(corners, w, h, settings) {
  const margin = 0.05
  if (corners.some(([ x, y ]) => x < -margin * w || x > (1 + margin) * w || y < -margin * h || y > (1 + margin) * h)) return false
  let area = 0
  for (let i = 0; i < 4; i++) {
    const [ x1, y1 ] = corners[i], [ x2, y2 ] = corners[(i + 1) % 4]
    area += x1 * y2 - x2 * y1
  }
  area = Math.abs(area) / 2
  if (area < settings.minArea * w * h) return false
  const width = (side(corners[0], corners[1]) + side(corners[3], corners[2])) / 2
  const height = (side(corners[0], corners[3]) + side(corners[1], corners[2])) / 2
  const aspect = width / height
  return aspect >= settings.aspectRange[0] && aspect <= settings.aspectRange[1]
}

// When the outline is much wider than a card for its height, the bottom edge was missed (a card filling the frame, ADR
// 0005): move the bottom corners down their side lines until the outline has a card's proportions (spec 009 AC-6.6).
export function completeOutline(corners, settings) {
  if (!settings.completeTolerance) return corners
  const [ tl, tr, br, bl ] = corners
  const width = (side(tl, tr) + side(bl, br)) / 2
  const height = (side(tl, bl) + side(tr, br)) / 2
  if (width / height <= CARD_ASPECT * (1 + settings.completeTolerance)) return corners
  const target = width / CARD_ASPECT
  const extend = (top, bottom) => {
    const stretch = target / side(top, bottom)
    return [ top[0] + (bottom[0] - top[0]) * stretch, top[1] + (bottom[1] - top[1]) * stretch ]
  }
  return [ tl, tr, extend(tr, br), extend(tl, bl) ]
}

// Solves for the 8 parameters of the map (u, v) -> (x, y) taking the output rectangle's corners to the card's corners:
// x = (a u + b v + c) / (g u + h v + 1), y = (d u + e v + f) / (g u + h v + 1).
export function homography(width, height, corners) {
  const from = [ [ 0, 0 ], [ width, 0 ], [ width, height ], [ 0, height ] ]
  const rows = [], rhs = []
  for (let i = 0; i < 4; i++) {
    const [ u, v ] = from[i], [ x, y ] = corners[i]
    rows.push([ u, v, 1, 0, 0, 0, -u * x, -v * x ]); rhs.push(x)
    rows.push([ 0, 0, 0, u, v, 1, -u * y, -v * y ]); rhs.push(y)
  }
  return solve(rows, rhs)
}

export function solve(a, b) {
  const n = b.length
  const m = a.map((row, i) => [ ...row, b[i] ])
  for (let col = 0; col < n; col++) {
    let pivot = col
    for (let r = col + 1; r < n; r++) if (Math.abs(m[r][col]) > Math.abs(m[pivot][col])) pivot = r
    ;[ m[col], m[pivot] ] = [ m[pivot], m[col] ]
    for (let r = col + 1; r < n; r++) {
      const f = m[r][col] / m[col][col]
      for (let c = col; c <= n; c++) m[r][c] -= f * m[col][c]
    }
  }
  const x = new Array(n).fill(0)
  for (let r = n - 1; r >= 0; r--) {
    let s = m[r][n]
    for (let c = r + 1; c < n; c++) s -= m[r][c] * x[c]
    x[r] = s / m[r][r]
  }
  return x
}

// Straightens the card into a width × height canvas with bilinear sampling and nothing else.
export function warp(source, corners, width, height) {
  const src = source.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, source.width, source.height)
  const [ a, b, c, d, e, f, g, hh ] = homography(width, height, corners)
  const out = new ImageData(width, height)
  const sw = source.width, sh = source.height, data = src.data, o = out.data
  for (let v = 0; v < height; v++) {
    for (let u = 0; u < width; u++) {
      const den = g * u + hh * v + 1
      const x = (a * u + b * v + c) / den, y = (d * u + e * v + f) / den
      const x0 = Math.max(0, Math.min(sw - 2, Math.floor(x))), y0 = Math.max(0, Math.min(sh - 2, Math.floor(y)))
      const fx = Math.max(0, Math.min(1, x - x0)), fy = Math.max(0, Math.min(1, y - y0))
      const i00 = (y0 * sw + x0) * 4, i01 = i00 + 4, i10 = i00 + sw * 4, i11 = i10 + 4
      const p = (v * width + u) * 4
      for (let ch = 0; ch < 3; ch++) {
        o[p + ch] = (data[i00 + ch] * (1 - fx) + data[i01 + ch] * fx) * (1 - fy) + (data[i10 + ch] * (1 - fx) + data[i11 + ch] * fx) * fy
      }
      o[p + 3] = 255
    }
  }
  const { canvas, context } = canvasOf(width, height)
  context.putImageData(out, 0, 0)
  return canvas
}

// The 3:4 picture the shipped strips are cut from: the card fills the guide's box (GUIDE.height of the height, 63:88,
// centred), and the rest is one flat colour.
export function framed(card, fill) {
  const height = Math.round(card.height / GUIDE.height)
  const width = Math.round(height * STAGE_ASPECT)
  const { canvas, context } = canvasOf(width, height)
  context.fillStyle = fill
  context.fillRect(0, 0, width, height)
  const cardHeight = height * GUIDE.height, cardWidth = cardHeight * CARD_ASPECT
  context.drawImage(card, (width - cardWidth) / 2, (height - cardHeight) / 2, cardWidth, cardHeight)
  return canvas
}

function side(p, q) {
  return Math.hypot(q[0] - p[0], q[1] - p[1])
}

function canvasOf(width, height) {
  const canvas = Object.assign(document.createElement("canvas"), { width, height })
  return { canvas, context: canvas.getContext("2d", { willReadFrequently: true }) }
}

function toGray({ data, width, height }) {
  const gray = new Float32Array(width * height)
  for (let i = 0, p = 0; i < gray.length; i++, p += 4) gray[i] = 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2]
  return gray
}
