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
