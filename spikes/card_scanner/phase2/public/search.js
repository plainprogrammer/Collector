// The browser-side search over the flat index (16-byte uuid + 128-byte hash per artwork), the same ranking as
// CardScannerPhase2::ArtIndex#search.
const RECORD = 144
let index = null

export async function loadIndex(url) {
  if (index) return index
  index = parseIndex(new Uint8Array(await (await fetch(url)).arrayBuffer()))
  return index
}

// The flat index's records as the search reads them; exported so spec 010's timing page can time the parse on its own.
export function parseIndex(bytes) {
  const count = bytes.length / RECORD
  const ids = new Array(count), words = new Uint32Array(count * 32)
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  for (let i = 0; i < count; i++) {
    const base = i * RECORD
    const h = Array.from(bytes.subarray(base, base + 16), (b) => b.toString(16).padStart(2, "0")).join("")
    ids[i] = `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
    for (let w = 0; w < 32; w++) words[i * 32 + w] = view.getUint32(base + 16 + w * 4)
  }
  return { count, ids, words, bytes: bytes.length }
}

function popcount(v) {
  v = v - ((v >>> 1) & 0x55555555)
  v = (v & 0x33333333) + ((v >>> 2) & 0x33333333)
  return (((v + (v >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24
}

// Each artwork's distance is the smallest over the query's offset hashes; returns the nearest `limit`.
export function search(index, hashes, limit = 10) {
  const queries = hashes.map((h) => { const v = new DataView(h.buffer, h.byteOffset, 128); return Array.from({ length: 32 }, (_, w) => v.getUint32(w * 4)) })
  const distances = new Uint16Array(index.count)
  for (let i = 0; i < index.count; i++) {
    let best = 1025
    for (const q of queries) {
      let d = 0
      for (let w = 0; w < 32 && d < best; w++) d += popcount(index.words[i * 32 + w] ^ q[w])
      if (d < best) best = d
    }
    distances[i] = best
  }
  const order = Array.from(distances.keys()).sort((p, q) => distances[p] - distances[q] || p - q).slice(0, limit)
  return order.map((i) => ({ id: index.ids[i], distance: distances[i] }))
}
