# Sheet

A panel that opens from the bottom edge over a page, for content that would otherwise take the collector off a page whose state a navigation would lose (spec 080). It is a native `<dialog>` opened as a modal.

**Markup** — the consumer provides the title, the body and, on a one-screen focused page, the content notice's lines; the page's script opens it with `showModal()`. On the scanner that is the `sheets` controller (spec 082).

```html
<dialog class="c-sheet" id="destination" aria-labelledby="destination_title">
  <div class="c-sheet__head">
    <h2 class="c-sheet__title" id="destination_title">Adding to</h2>
    <form method="dialog" class="c-sheet__dismiss"><button class="c-btn c-btn--ghost c-sheet__close" aria-label="Close"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"/></svg></button></form>
  </div>
  <div class="c-sheet__body">
    …
    <div class="c-sheet__foot"><p>…the content notice's first line…</p><p>…its second…</p></div>
  </div>
</dialog>
```

- Opened as a modal (`showModal()`): focus moves into the sheet on opening, and on closing it returns to the control that opened it. Both are the element's own.
- Three ways to close: the Close button (the cross at 20px and stroke 1.5 in a 44 × 44px button, named "Close", in a `form method="dialog"`, so it needs no script), Escape, and a tap on the backdrop. The first two are the element's own; the tap on the backdrop is the page's script's: the scanner's `sheets` controller closes the dialog when a click's target is the dialog itself (the sheet's children cover the rest), since a native dialog does not close on a backdrop click (spec 082 decision 9).
- Fixed to the bottom edge, as wide as the screen, 85% of its height at most. The head (the title in `heading`, Close) stays in view and the body scrolls, without passing the scroll on to the page behind (`overscroll-behavior: contain`). The body's last padding clears a phone's home indicator (`env(safe-area-inset-bottom)`).
- `surface-raised` with a 1px `line-strong` top border and `radius-md` top corners; no shadow. The backdrop is `scrim`, its only use; a browser whose `::backdrop` does not inherit the tokens draws no dimming, and the top border still separates the sheet. It slides up in 200ms and closes at once; under reduced motion it does not slide (README, Motion).
- **It needs script to open.** Use it only on a page that already needs script, or give its opener a plain link to a page that holds the same content. It is the one exception to "Nothing needs JavaScript" (README, Mobile and Hotwire).
- **It never navigates** on a page that holds the camera: a visit would release it. A form in a sheet answers with a Turbo Stream, and the answer replaces the sheet's body or title, never the `<dialog>`, so an open sheet stays open (spec 082 decision 15).
- **The foot.** A focused page that is one screen high has no footer, so each of its sheets ends with the content notice's lines in `c-sheet__foot`, the last thing in its body, in the footer's text style (12px/16px `ink-muted`, links in `brand`, underlined on hover, with the focus ring), under a 1px `line` rule; such a page has a sheet or keeps the footer, and a focused page that scrolls keeps the footer. A source that supplies no notice gives no foot in the sheet's own right, but a sheet on the scanner always has one: the foot is `layouts/_notice_foot`, the lines are the footer's own partial `layouts/_notice_lines`, and spec 084 adds the licence line to them (spec 082 decision 16). The scanner is the first page to do this (spec 080 decision 13; spec 082).
- **A live region per sheet.** While a modal sheet is open the rest of the page is inert, and a live region outside it is not announced, so each sheet holds its own `role="status"` element at the top of its body (`c-scan__sheet-status`, shown only while it holds a sentence) and empties it when the sheet closes (spec 082 decision 10).
- Parts shown and hidden inside it use the `hidden` attribute; `.c-sheet [hidden]` keeps a hidden `c-btn` hidden. The layout is on `.c-sheet[open]`, so never set `display` on `.c-sheet` itself.
- Uses, on the phone-first scanner (`Scanner`, spec 082): the sitting's destination ("Adding to", `#scanner_destination_sheet`), the sitting's list (`#scanner_list_sheet`) and, in development's measurement mode, the "Measured run" sheet. On a screen 640px wide or more the scanner's sheets are as wide as the shell (at most 480px) and centred under it, by a rule scoped to the scanner page; the sheet's own rule is unchanged. Preview: `Sheet.html`, where the sheets are drawn with the `open` attribute and so have no backdrop.
- It names no collectible.
