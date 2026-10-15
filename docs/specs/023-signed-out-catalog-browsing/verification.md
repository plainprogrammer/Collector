# Verification: Browse the Catalog Without Signing In (spec 023)

**Spec:** [spec.md](spec.md) v1.2.1 · **Plan:** [plan.md](plan.md) (with its "Amendments from the Fable plan review") · **Branch:** `023-signed-out-catalog-browsing` · **Issue:** [#59](https://github.com/plainprogrammer/Collector/issues/59)

## Red runs

Before the work the suite stood at 1413 examples, 0 failures, 1 pending. Each phase's examples were seen to fail before its code, or were guards that passed before and after; where an example was written against code that already worked, it was proved by breaking the code once.

**Phase 1, the setting (`3f9d593`).** `spec/models/catalog_spec.rb`, before `Catalog.public_in?` and `Catalog.public?` existed:

```text
catalog_spec  11 examples, 5 failures   (the five new examples: Catalog didn't respond to public_in? or public?)
```

**Phase 2, deployment files (`2c8355f`).** `spec/image_publishing_spec.rb`, before `compose.yaml` and `config/deploy.yml` named the variable:

```text
image_publishing_spec  29 examples, 3 failures   (the Compose key list, the Compose pass-through, the Kamal commented-out line)
```

**Phase 3a, `prefetch?` lifted to `ApplicationController` (`95af0ba`).** A refactor; its guard is `spec/requests/collection_views_spec.rb`'s prefetch examples (spec 006 AC-1.10, lines 60 and 68), green before and after. Broken once to prove the guard: with the prefetch header list emptied,

```text
collection_views_spec  9 examples, 2 failures   ("never saves a view from a prefetch", "never saves a view from a Firefox or legacy prefetch")
```

**Phase 3b, collection parts decided with `collector?` (`d075e70`).** Behaviour-neutral (every page rendering these views was still behind sign-in); guarded by the existing catalog request and system specs and by the quick add's full-lot example, which gained AC-6.2's expectations. Broken once: with `collector?` forced false, `spec/requests/catalog/quick_adds_spec.rb`, "answers an over-cap add without scripting with the card page at 422", failed.

**Phase 3c, the catalog opened to visitors (`2ef6ec6`).** `spec/requests/catalog/visitors_spec.rb` as first written, before `OpenCatalog`:

```text
visitors_spec  23 examples, 14 failures
  visitor pages     expected the response to have status code :ok (200) but it was :found (302)   (AC-3.1–3.4, 4.1, 4.2, 4.4, 4.5, 2.4 on, 5.2/5.3, 5.4, prefetch meta, prefetch return path)
  AC-3.7            expected redirect to /collection, got the card page   (sign-up didn't clear the return path; the next sign-in landed on the card)
```

The nine guards, green before and after: the setting off (AC-2.1; AC-2.4 off), no users with the setting off and on (AC-2.3, two examples), a collector's pages identical with the setting off and on (AC-2.2, amendment 2), the write actions still closed (AC-4.3), no return path for a collector (AC-3.5), a collector's collection parts (AC-6.1), and "returns a visitor to the catalog page they were on when they sign in (AC-3.5)". The commit message names eight of them by group; the ninth is identified by reading: before `OpenCatalog`, the refused card page already stored the return path, so that example passed for the old reason, and now holds for the new one (its prefetch companion was red).

**Phase 4, the visitor shell (`eb219ac`).** Five new examples in `visitors_spec.rb` and one in `spec/design_system_files_spec.rb`, before the header, the class and the block:

```text
visitors_spec            4 failures   the untabbed class for a visitor and not a collector (AC-5.7); the nav and actions (AC-5.1);
                                      the sign-in and sign-up pages, setting off and on (untabbed, and no prefetch meta, which Phase 3's layout had put there)
design_system_files_spec the untabbed shell block: expected 1, got 0
```

The fifth, "keeps the detail header, with its back link to search, on a visitor's card page (decision 3)", was green before (Phase 3b's interim header kept the detail form) and is a guard.

**Phase 5, the browser (`687dc91`, screenshots `1c28c71`).** `spec/system/visitor_catalog_spec.rb` was written against working code, so each example that can only be red by breaking the code was proved that way (headless Firefox), then the files were restored:

```text
"Untabbed shell (spec 023)" block deleted from additions.css:
  footed example     /catalog/entries?q=bolt: the footer keeps the tab bar's clearance   (and the same for /session/new)
  unfooted example   c-main padding-bottom: expected < 80, got 80.0
content_for :head line removed from catalog/_visitor_head:
  prefetch example   expected not to find css "#prefetched", found 1 match   (after #settled)
  sign-in flow       landed on /catalog/entries?q=bolt&set= instead of the card page
```

So the clearance rule and the prefetch meta are each caught by an example, and the examples pass with them in place.

After Phase 5 the full suite: **1455 examples, 0 failures, 1 pending** (seed 133). The pending example is `spec/system/art_agreement_spec.rb`, which needs the art spike's cache (`COLLECTOR_ART_AGREEMENT`), as on `main`.

**Phase 6, documents (`8bf7a5d`).** Verified by reading (below).

**Review follow-up (spec-alignment review).** Two examples were added for code that already worked: the kept query string (amendment 7) and the sign-up page's clearance (AC-5.7). Each was proved by breaking the code once, then the file was restored and `git diff` showed it clean:

```text
OpenCatalog#remember_visited_page storing request.path instead of request.fullpath:
  visitors_spec:259   Expected response to be a redirect to <http://www.example.com/catalog/entries/bolt-a?from=collection>
                      but was a redirect to <http://www.example.com/catalog/entries/bolt-a>.
"Untabbed shell (spec 023)" block deleted from additions.css:
  visitor_catalog_spec:66   Got 3 failures: "/catalog/entries?q=bolt: the footer keeps the tab bar's clearance",
                            "/session/new: …" and "/registration/new: the footer keeps the tab bar's clearance"
```

After it the full suite: **1456 examples, 0 failures, 1 pending** (seed 12618), the same pending example.

## Acceptance criteria

`visitors_spec` is `spec/requests/catalog/visitors_spec.rb`; `visitor_catalog_spec` is `spec/system/visitor_catalog_spec.rb`.

| Criterion | Held by |
|---|---|
| AC-1.1 | `spec/models/catalog_spec.rb:40` "is on for 1, true, yes and on, in any case and with surrounding spaces" (`1`, `true`, `yes`, `on`, `TRUE`, ` On `, ` TRUE `); `:45` "is off when unset, empty or anything else" (unset, empty, `0`, `false`, `maybe`) |
| AC-1.2 | `spec/models/catalog_spec.rb:52` "is off in tests unless an example turns it on", `:56` "reads the app's configuration", `:60` "is off when the configuration is anything but true" (the string `"true"` is off). The initializer half by reading: `config/initializers/public_catalog.rb` sets `config.x.public_catalog = !Rails.env.test? && Catalog.public_in?(ENV)` in `after_initialize`, with `art_matching.rb`'s kind of comment (why after initialize, why tests never read the environment; amendment 9); `config/application.rb:58` defaults it to `false` |
| AC-1.3 | `spec/image_publishing_spec.rb:76` "keeps the rest of the service unchanged (FR-4)" (the `contain_exactly` key list gains `COLLECTOR_PUBLIC_CATALOG`); `:89` "passes the open catalog setting to the container, empty unless it is set (spec 023 AC-1.3)"; `:109` "offers the open catalog as a commented-out setting (spec 023 AC-1.3)". The Compose header comment by reading: `compose.yaml:8` names it ("`true` opens catalog search and card pages to visitors who aren't signed in; default off"); `config/deploy.yml:55` says what it does above the commented-out line |
| AC-1.4 | By reading: README's Compose table row (`COLLECTOR_PUBLIC_CATALOG`, not required, default off, "`true` lets people who aren't signed in search the catalog and open card pages") and its "Open catalog" section: what opens (search, card pages, all printings), what stays private (collections, scanner, admin pages, every add or change; no owned counts, markers, add buttons or anyone's collection), that a hosted instance turns it on (research 016, ruling 27), how to set it for Compose and Kamal, restart after changing it, and rate-limit at the reverse proxy since every search runs a name match |
| AC-2.1 | `visitors_spec:47` "sends a visitor to sign in, and back to the page they asked for afterwards (AC-2.1)" (all three pages) |
| AC-2.2 | `visitors_spec:114` "renders a collector's catalog pages identically with the setting off and on (AC-2.2)" (amendment 2: bodies equal after masking the CSRF token); `:104` sign-in and sign-up unchanged in their prefetch meta with the setting off; the existing catalog request and system specs pass unchanged in the full run. The one existing spec edited, `quick_adds_spec.rb`, only gained AC-6.2's two expectations |
| AC-2.3 | `visitors_spec:75` "sends anyone to sign-up with the setting off (AC-2.3)", `:82` "… with the setting on (AC-2.3)" |
| AC-2.4 | `visitors_spec:58` "sends a visitor whose session no longer exists to sign in (AC-2.4)" (off); `:301` "gives a visitor whose session no longer exists the visitor's page (AC-2.4)" (on: 200, no `.c-avatar`) |
| AC-3.1 | `visitors_spec:141` "shows a visitor the same search results, set filter, freshness line and pager as a collector (AC-3.1)" (with and without a query, a set filter, page 2; compared part by part with a collector's) |
| AC-3.2 | `visitors_spec:157` "shows a visitor the card page (AC-3.2)" (image, `h1`, details, rules text, legality, two printings, "View on Scryfall") |
| AC-3.3 | `visitors_spec:170` "shows a visitor all printings, with and without a set, with its pager (AC-3.3)" |
| AC-3.4 | `visitors_spec:184` "answers 404 for a missing card and for an identity with no searchable printing (AC-3.4)" |
| AC-3.5 | `visitors_spec:251` "returns a visitor to the catalog page they were on when they sign in (AC-3.5)"; `:267` "doesn't let a prefetch change where a visitor returns to (AC-3.5, decision 4)" (`X-Sec-Purpose` and `Sec-Purpose`); `:259` "returns a visitor to the card page with its query string when they sign in (AC-3.5, plan amendment 7)" (`?from=collection` kept); `:278` "writes no return path for a collector's catalog request (AC-3.5)"; through Turbo from the header: `visitor_catalog_spec:122` "comes back to the card after signing in from it (decision 4)" (hover, click, Sign in, back on the card) |
| AC-3.6 | `visitor_catalog_spec:42` "searches by name and opens a card without signing in (AC-3.6)" (search "bolt", open the result, no `.c-avatar`, no "Add a copy", the footer's notice and "Sign in" on both pages) |
| AC-3.7 | `visitors_spec:288` "lands a visitor who signs up in their collection, then and after signing in again (AC-3.7)" |
| AC-4.1 | `visitors_spec:194` "shows a visitor no collection part and no tenant data (AC-4.1)" (another account's 3 copies in 2 lots; every selector and phrase in the criterion, and the owner's name and email, on all three pages) |
| AC-4.2 | `visitors_spec:207` "runs no query against lots for a visitor (AC-4.2)" (the SQL issued, from `sql.active_record`) |
| AC-4.3 | `visitors_spec:215` "still sends a visitor to sign in for quick add, a new lot, the collection, the scanner and More (AC-4.3)" (`Lot.count` unchanged) |
| AC-4.4 | `visitors_spec:226` "gives a visitor the search context even from a collection link (AC-4.4)" (crumbs, back arrow, printings links with no `from`) |
| AC-4.5 | `visitors_spec:236` "keeps every catalog response private for a visitor and a collector (AC-4.5)" |
| AC-5.1 | `visitors_spec:363` "gives a visitor the brand, Search and Sign in, and nothing that needs an account (AC-5.1)"; the detail form: `:382` "keeps the detail header, with its back link to search, on a visitor's card page (decision 3)" |
| AC-5.2, AC-5.3 | `visitors_spec:333` "has no tab bar, and the footer's content notice, for a visitor (AC-5.2, AC-5.3)"; the notice in the browser: `visitor_catalog_spec:42` |
| AC-5.4 | `visitors_spec:341` "tells a visitor only that the catalog hasn't been loaded (AC-5.4)" (exact text, no link) |
| AC-5.5 | `visitor_catalog_spec:57` "fits the search and card pages on a 390px phone, with Sign in in view (AC-5.5)" (390px frame: no sideways scroll, "Sign in" visible); the eight screenshots below, looked at |
| AC-5.6 | By reading: `docs/design-system/components/VisitorHeader.md` (markup, when it shows, the phone and detail forms, "No tab bar, and the untabbed shell", "For a visitor"); the design system README's "App additions (spec 023, in `collector/additions.css`): `VisitorHeader`" line; `AuthPage.md`'s "nothing else is reachable before signing in, except the open catalog's pages …" and "The brand stays unlinked even then … (accepted, spec 023)"; `Footer.md`'s clearance line naming the `c-shell--untabbed` exception |
| AC-5.7 | Markup: `visitors_spec:350` "marks the shell untabbed for a visitor and not for a collector (AC-5.7)"; `:104` and `:108` the sign-in and sign-up pages untabbed, setting off and on. Browser, 390px: `visitor_catalog_spec:66` "gives up the tab bar's clearance on a footed shell with no tab bar, and keeps it for a collector (AC-5.7)" (visitor's search, sign-in and sign-up, with sign-up open: footer under 80px, `c-main` 16px; collector: footer 80px or more); `:86` "… on an unfooted shell …" (`c-main` under 80px for a visitor, 80px or more for a collector). The block's shape: `spec/design_system_files_spec.rb:61` "keeps the rules in one block of their own, after the footer's, with no colour literal or font (AC-5.7)" |
| AC-6.1 | `visitors_spec:312` "shows a collector every collection part (AC-6.1)" (setting on: `×3`, the unowned frame, add forms, avatar, tab bar on search and all printings; "Owned" 3, two copies, add buttons, new-lot link on the card page) |
| AC-6.2 | `spec/requests/catalog/quick_adds_spec.rb:42` "answers an over-cap add without scripting with the card page at 422" (the "Owned" stat and `.c-avatar` stay; red with `collector?` forced false, above) |

### Functional requirements

| Requirement | Held by |
|---|---|
| FR-1 | By reading: `git grep 'public?'` in `app/` finds `Catalog.public?` defined in `app/models/catalog.rb` and asked only in `app/controllers/concerns/open_catalog.rb` |
| FR-2 | `OpenCatalog` (`allow_unauthenticated_access if: -> { Catalog.public? }`, `before_action :resume_session`) is included by `Catalog::EntriesController` and `Catalog::IdentitiesController` only; held by AC-3.1–3.3, AC-6.1 (a collector is recognised with the setting on) and AC-4.3 (no other action opens) |
| FR-3 | AC-4.2's example (no `lots` query); by reading, `OpenCatalog#owned_quantities` returns `{}` with no account and `Catalog::CardOverview#lots` returns `[]` |
| FR-4 | AC-2.2's identical-body guard (the setting changes nothing for a collector), AC-6.2 (another controller's re-render still shows the parts); by reading, `ApplicationHelper#collector?` reads `Current.user`, and no view names the setting |
| FR-5 | By reading: `CLAUDE.md`'s status line ("… which has needed sign-in since accounts (spec 004) unless the operator opens it with `COLLECTOR_PUBLIC_CATALOG` (spec 023)") and its new "Open catalog (spec 023)" Non-obvious Facts bullet (`Catalog.public_in?`, the initializer, `:public_catalog`, `OpenCatalog`, `prefetch?`, `collector?`, `catalog/_visitor_head`, `c-shell--untabbed`) |

### The plan's amendments

| Amendment | Held by |
|---|---|
| 1. Phase 3 in three commits | `95af0ba` (3a), `d075e70` (3b), `2ef6ec6` (3c), in that order, each with its guard or red run above |
| 2. Off means today, proven | `visitors_spec:114` (AC-2.2) |
| 3. "For a visitor" in `VisitorHeader.md` | By reading: the section names the plain `c-tile` with no `UnownedTile` marker, quantity badge or `TileAdd`; no "Owned", "Your copies" or "Add a copy"; "N known" with no muted rows |
| 4. Deterministic prefetch proof | `visitor_catalog_spec:105` "doesn't prefetch a hovered result for a visitor" (`#settled` then no `#prefetched`); red with the meta removed (above). The flow check is `:122` |
| 5. Unfooted shell on search without a query | `visitor_catalog_spec:86`, under `with_catalog_sources("other" => "OtherCatalogSource")`, measuring `c-main` on `catalog_entries_path` |
| 6. Interim brand link to search | By reading `d075e70`'s `_appbar`: the visitor branch links the brand to `catalog_entries_path` |
| 7. The return path keeps the query | `visitors_spec:259` "returns a visitor to the card page with its query string when they sign in (AC-3.5, plan amendment 7)": a visitor opens `catalog_entry_path(printing, from: "collection")`, signs in and is sent back to that path with its query; red with `request.path` in place of `request.fullpath` (above) |
| 8. Explicit spec types | `visitors_spec` is `type: :request`, `visitor_catalog_spec` is `type: :system`; multi-expectation examples carry `:aggregate_failures` |
| 9. The initializer's comment | By reading `config/initializers/public_catalog.rb` (see AC-1.2) |

**Verified only by reading:** AC-1.2's initializer half, AC-1.3's two comment lines, AC-1.4, AC-5.6, FR-1, FR-5, amendments 3, 6 and 9, and `docs/roadmap.md`'s #59 line, which now names spec 023 and the branch ("**In progress:** spec 023, branch `023-signed-out-catalog-browsing`"; the PR isn't open yet). Not tried: a real phone (the 390px frame stands in for it) and a deployed instance with the variable set in Compose or Kamal (the file checks and the parser's examples stand in for it).

## Screenshots

[screenshots/](screenshots/), eight JPEGs (about 280 KB in all): a visitor's search results for "lightning" and the Lightning Bolt card page, each at `1280` and `390` (a fixed-width frame), `light` and `dark`, from a dev server on this worktree with `COLLECTOR_PUBLIC_CATALOG=true`. The worktree's dev catalog was empty, so they were taken on a scratch seed in its dev database: one user, six "Lightning" printings in three sets (Lightning Bolt in CLU, 2XM and M10; Lightning Helix in CLU and 2XM; Lightning Strike in M10), with no images, so every tile and the card page show their placeholders. `search-1280-light`, `search-390-light`, `card-1280-dark` and `card-390-dark` were looked at for this record:

- **Search, 1280px:** the brand ("Collector"), "Search" underlined as current, and "Sign in" as a small secondary button at the right; three groups of plain tiles with set and language tags and no `×N`, "Not owned" tag, dashed frame or Add button; the footer's Fan Content Policy and Scryfall lines.
- **Search, 390px:** the mark and "Sign in" only (the nav hides); two tiles a row; nothing cut off, no sideways scroll; the footer ends the page with no empty band under it (the untabbed shell).
- **Card page, 1280px, dark:** crumbs "Search / Magic: The Gathering / Lightning Bolt", the placeholder image, details, rules text, "Printings 3 known" with no owned count and no muted rows, "Show all 3 printings", format legality; no "Owned" stat, "Add a copy" or "Your copies".
- **Card page, 390px, dark:** the detail header (the back arrow in the mark's place, "Sign in" at the right), the page in one column, nothing cut off.

The header and footer sit about 8px in from the window's edges. That inset predates this feature: spec 004's screenshots (`docs/specs/004-design-system-collection/screenshots/`) show it.

## Local gate

`bin/ci` at `9cd4907` (2026-10-14): passed in 3m27s. RuboCop, Brakeman, bundler-audit and the importmap audit clean; RSpec 1456 examples, 0 failures, 1 pending (the art-agreement skip), seed 43984.

## Notes

- The two Phase 5 commits (`687dc91`, `1c28c71`) end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. They are left as they are: rewriting the branch's history wasn't permitted.
- The screenshots' scratch seed lives only in the worktree's development database; nothing was added to `db/seeds.rb` or committed.
- Phase 4 moved the prefetch-off meta from the layout (where Phase 3 put it for anyone signed out, which reached sign-in and sign-up) into `catalog/_visitor_head`, so with the setting off no page changes (`eb219ac`'s ruling; `visitors_spec:104` and `:108` hold it).

## Commits

```text
8bf7a5d docs(023): document the open catalog setting
1c28c71 docs(023): screenshots of the visitor's pages
687dc91 test(023): a visitor searches and opens a card in the browser
eb219ac feat(023): give the header a visitor form and drop the tab bar for visitors
2ef6ec6 feat(023): open catalog search and card pages to visitors
d075e70 refactor(023): decide collection parts with collector?
95af0ba refactor(023): lift prefetch? to ApplicationController
2c8355f feat(023): pass COLLECTOR_PUBLIC_CATALOG through Compose and Kamal
3f9d593 feat(023): add the COLLECTOR_PUBLIC_CATALOG operator setting
6a3d580 docs(specs): plan 023 approved with changes from the Fable plan review
427bf80 docs(specs): plan 023 from the read-only plan review
d93999c docs(specs): plan for spec 023
7ea4f93 docs(specs): spec 023 v1.2.0, approved with changes
3e0ec11 docs(specs): spec 023 v1.1.0 from the read-only spec review
2b38dae docs(specs): draft spec 023, browse the catalog without signing in
```

Then this file. The branch isn't pushed; the pull request is the coordinator's to open.

## Left for the maintainer

- The read-only review of the branch (plan, Phase 7).
- The pull request, and the roadmap's #59 line updated with it.
- Upstreaming: the published design system's `AppHeader` should gain the signed-out form and the untabbed shell at its next export (`VisitorHeader.md`).
