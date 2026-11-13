# Scanner

The card scanner. Two sections: the phone-first scanner, drawn by spec 080 (#343) and built by #344 (the one-screen page) and #345 (the selection pane); and the scanner as built today, which stays true until those merge. Each of them deletes what it replaces in the second section.

## The phone-first scanner (drawn by spec 080, built by #344 and #345)

One screen that never scrolls: a top bar with the sitting's destination, the camera filling everything between the bars, and a bottom bar whose main button is always in view. After a capture the frozen capture shrinks into a strip and the selection pane slides up over the rest of the stage. Nothing here is live yet: no view renders these parts, and the scanner works as the second section says until #344 and #345 merge. Previews: `ScannerFlow.html` (the five steps), `ScannerConfidence.html` (the pane's three states), `Sheet.html` (the two sheets).

**Markup** — no view renders it yet. Shown for a Magic: The Gathering card, with a result.

```html
<body class="c-shell c-shell--untabbed c-shell--focused">
<div class="c-scan c-scan--result">
  <div class="c-scan__top">
    <a class="c-scan__back" href="/collection" aria-label="Back"><svg …back…></svg></a>
    <button type="button" class="c-scan__dest"><span class="c-scan__dest-label">Adding to</span> <span class="c-scan__dest-value"><span class="c-scan__dest-text">Atraxa › Main · NM</span><svg …chevron…></svg></span></button>
    <a class="c-btn c-btn--ghost c-scan__done" href="…">Done</a>
  </div>
  <div class="c-scan__stage">
    <video class="c-scan__video" playsinline muted></video>
    <div class="c-scan__guide" aria-hidden="true"></div>
    <div class="c-scan__line c-scan__line--status" hidden><p class="c-scan__line-text" role="status"></p></div>
    <div class="c-scan__line c-scan__line--added" hidden><p class="c-scan__line-text" role="status"></p><form class="c-scan__undo">…<button class="c-btn c-btn--ghost">Undo</button></form></div>
    <div class="c-scan__strip">
      <canvas class="c-scan__capture"></canvas>
      <div class="c-scan__read"><p class="c-scan__read-label">Read from the card</p><p class="c-scan__read-name">Lightning Bolt</p><p class="c-scan__read-line">MOM · 123 · EN</p></div>
    </div>
    <div class="c-scanpane">
      <p class="c-band c-band--success" role="status"><svg …check…></svg><span>Matched by its collector line</span></p>
      <div class="c-scanpane__body">
        <div class="c-scanpane__rowwrap">
          <ul class="c-scanpane__row">
            <li class="c-scanpane__item" aria-current="true"><img src="…" alt="Lightning Bolt, March of the Machine, MOM · 123"></li>
            <li class="c-scanpane__item"><img src="…" alt="…"></li>
          </ul>
          <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--prev" aria-label="Previous printing" disabled><svg …></svg></button>
          <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--next" aria-label="Next printing"><svg …></svg></button>
        </div>
        <div class="c-scanpane__card">
          <div class="c-scanpane__details">
            <h2 class="c-scanpane__name">Lightning Bolt</h2>
            <p class="c-scanpane__set">March of the Machine</p>
            <p class="c-scanpane__meta"><span class="c-tag">MOM · 123</span> <span>2023</span> <span class="c-scanpane__position">1 of 14 printings</span></p>
          </div>
          <div class="c-scanpane__adds">
            <form class="c-scanpane__add">…<button class="c-btn c-btn--secondary" aria-label="Add Lightning Bolt MOM · 123 Nonfoil">Add nonfoil</button></form>
            <form class="c-scanpane__add">…<button class="c-btn c-btn--secondary" aria-label="Add Lightning Bolt MOM · 123 Foil"><svg …star… aria-hidden="true"></svg>Add foil</button></form>
          </div>
        </div>
        <div class="c-scanpane__card" hidden>…</div>
      </div>
    </div>
  </div>
  <div class="c-scan__bottom">
    <button type="button" class="c-btn c-btn--secondary c-scan__count" aria-label="12 added. Show this sitting's cards."><b>12</b><span>added</span></button>
    <button type="button" class="c-btn c-btn--secondary c-scan__main">Scan again</button>
    <button type="button" class="c-btn c-btn--secondary c-scan__torch" aria-label="Torch" aria-pressed="false"><svg …></svg></button>
  </div>
</div>
</body>
```

Without a result the shell has no `c-scan--result`, the stage holds no strip and no pane, and the main button is the primary "Capture". The two lines over the camera, while aiming and after an add:

```html
<div class="c-scan__line c-scan__line--status"><p class="c-scan__line-text" role="status">Line the card up with the guide, then capture.</p></div>
<div class="c-scan__line c-scan__line--added" hidden><p class="c-scan__line-text" role="status"></p><form class="c-scan__undo">…<button class="c-btn c-btn--ghost">Undo</button></form></div>

<div class="c-scan__line c-scan__line--status" hidden><p class="c-scan__line-text" role="status"></p></div>
<div class="c-scan__line c-scan__line--added"><p class="c-scan__line-text" role="status">Added Lightning Bolt MOM · 123, foil</p><form class="c-scan__undo">…<button class="c-btn c-btn--ghost">Undo</button></form></div>
```

- **A focused page** (README, Mobile and Hotwire): no app header and no tab bar. The `<body>` carries `c-shell--focused` beside `c-shell--untabbed`, so the shell (`c-scan`, as tall as the dynamic viewport) is exactly the screen and the document never scrolls. The top bar is 56px, the bottom bar 96px, and the stage is everything between.
- **Controls** are 44px or more at every pointer: Back (44px), the destination, Done, the count (84 × 56px), the main button (64px high, taking the room that is left; the torch's too when there is none) and the torch (56px, only where the camera reports one).
- **The destination** opens the sitting's choices in a `Sheet`; the count opens the sitting's list in another. Neither navigates: every visit to the scanner releases the camera. "Done" keeps its confirm page and "Details" of an add still leaves for Edit copy. The destination sheet's form keeps `c-scanner__place` (its fieldset's `min-width:0`, spec 042 AC-7.1), and the list keeps `c-scanner__sitting`.
- **State is in the markup, never in a script's memory.** `c-scan--result` on the shell shows the capture strip and the pane; without it the stage is the live camera. The main button's `disabled` is the reading state. The row's centred item carries `aria-current="true"`. The server renders one `c-scanpane__card` per image, and every one but the centred card's carries `hidden`. Parts are shown and hidden with the `hidden` attribute (`.c-scan [hidden]` and `.c-scanpane [hidden]` keep a hidden `c-btn` hidden).
- **The stage follows the theme**: `surface-sunken` under the picture, which covers it. The guide is drawn as today (`brand`, with an `on-brand` dashed line inside), its box set inline by the camera controller. The guide's geometry is #344's, which re-measures the reading at the new framing.
- **Two lines over the camera**, 16px under the stage's top, on `surface-raised` with a `line-strong` border: the status line, centred, and the after-add line, which takes its place and spans the stage. While one shows, the other's wrapper carries `hidden`. Each line's `role="status"` element stays in the document and its text is inserted or replaced, which is what gets announced; Undo sits in the wrapper, outside the live region. The status line, the after-add line and the band are the page's three live regions.
- **Capture and add stay the collector's taps**, and one reading adds at most one copy. The frozen frame and the capture strip are drawn in the page from the captured frame: the picture never leaves the device and nothing new is sent.
- **The capture strip** is 144px with a 124px picture, 96px with a 76px one when the shell (on a phone, the screen) is less than 720px high, and never taller: the name read is one line, ending in an ellipsis.
- **The pane** fills the rest of the stage. The `StatusBand` is its top edge and never scrolls. Under it the image row gives way on a short screen: the images are 288px high at most and 160px at least. When the pane still does not fit (below 640px of screen, or with a wrapped band or set name), its content scrolls inside it; the bars, the strip and the band never move.
- **The row** scrolls sideways with scroll snap and draws no scrollbar. It holds the candidates first (three at most, in ranked order), then the centred card's other printings in today's Other printings order; when the scanner is not sure of the card it holds the candidate cards (design decision 17). The centred image has a 2px `brand` outline, and the images carry no text.
- **A swipe is never the only way**: Previous and Next sit over the neighbours (44px, the one at the row's end disabled). The centred card is announced through the band, which follows it (design decision 14): on a printing other than the matched one it reads "Not the printing that was read". The band is one element whose form, icon and sentence are replaced in place (`StatusBand`).
- **One details block** describes the centred card, each fact on its own line: the name; the set's full name, free to wrap; the set code and number as a tag with the year, and the position at the end.
- **One add button per finish**, sharing the pane's width, 52px high, wrapping onto two lines when it must; a special finish's button carries the star in `foil`. A foil marker read off the card relabels its button and chooses nothing.
- **Motion**: the capture's shrink and the pane's slide take 200ms and stop under reduced motion (README, Motion). The shrink starts from `--from` times the picture's size (4 unless the script sets it on `c-scan__capture`).

**Copy**

| Where | Words |
|---|---|
| Status line | "Line the card up with the guide, then capture." while aiming; "Reading the card…" while a reading runs |
| Top bar | "Adding to" over the destination: "Atraxa › Main · NM" (a place and a condition), "Blue binder" (a place alone), "No location · NM" (a condition alone), "No location". "Done". The back arrow is named "Back" |
| Count | "12 added" ("0 added", "1 added"); its accessible name is "12 added. Show this sitting's cards." |
| Main button | "Capture"; "Scan again" while a result shows. The torch is named "Torch" |
| Capture strip | "Read from the card", the name read, and the collector line read or "nothing read" |
| Band, success | "Matched by its collector line"; "Matched by its collector line, one digit corrected"; "Matched by its artwork" |
| Band, warning | "Printing not confirmed. Swipe to check." (alert); "Not sure of this card. Check it against your capture." (question mark); "Not the printing that was read" (alert, on a swipe away from the match) |
| Position | "1 of 14 printings"; "1 of 3 possible cards" |
| Add buttons | "Add nonfoil", "Add foil", "Add" and a finish's name in lower case ("Add etched"); "Add" alone for one finish or none; "Add foil · read from the card" when the foil marker was read. Accessible names stay today's: "Add Lightning Bolt MOM · 123 Foil" |
| After-add line | "Added Lightning Bolt MOM · 123, foil"; "Added Lightning Bolt MOM · 123" for a printing with no finish; "Undo". It names no condition or place: the top bar shows them |
| Previous and Next | "Previous printing", "Next printing"; "Previous card", "Next card" while the row holds possible cards |
| Sheets | "Adding to" (the destination); "This sitting: 12 cards" (the list) |

**Placed by #344 and #345** (today's copy stands until then): "Use a photo", the artwork-matching line, the photo-framing hint, the camera-unavailable states, "Nothing could be read", "No card matches", the catalog-not-ready notice, the send failures and the art-overrule sentence; the layout from 640px up, landscape and the bars' safe-area insets; how many printings load at once.

## As built, until #344 and #345

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
- With art matching on (spec 011), a candidate the artwork decided carries a `c-badge--success` with a check, "Matched by its artwork", when the artwork belongs to that printing alone; when several printings share it, "Matched by its artwork" is a muted evidence line beside "Printing not confirmed". A weak art match adds the muted line "Artwork looks similar" and no badge. "What the scanner read" gains an Artwork row ("Matched", "Looks similar" or "No match") when the capture sent artworks. When the artwork overruled the name or the collector line, one `c-status__message` sentence above the candidates says so ("The artwork matches a different card from the one the name suggests. The artwork's match is first."). "Other printings" then lists the printings sharing the artwork first.
- Under each candidate, `.c-scanner__adds` holds one `button_to` per finish (`form.c-scanner__add`, `c-btn--secondary c-btn--sm`, at least 44px): the finish's name, or "Add" for a printing with one finish or none. The accessible name says exactly what is added: "Add Lightning Bolt MOM · 123 Foil". A foil marker read off the card relabels the Foil button "Foil · read from the card" and chooses nothing (AC-6.5).
- Each candidate has a ghost "Other printings" link into the `turbo-frame#scanner_printings` under the candidates. The frame lists the card's English printings (`.c-scanner__printings`, a `c-list`: set · number, set name and release date, then the add buttons), with what was read first. Twenty show; the rest sit in a `details.c-scanner__more` ("Show N more").
- After an add, the reading clears and `#status` announces "Added 1 × Lightning Bolt (MOM · 123, Foil, NM) in Blue binder to your collection." (spec 042 AC-1.3: the condition's short label after the finish, "(MOM · 123, NM)" for a printing with no finish, "in <place>" while the lot has one; with the sitting's condition unspecified the label is left out). Undo's announcement and the accessible names ("Undo …", "Details of …") do not name the condition; the camera keeps running.
- The open sitting (`#scanner_sitting`, `.c-scanner__sitting`) follows the result: a `c-section__head` "This sitting: N cards" (followed by the choices that are set, ", Near mint" and ", in Blue binder"; spec 042 decision 3) with a "Done" button, then a `c-list` of adds, newest first (name; set · number, finish or "—", the short condition label (read from the entry's lot, "NM"; none while the lot's condition is unspecified; spec 042 AC-1.3), "in <place>" while the add's lot is in a location, "Added … ago"; "Details" and "Undo"). Ten show; the rest sit in a `details.c-scanner__more` whose summary is "Show all N". An add whose lot was removed or merged away shows a `c-tag` "Changed in your collection" instead of its actions, and names no condition or place.
- The sitting's one control (`form.c-form.c-scanner__place`, specs 040 and 042 decision 2) sits under the heading and shows for every signed-in collector, before the first add too (spec 042 AC-1.1). A `fieldset.c-choices` (the choice page's fieldset: a flex column, no border) with the legend "This sitting's cards" holds, stacked, a `c-field` "Condition" (a native select, "Not specified" first, then the scale as "Near mint (NM)" … "Damaged (DMG)") and, while the account has locations, a `c-field` "Location" ("No location" first, then the locations in the order of the locations page); a `c-btn--secondary c-btn--sm` "Set" sits in its `c-form__actions`. It works without script: "Set" submits it, a Turbo Stream redraws the panel and says "Cards you scan now: Near mint, in Blue binder." in `#status` (both choices for an account with locations, "condition not specified" and "no location" for what is unset, the condition alone for an account with none), and `sitting_focus_controller.js` then puts focus back on "Set" (spec 047). When "Set" deletes an empty sitting, or clears both choices with none open, the same sentence says "condition not specified" and "no location" (spec 047 decision 1, superseding spec 042 decision 3's cleared line). With no sitting open, the panel holds the control alone (no heading, no "Done"). The control uses existing classes plus one rule in `additions.css`, `.c-scanner__place .c-choices { min-width: 0; }`: a fieldset is as wide as its widest child by default, so without it a long location name widens the panel past 390px (spec 042 AC-7.1, plan open item P1).
- A sitting with no entries says, in a `c-empty`, "Cards you scan now: Near mint, in Blue binder." naming only the parts that are set, and "Nothing added yet." with neither (a redraw the next render drops); once every add was undone it says "Everything added in this sitting was undone." (spec 042 decision 3).
- "Undo" (`form.c-scanner__undo`) takes the add's copy back in place and `#status` announces "Removed 1 × … from your collection.", and the panel's heading (`h2[tabindex=-1]`, which has a `:focus-visible` ring in `focus`, not a Tab stop) takes focus, since the Undo button is gone (spec 047). "Details" opens the copy's Edit copy page and returns to the scanner.
- Focus after a redraw (spec 047): the redrawn panel carries `data-controller="sitting-focus"` and `data-sitting-focus-to-value` (`set` after a "Set", `heading` after an Undo) only in the answer to those; the page's own render and an add name nothing, so nothing moves focus.
- "Done" opens a `ConfirmPage` ("End this sitting?", the count kept, `c-btn--danger` "End sitting", whose form is non-Turbo). The scanner then shows the one-time summary ("Added N cards in this sitting", a `c-status__message` with a link to the collection) in place of the list, with the control under it on "Not specified" (and "No location" while the account has locations), for every account (spec 042 decision 3).
- Problems (no camera, no HTTPS, the text not sent) use the `StatusMessage` inline alert, with one next step as a button.
- The page needs JavaScript; `<noscript>` points to the catalog search.
- Parts the controllers show and hide use the `hidden` attribute; `.c-scanner [hidden]` keeps a hidden `c-btn` hidden.
- The development-only measurement panel (`scanner/measurements/_panel.html.erb`, outside `.c-scanner`) is built from `c-section`, `c-field` and `c-status__message`; `#measurement_panel [hidden]` keeps its hidden retry button and message hidden.
- On a coarse pointer the sitting's Condition and Location selects (`c-field`) and the measurement panel's "Card to capture" select are at least the touch floor (44px) high (`Form`, spec 072).
