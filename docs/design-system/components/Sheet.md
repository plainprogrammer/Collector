# Sheet

A panel that opens from the bottom edge over a page, for content that would otherwise take the collector off a page whose state a navigation would lose (spec 080). It is a native `<dialog>` opened as a modal.

**Markup** — the consumer provides the title, the body and, on a one-screen focused page, the content notice's lines; the page's script opens it with `showModal()`.

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
- Three ways to close: the Close button (the cross at 20px and stroke 1.5 in a 44 × 44px button, named "Close", in a `form method="dialog"`, so it needs no script), Escape, and a tap on the backdrop. The first two are the element's own; the tap on the backdrop is closed by the page's script, which is #344's and not built yet.
- Fixed to the bottom edge, as wide as the screen, 85% of its height at most. The head (the title in `heading`, Close) stays in view and the body scrolls, without passing the scroll on to the page behind (`overscroll-behavior: contain`). The body's last padding clears a phone's home indicator (`env(safe-area-inset-bottom)`).
- `surface-raised` with a 1px `line-strong` top border and `radius-md` top corners; no shadow. The backdrop is `scrim`, its only use; a browser whose `::backdrop` does not inherit the tokens draws no dimming, and the top border still separates the sheet. It slides up in 200ms and closes at once; under reduced motion it does not slide (README, Motion).
- **It needs script to open.** Use it only on a page that already needs script, or give its opener a plain link to a page that holds the same content. It is the one exception to "Nothing needs JavaScript" (README, Mobile and Hotwire).
- **It never navigates** on a page that holds the camera: a visit would release it. A form in a sheet answers with a Turbo Stream.
- **The foot.** A focused page that is one screen high has no footer, so each of its sheets ends with the small print's lines (the `layouts/notice_lines` partial, whose lines always end with the licence line) in `c-sheet__foot`, the last thing in its body, in the footer's text style (12px/16px `ink-muted`, links in `brand`, underlined on hover, with the focus ring), under a 1px `line` rule; such a page has a sheet or keeps the footer, and a focused page that scrolls keeps the footer. So every sheet of such a page has a foot (spec 084 decision 12). No page does this yet: the scanner keeps its footer until #344 builds the one-screen page (spec 080 decision 13).
- Parts shown and hidden inside it use the `hidden` attribute; `.c-sheet [hidden]` keeps a hidden `c-btn` hidden. The layout is on `.c-sheet[open]`, so never set `display` on `.c-sheet` itself.
- First two uses, on the phone-first scanner (`Scanner`, built by #344; no view renders a sheet yet): the sitting's destination ("Adding to") and the sitting's list. Preview: `Sheet.html`, where the sheets are drawn with the `open` attribute and so have no backdrop.
- It names no collectible.
