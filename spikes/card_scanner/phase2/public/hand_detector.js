import { canvasOf, toGray } from "/canvas.js"

// Finds the card as the two strongest near-horizontal and two strongest near-vertical edge lines in a
// downscaled copy of the photo, and returns its four corners in the source's pixel coordinates
// (top-left, top-right, bottom-right, bottom-left), or null. Cards are treated as upright (FR-2).
export function detectHand(source, settings) {
  const scale = settings.workWidth / source.width
  const w = settings.workWidth, h = Math.round(source.height * scale)
  const { canvas, ctx } = canvasOf(w, h)
  ctx.drawImage(source, 0, 0, w, h)
  const gray = toGray(ctx.getImageData(0, 0, w, h))
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
  return corners.map(([x, y]) => [x / scale, y / scale])
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

// Accumulates rho = x cos(theta) + y sin(theta) over edge pixels whose gradient points the right way:
// near-vertical gradients vote for horizontal lines (theta about 90 degrees), near-horizontal for vertical (theta about 0).
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

// The strongest line, then the strongest line at least minSeparation away in rho; null if the second
// is weaker than a third of the first (no second edge of the card was found).
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
  if (corners.some(([x, y]) => x < -margin * w || x > (1 + margin) * w || y < -margin * h || y > (1 + margin) * h)) return false
  let area = 0
  for (let i = 0; i < 4; i++) {
    const [x1, y1] = corners[i], [x2, y2] = corners[(i + 1) % 4]
    area += x1 * y2 - x2 * y1
  }
  area = Math.abs(area) / 2
  if (area < settings.minArea * w * h) return false
  const side = (p, q) => Math.hypot(q[0] - p[0], q[1] - p[1])
  const width = (side(corners[0], corners[1]) + side(corners[3], corners[2])) / 2
  const height = (side(corners[0], corners[3]) + side(corners[1], corners[2])) / 2
  const aspect = width / height
  return aspect >= settings.aspectRange[0] && aspect <= settings.aspectRange[1]
}
