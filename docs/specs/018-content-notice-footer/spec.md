# Feature 018: Content Notice Footer

**Status:** Draft
**Version:** 1.0.0
**Created:** 2026-10-11
**Last Updated:** 2026-10-11
**Branch:** `018-content-notice-footer`
**Issue:** [#34](https://github.com/plainprogrammer/Collector/issues/34)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-11 | Initial draft from issue #34 and [research 016](../016-scryfall-hosting-terms/research.md) (sections 4 and 7, rulings 27–28) |

---

## Problem Statement

Wizards of the Coast's Fan Content Policy asks every piece of Fan Content to carry a notice that it is unofficial. Collector shows Magic card names, text and images and has no such notice anywhere. Its only attribution is one line on the card page ("Card data and images provided by Scryfall."), while the collection grid and table, search results and the scanner show the same card images with none. [Research 016](../016-scryfall-hosting-terms/research.md) lists both as gaps that apply to every instance, including a private family one, and the maintainer ruled that a footer on every page closes them (roadmap ruling 28).

> **Inputs.** The policy's wording, Scryfall's guidelines and the gaps come from research 016. The catalog boundary ([ADR 0018](../../adr/0018-collectible-agnostic-catalog-core.md)), the source contract (`Catalog::Sources`), the scanner pages' Content-Security-Policy (spec 007 AC-2.4, `ScannerPage`) and the design system are fixed inputs, so this spec names them.

### Glossary

- **Page:** an HTML document the app renders for a browser with the application layout: every signed-in page, the sign-in and first-run registration pages, the admin pages and the scanner pages (measurement mode included).
- **Catalog type:** a kind of collectible with a registered catalog source (today only `mtg`).
- **Content notice:** the text a catalog type supplies for the footer. It has two kinds of line: a **rights notice** (what the content's owner asks to be shown) and a **source attribution** (who provides the data).
- **Core:** code outside a collectible's namespace (ADR 0018).

## Goals

- Every page carries the Fan Content Policy's notice and the Scryfall attribution, in one consistent place.
- The notice text belongs to the Magic catalog type. The core renders whatever the registered types supply and names no collectible, source or rights holder.
- A second catalog type adds its own notice without a change to the core.
- The footer renders correctly under the scanner pages' Content-Security-Policy.
- The footer is a documented design-system pattern.

## Non-Goals

- Fitting card images without cropping (issue #35, spec 019).
- Opening the catalog to signed-out visitors (issue #59).
- An about, licence or credits page.
- Letting an operator or collector edit, hide or translate the notice.
- Showing the notice only where card content appears. It is on every page.
- Attribution inside individual tiles, rows or scanner results.
- The static error pages in `public/`, emails, and responses that aren't a full page (Turbo Frame and Turbo Stream answers, JSON, the health check, the OCR and art-index assets).

## Users and Context

**Primary users:** anyone who opens a page of an instance: collectors, admins, and a visitor at the sign-in page.
**Secondary users:** the instance's operator, who is the one publishing Fan Content and needs the notice to be there without doing anything; a contributor adding a second collectible type.
**Usage context:** read rarely and never acted on. It sits at the end of every page, after the page's own content, on phones and wide screens.
**User mental model:** the small print at the bottom of a site. It must be findable and legible, and must not compete with the page.

## User Stories

### Story 1: The notice and attribution are on every page

**As an** operator of an instance
**I want** every page to carry the unofficial-content notice and the source attribution
**So that** the instance meets Wizards' Fan Content Policy and credits Scryfall wherever card content can appear

**Acceptance criteria:**

- [ ] **AC-1.1** Given the `mtg` catalog type is registered When a signed-in collector opens the collection page (grid or table), catalog search, a card page, an identity page, the scanner page, the More page, or a lot's add, edit or removal page Then the page contains, in a footer landmark after the page's main content, the text "Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."
- [ ] **AC-1.2** Given the same When any of those pages is opened Then the same footer contains the text "Card data and images provided by Scryfall."
- [ ] **AC-1.3** Given a signed-out visitor When they open the sign-in page, or the first-run registration page on a new instance Then the footer is present with both texts.
- [ ] **AC-1.4** Given a signed-in admin When they open the admin users, admin catalog or admin jobs pages Then the footer is present with both texts.
- [ ] **AC-1.5** Given the `mtg` catalog has never been loaded (no applied refresh run) When any page is opened Then the footer is present with both texts.
- [ ] **AC-1.6** Given any page When it is rendered Then the footer appears exactly once, and each line of the notice appears exactly once in it.
- [ ] **AC-1.7** Given a card page When it is opened Then "Card data and images provided by Scryfall." appears once on the page, in the footer, and no longer in the card's body.
- [ ] **AC-1.8** Given a request that answers with something other than a full page (a Turbo Frame or Turbo Stream answer, the health check) When it is rendered Then the response contains no footer.

### Story 2: The notice belongs to the collectible type

**As a** contributor adding a second collectible type
**I want** the footer's text to come from each registered catalog type
**So that** my type shows its own notice and attribution without a change to the core, and the core never names Magic, Wizards or Scryfall

**Acceptance criteria:**

- [ ] **AC-2.1** Given a second catalog type is registered whose source supplies a rights notice and a source attribution When any page is opened Then the footer shows the `mtg` type's lines and the second type's lines, grouped by type, in the order the types are registered.
- [ ] **AC-2.2** Given a registered catalog type whose source supplies no content notice When any page is opened Then the footer shows the other types' lines and nothing for that type, and the page renders without error.
- [ ] **AC-2.3** Given no registered catalog type supplies a content notice When any page is opened Then the page has no footer element at all (no empty landmark).
- [ ] **AC-2.4** Given two registered catalog types supply an identical line When any page is opened Then that line appears once.
- [ ] **AC-2.5** Given the core's footer code (the layout, the footer's partial, and whatever helper or model collects the notices) When it is searched for "mtg", "magic", "wizards", "scryfall" and "fan content", case-insensitively Then none is found. An automated check enforces this, as `spec/admin_catalog_core_spec.rb` does for the admin catalog page.
- [ ] **AC-2.6** Given `app/views/catalog/entries/show.html.erb` When it is searched for the attribution sentence Then it is not found. (The page's "View on Scryfall" menu link is a known exception recorded in ADR 0018 and is not changed here.)

### Story 3: The footer fits the page on every screen

**As a** collector
**I want** the footer to be legible small print at the end of the page that never covers or is covered by anything
**So that** it is there when I look for it and out of the way when I don't

**Acceptance criteria:**

- [ ] **AC-3.1** Given a viewport 390px wide, where the tab bar is fixed to the bottom When a page with the tab bar is scrolled to its end Then the whole footer is visible above the tab bar, with none of its text under the bar.
- [ ] **AC-3.2** Given a viewport 360px wide When any page is opened Then the footer's text wraps inside the page gutter with no horizontal scrolling.
- [ ] **AC-3.3** Given a viewport 1280px wide When a page whose content is shorter than the viewport is opened (the sign-in page) Then the footer follows the content in normal flow; it is not fixed or sticky and never overlaps content on any page.
- [ ] **AC-3.4** Given the light theme and the dark theme When the footer is rendered Then its text holds at least 4.5:1 contrast against its background in both.
- [ ] **AC-3.5** Given the footer When it is rendered Then it contains text only: no image, logo, icon, set symbol or other mark of Wizards of the Coast or Scryfall, and no interactive element.
- [ ] **AC-3.6** Given the collection page with its sticky filter bar, and the collection table in bulk mode with its bulk bar When the page is scrolled to its end Then the footer is fully visible and neither bar overlaps it.
- [ ] **AC-3.7** Given the design system's documentation When this feature is merged Then `docs/design-system/components/` has a document for the footer pattern (markup, where the layout renders it, its rules), and the README's Components section lists it among the app additions for spec 018.

### Story 4: The footer renders under the scanner's Content-Security-Policy

**As a** collector scanning cards
**I want** the scanner pages to carry the same footer
**So that** the pages that show card images from a camera carry the notice too, without weakening their policy

**Acceptance criteria:**

- [ ] **AC-4.1** Given the scanner page, which sends a Content-Security-Policy When it is opened in a browser Then the footer is displayed with both texts, styled as on other pages, and the browser reports no Content-Security-Policy violation.
- [ ] **AC-4.2** Given the scanner page When its response is compared with today's Then its Content-Security-Policy header is unchanged: the footer adds no source, directive or nonce use.
- [ ] **AC-4.3** Given measurement mode is enabled (development only) When the measurement page or its replay page, the other two pages that send the scanner's policy, is opened Then the footer is present with both texts and the policy header is unchanged.
- [ ] **AC-4.4** Given a phone-width viewport on the scanner page with the camera view and the sitting list showing When the page is scrolled to its end Then the footer is visible above the tab bar and overlaps neither the camera view nor the scanner's controls.

## Functional Requirements

### FR-1: A content notice per catalog type

A catalog type's source may supply a content notice: zero or more rights-notice lines and zero or more source-attribution lines, as plain text. Supplying one is optional, like the source contract's other optional hooks.

**Must:**
- The `mtg` type supplies one rights notice, the Fan Content Policy's wording with "Collector" as the title, exactly: "Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."
- The `mtg` type supplies one source attribution, exactly: "Card data and images provided by Scryfall."
- The notice is the same for every request: it doesn't depend on the account, the user, whether the catalog is loaded, or instance settings.
- The contract's documentation (`app/models/catalog/sources.rb`) describes the hook.

**Must not:**
- Contain markup. Lines are plain text and are escaped when rendered.
- Read the database, the network or the file system to produce the notice.
- Alter the policy's wording beyond replacing "[Title of your Fan Content]" with "Collector".

### FR-2: The footer on every page

The application layout renders one footer on every page, collecting the content notices of all registered catalog types.

**Must:**
- Sit after the page's main content, as the page's footer landmark (`contentinfo`).
- Group lines by catalog type in registration order; within a type, rights notices come before source attributions.
- Show each distinct line once.
- Be absent (no element) when no type supplies a notice.
- Render with no JavaScript, and be unaffected by Turbo navigation between pages (present after a Drive visit, a morph refresh and a restored Back visit).

**Must not:**
- Name a collectible, source or rights holder in core code (AC-2.5).
- Be rendered by each page separately. A new page gets the footer without doing anything.
- Run a database query.

### FR-3: The card page's attribution moves to the footer

**Must:**
- Remove the attribution line from the card page's body (AC-1.7, AC-2.6).
- Remove the `c-attribution` rule from `collector/additions.css` if nothing else uses it once the line is gone, or reuse it for the footer; either way no unused rule is left.

**Must not:**
- Change anything else on the card page. Its image rules belong to spec 019.

### FR-4: Presentation

**Must:**
- Use only design-system tokens and `c-*` classes; new rules go in `collector/additions.css` in one block of their own for this spec.
- Read as small print: `ink-muted` text at caption size, set apart from the content above it by space or a `line` divider, aligned to the page gutter (`space-8` wide, `space-4` below 640px).
- Follow the app shell's viewport breakpoint, since the footer is part of the shell.
- Have a component document and a README entry (AC-3.7).

**Must not:**
- Use `brand`, a category colour, `foil`, or a status colour.
- Include a logo, image or icon (Scryfall's guidelines forbid implying its endorsement; the design system forbids a game's marks as decoration).
- Be fixed or sticky.

## Non-Functional Requirements

### Performance

- The footer adds no database query, no HTTP request and no asset beyond the stylesheet pages already load.

### Security

- The scanner pages' Content-Security-Policy is unchanged (AC-4.2). The footer uses no inline script, no inline event handler and no external resource.
- Notice lines are escaped as text. No `html_safe` or `raw`.

### Reliability

- A source without the hook, or one that returns nothing, never breaks a page (AC-2.2, AC-2.3).

### Accessibility

- One footer landmark per page. Text at 4.5:1 or better in both themes (AC-3.4). No new tab stop.

### Hosted-door rules

- **Source terms allow hosting:** this closes two of research 016's gaps (no unofficial-content notice; attribution on the card page only), which the ruling makes a condition of Scryfall passing the rule.
- **The operator is not the user:** no admin page changes what it shows of a collection.
- **Collector choices are stored per account or user:** no setting or environment variable is added.
- **Bounded cost per account:** none. Nothing is stored and no background work is added.

### Testability

- AC-1.1 to AC-1.8, AC-2.1 to AC-2.4 and AC-4.2 to AC-4.3 are request or view examples in the suite; AC-2.1 to AC-2.4 register a test-only catalog type or source.
- AC-2.5 and AC-2.6 are file-content examples.
- AC-3.1, AC-3.2, AC-3.6, AC-4.1 and AC-4.4 are system examples in headless Firefox (phone widths in a fixed-width frame, since the browser's window can't go below 500px), or screenshots in the PR where a layout can't be asserted.
- AC-3.3 to AC-3.5 are checked by a suite example where one can assert them (AC-3.5: the footer contains no `img`, `svg`, `a` or `button`), and otherwise by screenshots at 1280px and 390px in light and dark.
- AC-3.7 is checked in review.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A registered source doesn't implement the content-notice hook | It contributes nothing; other types' lines show (AC-2.2) |
| A source's notice has no lines, or only blank ones | It contributes nothing; blank lines are never rendered |
| No registered type supplies a notice | No footer element (AC-2.3) |
| No catalog type is registered at all | No footer element; pages render as today |
| The catalog isn't loaded, or its last refresh failed | The footer is unchanged (AC-1.5); it never depends on catalog data |
| A notice line contains `<`, `&` or quotes | It is shown as text, escaped |
| A page is rendered inside the scanner's policy | The footer renders and the policy is unchanged (AC-4.1, AC-4.2) |

## Open Questions

- [NEEDS CLARIFICATION: **Links.** Should "Fan Content Policy" link to Wizards' policy page and "Scryfall" to scryfall.com? The draft says plain text with no interactive element (AC-3.5, FR-2): it adds no tab stop to every page, needs no markup in a type's notice, and can't be read as an endorsement. Links would mean the notice carries structured link data instead of plain lines.]
- [NEEDS CLARIFICATION: **`README.md`.** Its attribution line (line 311) credits Wizards and Scryfall but doesn't carry the policy's notice. Add the notice there in this PR, or leave the README alone? The draft leaves it out of scope: the README isn't a page of the app.]

## Out of Scope (Future Considerations)

- Card images fitted without cropping (issue #35, spec 019), which shares `collector/additions.css` and the card page with this spec.
- Browsing the catalog without signing in (issue #59). When it lands, its pages get the footer from the layout with no further work.
- Removing the card page's "View on Scryfall" link from core code (a known exception in ADR 0018).
- A notice on the static error pages, which are served without the app.
- Upstreaming the footer pattern into the published design system (it joins the list of app additions awaiting the next export).
- A per-type notice for comics, written with the comics type.
