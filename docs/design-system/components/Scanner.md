# Scanner

The card scanner (spec 007): a live camera feed with a card-shaped guide, the controls under it, and what the scanner read with its candidate printings.

**Markup** — `scanners/_scanner.html.erb` renders it; the controllers `card-reader` and `camera` bring it to life.

```html
<div class="c-scanner">
  <p class="c-scanner__status" role="status" aria-live="polite">Ready. Line the card up with the guide, then capture.</p>
  <div class="c-scanner__stage"><video class="c-scanner__video" playsinline muted></video><div class="c-scanner__guide" aria-hidden="true"></div></div>
  <div class="c-scanner__controls">
    <button class="c-btn c-btn--primary c-scanner__shutter">Capture</button>
    <button class="c-btn c-btn--secondary c-scanner__torch" aria-pressed="false">Torch</button>
    <label class="c-btn c-btn--ghost c-scanner__photo">Use a photo<input type="file" accept="image/*" class="c-sr"></label>
  </div>
  <div id="scanner_result" class="c-scanner__result">…<dl class="c-scanner__read">…</dl><div class="c-grid">…</div></div>
</div>
```

- The stage is 3:4 and the guide a 63:88 card centred in it, at 80% of the stage's height. `scanner/geometry.js` holds the same numbers; change both together.
- The guide is drawn in `brand` with an `on-brand` dashed inner line, so it reads on light and dark scenes. Alignment is never shown by colour alone: the status line says what to do.
- The shutter, torch and photo controls are at least 44px and sit under the stage, in the bottom third of a phone screen.
- Candidates are `ItemTile`s without the add button. A collector-line match carries a `c-badge--success` with a check and the words "Matched by its collector line".
- Problems (no camera, no HTTPS, the text not sent) use the `StatusMessage` inline alert, with one next step as a button.
- The page needs JavaScript; `<noscript>` points to the catalog search.
- Parts the controllers show and hide use the `hidden` attribute; `.c-scanner [hidden]` keeps a hidden `c-btn` hidden.
