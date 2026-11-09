# Feature 049: Sessions Expire After 30 Days Unused, and Stop Storing the Address and User Agent

**Status:** Approved on 2026-11-09 by the coordinator under the maintainer's delegation (Gate A), with decisions 6–11 as recommended; Fable review round 1 (APPROVE WITH CHANGES) fixed, no round 2
**Version:** 1.0.0
**Created:** 2026-11-09
**Last Updated:** 2026-11-09
**Branch:** `228-session-idle-expiry`
**Issue:** [#228](https://github.com/plainprogrammer/Collector/issues/228) (from [#218](https://github.com/plainprogrammer/Collector/issues/218), rulings 1 and 2)
**Depends on:** [spec 004](../004-design-system-collection/spec.md) (FR-2, sessions and sign-in), [spec 006](../006-collection-list-view/spec.md) (a session's bulk selection and Undo, FR-4, FR-6), [spec 030](../030-backup-restore/spec.md) (decision 3, a restore ends every session), [spec 031](../031-upgrade-from-previous-release/spec.md) (the upgrade proof). Area doc: [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md)
**Frozen:** the current rules are in [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) (whole spec); see the [specs index](../README.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-09 | First draft, from issue #228 and the tenancy area doc's "A session" section |
| 0.2.0 | 2026-11-09 | Spec review round 1 (Fable, APPROVE WITH CHANGES, 0 blocking, 2 major, 9 minor) fixed: "expired" is defined on the stamp, which the app can read, not on the true last use (M1); the stamp is a column of its own and `updated_at` is not rewritten, so the upgrade proof's differences are named (M2); the status line's decision numbers; the area doc keeps four unsourced behaviours, not five; FR-3 covers a stamp in the future; the write prohibitions say `sessions`; the busy-database error class; the migration precedent (`disable_ddl_transaction!`); `seeds/0.2.1.rb` unchanged and the spec helper; FR-1 names the Active Storage gate |
| 1.0.0 | 2026-11-09 | Approved at Gate A; recommendations 6–11 accepted. Notes for the plan: prove with a migration spec that the column drop keeps a session's bulk selection and Undo removal (a cascade would delete collector state), and count writes with a statement-counting helper (spec 032 AC-11.12's) |

---

## Problem Statement

A session never ends on its own. `Authentication#start_new_session_for` sets a signed cookie that lasts 20 years, and nothing ends a `sessions` row except signing out, an admin or the operator setting a new password, deleting the user, or a restore. A lost phone or a shared browser keeps its access until someone resets the password. Each session row also keeps the client's address and user agent, which nothing reads: personal data about a collector, held for as long as the session lives, which is for ever ([#218](https://github.com/plainprogrammer/Collector/issues/218) 1 and 2).

This spec ends a session after 30 days without use, records use cheaply, sweeps the dead rows every night, and stops storing the address and the user agent (and removes what is stored).

> **Terms.**
> - A *session* is a `sessions` row and the cookie that names it (spec 004 FR-2; the area doc's Glossary).
> - A request *uses* a session when the app resolves that session from the cookie (decision 6).
> - The *stamp* is the session's stored last-use time: the time of the last request that updated it, or, until one has, the time the session was created. It is updated at most once in 24 hours (decision 2), so it is less than 24 hours older than the true last use.
> - A session is *expired* when its stamp is 30 days or more old (the *idle limit*). Every rule of this spec that says a session is expired means this, for the request path and the sweep alike.

## Goals

- A session unused for 30 days ends: the next request with it is treated as having no session, and the collector is asked to sign in.
- A session in regular use keeps going: there is no absolute lifetime.
- Ordinary requests don't write to the database; recording use costs at most one write per session per day.
- A nightly job deletes expired sessions, and the bulk selection and Undo that belong to them.
- A session stores neither the client's address nor its user agent, and the stored values are gone after the upgrade.
- An upgrade signs no one out: every session that exists at the upgrade gets 30 days from the upgrade.

## Non-Goals

- **An absolute lifetime** (maximum age whatever the use). Ruled out in #228.
- **A "your sessions" list,** sign out everywhere, or any page that shows sessions. The address and user agent are not kept for one.
- **A different idle limit per instance or per account,** or a setting for it. 30 days is a constant (decision 1).
- **A new message on the sign-in page** for an expired session (decision 9).
- **Changing what ends a session today:** sign-out, a new password, deleting the user and a restore are unchanged (spec 004 AC-4.7, AC-5.3, AC-5.4; spec 030 decision 3).
- **Rewriting a backup or an export already taken.** A backup made before the upgrade holds the old session rows with their addresses and agents; a restore deletes every session (spec 030 decision 3), so the values do not come back into a running instance. An export never held sessions (the format's Coverage: "Left out").
- **The development-only request log** (`COLLECTOR_REQUEST_LOG`), which writes each request's user agent to a file outside the database (spec 007 AC-6.5). It is not a session.
- **The sign-in rate limit,** the instance setting and the other behaviours of #218 (their own issues).

## Users and Context

**Primary users:** collectors, who sign in on a phone or a laptop and expect to stay signed in while they use Collector, and to be asked again after a long absence.

**Secondary users:** operators (self-hosters, admins), who run the instance: they get a table that does not grow without bound, and no personal data held for nothing.

**Usage context:** a collector opens Collector now and then, from a few times a day to a few times a month. The nightly sweep runs inside the app's own Solid Queue, as the stored-upload sweep does (spec 028 decision 9).

**User mental model:** "I stay signed in while I use it; if I don't use it for a month it signs me out."

## Decisions

### Ruled by the maintainer (#228)

1. **Idle expiry only, 30 days.** A session ends after 30 days without use. A session in regular use keeps going; there is no absolute lifetime.
2. **Use is recorded at most about once a day.** The stamp is updated only when it is 24 hours or more old, so an ordinary request writes nothing. A new session's stamp is its creation time. Consequence: the stamp lags the true last use by less than 24 hours, so a session used within the last 29 days is never expired and one unused for 30 days always is; one unused for 29 to 30 days may or may not be.
3. **A nightly job deletes expired sessions** (`config/recurring.yml`).
4. **An expired session is no session.** A request with one is treated as having none: a collector is redirected to sign in (a visitor to an open endpoint is a visitor).
5. **The address and the user agent are no longer stored,** and the stored values are removed. The two columns are dropped in a reversible migration that is safe to run unattended (`.claude/rules/sqlite-and-migrations.md`).

### Recommended for Gate A

6. **What "use" means: any request that resolves the session from the cookie.** That is every request that reaches `resume_session`: a page, a form post, a Turbo refresh, and a request to an open catalog page that a collector makes while signed in (`OpenCatalog` resumes the session). A request with no cookie, a cookie that doesn't verify, a row that is gone or an expired session is not a use. *Why:* the simplest rule that tells "someone is at the keyboard" from "nothing happened"; the alternatives (only non-GET requests, or only page loads) would sign out a collector who only browses. *Cost, accepted:* the admin pages' polling (`poll` controller, spec 015 FR-4) refreshes a visible tab only while a job is in flight, so such a tab keeps its session alive for as long as the job runs; the work is finite and a person is looking at the page. *Alternative:* only requests with a user action (not the poll's) count; it needs a marker on the poll's requests and is not worth a header for a bounded case.
7. **The cookie's own lifetime: 30 days, from the last stamp.** The cookie is no longer permanent (20 years). It is set to expire 30 days after it is issued, and re-issued (with the same attributes: signed, HTTP-only, same-site lax, secure on HTTPS) in the response of the request that updates the stamp, so a browser drops it at about the time the server would. The server's check is the authority; the cookie's date is tidiness (a dead cookie isn't kept for 20 years) and never extends a session. *Alternative:* leave the cookie permanent; correct, but a browser keeps sending a dead cookie for 20 years. The cost of the recommendation is one cookie write per session per day, in a response that already writes.
8. **The sweep is a Solid Queue recurring job with `limits_concurrency`,** `config/recurring.yml` entries in `production` and `development` (as the stored-upload sweep has), queue `default`, at night (4:10 am every day; the plan may move the minute). Two sweeps never run at once (`.claude/rules/background-jobs.md`: one at a time, as the sweep is cross-tenant and SQLite has one writer). It is idempotent: a second run right after the first deletes nothing. It retries on `SQLite3::BusyException` with backoff. *Alternative:* no concurrency limit, since an overlapping delete is harmless; the rule says to limit jobs that must not overlap and costs one line.
9. **What an expired session's next request shows: exactly what no session shows.** A collector's GET is redirected to the sign-in page and the path asked for is kept to return to, as for any request with no session (spec 004 AC-4.4); a non-GET is redirected to sign-in and changes nothing. There is no "your session expired" message. *Why:* the cookie itself expires at 30 days (decision 7) and the sweep removes the row, so after a long absence most requests arrive with no cookie or a gone row, and no message could be shown for them; a message only for the day-30-to-sweep window would be inconsistent. The expired row is not deleted by the request (a read doesn't write); the response removes the cookie.
10. **The sweep deletes in batches of 1,000 rows,** each batch its own short write transaction, until none is left. *Why:* `sessions` holds a row per sign-in, so a small instance has tens of rows and a long-lived one a few thousand; 1,000 keeps each transaction short (`.claude/rules/background-jobs.md`, `sqlite-and-migrations.md`) without a long loop. The delete cascades to `bulk_selections` and `bulk_removals` in the database (spec 006 FR-4, FR-6; `spec/backup_guards_spec.rb`), so the job runs no per-row callback.

### Also recommended: what the upgrade does to sessions that exist

11. **Every session that exists at the upgrade has its stamp set to the time of the upgrade.** None expires at once, even one created a year ago, because the only older record is its creation time, which says nothing about use. *Cost, accepted:* a lost phone's session lives up to 30 more days after the upgrade. The two columns' values are discarded; the sessions, and their bulk selections and removals, are kept (spec 031: the upgrade proof lists the dropped columns as expected changes). The stamp is a column of its own (name left to the plan); `updated_at` stays Rails' bookkeeping and is not rewritten, so the upgrade proof's difference is the dropped columns and the added column's backfill. *Alternative:* set it to the row's creation time: every session older than 30 days would end at the first sweep and everyone would sign in again, including collectors in daily use.

## User Stories

### Story 1: A session unused for 30 days ends

**As a** collector who has left a device signed in
**I want** an unused session to end by itself
**So that** a lost phone or a shared browser doesn't keep access for ever

**Acceptance criteria:**

- [ ] **AC-1.1** Given a session whose stamp is 29 days and 23 hours old When a request carries its cookie Then the request is signed in as that user, as today.
- [ ] **AC-1.2** Given a session whose stamp is 30 days and one second old When a collector's GET carries its cookie Then the response redirects to the sign-in page, the path asked for is kept as the page to return to after signing in (spec 004 AC-4.4), and no signed-in page is shown.
- [ ] **AC-1.3** Given an expired session When a request that is not a GET carries its cookie Then the response redirects to the sign-in page and the data the request would have changed is unchanged.
- [ ] **AC-1.4** Given an expired session and an instance with the open catalog (spec 023) When its cookie opens a catalog page Then the page is shown as to a visitor (the header's sign-in link, no collection signals).
- [ ] **AC-1.5** Given an expired session When a request carries its cookie Then the request writes nothing to `sessions` (the row is not deleted or changed) and the response removes the `session_id` cookie.
- [ ] **AC-1.6** Given a collector who signs in again after expiry When the sign-in succeeds Then a new session exists with its own id and the expired one is not reused.
- [ ] **AC-1.7** Given a collector who makes a request every 10 days for 100 days (time advancing between requests) When each request carries the session's cookie Then every request is signed in: there is no absolute lifetime.
- [ ] **AC-1.8** Given an expired session that has a bulk selection and a bulk removal with Undo When the nightly sweep runs Then the session, its selection and its removal are gone (Story 3).

### Story 2: Use is recorded about once a day

**As an** operator
**I want** ordinary requests not to write to the database
**So that** a busy collector doesn't make the database work for nothing

**Acceptance criteria:**

- [ ] **AC-2.1** Given a collector signs in or signs up When the session is created Then its stamp is that moment.
- [ ] **AC-2.2** Given a session whose stamp is 23 hours old When a request carries its cookie Then the stamp is unchanged and the request makes no write to `sessions`.
- [ ] **AC-2.3** Given a session whose stamp is 24 hours old or more (and not expired) When a request carries its cookie Then the stamp becomes the time of the request, and the response sets the `session_id` cookie again to expire 30 days from then (decision 7).
- [ ] **AC-2.4** Given a signed-in collector When each of these carries the cookie: a GET of a page, a form post, and a visit to an open catalog page (when the instance has one open) Then each counts as a use (the stamp updates when it is 24 hours old).
- [ ] **AC-2.5** Given a request with no cookie, a cookie that doesn't verify, or one that names a row that is gone When it reaches the app Then nothing is recorded and no row is created.
- [ ] **AC-2.6** Given a successful sign-in When the response is sent Then the cookie is HTTP-only, same-site lax, signed, secure when the request is HTTPS (as today), and expires 30 days from the sign-in instead of being permanent.
- [ ] **AC-2.7** Given a session used twice within one hour When both requests complete Then the second made no write to `sessions` (only the first request after the stamp is 24 hours old writes).
- [ ] **AC-2.8** Given a session whose stamp is later than the time of the request (the host's clock was set back) When a request carries its cookie Then the request is signed in, and the stamp becomes the time of the request.

### Story 3: A nightly job deletes expired sessions

**As an** operator
**I want** expired sessions removed
**So that** the table doesn't grow and no personal data outlives its use

**Acceptance criteria:**

- [ ] **AC-3.1** Given sessions that are expired and sessions that are not When the job runs Then each expired session is deleted, with its bulk selection and bulk removals, and no other session or selection is changed.
- [ ] **AC-3.2** Given no expired session When the job runs Then it changes nothing; given it has just run When it runs again Then it deletes nothing and does not fail.
- [ ] **AC-3.3** Given more expired sessions than one batch (the batch size reduced in the example, or 2,500 rows) When the job runs Then every expired session is deleted, each batch in its own transaction (the plan picks how an example observes it).
- [ ] **AC-3.4** Given the job When it runs Then it touches only `sessions` and the rows that cascade from it: no user, account, lot, location or other table changes.
- [ ] **AC-3.5** Given a batch that meets a busy database (`SQLite3::BusyException`, or the `ActiveRecord::StatementTimeout` Rails raises for it) When the job runs Then it is retried later and the job completes the deletion; given an error that is not transient it is not retried: the job fails and shows under Failed.
- [ ] **AC-3.6** Given `config/recurring.yml` When read for `production` and `development` Then each has an entry for the job, daily, in a night hour, on the `default` queue.
- [ ] **AC-3.7** Given two sweeps queued together When both are ready Then only one runs at a time (the job's declared concurrency limit, one key for all).
- [ ] **AC-3.8** Given an expired session of a user and a non-expired session of another account When the job runs Then it deletes the first and leaves the second and both accounts (it is cross-tenant by nature and says so in a comment, `.claude/rules/multi-tenancy.md`).

### Story 4: The address and the user agent are no longer stored

**As a** collector
**I want** Collector not to keep my address and browser for nothing
**So that** no personal data is held that nothing uses

**Acceptance criteria:**

- [ ] **AC-4.1** Given a successful sign-in or sign-up When the session is created Then the `sessions` row has no address and no user agent, and the table has no column for either.
- [ ] **AC-4.2** Given a database at the previous schema with sessions that hold an address and a user agent, a bulk selection and a bulk removal When the migration runs Then every session, selection and removal is still there with the same ids and the same user, and the two columns and their values are gone.
- [ ] **AC-4.3** Given the same database When the migration has run Then every session that existed has a stamp equal to the migration's time (not its creation time), so a sweep run right after deletes none, even one created a year before (decision 11).
- [ ] **AC-4.4** Given the migration When it runs forward, backward and forward again (`db:migrate:redo`, or a migration spec) Then each run succeeds, the backward run restores the two columns empty and removes the stamp's column, and the forward run after it leaves the same table as the first.
- [ ] **AC-4.5** Given an upgrade from the previous release's image When `bin/upgrade-smoke` compares the databases Then the two columns are listed as expected `dropped` changes of this migration with spec 049 as the reason, `seeds/next.rb` creates sessions without them, `seeds/0.2.1.rb` (which runs in the previous image) is unchanged, the stamp column's backfill is listed too if the proof reports it, and the proof passes. The spec helpers that create sessions (`spec/support/backup_helpers.rb`) stop passing the two attributes.
- [ ] **AC-4.6** Given `spec/backup_guards_spec.rb` and the export format's Coverage guard (`ExportFormat`) When the suite runs Then both pass without a change to the format or its version: `sessions` stays "Left out", and every foreign key to `sessions` still cascades.
- [ ] **AC-4.7** Given a backup taken before the upgrade When it is restored onto the upgraded release Then the restore succeeds (its sessions step deletes the old rows, spec 030 decision 3) and the migration then runs on the restored database.

### Story 5: The documents say so

- [ ] **AC-5.1** Given [`tenancy-and-accounts.md`](../../architecture/tenancy-and-accounts.md) When read Then "A session" (created, resumed, ended) states the 30-day idle expiry, what a use is, the once-a-day stamp, the cookie's lifetime, the sweep and that an expired session is no session; the Glossary, the Invariants' list of jobs and of cross-account reads name the sweep; the Named constants table has the idle limit, the stamp's interval, the batch size and the cookie's lifetime; the Decisions section replaces "Six behaviours have no spec source" with four, and the "Accepted limits" entries for sessions (a session lasts until ended; the address and user agent) are removed; each with spec 049 as the source. (Verified by reading, recorded in `verification.md`.)
- [ ] **AC-5.2** Given `docs/specs/README.md` When read Then it has row 049 with the issue, the area it covers and what it supersedes (spec 004 FR-2's lifetime only by silence: no criterion is changed).
- [ ] **AC-5.3** Given `docs/backup-restore.md` and `README.md` When read Then nothing says a session lasts until ended; if a sentence does, it is corrected. (Verified by reading.)

## Functional Requirements

- **FR-1** The app must treat a session as no session when it is expired, in the same place that finds the session from the cookie, so every endpoint that resolves a session (`require_authentication`, `authenticated?`, the open catalog, and the Active Storage gate, which includes `Authentication`) agrees.
- **FR-2** The expiry rule must be defined once and used by the request path and the sweep alike, so a session the request rejects is the one the sweep deletes.
- **FR-3** A request that uses a session must update the stamp only when it is 24 hours or more old or later than the time of the request, and in that request re-issue the cookie with a 30-day lifetime and the same security attributes.
- **FR-4** The sweep must delete expired sessions in batches, each in its own transaction, be idempotent, run one at a time, retry a busy database, and be scheduled nightly in `config/recurring.yml`.
- **FR-5** `sessions.ip_address` and `sessions.user_agent` must be removed, and no code may read or write them.
- **FR-6** The migration must be reversible, keep every existing session and what cascades from it, give every existing session a stamp of the migration's time, and be safe to run unattended on a self-hoster's upgrade.
- **FR-7** The upgrade proof's `expected_changes.yml` must list the dropped columns, and `seeds/next.rb` must create sessions without them.

**Must not:**

- Add an absolute session lifetime, or extend a session by anything but a use.
- Write to `sessions` on a request that does not update the stamp, or on one with an expired session.
- Read the address or the user agent into a log line or a record in their place.
- Change the export format, its version, or what the export holds.
- Change what ends a session today, or the cascade of a session's selection and Undo.

## Non-Functional Requirements

### Performance

- A request with a session within a day of its stamp issues no more queries than today. The sweep deletes in batches of 1,000, each a short transaction.

### Security

- The cookie stays signed, HTTP-only, same-site lax and secure on HTTPS (spec 004 NFR Security). The server decides expiry; the cookie's own date is never trusted to extend a session.
- An expired session can't be revived: its row is not touched by a request, and a later sign-in makes a new one.
- No address or user agent is held in the database after this spec.

### Reliability

- The migration runs unattended from any prior version: it keeps sessions (no one is signed out) and is reversible.
- A failed or missed sweep is harmless: expiry is enforced by the request path, so a session the sweep has not yet deleted is already refused.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A request with an expired session's cookie | Treated as no session (AC-1.2, AC-1.3); the cookie is removed; nothing is written |
| A signed-in collector's request, stamp under 24 hours old | Signed in; no write |
| The same, stamp 24 hours old or more | Signed in; the stamp and the cookie are renewed |
| The sweep meets a busy database | The batch is retried later (AC-3.5); expiry is still enforced by requests |
| The sweep is missed for several nights | The next run deletes everything expired, in batches |
| A session expires while a bulk selection is open | The next request redirects to sign-in; the selection goes with the session at the sweep |
| An instance is upgraded | Every session lives 30 more days from the upgrade (decision 11); the two columns are gone |
| A user is deleted, a password is changed, a restore runs | As today (the sessions end); unchanged |
| The clock was set back on the host, so a stamp is later than now | The session is not expired, and the stamp counts as 24 hours old: the next request rewrites it to now (AC-2.8) |

## Open Questions

- Decisions 6–11 are recommendations for the coordinator's Gate A ruling: the cookie's lifetime (7), what a use is (6), the sweep as a recurring job with a concurrency limit (8), the batch size (10), what an expired session shows (9), and the upgrade's treatment of existing sessions (11).
- For the plan: dropping columns from `sessions` on SQLite makes Rails rebuild the table, and the drop of the old table inside a transaction can run the foreign keys' `ON DELETE CASCADE` on `bulk_selections` and `bulk_removals` (AC-4.2). The project has the answer already: `db/migrate/20261103100001_add_currency_to_accounts.rb` (and `AddLocationToLots`) use `disable_ddl_transaction!` with each step guarded by `column_exists?`, and `spec/migrations/add_currency_to_accounts_spec.rb` asserts it. The plan reuses that pattern and its spec's shape; the migration is then not atomic, as those are not.

## Supersedes

None. Spec 004 FR-2 and NFR Security never promised a lifetime; the area doc recorded the lack as "no spec source" ([#218](https://github.com/plainprogrammer/Collector/issues/218) 1 and 2), and this spec is its source.

## Out of Scope (Future Considerations)

- A page listing a collector's sessions, with sign out of a single device.
- A per-instance idle limit setting.
- A "your session expired" notice (decision 9).
- Counting only user-initiated requests as use (decision 6, the alternative).
