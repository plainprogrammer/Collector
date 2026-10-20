# StageList

The steps of a long operation in order, each with its state in a word, and how far the current one is (spec 015).

**Markup** — an `ol.c-stages` with one `li.c-stages__stage` per step: its label, its state, and for the current step a `ProgressMeter` and a note. The current step carries `aria-current="step"`.

```html
<ol class="c-stages">
  <li class="c-stages__stage"><span class="c-stages__label">Download</span><span class="c-stages__state">Done</span></li>
  <li class="c-stages__stage" aria-current="step">
    <span class="c-stages__label">Sync cards</span><span class="c-stages__state">In progress</span>
    <div class="c-meter">…</div>
    <span class="c-stages__note">66,140 seen · 18 inserted · 312 updated</span>
  </li>
  <li class="c-stages__stage"><span class="c-stages__label">Retire missing cards</span><span class="c-stages__state">Waiting</span></li>
</ol>
```

- The state is always a word: "Done", "In progress", "Waiting", or "Stopped here" on the step where a run failed or was interrupted. Colour and weight only repeat it: the current step is `ink` and semibold, the others `ink-muted`.
- The label and the state share a row; the meter and the note take the full width under them.
- A step with nothing to measure is current in words alone, with no meter.
- Counts in the note are exact, in mono, separated by " · ".
