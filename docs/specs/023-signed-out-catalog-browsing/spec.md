# Feature 023: Browse the Catalog Without Signing In

**Status:** Approved with changes by the maintainer on 2026-10-14, after a read-only Fable review; the changes are in v1.2.0
**Version:** 1.2.1
**Created:** 2026-10-14
**Last Updated:** 2026-10-14
**Branch:** `023-signed-out-catalog-browsing`
**Issue:** [#59](https://github.com/plainprogrammer/Collector/issues/59)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-14 | Written from issue #59, the north star's hosted-door notes and rulings 27, 29 and 30 |
| 1.1.0 | 2026-10-14 | From the read-only Opus spec review: ruling 27 restated as written; decision 1's reasons corrected and the environment variable versus `InstanceSetting` put to the maintainer; a parser and an initializer named (AC-1.1, AC-1.2); the compose spec named (AC-1.3); an empty instance (AC-2.3) and a stale session cookie (AC-2.4) covered; one signed-in test per request (FR-4); decision 4 says when the key is written and that sign-up still goes to the collection; AC-4.1 checks structure; caching (AC-4.5); the brand's label and the detail header on phones |
| 1.2.0 | 2026-10-14 | The maintainer's rulings (decision 1: the environment variable; decision 2: all printings opens) and approval with changes, from the read-only Fable review: `collector?` is a helper every page reads, so the quick add's full-lot re-render keeps the collection parts (FR-4, AC-6.2); a shell with no tab bar drops its clearance (`c-shell--untabbed`, decision 3, AC-5.7, ruled by the maintainer); a prefetch is recognised as `CollectionsController#prefetch?` does, lifted to a shared place (decision 4); sign-up clears the return path (decision 4, AC-3.7); the README advises a rate limit at the proxy (AC-1.4); AC-1.2's initializer half and AC-4.3's CSRF note corrected; the sign-in page's unlinked brand accepted (AC-5.6); the return path isn't an open redirect (Security) |
| 1.2.1 | 2026-10-14 | From the Fable plan review: decision 4 notes that the return path keeps the page's query, so a card opened from a `from=collection` link is returned to with it |

---

## Problem Statement

Scryfall passes the "source terms allow hosting" rule for a free hosted service. For a paid one, one of its conditions is that any Wizards of the Coast or Scryfall data is publicly accessible on a hosted instance, with search open to everyone including unauthenticated visitors ([research 016](../016-scryfall-hosting-terms/research.md), ruling 27). Card pages hold the same data and open with search (ruling 29). Not every instance should be open: it is an operator setting, off by default, which a hosted instance turns on (ruling 30).

Today every catalog page needs sign-in (spec 004), and each one reads the signed-in account:

| Page | Route | What it reads from the account |
|---|---|---|
| Search | `GET /catalog/entries` (`Catalog::EntriesController#index`) | Owned quantity per tile (`×N`), the unowned marker and dashed frame (spec 021), the tile's add button |
| Card page | `GET /catalog/entries/:external_key` (`#show`) | The "Owned" stat, "Add a copy", "Your copies", the printings list's "N owned", `×N`, muted unowned rows and add buttons |
| All printings | `GET /catalog/identities/:external_key` (`Catalog::IdentitiesController#show`, "Show all N printings") | The same tiles as search |

The shell around them reads, or links to, signed-in pages too: the app header's avatar menu reads the user; its add button and brand, and the tab bar's Collection, Scan and More tabs, link to pages that need sign-in; and the catalog-not-loaded notice reads the user's admin flag.

> **Terms.**
> - A *visitor* is anyone without a session: never signed in, or signed out.
> - A *collector* is a signed-in user.
> - The *open catalog* is the instance with the new setting on.
> - *Catalog pages* are the three pages in the table above.
> - *Collection parts* are the parts of a catalog page that read the account, listed in the table's last column.

## Goals

- An operator can open the catalog to visitors with one environment variable, documented for Compose and Kamal.
- With it on, a visitor can search, open a card page and see all of a card's printings, with no collection part and no tenant data.
- A collector sees catalog pages exactly as today, setting on or off.
- With it off, nothing changes: every page answers as it does today.

## Non-Goals

- Opening anything else to visitors: the collection, lots, quick add, the scanner, More, admin pages. Every write action still needs sign-in.
- Changing `/` (it still goes to the collection, which asks a visitor to sign in), or what the sign-in and sign-up pages show (they lose only the empty band, decision 3). A visitor who signs up still lands in their new collection, as today; sign-up only clears the return path (decision 4).
- Rate limiting in the app (the README advises it at the reverse proxy).
- Caching or other hardening for public traffic (hosted-service features are after 1.0, north star).
- A per-account or per-user choice. This is the operator's choice of what the instance publishes (hosted-door rule 3, note 1).

## Decisions

### 1. An environment variable, `COLLECTOR_PUBLIC_CATALOG`

Off unless it is `1`, `true`, `yes` or `on` (any case, surrounding spaces ignored), as `COLLECTOR_MTG_ART_MATCHING` is parsed: a pure parser, `Catalog.public_in?(env)`, and an `after_initialize` initializer that stores the result in `config.x.public_catalog` once at boot. The test environment never reads the variable (a developer's exported variable mustn't change the suite; examples set the configuration). It lives in the catalog core (`Catalog.public?`), since it opens every collectible's catalog, not MTG's.

The issue asks for "an instance setting", which could be read as a new admin toggle beside `InstanceSetting.sign_up_open` (spec 004). An environment variable is recommended instead:
- the brief rules out changing admin pages, where a toggle would live;
- a hosted instance fixes it in its deployment configuration, beside the other operator settings, where the condition it meets (ruling 27) is visible and versioned;
- an admin can't switch a terms condition off by accident from a page.

**Ruled by the maintainer (2026-10-14):** the environment variable `COLLECTOR_PUBLIC_CATALOG`, off by default, documented for Compose and Kamal. The alternative, an `InstanceSetting` column with a toggle on an admin page, was not taken.

### 2. "Show all N printings" opens with search

It is a page of search results (spec 004's printings page), linked from every result group with more printings than shown. Leaving it closed would put a link on every visitor's search page that sends them to sign in. Ruling 29's reasoning (the same Wizards and Scryfall data) covers it. **Ruled by the maintainer (2026-10-14):** it opens to visitors.

### 3. The visitor header: brand, Search, Sign in; no tab bar

A visitor's app header shows the brand (linked to search, since `/` would ask them to sign in, and labelled "Collector search"), one nav link, "Search", marked current, and a "Sign in" button (`c-btn c-btn--secondary c-btn--sm`) in the actions. No avatar, no add button. Below 640px the nav hides, as it does for everyone, leaving the mark and "Sign in"; on the card page the back arrow takes the mark's place, as for a collector. No tab bar: a bar with one destination is not navigation, and the header already holds the way in. The header is built from existing classes; the form is documented in a new app document, `VisitorHeader.md`.

Below 640px the shell keeps 80px at the foot of the page clear for the tab bar (`c-main`, or the footer on a footed shell). With no tab bar that is an empty band. **Ruled by the maintainer (2026-10-14):** add one rule. The layout marks the shell `c-shell--untabbed` whenever a page renders no tab bar, and one block in `additions.css`, headed `Untabbed shell (spec 023)`, gives `c-main` and the footer their ordinary padding there. The sign-in and sign-up pages, which have never had a tab bar, lose the same band. `VisitorHeader.md` documents the rule, and the design system README's additions list it as in `additions.css`. The detail form of the header (`c-appbar--detail`, the back arrow on phones) is kept on the card page.

### 4. Signing in from a catalog page comes back to it

A visitor who opens a catalog page and then signs in returns to the last catalog page they opened, through the same session key a refused page uses today (`return_to_after_authenticating`). Without it a visitor who signs in to add the card in front of them lands in their collection and has to search again. The key is written only when a visitor's GET of a catalog page renders it, and not for a prefetch, which is a page they hovered, not one they saw. A prefetch is recognised as `CollectionsController#prefetch?` recognises one today (`Sec-Purpose`, `X-Sec-Purpose`, `X-Moz` or `Purpose` naming it), lifted to a place both controllers share. A collector's request never writes it. A refused page visited later overwrites it, as today. The path is the page's full path with its query, so a visitor who followed a `from=collection` link comes back to it with that parameter, and, now signed in, sees the collection's crumbs (consistent with decision 6). Sign-up still lands in the collection (a non-goal), and clears the key, so a visitor who browses a card, signs up, and later signs out and in again doesn't land on that card.

### 5. Collection parts are left out, not shown empty

A visitor never sees an ownership statement, true or false: no `×N`, no "Not owned" marker or dashed frame, no "Owned" stat, no "N owned" count, no muted rows, no add control, no "Your copies". The tile is the plain `c-tile`. The printings list's count reads "N known". Rows that would be muted aren't. Saying "Not owned" to someone with no collection would be false.

### 6. The context of a card page is always Search for a visitor

The `from=collection` parameter makes the card page's crumbs and back arrow point to the collection (spec 004 AC-8.9). A visitor has none, so for a visitor the context is Search whatever the URL says.

### 7. The not-loaded notice drops its second sentence for a visitor

Spec 015's notice tells a member to ask an admin, or an admin to load it. A visitor sees only the first sentence ("The card catalog hasn't been loaded yet."): who runs the instance is not theirs to know from the page.

## User Stories

### Story 1: The operator opens the catalog

**As an** operator of a hosted instance
**I want** to open the catalog to visitors with one setting
**So that** the instance meets the source's terms for hosting

- [ ] **AC-1.1** `Catalog.public_in?(env)` is false for `COLLECTOR_PUBLIC_CATALOG` unset, empty, `false`, `0` or `maybe`, and true for `1`, `true`, `yes`, `on` and ` TRUE `
- [ ] **AC-1.2** `Catalog.public?` is true only when `config.x.public_catalog` is `true`, and the configuration is false in the test environment. The initializer sets it from the environment outside the test environment only (verified by reading, as spec 011's)
- [ ] **AC-1.3** `compose.yaml` passes `COLLECTOR_PUBLIC_CATALOG` through (empty by default) and names it in its header comment; `config/deploy.yml` has it commented out with a line saying what it does; `spec/image_publishing_spec.rb` checks both, as it does for `COLLECTOR_MTG_ART_MATCHING`, and its `contain_exactly` list of Compose environment keys gains the new one
- [ ] **AC-1.4** The README's Compose variable table lists it (off by default), and the README says what it opens, what stays private, that it suits a hosted instance, and that an operator opening it should rate-limit requests at the reverse proxy, since search runs a name match on every request (verified by reading)

### Story 2: With the setting off, nothing changes

- [ ] **AC-2.1** Given the setting is off and a visitor When they request search, a card page or all printings Then they are redirected to sign in, and after signing in land on the page they asked for (as today)
- [ ] **AC-2.2** Given the setting is off and a collector Then the three catalog pages render as today (the existing request and system specs pass unchanged)
- [ ] **AC-2.3** Given no users exist, with the setting on or off When anyone requests a catalog page Then they are redirected to sign-up (first run, spec 004, unchanged)
- [ ] **AC-2.4** Given a visitor whose session cookie names a session that no longer exists When they request a catalog page Then with the setting off they are redirected to sign in, and with it on they get the visitor's page

### Story 3: A visitor searches and opens a card

**As a** visitor to an open catalog
**I want** to search cards and read a card's page
**So that** I can look cards up without an account

- [ ] **AC-3.1** Given the setting is on and a visitor When they request search, with or without a query and set filter, and a page number Then it answers 200 with the same results, set filter, freshness line and pagination a collector sees
- [ ] **AC-3.2** Given the same When they request a card page Then it answers 200 with the image, name, details, rules, legality, the printings list and "View on Scryfall"
- [ ] **AC-3.3** Given the same When they request all printings of a card, with and without a set Then it answers 200 with its tiles and pagination (decision 2)
- [ ] **AC-3.4** Given the same When they request a card that doesn't exist, or all printings of an identity with no searchable entry Then it answers 404 (as for a collector)
- [ ] **AC-3.5** Given a visitor on a catalog page, with the setting on When they sign in from the header Then they land on that catalog page; a prefetch of another catalog page in between doesn't change where they land; a collector's catalog request writes no return path
- [ ] **AC-3.7** Given a visitor who opened a card page When they sign up Then they land in their collection (as today), and signing out and in again also lands in the collection
- [ ] **AC-3.6** A system example: a visitor, without signing in, searches by name, opens a result, sees the card page with no collection part, and the footer's notice on both pages

### Story 4: No tenant data reaches a visitor

- [ ] **AC-4.1** Given another account owns 3 copies of a printing in 2 lots When a visitor opens search for it, its card page and its printings page Then no page has a `.c-avatar`, `.c-tile__qty`, `.c-tile__add`, a form posting to a quick add, a link to a new-lot page, `#copies`, a `.c-stat`, a `.c-tile--owned-none` or an `li.is-unowned`; and no page's text contains "Not owned", "Your copies", "Add a copy", " owned" or that account's user name or email
- [ ] **AC-4.2** A visitor's request runs no query against `lots` (checked by the SQL issued)
- [ ] **AC-4.3** Given the setting is on and a visitor When they post a quick add, request a new-lot page, the collection, the scanner or More Then they are redirected to sign in, and `Lot.count` doesn't change
- [ ] **AC-4.4** Given a visitor following a link with `from=collection` to a card page Then its crumbs and back arrow point to Search, and its printings links carry no `from` (decision 6)
- [ ] **AC-4.5** A visitor's and a collector's catalog responses keep Rails' default `Cache-Control: private`; nothing marks them publicly cacheable

### Story 5: The shell has a visitor form

- [ ] **AC-5.1** Given a visitor on a catalog page Then the header shows the brand linked to search (labelled "Collector search"), "Search" as the current nav link and a "Sign in" link to the sign-in page; no avatar, no "Add items" button, no admin links, no "Sign out"
- [ ] **AC-5.2** Given the same Then no tab bar is rendered
- [ ] **AC-5.3** Given the same Then the footer renders its content notice (spec 018), as on every page
- [ ] **AC-5.4** Given a catalog not yet loaded When a visitor searches Then the notice says it hasn't been loaded and nothing more (decision 7)
- [ ] **AC-5.5** Given a visitor's search and card pages at 1280px and 390px, in light and dark Then nothing is cut off and the page doesn't scroll sideways (screenshots)
- [ ] **AC-5.6** `docs/design-system/components/VisitorHeader.md` documents the header form; the design system README lists it under spec 023's app additions; `AuthPage.md`'s "nothing else is reachable before signing in" names the open catalog as the exception, and says the auth pages' brand stays unlinked, so a visitor who opens sign-in goes back with the browser (accepted); the README's additions line for spec 023 says `VisitorHeader` is in `collector/additions.css` (verified by reading)
- [ ] **AC-5.7** Given a page with no tab bar (a visitor's catalog page, sign-in, sign-up) at 390px Then the body has `c-shell--untabbed`, and neither `c-main` nor the footer keeps the tab bar's 80px clearance; given a collector's page Then the class is absent and the clearance is as today (browser example)

### Story 6: A collector sees what they see today

- [ ] **AC-6.1** Given the setting is on and a collector Then search, the card page and all printings show every collection part as today (owned counts, markers, add controls, copies, the avatar menu and the tab bar)
- [ ] **AC-6.2** Given a collector whose quick add is refused because the lot is full, without scripting When the card page is re-rendered by the quick add Then it still shows the collection parts (the "Owned" stat, "Your copies", the avatar)

## Functional Requirements

- **FR-1** `Catalog.public?` is the one test of the setting; every behaviour asks it.
- **FR-2** The three catalog actions skip the sign-in requirement when `Catalog.public?`; each still resumes a session when there is one, so a collector is recognised. No other action changes.
- **FR-3** With no signed-in account, no catalog action reads tenant data: search and all printings pass an empty owned map without querying, and the card page's overview holds no lots without querying.
- **FR-4** The views decide on collection parts from whether someone is signed in, never from the setting. A helper every page can read (`collector?`, from `Current.user`) gives the answer, and it is resolved once per request by the authentication before-actions, so a stale session cookie costs one query, not one per tile, and a page another controller renders (the quick add's full-lot re-render of the card page) reads it the same way.
- **FR-5** `CLAUDE.md`'s project status line says catalog search needs sign-in unless the operator opens it.

## Non-Functional Requirements

- **Security.** The return path is `request.fullpath`, set by the server from the request it is answering, never read from a parameter, so it can't send anyone off the instance. Responses keep Rails' private caching (AC-4.5), since one URL now renders for visitors and collectors alike. Tenant isolation is checked by request specs with another account's lots present (AC-4.1) and by the absence of `lots` queries (AC-4.2). No new parameter is read; no write action is opened. Brakeman stays clean.
- **External data.** Pages still never call Scryfall during render; card images are the same Scryfall CDN URLs the pages already use.
- **Hosted-door rules.** Rule 1: this is the condition ruling 27 sets. Rule 2: no operator page changes. Rule 3: an operator setting, per the north star's note. Rule 4: no storage and no background work per account or per visitor; each visitor request costs the same queries as a collector's minus the `lots` queries.
- **Data and upgrades.** No migration, no stored data, no change to the export format.
- **Testability.** Request specs for every combination of setting on/off and signed in/out on all three pages; one system spec of the visitor's flow; screenshots for AC-5.5. Documents are verified by reading.

## Open Questions

None. Decisions 1 and 2 were ruled by the maintainer on 2026-10-14.

## Out of Scope

The sign-in and sign-up pages (except the clearance rule of decision 3 and the cleared return path of decision 4), `/`, the collection, lots, quick add, the scanner, More, admin pages, the export format, rate limiting.
