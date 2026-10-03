// The art fingerprint, the same arithmetic and loop order as CardScannerPhase2::Fingerprint in Ruby: the art
// region resampled by area to the grid, four planes (grey, blue, green, red), each a difference hash of
// horizontal neighbours, packed most significant bit first into 128 bytes.
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

export function dhash(plane, cols, rows, out, offset) {
  let bit = 0
  for (let j = 0; j < rows; j++) {
    for (let i = 0; i < cols - 1; i++, bit++) {
      if (plane[j * cols + i + 1] > plane[j * cols + i]) out[offset + (bit >> 3)] |= 0x80 >> (bit & 7)
    }
  }
}

// One 128-byte hash of a canvas holding the card (or, for the agreement check, a whole artwork image).
export function fingerprint(canvas, settings, offset) {
  const image = canvas.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, canvas.width, canvas.height)
  const [cols, rows] = settings.grid
  const [x0, y0, x1, y1] = box(canvas.width, canvas.height, settings.box, offset)
  const [r, g, b] = areaResample(image, x0, y0, x1, y1, cols, rows)
  const grey = new Float64Array(r.length)
  for (let k = 0; k < r.length; k++) grey[k] = 0.299 * r[k] + 0.587 * g[k] + 0.114 * b[k]
  const out = new Uint8Array(128)
  ;[grey, b, g, r].forEach((plane, n) => dhash(plane, cols, rows, out, n * 32))
  return out
}

export function fingerprints(canvas, settings) {
  return settings.offsets.map((offset) => fingerprint(canvas, settings, offset))
}

export const hex = (bytes) => Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("")
