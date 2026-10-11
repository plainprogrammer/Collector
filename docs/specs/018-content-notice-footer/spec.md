# Feature 018: Content Notice Footer

**Status:** Draft
**Version:** 1.2.1
**Created:** 2026-10-11
**Last Updated:** 2026-10-11
**Branch:** `018-content-notice-footer`
**Issue:** [#34](https://github.com/plainprogrammer/Collector/issues/34)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-11 | Initial draft from issue #34 and [research 016](../016-scryfall-hosting-terms/research.md) (sections 4 and 7, rulings 27–28) |
| 1.1.0 | 2026-10-11 | Spec review revisions (Fable, Mode A, NEEDS REVISION, nothing blocking). **Scanner policy:** the nonce differs per request, so AC-4.2 compares directives and sources, and AC-4.1 asserts the footer's applied style instead of a violation report. **Short pages:** the footer sits directly after the content, not pushed to the viewport's bottom (AC-3.3). **Lines:** a type supplies its lines in display order; they render one per paragraph with no heading, and a repeated line stays with the first type (FR-1, FR-2, AC-2.1, AC-2.4). **Pages:** the rule is every response rendered with the application layout, including re-rendered forms; a frame answer is one requested with a `Turbo-Frame` header (glossary, AC-1.1, AC-1.3, AC-1.6, AC-1.8). **Also:** ADR 0018's consequence is updated (FR-3); the text style is named (FR-4); a hook that raises isn't rescued (Error Scenarios) |
| 1.2.0 | 2026-10-11 | Maintainer rulings, relayed by the coordinator. **Links:** "Fan Content Policy" links to Wizards' policy page and "Scryfall" to scryfall.com, so a notice line carries link data (glossary, AC-1.9, AC-1.10, AC-2.7, AC-3.5, AC-3.8, AC-4.1, FR-1, FR-2, FR-4, Accessibility, Security, Error Scenarios). The core still names no collectible, there is still no logo, and the wording doesn't change. **`README.md`** is left out of this PR (Out of Scope). Open Questions is now empty |
| 1.2.1 | 2026-10-11 | Second review pass (Fable, Mode A, NEEDS REVISION, nothing blocking; wording only). A link's phrase is matched exactly, occurs once and overlaps no other, and its address is an absolute `https` URI (FR-1, Security, Error Scenarios); how two lines compare as identical (AC-2.4); the system example asserts a link's `href` and doesn't follow it (AC-4.1); a footer link is a brand link at the line's own weight with no `target` (AC-3.8); inline links keep the line's height (FR-4); `rel="noopener"` is kept only for parity (FR-2); AC-3.8 moved below AC-3.7; tab stops per type (Accessibility) |

---

## Problem Statement

Wizards of the Coast's Fan Content Policy asks every piece of Fan Content to carry a notice that it is unofficial. Collector shows Magic card names, text and images and has no such notice anywhere. Its only attribution is one line on the card page ("Card data and images provided by Scryfall."), while the collection grid and table, search results and the scanner show the same card images with none. [Research 016](../016-scryfall-hosting-terms/research.md) lists both as gaps that apply to every instance, including a private family one, and the maintainer ruled that a footer on every page closes them (roadmap ruling 28).

> **Inputs.** The policy's wording, Scryfall's guidelines and the gaps come from research 016. The catalog boundary ([ADR 0018](../../adr/0018-collectible-agnostic-catalog-core.md)), the source contract (`Catalog::Sources`), the scanner pages' Content-Security-Policy (spec 007 AC-2.4, `ScannerPage`) and the design system are fixed inputs, so this spec names them.

### Glossary

- **Page:** any response rendered with the application layout: every signed-in page, the sign-in page, the sign-up page (first-run or open), the admin pages and the scanner pages (measurement mode included), and a form re-rendered after a failed submission (422 or 429).
- **Catalog type:** a kind of collectible with a registered catalog source (today only `mtg`).
- **Content notice:** the lines a catalog type supplies for the footer, in the order they are shown. A line is plain text, and may name **links**: a phrase of the line and the `https` address it leads to. For `mtg` they are a rights notice (what the content's owner asks to be shown) and a source attribution (who provides the data).
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
**Usage context:** read rarely; its only actions are the two links. It sits at the end of every page, after the page's own content, on phones and wide screens.
**User mental model:** the small print at the bottom of a site. It must be findable and legible, and must not compete with the page.

## User Stories

### Story 1: The notice and attribution are on every page

**As an** operator of an instance
**I want** every page to carry the unofficial-content notice and the source attribution
**So that** the instance meets Wizards' Fan Content Policy and credits Scryfall wherever card content can appear

**Acceptance criteria:**

- [ ] **AC-1.1** Given the `mtg` catalog type is registered When a signed-in collector opens the collection page (grid or table), catalog search, a card page, an identity page, the scanner page, the More page, or a lot's add, edit or removal page (a representative list; the rule is every page, as the glossary defines it) Then the page contains, in a footer landmark after the page's main content, the text "Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."
- [ ] **AC-1.2** Given the same When any of those pages is opened Then the same footer contains the text "Card data and images provided by Scryfall."
- [ ] **AC-1.3** Given a signed-out visitor When they open the sign-in page, or the sign-up page (first-run on a new instance, or open sign-up) Then the footer is present with both texts.
- [ ] **AC-1.4** Given a signed-in admin When they open the admin users, admin catalog or admin jobs pages Then the footer is present with both texts.
- [ ] **AC-1.5** Given the `mtg` catalog has never been loaded (no applied refresh run) When any page is opened Then the footer is present with both texts.
- [ ] **AC-1.6** Given any page, including a form re-rendered with 422 or 429 When it is rendered Then the footer appears exactly once, and each line of the notice appears exactly once in it.
- [ ] **AC-1.7** Given a card page When it is opened Then "Card data and images provided by Scryfall." appears once on the page, in the footer, and no longer in the card's body.
- [ ] **AC-1.8** Given a request that isn't answered with the application layout (a request carrying a `Turbo-Frame` header, a Turbo Stream answer, the health check) When it is rendered Then the response contains no footer. The same address requested without the `Turbo-Frame` header is a page and carries it.
- [ ] **AC-1.9** Given any page When its footer is read Then the words "Fan Content Policy" in the notice are a link to `https://company.wizards.com/en/legal/fancontentpolicy`, and no other part of that line is a link.
- [ ] **AC-1.10** Given any page When its footer is read Then the word "Scryfall" in the attribution is a link to `https://scryfall.com`, and no other part of that line is a link.

### Story 2: The notice belongs to the collectible type

**As a** contributor adding a second collectible type
**I want** the footer's text to come from each registered catalog type
**So that** my type shows its own notice and attribution without a change to the core, and the core never names Magic, Wizards or Scryfall

**Acceptance criteria:**

- [ ] **AC-2.1** Given a second catalog type is registered whose source supplies two lines When any page is opened Then the footer shows the `mtg` type's lines and then the second type's lines: types in the order they are registered, each type's lines in the order it supplies them.
- [ ] **AC-2.2** Given a registered catalog type whose source supplies no content notice When any page is opened Then the footer shows the other types' lines and nothing for that type, and the page renders without error.
- [ ] **AC-2.3** Given no registered catalog type supplies a content notice When any page is opened Then the page has no footer element at all (no empty landmark).
- [ ] **AC-2.4** Given two registered catalog types supply an identical line (the same text, character for character after trimming surrounding whitespace, and the same phrase-to-address links) When any page is opened Then that line appears once, in the position of the first type that supplies it.
- [ ] **AC-2.5** Given the core's footer code (the layout, the footer's partial, and whatever helper or model collects the notices) When it is searched for "mtg", "magic", "wizards", "scryfall" and "fan content", case-insensitively Then none is found, in text or in an address. An automated check enforces this, as `spec/admin_catalog_core_spec.rb` does for the admin catalog page.
- [ ] **AC-2.6** Given `app/views/catalog/entries/show.html.erb` When it is searched for the attribution sentence Then it is not found. (The page's "View on Scryfall" menu link is a known exception recorded in ADR 0018 and is not changed here.)
- [ ] **AC-2.7** Given a second catalog type whose source supplies a line with a link, and one supplying a line with none When any page is opened Then the first line's phrase is a link to its address and the second line is text only.

### Story 3: The footer fits the page on every screen

**As a** collector
**I want** the footer to be legible small print at the end of the page that never covers or is covered by anything
**So that** it is there when I look for it and out of the way when I don't

**Acceptance criteria:**

- [ ] **AC-3.1** Given a viewport 390px wide, where the tab bar is fixed to the bottom When a page with the tab bar is scrolled to its end Then the whole footer is visible above the tab bar, with none of its text under the bar.
- [ ] **AC-3.2** Given a viewport 360px wide When any page is opened Then the footer's text wraps inside the page gutter with no horizontal scrolling.
- [ ] **AC-3.3** Given a viewport 1280px wide When a page whose content is shorter than the viewport is opened (the sign-in page) Then the footer sits directly after the content, not pushed to the bottom of the viewport; it is never fixed or sticky and never overlaps content on any page.
- [ ] **AC-3.4** Given the light theme and the dark theme When the footer is rendered Then its text holds at least 4.5:1 contrast against its background in both.
- [ ] **AC-3.5** Given the footer When it is rendered Then it contains text and the links its lines name, and nothing else: no image, logo, icon, set symbol or other mark of Wizards of the Coast or Scryfall, and no button or form control.
- [ ] **AC-3.6** Given the collection page with its sticky filter bar, and the collection table in bulk mode with its bulk bar When the page is scrolled to its end Then the footer is fully visible and neither bar overlaps it.
- [ ] **AC-3.7** Given the design system's documentation When this feature is merged Then `docs/design-system/components/` has a document for the footer pattern (markup, where the layout renders it, its rules), and the README's Components section lists it among the app additions for spec 018.
- [ ] **AC-3.8** Given a footer link When it is rendered, hovered and focused with the keyboard Then it is a brand link at the line's own weight, as `c-crumbs` links are (`brand` colour, no underline until hovered, the 2px `focus` ring), holds at least 4.5:1 contrast in both themes, and has no `target` attribute, so it opens in the same tab.

### Story 4: The footer renders under the scanner's Content-Security-Policy

**As a** collector scanning cards
**I want** the scanner pages to carry the same footer
**So that** the pages that show card images from a camera carry the notice too, without weakening their policy

**Acceptance criteria:**

- [ ] **AC-4.1** Given the scanner page, which sends a Content-Security-Policy When it is opened in a browser Then the footer is displayed with both texts and its stylesheet rule applied (its computed colour is the `ink-muted` token's), its markup carries no inline style or script and loads no external resource, and each link's `href` is its address (no directive of the policy governs following a link, so nothing more is asserted and the example doesn't follow it).
- [ ] **AC-4.2** Given the scanner page When it is requested Then its Content-Security-Policy has exactly the directives and sources spec 007 AC-2.4 lists (the nonce's value differs per request): the footer adds no directive, source or nonce use.
- [ ] **AC-4.3** Given measurement mode is enabled (development only) When the measurement page or its replay page, the other two pages that send the scanner's policy, is opened Then the footer is present with both texts and the policy is as AC-4.2 states.
- [ ] **AC-4.4** Given a phone-width viewport on the scanner page with the camera view and the sitting list showing When the page is scrolled to its end Then the footer is visible above the tab bar and overlaps neither the camera view nor the scanner's controls.

## Functional Requirements

### FR-1: A content notice per catalog type

A catalog type's source may supply a content notice: zero or more lines, in the order they are shown. A line is plain text with zero or more links, each a phrase that occurs in the line and an `https` address. Supplying one is optional, like the source contract's other optional hooks. The core doesn't know what kind of line each is, or where its links lead.

**Must:**
- The `mtg` type supplies two lines. First, the Fan Content Policy's wording with "Collector" as the title, exactly: "Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC." Its link: "Fan Content Policy" to `https://company.wizards.com/en/legal/fancontentpolicy`.
- Second, the source attribution, exactly: "Card data and images provided by Scryfall." Its link: "Scryfall" to `https://scryfall.com`.
- The notice is the same for every request: it doesn't depend on the account, the user, whether the catalog is loaded, or instance settings.
- A link's phrase is matched exactly and case-sensitively, occurs exactly once in its line, and overlaps no other phrase of that line. A line that breaks either rule is shown as text with no links.
- The contract's documentation (`app/models/catalog/sources.rb`) describes the hook.

**Must not:**
- Contain markup. A line's text and its link phrases are plain text and are escaped when rendered; the core builds the link.
- Imply endorsement. A link's phrase is the name alone ("Scryfall", "Fan Content Policy"); no "powered by", "partner" or "official".
- Read the database, the network or the file system to produce the notice.
- Alter the policy's wording beyond replacing "[Title of your Fan Content]" with "Collector".

### FR-2: The footer on every page

The application layout renders one footer on every page, collecting the content notices of all registered catalog types.

**Must:**
- Sit after the page's main content, as the page's footer landmark (`contentinfo`).
- Show types in registration order and each type's lines in the order it supplies them.
- Render one line per paragraph, with no heading and no type name; grouping is only the order.
- Show each distinct line once, where the first type that supplies it puts it.
- Be absent (no element) when no type supplies a notice.
- Render each link a line names as a link on its phrase, with no `target` (same tab) and with `rel="noopener"`, which is inert on a same-tab link and kept to match the card page's "View on Scryfall" link.
- Render with no JavaScript, and be unaffected by Turbo navigation between pages (present after a Drive visit, a morph refresh and a restored Back visit).

**Must not:**
- Name a collectible, source or rights holder in core code (AC-2.5).
- Be rendered by each page separately. A new page gets the footer without doing anything.
- Run a database query.

### FR-3: The card page's attribution moves to the footer

**Must:**
- Remove the attribution line from the card page's body (AC-1.7, AC-2.6).
- Remove the `c-attribution` rule from `collector/additions.css` if nothing else uses it once the line is gone, or reuse it for the footer; either way no unused rule is left.
- Update ADR 0018's consequence: the card page's attribution is no longer a core exception, and the footer's check (AC-2.5) joins `spec/admin_catalog_core_spec.rb` as a guard. The "View on Scryfall" link remains the exception.

**Must not:**
- Change anything else on the card page. Its image rules belong to spec 019.

### FR-4: Presentation

**Must:**
- Use only design-system tokens and `c-*` classes; new rules go in `collector/additions.css` in one block of their own for this spec.
- Read as small print: `ink-muted` text at the size of the line it replaces (12px on a 16px line, IBM Plex Sans 400), set apart from the content above it by space or a `line` divider, aligned to the page gutter (`space-8` wide, `space-4` below 640px).
- Follow the app shell's viewport breakpoint, since the footer is part of the shell.
- Have a component document and a README entry (AC-3.7). The document states that the footer's inline links keep the line's height, as `StatusMessage` and breadcrumb links do; the design system's 44px touch rule is applied to buttons and inputs.

**Must not:**
- Use a category colour, `foil`, or a status colour, or use `brand` for anything but a link.
- Include a logo, image or icon (Scryfall's guidelines forbid implying its endorsement; the design system forbids a game's marks as decoration).
- Be fixed or sticky.

## Non-Functional Requirements

### Performance

- The footer adds no database query, no HTTP request and no asset beyond the stylesheet pages already load.

### Security

- The scanner pages' Content-Security-Policy is unchanged (AC-4.2). The footer uses no inline script, no inline event handler and no external resource.
- Notice text and link phrases are escaped. No `html_safe` or `raw` on them.
- A link's address is rendered only when it is an absolute URI whose scheme is `https` (case-insensitively); anything else (`javascript:`, `http:`, a relative path) is never put in an `href`.

### Reliability

- A source without the hook, or one that returns nothing, never breaks a page (AC-2.2, AC-2.3).

### Accessibility

- One footer landmark per page. Text at 4.5:1 or better in both themes (AC-3.4). The `mtg` type's two links add two tab stops to every page, after the page's main content; another type's links add theirs. Each shows the `focus` ring.

### Hosted-door rules

- **Source terms allow hosting:** this closes two of research 016's gaps (no unofficial-content notice; attribution on the card page only), which the ruling makes a condition of Scryfall passing the rule.
- **The operator is not the user:** no admin page changes what it shows of a collection.
- **Collector choices are stored per account or user:** no setting or environment variable is added.
- **Bounded cost per account:** none. Nothing is stored and no background work is added.

### Testability

- AC-1.1 to AC-1.10, AC-2.1 to AC-2.4, AC-2.7 and AC-4.2 to AC-4.3 are request or view examples in the suite; AC-2.1 to AC-2.4 and AC-2.7 register a test-only catalog type or source.
- AC-2.5 and AC-2.6 are file-content examples.
- AC-3.1, AC-3.2, AC-3.6, AC-4.1 and AC-4.4 are system examples in headless Firefox (phone widths in a fixed-width frame, since the browser's window can't go below 500px), or screenshots in the PR where a layout can't be asserted.
- AC-3.3 to AC-3.5 and AC-3.8 are checked by a suite example where one can assert them (AC-3.5: the footer contains no `img`, `svg`, `button` or form control, and only the links its lines name; AC-3.8: the link's class and attributes), and otherwise by screenshots at 1280px and 390px in light and dark.
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
| A link's address isn't `https` | The line is shown as text with no link |
| A link's phrase doesn't occur in its line, or occurs more than once | The line is shown as text with no link |
| Two links' phrases overlap in one line | The line is shown as text with no link |
| Two types supply the same text with different links | Both lines are shown; they are distinct lines |
| A collector follows a footer link from the scanner mid-sitting | The page is left as by any link: the camera stops, and the sitting is still there on return (spec 009 AC-3.3) |
| A source's hook raises | It is a bug in that source. The core doesn't rescue it, and the page fails as any view error does |
| A page is rendered inside the scanner's policy | The footer renders and the policy is unchanged (AC-4.1, AC-4.2) |

## Open Questions

None. The two questions of the draft were ruled on by the maintainer on 2026-10-11 (changelog 1.2.0): the footer links both names, and `README.md` is left alone.

## Out of Scope (Future Considerations)

- Card images fitted without cropping (issue #35, spec 019), which shares `collector/additions.css` and the card page with this spec.
- Browsing the catalog without signing in (issue #59). When it lands, its pages get the footer from the layout with no further work.
- Adding the policy's notice to `README.md`, whose attribution line credits Wizards and Scryfall (maintainer's ruling: not in this PR).
- Removing the card page's "View on Scryfall" link from core code (a known exception in ADR 0018).
- A notice on the static error pages, which are served without the app.
- Upstreaming the footer pattern into the published design system (it joins the list of app additions awaiting the next export).
- A per-type notice for comics, written with the comics type.
