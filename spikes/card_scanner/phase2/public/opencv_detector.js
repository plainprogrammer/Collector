import { canvasOf } from "/canvas.js"
import { orderCorners, validQuad } from "/hand_detector.js"

let loading = null

// Loads the prebuilt build from this origin once. 4.x builds expose `cv` as a Promise, as the Emscripten Module
// (4.13.0: a thenable that is already initialising and resolves with itself, so setting `onRuntimeInitialized`
// after load never fires), or fire `onRuntimeInitialized`; all are handled. The Module's `then` is removed once
// it is ready, since resolving a promise with a self-resolving thenable never settles.
export function loadOpenCV(url) {
  loading ||= new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = url
    script.onerror = () => reject(new Error(`Loading ${url} failed (see the server's csp-reports.jsonl)`))
    script.onload = async () => {
      try {
        let cv = window.cv
        if (cv instanceof Promise) cv = await cv
        else if (!cv.Mat) {
          await new Promise((ready) => {
            if (typeof cv.then === "function") cv.then(() => ready())
            else cv.onRuntimeInitialized = ready
          })
        }
        if (typeof cv.then === "function") delete cv.then
        window.cv = cv
        resolve(cv)
      } catch (error) { reject(error) }
    }
    document.head.appendChild(script)
  })
  return loading
}

// Canny edges, the largest convex four-point contour, and the same ordering and checks as the hand detector.
export function detectOpenCV(cv, source, settings) {
  const scale = settings.workWidth / source.width
  const w = settings.workWidth, h = Math.round(source.height * scale)
  const { canvas, ctx } = canvasOf(w, h)
  ctx.drawImage(source, 0, 0, w, h)
  const src = cv.matFromImageData(ctx.getImageData(0, 0, w, h))
  const gray = new cv.Mat(), blurred = new cv.Mat(), edges = new cv.Mat(), dilated = new cv.Mat(), hierarchy = new cv.Mat()
  const kernel = cv.Mat.ones(3, 3, cv.CV_8U), contours = new cv.MatVector()
  let corners = null
  try {
    cv.cvtColor(src, gray, cv.COLOR_RGBA2GRAY)
    cv.GaussianBlur(gray, blurred, new cv.Size(settings.blur, settings.blur), 0)
    cv.Canny(blurred, edges, settings.canny[0], settings.canny[1])
    cv.dilate(edges, dilated, kernel)
    cv.findContours(dilated, contours, hierarchy, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE)
    const candidates = []
    for (let i = 0; i < contours.size(); i++) {
      const contour = contours.get(i)
      candidates.push({ index: i, area: cv.contourArea(contour) })
      contour.delete()
    }
    candidates.sort((p, q) => q.area - p.area)
    for (const { index, area } of candidates.slice(0, 10)) {
      if (area < settings.minArea * w * h) break
      const contour = contours.get(index), approx = new cv.Mat()
      cv.approxPolyDP(contour, approx, settings.approxEpsilon * cv.arcLength(contour, true), true)
      const points = approx.rows === 4 && cv.isContourConvex(approx) ? [0, 1, 2, 3].map((k) => [approx.data32S[2 * k], approx.data32S[2 * k + 1]]) : null
      approx.delete()
      contour.delete()
      if (!points) continue
      const ordered = orderCorners(points)
      if (validQuad(ordered, w, h, settings)) { corners = ordered; break }
    }
  } finally {
    ;[src, gray, blurred, edges, dilated, hierarchy, kernel].forEach((m) => m.delete())
    contours.delete()
  }
  return corners && corners.map(([x, y]) => [x / scale, y / scale])
}
