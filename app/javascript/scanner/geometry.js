// Card guide and strip geometry for the scanner (spec 007 AC-1.3, AC-4.2). The stage is 3:4; the guide is a
// 63:88 card centred in it; strips are fractions of the guide. Live frames and picked photos use the same
// rules, and the CSS gives .c-scanner__stage the same aspect ratio.
export const CARD_ASPECT = 63 / 88
export const STAGE_ASPECT = 3 / 4
export const GUIDE = { height: 0.8, maxWidth: 0.9 } // shares of the stage
// Frozen on 2026-10-01 for the measured run after 4 tuning rounds on 12 cards outside the corpus (spec 007 AC-6.1).
export const STRIPS = {
  name: { x: 0.05, y: 0.055, w: 0.75, h: 0.11 },
  collector: { x: 0.03, y: 0.89, w: 0.55, h: 0.11 }
}
// Strips for a picture the detector straightened (spec 009 AC-6.6): there the card exactly fills the guide, unlike a live
// frame, where it sits a little inside. Starts equal to STRIPS; tuned on the spike's development photos.
export const DETECTED_STRIPS = { name: { ...STRIPS.name }, collector: { ...STRIPS.collector } }
// Strips are drawn at this many times their size before OCR. A tuning setting, frozen before the measured run (AC-6.1).
export const STRIP_SCALE = 2
// Strips whose dark pixel rows are inverted before OCR. A tuning setting, frozen before the measured run (AC-6.1).
// Collector lines are light text on the black border; inverting the name strip too hurt name matching (round 3).
export const INVERT_DARK_ROWS = [ "collector" ]

export function guideRect(viewWidth, viewHeight) {
  let height = viewHeight * GUIDE.height
  let width = height * CARD_ASPECT
  if (width > viewWidth * GUIDE.maxWidth) {
    width = viewWidth * GUIDE.maxWidth
    height = width / CARD_ASPECT
  }
  return { x: (viewWidth - width) / 2, y: (viewHeight - height) / 2, width, height }
}

// The guide in image pixels when a frameWidth × frameHeight image fills a view with object-fit: cover.
export function guideInFrame(frameWidth, frameHeight, viewWidth, viewHeight) {
  const scale = Math.max(viewWidth / frameWidth, viewHeight / frameHeight)
  const offsetX = (frameWidth - viewWidth / scale) / 2
  const offsetY = (frameHeight - viewHeight / scale) / 2
  const guide = guideRect(viewWidth, viewHeight)
  return { x: offsetX + guide.x / scale, y: offsetY + guide.y / scale, width: guide.width / scale, height: guide.height / scale }
}

export function cropStrips(image, card, layout = STRIPS) {
  return Object.fromEntries(Object.entries(layout).map(([ key, strip ]) => {
    const width = Math.round(card.width * strip.w)
    const height = Math.round(card.height * strip.h)
    const canvas = document.createElement("canvas")
    canvas.width = width * STRIP_SCALE
    canvas.height = height * STRIP_SCALE
    const context = canvas.getContext("2d", { willReadFrequently: true })
    context.drawImage(image, card.x + card.width * strip.x, card.y + card.height * strip.y,
      width, height, 0, 0, canvas.width, canvas.height)
    stretchContrast(context, canvas.width, canvas.height)
    if (INVERT_DARK_ROWS.includes(key)) invertDarkRows(context, canvas.width, canvas.height)
    return [ key, canvas ]
  }))
}

// Grayscale, then stretch so the darkest pixel is black and the lightest white. Tuning round 1 read clipped names
// and small, low-contrast collector lines (grey on a dark border) as empty; enlarging and stretching helps OCR.
function stretchContrast(context, width, height) {
  const image = context.getImageData(0, 0, width, height)
  const pixels = image.data
  const gray = new Uint8ClampedArray(pixels.length / 4)
  for (let i = 0; i < gray.length; i++) {
    gray[i] = 0.299 * pixels[i * 4] + 0.587 * pixels[i * 4 + 1] + 0.114 * pixels[i * 4 + 2]
  }
  let min = 255, max = 0
  for (const value of gray) { min = Math.min(min, value); max = Math.max(max, value) }
  if (max === min) return
  for (let i = 0; i < gray.length; i++) {
    const value = (gray[i] - min) * 255 / (max - min)
    pixels[i * 4] = pixels[i * 4 + 1] = pixels[i * 4 + 2] = value
  }
  context.putImageData(image, 0, 0)
}

// Turn light-on-dark rows into dark-on-light: invert every pixel row whose mean luminance is below 128. The bright
// text-box rows above a collector line are left alone.
function invertDarkRows(context, width, height) {
  const image = context.getImageData(0, 0, width, height)
  const pixels = image.data
  for (let y = 0; y < height; y++) {
    const start = y * width * 4, end = start + width * 4
    let sum = 0
    for (let i = start; i < end; i += 4) sum += 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2]
    if (sum / width >= 128) continue
    for (let i = start; i < end; i += 4) {
      pixels[i] = 255 - pixels[i]; pixels[i + 1] = 255 - pixels[i + 1]; pixels[i + 2] = 255 - pixels[i + 2]
    }
  }
  context.putImageData(image, 0, 0)
}
