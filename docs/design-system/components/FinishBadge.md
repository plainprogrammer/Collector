# FinishBadge

The one badge a tile or copy row shows for a special finish: "Foil", "Etched" or "Foil, etched".

**Markup** — the consumer provides the label; the icon is the filled star. On a tile it sits in `c-tile__flags`.

```html
<span class="c-tile__flags"><span class="c-badge c-badge--foil"><svg viewBox="0 0 24 24" fill="currentColor" stroke="none" aria-hidden="true">…star…</svg>Foil, etched</span></span>
```

- It is a `Badge` with the `foil` fill, so Badge's rules apply: gold marks what is special, and there is at most one per tile.
- When you own copies in more than one special finish, list them in one badge, the first word capitalised and the rest lower case ("Foil, etched"); never stack two gold badges.
- Nonfoil is the ordinary finish and gets no badge; in the copies table it is plain muted text.
- The collectible's extension decides which finishes are special (for Magic, foil and etched); the core only renders the label.
- Always the icon plus the word: the fill alone never carries the meaning.
