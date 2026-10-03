import { canvasOf } from "/canvas.js"

const CARD_ASPECT = 63 / 88
const STAGE_ASPECT = 3 / 4
const GUIDE_HEIGHT = 0.8 // geometry.js GUIDE.height: the card's share of a 3:4 picture's height

// Solves for the 8 parameters of the map (u, v) -> (x, y) taking the output rectangle's corners to the
// card's corners: x = (a u + b v + c) / (g u + h v + 1), y = (d u + e v + f) / (g u + h v + 1).
export function homography(width, height, corners) {
  const from = [ [0, 0], [width, 0], [width, height], [0, height] ]
  const rows = [], rhs = []
  for (let i = 0; i < 4; i++) {
    const [u, v] = from[i], [x, y] = corners[i]
    rows.push([u, v, 1, 0, 0, 0, -u * x, -v * x]); rhs.push(x)
    rows.push([0, 0, 0, u, v, 1, -u * y, -v * y]); rhs.push(y)
  }
  return solve(rows, rhs)
}

export function solve(a, b) {
  const n = b.length
  const m = a.map((row, i) => [ ...row, b[i] ])
  for (let col = 0; col < n; col++) {
    let pivot = col
    for (let r = col + 1; r < n; r++) if (Math.abs(m[r][col]) > Math.abs(m[pivot][col])) pivot = r
    ;[m[col], m[pivot]] = [m[pivot], m[col]]
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

// Straightens the card into a width x height canvas with bilinear sampling and nothing else (AC-2.1).
export function warp(source, corners, width, height) {
  const src = source.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, source.width, source.height)
  const [a, b, c, d, e, f, g, hh] = homography(width, height, corners)
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
  const { canvas, ctx } = canvasOf(width, height)
  ctx.putImageData(out, 0, 0)
  return canvas
}

// The 3:4 picture the shipped photo path reads: the card fills the guide's box (80% of the height, 63:88,
// centred), the rest is one flat colour (a tuned setting).
export function picture(card, fill) {
  const height = Math.round(card.height / GUIDE_HEIGHT)
  const width = Math.round(height * STAGE_ASPECT)
  const { canvas, ctx } = canvasOf(width, height)
  ctx.fillStyle = fill
  ctx.fillRect(0, 0, width, height)
  const cardHeight = height * GUIDE_HEIGHT, cardWidth = cardHeight * CARD_ASPECT
  ctx.drawImage(card, (width - cardWidth) / 2, (height - cardHeight) / 2, cardWidth, cardHeight)
  return canvas
}
