# ItemPagePhone

The same card page at phone width (390px). Same markup as `ItemPage`; only CSS changes below 640px:

- The header shows a back arrow instead of the logo (`c-appbar--detail`), like a native detail screen. Breadcrumbs hide, because the back arrow replaces them.
- There is no `+` in the header on a card page: the page's own `Add a copy` button stays visible, full width next to `Add to deck` and the "…" menu.
- The image sits centred at the top at about two-thirds width; it is no longer sticky.
- The stats stay three across (`c-stats--three`), divided by left borders; the labels fit at 360px (spec 057 decision 7).
- Tables take their narrow layout: set, finish, condition, language and location fold into a second line under the printing.
- Printings rows keep the `SET · number` code (`.c-list .is-data`) on one line; only the set name beside it wraps. (Collector addition, `additions.css`.)
- In decks is the full-width table with Zone folded under the deck name and the format (`c-table__sub`); Format legality follows it (spec 057 decision 8).
- The bottom tab bar stays, with Collection current.
