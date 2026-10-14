# Feature 023: Browse the Catalog Without Signing In

**Status:** Draft, awaiting the maintainer's approval
**Version:** 1.0.0
**Created:** 2026-10-14
**Last Updated:** 2026-10-14
**Branch:** `023-signed-out-catalog-browsing`
**Issue:** [#59](https://github.com/plainprogrammer/Collector/issues/59)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-14 | Written from issue #59, the north star's hosted-door notes and rulings 27, 29 and 30 |

---

## Problem Statement

Scryfall's terms pass the "source terms allow hosting" rule for a hosted instance on one condition: any Wizards of the Coast or Scryfall data is publicly accessible, with search open to everyone, including visitors who aren't signed in ([research 016](../016-scryfall-hosting-terms/research.md), ruling 27). Card pages hold the same data and open with search (ruling 29). Not every instance should be open: it is an operator setting, off by default, which a hosted instance turns on (ruling 30).

Today every catalog page needs sign-in (spec 004), and each one reads the signed-in account:

| Page | Route | What it reads from the account |
|---|---|---|
| Search | `GET /catalog/entries` (`Catalog::EntriesController#index`) | Owned quantity per tile (`×N`), the unowned marker and dashed frame (spec 021), the tile's add button |
| Card page | `GET /catalog/entries/:external_key` (`#show`) | The "Owned" stat, "Add a copy", "Your copies", the printings list's "N owned", `×N`, muted unowned rows and add buttons |
| All printings | `GET /catalog/identities/:external_key` (`Catalog::IdentitiesController#show`, "Show all N printings") | The same tiles as search |

The shell around them reads the user too: the app header's avatar menu, its add button, the tab bar's Collection, Scan and More tabs, and the catalog-not-loaded notice's admin check.

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
- Changing `/` (it still goes to the collection, which asks a visitor to sign in), the sign-in or sign-up pages, or registration.
- Rate limiting, caching or other hardening for public traffic (hosted-service features are after 1.0, north star).
- A per-account or per-user choice. This is the operator's choice of what the instance publishes (hosted-door rule 3, note 1).

## Decisions

### 1. An environment variable, `COLLECTOR_PUBLIC_CATALOG`

Off unless it is `1`, `true`, `yes` or `on` (any case, surrounding spaces ignored), as `COLLECTOR_MTG_ART_MATCHING` is parsed. It is read once at boot into `config.x.public_catalog`, and the test environment never reads it (a developer's exported variable mustn't change the suite; examples set the configuration). It is the operator's choice, of the same kind as the art and language settings, and the north star's note names it as an operator setting. Not an admin toggle in `InstanceSetting`: the issue and the brief place it with the other environment settings, and a hosted instance sets it in its deployment. It lives in the catalog core (`Catalog.public?`), since it opens every collectible's catalog, not MTG's.

### 2. "Show all N printings" opens with search

It is a page of search results (spec 004's printings page), linked from every result group with more printings than shown. Leaving it closed would put a link on every visitor's search page that sends them to sign in. Ruling 29's reasoning (the same Wizards and Scryfall data) covers it. **Put to the maintainer** with the spec's approval; the alternative is to keep it closed and hide the link from visitors.

### 3. The visitor header: brand, Search, Sign in; no tab bar

A visitor's app header shows the brand (linked to search, since `/` would ask them to sign in), one nav link, "Search", marked current, and a "Sign in" button (`c-btn c-btn--secondary c-btn--sm`) in the actions. No avatar, no add button. Below 640px the nav hides, as it does for everyone, leaving the mark and "Sign in". No tab bar: a bar with one destination is not navigation, and the header already holds the way in. Built only from existing classes, so `additions.css` doesn't change; the form is documented in a new app document, `VisitorHeader.md`. The detail form of the header (`c-appbar--detail`, the back arrow on phones) is kept on the card page.

### 4. Signing in from a catalog page comes back to it

A visitor who opens a catalog page and then signs in returns to the last catalog page they saw, through the same session key a refused page uses today (`return_to_after_authenticating`). Without it a visitor who signs in to add the card in front of them lands in their collection and has to search again. A refused page visited later overwrites the key, as today.

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

- [ ] **AC-1.1** Given `COLLECTOR_PUBLIC_CATALOG` is unset, empty, `false` or `0` When the app boots outside the test environment Then `Catalog.public?` is false; given `1`, `true`, `yes`, `on`, ` TRUE ` Then it is true
- [ ] **AC-1.2** In the test environment the variable is never read; `Catalog.public?` reads `config.x.public_catalog`, false by default
- [ ] **AC-1.3** `compose.yaml` passes `COLLECTOR_PUBLIC_CATALOG` through (empty by default) and names it in its header comment; `config/deploy.yml` has it commented out with a line saying what it does
- [ ] **AC-1.4** The README's Compose variable table lists it (off by default), and the README says what it opens, what stays private, and that it suits a hosted instance (verified by reading)

### Story 2: With the setting off, nothing changes

- [ ] **AC-2.1** Given the setting is off and a visitor When they request search, a card page or all printings Then they are redirected to sign in, and after signing in land on the page they asked for (as today)
- [ ] **AC-2.2** Given the setting is off and a collector Then the three catalog pages render as today (the existing request and system specs pass unchanged)

### Story 3: A visitor searches and opens a card

**As a** visitor to an open catalog
**I want** to search cards and read a card's page
**So that** I can look cards up without an account

- [ ] **AC-3.1** Given the setting is on and a visitor When they request search, with or without a query and set filter, and a page number Then it answers 200 with the same results, set filter, freshness line and pagination a collector sees
- [ ] **AC-3.2** Given the same When they request a card page Then it answers 200 with the image, name, details, rules, legality, the printings list and "View on Scryfall"
- [ ] **AC-3.3** Given the same When they request all printings of a card, with and without a set Then it answers 200 with its tiles and pagination (decision 2)
- [ ] **AC-3.4** Given the same When they request a card that doesn't exist, or all printings of an identity with no searchable entry Then it answers 404 (as for a collector)
- [ ] **AC-3.5** Given a visitor on a catalog page, with the setting on When they sign in from the header Then they land on that catalog page
- [ ] **AC-3.6** A system example: a visitor, without signing in, searches by name, opens a result, sees the card page with no collection part, and the footer's notice on both pages

### Story 4: No tenant data reaches a visitor

- [ ] **AC-4.1** Given another account owns 3 copies of a printing in 2 lots When a visitor opens search for it, its card page and its printings page Then no page contains `×3`, "Owned", "owned", "Not owned", "Your copies", "Add a copy", an add button, a quick-add form, a `c-tile--owned-none` or `is-unowned` class, or that account's user name, initial or email
- [ ] **AC-4.2** A visitor's request runs no query against `lots` (checked by the SQL issued)
- [ ] **AC-4.3** Given the setting is on and a visitor When they post a quick add, request a new-lot page, the collection, the scanner or More Then they are redirected to sign in, and nothing is written
- [ ] **AC-4.4** Given a visitor following a link with `from=collection` to a card page Then its crumbs and back arrow point to Search (decision 6)

### Story 5: The shell has a visitor form

- [ ] **AC-5.1** Given a visitor on a catalog page Then the header shows the brand linked to search, "Search" as the current nav link and a "Sign in" link to the sign-in page; no avatar, no "Add items" button, no admin links, no "Sign out"
- [ ] **AC-5.2** Given the same Then no tab bar is rendered
- [ ] **AC-5.3** Given the same Then the footer renders its content notice (spec 018), as on every page
- [ ] **AC-5.4** Given a catalog not yet loaded When a visitor searches Then the notice says it hasn't been loaded and nothing more (decision 7)
- [ ] **AC-5.5** Given a visitor's search and card pages at 1280px and 390px, in light and dark Then nothing is cut off and the page doesn't scroll sideways (screenshots)
- [ ] **AC-5.6** `docs/design-system/components/VisitorHeader.md` documents the header form; the design system README lists it under spec 023's app additions; `AuthPage.md` no longer says nothing is reachable before signing in without the exception (verified by reading)

### Story 6: A collector sees what they see today

- [ ] **AC-6.1** Given the setting is on and a collector Then search, the card page and all printings show every collection part as today (owned counts, markers, add controls, copies, the avatar menu and the tab bar)

## Functional Requirements

- **FR-1** `Catalog.public?` is the one test of the setting; every behaviour asks it.
- **FR-2** The three catalog actions skip the sign-in requirement when `Catalog.public?`; each still resumes a session when there is one, so a collector is recognised. No other action changes.
- **FR-3** With no signed-in account, no catalog action reads tenant data: search and all printings pass an empty owned map without querying, and the card page's overview holds no lots without querying.
- **FR-4** The views decide on collection parts from whether someone is signed in (`authenticated?`), never from the setting.
- **FR-5** `CLAUDE.md`'s project status line says catalog search needs sign-in unless the operator opens it.

## Non-Functional Requirements

- **Security.** Tenant isolation is checked by request specs with another account's lots present (AC-4.1) and by the absence of `lots` queries (AC-4.2). No new parameter is read; no write action is opened. Brakeman stays clean.
- **External data.** Pages still never call Scryfall during render; card images are the same Scryfall CDN URLs the pages already use.
- **Hosted-door rules.** Rule 1: this is the condition ruling 27 sets. Rule 2: no operator page changes. Rule 3: an operator setting, per the north star's note. Rule 4: no storage and no background work per account or per visitor; each visitor request costs the same queries as a collector's minus the `lots` queries.
- **Data and upgrades.** No migration, no stored data, no change to the export format.
- **Testability.** Request specs for every combination of setting on/off and signed in/out on all three pages; one system spec of the visitor's flow; screenshots for AC-5.5. Documents are verified by reading.

## Open Questions

- Decision 2 (all printings opens too) is put to the maintainer with this spec.

## Out of Scope

The sign-in and sign-up pages, `/`, the collection, lots, quick add, the scanner, More, admin pages, the export format, rate limiting.
