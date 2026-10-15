# VisitorHeader

The header a visitor sees on the open catalog's pages (search, a card page, all printings) when the instance's operator has opened the catalog to people who haven't signed in: the brand, one nav link, "Search", and a "Sign in" button. It is the signed-out form of `AppHeader`. The exported `AppHeader.md` describes only the signed-in form and isn't edited; where they differ for a visitor, this document holds.

**Markup**: the `layouts/appbar` partial renders it whenever no one is signed in (`collector?` is false); a page renders the partial as it does for a collector and provides nothing more. The logos come from `layouts/appbar_logos`, which both forms share.

```html
<header class="c-appbar" id="appbar">
  <a class="c-appbar__brand" href="/catalog/entries" aria-label="Collector search">
    <span class="c-appbar__wordmark"><img class="c-logo--light" src="collector-wordmark.svg" alt=""><img class="c-logo--dark" src="collector-wordmark-reversed.svg" alt=""></span>
    <span class="c-appbar__mark"><img class="c-logo--light" src="collector-mark.svg" alt=""><img class="c-logo--dark" src="collector-mark-reversed.svg" alt=""></span>
  </a>
  <nav class="c-appbar__nav" aria-label="Main"><a href="/catalog/entries" aria-current="page">Search</a></nav>
  <div class="c-appbar__actions"><a class="c-btn c-btn--secondary c-btn--sm" href="/session/new">Sign in</a></div>
</header>
```

- It shows only on the open catalog's pages, and only to a visitor. Every other page still asks a visitor to sign in, and the sign-in and sign-up pages keep the brand-only header of `AuthPage`.
- The brand links to search, not to `/`, because `/` is the collection and would ask a visitor to sign in. Its label says where it goes: "Collector search".
- The nav holds one link, "Search", always marked current: it is the only destination a visitor has.
- The actions hold one element, the "Sign in" link, styled as a small secondary button (`c-btn c-btn--secondary c-btn--sm`). There is no avatar, no account menu, no add button (`c-appbar__add`), no admin link and no "Sign out".
- Signing in from it returns the visitor to the catalog page they were on.
- Below 640px (viewport) the nav hides, as it does for everyone, leaving the mark and "Sign in".
- On the card page it takes the detail form, as for a collector: `c-appbar--detail`, and on phones the back arrow (`c-appbar__back`, back to search) takes the mark's place. "Sign in" stays.

## No tab bar, and the untabbed shell

A visitor gets no `TabBar`: a bar with one destination is not navigation, and the header already holds the way in. This is an exception to the design system README's "Phones get a compact header and a bottom tab bar", which isn't edited because it is exported.

Below 640px the shell keeps 80px at the foot of the page clear for the fixed tab bar: `c-main` carries it, or, on a footed shell (`c-shell--footed`, see `Footer`), the footer does. With no tab bar that is an empty band. So the layout adds `c-shell--untabbed` to the shell whenever a page renders no tab bar (`<body class="c-shell c-shell--footed c-shell--untabbed">`), and one block in `collector/additions.css`, headed `Untabbed shell (spec 023)`, gives the clearance up there:

- `c-main` keeps an ordinary `space-6` at its foot (plus the home indicator's inset); on a footed shell it keeps `space-4`, as under `c-shell--footed`.
- The footer keeps `space-4` at its foot, plus the home indicator's inset.

A visitor's catalog pages, sign-in and sign-up are untabbed. A page provides nothing: the class follows from whether the page rendered a tab bar. A collector's pages have the tab bar, and their clearance is unchanged.

## For a visitor

The catalog pages read the collector's account for their collection parts. A visitor has none, so those parts are left out, not shown empty:

- A tile is the plain `c-tile` (`ItemTile`). It has no "Not owned" marker and no dashed frame (`UnownedTile`), no quantity badge (`c-tile__qty`) and no add control (`TileAdd`). The tile sits in its `c-tilecell` alone.
- The card page has no "Owned" stat, no "Your copies" section and no "Add a copy" button.
- The printings list's count reads "N known", with no "· N owned". No row is muted (`is-unowned`), and no row has a quantity or an add control.
- The catalog-not-loaded notice says only that the catalog hasn't been loaded.
