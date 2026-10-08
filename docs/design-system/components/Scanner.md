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
- A picked photo is searched for the card (`scanner/detector.js`), which is straightened into the guide's box before the strips are cut. When no card edge is found, the status line says so and gives the framing advice; `.c-scanner__hint` under the controls gives it before any photo is picked.
- With art matching on and an art index built (spec 011), `.c-scanner__art` under the controls is a second, quiet status line (`role="status"`, `aria-live="polite"`, styled like the hint): "Loading artwork matching…", then "Artwork matching is on" or "Artwork matching isn't available. The scanner is reading text only." It isn't rendered otherwise.
- Candidates are `ItemTile`s. Each says what it was matched by: a `c-badge--success` with a check, "Matched by its collector line" (or "…, one digit corrected"), or a `c-badge--warning` with the alert icon, "Printing not confirmed"; "Matched by its name" follows in muted text (spec 009 AC-2.1, AC-5.1).
- Under each candidate, `.c-scanner__adds` holds one `button_to` per finish (`form.c-scanner__add`, `c-btn--secondary c-btn--sm`, at least 44px): the finish's name, or "Add" for a printing with one finish or none. The accessible name says exactly what is added: "Add Lightning Bolt MOM · 123 Foil". A foil marker read off the card relabels the Foil button "Foil · read from the card" and chooses nothing (AC-6.5).
- Each candidate has a ghost "Other printings" link into the `turbo-frame#scanner_printings` under the candidates. The frame lists the card's English printings (`.c-scanner__printings`, a `c-list`: set · number, set name and release date, then the add buttons), with what was read first. Twenty show; the rest sit in a `details.c-scanner__more` ("Show N more").
- After an add, the reading clears and `#status` announces "Added 1 × Lightning Bolt (MOM · 123, Foil) to your collection."; the camera keeps running.
- The open sitting (`#scanner_sitting`, `.c-scanner__sitting`) follows the result: a `c-section__head` "This sitting: N cards" with a "Done" button, then a `c-list` of adds, newest first (name; set · number, finish or "—", "Added … ago"; "Details" and "Undo"). Ten show; the rest sit in a `details.c-scanner__more` whose summary is "Show all N". An add whose lot was removed or merged away shows a `c-tag` "Changed in your collection" instead of its actions.
- "Undo" (`form.c-scanner__undo`) takes the add's copy back in place and `#status` announces "Removed 1 × … from your collection.". "Details" opens the copy's Edit copy page and returns to the scanner.
- "Done" opens a `ConfirmPage` ("End this sitting?", the count kept, `c-btn--danger` "End sitting", whose form is non-Turbo). The scanner then shows the one-time summary ("Added N cards in this sitting", a `c-status__message` with a link to the collection) in place of the list.
- Problems (no camera, no HTTPS, the text not sent) use the `StatusMessage` inline alert, with one next step as a button.
- The page needs JavaScript; `<noscript>` points to the catalog search.
- Parts the controllers show and hide use the `hidden` attribute; `.c-scanner [hidden]` keeps a hidden `c-btn` hidden.
- The development-only measurement panel (`scanner/measurements/_panel.html.erb`, outside `.c-scanner`) is built from `c-section`, `c-field` and `c-status__message`; `#measurement_panel [hidden]` keeps its hidden retry button and message hidden.
