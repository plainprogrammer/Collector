# StatusBand

A filled band across the top of a result that says, in an icon and a sentence, how sure the app is of it (spec 080). It is the one filled use of a status colour.

**Markup** — the consumer provides the form, the icon and the sentence. Shown with sentences of its first use (the scanner's selection pane, below).

```html
<p class="c-band c-band--success" role="status"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg><span>Matched by its collector line</span></p>
<p class="c-band c-band--warning" role="status"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4 2.5 20h19z"/><path d="M12 10v4M12 17h.01"/></svg><span>Printing not confirmed. Swipe to check.</span></p>
<p class="c-band c-band--warning" role="status"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01"/></svg><span>Not sure of this card. Check it against your capture.</span></p>
```

- Three forms: success with a check, warning with the alert triangle, warning with a question mark in a circle. The two warnings differ by icon and words, never by colour.
- The ground is `success` or `warning`; the sentence and the icon are `on-success` or `on-warning` (4.5:1 or better in both themes). It uses no other colour. `danger` has no band: something that went wrong is a `StatusMessage`.
- A band always carries an icon and a sentence. It holds no control and is never decoration.
- 14px/20px, weight 600, `space-4` at the sides. One line is 40px high with the line centred; a longer sentence wraps, the band grows (56px for two lines) and the icon stays on the first line. The icon is 16px at stroke 2 (the markup keeps `stroke-width="1.5"`; the band's CSS sets the 2, README Iconography).
- It is a live region (`role="status"`) and one element: when what it describes changes, its form class, icon and sentence are replaced in place, which is what gets announced. Never render a second band and reveal it with `hidden`.
- First use, built: the top edge of the scanner's selection pane (`Scanner`, `p#scanner_band`, spec 088, #345). Its sentences there: "Matched by its collector line", "Matched by its collector line, one digit corrected" and "Matched by its artwork" (success); "Printing not confirmed. Swipe to check." (warning, alert, when the scanner is sure of the card and not of its printing); "Not the printing that was read" (warning, alert, on every printing other than the matched one); "Not sure of this card. Check it against your capture." (warning, question mark). The pane's `selection` controller replaces the one band's form class, icon and sentence in place from the centred card, and follows the sentence with a visually hidden tail naming the card, so a swipe is announced; the band is empty and takes no space while no result shows (`.c-band:empty`). Preview: `StatusBand.html`.
- It names no collectible: the component is the coloured band, and each use writes its own sentences.
