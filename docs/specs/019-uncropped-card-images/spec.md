# Feature 019: Fit Card Images Without Cropping

**Status:** Draft
**Version:** 1.1.0
**Created:** 2026-10-11
**Last Updated:** 2026-10-11
**Branch:** `019-uncropped-card-images`
**Issue:** [#35](https://github.com/plainprogrammer/Collector/issues/35)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-10-11 | Initial draft from issue #35 and [research 016](../016-scryfall-hosting-terms/research.md) (sections 4 and 7, ruling 28) |
| 1.1.0 | 2026-10-11 | Spec review revisions (Fable, Mode A). The thumbnail's two boxes differ today (34px with an image, about 33.5px without), so **FR-2** lets the image box take the empty slot's height (AC-3.3). **Testability** says the plan settles how the browser gets test images without the network, with a fallback. **AC-1.4** is a markup check, not a second browser example. **Goal 4**, **AC-4.3** and **AC-4.5** reworded; *shown whole* may be established from natural size, box and computed fit |

---

## Problem Statement

Scryfall's image guidelines say: "Do not cover, crop, or clip off the copyright or artist name on card images. Do not distort, skew, or stretch card images." Collector fits card images into a fixed 63:88 box with a rule that fills the box and cuts off whatever doesn't fit, so an image is cropped whenever its proportions differ from the box's. The table's thumbnail has no fitting rule at all, so it stretches the image to its box.

The damage today is under a pixel, because Scryfall's images are within 0.3% of 63:88. The fault is that the app crops and stretches by design, which breaks a term every instance depends on ([research 016](../016-scryfall-hosting-terms/research.md), section 4) and contradicts the design system's own rule: "never crop an item to fit" (`docs/design-system/README.md`).

> **Inputs.** The design system (`docs/design-system/`, the `c-*` classes, the token variables) and its export arrangement are fixed inputs, so this spec names its files and classes. `components.css`, `tokens.css` and `docs/design-system/` come from the published design system's export and are replaced wholesale on re-export; app patterns live in `app/assets/stylesheets/collector/additions.css`.
>
> **Terms.**
> - A *card image* is a catalog entry's image as served by its source (for Magic, a Scryfall image).
> - A *slot* is the box a page reserves for a card image. There are three: the tile's (`c-tile__media`), the card page's (`c-item__image`, one per face) and the table thumbnail's (`c-table__thumb`).
> - *Shown whole* means every pixel row and column of the image is painted inside the slot. An example may establish this from the image's natural size, the slot's box and the fit the browser computed, without sampling what was painted.
> - *In its own proportions* means the painted image's width divided by its height equals the image file's, within one device pixel.

**What the rules do today** (read from `components.css`; the plan measures each in a browser before changing it):

| Slot | Where it appears | Rule today | Effect when the image isn't 63:88 |
|---|---|---|---|
| `c-tile__media` | Collection grid, search results, scanner candidates | `object-fit: cover` (line 88) | Cropped |
| `c-item__image` | Card page, one per face | `object-fit: cover` (line 249) | Cropped |
| `c-table__thumb` | Collection table | None. The tag's `width="24" height="34"` fix the box at 24×34 (0.706); the image is 0.718 | Stretched about 1.7% taller |

The thumbnail's empty slot (a `span`, shown when there is no image) has no height hint, so it follows 63:88 and is about 33.5px tall: half a pixel shorter than the slot with an image.

## Goals

- In all three slots, a card image is shown whole and in its own proportions, whatever its proportions are.
- That holds in the light and dark themes, at 1280px and at 390px wide.
- The rule survives a re-export of the design system: replacing `components.css` doesn't bring the cropping back, and the suite fails if it does.
- The design system's docs name the override and the three slots it covers, so new image slots follow it.

## Non-Goals

- Changing which image a slot loads (`small`, `normal`, `large`) or its `width` and `height` hints, beyond what stopping the stretch needs (FR-2 names the one size that changes).
- Changing the slot's size or shape per image. Slots stay 63:88 (decision 2).
- Changing the rounded corners (decision 3).
- The attribution line and the unofficial-content notice ([#34](https://github.com/plainprogrammer/Collector/issues/34), spec 018).
- The scanner's camera view (`c-scanner__video`), which fills its stage by design and isn't a card image.
- Publishing a change to the design system or re-exporting it (decision 1).
- Any image slot for comics or other types. They inherit the rule when they're built.

## Decisions

These are the choices issue #35 asks the spec to make. Each is the maintainer's to overrule at approval.

### 1. An override in `additions.css`, not a re-export

The fitting rules are overridden in `additions.css`, in one block of their own, with a pattern doc under `docs/design-system/components/` and a line in the README's app additions.

- A re-export replaces `docs/design-system/` wholesale. Twenty-eight patterns from specs 004, 006, 007 and 015 live only in this repo and aren't upstream yet, so a re-export today would drop their docs and README entries. Upstreaming all of them is a job of its own, far larger than this fix.
- The override sits beside every other app pattern and follows the same arrangement: it is listed for upstreaming, and once the published system fits images this way the override is deleted.
- A re-export can't undo it. `additions.css` isn't part of the export and loads after `components.css`, and the suite checks the fit in a rendered page, so it fails if a future export or reordering brings `cover` back.
- The block is kept separate from the rest of the file so it doesn't collide with spec 018's edits to the same file.

### 2. The whole image inside the 63:88 slot; any leftover shows `surface-sunken`

The slot keeps its 63:88 shape and the image is scaled to fit inside it, centred. Where the image's proportions differ, the leftover strip shows the slot's `surface-sunken` ground, equal on both sides.

- This is what the design system already does for comics: `c-tile--comic` "keeps the same slot as a card (so mixed rows line up) and shows the whole cover inside it, uncropped" (`ItemTile.md`). Cards get the same rule.
- Sizing the slot from the image was the alternative. It would make grid rows uneven, shift the layout as images load, and leave the missing-image fallback with no shape of its own.
- With today's Scryfall images the strip is about a quarter of a pixel at tile size, so nothing visibly changes.

### 3. The rounded corners stay

`radius-card` is 4.75% of the slot's width, the corner of a physical card, so the tile and card-page slots round off only what lies outside the card's own printed corner. The thumbnail's 2px corner is larger in proportion (8.3% of 24px) and trims under one pixel of the card's border at each corner; it stays as it is. No copyright line or artist name is near a corner arc. See the open question.

## Users and Context

**Primary users:** collectors browsing their collection, searching the catalog, opening a card page or confirming a scan.
**Secondary users:** operators, who are bound by the source's terms for every image their instance shows; and whoever builds the next image slot (comics), who needs the rule written down.
**Usage context:** every page that shows a card image, on a phone or a desktop, in either theme.
**User mental model:** "the picture of my card is the card": all of it, the right shape, nothing shaved off.

**Hosted-door rules** ([north star](../../north-star.md#hosted-door-rules)): this closes a gap against the first rule (source terms). It adds no admin page, no setting and no stored data, so the other three don't apply; its cost per account is nil.

## User Stories

### Story 1: Tiles show the whole card

**As a** collector
**I want** each tile in the grid, in search results and among the scanner's candidates to show the whole card image
**So that** nothing on the card is cut off, whatever shape the image is

**Acceptance criteria:**

- [ ] **AC-1.1** Given a lot whose entry's image is wider in proportion than 63:88 (a square image) When the collection grid is rendered Then the tile shows the image whole and in its own proportions, centred in the slot, and the slot is still 63:88
- [ ] **AC-1.2** Given a lot whose entry's image is taller in proportion than 63:88 (a 1:2 image) When the collection grid is rendered Then the tile shows the image whole and in its own proportions, centred in the slot, and the slot is still 63:88
- [ ] **AC-1.3** Given an entry whose image isn't 63:88 When it appears in catalog search results Then its tile shows the image whole and in its own proportions
- [ ] **AC-1.4** Given a scan whose candidate's image isn't 63:88 When the scanner's result is rendered Then the candidate's image sits in the tile slot (`c-tile__media`) with no class or style of its own, so AC-1.3's rule applies to it
- [ ] **AC-1.5** Given a tile whose image leaves part of the slot empty When the page is in the light theme and when it is in the dark theme Then the empty part shows that theme's `surface-sunken`
- [ ] **AC-1.6** Given a collection grid of tiles whose images have different proportions When it is rendered Then every tile's slot has the same width and height as its neighbours in the row
- [ ] **AC-1.7** Given an entry with no image When its tile is rendered Then the missing-image fallback (name and set number on `surface-sunken`) fills the slot as it does today
- [ ] **AC-1.8** Given a tile with a quantity badge, and a tile for a card you don't own When they are rendered Then the badge sits in the slot's top right corner and the unowned tile is faded, as today

### Story 2: The card page shows the whole card

**As a** collector
**I want** the card page to show each face's image whole
**So that** I can read all of the card I'm looking at

**Acceptance criteria:**

- [ ] **AC-2.1** Given an entry whose image isn't 63:88 When its card page is rendered at 1280px wide Then the image is shown whole and in its own proportions, centred in a 63:88 slot
- [ ] **AC-2.2** Given the same entry When its card page is rendered at 390px wide Then the image is shown whole and in its own proportions, and the page doesn't scroll sideways
- [ ] **AC-2.3** Given an entry with two face images of different proportions When its card page is rendered Then each face's image is shown whole and in its own proportions in its own slot
- [ ] **AC-2.4** Given a card page whose image leaves part of the slot empty When the page is in the light theme and when it is in the dark theme Then the empty part shows that theme's `surface-sunken`
- [ ] **AC-2.5** Given an entry with no image When its card page is rendered Then the fallback (the face's name on `surface-sunken`) fills the slot as it does today

### Story 3: The table thumbnail isn't stretched

**As a** collector using the table view
**I want** the thumbnail beside each card's name to be the card in miniature
**So that** it isn't squashed or stretched

**Acceptance criteria:**

- [ ] **AC-3.1** Given a lot whose entry's image is 488×680 (Scryfall's `normal` size) When the collection table is rendered Then the thumbnail's painted image is in the image's own proportions, within one device pixel
- [ ] **AC-3.2** Given a lot whose entry's image isn't 63:88 When the collection table is rendered Then the thumbnail shows the image whole and in its own proportions inside the thumbnail's slot
- [ ] **AC-3.3** Given table rows whose images have different proportions, and a row with no image When the table is rendered at 1280px and at 390px wide Then every thumbnail slot, with or without an image, has the same width and height, and the rows keep one height
- [ ] **AC-3.4** Given a thumbnail whose image leaves part of the slot empty When the page is in the light theme and when it is in the dark theme Then the empty part shows that theme's `surface-sunken`

### Story 4: The design system carries the rule

**As a** maintainer or agent building a view
**I want** the fitting rule written into the design system's docs, and held by the suite
**So that** a re-export or a new image slot doesn't bring cropping back

**Acceptance criteria:**

- [ ] **AC-4.1** Given the repository When `docs/design-system/components/` is listed Then it holds a doc for the image-fitting pattern that names the three slots, states that a card image is shown whole and in its own proportions with the leftover on `surface-sunken`, and says the pattern overrides the export until it is upstreamed
- [ ] **AC-4.2** Given `docs/design-system/README.md` When its app additions are read Then a line for spec 019 names the pattern and says to upstream it
- [ ] **AC-4.3** Given `additions.css` When it is read Then the fitting rules sit in one block of their own under a heading comment that names spec 019, and use no colour literal and no font name, only token variables for both
- [ ] **AC-4.4** Given `components.css` as exported, unchanged by this feature When the suite runs Then the examples for AC-1.1, AC-2.1 and AC-3.2 pass; and when the override block is removed they fail
- [ ] **AC-4.5** Given the pull request When it is opened Then it shows the collection grid, a card page and the collection table with an image that isn't 63:88, each in the light and dark themes at 1280px and 390px wide, from screenshots committed under this spec's `screenshots/`

## Functional Requirements

### FR-1: Fit the image inside its slot

**Must:**
- Show a card image whole and in its own proportions in the tile, card page and thumbnail slots, for an image of any proportions.
- Centre the image in the slot, horizontally and vertically.
- Show the slot's `surface-sunken` ground wherever the image doesn't cover the slot.
- Scale the image down or up to the largest size that fits the slot.

**Must not:**
- Crop, clip, stretch or squash a card image.
- Draw anything over a card image that isn't drawn there today.

### FR-2: Keep the slots as they are

**Must:**
- Keep every slot at 63:88 and at its present size, border and corner radius, with one exception: the thumbnail's image box takes the empty slot's height (63:88 of 24px) in place of its 34px hint, so the two match (AC-3.3).
- Keep the missing-image fallbacks, the quantity badge, the unowned fade, the hover lift and the focus ring unchanged.
- Keep the grid's columns and the table's row height unchanged.

**Must not:**
- Size a slot from its image.
- Shift the layout when an image finishes loading.

### FR-3: Make the change where a re-export can't undo it

**Must:**
- Make the change in `additions.css`, in one block of its own, using only token variables.
- Leave `components.css` and `tokens.css` byte-for-byte as exported.
- Cover each of the three slots with an example that fails if the image is cropped or stretched.

**Must not:**
- Touch any other block of `additions.css`, or the attribution line in `app/views/catalog/entries/show.html.erb`.

### FR-4: Document the pattern

**Must:**
- Add a doc for the pattern under `docs/design-system/components/` and list it in the README's app additions as an override to upstream.

**Must not:**
- Edit the exported component docs (`ItemTile.md`, `ItemPage.md`, `CollectionTable.md`), which a re-export replaces.

## Non-Functional Requirements

### Performance

- No new requests, scripts or images. The change is style rules only.
- No layout shift: a slot has the same size before and after its image loads.

### Security

- No change. Image addresses still pass through `catalog_url`, and no page gains a Content-Security-Policy exception.

### Reliability

- The fit doesn't depend on JavaScript.
- The fit holds in headless Firefox (the suite's browser) and in the phone browser the maintainer uses (WebKit).

### Testability

- AC-1.1 to AC-3.4 are system examples in a real browser, since fitting is decided by the browser's layout: they measure the slot and what the image paints in it, using test images of other proportions (a square one and a 1:2 one). The suite makes no real HTTP request for them.
- These are the first examples to load a card image in the suite's browser. WebMock stops Ruby's requests, not Firefox's, and `catalog_url` passes only `https` addresses on a source's allowed hosts. The plan decides how Firefox receives the test images without the network and proves it in its first task. If no way works, the examples derive the painted rectangle from the image's natural size, the slot's box and the computed fit.
- AC-1.4 is a markup check in a request example, since a browser example would need a scan and adds nothing to AC-1.3.
- 390px-wide examples run in a fixed-width frame, since headless Firefox windows can't be narrower than 500px.
- AC-4.1 to AC-4.3 are file-shape examples. AC-4.4's second half is shown once in the plan's red step. AC-4.5 is evidence in the pull request.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| The image fails to load | The slot keeps its 63:88 shape and `surface-sunken` ground and shows the image's alternative text where the browser provides it; the thumbnail, whose alternative text is empty, shows the empty slot |
| The entry has no image address, or one `catalog_url` rejects | The existing fallback fills the slot (AC-1.7, AC-2.5); the thumbnail shows its empty slot |
| The image is landscape (wider than tall) | Shown whole, full width, centred vertically, with `surface-sunken` above and below |
| The image is smaller than the slot | Scaled up to fit, in its own proportions |
| A re-export replaces `components.css` with `cover` still in it | The override still applies; if it didn't, AC-4.4's examples fail |
| A re-export ships the fix upstream | The override is redundant and harmless; it is removed in that re-export's PR |

## Open Questions

- [NEEDS CLARIFICATION: is the thumbnail's 2px corner acceptable? At 24px wide it rounds 8.3% of the width against the card's own 4.75%, trimming under one pixel of border at each corner. The draft keeps it (decision 3). The alternative is to give the thumbnail the card's own corner, a visible change to an exported style.]

## Out of Scope (Future Considerations)

- **The unowned fade.** `c-tile--owned-none` shows a card you don't own at 45% opacity. Scryfall's guideline also says "Do not blur, sharpen, desaturate, or color-shift card images". Research 016 didn't examine the fade and this spec leaves it alone; whether it needs a ruling is the maintainer's call, as a separate issue.
- Upstreaming this and the earlier app additions into the published design system, and the re-export that follows.
- Sizing a slot from its image on the card page, if comics or oversized items make the leftover strip matter.
