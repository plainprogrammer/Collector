# ProxyTag

A dashed tag that marks a proxy without colour, so a stand-in is never mistaken for a copy you own.

**Markup** — the word "Proxy" and the number of proxies, in one inline element.

```html
<span class="c-proxy">Proxy <b>2</b></span>
```

- The tag reads without colour: the word and the dashed outline carry it (spec 060 decision 5).
- It is 20px high with `radius-sm` corners and a 1px dashed `ink-muted` border. The text is `ink`: "Proxy" in the sans family at weight 600, the number in mono at weight 400, both 12px (spec 060 FR-1).
- Keep the word with the number; never show the number alone inside the dashed box. The tag does not wrap (`white-space: nowrap`).
- It is never a fill and never takes a colour, and it is used for proxies and nothing else (spec 060 FR-1).
- Where it is used, and nowhere else on the deck pages (spec 060 decision 5, FR-1):
  - the Proxy column of a zone table on `DeckPage`;
  - the line under a card's name in a zone table on a phone, after `set · number`;
  - the Proxy cell of the Decks list on `DecksIndex`, and the line under a deck's name on a phone.
- A row with no proxies shows a muted dash (`<span class="is-muted">–</span>`) in the cell and no tag, and no tag is added to the phone's line (spec 060 AC-1.1).
- The card page's In decks table keeps its plain Proxy count and its dash, as spec 057 decision 8 wrote it; the tag is not used there (`ItemPage`).
- It is live since spec 068 (#254): the zone table's Proxy cell shows it with the row's proxies added up (one tag for a printing with proxies of two finishes), the phone's line under the name carries it after `set · number`, and the Decks list's Proxy cell and phone line show it for a deck that has proxies; the markup is built by the `proxy_tag` helper.
- A proxy never counts as owned: it is not in Owned, In decks or Free to use (the README's Decks section). A table that shows the tag shows the owned count in its own column, and Total is owned plus proxy.
