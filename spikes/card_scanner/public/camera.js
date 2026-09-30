// Phase 0 camera spike (spec 005, Story 2): start a camera, capture one frame, and hash it
// and the source photo with the same 16×16 average hash so a test can compare them.
function averageHash(source, width, height) {
  const canvas = Object.assign(document.createElement("canvas"), { width: 16, height: 16 })
  const context = canvas.getContext("2d", { willReadFrequently: true })
  context.drawImage(source, 0, 0, width, height, 0, 0, 16, 16)
  const { data } = context.getImageData(0, 0, 16, 16)
  const grey = []
  for (let i = 0; i < data.length; i += 4) grey.push(0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2])
  const mean = grey.reduce((sum, value) => sum + value, 0) / grey.length
  return grey.map((value) => (value > mean ? "1" : "0")).join("")
}

const video = document.getElementById("video")
const capture = document.getElementById("capture")
const status = document.getElementById("status")
let stream = null

document.getElementById("start").addEventListener("click", async () => {
  try {
    stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false })
    video.srcObject = stream
    await video.play()
    capture.disabled = false
    status.textContent = `Camera: ${stream.getVideoTracks()[0].label}`
  } catch (error) {
    status.textContent = `Camera error: ${error.name}`
  }
})

capture.addEventListener("click", () => {
  document.getElementById("frame-hash").value = averageHash(video, video.videoWidth, video.videoHeight)
  stream.getTracks().forEach((track) => track.stop())
  video.srcObject = null
})

const source = new URLSearchParams(location.search).get("source")
if (source) {
  const image = await createImageBitmap(await (await fetch(`/corpus/${encodeURIComponent(source)}`)).blob())
  document.getElementById("source-hash").value = averageHash(image, image.width, image.height)
}
