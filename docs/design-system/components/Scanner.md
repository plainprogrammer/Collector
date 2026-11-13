# Scanner

The card scanner. Three parts: the one-screen page, built by #344 (spec 082) on spec 080's shell; what the selection pane will be, drawn by spec 080 and built by #345; and the result partial that fills the pane until #345 replaces it. Each issue deletes what it replaces (spec 080 decision 1).

## The one-screen scanner (built by #344, spec 082)

One screen that never scrolls: a top bar with the sitting's destination, the camera filling everything between the bars, and a bottom bar whose main button is always in view. The sitting's choices and its list are two sheets over the camera, so opening them never releases it. A result opens in the pane over the stage, and an add returns to the live camera with a line that confirms it and offers Undo. Previews: `ScannerFlow.html` (the five steps), `ScannerConfidence.html` (the pane's three states, #345's), `Sheet.html` (the two sheets).

**Markup** — `scanners/_scanner.html.erb` renders it (`scanners/show` and measurement mode both); the controllers `scan-shell`, `sheets`, `card-reader` and `camera` bring it to life. Shown for a Magic: The Gathering card, aiming, with no sitting open. The controllers' `data-*` attributes are left out.

```html
<body class="c-shell c-shell--untabbed c-shell--focused">
<main class="c-scan">
  <h1 class="c-sr">Scan a card</h1>
  <div class="c-scan__top">
    <a class="c-scan__back" href="/collection" aria-label="Back"><svg …back…></svg></a>
    <div id="scanner_sitting_bar" class="c-scan__sitting">
      <button type="button" class="c-scan__dest"><span class="c-scan__dest-label">Adding to</span> <span class="c-scan__dest-value"><span class="c-scan__dest-text">Atraxa › Main · NM</span><svg …chevron…></svg></span></button>
      <a class="c-btn c-btn--ghost c-scan__done" href="…">Done</a>
    </div>
  </div>
  <div class="c-scan__stage">
    <div class="c-scan__feed"><video class="c-scan__video" playsinline muted autoplay></video><div class="c-scan__guide" aria-hidden="true"></div></div>
    <canvas class="c-scan__frozen" aria-hidden="true" hidden></canvas>
    <div class="c-scan__line c-scan__line--status"><p class="c-scan__line-text" id="scanner_status_text" role="status">Ready. Line the card up with the guide, then capture.</p></div>
    <div class="c-scan__line c-scan__line--added" hidden><p class="c-scan__line-text" id="scanner_added_text" role="status"></p><div id="scanner_added_action" class="c-scan__added-action"></div></div>
    <div class="c-scan__notice" hidden><p class="c-scan__notice-text">…</p><button class="c-btn c-btn--secondary">Try the camera again</button><label class="c-btn c-btn--secondary c-scanner__photo">Use a photo<input type="file" accept="image/*" class="c-sr"></label></div>
    <div class="c-scanpane">
      <div class="c-scanpane__results">
        <div id="status" class="c-scan__pane-status" role="status"></div>
        <div class="c-scanner__failure" hidden>…</div>
        <div id="scanner_result" class="c-scanner__result"></div>
      </div>
    </div>
  </div>
  <div class="c-scan__bottom">
    <button type="button" id="scanner_count" class="c-btn c-btn--secondary c-scan__count" aria-label="12 added. Show this sitting's cards."><b>12</b><span>added</span></button>
    <button type="button" class="c-btn c-btn--primary c-scan__main">Capture</button>
    <button type="button" class="c-btn c-btn--secondary c-scan__torch" aria-label="Torch" aria-pressed="false" hidden><svg …></svg></button>
  </div>
  <dialog class="c-sheet" id="scanner_destination_sheet">…</dialog>
  <dialog class="c-sheet" id="scanner_list_sheet">…</dialog>
</main>
</body>
```

While a result shows the shell carries `c-scan--result`, the frozen canvas is shown, the pane holds the result and the main button is the secondary "Scan again". After an add the after-add line is shown and the status line's wrapper carries `hidden`:

```html
<div class="c-scan__line c-scan__line--status" hidden><p class="c-scan__line-text" id="scanner_status_text" role="status"></p></div>
<div class="c-scan__line c-scan__line--added"><p class="c-scan__line-text" id="scanner_added_text" role="status">Added Lightning Bolt MOM · 123, foil</p><div id="scanner_added_action" class="c-scan__added-action"><form class="c-scan__undo">…<button class="c-btn c-btn--ghost">Undo</button></form></div></div>
```

- **A focused page** (README, Mobile and Hotwire): no app header, tab bar, `#status` region or footer; the page places its own live regions and shows the flash itself. The `<body>` carries `c-shell--focused` beside `c-shell--untabbed`, so the shell (`c-scan`, as tall as the dynamic viewport) is exactly the screen and the document never scrolls. The top bar is 56px, the bottom bar 96px, and the stage is everything between. The bars grow by `env(safe-area-inset-top)` and `env(safe-area-inset-bottom)` and pad by the left and right insets. From 640px the shell is a centred column at most 480px wide on `surface-sunken`, and the scanner's sheets are as wide as the shell and under it. The heading is a visually hidden `<h1>`: "Scan a card", "Measure the scanner" in measurement mode (spec 082 decisions 6, 17, 18).
- **Controls** are 44px or more at every pointer: Back (44px), the destination, Done, the count (84 × 56px), the main button (64px high, taking the room that is left; the torch's too when there is none), the torch (56px, only where the camera reports one) and every button in the sheets. The sheets' selects are the exception: `Form` makes them 36px at a fine pointer and 44px at a coarse one (spec 072).
- **The top bar's destination** reads "Adding to" over the value, on one line ending in an ellipsis when too long; "Done" shows only while a sitting is open, and with none the destination takes its room. The sitting's top-bar parts are one element, `#scanner_sitting_bar` (`display: contents`), which every answer that changes the sitting replaces.
- **The camera** is the stage's feed (`c-scan__feed`, the video and the guide), shown once the camera is live. The guide is drawn as spec 080 drew it (`brand`, with an `on-brand` dashed line inside), its box set inline by the camera controller from the same computation the capture crops with (`liveGuideRect`, [scanner](../../architecture/scanner.md), Named constants): it sits in the stage's aiming area, below the lines, so one line of text never covers it. The photo path keeps the 3:4 view and the shipped guide.
- **The frozen frame** is a canvas (`c-scan__frozen`) over the feed, cropped as the video is (`object-fit: cover`): a capture draws its frame on it, the video keeps playing under it, and it goes when the result does. Nothing leaves the page.
- **State is in the markup, never in a script's memory.** `c-scan--result` on the shell follows whether the pane has something to show (`#scanner_result`, the pane's `#status` or the send failure not empty), set by `scan-shell` from the markup, so a Turbo Stream that empties them also returns the stage to the camera. The main button's label and style follow it and its `disabled` is the reading state. Parts are shown and hidden with the `hidden` attribute (`.c-scan [hidden]` and `.c-scanpane [hidden]` keep a hidden `c-btn` hidden).
- **Two lines over the camera**, 16px under the stage's top, on `surface-raised` with a `line-strong` border: the status line, centred, and the after-add line, which takes its place and spans the stage. A line's wrapper is shown while its text is not empty; the status line's is hidden while the after-add line or the pane shows, and its text is emptied then, so the next sentence is a change a screen reader announces. Each line's `role="status"` element stays in the document and its text is replaced; Undo (or a link) sits in the wrapper, outside the live region. A flash from another page, or the end of a sitting, is shown on the after-add line; an alert flash has the `warning` border (`c-scan__line--alert`).
- **Five live regions**, each keeping its element: the status line, the after-add line, the pane's `#status` and one in each sheet. A modal sheet makes the rest of the page inert, so each sheet holds its own, empties it when it closes (`sheets`), and an answer writes to the region that is in view. Which answer writes where is in [scanner](../../architecture/scanner.md), States and transitions.
- **A stage notice** (`c-scan__notice`) is centred on the stage, on `surface-raised` with a `line-strong` border, for the camera unavailable (the reason's sentence, "Try the camera again" except for the insecure context, and "Use a photo"), the engine failed ("The scanner couldn't load…", "Load the scanner again", no photo) and script off (`<noscript>`, with the notice's lines under the sentence). A broken measurement manifest shows one too. The catalog not loaded is no notice: its sentence (`catalog/not_loaded`) sits at the stage's foot, `space-4` from the edges (`c-scan__catalog`), in the alert style, with no dismissal.
- **The pane** (`c-scanpane`) fills the stage over the frozen frame when `c-scan--result` is set, sliding up in 200ms (none under reduced motion). #344 puts today's result in it unchanged, in an interim scrolling body, `c-scanpane__results`: it scrolls inside the pane with `overscroll-behavior: contain`, holds the pane's `#status`, the send failure (the name and collector line read, "Send again" or "Sign in") and `#scanner_result`, and is #345's to remove with the layout it replaces. The bars never move.
- **The sheets** are `Sheet`s opened by the `sheets` controller (`Sheet`, which describes the shared rules). They end with the content notice's foot. The destination sheet, "Adding to": its status region (`c-scan__sheet-status`, shown only while it holds a sentence), the sitting's form, then "Use a photo" with the photo hint (`c-scan__photo`: a `c-btn--secondary` label holding the file input, enabled whenever the engine is ready, and the hint "Using a photo? Take the whole card, upright, filling most of the photo as the live guide does, on a plain background."), then, with art matching on, the art line. The list sheet: the title is the sitting's heading ("This sitting: 12 cards, Near mint, in Blue binder"; `h2`, `tabindex="-1"`), then its status region, then the entries. Neither holds "Done": the top bar does. A form in a sheet answers with a Turbo Stream, and an answer replaces a sheet's body, never the `<dialog>`. Only "Details", Done and Back leave the page.
- **The sitting's form** (`form.c-form.c-scanner__place`, specs 040, 042) sits in the destination sheet and shows for every signed-in collector, before the first add too (spec 042 AC-1.1). A `fieldset.c-choices` (the choice page's fieldset: a flex column, no border) with the legend "This sitting's cards" holds, stacked, a `c-field` "Condition" (a native select, "Not specified" first, then the scale as "Near mint (NM)" … "Damaged (DMG)") and, while the account has a place or a zone, a `c-field` "Location" ("No location" first, then the places in the order of the locations page and the decks' zones as "Deck › Zone"); a `c-btn--secondary c-btn--sm` "Set" sits in its `c-form__actions`. It works without script as a form: "Set" submits it, a Turbo Stream redraws the form and the top bar, says "Cards you scan now: Near mint, in Blue binder." in the sheet's region (both choices for an account with locations, "condition not specified" and "no location" for what is unset, the condition alone for an account with none; spec 047 decision 1), and `sitting_focus_controller.js` puts focus back on "Set" (spec 047). The control uses existing classes plus one rule, `.c-scanner__place .c-choices { min-width: 0; }`: a fieldset is as wide as its widest child, so without it a long location name widens the sheet past 390px (spec 042 AC-7.1).
- **The sitting's list** (`#scanner_sitting`, `.c-scanner__sitting`) is the list sheet's body: a `c-list` of adds, newest first (name; set · number, finish or "—", the short condition label read from the entry's lot, "in <place>" while the lot is in a location, "Added … ago"; "Details" and "Undo"). Ten show; the rest sit in a `details.c-scanner__more` whose summary is "Show all N". An add whose lot was removed or merged away shows a `c-tag` "Changed in your collection" instead of its actions. A sitting with no entries says, in a `c-empty`, "Cards you scan now: Near mint, in Blue binder." naming only the parts that are set, and "Nothing added yet." with neither; once every add was undone it says "Everything added in this sitting was undone." (spec 042 decision 3).
- **Undo** (`form.c-scanner__undo`, in the list or on the after-add line) takes the add's copy back in place. From the list the sheet stays open, its region says "Removed 1 × … from your collection." and its title takes focus (`:focus` ring, not `:focus-visible`: Firefox gives programmatic focus none once the focused Undo is replaced); from the after-add line the line says the same and focus goes to the main button, as it does after an add, whose button the redraw removed (spec 047; spec 082 decision 15). "Details" opens the copy's Edit copy page and returns to the scanner. "Done" opens a `ConfirmPage` ("End this sitting?", the count kept, `c-btn--danger` "End sitting", whose form is non-Turbo), after which the scanner shows the summary on the after-add line ("Added N cards in this sitting." with "Open your collection" beside it).
- **Capture and add stay the collector's taps**, and one reading adds at most one copy. The frozen frame is drawn in the page from the captured frame: the picture never leaves the device and nothing new is sent.
- **Measurement mode** (development only) is the same page: one more top-bar button (`c-scan__run`, at most 40% of the bar, one line ending in an ellipsis) reads the next row's file, "3 of 40" and the framing, and opens the "Measured run" sheet, which holds the run panel (`scanner/measurements/_panel.html.erb`, built from `c-section`, `c-field` and `c-status__message`; `#measurement_panel [hidden]` keeps its hidden retry button and message hidden) and the framing buttons (`c-scan__framing`: "Full framing", "Shipped framing", `c-btn--secondary`, the chosen one disabled).
- **Motion**: the pane's slide takes 200ms and stops under reduced motion (README, Motion).

**Copy**

| Where | Words |
|---|---|
| Status line | "Loading the scanner…"; "Ready." with no camera; "Ready. Line the card up with the guide, then capture." while aiming; "Reading the card…" while a reading runs; "The card couldn't be read. Line it up with the guide and try again." |
| Top bar | "Adding to" over the destination: "Atraxa › Main · NM" (a place and a condition), "Blue binder" (a place alone), "No location · NM" (a condition alone), "No location". "Done". The back arrow is named "Back" |
| Count | "12 added" ("0 added", "1 added"); its accessible name is "12 added. Show this sitting's cards." |
| Main button | "Capture"; "Scan again" while a result shows. The torch is named "Torch" |
| Pane's region | "Done. What the scanner read and its candidates are showing." after a reading; today's failure, refusal and Other printings sentences |
| After-add line | "Added Lightning Bolt MOM · 123, foil"; "Added Lightning Bolt MOM · 123" for a printing with no finish; "Undo". It names no condition or place: the top bar shows them. After an Undo: "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection." After Done: "Added 12 cards in this sitting." and "Open your collection" |
| Sheets | "Adding to" (the destination); "This sitting: 12 cards" (the list); "Use a photo"; the photo hint above |
| Stage notices | The camera's reasons ("The live camera needs this page to be served over HTTPS. You can use a photo instead.", "The camera is blocked for this site. Allow it in your browser's settings, or use a photo instead.", "No camera was found. You can use a photo instead.", "The camera didn't start. Try again, or use a photo instead.", "The camera stopped. Try again, or use a photo instead."), "Try the camera again", "Use a photo"; "The scanner couldn't load, so neither the camera nor a photo can be read. Check your connection and load it again." with "Load the scanner again"; "The scanner needs JavaScript." with a link to the catalog search |

## What #345 builds in the pane (drawn by spec 080)

After a capture the frozen capture shrinks into a strip and the selection pane slides up over the rest of the stage, with its band, its swipe row of printings, one details block and one add button per finish. None of it is built: #344's pane holds the result partial below, and #345 replaces that with this, keeping "Scan again", the after-add line and the frozen frame. Previews: `ScannerConfidence.html`, `ScannerFlow.html`.

**Markup** — no view renders it yet. Inside the stage, with a result:

```html
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
```

- **The server renders one `c-scanpane__card` per image**, and every one but the centred card's carries `hidden`. The row's centred item carries `aria-current="true"`.
- **The capture strip** is 144px with a 124px picture, 96px with a 76px one when the shell (on a phone, the screen) is less than 720px high, and never taller: the name read is one line, ending in an ellipsis.
- **The pane** fills the rest of the stage. The `StatusBand` is its top edge and never scrolls. Under it the image row gives way on a short screen: the images are 288px high at most and 160px at least. When the pane still does not fit (below 640px of screen, or with a wrapped band or set name), its content scrolls inside it; the bars, the strip and the band never move.
- **The row** scrolls sideways with scroll snap and draws no scrollbar. It holds the candidates first (three at most, in ranked order), then the centred card's other printings in today's Other printings order; when the scanner is not sure of the card it holds the candidate cards (design decision 17). The centred image has a 2px `brand` outline, and the images carry no text.
- **A swipe is never the only way**: Previous and Next sit over the neighbours (44px, the one at the row's end disabled). The centred card is announced through the band, which follows it (design decision 14): on a printing other than the matched one it reads "Not the printing that was read". The band is one element whose form, icon and sentence are replaced in place (`StatusBand`).
- **One details block** describes the centred card, each fact on its own line: the name; the set's full name, free to wrap; the set code and number as a tag with the year, and the position at the end.
- **One add button per finish**, sharing the pane's width, 52px high, wrapping onto two lines when it must; a special finish's button carries the star in `foil`. A foil marker read off the card relabels its button and chooses nothing.
- **Motion**: the capture's shrink takes 200ms and stops under reduced motion (README, Motion). It starts from `--from` times the picture's size (4 unless the script sets it on `c-scan__capture`).

| Where | Words |
|---|---|
| Capture strip | "Read from the card", the name read, and the collector line read or "nothing read" |
| Band, success | "Matched by its collector line"; "Matched by its collector line, one digit corrected"; "Matched by its artwork" |
| Band, warning | "Printing not confirmed. Swipe to check." (alert); "Not sure of this card. Check it against your capture." (question mark); "Not the printing that was read" (alert, on a swipe away from the match) |
| Position | "1 of 14 printings"; "1 of 3 possible cards" |
| Add buttons | "Add nonfoil", "Add foil", "Add" and a finish's name in lower case ("Add etched"); "Add" alone for one finish or none; "Add foil · read from the card" when the foil marker was read. Accessible names stay today's: "Add Lightning Bolt MOM · 123 Foil" |
| Previous and Next | "Previous printing", "Next printing"; "Previous card", "Next card" while the row holds possible cards |

Still to place by #345: how many printings load at once.

## The result partial, until #345

What fills the pane today (spec 007; `scanners/_result.html.erb`, `_candidate`, `_add_buttons`): what the scanner read with its candidate printings, in `#scanner_result` inside the pane's interim body. #345 replaces it with the pane above.

```html
<div id="scanner_result" class="c-scanner__result">…<dl class="c-scanner__read">…</dl><div class="c-grid">…</div></div>
```

- Candidates are `ItemTile`s. Each says what it was matched by: a `c-badge--success` with a check, "Matched by its collector line" (or "…, one digit corrected"), or a `c-badge--warning` with the alert icon, "Printing not confirmed"; "Matched by its name" follows in muted text (spec 009 AC-2.1, AC-5.1).
- With art matching on (spec 011), a candidate the artwork decided carries a `c-badge--success` with a check, "Matched by its artwork", when the artwork belongs to that printing alone; when several printings share it, "Matched by its artwork" is a muted evidence line beside "Printing not confirmed". A weak art match adds the muted line "Artwork looks similar" and no badge. "What the scanner read" gains an Artwork row ("Matched", "Looks similar" or "No match") when the capture sent artworks. When the artwork overruled the name or the collector line, one `c-status__message` sentence above the candidates says so ("The artwork matches a different card from the one the name suggests. The artwork's match is first."). "Other printings" then lists the printings sharing the artwork first.
- Under each candidate, `.c-scanner__adds` holds one `button_to` per finish (`form.c-scanner__add`, `c-btn--secondary c-btn--sm`, at least 44px): the finish's name, or "Add" for a printing with one finish or none. The accessible name says exactly what is added: "Add Lightning Bolt MOM · 123 Foil". A foil marker read off the card relabels the Foil button "Foil · read from the card" and chooses nothing (AC-6.5).
- Each candidate has a ghost "Other printings" link into the `turbo-frame#scanner_printings` under the candidates. The frame lists the card's English printings (`.c-scanner__printings`, a `c-list`: set · number, set name and release date, then the add buttons), with what was read first. Twenty show; the rest sit in a `details.c-scanner__more` ("Show N more").
- "What the scanner read" (`dl.c-scanner__read`) lists the name text, the collector-line text, the parsed set, number and language, "Printing" and, only when artworks were sent, "Artwork". Nothing read, no candidate and "No card matches what was read. Line the card up with the guide and capture it again." are today's sentences, and "The card catalog isn't ready yet" is the catalog's.
- Problems in a reading (the text not sent) use the `StatusMessage` inline alert in the pane, with one next step as a button.
- The `.c-scanner__status` line is still used by the measurement replay page, and `.c-scanner__photo`'s 44px rule and `.c-scanner__failure`'s flex rule by the page above.
- On a coarse pointer the sitting's Condition and Location selects (`c-field`) and the measurement panel's "Card to capture" select are at least the touch floor (44px) high (`Form`, spec 072).
