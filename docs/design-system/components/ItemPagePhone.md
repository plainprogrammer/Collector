# ItemPagePhone

The same card page at phone width (390px). Same markup as `ItemPage`; only CSS changes below 640px:

- The header shows a back arrow instead of the logo (`c-appbar--detail`), like a native detail screen. Breadcrumbs hide, because the back arrow replaces them.
- There is no `+` in the header on a card page: the page's own `Add a copy` button stays visible, full width next to `Add to deck` and the "…" menu.
- The image sits centred at the top at about two-thirds width; it is no longer sticky.
- Stats become a 2 × 2 grid.
- Tables take their narrow layout: set, finish, condition, language and location fold into a second line under the printing.
- Decks and legality stack instead of sitting side by side.
- The bottom tab bar stays, with Collection current.
