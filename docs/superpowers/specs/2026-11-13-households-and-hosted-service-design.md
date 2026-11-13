# Households and the hosted service: the accounts design

**Date:** 2026-11-13. **Status:** approved by the maintainer in the interview, 2026-11-13 (one AGPL codebase, a household of accounts, households and the hosted-service features in 1.0, and the issue split); issues filed (see "Filed" at the end).
**Builds on:** accounts and tenancy as built on `main` at `7de9574` ([`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md), [ADR 0017](../../adr/0017-row-level-tenancy-one-user-per-account.md), [ADR 0019](../../adr/0019-lot-as-the-unit-of-ownership.md), [ADR 0025](../../adr/0025-a-lots-location-is-part-of-its-identity.md), [ADR 0028](../../adr/0028-decks-are-locations-with-zones.md)), the export format ([`data-portability.md`](../../architecture/data-portability.md)), the [north star](../../north-star.md) and its hosted-door rules, [research 016](../../specs/016-scryfall-hosting-terms/research.md) (rulings 27 to 30), and the licensing research of 2026-11-13.
**Supersedes:** the project draft "Collector — Hosted SaaS: Accounts, Plans, and Billing" (2026-10-15). That draft was written before it was checked against the code; "What changed" lists the differences.
**Deliverable:** GitHub issues under two new labels, `theme: households` and `theme: hosted`, both on the 1.0 milestone, each one outcome that a Claude Code agent takes through the SDD workflow in one PR, and two roadmap lanes.
**Roadmap:** this reverses ruling 6 and ruling 14 for hosted-service features, and the two matching lines of the north star's "Not before 1.0" (rulings 42 to 45). Ruling 27 stands as written until the maintainer rules on decision 19, which proposes to narrow it.

## Why

The family's collection is the 1.0 test, and a family is several people. Today each person has a private account and nothing is shared: cards the household owns together have no home, and a parent can't see or help with a shared binder. The maintainer wants both personal collections and a shared household one (ruling 5).

The later goal is a paid hosted service on the same code. The maintainer ruled on 2026-11-13 that Collector stays AGPL-3.0 as one codebase, with no proprietary part. The hosted service sells operation, not code: hosting, backups, catalog upkeep, household sharing and, later, AI features on the operator's keys. So plans, limits and billing are ordinary features of the AGPL code, switched on by configuration.

Both are built in 1.0, because the maintainer wants to take the hosted service to market sooner (2026-11-13). Households come first in the order because they change who owns a row. That change gets dearer with each table added, and decks, zones, proxies and prices are being added now. A plan belongs to a household, so the hosted lane builds on the first households candidate.

## What changed since the October draft

| October draft | Now | Why |
|---|---|---|
| Add `accounts`, `memberships` and `account_id` to every owned table (its migration steps 1 to 3) | Already built | Spec 004 and ADR 0017: every collector-owned table carries `account_id`, and every query goes through `Current.account` |
| `acts_as_tenant` with `require_tenant` | Dropped | Tenancy is hand-written and guarded by a request spec per resource; the app has no `default_scope` |
| The account is the household; members share all of it | The account is one collection; a household groups accounts | Decisions 3 and 4: a member or the household owns a deck or a place, and a member's collection is private by default |
| Kid profiles as a membership with no user | No kid role in 1.0 | Decision 4: a kid's collection is treated like any other member's |
| Tiers: Free, Collector, Family | Plus tiers added, with monthly AI quotas | Pricing direction of 2026-11 |
| Entry granularity was an open question | Answered | A lot splits by finish, condition, price paid and place (ADRs 0019, 0025), so a cap on distinct catalog entries counts `DISTINCT catalog_entry_id` |
| AGPL footer link to the deployed commit | Already an issue | [#374](https://github.com/plainprogrammer/Collector/issues/374), on the 1.0 milestone |
| Billing built with the tenancy work | Billing is a lane of its own in 1.0, after households | A plan belongs to a household; ruling 45; decision 19 proposes that ruling 27 gate the sale, not the code |

## Decisions

| # | Decision | By |
|---|---|---|
| 1 | Collector stays AGPL-3.0, one codebase. There are no proprietary add-ons. The hosted service differs from a self-hosted instance by configuration only. | Maintainer, 2026-11-13 |
| 2 | Household structure is built in 1.0, alongside the deck and location work. Billing and the other hosted-service features are built in 1.0 too, to reach the market sooner. | Maintainer, 2026-11-13 |
| 3 | A member or the household can own a deck, a binder or any other location. | Maintainer, 2026-11-13 |
| 4 | A kid's collection is treated like any other member's. It is not visible to other members by default. | Maintainer, 2026-11-13 |
| 5 | The hosted service sells hosting, backups, catalog upkeep, household sharing, support and, later, AI features on the operator's keys. | Maintainer, 2026-10 |
| 6 | Plans are priced per household. Free: one member, 500 distinct catalog entries across all collectible types, quantities not counted. Collector: $4 a month or $36 a year. Family: $7 a month or $60 a year, up to 6 members. Plus tiers with monthly AI quotas: $8 a month or $72 a year (individual), $15 a month or $132 a year (family). | Maintainer, 2026-10 and 2026-11 |
| 7 | Catalog search, card pages, prices and price history are open to everyone on a hosted instance and are never a paid feature (rulings 27 and 37). | Maintainer |
| 8 | Billing is Stripe through the `pay` gem, with Stripe Managed Payments as merchant of record, in the United States only at launch. | Maintainer, 2026-10 |
| 9 | An account stays the unit of ownership and privacy. A household is a group of accounts: each member's own account, and one shared account the household owns. | Maintainer, 2026-11-13 |
| 10 | Every user belongs to exactly one household. A household of one is invisible in the app. | Proposed |
| 11 | A household has two roles: manager and member. There is no kid role in 1.0. | Proposed |
| 12 | A person joins a household with an invitation code a manager creates. No email is sent. | Proposed |
| 13 | Every member reads and edits the shared collection. | Proposed |
| 14 | A session works in one collection at a time: the member's own or the household's. `Current.account` is that collection. | Proposed |
| 15 | Copies move between a member's collection and the household's by a transfer. A copy is in one collection at a time. | Proposed |
| 16 | The export stays one file per account. The shared collection has its own file. | Proposed |
| 17 | Hosted mode is one operator setting. Without it an instance has no plans, no limits and no billing routes. | Proposed |
| 18 | A plan belongs to the household, and a limit counts across the household's accounts. | Proposed |
| 19 | The hosted lane's first item settles ruling 27 (Wizards' position on charging). The plan and billing code is built behind hosted mode meanwhile, and no paid plan is offered at a hosted instance before that item closes. | Proposed: it narrows ruling 27's "built" to "offered" |
| 20 | Outside contributions to the core are accepted under a sign-off (DCO) from the first one. Whether to ask for a wider inbound licence is decided before the first outside pull request to the core. | Proposed |
| 21 | A member borrows copies from the household's collection into a deck of their own, and returns them. It is built in 1.0. | Proposed |

Decisions 10 to 21 are the design's proposals. Each is settled in the spec of the issue that carries it. Decisions 19 and 21 change what is in 1.0, so the maintainer confirms them before their issues start.

## Goals, non-goals and anti-goals

**Goals**
- Each family member has a private collection, and the household has a shared one.
- A deck or a place belongs to a member or to the household.
- Nothing a member owns is visible to another member unless it is in the shared collection.
- The code that exists keeps its tenancy rule: one `Current.account`, and another account's record is a 404.
- A later hosted service needs no change to who owns what.

**Non-goals in 1.0**
- One view of everything the household's members own between them.
- A member who may read the shared collection but not edit it.
- Lending to someone outside the household ([#259](https://github.com/plainprogrammer/Collector/issues/259), 2.0 milestone).
- A user in two households.
- AI features and their quotas.

**Anti-goals**
- A feature of the code withheld from a self-hosted instance (decision 1).
- A catalog page, a price or a price history behind payment (decision 7).
- An admin page that shows what a collection holds (hosted-door rule 2).
- A manager who can open a member's private collection.

## Constraints

- **Tenancy as built.** Every collector-owned table carries `account_id`. A request resolves `Current.account` once, and every query goes through it. A request spec per resource proves that another account's record is a 404.
- **A lot's identity.** A lot is a quantity of one printing with one finish, condition, price paid and place. Five places build its key. A location and the lots in it are in the same account, and a deck's copies sit in its zones.
- **The export.** One JSON document per account, holding the profile of its one user. A new table or column with `account_id` or `user_id` fails the suite until the format's coverage tables list it. New collector-owned data extends the export in the same PR.
- **No email.** The app sends none today: no invitation and no password reset. The hosted lane brings the first ([#395](https://github.com/plainprogrammer/Collector/issues/395)); households don't depend on it.
- **Sign-up.** Closed by default once the first user exists. An admin creates users or opens sign-up.
- **The hosted-door rules.** Each spec states what it costs per account, stores a collector's choices per account or user, and gives an admin no view into a collection.
- **Ruling 27.** No paid plan is built until Wizards' position on charging is settled in writing or by legal advice. Decision 19 proposes "offered" in place of "built".
- **SQLite in every environment** ([ADR 0016](../../adr/0016-sqlite-in-every-environment.md)), one host. Migrations run unattended on a self-hoster's upgrade and are never edited after release.

## Approaches to ownership

| | A. A household of accounts (chosen) | B. An owner on each row |
|---|---|---|
| Shape | A household has each member's account and one shared account | One account per household; places, decks and lots carry the member who owns them, or none for the household |
| Queries | Unchanged: everything goes through `Current.account` | Every query on owned data gains "mine or the household's" |
| A member's privacy | Kept by the rule that exists: another account is a 404 | Kept only if no query forgets the new condition |
| A lot's key | Unchanged | Gains the owner, in all five places that build it |
| The export | One file per account, as now | One file holds several owners; the format is reshaped |
| A household copy in a member's deck | By a transfer into the member's collection | Possible directly |
| One view across owners | A deliberate cross-account read, built later | A filter |
| Risk | New: switching collections and transfers | High: a missed condition shows a child's collection to the household |

The maintainer chose A (decision 9). It meets decisions 3 and 4 with the isolation rule the suite already proves, and it leaves lots, locations, decks, the scanner and the export as they are. Its cost is decision 15: a copy is in one collection, so using a household card in a personal deck means transferring it, or building the deck in the shared collection.

That cost is real for this family. The maintainer keeps a large set of "house" cards in his own collection today, and the children borrow from it more than he borrows from them. Two candidates answer it: moving many lots at once puts the house cards in the shared collection ([#386](https://github.com/plainprogrammer/Collector/issues/386)), and borrowing lets a member use a household copy in a deck of their own without taking it over (decision 21, [#388](https://github.com/plainprogrammer/Collector/issues/388)).

## The household model

```
Household
  ├─ members: User (role: manager | member)
  ├─ each member's own Account   (kind: personal, private to that user)
  └─ one shared Account          (kind: shared, read and edited by every member)

Account ── lots, locations, decks, proxies, working state   (unchanged)
```

- **Household.** A name. It is created with a user, as the account is. A household of one shows nothing of itself.
- **Membership.** A user belongs to exactly one household, as a manager or a member. A household always has a manager.
- **Personal account.** What an account is today: one user, private. `users.account_id` stays unique.
- **Shared account.** An account with no user of its own, owned by the household. It is created when the household gains its second member, or when a manager first asks for it.
- **The working collection.** A session works in the member's own collection or the household's. A switch in the navigation changes it, and every page then reads and writes there: the collection, places, decks, the scanner, number entry, import and export. Working state such as a scanner sitting belongs to the collection it was started in.
- **Joining.** A manager creates an invitation code. A signed-in user enters it and joins; their own collection comes with them and stays private. The household they leave behind, if it was a household of one, is removed.
- **Leaving.** A member leaves with their own collection and gets a household of one. A manager can remove a member the same way. The last manager can't leave while other members remain; they hand the role over first. A household whose shared collection holds copies can't be dissolved until the copies are transferred or removed.
- **Transfers.** A member moves some or all copies of a lot between their own collection and the shared one, choosing a place in the destination. It merges with an identical lot there, as Move copies does. A deck is transferred whole, with its zones and proxies.
- **Deleting a user.** It deletes their own collection, as now. The shared collection is the household's and stays.
- **The operator.** The admin users page shows each user's household and each household's shared copy count. It never lists what a collection holds.
- **The export.** A member exports their own collection as now. Any member exports the shared collection as a second file. The shared file has no single profile, so the format's `profile` changes for it and the version rises in the PR that adds the shared account.

**Cost per household:** one household row, one membership row per member, and at most one extra account.

## The hosted service

Built in 1.0, after the first households candidate, as ordinary features of the AGPL code.

- **Hosted mode.** One operator setting (`COLLECTOR_HOSTED`). Without it there are no plans, every household is unlimited and the billing routes aren't mounted. A self-hosted instance loses nothing.
- **Plans.** A registry in code, keyed by a plan key on the household: free, collector, family and the two Plus tiers. An operator can set a household's plan by hand (a comped account).
- **Limits.** The free plan's 500 counts distinct catalog entries across the household's accounts. It warns past the limit and refuses new additions past a small margin. Reading, editing, removing, deck building and export are never restricted. A plan's member limit is checked when a person joins.
- **Billing.** Stripe Checkout and the customer portal through `pay`, with Managed Payments. A webhook recomputes the household's plan. No Stripe call is made while a page renders.
- **Downgrade.** Nothing is deleted or locked. Additions are refused until the household is under its limit, and no new member can join.
- **Email and sign-up.** Public sign-up needs email delivery, address verification and password reset, and stronger limits on abuse.
- **The source offer.** [#374](https://github.com/plainprogrammer/Collector/issues/374) shows the licence, the version and the commit, with where to get the source. The hosted instance deploys only commits that are public.
- **What stays out of the repository.** Secrets, Stripe and model keys, the hosted environment's values, customer data and backups. The marketing site and the analytics account are separate works.
- **AI quotas.** A plan attribute is reserved. Nothing reads it until the AI features are designed.

## Checked against the hosted-door rules

| Rule | Households | Hosted service |
|---|---|---|
| Source terms allow hosting | No new source | Ruling 27 gates the paid plans; the free cap is put to Scryfall in writing |
| The operator is not the user | The admin page shows households and counts only | A comped plan is account management |
| Collector choices per account or user | The working collection is the session's; the household's name and roles are the household's | The plan is the household's |
| Bounded cost per account | Stated above | A cached entry count per household |

## Open questions

1. **A borrowed copy.** How a copy the household owns is shown in a member's own deck, when the deck's zone and the copy are in different accounts, and whether it builds on the loan location of [#259](https://github.com/plainprogrammer/Collector/issues/259) ([#388](https://github.com/plainprogrammer/Collector/issues/388)).
2. **Who edits the shared collection.** Every member (decision 13), or does a manager choose per member?
3. **Joining on a self-hosted instance.** The person needs a user first: an admin creates one, or sign-up is open. Is an invitation code that also creates the user wanted?
4. **The shared file's profile.** What the export's `profile` holds for a shared collection: the household's name only, or its members' names too.
5. **Kids on the hosted service.** A child under 13 with a sign-in of their own brings COPPA duties. The hosted lane decides whether a child's sign-in is allowed there.
6. **A trial.** A 14-day Family trial with no card, or the free plan alone.
7. **Price ids.** In the environment, or in a table that allows grandfathered prices. The environment is proposed.
8. **The name.** "Collector" is generic and hard to register as a mark. The mark is the practical defence against a copy of the hosted service, so the name is settled before the first sale.
9. **The hosted database.** ADR 0016 keeps SQLite in every environment. Whether the hosted instance leaves it is decided on measurements, not here.

## Filed

On the [1.0 milestone](https://github.com/plainprogrammer/Collector/milestone/1), in order. Each is one outcome, refined into a spec when its turn comes.

**Households lane** (`theme: households`):

| Issue | Outcome | After |
|---|---|---|
| [#379](https://github.com/plainprogrammer/Collector/issues/379) | Design system: households | |
| [#380](https://github.com/plainprogrammer/Collector/issues/380) | Every user has a household (with the ADR that supersedes ADR 0017's one-user half) | |
| [#381](https://github.com/plainprogrammer/Collector/issues/381) | Join a household with an invitation code | #379, #380 |
| [#382](https://github.com/plainprogrammer/Collector/issues/382) | Leave a household, or be removed from it | #381 |
| [#383](https://github.com/plainprogrammer/Collector/issues/383) | Hand the manager role to another member | #381 |
| [#384](https://github.com/plainprogrammer/Collector/issues/384) | Work in the household's shared collection (raises the export format) | #379, #381 |
| [#385](https://github.com/plainprogrammer/Collector/issues/385) | Move copies between my collection and the household's | #384 |
| [#386](https://github.com/plainprogrammer/Collector/issues/386) | Move many lots between collections from bulk mode | #385 |
| [#387](https://github.com/plainprogrammer/Collector/issues/387) | Move a deck between my collection and the household's | #385 |
| [#388](https://github.com/plainprogrammer/Collector/issues/388) | Borrow copies from the household's collection | #384, #385 |
| [#389](https://github.com/plainprogrammer/Collector/issues/389) | Households on the admin users page | #380 |

**Hosted lane** (`theme: hosted`):

| Issue | Outcome | After |
|---|---|---|
| [#390](https://github.com/plainprogrammer/Collector/issues/390) | Settle Wizards of the Coast's position on charging for a hosted instance (not code) | |
| [#391](https://github.com/plainprogrammer/Collector/issues/391) | Ask Scryfall in writing about the free plan's cap (not code) | |
| [#392](https://github.com/plainprogrammer/Collector/issues/392) | Hosted mode: one operator setting | |
| [#393](https://github.com/plainprogrammer/Collector/issues/393) | A household has a plan | #392, #380 |
| [#394](https://github.com/plainprogrammer/Collector/issues/394) | A plan's limits are enforced | #393 |
| [#395](https://github.com/plainprogrammer/Collector/issues/395) | Reset a password by email | |
| [#396](https://github.com/plainprogrammer/Collector/issues/396) | Public sign-up that resists abuse | #395 |
| [#397](https://github.com/plainprogrammer/Collector/issues/397) | Pay for a plan, manage it and cancel it (waits for #390 under ruling 27) | #390, #394, #395 |
| [#398](https://github.com/plainprogrammer/Collector/issues/398) | What a household keeps after a downgrade | #397 |
| [#399](https://github.com/plainprogrammer/Collector/issues/399) | Off-host backups for a hosted instance, with a restore drill | #392 |
| [#400](https://github.com/plainprogrammer/Collector/issues/400) | Terms, privacy and refund pages, with the rule for children's sign-ins | |

**Housekeeping:**

| Issue | Outcome |
|---|---|
| [#401](https://github.com/plainprogrammer/Collector/issues/401) | Contribution policy: a sign-off on every commit, and licence identifiers in the source |
| [#402](https://github.com/plainprogrammer/Collector/issues/402) | CI fails on a dependency whose licence isn't allowed |

The source offer (the licence, the version and the commit, with where to get the source) is [#374](https://github.com/plainprogrammer/Collector/issues/374), filed before this design.

The maintainer's own tasks, not issues for an agent: the name and its trademark search (question 8).
