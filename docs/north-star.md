# North Star

**Decided:** 2026-10-11, by the maintainer, in a planning interview. The rulings behind each line are in the [roadmap's decision log](roadmap.md#decision-log).

This document says what Collector is being built towards and the rules every future spec is checked against. It builds on the [foundation](../.claude/memory/foundation.md) (mission and principles) and doesn't replace it. The [roadmap](roadmap.md) says what is built in which order.

## Goal

Collector holds the maintainer's and their family's real collection on an instance the maintainer runs, and nothing about how it is built rules out offering it as a hosted service later.

A hosted offering is an outcome the maintainer wants after 1.0. It is kept open and isn't scheduled.

- **The family instance sets the priorities.** A feature is in 1.0 because the family's collection can't move in without it.
- **The hosted service is a constraint, with no commitment to a form.** Whether it is paid, free or invite-only is undecided. No hosted-service feature is built before 1.0; the [hosted-door rules](#hosted-door-rules) apply now.
- **Magic: The Gathering cards are the first collectible type. Comics are the second.** Whether comics are in 1.0 is decided by the maintainer's ruling on the comics source research ([roadmap, theme E](roadmap.md#theme-e-comics)).

## The 1.0 test

1.0 is reached when all three are true. There is no date.

1. The family's real cards are in a deployed instance, each with a location. The same holds for their comics, if the ruling puts comics in 1.0.
2. An export of that instance has been restored into a fresh instance and matched.
3. The instance has been upgraded in place across at least one release.

## Hosted-door rules

Every spec is checked against these four rules, so that a hosted service stays possible.

| Rule | A spec fails it when |
|---|---|
| **Source terms allow hosting** | It adopts a catalog source whose licence or terms forbid a public, possibly paid, instance. |
| **The operator is not the user** | An admin page or task shows or edits the items in a collector's collection. |
| **Collector choices are stored per account or user** | It adds an instance setting or environment variable for something a collector would choose. |
| **Bounded cost per account** | It doesn't state what the feature costs per account in storage and background work. |

Notes on applying them:

- A setting that decides what the global catalog ingests, or what it costs the operator to build, is an operator's choice and may stay an instance setting. `COLLECTOR_MTG_LANGUAGES` and `COLLECTOR_MTG_ART_MATCHING` are of this kind.
- An operator manages accounts, so the second rule allows it: creating and deleting an account (deleting a user deletes their collection), changing a user's name, email or password, and showing each account's copy count, as spec 004's admin users page does. It doesn't allow listing, opening or editing what a collection holds.
- Currency is a collector's choice stored as an instance setting (spec 004). It is the one known breach, of the third rule, and is listed in the roadmap's housekeeping lane.
- Scryfall's terms haven't been checked against the first rule yet. That check is the roadmap's first item.

## Spec rules

- **One outcome, one PR.** A spec delivers one capability that a collector or operator could state in a sentence, merges as one PR and leaves `main` releasable. A title that needs "and" is split.
- **Enabling slices are allowed** when they are releasable alone: a schema change, a format definition, a research note.
- **Spikes are separate from builds.** A spike measures and recommends, with no pass threshold. The maintainer rules on its findings, and the build spec is written after the ruling.
- **Export covers it.** A spec that adds collector-owned data extends the export format in the same PR, so the second check of the 1.0 test stays true as themes land.

## Not before 1.0

- Market prices and estimated value. Price paid stays the only money field.
- Wishlists and lending.
- Personal and household collections side by side. Family members start on separate private accounts. No ownership model is decided early; an export format bump and migrations are accepted when its turn comes ([ADR 0017](adr/0017-row-level-tenancy-one-user-per-account.md)).
- Importing files from other tools.
- Art matching on the scanner's photo path, and native apps.
- Hosted-service features: billing, plans or limits, hardened public sign-up, email (including password reset), and backups that a hosting operator runs for its customers. The self-hoster's own backup and restore is in 1.0 (roadmap item 6).

## Changing this document

A change to the goal, the 1.0 test or a rule needs the maintainer's explicit ruling, recorded in the roadmap's decision log with its date. The roadmap's candidate lists change freely as specs are written.
