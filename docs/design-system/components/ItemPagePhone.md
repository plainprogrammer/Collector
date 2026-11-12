# ItemPagePhone

The same card page at phone width (390px). Same markup as `ItemPage`; only CSS changes below 640px:

- The header shows a back arrow instead of the logo (`c-appbar--detail`), like a native detail screen. Breadcrumbs hide, because the back arrow replaces them.
- There is no `+` in the header on a card page: the page's own `Add a copy` button stays visible and is the flexible control of the one-line head row, beside `Add to deck` and the "…" menu. The three controls stay on one line at 360px: below 640px of the page container the `Add to deck` link (`c-item__adddeck`) shows its words without its icon and the gap between the controls is `var(--space-1)` (4px), because with the icon and the 8px gap they need 318 to 326px against 297px in a 360px frame with a scrollbar (spec 071 AC-1.5). The deck page's head shares `c-item__actions` and keeps its gap and icons.
- The image sits centred at the top at about two-thirds width; it is no longer sticky.
- The stats stay three across (`c-stats--three`), divided by left borders; the labels fit at 360px (spec 057 decision 7).
- Tables take their narrow layout: set, finish, condition, language and location fold into a second line under the printing.
- Printings rows keep the `SET · number` code (`.c-list .is-data`) on one line; only the set name beside it wraps. (Collector addition, `additions.css`.)
- In decks is the full-width table with Zone folded under the deck name and the format (`c-table__sub`); Format legality follows it (spec 057 decision 8).
- The section folds whenever it is narrower than 640px: the cell reads the deck's name, then the format and the zone ("Modern · Main"), Owned and Proxy stay, and the name wraps inside its cell (spec 073 AC-5.2).
- The bottom tab bar stays, with Collection current.
