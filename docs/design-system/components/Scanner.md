# Scanner

The card scanner. Two parts: the one-screen page, built by #344 (spec 082) on spec 080's shell; and the selection pane a result opens in, drawn by spec 080 and built by #345 (spec 088), which replaced spec 009's result page.

## The one-screen scanner (built by #344, spec 082)

One screen that never scrolls: a top bar with the sitting's destination, the camera filling everything between the bars, and a bottom bar whose main button is always in view. The sitting's choices and its list are two sheets over the camera, so opening them never releases it. A result opens in the pane over the stage (the selection pane, below), and an add returns to the live camera with a line that confirms it and offers Undo. Previews: `ScannerFlow.html` (the five steps), `ScannerConfidence.html` (the pane's three states), `Sheet.html` (the two sheets).

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
    <div class="c-scan__strip">…</div>
    <div class="c-scanpane">
      <p id="scanner_band" class="c-band" role="status"></p>
      <div id="status" class="c-scan__pane-status" role="status"></div>
      <div class="c-scanner__failure" hidden>…</div>
      <div id="scanner_result" class="c-scanpane__result"></div>
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

While a result shows the shell carries `c-scan--result`, the frozen canvas, the strip and the pane are shown, the pane holds the selection and the main button is the secondary "Scan again". After an add the after-add line is shown and the status line's wrapper carries `hidden`:

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
- **Six live regions**, each keeping its element: the status line, the after-add line, the pane's `#status`, the band and one in each sheet. A modal sheet makes the rest of the page inert, so each sheet holds its own, empties it when it closes (`sheets`), and an answer writes to the region that is in view. Which answer writes where is in [scanner](../../architecture/scanner.md), States and transitions.
- **A stage notice** (`c-scan__notice`) is centred on the stage, on `surface-raised` with a `line-strong` border, for the camera unavailable (the reason's sentence, "Try the camera again" except for the insecure context, and "Use a photo"), the engine failed ("The scanner couldn't load…", "Load the scanner again", no photo) and script off (`<noscript>`, with the notice's lines under the sentence). A broken measurement manifest shows one too. The catalog not loaded is no notice: its sentence (`catalog/not_loaded`) sits at the stage's foot, `space-4` from the edges (`c-scan__catalog`), in the alert style, with no dismissal.
- **The pane** (`c-scanpane`) fills the stage over the frozen frame when `c-scan--result` is set, sliding up in 200ms (none under reduced motion). It holds, from the top, the band, the pane's `#status`, the send failure ("Send again" or "Sign in"; the name and collector line read are in the strip) and `#scanner_result`, which holds the selection (below). The bars never move.
- **The sheets** are `Sheet`s opened by the `sheets` controller (`Sheet`, which describes the shared rules). They end with the content notice's foot. The destination sheet, "Adding to": its status region (`c-scan__sheet-status`, shown only while it holds a sentence), the sitting's form, then "Use a photo" with the photo hint (`c-scan__photo`: a `c-btn--secondary` label holding the file input, enabled whenever the engine is ready, and the hint "Using a photo? Take the whole card, upright, filling most of the photo as the live guide does, on a plain background."), then, with art matching on, the art line. The list sheet: the title is the sitting's heading ("This sitting: 12 cards, Near mint, in Blue binder"; `h2`, `tabindex="-1"`), then its status region, then the entries. Neither holds "Done": the top bar does. A form in a sheet answers with a Turbo Stream, and an answer replaces a sheet's body, never the `<dialog>`. Only "Details", Done and Back leave the page.
- **The sitting's form** (`form.c-form.c-scanner__place`, specs 040, 042) sits in the destination sheet and shows for every signed-in collector, before the first add too (spec 042 AC-1.1). A `fieldset.c-choices` (the choice page's fieldset: a flex column, no border) with the legend "This sitting's cards" holds, stacked, a `c-field` "Condition" (a native select, "Not specified" first, then the scale as "Near mint (NM)" … "Damaged (DMG)") and, while the account has a place or a zone, a `c-field` "Location" ("No location" first, then the places in the order of the locations page and the decks' zones as "Deck › Zone"); a `c-btn--secondary c-btn--sm` "Set" sits in its `c-form__actions`. It works without script as a form: "Set" submits it, a Turbo Stream redraws the form and the top bar, says "Cards you scan now: Near mint, in Blue binder." in the sheet's region (both choices for an account with locations, "condition not specified" and "no location" for what is unset, the condition alone for an account with none; spec 047 decision 1), and `sitting_focus_controller.js` puts focus back on "Set" (spec 047). The control uses existing classes plus one rule, `.c-scanner__place .c-choices { min-width: 0; }`: a fieldset is as wide as its widest child, so without it a long location name widens the sheet past 390px (spec 042 AC-7.1).
- **The sitting's list** (`#scanner_sitting`, `.c-scanner__sitting`) is the list sheet's body: a `c-list` of adds, newest first (name; set · number, finish or "—", the short condition label read from the entry's lot, "in <place>" while the lot is in a location, "Added … ago"; "Details" and "Undo"). Ten show; the rest sit in a `details.c-scanner__more` whose summary is "Show all N". An add whose lot was removed or merged away shows a `c-tag` "Changed in your collection" instead of its actions. A sitting with no entries says, in a `c-empty`, "Cards you scan now: Near mint, in Blue binder." naming only the parts that are set, and "Nothing added yet." with neither; once every add was undone it says "Everything added in this sitting was undone." (spec 042 decision 3).
- **Undo** (`form.c-scan__undo`, in the list or on the after-add line) takes the add's copy back in place. From the list the sheet stays open, its region says "Removed 1 × … from your collection." and its title takes focus (`:focus` ring, not `:focus-visible`: Firefox gives programmatic focus none once the focused Undo is replaced); from the after-add line the line says the same and focus goes to the main button, as it does after an add, whose button the redraw removed (spec 047; spec 082 decision 15). "Details" opens the copy's Edit copy page and returns to the scanner. "Done" opens a `ConfirmPage` ("End this sitting?", the count kept, `c-btn--danger` "End sitting", whose form is non-Turbo), after which the scanner shows the summary on the after-add line ("Added N cards in this sitting." with "Open your collection" beside it).
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
| Pane's region | "Done." and the band's sentence (visually hidden) after a reading; a refusal's, a failure's and a refused add's sentences as alerts |
| After-add line | "Added Lightning Bolt MOM · 123, foil"; "Added Lightning Bolt MOM · 123" for a printing with no finish; "Undo". It names no condition or place: the top bar shows them. After an Undo: "Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection." After Done: "Added 12 cards in this sitting." and "Open your collection" |
| Sheets | "Adding to" (the destination); "This sitting: 12 cards" (the list); "Use a photo"; the photo hint above |
| Stage notices | The camera's reasons ("The live camera needs this page to be served over HTTPS. You can use a photo instead.", "The camera is blocked for this site. Allow it in your browser's settings, or use a photo instead.", "No camera was found. You can use a photo instead.", "The camera didn't start. Try again, or use a photo instead.", "The camera stopped. Try again, or use a photo instead."), "Try the camera again", "Use a photo"; "The scanner couldn't load, so neither the camera nor a photo can be read. Check your connection and load it again." with "Load the scanner again"; "The scanner needs JavaScript." with a link to the catalog search |

## The selection pane (built by #345, spec 088)

After a capture the frozen capture shrinks into a strip, with what was read from it beside it, and the pane slides up over the rest of the stage with its band, a swipe row of card images, one details block and one add button per finish. A confident match is added with one tap on a finish; a wrong printing is a swipe or a Next away; the band says in an icon and words when the scanner is less sure. Previews: `ScannerConfidence.html`, `ScannerFlow.html`. Measurement mode still records the parsed fields, outcomes, tier and overrule of a reading, which the page no longer shows.

**Markup** — `scanners/_scanner.html.erb` (the strip and the pane's frame) and `scanners/_selection.html.erb`, `_panel.html.erb`, `_item.html.erb`, `_add_buttons.html.erb` (the selection, rendered by the reading's answer and by `GET /scanner/printings`). Inside the stage, with a result the scanner is sure of; the controllers' `data-*` attributes and the icons' paths are left out:

```html
<div class="c-scan__strip">
  <canvas class="c-scan__capture" aria-hidden="true"></canvas>
  <div class="c-scan__read"><p class="c-scan__read-label">Read from the card</p><p class="c-scan__read-name">Lightning Bolt</p><p class="c-scan__read-line">R 0123 MOM • EN</p></div>
</div>
<div class="c-scanpane">
  <p id="scanner_band" class="c-band c-band--success" role="status" aria-live="polite"><svg …check…></svg><span>Matched by its collector line<span class="c-sr">. Printing 1 of 14: Lightning Bolt, March of the Machine, MOM · 123.</span></span></p>
  <div id="status" class="c-scan__pane-status" role="status" aria-live="polite"><p class="c-sr">Done. Matched by its collector line. Printing 1 of 14: …</p></div>
  <div class="c-scanner__failure" hidden>…</div>
  <div id="scanner_result" class="c-scanpane__result">
    <turbo-frame id="scanner_selection" class="c-scanpane__body">
      <div class="c-scanpane__rowwrap" role="group" aria-label="Printings">
        <ul class="c-scanpane__row" tabindex="0">
          <li class="c-scanpane__item" aria-current="true"><img src="…" alt="Lightning Bolt, March of the Machine, MOM · 123" loading="lazy" width="206" height="288"></li>
          <li class="c-scanpane__item"><img src="…" alt="…"></li>
          <li class="c-scanpane__item c-scanpane__item--more"><div class="c-scanpane__missing"><strong>10 more printings</strong></div></li>
        </ul>
        <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--prev" aria-label="Previous printing" disabled><svg …></svg></button>
        <button type="button" class="c-btn c-btn--secondary c-scanpane__nav c-scanpane__nav--next" aria-label="Next printing"><svg …></svg></button>
      </div>
      <div class="c-scanpane__card">
        <template data-band="c-band--success"><svg …check…></svg><span>Matched by its collector line<span class="c-sr">. Printing 1 of 14: …</span></span></template>
        <div class="c-scanpane__details">
          <h2 class="c-scanpane__name">Lightning Bolt</h2>
          <p class="c-scanpane__set">March of the Machine</p>
          <p class="c-scanpane__meta"><span class="c-tag">MOM · 123</span><span>2023</span><span class="c-scanpane__position">1 of 14 printings</span></p>
        </div>
        <div class="c-scanpane__adds">
          <form class="c-scanpane__add">…<button class="c-btn c-btn--secondary" aria-label="Add Lightning Bolt MOM · 123 Nonfoil">Add nonfoil</button></form>
          <form class="c-scanpane__add">…<button class="c-btn c-btn--secondary" aria-label="Add Lightning Bolt MOM · 123 Foil"><svg …star… aria-hidden="true"></svg>Add foil</button></form>
        </div>
      </div>
      <div class="c-scanpane__card" hidden>…</div>
      <div class="c-scanpane__card" hidden><template data-band="…">…</template><div class="c-scanpane__details"><h2 class="c-scanpane__name">Lightning Bolt</h2><p class="c-scanpane__set">10 more printings</p><p class="c-scanpane__meta"></p></div><div class="c-scanpane__adds"><div class="c-scanpane__add"><a class="c-btn c-btn--secondary" href="/scanner/printings?…">Show 20 more</a></div></div></div>
    </turbo-frame>
  </div>
</div>
```

Three states of the band, one element whose form, icon and sentence `selection` replaces in place from the centred card's `<template data-band>`; it is empty while no result shows. When the scanner is not sure of the card the row holds the possible cards, `aria-label="Possible cards"`, the position reads "1 of 3 possible cards", Previous and Next are named for cards, and each panel's details line ends with a ghost link, `a.c-btn.c-btn--ghost.c-btn--sm` "All printings" (the line is `c-scanpane__meta c-scanpane__meta--cards`, with no year):

```html
<p id="scanner_band" class="c-band c-band--warning" role="status"><svg …question…></svg><span>Not sure of this card. Check it against your capture.<span class="c-sr">. Card 1 of 3: …</span></span></p>
<p class="c-scanpane__meta c-scanpane__meta--cards"><span class="c-tag">MOM · 123</span><span class="c-scanpane__position">1 of 3 possible cards</span><a class="c-btn c-btn--ghost c-btn--sm" href="/scanner/printings?…">All printings</a></p>
```

- **The strip** (`c-scan__strip`, a sibling of the pane in the stage) shows with `c-scan--result`. Its canvas holds the capture's card box, not the whole frame; the page writes the name and the collector line read with `textContent`, one line each ending in an ellipsis, "nothing read" for a blank text. It is 144px with a 124px picture, 96px with a 76px one when the shell (on a phone, the screen) is less than 720px high, and 64px with a 52px one when it is less than 600px high (spec 088 decision 13; spec 080 decision 7 and AC-4.7 stopped at 96px). In the 64px strip the label "Read from the card" is visually hidden (the technique of `.c-sr`, so it stays in the document for assistive technology) and the name and the line, 44px, are centred in it; at 144px and 96px the label shows (spec 088 decision 13, 1.0.3). A send failure keeps it.
- **The pane** fills the rest of the stage. The band is its top edge and never scrolls; under it the image row gives way on a short screen: the images are 288px high at most and 96px at least (`--scan-image-min` on `.c-scanpane`; spec 080's floor was 160px, superseded for this number by spec 088 decision 13). At 390 × 844, 360 × 640 and 360 × 560 a confident match shows the band, Previous and Next, the details and the add buttons with no scrolling (images 288, 160 and 112px, the strip 144, 96 and 64px). With a two-line band and the 44px "All printings" line (a not-sure result) the images are 278 or 288px at 390 × 844 and about 122px at 360 × 640, and at 360 × 560 they are at the 96px floor and the body scrolls inside the pane by about 6px; a wrapped set name adds 22px a line. The bars, the strip and the band never move. The pane's body is the selection frame, `.c-scanpane__body`, a grid of the image row and the centred card's panel.
- **The row** scrolls sideways with scroll snap and draws no scrollbar; the server renders it, up to 20 printings (a printings row, with a "‹n› more printings" item last, up to 200 in all) or the possible cards (three at most). The centred image has a 2px `brand` outline; an image with no picture shows the name and set number as text on `surface-sunken` (`c-scanpane__missing`). The row is a focusable list in a `role="group"` and takes Left and Right.
- **Previous and Next** sit over the neighbours, 44px, always shown, the one at the row's end disabled. They do what a swipe does; focus moves to the other when the focused one becomes disabled. The centred card is announced through the band: its sentence is followed by a visually hidden tail ("Printing 2 of 14: Lightning Bolt, Double Masters 2022, 2X2 · 117."), and on every printing but the matched one it reads "Not the printing that was read". The band is one element (`StatusBand`).
- **One details block** describes the centred card, each fact on its own line: the name; the set's full name, free to wrap; the set code and number as a tag with the year (a printings row, when the date is known) and the position at the end. Only the centred card's panel is shown, the others carry `hidden`.
- **One add button per finish**, sharing the pane's width, 52px high, wrapping onto two lines when it must; a special finish's button carries the star in `foil`. A foil marker read off the card relabels its button "Add foil · read from the card" and chooses nothing. The forms are `form.c-scanpane__add` and target the page (`data-turbo-frame="_top"`).
- **Where the other outcomes show**: "Nothing could be read" and "No card matches what was read" are the status line's sentences, with no pane and no strip; "The card catalog isn't ready yet" and a refused reading show as an alert in the pane's `#status` under the strip; a send failure shows the strip, the failure block and its alert.
- **Motion**: the capture's shrink and the pane's rise take 200ms and stop under reduced motion (README, Motion). The shrink starts from `--from` times the picture's size (4 unless the script sets it on `c-scan__capture`); a row scrolls smoothly by a step, at once under reduced motion.

| Where | Words |
|---|---|
| Capture strip | "Read from the card", the name read, and the collector line read or "nothing read" |
| Band, success | "Matched by its collector line"; "Matched by its collector line, one digit corrected"; "Matched by its artwork" |
| Band, warning | "Printing not confirmed. Swipe to check." (alert); "Not sure of this card. Check it against your capture." (question mark); "Not the printing that was read" (alert, on every printing but the matched one) |
| Position | "1 of 14 printings"; "1 of 1 printing"; "1 of 3 possible cards" |
| Add buttons | "Add nonfoil", "Add foil", "Add" and a finish's name in lower case ("Add etched"); "Add" alone for one finish or none; "Add foil · read from the card" when the foil marker was read. Accessible names stay "Add Lightning Bolt MOM · 123 Foil" |
| Previous and Next | "Previous printing", "Next printing"; "Previous card", "Next card" while the row holds possible cards |
| More | "All printings" (a possible card's link); "‹n› more printings" (the row's last item, and its set line) and "Show 20 more" |
| Pane's region | "Done." and the band's sentence with its tail, visually hidden; the other outcomes' sentences above |

- The `.c-scanner__status` line is still used by the measurement replay page, and `.c-scanner__photo`'s 44px rule and `.c-scanner__failure`'s flex rule by the page above. The older `c-scanner__*` rules of spec 009's result page (`__candidate`, `__adds`, `__add`, `__evidence`, `__printings`, `__result`, `__read`, `__mono`) were removed by spec 088.
- On a coarse pointer the sitting's Condition and Location selects (`c-field`) and the measurement panel's "Card to capture" select are at least the touch floor (44px) high (`Form`, spec 072).
