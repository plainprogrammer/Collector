# Feature 090: Every User Has a Household

**Status:** Draft (decisions 2 to 6 are pending the maintainer's ruling; each is written on the recommendation)
**Version:** 0.1.0
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 004](../004-design-system-collection/spec.md) (accounts, FR-2 to FR-5; frozen, by [tenancy and accounts](../../architecture/tenancy-and-accounts.md)), [spec 017](../017-export-format/spec.md) FR-9 (the coverage guard), [spec 031](../031-upgrade-from-previous-release/spec.md) (the upgrade proof), [spec 049](../049-session-idle-expiry/spec.md) (three migrations without a transaction, the precedent for decision 5)
**Branch:** `090-every-user-has-a-household`
**Issue:** [#380](https://github.com/plainprogrammer/Collector/issues/380) (the 1.0 milestone, households lane; the root of #381 to #389 and of the hosted lane's #393)
**ADR:** [0030](../../adr/0030-a-household-is-a-group-of-accounts.md), which supersedes the one-user half of [ADR 0017](../../adr/0017-row-level-tenancy-one-user-per-account.md)
**Supersedes:** spec 004 FR-3 in part ("an account has exactly one user": an account is now in a household, and `users.account_id` stays unique) and [ADR 0017](../../adr/0017-row-level-tenancy-one-user-per-account.md)'s one-user half, by ADR 0030; the area doc [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) records it
**Design:** [households and the hosted service](../../superpowers/specs/2026-11-13-households-and-hosted-service-design.md), decisions 9 to 11 (rulings 43 and 44 of the [roadmap](../../roadmap.md))

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-13 | First draft from issue #380, the design and the coordinator's brief. Decisions 2 to 6 are the five scope questions put to the maintainer, written on their recommendations |

## Problem Statement

Every later piece of the households lane (joining, leaving, a shared collection, transfers, borrowing) and the hosted lane's plan per household needs one fact that does not exist: which household a user, and an account, belongs to. Adding it later, after more tables exist and after more instances hold data, only gets dearer (design, "Why"). The fact has to exist for every user on every instance, including the ones that are upgraded from a release that had no households, and it has to arrive without a collector seeing anything change: no page, no word, no new rule for them to learn.

This feature adds the structure and nothing that uses it: a household with a name and its members, a role for each member, a kind for each account, a household made with every new user, and one made for every user that already exists on upgrade.

> **Terms.** *Household*: a named group of accounts; today always one user's. *Member* (of a household): a user in it. *Manager*: a member with the manager role; *plain member*: a member with the member role. *Membership*: the row that puts one user in one household with a role. *Personal account*: an account of kind `personal`, a member's own and private (what every account is today). *Shared account*: an account of kind `shared`, owned by the household and used by no single user; none exists after this feature. *Household of one*: a household with one member. **"Member" is also spec 015's word for a user without the admin flag** (the admin users page's "Member"); the two are independent: the admin flag governs the instance, the role governs a household, and no page shows a role in this feature.

## Goals

- Every user belongs to exactly one household, as a manager or a member; a household always has a manager.
- A new user, by every way a user is made (first run, sign-up, an admin, the operator's command), starts as the manager of a household of one, made in the same write as the user and their account.
- An account knows its household and its kind (`personal` or `shared`); a user's account is personal and is in the user's household.
- An existing instance gains a household for every user when it upgrades, unattended, with no row lost and no collector signed out, and the upgrade proof shows it.
- Nothing in the app looks different: no new page, link, word or field, and every tenant-isolation check passes unchanged.
- The names the later issues build on are settled here: tables, columns, roles, kinds.

## Non-Goals

- Any page, link, form or word about households: no invitation, no join or leave, no household name field, no role shown, no switch. The admin users page does not change (#389).
- A shared account, a way to create one, or a collection in it (#384). The schema allows one; nothing makes one.
- A user in two households, or a household with no member.
- Moving a user between households (#381, #382) and handing the manager role over (#383). This feature makes the rule they must keep.
- A kid role, or any role beyond manager and member (design decision 11).
- `Current.household`, or any change to how a request resolves `Current.account` (decision 14 of the design is #384's).
- Raising the export format's version or carrying a household in an export (decision 4).
- A plan, a limit or hosted mode (the hosted lane, #392 to #394).

## Users and Context

**Primary users:** every collector, who sees no change; an operator upgrading an instance, who needs the upgrade to give households to existing users with no step to run.
**Secondary users:** the agents and maintainers of #381 to #389 and #393, who build on the names and rules here; the maintainer's own instance, upgraded from the previous release.
**Usage context:** a migration at the first start after an upgrade (`db:prepare` on boot), and a household made whenever a user is.
**User mental model:** none. A household of one is invisible (design decision 10); the collector's mental model is the one they have, a private collection.

## Decisions

1. **The names.** *(Settles design decisions 10 and 11 and the schema half of 9; no departure from the design's names.)* Tables `households` (`id`, `name`, timestamps) and `memberships` (`id`, `household_id`, `user_id`, `role`, timestamps); roles `manager` and `member` (`memberships.role`, an enum with explicit values, a `CHECK` naming both); two columns on `accounts`: `household_id` (a foreign key to `households`, indexed) and `kind` (`personal` or `shared`, default `personal`, a named `CHECK`). `users.account_id` stays, unique, and `users` gains nothing. A user's household is read through their membership, an account's through `accounts.household_id`. **Both exist on purpose:** a shared account has no user, so it can't be found through a membership, and a membership is where the role lives; the cost is one fact held twice for a personal account. Its rule is decision 6.
   **Added to the design's model, each with its reason:** `memberships.user_id` is unique (one household per user, as a fact of the database, not only the model); `memberships.household_id` is indexed (the household's members are read by it); a partial unique index on `accounts (household_id) WHERE kind = 'shared'` (the design says "one shared Account"; stating it now means #384 can't build a second by accident, and no row can break it today).
2. **A household of one is named for its user.** *(Pending the maintainer's ruling; recommended over: a constant "Household".)* The name is stored text, the user's name followed by "'s household" ("Ada's household"), the user's name cut to fit so the whole is at most 100 characters; a household's name is present and at most 100 characters. It is stored, not derived, so a user's rename later changes nothing in the household, and a list of households (#389) tells them apart. No page shows or edits it in this feature; a manager renames it when a later issue gives them the page.
3. **"A household always has a manager" is enforced by the model and by the parts of the database SQLite can state.** *(Pending the maintainer's ruling; recommended over: a database trigger.)* The database holds: the role `CHECK`, `memberships.user_id` unique, both foreign keys, `NOT NULL` on every column. The model holds: a household is created with its first membership, a manager, in one transaction with the user; and a household with another member can't lose its last manager by demotion, by removal of the membership, or by deleting the user. **No trigger:** `db/schema.rb` doesn't dump triggers, so a volume made from the schema would lack the rule that an upgraded one has. A spec and the upgrade proof check the rule on real rows (a household without a manager is a failure of both).
4. **The export does not carry the household, and the format stays version 4.** *(Pending the maintainer's ruling; recommended over: carrying the name in `profile` and raising to version 5 now.)* The export is one file per account and holds the collection and its profile (design decision 16). A household is a fact about a group, not about the collection; a household of one has a default name, and a person who imports their file onto another instance is made a household there by the same rule that makes every user one. The shared collection's file and its `profile` are #384's (the design's open question 4), and that is the issue that raises the version. The format document's Coverage tables list the new data as "Left out" with the reason (`memberships`, `accounts.household_id`, `accounts.kind`); `households` has neither `account_id` nor `user_id`, so the guard doesn't ask for it, and the format document says in one sentence where it is.
5. **Three migrations, as spec 049 did; the third makes `accounts.household_id` `NOT NULL` by a table copy.** *(Pending the maintainer's ruling; recommended over: leaving the column nullable.)*
   - **(a) Schema.** Creates `households` and `memberships`; adds `accounts.household_id` and `accounts.kind` with `ALTER TABLE … ADD COLUMN`, which copies no table (a `REFERENCES` column is accepted because its default is `NULL`; a `CHECK` stated on the column is tested against every row and is kept by the schema dump when named; the precedent is `AddDecks`). Guarded, so a run that stopped part way is finished by the next boot.
   - **(b) Backfill.** A data migration with no schema change. It reads the users that have no membership in batches of 500, and for each batch, in one short transaction, inserts a household for each user (decision 2's name), the manager membership and the account's `household_id`, with plain SQL and no application model. It is idempotent: it selects only users with no membership, so a second run, or a run that was stopped after some batches, makes exactly the rest and nothing twice; it takes no lock beyond each batch's own write transaction, so the instance's other work waits at most one batch. Cost: users, not lots; ten thousand users are twenty batches.
   - **(c) Tighten.** Makes `accounts.household_id` `NOT NULL`, so "every account has a household" is a fact of the database, as `users.account_id`'s `NOT NULL` is. **What the copy risks.** SQLite can't add `NOT NULL` to a column in place; Rails copies `accounts` (create the new table, copy the rows, drop the old, rename). `accounts` is the most referenced table in the schema: thirteen tables hold a foreign key to it. Eleven have `ON DELETE CASCADE` (`bulk_removals`, `bulk_selection_marks`, `bulk_selections`, `deck_proxies`, `decks`, `import_uploads`, `locations`, `number_entries`, `number_entry_lines`, `scanner_sitting_entries`, `scanner_sittings`), `lots` has the default `RESTRICT` (the reason `Account` declares `lots` before `locations`, `spec/models/account_spec.rb`), and `users` has the default too; a cascade from one of the eleven reaches their own children in turn (a location's lots are refused by the restrict, a deck's zones and proxies go). With foreign keys enforced, the copy's `DROP TABLE accounts` runs those delete rules: the cascades would delete every collector's working state and decks, and the restrict would refuse the drop or, with enforcement off, leave the copy half made. Rails turns enforcement off for a copy only **outside a transaction**, so (c) runs with `disable_ddl_transaction!` (as `AddLocationToLots`, `AddDecks` and spec 049's third migration do), which opens the window that a statement fails part way with no rollback; every step is therefore guarded, and a run that stopped is finished by the next boot. **What proves no row is lost:** the upgrade proof compares every table of the old database with the upgraded one over the columns both have, row by row (`script/upgrade/compare.rb`), and seeds a row in every table including each of those thirteen; `PRAGMA foreign_key_check` and `integrity_check` run on the result; a migration spec runs (c) on a database holding rows in each referencing table and asserts every count is unchanged; and the copy's foreign keys and named checks are read back from the schema dump.
   - **The nullable fallback (a real option).** Skip (c): `accounts.household_id` stays nullable in the database and the model validates it present. *Gains:* no copy of `accounts`, no no-transaction window, two migrations, nothing in this feature can lose a row. *Costs:* the database can't state "every account has a household", so a bug or a hand-written insert can leave an account with none and nothing but a guard spec and the upgrade proof would notice; a fresh volume (made from `schema.rb`) and an upgraded one agree only if the column is nullable in both, so the schema says nullable forever unless a later migration pays the copy then, with more tables referencing `accounts` and more instances to carry through it (the design's own reason for doing this now). The recommendation is (c): the copy has been done safely three times on this schema (`locations` twice, `sessions` once), the proof that guards it exists and this issue is the cheapest time to pay it. The ruling is the maintainer's; if the plan review finds the copy unsafe, the fallback is taken and this spec's version records it.
   - **Reversible:** (c) down makes the column nullable again by the same copy; (b) down does nothing (the rows are removed with their tables, and a second run of its up finds nothing to do); (a) down drops the tables and the columns, and **refuses** (an `IrreversibleMigration` that says what exists) when any household has more than one member or any shared account exists, since the older code can't hold either; a household of one is simply removed with its name.
6. **A personal account is in its user's household.** For a user, `accounts.household_id` of their account equals `memberships.household_id` of their membership. The database can't compare two tables, so the rule is the model's (a user is built with both from one household; a later issue that moves a user changes both in one transaction), and a guard spec and the upgrade proof check it on real rows. A shared account has no user; a personal account has exactly one.
7. **Deleting a user removes their membership, their account, and, when no one is left, their household.** An admin's delete of a user (spec 004 AC-5.4) works as before. A household left with no member is removed in the same delete; a household left with other members keeps them, and the model refuses the delete when the user is the household's last manager and others remain (no page makes such a household in this feature, so only a model spec reaches it; #382 and #383 give it a page and a message). The delete order is the plan's: the membership's and the account's foreign keys decide it.
8. **A household is made by the user model, so every path gets one.** The one place an account is made from a user today (`before_validation :build_account`) also makes the household and the manager membership; the first-run sign-up, the open sign-up, the admin's add-a-user form and `bin/rails collector:user` all go through it, and a spec per path says so. Nothing in a request names a household, a role or a kind (`household_id`, `role` and `kind` are not permitted from parameters).
9. **"Nothing looks different" is checked by four things, beyond the existing specs passing unchanged.** (i) A request spec renders the collection, the admin users page, the account menu, sign-in, sign-up and the catalog search as a collector and as an admin and asserts that none of the bodies contains "household" (case-insensitive), in the page or the head. (ii) The existing tenancy request specs and system specs are not edited, except where they build a user by hand (the factory makes the household), and the run proves they pass. (iii) `bin/rails routes` on the branch and on `main` before it are compared once, at the implementation review, and the empty diff is recorded in `verification.md` (no permanent route-list spec: it would conflict with every branch that adds a route). (iv) The upgrade proof's web leg (spec 031 Story 5) signs in as each seeded user on the upgraded instance and loads the collection, locations and export pages, as it does today, and that leg runs after the backfill.
10. **The upgrade proof gains a household check, and `expected_changes.yml` stays empty.** `compare.rb` reads only the old database's tables and the columns both databases have, so the new tables and columns are invisible to it and no entry would match; the harness gains a check on the upgraded snapshot (and on the restore leg's) that every user has exactly one manager membership, every account a household, a personal account's household is its user's, every household has a manager, and the households' count equals the users' (the seed's two users make two). The seed for the next release (`script/upgrade/seeds/next.rb`) creates its users through the models, so the new tables hold rows, as the seed rule needs.
11. **The ADR is 0030, and the tenancy area doc changes with it.** [ADR 0030](../../adr/0030-a-household-is-a-group-of-accounts.md) supersedes the one-user half of ADR 0017 (an account may now be one of several in a household, `users.account_id` stays unique, an account stays the unit of ownership and privacy) and keeps the rest of ADR 0017 (the `account_id` rule, `Current.account`, 404 for another account's record). ADR 0017 gets a status line saying it is superseded in part; the one-user text isn't rewritten. The doc [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) changes in the glossary, invariants, deletion and accepted limits, and the [`data-portability.md`](../../architecture/data-portability.md) and [export format](../../export-format/README.md) coverage lines change with decision 4.
12. **Hosted-door rules.** *Cost per household:* one household row, one membership row per member, no row per lot or per request. *Stored per account or user:* the household's name and members' roles are the household's, nothing else is stored about a collector's choices. *The operator is not the user:* no admin page changes, so none shows a collection; the household's fields are not on any page.

## User Stories and Acceptance Criteria

### Story 1: A new user starts in a household of one

**As** an operator or a person signing up **I want** every user, however they are made, to be the manager of a household of one **so that** the later features have a household to work with from the first day.

- [ ] **AC-1.1** Given an instance with no user When the first visitor signs up Then a user, their personal account, a household named "<name>'s household" and a membership with role `manager` exist, the account's household is that household, and the page the visitor lands on is the collection as before.
- [ ] **AC-1.2** Given sign-up is open When a person signs up Then they have the same four records, as the manager of a household of their own (not the first user's).
- [ ] **AC-1.3** Given an admin on the users page When they add a user Then the user has the same four records, and the admin's own household is unchanged.
- [ ] **AC-1.4** Given the operator's command When it creates an admin by email Then the admin has the same four records.
- [ ] **AC-1.5** Given a user whose name is 100 characters When the user is created Then the household's name is at most 100 characters and begins with the start of the user's name; given a name of one character Then it is that character followed by "'s household".
- [ ] **AC-1.6** Given a sign-up that is invalid (a blank name, a used email) When it is submitted Then no household, membership or account exists afterwards, and a sign-up that loses the first-user race (spec 004 AC-3.4) leaves none either.
- [ ] **AC-1.7** Given any request that creates a user When its parameters hold `household_id`, `role` or `kind` Then they are ignored: the user's household is a new one, their role `manager` and their account `personal`.

### Story 2: The rules of a household hold

**As** a maintainer of the later households issues **I want** the structure to refuse what a household may not be **so that** a bug in a later page can't leave a household without a manager or a user in two.

- [ ] **AC-2.1** Given a membership When its role is anything but `manager` or `member` Then the model refuses it, and an insert that bypasses the model is refused by the database.
- [ ] **AC-2.2** Given a user with a membership When a second membership is made for them, in the same or another household Then the model refuses it, and an insert that bypasses the model is refused by the database.
- [ ] **AC-2.3** Given a household with two members, one a manager When the manager's role is changed to member, or their membership is removed, or their user is deleted Then it is refused and nothing changes; given the same household with two managers When one is demoted Then it succeeds.
- [ ] **AC-2.4** Given a household of one When its only member's membership is removed through the model on its own Then it is refused (a household is never left with none by that route); deleting the user (AC-4.4) is the only way a household of one goes.
- [ ] **AC-2.5** Given an account When its kind is anything but `personal` or `shared` Then the model refuses it and the database refuses a bypassing insert; given two shared accounts in one household Then the second is refused by the model and by the database.
- [ ] **AC-2.6** Given a shared account When it has a user, or a personal account that has none Then the model refuses it. No shared account exists in any request or in the seed.
- [ ] **AC-2.7** Given a household name that is blank or over 100 characters When it is saved Then the model refuses it.
- [ ] **AC-2.8** Given every user in the test database after any example that makes users When the guard runs Then each has exactly one membership, each household has a manager, and each personal account's household is its user's household (a guard the upgrade proof repeats on real data).

### Story 3: An existing instance gains households on upgrade

**As** an operator **I want** every existing user to have a household after the upgrade **so that** nothing breaks and nothing is left for me to do.

- [ ] **AC-3.1** Given a database as the previous release leaves it (users, accounts, lots, locations, decks, proxies, sessions, working state, the prices database untouched) When the migrations run Then every user has one household named "<name>'s household", one membership with role `manager`, and an account whose household is it, every account kind is `personal`, and the rows of every old table are unchanged.
- [ ] **AC-3.2** Given the migrations have run When the backfill runs again (its migration is applied a second time, or the database is migrated from a state with some users done) Then no household or membership is added or changed and the count of each is the same.
- [ ] **AC-3.3** Given 1,201 users with no membership When the backfill runs Then it makes households in batches of at most 500, each batch one transaction, and every user has exactly one household afterwards; given it stops after the first batch When the migrations run again Then the rest are made and the first batch's are not made twice.
- [ ] **AC-3.4** Given an instance with no users (a fresh volume's first run, or an upgraded instance that never had one) When the migrations run Then they succeed and the first sign-up gets its household by AC-1.1.
- [ ] **AC-3.5** Given the three migrations When the database is rolled back through them Then it returns to the previous release's schema with every old row unchanged; given a household with two members or a shared account When (a) is rolled back Then it refuses, names what exists, and changes nothing.
- [ ] **AC-3.6** Given (c) has run on a database that holds rows in every table that references `accounts` When the counts are compared before and after Then each is equal, `PRAGMA foreign_key_check` and `integrity_check` report nothing, and the foreign keys, named checks and indexes of `accounts` and of its thirteen referencing tables are those of the schema dump.
- [ ] **AC-3.7** Given an older backup When it is restored onto the new code and the instance starts Then the migrations run as in AC-3.1 and every user has a household, and no session the restore didn't end is ended by the migration.
- [ ] **AC-3.8** Given sessions exist before the three migrations run When they have run Then every `sessions` row is unchanged, so a collector signed in before the upgrade is still signed in (spec 049's rule for upgrades; the upgrade proof's behaviour leg signs in with the old password and checks the same).

### Story 4: Nothing looks different

**As** a collector **I want** the app to be exactly what it was **so that** nothing I do or see has to be learned again.

- [ ] **AC-4.1** Given a collector and an admin When each opens the collection, the admin users page, the account menu, sign-in, sign-up and the catalog search Then no body contains "household" (case-insensitive), and each page's status and text equal what they were on `main` before this feature (the existing specs for each, unedited, pass).
- [ ] **AC-4.2** Given the application's routes When `bin/rails routes` on the branch is compared with the output on `main` before this feature Then the diff is empty (checked once at the implementation review and recorded in `verification.md`; not an RSpec example, decision 9).
- [ ] **AC-4.3** Given every existing request spec for another account's record When the suite runs Then each passes unchanged: another account's record is 404, and `Current.account` is still the signed-in user's own account.
- [ ] **AC-4.4** Given an admin deletes a user (spec 004 AC-5.4) When it completes Then the confirmation, the notice and the other accounts are as before, and the deleted user's household, membership and account are gone.
- [ ] **AC-4.5** Given the admin users page When it lists users Then each row, count and button are as before, and no query reads `households` or `memberships`.

### Story 5: The export and the backup stay whole

**As** a collector **I want** my export to round-trip and my instance's backup to keep working **so that** nothing about my data's safety changes.

- [ ] **AC-5.1** Given the export format document When its Coverage tables are compared with the database Then `memberships` is a table "Left out" with its reason, `accounts.household_id` and `accounts.kind` are columns "Left out" with their reasons, the guard passes, and no new field is in the schema or the examples; the format version stays 4.
- [ ] **AC-5.2** Given a collector's export When it is applied to the same account, or to a fresh user's account on a fresh instance Then the lots, locations, decks, proxies and currency round-trip as before, and the account's household, membership and kind are unchanged by the apply.
- [ ] **AC-5.3** Given `backup:create` and `backup:restore` When they run on an instance that has households Then the restored instance has the same households and memberships (they are in the primary database, which the backup holds whole), and `spec/backup_guards_spec.rb` passes unedited.
- [ ] **AC-5.4** Given the format document When it is read Then one sentence says the household isn't in the file, why, and that the shared collection's file (#384) is where it is decided again.

### Story 6: The upgrade proof covers the households

**As** a maintainer **I want** the upgrade proof to fail if the backfill is wrong **so that** an upgrade that gives a user no household can't ship.

- [ ] **AC-6.1** Given the seed of the previous release (`script/upgrade/seeds/0.3.0.rb`), upgraded by the code under test When the harness checks the upgraded snapshot Then every user has exactly one manager membership, every account a household of its user's, every household a manager, the households' count equals the users' and every account's kind is `personal`; a snapshot that breaks any of these fails the run naming it.
- [ ] **AC-6.2** Given the proof's backup leg (spec 031 AC-6.3) When the previous release's backup is restored into the new image Then the same check passes on its snapshot.
- [ ] **AC-6.3** Given the proof's comparison When it runs Then `expected_changes.yml` is empty (`changes: []`), no old table or column is reported changed, and the new tables and columns are not compared.
- [ ] **AC-6.4** Given the seed for the next release When it runs on a fresh instance of the code under test Then `households` and `memberships` each hold a row and no seed exception is added.
- [ ] **AC-6.5** Given a fixture snapshot with a user who has no membership, one with a household with no manager, and one whose account is in another household When the check runs on each Then it fails naming the rule broken (a spec of the harness, not of the application).
- [ ] **AC-6.6** Given `bin/upgrade-smoke` run against the previous release built from its tag and the code under test When it completes Then it passes with the check of AC-6.1 and AC-6.2 (evidence in `verification.md`; it needs the container engine and a slot).

## Functional Requirements

### FR-1: The household structure

A household has a name; a membership puts one user in one household with a role; an account has a household and a kind (decisions 1, 2, 6).

**Must:** keep `users.account_id` unique; keep every `account_id` rule of ADR 0017; give each personal account exactly one user; keep a shared account out of every request and every seed.
**Must not:** add a column to `users`; read or write a household in any controller, view or helper; add `Current.household`.

### FR-2: Every user is made with their household

The user model makes the household, the manager membership and the account together, in the transaction that saves the user (decision 8).

**Must:** work for the four paths of Story 1; roll back with the user; take the household's name from decision 2.
**Must not:** accept a household, role or kind from a request; make a household for a user who already has one.

### FR-3: The migrations

Three migrations, in the order of decision 5.

**Must:** run unattended from the previous release and from any older one; be guarded so a stopped run is finished by the next boot; run (c) without a transaction; touch no table the previous release's code reads other than `accounts`.
**Must not:** edit a released migration; reference an application model; sign anyone out; write a row per lot, per location or per request.

### FR-4: The upgrade proof

The harness checks the upgraded and the restored snapshots (decision 10).

**Must:** fail naming the broken rule; leave `expected_changes.yml` empty.
**Must not:** weaken a comparison of an old table.

### FR-5: Documentation

The ADR, the tenancy area doc, the format document's Coverage and one sentence, `CLAUDE.md`'s Project Status line for accounts, the specs index (decision 11).

**Must:** record the supersession in this spec, ADR 0030 and the index in both directions (`.claude/rules/documentation.md`).
**Must not:** rewrite ADR 0017's text, or restate an area's rules in `CLAUDE.md`.

## Non-Functional Requirements

### Performance

- The backfill's batch is a short write transaction, so another request waits at most one batch's write; on 10,000 users it makes 20 batches and completes in seconds (measured by a `timing: true` example on the plan's larger count, not asserted as a hard bound).
- A request's queries are unchanged: no request reads a household. A new user costs two extra inserts (household, membership).

### Security

- `household_id`, `role` and `kind` are never permitted from parameters. Another account's record is still 404; no household rule gives one user a view of another's collection.
- The admin gate and the admin pages are unchanged; no admin page shows a household, a role or a collection.
- No migration, spec or seed runs the `sqlite3` command or a production-environment task.

### Reliability

- A migration that stops part way is finished by the next boot (guards, idempotent backfill); a failed (c) leaves `accounts` as it was or finished, never missing rows (AC-3.6).
- A restore of an older backup is migrated by the same migrations (AC-3.7).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A user is created and the household or membership insert fails | The whole write rolls back; no user, account, household or membership remains; the sign-up or admin form shows the error it shows for any failed save |
| The backfill is stopped after some batches | The next boot's migration makes the households of the users that have none and no other; no user has two |
| The backfill meets a busy database | A batch's transaction waits on the busy timeout as every write does; a failure ends the migration, and the next boot resumes it |
| (c) stops between its steps | Its guards finish it on the next boot; the proof and AC-3.6 read the result |
| (a) is rolled back with a two-member household or a shared account | Refused: "N households with more than one member and M shared accounts exist; remove them before rolling back"; nothing changes |
| An admin deletes the last manager of a household with other members | Refused by the model; no page makes such a household yet (#382, #383) |
| A restored backup from before this feature | Migrated at the next start like an upgrade; households exist for every user |

## Open Questions

- [NEEDS CLARIFICATION: decision 2, the name of a household of one: "<name>'s household" (recommended) or a constant "Household". The maintainer rules.]
- [NEEDS CLARIFICATION: decision 3, the "always has a manager" rule: model plus the database's checks (recommended) or a trigger as well (rejected here for the schema dump). The maintainer rules.]
- [NEEDS CLARIFICATION: decision 4, the export: not carried, version 4 stays (recommended) or the name carried in `profile` at version 5. The maintainer rules.]
- [NEEDS CLARIFICATION: decision 5, migration (c): the table copy making `accounts.household_id` `NOT NULL` (recommended) or the nullable fallback. The maintainer rules; the risks and costs of both are in the decision.]
- [NEEDS CLARIFICATION: decision 5's partial unique index on the shared account, kept or left to #384. Recommended: kept.]

## Out of Scope (Future Considerations)

- Joining, leaving, removing a member, handing the manager role over (#381 to #383); the working collection and the shared collection (#384); transfers and borrowing (#385 to #388); households on the admin users page (#389).
- A household's name shown or edited anywhere; the roles shown anywhere.
- A plan per household (#393).
- Rewriting ADR 0017's text. It stays as written, with its status line pointing to ADR 0030.
