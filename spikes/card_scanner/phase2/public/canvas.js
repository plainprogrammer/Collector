export function canvasOf(width, height) {
  const canvas = new OffscreenCanvas(width, height)
  return { canvas, ctx: canvas.getContext("2d", { willReadFrequently: true }) }
}

// Draws a bitmap at a scale: scale 1 keeps the photo's pixels; otherwise the whole photo is fitted into
// the given height (1440 for the live-frame stand-in, AC-2.6).
export function sourceCanvas(bitmap, targetHeight) {
  const scale = targetHeight ? targetHeight / bitmap.height : 1
  const { canvas, ctx } = canvasOf(Math.round(bitmap.width * scale), Math.round(bitmap.height * scale))
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
  return canvas
}

export function imageDataOf(canvas) {
  return canvas.getContext("2d", { willReadFrequently: true }).getImageData(0, 0, canvas.width, canvas.height)
}

export function toGray(imageData) {
  const { data, width, height } = imageData
  const gray = new Float32Array(width * height)
  for (let i = 0, p = 0; i < gray.length; i++, p += 4) gray[i] = 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2]
  return gray
}

export async function pngBlob(canvas) {
  return canvas.convertToBlob({ type: "image/png" })
}
