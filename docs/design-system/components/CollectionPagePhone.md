# CollectionPagePhone

The same collection screen at phone width (390px): compact header, two-column grid and the bottom tab bar.

It is exactly the `CollectionPage` markup; only CSS changes below 640px:

- The header keeps the logo mark (not the wordmark), an icon-only `+` for Add items and the avatar menu. The page head's buttons hide, because `+` replaces them.
- The top navigation hides and the bottom `TabBar` appears, fixed to the bottom and padded for the home indicator. The page adds matching bottom padding so the last row is never covered.
- The filter bar takes its narrow layout: full-width search, sideways-scrolling filters, and a "…" menu holding `Edit many`.
- The grid falls to two columns on its own.
- The viewport meta tag needs `viewport-fit=cover` for the safe-area padding to work on iOS.
