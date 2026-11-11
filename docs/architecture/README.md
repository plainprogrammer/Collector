# Architecture

One area doc per subsystem holds the current truth about it: its terms, the rules that always hold, its states, its named constants and why they have their values, and the decisions not recorded in an ADR. Each statement names the spec criterion, ADR or issue behind it. When an area doc and an older spec disagree, the area doc is right: specs record what a feature promised when it shipped, and freeze once an area doc covers them (see the [specs index](../specs/README.md)).

Lasting decisions are in [ADRs](../adr/README.md). What an agent needs before it knows where to look stays in [CLAUDE.md](../../CLAUDE.md).

The area docs and the numbered ADRs are also pages of the generated API documentation: `bin/yard doc` writes it to `doc/` (spec 054, [ADR 0027](../adr/0027-yard-for-api-documentation.md)), turning the relative links below into links between pages. The files keep plain relative links. Known limits (spec 054): a link to a heading that matches no heading of the target page is passed through unchanged, so it may not land on the heading in the site (decision 6); `@see file:<name>.md` naming a page that doesn't exist renders a dead link and is not caught; `bin/yard doc` doesn't clear `doc/`, so a page whose source was deleted leaves its generated file behind until `doc/` is removed; links with a title, angle-bracket targets, reference-style links, `~~~` fences and root-absolute links (`/foo.md`) are not rewritten (none occurs in the docs today).

## Areas

| Area | Doc | Specs it covers | Reference docs |
|---|---|---|---|
| Catalog operations | [catalog-operations.md](catalog-operations.md) | 002 FR-3–FR-6 and their Error Scenarios rows; 011 FR-2 (the build's run); 015; 024 | none |
| Catalog core | [catalog-core.md](catalog-core.md) | 002 FR-1, FR-2, FR-7–FR-10 (FR-9's convention stays in the rules); 004 (search, the card page's catalog content, the collecting vocabulary); 007 (FR-4's name index and name matching, FR-5, AC-3.4, AC-3.5, AC-3.9); 009 AC-6.1; 016; 018; 019; 023; 057 (decision 12's wording only: the design system is the project's own) | none |
| Collection and lots | [collection-and-lots.md](collection-and-lots.md) | 004 (collection, adding cards); 006; 021; 026 (all but the list left out of the export); 029 (locations, the pages, the navigation); 032 (a lot's place, moving copies, removing a location); 033 (all but decision 5 for rows, #142); 034; 037; 057 (decision 12's wording only); 062 (decks and zones as locations, the format seam, the Decks pages, the label "Deck › Zone" and the safe Edit copy) | [design system](../design-system/README.md) |
| Tenancy and accounts | [tenancy-and-accounts.md](tenancy-and-accounts.md) | 004 (Stories 3, 4, 5 and 12 but for the lots' isolation; FR-2 but for its supersession of 002 FR-7; FR-3–FR-5; AC-2.4 and AC-2.6; NFR Security; the first-run part of NFR Reliability); the admin gate of 015 (AC-7.1, AC-7.3); the ownership rule behind `ActiveStorageGate` (028 decision 8; ADR 0022); 062 (the deck routes' 404 rule and the operator's blindness: AC-3.8, AC-9.6–AC-9.8) | none |
| Scanner | [scanner.md](scanner.md) | 005; 007 (all but FR-4's name index and name matching, FR-5, AC-3.4, AC-3.5, AC-3.9); 008; 009 (all but AC-6.1); 010; 011 (all but FR-2 and Story 3's build run: AC-3.1, AC-3.2, AC-3.4–AC-3.6, AC-3.8, AC-3.11); 040 and 042 (the sitting's place and condition control, copy, requests; their parts on lots, locations and the export are in the two docs that cover them); 047 | [design system](../design-system/README.md) |
| Data portability | [data-portability.md](data-portability.md) | 017; 022; 025 (all but decision 6's request body limit); 026 (the list left out of the export); 028 (all but the stored upload's retention and gate); 029 (format version 2, the export, the preview and the apply of locations); 030 (export versus backup); 032 (format version 3, the export, the preview and the apply of a lot's location); 062 (format version 4: decks and a lot's zone in the export, the reader, the preview, the fingerprint and the apply) | [export format](../export-format/README.md) |
| Release and deploy | [release-and-deploy.md](release-and-deploy.md) | 001 (container, Compose, Kamal, remote CI); 012; 013; 020; 025 (decision 6, the request body limit); 028 (decisions 8 and 9, stored upload retention, the sweep); 030 (backup and restore, all but the export-versus-backup guidance and decision 14 and AC-5.7, which spec 031 decision 7 supersedes in part); 031 (the upgrade proof, the migration guard); 014 (the image's libvips) | [releasing](../releasing.md); [backup and restore](../backup-restore.md) |

Specs 001 (stack, CI, hooks), 003 and 014 describe the development environment. Its facts stay in CLAUDE.md, where an agent needs them first, and have no area doc; they freeze with the release and deploy area. Spec 004's design-system part, spec 057 (the deck rules, navigation, pickers and the retired re-export wording), spec 060 (the deck components and their previews) and spec 063 (the stroke of small icons: Iconography and `additions.css`) are covered by [`docs/design-system/`](../design-system/README.md).

## The shape of an area doc

Every area doc has these sections, in this order. A section with nothing in it says "None." under its heading.

1. **Scope**: what the area covers and where its edges are, naming the neighbouring areas.
2. **Glossary**: the area's terms.
3. **Invariants**: statements that always hold.
4. **States and transitions**: for each stateful thing, its states, what moves it between them, and what a reader sees.
5. **Named constants**: name, value, where it is defined, why that value, and its source.
6. **Decisions not in an ADR**: each with its source. Accepted limits and open issues go here too.
7. **Sources**: every spec part, ADR and issue the doc distils, linked.
8. **Distillation log**: one row per whole feature distilled into the doc: date, what was distilled, the pull request.

Each statement that came from a spec criterion, ADR or issue names it inline, for example "(spec 015 AC-2.16; #60)". Code comments cite spec criteria; the [specs index](../specs/README.md) leads from a spec to the area doc that holds its current form.

## When an area doc changes

- A pull request that changes the behaviour, a constant or a rule of an area that has an area doc updates the doc in the same pull request. An issue fix adds its issue to Sources; only a whole feature's distillation adds a Distillation log row.
- A feature is distilled into its area docs in the feature's own pull request, after `session-wrap` on the feature branch and before the pull request is marked ready for review. Its plan is retired after the merge. The `distill-feature` skill (`.claude/skills/distill-feature/SKILL.md`) does both; `.claude/CLAUDE.md`'s session-end instruction runs it after every `session-wrap`.
- A change that supersedes part of a shipped spec records the supersession in its own spec and in the specs index, and updates the area doc where one covers that part. It doesn't edit the earlier spec.
