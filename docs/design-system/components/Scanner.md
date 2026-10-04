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
- Candidates are `ItemTile`s. Each says what it was matched by: a `c-badge--success` with a check, "Matched by its collector line" (or "…, one digit corrected"), or a `c-badge--warning` with the alert icon, "Printing not confirmed"; "Matched by its name" follows in muted text (spec 009 AC-2.1, AC-5.1).
- Under each candidate, `.c-scanner__adds` holds one `button_to` per finish (`form.c-scanner__add`, `c-btn--secondary c-btn--sm`, at least 44px): the finish's name, or "Add" for a printing with one finish or none. The accessible name says exactly what is added: "Add Lightning Bolt MOM · 123 Foil". A foil marker read off the card relabels the Foil button "Foil · read from the card" and chooses nothing (AC-6.5).
- After an add, the reading clears and `#status` announces "Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection."; the camera keeps running.
- The open sitting (`#scanner_sitting`, `.c-scanner__sitting`) follows the result: a `c-section__head` "This sitting: N cards" with a "Done" button, then a `c-list` of adds, newest first (name; set · number, finish or "—", "Added … ago"; "Details" and "Undo"). Ten show; the rest sit in a `details.c-scanner__more` whose summary is "Show all N". An add whose lot was removed or merged away shows a `c-tag` "Changed in your collection" instead of its actions.
- Problems (no camera, no HTTPS, the text not sent) use the `StatusMessage` inline alert, with one next step as a button.
- The page needs JavaScript; `<noscript>` points to the catalog search.
- Parts the controllers show and hide use the `hidden` attribute; `.c-scanner [hidden]` keeps a hidden `c-btn` hidden.
- The development-only measurement panel (`scanner/measurements/_panel.html.erb`, outside `.c-scanner`) is built from `c-section`, `c-field` and `c-status__message`; `#measurement_panel [hidden]` keeps its hidden retry button and message hidden.
