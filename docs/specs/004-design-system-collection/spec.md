# Feature 004: Design System, Accounts, Adding Cards and the Collection Grid

**Status:** Approved
**Version:** 2.1.2
**Created:** 2026-09-29
**Last Updated:** 2026-09-29
**Branch:** `feat/004-design-system-collection` (chosen at `sdd-execute`; drafted on `plainprogrammer/design-system-implementation`)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-09-29 | Initial approved spec |
| 2.0.0 | 2026-09-29 | Spec review revisions. **Health check and first run:** the health check is exempt from the first-run redirect, and the upgrade warning is stronger (AC-3.1, AC-3.5, FR-4). **Sign-in and sessions:** the sign-in rate limit is keyed on email + client address behind a trusted proxy, with a 429 (AC-4.8); the session cookie is secure over HTTPS, with a documented setting (NFR Security). **Price paid:** the currency is a documented instance setting (FR-6). **Condition and finish:** vocabulary moves into the collectible's extension, and lot identity is enforced in the data store (FR-6). **Superseded 002 ACs are now listed explicitly (AC-6.5, AC-8.2):** search tiles gain a language code, and the card page gets a details section. **Design-system fixes:** the logo follows the OS dark theme, and each tile has one finish badge (AC-2.5, AC-8.5, AC-11.2, FR-11). **Newly defined:** where the collector came from and the return path (AC-7.3, AC-8.9, FR-13); the Printings list (AC-8.7); mana-cost labels and formats (AC-8.3, AC-8.8); the command's inputs (AC-5.7); the count semantics (AC-11.4); merges past the 9,999 cap (AC-10.2). **Also:** AC-3.4 rewritten to be testable; stats keep one stat, with no 2 × 2 grid (FR-9); new FR-13 (app shell) and FR-14 (search page); FR-11 lists more patterns; self-service profile is explicitly out of scope; minor clarifications |
| 2.0.1 | 2026-09-29 | Second-review wording fixes (no behaviour change). **Card page:** the shown printing always has a Printings row (AC-8.7); the phone back link targets the breadcrumb's first item (AC-2.7); multi-face artists are listed per face (AC-8.1); a listed format missing from the data shows "Not legal" (AC-8.8); 002 FR-8's search link is replaced by the breadcrumb (AC-8.2). **Admin and command:** the admin's new password needs no confirmation (AC-5.3); the command rejects a malformed email (AC-5.7). **Also:** the page used for a no-script over-cap quick add (AC-7.3a); browser-level tags on AC-1.5 and AC-6.1; a single-stat block pattern (FR-11) |
| 2.1.0 | 2026-09-29 | From the plan review: the result count sits on the line directly beneath the filter bar, inside the results, so it updates with each search without scripting (AC-6.4, AC-11.4). With scripting on, an over-cap quick add shows its message in the status region and leaves the page as it was (AC-7.3a) |
| 2.1.1 | 2026-09-29 | FR-11 lists the table action cell (`TableActions`), which the admin users list and the copies table already use (no behaviour change) |
| 2.1.2 | 2026-09-29 | From the implementation review. The add, edit and removal pages for a lot are detail pages like the card page, with a back link to the card page (AC-2.7, AC-2.8). Tiles show the printing's printed name, localized when present, while sorting stays by card name (AC-6.2, AC-11.2) |

---

## Problem Statement

Collector can find a Magic card, but that's all it can do. Search (feature 002) is an unstyled proof of concept, it's open to anyone, and it ends at a detail page: a collector can't record that they own a card. The design system (tokens, `c-*` components, page patterns, voice) has been exported for this Rails app but isn't installed, so every new screen would be built without it. This feature installs the design system and adds accounts, so each collector has their own collection. It restyles search to the design system and lets a collector add cards from search, so their collection appears as the design system's default image grid. It also gives cards one item page that both search and the collection link to.

> **Constraints.** The design system export (`~/Downloads/collector-design-system.zip`, installed into the repo by this feature) is a fixed input, the way the stack is. Its rules (`docs/design-system/README.md`) and component docs define the look, voice and responsive behaviour of every screen here. This spec refers to its components by name (`AppHeader`, `FilterBar`, `ItemTile`, `ItemPage`, …). Row-level multi-tenancy (`.claude/rules/multi-tenancy.md`) is a fixed input too. The feature-002 search and printing behaviours (its ACs 1.x, 2.x, 3.x and 10.x) still apply except where this spec supersedes them, and every supersession is listed in AC-6.5 and AC-8.2. The biggest deliberate change is that search is no longer public (FR-7 of 002 is superseded by FR-2 here).

## Goals

- The design system is installed in the repo (stylesheets, fonts, logos, docs, previews, Claude Code skill and `CLAUDE.md` guidance), and every page in the app is built only from its tokens and `c-*` components.
- Every page uses the design system's app shell (header on wide screens, bottom tab bar on phones), works from 360px wide up, and renders correctly in light and dark themes.
- A self-hoster's instance has accounts. The first person to visit an empty instance becomes its admin. After that, sign-up is closed unless the admin opens it, and the admin can manage users from within the app. Each user has exactly one account.
- Every page except sign-in, sign-up and the health check requires a signed-in user. All collection data belongs to an account, and no account can see or change another account's data.
- Card search follows the design system and shows how many of each printing you own.
- A collector can add a printing to their collection in one click from search, or with full details (quantity, finish, condition, price paid) from the card page.
- The card page follows the `ItemPage` design: it shows your copies (with edit and remove), every printing (with quick add) and format legality. Search and the collection both link to it.
- The collection page shows your cards as the design system's image grid, with a name filter and exact counts.

## Non-Goals

- Table view, the grid/table `ViewSwitch`, `Edit many` and bulk mode (the next feature).
- Locations, decks and wishlists. There is no location on a copy, so tiles have no location line, and the card page has no "In decks" or "Free to use" stats and no "In decks" section.
- Price data, estimated value or price history (price paid is the collector's own record, not market data).
- Collection export and import.
- Email of any kind, including password reset by email.
- A theme switch in the UI (the theme follows the operating system).
- Choosing or reordering navigation sections.
- Multiple users sharing one account, or seeing another collector's items.
- Self-service profile: a user can't change their own name, email or password. The admin (AC-5.3) or the command (AC-5.7) does it.
- Changes to catalog ingestion (feature 002's refresh behaviour is unchanged).

## Users and Context

**Primary users:** Collectors on a self-hosted instance (the maintainer's household to start with). They search for cards they hold and record them, then browse their collection, on a phone at the table as often as on a desktop.
**Secondary users:**
- The instance admin (the first user), who opens or closes sign-up and manages users.
- Operators who upgrade an existing instance, which has no users yet.
- Contributors, who build future UI from the installed design system.

**Usage context:** A collector signs in and opens Search, types a card name and taps `Add` on the printing in their hand. They repeat that for the next card. When a copy needs details (foil, condition, what they paid), they open the card page and use `Add a copy`, or edit the lot afterwards. They open Collection to see what they have.
**User mental model:** "Find it, tap Add, it's in my collection." Vocabulary from the design system and 002:
- *card*: the gameplay identity.
- *printing*: one set, number and language.
- *copy*: one physical card.
- *lot*: copies of one printing with the same finish, condition and price paid.
- Also: *finish*, *condition*, *price paid*, *collection*.

## User Stories

### Story 1: Contributor builds on the installed design system

**As a** contributor
**I want** the design system installed in the repo and used by every page
**So that** new screens look and behave consistently without re-deriving the design

**Acceptance criteria:**

- [ ] **AC-1.1** Given the repository When it is inspected Then it contains the design system's token and component stylesheets, the four self-hosted font files, the four logo files, `docs/design-system/` (README, `tokens.json`, `logos.md`, component docs, previews) and the `collector-design-system` Claude Code skill, and the root `CLAUDE.md` contains the design system's UI guidance
- [ ] **AC-1.2** Given any page of the app When it is served Then its stylesheets load the design system's tokens before its components, and all four font files are served with status 200
- [ ] **AC-1.3** Given the app's stylesheets outside the design system's own directory When they are inspected Then they contain no hex, `rgb()` or `hsl()` colour literals and no font-family declarations, and feature 002's ad-hoc catalog styles are removed
- [ ] **AC-1.4** Given every new pattern this feature introduces (FR-11) When `docs/design-system/` is inspected Then each has a component doc and is listed in the README's Components section
- [ ] **AC-1.5** (verified in a browser-level test) Given any page built by this feature When it is rendered 360px wide Then the page does not scroll horizontally

### Story 2: Collector moves around the app shell

**As a** signed-in collector
**I want** the same navigation on every page
**So that** I can get to my collection and to search from anywhere, on any device

**Acceptance criteria:**

- [ ] **AC-2.1** Given a signed-in collector on a wide screen (640px or wider) When any page renders Then the header shows the Collector wordmark linking home, the main navigation with exactly "Collection" and "Search" in that order, and an avatar menu labelled with the collector's name
- [ ] **AC-2.2** Given a signed-in collector on a phone (narrower than 640px) When any page renders Then the header navigation is hidden and a bottom tab bar shows "Collection", "Search" and "More", each with an icon and a visible label
- [ ] **AC-2.3** Given the collector is on a page belonging to a section When the page renders Then that section's navigation link, in both the header and the tab bar, is marked as the current page, and no other link is
- [ ] **AC-2.4** Given the avatar menu (wide) or the More page (phone) When it is opened Then it offers "Sign out", and also "Users and sign-up" when the collector is an admin
- [ ] **AC-2.5** Given the collector has no theme set in the page When their operating system prefers dark Then the page renders with the design system's dark tokens and the reversed (dark-ground) logo, and otherwise with the light tokens and the standard logo
- [ ] **AC-2.6** Given a signed-in collector When they request the root path Then they are redirected to their collection page
- [ ] **AC-2.7** Given a detail page on a phone When it renders Then the header shows a back link (accessible name "Back") in place of the logo, and no add button; scripting may enhance it to go back in history. Detail pages and their back link targets:
  - a card page: the breadcrumb's first item from AC-8.9 (the collection page or the search page)
  - the add, edit and removal pages for a lot: that printing's card page
- [ ] **AC-2.8** Given any signed-in page that is not a detail page (AC-2.7) on a phone When it renders Then the header shows the logo mark, an icon-only add button (accessible name "Add items") leading to search, and the avatar menu

### Story 3: First visitor sets up the instance

**As an** operator who has just installed or upgraded Collector
**I want** the first person to visit to create the admin account
**So that** I can start using the instance without a command line

**Acceptance criteria:**

- [ ] **AC-3.1** Given an instance with no users When anyone requests any page other than sign-up or the health check Then they are redirected to sign-up, which explains that this first account will be the instance's admin; and the health check still responds 200
- [ ] **AC-3.2** Given an instance with no users When a visitor submits sign-up with a valid name, email and password Then a user is created as an admin, with its own new account, and the visitor is signed in and taken to their (empty) collection
- [ ] **AC-3.3** Given the first user has been created When the instance's sign-up setting is inspected Then sign-up is closed
- [ ] **AC-3.4** Given a visitor loaded the first-admin sign-up page while the instance had no users, and another user was created before they submitted When their submission is processed Then no user is created and the sign-up-closed response (AC-4.2) is returned; creating the first user re-checks that no user exists within the same write, so two submissions can never both become the first admin
- [ ] **AC-3.5** Given the README When it is read Then its upgrade notes warn, prominently and before the upgrade steps, that:
  - an upgraded instance has no users, and whoever reaches it first becomes admin
  - an instance reachable by others must be restricted before upgrading (for example, stop exposing it through the reverse proxy), or the operator must run the AC-5.7 command right after the upgrade to create the admin, which closes the first-run page
  - the operator should then sign up or sign in before exposing it again

  Fresh-install notes give the same advice
- [ ] **AC-3.6** Given an instance with no users When the operator runs the AC-5.7 command to create an admin Then the first-run redirect stops, sign-up is closed, and the created user can sign in

### Story 4: Collector signs up and signs in

**As a** collector
**I want** to create an account when the instance allows it, then sign in and out
**So that** my collection is mine and private

**Acceptance criteria:**

- [ ] **AC-4.1** Given sign-up is open When a visitor submits a name, a unique email and a password of at least 12 characters with a matching confirmation Then a non-admin user with its own new account is created, and the visitor is signed in and taken to their collection
- [ ] **AC-4.2** Given sign-up is closed When a visitor opens the sign-up page Then the response is 200 and shows "Sign-up is closed on this instance. Ask the person who runs it for an account." with no form; and when a sign-up is submitted anyway, the response is 422 with the same message and no user is created
- [ ] **AC-4.3** Given a sign-up with any of these When it is submitted Then no user is created, the response status is 422, and each invalid field shows its own message:
  - a blank name, or a name over 100 characters
  - a malformed email: not exactly one "@" with text on both sides, or containing whitespace
  - an already-used email (compared case-insensitively)
  - a password under 12 characters, or a confirmation that doesn't match
- [ ] **AC-4.4** Given a user When they submit sign-in with their email (any letter case) and password Then they are signed in and taken to the page they originally requested (only when it was a GET for a page on this instance), or otherwise to their collection
- [ ] **AC-4.4a** Given a signed-in user When they open the sign-in or sign-up page Then they are redirected to their collection
- [ ] **AC-4.5** Given a wrong email or password When sign-in is submitted Then the response is 422 with "Email or password is incorrect." and the message doesn't say which one was wrong
- [ ] **AC-4.6** Given a signed-out visitor When they request any page other than sign-in, sign-up or the health check Then they are redirected to sign-in
- [ ] **AC-4.7** Given a signed-in user When they choose "Sign out" Then their session ends and requesting their collection redirects to sign-in
- [ ] **AC-4.8** Given 10 sign-in attempts for one email from one client address within 3 minutes When another attempt for that email from that address is submitted Then the response status is 429 with "Too many attempts. Try again in a few minutes." and no password is checked. Attempts for a different email, or from a different client address, are not refused. Behind a trusted reverse proxy, the client address is the one the proxy forwards, not the proxy's own

### Story 5: Admin manages users and sign-up

**As the** instance admin
**I want** to open or close sign-up and create, edit and remove users
**So that** I control who uses my instance and can help someone who forgot their password

**Acceptance criteria:**

- [ ] **AC-5.1** Given an admin When they open "Users and sign-up" Then they see every user with name, email, admin status and number of copies owned, along with the current sign-up setting and a control to open or close it. (The per-user copy count is the one deliberate cross-account read in this feature, and it is limited to admins.)
- [ ] **AC-5.2** Given an admin When they create a user with a name, email, password and admin flag Then the user exists with its own new account and can sign in with that password
- [ ] **AC-5.3** Given an admin When they edit a user's name, email or admin flag, or set a new password for them Then the change is saved (subject to AC-4.3's name, email and password-length rules, 422 otherwise; the admin's new-password field has no confirmation), and a new password replaces the old one immediately: the old one no longer signs in, and that user's existing sessions are ended
- [ ] **AC-5.4** Given an admin When they delete another user and confirm, on a confirmation that states "This permanently deletes <name>'s account and all <n> copies in their collection. It can't be undone." Then that user, their account, their sessions and all of their copies are removed, and no other account's data changes
- [ ] **AC-5.5** Given an admin When they try to delete themselves, or remove admin from the only admin Then the change is refused with a message explaining why, and nothing changes
- [ ] **AC-5.6** Given a signed-in non-admin When they request any users or sign-up setting page or action Then the response status is 404
- [ ] **AC-5.7** Given the operator has shell access to the instance When they run the documented command with an email Then:
  - the password comes from a documented environment variable, or else is prompted for when the command runs interactively, or else is generated (at least 16 characters) and printed once to the terminal
  - if a user has that email, their password is set and their sessions are ended
  - otherwise a new admin user with its own account is created, named after the email's part before "@"
  - the password is never written to the application log
  - an email that fails AC-4.3's format rules makes the command exit non-zero without changing anything
  - the README documents the command for the Compose and Kamal paths

### Story 6: Collector searches the catalog in the design system

**As a** signed-in collector
**I want** card search to look and work like the rest of Collector and to show what I already own
**So that** I can see at a glance which printings I have while I add cards

**Acceptance criteria:**

- [ ] **AC-6.1** (in-place update verified in a browser-level test) Given the search page When it renders Then it has one page title ("Search"), and a sticky filter bar with a name search input and a set choice. Submitting it changes the URL (query and set in the URL, back button restores the previous search) and updates the results without a full page load, and it also works with scripting disabled
- [ ] **AC-6.2** Given results When they render Then each card is a section headed by the card name, holding one tile per listed printing. Each tile shows the printing's image (or the name on a plain fallback when there is none), its printed name (the localized name when the printing has one, otherwise its name), a `SET · number` tag and its language code (e.g. "EN", "JA"), and links to that printing's card page
- [ ] **AC-6.3** Given the collector owns copies of a listed printing When the results render Then that printing's tile shows the owned quantity ("×3"), and tiles of printings they don't own are shown faded with no quantity
- [ ] **AC-6.4** Given results When they render Then the line directly beneath the filter bar shows the exact number of matching cards ("12 cards" or "1 card") and the catalog's last-updated date (002 AC-1.12)
- [ ] **AC-6.5** Given feature 002's search behaviours (ACs 1.1–1.14, 2.1–2.4, 10.1–10.3) When they are exercised by a signed-in collector Then they still hold, except for these superseded parts:
  - **002 AC-1.5** (what each listed printing shows) is replaced by AC-6.2. Result tiles show image, name, `SET · number` and language; set name, rarity and finishes appear on the card page (AC-8.1).
  - **002 AC-1.7, AC-1.8 and AC-1.11** keep their conditions and statuses, but their messages now read:
    - "No cards match "<query>". Check the spelling or try part of the name."
    - "Type part of a card name to search."
    - "The card catalog hasn't been loaded yet."
  - **002 AC-10.1**'s "each shown as in AC-1.5" becomes "each shown as a tile as in AC-6.2".
  - **Access:** search and printings pages require sign-in (FR-2).
- [ ] **AC-6.6** Given the "all printings of a card" page (002 Story 10) When it renders Then it uses the same tiles, owned quantities and add controls as search results
- [ ] **AC-6.7** Given the search page When the collector presses "/" outside a text field Then the search input receives focus (an enhancement; the page works without it)

### Story 7: Collector quick-adds a printing from search

**As a** collector sorting a stack of cards
**I want** to add a printing with a single tap from the results
**So that** I can record many cards quickly without filling in forms

**Acceptance criteria:**

- [ ] **AC-7.1** Given a printing in search results When the collector chooses its `Add` control Then one copy of that printing is added to their collection with finish, condition and price paid unspecified
- [ ] **AC-7.2** (verified in a browser-level test) Given scripting is enabled When the quick add completes Then the page is not reloaded, the URL and scroll position are unchanged, that printing's tile now shows the new owned quantity, and a status message reads "Added 1 × <card name> (<SET> · <number>) to your collection." and is announced to screen readers
- [ ] **AC-7.3** Given scripting is disabled When the quick add is submitted Then the response redirects (303) to the page the add was made from, carried with the add as a return path, and that page shows the same status message and the updated quantity. A return path that isn't a path on this instance is ignored, and the collector is sent to the printing's card page instead
- [ ] **AC-7.3a** Given the collector already has 9,999 copies in the lot a quick add would merge into When they quick-add Then nothing changes, the response status is 422, and a status message reads "You already have the most copies one lot can hold (9,999).". With scripting on, the message appears in the status region and the rest of the page is unchanged. Without scripting, that 422 renders the printing's card page with the message
- [ ] **AC-7.4** Given the collector already has a lot of that printing with finish, condition and price paid all unspecified When they quick-add it again Then that lot's quantity increases by one and no new lot is created
- [ ] **AC-7.5** Given the collector has only lots of that printing with a specified finish, condition or price When they quick-add it Then a new lot with quantity 1 and those fields unspecified is created
- [ ] **AC-7.6** Given the `Add` control on a tile When it is inspected Then it is a separate control from the tile's link (not nested in it), has an accessible name that includes the card name and `SET · number`, and is at least 40px on touch devices

### Story 8: Collector views a card's page

**As a** collector
**I want** one page per card that shows the printing, my copies and every printing
**So that** I can answer "what is it, how many do I have and which printings" in one place, whether I came from search or my collection

**Acceptance criteria:**

- [ ] **AC-8.1** Given a printing When its card page is opened (addressed by the printing's Scryfall ID, as in 002 AC-3.4) Then it shows, in this order:
  - the printing's image and a caption naming the shown printing (`SET · number`, language)
  - the card name as the page's one title
  - a category chip reading "Magic: The Gathering"
  - the type line and mana cost
  - the rules text
  - a details list: set name and `SET · number`, language, localized name (if any), rarity (a word), finishes, release date and artist (one entry per face, in face order, for multi-face printings)
  - stats
  - Your copies
  - Printings
  - Format legality
- [ ] **AC-8.2** Given the card page When it renders Then it still meets:
  - 002 AC-3.1: every attribute is shown, in the sections of AC-8.1
  - 002 AC-3.2: the Scryfall link (in the page's "…" menu as "View on Scryfall") and the attribution
  - 002 AC-3.3: the retired notice
  - 002 AC-3.5: the link to the card's printings page, as AC-8.7's "Show all N printings"
  - 002 FR-8's "link to search results for the card" is replaced by the "Search" breadcrumb (AC-8.9)

  For a multi-face printing, the name, type line, mana cost, rules text and artist are shown once per face in face order, and each face's image is shown in the media column
- [ ] **AC-8.3** Given a mana cost When it renders Then it is shown as Collector's own coloured pips with letters, one per symbol in printed order, with no game-publisher symbols. It has an accessible label that reads the whole cost aloud, symbol by symbol in printed order:
  - a number reads as "<n> generic", X as "X", C as "1 colourless"
  - W/U/B/R/G read as "1 white", "1 blue", "1 black", "1 red", "1 green"
  - e.g. "Mana cost: 1 generic, 1 red, 1 red"

  Hybrid, Phyrexian and snow symbols aren't designed yet: they are shown as their text (e.g. `{W/U}`) in a tag beside the pips, and read as "white or blue", "Phyrexian green", "snow". A multi-face card shows each face's cost with that face. Rarity is shown as a word (Common, Uncommon, Rare, Mythic, Special, Bonus)
- [ ] **AC-8.4** Given the collector owns 7 copies of the card across 3 printings When the page renders Then the stats show "Owned 7" with "3 printings" beneath, counting every printing of the card, not only the one shown
- [ ] **AC-8.5** Given the collector owns lots of the card When "Your copies" renders Then its heading counts copies and lots ("7 in 4 lots"), and there is one row per lot, across every printing of the card. Each row shows `SET · number`, finish (a special finish, MTG foil or etched, as the one finish badge; any other finish as its capitalised word in muted text; "—" when unspecified), condition, language, quantity and price paid per copy ("—" when unspecified), plus an actions menu with "Edit copy" and "Remove"
- [ ] **AC-8.6** Given the collector owns none of the card When "Your copies" renders Then it says "You don't have this card yet." with the `Add a copy` action
- [ ] **AC-8.7** Given the card has printings When "Printings" renders Then:
  - The rows are, in order: the shown printing; then every other printing the collector owns (retired ones included and tagged "Retired"); then up to 10 of the newest non-retired card-kind printings not already listed. Owned rows and the newest rows are each ordered newest first, using 002's tie-breakers.
  - Each row shows `SET · number`, set name, language and owned quantity.
  - Printings they don't own are muted with an `Add` quick-add control (Story 7 behaviour, returning to the card page).
  - The shown printing is tagged "Shown", and each other row links to that printing's card page.
  - Whenever the card has at least one non-retired card-kind printing, a "Show all N printings" link leads to the printings page, where N is that count.
- [ ] **AC-8.8** Given the printing has format legalities When "Format legality" renders Then it lists these paper formats in this order: Standard, Pioneer, Modern, Legacy, Vintage, Pauper, Commander, Oathbreaker, Premodern. Any other format in the data is omitted, and a listed format missing from the data shows "Not legal". Each format shows a word: "Legal" in the success colour with a check; "Not legal", "Banned" or "Restricted" in muted text with a cross, never in the danger colour
- [ ] **AC-8.9** Given the collector opened the card page from a link in their collection (which marks the card page URL as coming from the collection) When it renders Then the breadcrumb starts "Collection" and the Collection section is current. Given any card page URL without that mark (from search results, the printings page or a typed link), the breadcrumb starts "Search" and the Search section is current. The mark is kept on links between printings and after adds, edits and removals made on that page
- [ ] **AC-8.10** (verified in a browser-level test) Given the page on a wide screen When the collector scrolls Then the image column stays in view; and given a phone-width page, the image is centred above the details and the "Your copies" rows fold finish, condition and language under the printing

### Story 9: Collector adds a copy with details

**As a** collector
**I want** to add copies with quantity, finish, condition and price paid
**So that** my collection records foils, condition and what I paid

**Acceptance criteria:**

- [ ] **AC-9.1** Given a card page When the collector chooses `Add a copy` Then a form for the shown printing asks for quantity (required, default 1), finish (optional; choices limited to the printing's available finishes, and not offered at all when the printing lists none), condition (optional; the collectible's condition scale, for MTG: Near mint, Lightly played, Moderately played, Heavily played, Damaged) and price paid per copy (optional, in the instance currency)
- [ ] **AC-9.2** Given valid input When the form is submitted Then the copies are added and the collector returns to the card page, which shows the updated stats and lots and the message "Added <n> × <card name> (<SET> · <number>) to your collection."
- [ ] **AC-9.3** Given the collector has a lot of the same printing with the same finish, condition and price paid (unspecified matches only unspecified) When they add copies Then that lot's quantity increases by the added quantity and no new lot is created; if the sum would exceed 9,999, nothing changes and the form returns 422 with "One lot can hold at most 9,999 copies." on quantity
- [ ] **AC-9.4** Given a quantity that is blank, not a whole number, below 1 or above 9,999, a finish the printing doesn't have, an unknown condition, or a price paid that is negative, not a number or has more than two decimal places When the form is submitted Then nothing is added, the response status is 422 and each invalid field shows its own message
- [ ] **AC-9.5** Given the form on a phone When it renders Then `Add a copy` stays visible full-width and secondary actions (View on Scryfall) are in a "…" menu

### Story 10: Collector edits and removes a lot

**As a** collector
**I want** to correct or remove a lot
**So that** mistakes from quick-adding can be fixed until bulk editing arrives

**Acceptance criteria:**

- [ ] **AC-10.1** Given a lot When the collector chooses "Edit copy" Then a form shows its current quantity, finish, condition and price paid, and saving valid values updates the lot and returns to the card page with "Saved."
- [ ] **AC-10.2** Given an edit that makes a lot's finish, condition and price paid equal to another lot of the same printing When it is saved Then the two lots become one lot with the edited finish, condition and price paid and the summed quantity; if the sum would exceed 9,999, nothing changes and the form returns 422 with "One lot can hold at most 9,999 copies." on quantity
- [ ] **AC-10.3** Given invalid edit values (the rules of AC-9.4) When the form is submitted Then the lot is unchanged, the response status is 422 and each invalid field shows its own message
- [ ] **AC-10.4** Given a lot When the collector chooses "Remove" and confirms Then the lot is removed, the card page shows the updated stats and "Removed <n> × <card name> (<SET> · <number>) from your collection.", and if no copies of the card remain the Your copies empty state is shown
- [ ] **AC-10.5** Given scripting is disabled When the collector removes a lot Then removal still requires an explicit confirmation step before anything is deleted

### Story 11: Collector browses their collection as a grid

**As a** collector
**I want** my collection as a grid of card images with counts
**So that** I can see what I have and find a card quickly

**Acceptance criteria:**

- [ ] **AC-11.1** Given a signed-in collector When they open their collection Then the page title reads "My collection", a stats line shows total copies and unique cards ("4,812 items · 1,906 unique", where unique counts distinct cards), and the page's one primary action, `Add items`, leads to search
- [ ] **AC-11.2** Given the collector owns copies When the grid renders Then there is one tile per owned printing showing:
  - its image (or the no-image fallback) at the card's 63:88 ratio
  - the total quantity across its lots, always shown, including "×1"
  - at most one finish badge, reading "Foil" if any lot is foil, "Etched" if any is etched, or "Foil, etched" if both
  - the printing's printed name (localized when present, as in AC-6.2); tiles still sort by card name (AC-11.3)
  - a `SET · number` tag and the language code
  
  Each tile links to that printing's card page
- [ ] **AC-11.3** Given the grid When it renders Then tiles are ordered by card name A–Z, then release date newest first, set code, collector number and language, 120 tiles per page with previous/next navigation; invalid or out-of-range page numbers fall back to the first or last page with status 200
- [ ] **AC-11.4** Given the collection's filter bar When the collector types part of a card name (display or localized, case-insensitive for ASCII, `%` and `_` literal) Then only tiles of matching printings are shown, the count on the line directly beneath the filter bar reads "<matching copies> of <total copies> items" (both are quantity sums over the whole collection, not only the current page), and the filter is in the URL with a working back button
- [ ] **AC-11.5** Given a filter that matches nothing When it is applied Then the grid is replaced by "No cards in your collection match "<query>"." and the count reads "0 of <total> items"
- [ ] **AC-11.6** Given an empty collection When the page renders Then it shows "No cards in your collection yet. Search for a card to start adding." with a link to search, and no filter bar
- [ ] **AC-11.7** Given the grid When it is inspected Then it shows no checkboxes, no view switch and no "Edit many" control (bulk and table views are a later feature)
- [ ] **AC-11.8** (verified in a browser-level test) Given a phone-width page When the collection renders Then the grid shows two columns, the filter bar's search takes the full width, and the page head's `Add items` is hidden in favour of the header's add button (AC-2.8)
- [ ] **AC-11.9** Given a collection tile's printing has been retired from the catalog When the grid renders Then the tile is still shown (owned copies never disappear because of a catalog change)

### Story 12: Collections are private to their account

**As a** collector sharing an instance
**I want** nobody else to see or change my copies
**So that** my collection stays mine

**Acceptance criteria:**

- [ ] **AC-12.1** Given two accounts each with copies When collector A opens their collection, search results or any card page Then only A's copies are counted or listed
- [ ] **AC-12.2** Given a lot belonging to account B When collector A requests its edit form, or submits an update or removal for it Then the response status is 404 and the lot is unchanged
- [ ] **AC-12.3** Given an add, edit or sign-up submission containing an account, user or admin value When it is processed Then those values are ignored and the record belongs to the signed-in collector's account (or, for sign-up, a new non-admin account, except the first user, who is admin per AC-3.2)
- [ ] **AC-12.4** Given every table holding collection data When the schema is inspected Then each has a non-null account reference with a foreign key and an index, and the catalog tables still have none
- [ ] **AC-12.5** Given two requests that would each create the same lot identity (printing + finish + condition + price paid, with unspecified values treated as equal) for one account When both are processed Then the account ends up with one lot holding both quantities, never two lots with the same identity; the data store itself rejects a duplicate identity

## Functional Requirements

### FR-1: Design system installation

**Must:**
- Install the export's stylesheets, fonts, logos, `docs/design-system/`, the `collector-design-system` skill, and its `CLAUDE.md` guidance, which is adapted to this repo's paths and states that the repo copy is updated by re-exporting.
- Load tokens before components on every page; make sure the fonts resolve through the asset pipeline.
- Set the viewport so phone safe areas work, and give the page body the app-shell class.
- Remove feature 002's ad-hoc catalog styles.

**Must not:**
- Hand-edit the generated token stylesheet (tokens change in `tokens.json` and are regenerated).
- Use colour, spacing or font values outside the tokens in app styles.
- Use game-publisher symbols, set symbols or card-frame art as UI decoration.

### FR-2: Authentication and access

**Must:**
- Authenticate users by email (case-insensitive, unique) and a password of at least 12 characters, stored only as a salted hash.
- Require a signed-in user for every page except sign-in, sign-up and the health check; return users to the page they asked for after sign-in.
- Support signing out, which ends only the current session.
- Rate-limit sign-in attempts per email and client address (AC-4.8). The client address honours the forwarded address only from a trusted reverse proxy, which is configured through a documented setting.
- Supersede feature 002 FR-7's "Be public": search, printings and card pages require sign-in.

**Must not:**
- Reveal whether an email is registered in sign-in errors.
- Send email.

### FR-3: Accounts and users

**Must:**
- Give every user exactly one account, created with the user, and make the account the owner of all collection data.
- Mark users as admin or not; the first user on an instance is an admin.
- Keep at least one admin at all times (AC-5.5).
- On user deletion, delete the account, its sessions and all its collection data.

### FR-4: First run and the sign-up setting

**Must:**
- Send every request on an instance with no users, except the health check, to sign-up, which creates the first admin.
- Store an instance-wide sign-up setting (open or closed) that is closed once the first user exists and that admins can change in the app.
- Make creating the first user safe against simultaneous submissions (AC-3.4).
- Provide a documented command that resets a user's password or creates an admin (AC-5.7), usable to create the first admin without the browser (AC-3.6).
- Document the first-visitor-becomes-admin risk in the README's upgrade and install notes (AC-3.5).

### FR-5: User administration

**Must:**
- Let admins list, create, edit (name, email, admin flag, new password) and delete users, and open or close sign-up.
- Require an explicit confirmation before deleting a user, which works without scripting.
- Return 404 to non-admins for every admin page and action.

### FR-6: Collection copies (lots)

**Must:**
- Record copies as lots owned by an account. A lot has:
  - a catalog printing
  - a quantity (1–9,999)
  - a finish (optional)
  - a condition (optional)
  - a price paid per copy (optional; non-negative, at most two decimal places, stored exactly with no rounding)
- Treat printing + finish + condition + price paid as a lot's identity within an account (unspecified equals unspecified). Adding or editing into an existing identity merges quantities (AC-7.4, AC-9.3, AC-10.2), capped at 9,999. The data store enforces the identity's uniqueness (AC-12.5).
- Reference the printing by a relation that survives catalog refreshes (002 never deletes or re-keys entries), and keep lots of retired printings.
- Keep the core collectible-agnostic. The core stores finish and condition as values it doesn't interpret. The collectible's extension supplies:
  - the valid finishes for a printing (MTG: the printing's finishes)
  - which finishes are "special" and get the finish badge (MTG: foil, etched)
  - the condition scale with labels and short forms (MTG: Near mint NM, Lightly played LP, Moderately played MP, Heavily played HP, Damaged DMG)
- Show price paid in one instance-wide currency, set by a documented setting holding an ISO 4217 code (default USD), formatted with that currency's symbol and two decimals (`$1,234.50`). An unrecognised code stops the app at boot with an error naming it. Changing the currency later doesn't convert stored amounts, and the README says so.
- Keep each lot addressable for a future export by the printing's external ID (Scryfall ID), finish, condition and price paid, never by internal IDs.

**Must not:**
- Allow a lot's account to be set from user input.
- Store MTG-specific attributes in core collection tables.

### FR-7: Adding copies

**Must:**
- Provide quick add (one copy, other fields unspecified) from search results, the printings page and the card page's Printings section. With scripting on, it updates the page in place; otherwise it redirects to the local return path it carries (AC-7.3).
- Provide the `Add a copy` form on the card page (Story 9).
- Confirm every add with a status message that screen readers announce.

### FR-8: Editing and removing lots

**Must:**
- Provide per-lot edit and remove from the card page's Your copies section (Story 10), scoped to the signed-in account.
- Require confirmation before removal, in a way that works without scripting.

### FR-9: Card page

**Must:**
- Follow the `ItemPage`/`ItemPagePhone` design with the sections and order in AC-8.1. Leave out the "In decks" and "Free to use" stats, the estimated value, the "In decks" section, "Add to deck" and "Add to wishlist", because those features don't exist yet.
- Keep every feature-002 detail-page behaviour (AC-8.2).
- Show one stat, "Owned" with its printings count (AC-8.4). The stats grid is not laid out 2 × 2 until more stats exist.
- Determine the breadcrumb and current section from an explicit mark in the URL set by collection links (AC-8.9), never from the Referer header.
- Make no outbound network request while rendering.

### FR-10: Collection page

**Must:**
- Follow the `CollectionPage`/`CollectionPagePhone` design with the page head, sticky filter bar and image grid (Story 11). The filter bar has only the name search; the count sits on the line directly beneath it (AC-11.4).
- Keep the filter and page in the URL, with results updating in place and the back button working.
- Paginate at 120 tiles and lazy-load images.

### FR-11: New design-system patterns

**Must:**
- Add, to the design system's component stylesheet and docs (a doc per pattern, listed in the README), any pattern this feature needs that the export lacks, built only from tokens. At least:
  - the search result group (card header plus a tile grid)
  - a tile with an add control outside its link
  - the single finish badge ("Foil", "Etched" or "Foil, etched"), a `foil` fill used at most once per tile, per Badge's rules
  - the logo swap for the operating system's dark theme when the page sets no theme (the export swaps only on an explicit dark theme)
  - the status message, announced by screen readers
  - form layout with per-field error messages
  - a set choice (select) inside the filter bar
  - pagination (previous/next with page position)
  - the empty state
  - the confirmation page used for removals and user deletion when scripting is off
  - the card-page details list
  - a single-stat stats block (the export's stats grid assumes four stats)
  - the More page
  - the sign-in and sign-up form page
  - the admin users list
  - the narrow table action cell holding a row's "…" menu
- Keep the export's rules: `brand` is the only action colour, status colours come with a word or icon, and the copy is sentence case with no emoji or exclamation marks and doesn't say "we".

### FR-12: Responsiveness and accessibility

**Must:**
- Work at every width from 360px, laid out narrow first. The app shell responds to the viewport at 640px; collection and detail content responds to its container.
- Show a visible focus ring on every interactive element in both themes, and keep touch targets at the design system's minimums. (Verified manually at 1280px and 390px, in light and dark, against the previews.)
- Make every hover affordance available by tap, and make every page and action work with scripting disabled. Scripting only enhances ("/" to focus search, in-place updates, closing menus on an outside click).

### FR-13: App shell and navigation

**Must:**
- Show the `AppHeader` on every signed-in page, and the `TabBar` below 640px (viewport), with the sections in AC-2.1/AC-2.2.
- Map pages to sections:
  - Collection: the collection page, and card pages marked as coming from the collection.
  - Search: the search page, printings pages and every other card page.
  - No section: the More page, admin pages, and the sign-in and sign-up pages.
- Keep the current-section marking correct after in-app navigation without a full page load. If the header and tab bar are kept between pages, the marking is updated from the URL (an enhancement); the server-rendered marking is correct on every full load.
- Show only the brand and no navigation on the sign-in and sign-up pages.

### FR-14: Search page

**Must:**
- Follow Story 6: the page title, the sticky filter bar (name and set, GET, results updated in place, state in the URL), the catalog freshness line, and result groups of tiles with owned quantities and add controls.
- Apply the same tiles and controls to the printings page (AC-6.6).
- Keep all of feature 002's search and printings-page behaviours except the parts superseded in AC-6.5.
- Compute owned quantities only from the signed-in account's lots, in a bounded number of queries per page.

## Non-Functional Requirements

### Performance

- The collection page returns in under 500 ms (server time) for an account with 5,000 lots on a typical developer machine. (Verified manually.)
- Search stays under feature 002's 500 ms target with owned quantities added, for an account with 5,000 lots. (Verified manually.)
- Rendering any list makes a bounded number of database queries, independent of the number of tiles or rows.

### Security

- Passwords are stored only as salted hashes, and password fields are filtered from logs.
- The session cookie is HTTP-only and same-site. It is marked secure whenever the request is HTTPS, including behind a TLS-terminating proxy when a documented setting says the instance is served over HTTPS. The README states that signing in over plain HTTP is only acceptable on a trusted private network.
- Every state-changing request is CSRF-protected.
- Every collection query is scoped to the signed-in account. Admin-only actions check admin status on the server.
- Account, user and admin attributes are never mass-assignable from request parameters (AC-12.3).
- User-provided text (names) and catalog text are escaped when rendered.

### Reliability

- Schema changes are reversible and safe to run unattended on boot against a feature-002 database. An upgraded instance starts with no users and follows first-run setup (Story 3).
- Collection data lives in the primary database with the catalog. A catalog refresh never modifies or removes lots.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| Signed-out request to a protected page | Redirect to sign-in; return to the page after sign-in |
| Any request on an instance with no users (except the health check) | Redirect to sign-up (first admin) |
| Health check on an instance with no users | 200 |
| Wrong email or password | 422, "Email or password is incorrect." |
| Too many sign-in attempts for one email from one client address | 429, "Too many attempts. Try again in a few minutes." |
| Sign-up page while closed | 200, closed message, no form |
| Sign-up submitted while closed (including losing the first-user race) | 422, closed message, no user created |
| Add or edit would push a lot past 9,999 copies | 422 with a message; nothing changes |
| `Add a copy` for a printing with no listed finishes | Finish is not offered and stays unspecified |
| Quick-add return path that isn't a path on this instance | Ignored; redirect to the printing's card page |
| Unrecognised currency setting | App refuses to boot, naming the setting and value |
| Invalid sign-up, user or lot fields | 422 with a message per field; nothing saved |
| Non-admin requests admin page or action | 404 |
| Admin deletes self or demotes the last admin | Refused with an explanation; nothing changes |
| Request for another account's lot | 404; lot unchanged |
| Quick add or form for an unknown printing | 404 |
| Quick add for a retired printing | Allowed; the lot is created (copies of retired printings are valid) |
| Card, search or collection page when a printing has no image | No-image fallback (name on sunken surface), never a broken image |
| Collection page number invalid or out of range | 200, first or last page |
| Lot edit collides with another lot's identity | Lots merged (AC-10.2) |

## Open Questions

None. Resolved during specification:
- Accounts: minimal accounts and sign-in in this feature, one user per account.
- Sign-up: first-run admin, a closed-by-default setting the admin can toggle, and user management in the app.
- Copy fields: quantity required; finish, condition and price paid optional.
- Quick add: one copy with the other fields unspecified.
- Lots: merge on identical printing + finish + condition + price paid.
- Lot actions: edit and remove.
- Navigation: Collection and Search.
- Search requires sign-in.
- Grid: one tile per printing.
- No location field.
- No email-based password reset.
- First run (after review): the first visitor stays admin; the health check is exempt; the README warns prominently; and the command can create the first admin instead.
- Rate limit: per email + client address, honouring a trusted proxy.
- Session cookie: secure over HTTPS, with a documented setting for TLS proxies.
- Currency: an instance setting, default USD.
- Self-service profile: out of scope.

## Out of Scope (Future Considerations)

- Table view, view switch saved as a user preference, `Edit many`, bulk mode and undo (next feature).
- Locations (and a location line on tiles), decks, "Free to use", wishlists and the remaining navigation sections, and choosing and reordering sections.
- Quick filters in the collection filter bar (finish, condition, set).
- Market prices and estimated value.
- Collection export and import in a versioned format. This is the next priority after bulk views: until then, admin deletion of a user is the only way collection data can be lost, and its confirmation says so.
- Self-service profile: changing your own name, email or password.
- Designed pips for hybrid, Phyrexian and snow mana.
- Email: password reset, invitations, notifications.
- A theme switch, and instance re-skinning of `brand` tokens.
- Showing other collectors' items on a shared instance.
- Comics and other collectible types.
