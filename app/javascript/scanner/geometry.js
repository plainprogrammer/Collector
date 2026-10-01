// Card guide and strip geometry for the scanner (spec 007 AC-1.3, AC-4.2). The stage is 3:4; the guide is a
// 63:88 card centred in it; strips are fractions of the guide. Live frames and picked photos use the same
// rules, and the CSS gives .c-scanner__stage the same aspect ratio.
export const CARD_ASPECT = 63 / 88
export const STAGE_ASPECT = 3 / 4
export const GUIDE = { height: 0.8, maxWidth: 0.9 } // shares of the stage
// Frozen before the measured run, tuned only on cards outside the corpus (spec 007 AC-6.1).
export const STRIPS = {
  name: { x: 0.05, y: 0.03, w: 0.72, h: 0.085 },
  collector: { x: 0.03, y: 0.905, w: 0.55, h: 0.085 }
}

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

export function cropStrips(image, card) {
  return Object.fromEntries(Object.entries(STRIPS).map(([ key, strip ]) => {
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(card.width * strip.w)
    canvas.height = Math.round(card.height * strip.h)
    canvas.getContext("2d").drawImage(image, card.x + card.width * strip.x, card.y + card.height * strip.y,
      canvas.width, canvas.height, 0, 0, canvas.width, canvas.height)
    return [ key, canvas ]
  }))
}
