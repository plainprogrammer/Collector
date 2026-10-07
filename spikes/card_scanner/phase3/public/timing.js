import { parseIndex, search } from "/phase2/search.js"
import { fingerprints } from "/phase2/fingerprint.js"

// Spec 010 Story 2: loads the full art index on this device and times the download, the parse, 43 searches, 100 searches for
// responsiveness, and the fingerprint of straightened cards; posts everything to /phone/results.
const status = document.getElementById("status"), out = document.getElementById("result")
const bytesOf = (hex) => Uint8Array.from(hex.match(/../g), (h) => parseInt(h, 16))
const popcount = (v) => { v -= (v >>> 1) & 0x55555555; v = (v & 0x33333333) + ((v >>> 2) & 0x33333333); return (((v + (v >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24 }
const bits = (a, b) => { let d = 0; for (let i = 0; i < a.length; i++) d += popcount(a[i] ^ b[i]); return d }
const median = (xs) => { const s = [ ...xs ].sort((a, b) => a - b), m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2 }
const tick = () => new Promise((resolve) => setTimeout(resolve, 0))

async function run(mode) {
  status.textContent = `Running ${mode}…`
  const settings = (await (await fetch("/settings.json")).json()).fingerprint
  const url = new URL("/phone/index.bin", location).href
  performance.clearResourceTimings()
  const started = performance.now()
  const response = await fetch(url, { cache: mode === "cold" ? "reload" : "force-cache" })
  const bytes = new Uint8Array(await response.arrayBuffer())
  const downloaded = performance.now()
  const index = parseIndex(bytes)
  const ready = performance.now()
  const entry = performance.getEntriesByName(url).pop() || {}
  const queries = await (await fetch("/phone/queries.json")).json()
  const searches = queries.map(({ file, hashes }) => {
    const t = performance.now(), top = search(index, hashes.map(bytesOf), 10)
    return { file, ms: performance.now() - t, top: top[0] }
  })
  let gap = 0, last = performance.now()
  for (let i = 0; i < 100; i++) {
    search(index, queries[i % queries.length].hashes.map(bytesOf), 10)
    status.textContent = `Responsiveness: ${i + 1}/100`
    await tick()
    const now = performance.now(); gap = Math.max(gap, now - last); last = now
  }
  const cards = []
  for (const { file, hashes } of queries.slice(0, 12)) {
    const blob = await (await fetch(`/phone/cards/${file.replace(/\.\w+$/, "")}.png`)).blob()
    const bitmap = await createImageBitmap(blob)
    const canvas = Object.assign(document.createElement("canvas"), { width: bitmap.width, height: bitmap.height })
    canvas.getContext("2d", { willReadFrequently: true }).drawImage(bitmap, 0, 0)
    const t = performance.now(), mine = fingerprints(canvas, settings), ms = performance.now() - t
    cards.push({ file, ms, maxBits: Math.max(...mine.map((h, k) => bits(h, bytesOf(hashes[k])))) })
  }
  const result = {
    mode, userAgent: navigator.userAgent, at: new Date().toISOString(),
    index: { count: index.count, decodedBytes: index.bytes, encodedBodySize: entry.encodedBodySize ?? null, transferSize: entry.transferSize ?? null,
      decodedBodySize: entry.decodedBodySize ?? null, contentLength: Number(response.headers.get("content-length")) || null },
    downloadMs: downloaded - started, readyMs: ready - downloaded,
    search: { n: searches.length, medianMs: median(searches.map((s) => s.ms)), slowestMs: Math.max(...searches.map((s) => s.ms)), tops: searches.map(({ file, top }) => ({ file, top })) },
    responsive: { searches: 100, maxGapMs: gap, completed: true },
    fingerprint: { n: cards.length, medianMs: median(cards.map((c) => c.ms)), slowestMs: Math.max(...cards.map((c) => c.ms)), maxBits: Math.max(...cards.map((c) => c.maxBits)), cards },
    // AC-2.5: what the page holds. The ids' bytes are an upper bound (36 UTF-16 code units each); WebKit gives no heap figure.
    memory: { decodedBytes: index.bytes, wordsBytes: index.words.byteLength, ids: index.count, idsBytes: index.ids.reduce((n, id) => n + id.length * 2, 0) }
  }
  const saved = await fetch("/phone/results", { method: "POST", body: JSON.stringify(result), headers: { "Content-Type": "application/json" } })
  out.textContent = JSON.stringify({ ...result, search: { ...result.search, tops: `${result.search.tops.length} tops` } }, null, 2)
  status.textContent = saved.ok ? `Done (${mode}); results saved.` : `Done (${mode}); saving failed: HTTP ${saved.status}`
  return result
}

document.getElementById("cold").addEventListener("click", () => run("cold"))
document.getElementById("warm").addEventListener("click", () => run("warm"))
window.__phase3Timing = { run }
