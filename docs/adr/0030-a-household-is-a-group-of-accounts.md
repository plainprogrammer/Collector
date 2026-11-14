# 0030: A household is a group of accounts; an account stays the unit of ownership and privacy

## Status

Proposed (2026-11-13), written with spec 090; it becomes Accepted with the pull request. It supersedes the one-user half of [ADR 0017](0017-row-level-tenancy-one-user-per-account.md): an account no longer has to be the only account of its user's group. It keeps the rest of ADR 0017. The ownership model it records was ruled by the maintainer on 2026-11-13 (design decision 9; roadmap rulings 43 and 44), and so were what the export carries (decision 6 here, spec 090 decision 4) and the household's name and manager rule. The shape of the third migration (decision 7) was ruled by the maintainer the same day: the table copy, not the nullable fallback, on two conditions (the plan review traces it against Rails 8.1.4.1's `alter_table`, and the upgrade proof runs from the previous release built from its tag).

**Date:** 2026-11-13
**Feature:** 090-every-user-has-a-household

## Context

ADR 0017 fixed the tenancy rule: every collector-owned table carries `account_id`, a request resolves `Current.account`, every query goes through it, and another account's record is a 404. It also fixed that an account has exactly one user, and deferred personal and household collections side by side, to be decided with an export format bump and migrations when they came.

They came: the maintainer moved households into 1.0 on 2026-11-13 ([design](../superpowers/specs/2026-11-13-households-and-hosted-service-design.md), rulings 43 and 44), because the family's collection is the 1.0 test and a family is several people, and because a change to who owns a row gets dearer with each table added (lots, locations, decks, proxies and prices all exist or are on the way). Each family member wants a private collection, and the household wants one it shares. The hosted lane then prices a plan per household.

This ADR records the decision that is needed first, by every later issue of both lanes: what a household is in the schema, and what it leaves alone. The shared collection, joining, leaving and transfers are decided in their own specs (#381 to #389).

## Options considered

- **A. A household is a group of accounts (chosen; ruled 2026-11-13).** Each member keeps their own account, and the household may have one shared account. Everything that exists keeps going through `Current.account`; another account is a 404. A copy is in one account at a time, so a copy moves between a member's account and the household's by a transfer.
- **B. An owner on each row.** One account per household, and every place, deck and lot carries the member who owns it, or none for the household. Rejected by the design: every query gains "mine or the household's", a lot's key gains the owner in all five places that build it, the export is reshaped, and a missed condition shows a child's collection to the household. Its one gain, using a household copy in a member's deck with no transfer, is answered by borrowing (#388).
- **C. Keep one user per account and add nothing.** The 1.0 test fails: the family has no shared collection.

**For the structure (spec 090 decisions 1 and 6):**

- **A. A `households` table, a `memberships` table (user, household, role) and `accounts.household_id` with `accounts.kind` (chosen).** A personal account's household is found both through its user's membership and through the account; a shared account has no user, so only the account can say. The cost is one fact held twice for a personal account, kept in step by the model and checked by a guard.
- **B. `users.household_id` and a role on `users`, with accounts finding their household through their user.** One fact, not two, and no membership table. Rejected: a shared account has no user, so it would need its own column anyway, and a user's role is a fact of the membership, which later issues move and remove as a row.
- **C. `accounts.household_id` only, with a role on the account.** Rejected: a role belongs to a person, not to the collection they hold; a shared account has no person.

## Decision

1. **An account stays the unit of ownership and privacy.** Every collector-owned table keeps `account_id` and nothing in it changes. A household is a group of accounts: each member's own account (`kind` `personal`) and, from #384, at most one shared account (`kind` `shared`, no user). The rules of the shared account (one per household, no user) are written by the issue that makes one, not here. The foreign keys: `accounts.household_id` and `memberships.household_id` are no action, so a household that holds an account or a member can't be deleted, and `memberships.user_id` cascades, so a user's delete removes their membership.
2. **Every user belongs to exactly one household,** through a membership row whose `user_id` is unique. A membership has a role, `manager` or `member`, stated by a `CHECK`. A household always has a manager. There is no other role in 1.0 (no kid role: a child's collection is any member's).
3. **`users.account_id` stays unique.** A user has one account, their own, and a personal account has one user. What changes is that an account belongs to a household, through `accounts.household_id`, which is `NOT NULL` (ruled by the maintainer, 2026-11-13, over a nullable fallback; spec 090 decision 5 weighs both).
4. **A household is made with its user, as the account is.** The user model makes the household, the manager membership and the account in one write, so first run, sign-up, an admin's form and the operator's command all give one. A household of one is named for its user and is invisible in the app.
5. **"A household always has a manager" is the model's rule, plus the database's checks.** There is no trigger, because `db/schema.rb` doesn't dump triggers and a volume made from the schema would differ from an upgraded one. The rule is checked on real rows by a guard spec and by the upgrade proof.
6. **The export doesn't carry the household, and the format stays version 4.** The export is one file per account. The household's name and members are a fact about a group; they are listed in the format document's Coverage tables as left out. The shared collection's own file, and the version raise it brings, are #384's.
7. **Three migrations carry it onto every instance, all run without a transaction:** the schema (new tables, two columns added without a table copy), a batched idempotent backfill that gives every existing user a household of one, and `NOT NULL` on `accounts.household_id` by a table copy that first gives any straggler a household. The upgrade proof checks the invariants on the upgraded, the restored and a fresh snapshot, and the backfill's own facts on the upgraded and restored ones. The third migration's risk and the nullable fallback it was ruled over are weighed in spec 090 decision 5.

What ADR 0017 keeps, unchanged: the `account_id` rule, `Current.account` resolved once and failing closed, queries through the account, 404 for another account's record, catalog data global, jobs and broadcasts carrying the account, the admin flag giving no view into a collection, and "the operator is not the user". `Current.account` is still the signed-in user's own account; that a session may work in the household's shared account instead is #384's.

## Consequences

- **Good:** the isolation rule that the suite proves per resource is untouched, so a family member's private collection stays private by the rule that exists. The structure the later lanes need exists on every instance before any of them is built, and costs one household row and one membership row per member.
- **Good:** a household of one is the case every user is in on upgrade, so each later feature starts from a state that already exists on every instance, not from a migration of its own.
- **Cost:** one fact, a personal account's household, is held twice (the account's column and its user's membership). A later issue that moves a user between households changes both in one transaction; until then a guard and the upgrade proof check them.
- **Cost:** a copy is in one account at a time, so a household card in a personal deck means a transfer or a borrow (design decision 15, #385, #388).
- **Cost:** the third migration copies `accounts`, the most referenced table in the schema (eleven cascading children), with foreign keys switched off outside a transaction; inside one the copy would silently delete those children. The upgrade proof, which seeds a row in every table that references `accounts`, is what shows no row is lost; the copy also restores the table's id sequence. Had the fallback been chosen, `accounts.household_id` would be nullable in the database and the model alone would say it is present.
- **Cost:** "member" now means two things: spec 015's user without the admin flag, and a household's non-manager. They are independent, and no page shows either yet; #389 and the pages of #381 onward choose their words with both in view.
- **Cost:** an older release can't hold a household with two members or a shared account, so rolling back the first migration refuses when either exists.
- **Follow-up:** ADR 0017's status line records that this supersedes its one-user half; its text isn't rewritten. The tenancy area doc, the format document's Coverage and `CLAUDE.md`'s status paragraph change with spec 090.
