# ProgressMeter

How far through something is: a bar with its percentage, and the amounts in words where there are any (spec 015).

**Markup** — a `div.c-meter` holding a native `<progress>` with an `aria-label` naming what it measures, the percentage as text, and optionally the amounts.

```html
<div class="c-meter">
  <progress class="c-meter__bar" max="100" value="50" aria-label="Download"></progress>
  <span class="c-meter__value">50%</span>
  <span class="c-meter__text">39.3 MB of 78.6 MB</span>
</div>
```

- The bar is the browser's own `<progress>`, tinted with `accent-color: var(--brand)`, so assistive technology reads its value and label without scripting.
- The percentage is always written next to the bar; the bar is never the only signal.
- Without a total there is no bar and no percentage, only the amount ("1 MB").
- Numbers are exact and in mono: "7,976 of 31,904 artworks fingerprinted".
- The parts wrap, so on a phone the words drop under the bar.
