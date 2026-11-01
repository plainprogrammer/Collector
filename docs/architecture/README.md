# Architecture

One area doc per subsystem holds the current truth about it: its terms, the rules that always hold, its states, its named constants and why they have their values, and the decisions not recorded in an ADR. Each statement names the spec criterion, ADR or issue behind it. When an area doc and an older spec disagree, the area doc is right: specs record what a feature promised when it shipped, and freeze once an area doc covers them (see the [specs index](../specs/README.md)).

Lasting decisions are in [ADRs](../adr/README.md). What an agent needs before it knows where to look stays in [CLAUDE.md](../../CLAUDE.md).

## Areas

| Area | Doc | Specs it covers | Reference docs |
|---|---|---|---|
| Catalog operations | [catalog-operations.md](catalog-operations.md) | 002 FR-3–FR-6 and their Error Scenarios rows; 011 FR-2 (the build's run); 015; 024 | none |
| Catalog core | not written yet | 002 FR-1, FR-2, FR-7–FR-10; 016; 018; 019; 023 | none |
| Collection and lots | [collection-and-lots.md](collection-and-lots.md) | 004 (collection, adding cards); 006; 021; 026 (all but the list left out of the export); 029 (locations, the pages, the navigation); 032 (a lot's place, moving copies, removing a location); 033 (all but decision 5 for rows, #142); 034 | [design system](../design-system/README.md) |
| Tenancy and accounts | not written yet | 004 (accounts, users, admin users) | none |
| Scanner | not written yet | 005; 007; 008; 009; 010; 011 (all but FR-2's build run) | none |
| Data portability | [data-portability.md](data-portability.md) | 017; 022; 025 (all but decision 6's request body limit); 026 (the list left out of the export); 028 (all but the stored upload's retention and gate); 029 (format version 2, the export, the preview and the apply of locations); 030 (export versus backup); 032 (format version 3, the export, the preview and the apply of a lot's location) | [export format](../export-format/README.md) |
| Release and deploy | [release-and-deploy.md](release-and-deploy.md) | 001 (container, Compose, Kamal, remote CI); 012; 013; 020; 025 (decision 6, the request body limit); 028 (decisions 8 and 9, stored upload retention, the sweep); 030 (backup and restore, all but the export-versus-backup guidance and decision 14 and AC-5.7, which spec 031 decision 7 supersedes in part); 031 (the upgrade proof, the migration guard); 014 (the image's libvips) | [releasing](../releasing.md); [backup and restore](../backup-restore.md) |

Specs 001 (stack, CI, hooks), 003 and 014 describe the development environment. Its facts stay in CLAUDE.md, where an agent needs them first, and have no area doc; they freeze with the release and deploy area. Spec 004's design-system part is covered by [`docs/design-system/`](../design-system/README.md).

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
