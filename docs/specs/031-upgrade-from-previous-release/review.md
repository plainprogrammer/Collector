# Spec 031: Mode A Review

**Reviewer:** independent read-only agent (Opus), `sdd-superpowers:sdd-review` Mode A, 2026-10-23, on spec version 1.0.0.
**Verdict on 1.0.0:** NEEDS REVISION (3 critical, 12 important, 8 minor). **After fixes (1.0.1):** the findings below are addressed; the spec still needs the maintainer's approval and rulings on decisions 4 to 10 before a plan (hard gate).

Facts the review confirmed against the repo: the tags and their migration counts (11, 14, 14, main 20), that no released migration file was edited or deleted, the entrypoint, `.dockerignore`, `bin/image-smoke`, `bin/backup-smoke`, the image job's order and gating, and spec 030's quotes.

## Findings and what was done

| # | Severity | Finding | Fix in 1.0.1 |
|---|---|---|---|
| 1 | Critical | A stale expected change breaks `main` and every PR once a release is tagged | Decision 6, AC-4.5, decision 9: an entry whose migration the previous release has is retired (ignored, printed); only an entry that matches nothing while its migration is unreleased fails; deleting retired entries is a post-tag step |
| 2 | Critical | The `image` job's checkout has no tags or history | Decision 2: both jobs fetch full history and tags; the missing-tags rule applies to `bin/upgrade-smoke` too (AC-8.5) |
| 3 | Critical | Helpers under `lib/` would ship in the image (FR-8) | Helpers under `script/upgrade/`; `.dockerignore` added to the documents that change; FR-8 |
| 4 | Important | "Sign-up closed" is the default, so it proves nothing | Seed sets sign-up open (AC-2.3, AC-5.3) |
| 5 | Important | Catalog seeding vs "only through `Catalog::Refresh`" | Decision 4: direct model rows, as `bin/backup-smoke` does, stated as a departure confined to the throwaway volume |
| 6 | Important | Unlimited coverage exceptions | Decision 5 and AC-2.5: `seed_exceptions.yml`, per release, printed, fails for a table the release lacks; the plan lists those for v0.2.1 |
| 7 | Important | No kind for rows a migration adds; AC-4.2 case wrong | `rows_added` kind; AC-4.2 reworded |
| 8 | Important | AC-3.4 cited a guard criterion that did not exist | AC-3.4 reworded; AC-8.3 is the command allowlist; first boot on an empty volume loads the release's schema (decision 4) |
| 9 | Important | AC-7.2 wrong on the matrix and untestable on a branch | AC-7.2 and decision 8: no tag of the release is created; an untagged digest may remain; a throwaway failing pre-release tag verifies it |
| 10 | Important | Backup leg's checks and CI exercise | AC-6.2 lists the checks, AC-5.7 excluded; decision 7 and AC-6.5: proved once by hand now, in CI from the first release with the task |
| 11 | Important | Hand-run with two images: which version? | Decision 2 "By hand": image version label or `--previous-version` |
| 12 | Important | Which release the guard uses on a tag build; pre-releases | Decision 2 "The tag being built" |
| 13 | Important | Scope: backup leg, ordering rule | Backup leg justified in decisions 7 and 10; the ordering rule was also factually wrong (Rails runs any pending version) and was removed |
| 14 | Important | Credentials on non-PR runs contradict FR-6 and AC-1.6 | Decision 3, AC-1.6, FR-6: anonymous on PRs; no login, secret or permission of the check's own elsewhere |
| 15 | Important | Supersession of spec 030 not recorded | Supersedes section and the index row |
| m | Minor | Retry count, AC-5.7 job named, AC-7.4 pass/fail, AC-2.2 untestable clause, seed deliverables, open questions repeating decisions | Fixed in the spec (AC-1.5, AC-5.7, AC-7.4, AC-2.2, decision 10, Open Questions) |

Not changed: the review noted that FR-4 and AC-1.3 name mechanisms (SQLite access, image labels). They are kept: this is an infrastructure spec whose outcome is those mechanisms' result, and the plan owns the rest.

## Result

**READY TO PLAN once the maintainer approves** (1.0.1). Three decisions (1 to 3) are ruled; 4 to 10 are recommendations awaiting rulings.

---

# Round 2: second Mode A review (Opus, 2026-10-23, on 1.0.1 at `cac9cf9`)

**Verdict on 1.0.1:** NEEDS REVISION (1 critical, 6 major, 12 minor). The review agreed with decisions 4 to 10, which the maintainer confirmed as recommended on 2026-10-23 (marked "ruled 2026-10-23" in 1.1.0). **After fixes (1.1.0):** every finding is taken; none changes a ruled decision. The spec awaits the maintainer's approval before a plan.

| # | Severity | Finding | Fix in 1.1.0 |
|---|---|---|---|
| C1 | Critical | `next.rb` is never coverage-checked, so `main` can go red after a tag | AC-2.6 applies AC-2.5's coverage rule to `next.rb`'s database, exceptions keyed `next` in `seed_exceptions.yml`; the release step renames the key (decisions 5 and 9, AC-9.1); Error Scenarios row |
| M1 | Major | The WAL may survive the stop; a bare main file can lose rows | Decision 5 and AC-2.4: clean exit = status 0 or 143 (137 fails); copy the main file with `-wal` and `-shm`; consolidate with `VACUUM INTO`; compare only the snapshot; Error Scenarios row |
| M2 | Major | When the upgraded database is copied is undefined while behaviour checks write | New AC-2.9 and decision 5: upgrade, `/up`, stop, snapshot, compare, restart, then behaviour checks; their writes are never compared; AC-3.2, 3.5, 4.1, 6.2 read the snapshot |
| M3 | Major | The image job has no Ruby for the comparer | Decision 5: host Ruby from `ruby/setup-ruby` with the cached bundle (`sqlite3`, `json_schemer`), not either image; AC-8.3, workflow in Documents that change, time bar (decision 8, AC-7.4), Error Scenarios row |
| M4 | Major | AC-6.5's hand run can't run for a non-release image | Decision 2 "By hand": `--previous-ref <git ref>` (tree from the ref, `seeds/next.rb`, `next` exceptions, states it is no release proof); AC-6.5 uses it |
| M5 | Major | AC-5.3's statuses can't see sign-up open | AC-5.3 checks the sign-up form (`user[email_address]`) is shown and not the closed notice, on both instances |
| M6 | Major | Spec 030's *Superseded by* cell missing | The index cell for 030 added; AC-9.3 requires both directions; Supersedes section |
| m1 | Minor | CI and local resolve different releases | One resolver with a fixed order (decision 2), AC-1.7 |
| m2 | Minor | Label fallback covers only an absent label | Decision 2: absent or non-stable label needs a flag; flag wins; disagreement printed |
| m3 | Minor | "19 tables" reads as 19 exceptions | Decision 5 reworded |
| m4 | Minor | Digest encoding undefined | Decision 5 fixes `quote()` per value, SHA-256 per row and per table; AC-4.7 covers a table without a primary key and a spec on the encoding. Reporting the ordering columns' values for such a table is allowed in NFR Security (the seed's own values) |
| m5 | Minor | An entry's version may name no migration | Decision 6 and AC-4.5: the version must be a file in the code under test's `db/migrate/` |
| m6 | Minor | AC-8.3 allowlist incomplete | AC-8.3 lists categories (file operations, backup tasks, host harness commands); the plan holds the exact allowlist; the forbidden `db:*` tasks stay a spec check |
| m7 | Minor | Time budget omitted three costs | Decision 8 and AC-7.4 name the Ruby setup, `next.rb`'s boot, the restart and the backup leg; 10 minutes is the upgrade step's timeout, the 5-minute target covers both steps |
| m8 | Minor | Step 4 is the export restore | Decision 9, Goals, Problem Statement, AC-9.1: the proof replaces the upgrade part of step 5; step 4 unchanged |
| m9 | Minor | AC-5.7 not testable | AC-5.7: a `perform_later` through `bin/rails runner` returns a job whose row is in `solid_queue_jobs` |
| m10 | Minor | The failing-tag test needs a commit that passes `ci` | AC-7.2 says how the failure is induced, that `ci` must be green, and that the maintainer pushes the tag |
| m11 | Minor | Schema-loaded old database vs a long-lived file | Named in Non-Goals |
| m12 | Minor | "No tag" pass vs fetch failure | Decision 2 "None" and AC-8.5: "no previous release" only when tags are present and none is stable, or there is no remote |

Not taken: none. One choice of mine within the review's options: for M2 the spec stops and restarts the upgraded container (a fourth boot, counted in the time bar) instead of a `VACUUM INTO` through `bin/rails runner` on the running container, because the stop gives one path for both databases and the clean-exit check.

## Result (round 2)

**READY TO PLAN once the maintainer approves** (1.1.0). Decisions 1 to 10 are all ruled.
