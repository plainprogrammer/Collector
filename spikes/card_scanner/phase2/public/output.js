import { pngBlob } from "/canvas.js"

export async function store(run, stem, name, canvas) {
  const response = await fetch(`/outputs/${run}/${stem}/${name}`, { method: "POST", body: await pngBlob(canvas), headers: { "Content-Type": "image/png" } })
  if (!response.ok) throw new Error(`Storing ${name} failed: HTTP ${response.status}`)
}
