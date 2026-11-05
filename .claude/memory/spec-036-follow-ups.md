---
name: spec-036-follow-ups
description: What spec 036 (advisory response, merged 2026-11-03) still leaves open: the maintainer's seven Quickstart checks, the Dependabot-alerts question, two optional example tightenings, and two stale statements about the repository being private
metadata:
  type: project
---

Spec 036 (issue #164, pull request #163, merge commit `8d54059`) merged on 2026-11-03: Dependabot's security updates for the Ruby gems as one group, a daily audit workflow (`.github/workflows/advisory-audit.yml`, 05:17 UTC), and the response to a red audit in `docs/architecture/release-and-deploy.md`. Reviewed SPEC-ALIGNED, distilled, its plan retired in `3ebd563429e487d6f03f5bf33c2490664a7d353b` and the roadmap line marked Done (both in the follow-up pull request that opened after the merge).

**Still open, all the maintainer's:**

- The seven Quickstart checks, in the order in the retired plan (`git show 3ebd563429e487d6f03f5bf33c2490664a7d353b^:docs/specs/036-advisory-response/plan.md`, last section; results go in the second table of `verification.md`): the first hand run on `main` before the throwaway-branch run (AC-2.7 before AC-2.6), the throwaway branch locking the lockfile of `922c426`, the failed run's notification, a cron change in a commit of the maintainer's own pushed to `main` (it also updates the area doc's schedule row), Insights for the `bundler` job, the next batch of security updates, and the Dependabot alerts for the five gems.
- The open question (Decision 4): why Dependabot's security updates opened nothing, even for the direct gem sqlite3. If no alert was created, `sdd-spec-update` comes before any work on `allow: indirect`.
- Optional, from the implementation review (not done): reject a job-level `continue-on-error` and compare the second audit step's `if:` exactly in `spec/advisory_response_spec.rb`; the maintainer may want the README's Dependabot sentence to say version updates cover direct gems only.
- Stale statements found, outside the feature and unchanged: ADR 0008 says the repository is private (it is public: `gh api repos/plainprogrammer/Collector` returns `"visibility":"public"`), and the area doc's open point says attestations and SBOMs wait until the repository is public, which may now be over.

**Why:** the first six items need GitHub or the maintainer, and `verification.md` of the spec holds the same list and is the place to record results.

**How to apply:** when the maintainer reports a Quickstart result or asks about spec 036, start from `verification.md` and this list. Related: [[cloud-session-github-limits]], [[github-comment-tool-mangles-mentions]].
