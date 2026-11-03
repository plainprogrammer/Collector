# Feature 036: Advisory Response for Locked Dependencies

**Status:** Draft
**Version:** 0.1.0
**Created:** 2026-11-03
**Last Updated:** 2026-11-03
**Branch:** `claude/happy-fermi-y30wzq` (the cloud session's designated branch; the convention's `036-advisory-response` is not used because the session is bound to this name)
**Issue:** none yet (a housekeeping candidate; the roadmap's rule is one issue per candidate, opened with the maintainer's go-ahead)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-03 | First draft, from the diagnosis of the 2026-11-03 blockade (PRs [#157](https://github.com/plainprogrammer/Collector/pull/157)–[#162](https://github.com/plainprogrammer/Collector/pull/162)) and the maintainer's rulings of the same day (Decisions 1–6) |

---

## Problem Statement

On 2026-11-03 five Dependabot pull requests (#157–#161) all failed the `checks` job, though none of them touched what failed: `bin/bundler-audit` reported published advisories against five gems already locked on `main` (addressable 2.9.0, loofah 2.25.2, nokogiri 1.19.4, rails-html-sanitizer 1.7.1, sqlite3 2.10.1). Only sqlite3 had a Dependabot pull request, and that one could not go green alone, because the other four advisories still failed its audit. The maintainer fixed the five gems by hand in [#162](https://github.com/plainprogrammer/Collector/pull/162).

Three things combined:

- **Dependabot's version updates skipped four of the five gems.** They keep up to date the dependencies a manifest names explicitly. addressable, loofah, nokogiri and rails-html-sanitizer are dependencies of dependencies, so they were never eligible; all 16 Dependabot pull requests the repository has had are direct gems or GitHub Actions. Version updates also run weekly (all but one of the 16 pull requests were opened on a Tuesday) and apply Dependabot's default 3-day cooldown, so a direct gem's fix released on 2026-11-02 would have waited for the following week's run.
- **Dependabot's security updates, which are enabled, opened nothing for those four gems.** They start from Dependabot alerts and the cooldown doesn't apply to them (Dependabot's documentation), so they were the way these fixes should have arrived. Why they didn't is not known (Open Questions).
- **Nothing runs the audits between pull requests.** The audit runs when someone opens a pull request or pushes to `main`, so an advisory published on a Monday is first seen when the next run happens to start.

When several advisories land together, a fix pull request per gem cannot pass: each is blocked by the others' advisories. A batch can only be fixed by one pull request that carries every fix.

## Goals

- A new advisory against a locked gem or an importmap pin turns a run red within 24 hours of GitHub starting the scheduled run, without waiting for a pull request or a push.
- When Dependabot opens security-update pull requests for the Ruby gems, they arrive as one pull request, so a batch of advisories can be fixed together.
- The response to a red audit is written down, so the fix is one pull request that updates every flagged gem and nothing else.

## Non-Goals

- Changing the audit gate: `config/ci.rb`'s two audit steps and the `checks` job stay as they are. A red audit still blocks every pull request; that is the gate working (security rule: gate CI on `bin/bundler-audit` and `bin/importmap audit`).
- Making Dependabot's version updates cover transitive gems (`allow: indirect` or `all`). Ruled out for now (Decision 6).
- Changing Dependabot's schedule, its cooldown, its pull request limit or the `github-actions` entry.
- Auto-merging, or auto-rebasing, Dependabot pull requests.
- Finding out why the security updates opened nothing. That is an open question for the maintainer to answer from the Dependabot alerts, and it decides whether Story 1 can ever fire for a transitive gem.
- Dependabot for the base image (as spec 012's Non-Goals).

## Users and Context

**Primary users:** the maintainer, who is also the operator of the family instance and the only person who merges.
**Secondary users:** self-hosters, who receive fixes sooner because the maintainer learns of them sooner.
**Usage context:** advisories are published on the ecosystems' own schedule, at any hour, in batches. The maintainer works in short sessions and reads GitHub's failed-run emails and the pull request list, not a dashboard.
**User mental model:** "Dependabot keeps things up to date, and CI tells me when something is wrong." The 2026-11-03 blockade broke the first half: Dependabot did not produce the fix, and CI told the maintainer only by failing five unrelated pull requests at once.

**Hosted-door rules ([north star](../../north-star.md#hosted-door-rules)):** the first three don't apply (no catalog source, no admin page, no collector choice). The fourth is stated in Non-Functional Requirements: the feature costs nothing per account.

**Area docs this changes:** [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (the Dependabot bullet and the workflow list). **Supersedes:** nothing; the area doc's sentence "Dependabot covers gems and GitHub Actions" (spec 001 AC-2.6, FR-4) stays true.

## User Stories

### Story 1: A batch of security fixes arrives as one pull request

**As the** maintainer
**I want** Dependabot's security-update pull requests for the Ruby gems to come as one group
**So that** advisories that land together are fixed together, and no fix is blocked by another's advisory

**Acceptance criteria:**

- [ ] **AC-1.1** Given `.github/dependabot.yml` When it is parsed Then its `bundler` entry defines a group whose `applies-to` is `security-updates` and whose `patterns` is `["*"]`
- [ ] **AC-1.2** Given `.github/dependabot.yml` When it is parsed Then the `bundler` entry's `schedule.interval` is still `weekly` and its `open-pull-requests-limit` is still `10`, the `github-actions` entry is unchanged, and the group applies to no version updates
- [ ] **AC-1.3** Given the change is merged When Dependabot next reads the repository Then Insights, Dependency graph, Dependabot shows the `bundler` ecosystem's last job with no configuration error (recorded by reading, in `verification.md`)
- [ ] **AC-1.4** Given two or more locked gems have advisories and Dependabot opens security-update pull requests for them When the pull requests appear Then the Ruby gems' security updates are in one pull request (observed when it next happens and then recorded in `verification.md`; the spec does not wait for it, because it needs an advisory)

### Story 2: A red audit is noticed within a day

**As the** maintainer
**I want** the dependency audits to run every day on `main`
**So that** a new advisory reaches me as a failed run before it blocks a pull request

**Acceptance criteria:**

- [ ] **AC-2.1** Given the new workflow file When it is parsed Then its triggers are exactly a daily `schedule` and `workflow_dispatch`, and it does not run on `push` or `pull_request`
- [ ] **AC-2.2** Given the workflow When it is parsed Then one job runs `bin/bundler-audit` and `bin/importmap audit`, as separate steps, and neither step can pass when its audit fails
- [ ] **AC-2.3** Given the workflow When it is parsed Then the second audit runs even when the first fails, so one run lists the advisories of both
- [ ] **AC-2.4** Given the workflow When it is parsed Then the job's token is `contents: read` and nothing more, every `uses:` line is pinned to a full commit SHA with its version in a trailing comment, and every action is one `ci.yml` already uses at the same SHA
- [ ] **AC-2.5** Given the workflow When it is parsed Then the job has a timeout of 10 minutes or less
- [ ] **AC-2.6** Given a `main` whose lockfile locks a gem with a published advisory When the workflow runs Then the run fails and its log lists the gem, its locked version, the advisory and the fixed version (verified after merge by running the workflow by hand against a throwaway branch that locks a vulnerable version, and recorded in `verification.md`)
- [ ] **AC-2.7** Given a `main` with no advisories When the workflow runs Then the run passes (verified by the same hand run on `main`)
- [ ] **AC-2.8** Given the failed hand run of AC-2.6 When the maintainer opens the repository's Actions tab Then the run is listed as failed, and the maintainer, who started it, was notified by GitHub as their notification settings for Actions say (recorded in `verification.md`). This shows the settings work, not who a scheduled run notifies (Open Questions)

### Story 3: The response to a red audit is written down

**As the** maintainer
**I want** the area doc to say how a red audit is fixed
**So that** the fix is one pull request, not a pull request per gem

**Acceptance criteria:**

- [ ] **AC-3.1** Given the area doc `release-and-deploy.md` When it is read Then it states that Dependabot's version updates cover direct gems only, that its security updates for the Ruby gems are one group, and that the daily workflow runs both audits on `main` (each statement with its source, spec 036 and the Dependabot documentation)
- [ ] **AC-3.2** Given the area doc When it is read Then it states the response to a red audit: run `bin/bundler-audit`, update every flagged gem in one change with `bundle update --conservative <gems>`, run `bin/ci checks` and the suite, and open one pull request
- [ ] **AC-3.3** Given the README's sentence "Dependabot keeps gems and GitHub Actions up to date" When it is read against the new behaviour Then it is still true, or it is corrected in the same pull request

## Functional Requirements

### FR-1: Security updates for the Ruby gems are one group

`.github/dependabot.yml`'s `bundler` entry groups every security update into one pull request.

**Must:**
- Group all dependencies by pattern, so the group holds a direct gem and a transitive one together.
- Apply the group to security updates only.
- Leave every other key of both entries as it is.

**Must not:**
- Change when Dependabot runs, how many pull requests it may open, or which dependencies its version updates cover.
- Group the `github-actions` entry's updates.

### FR-2: A daily run of both audits on the default branch

A workflow file, separate from `ci.yml`, runs the two audits once a day and on request.

**Must:**
- Audit the default branch's head, with the advisory data current at the time of the run, not a cached copy.
- Fail the run when either audit reports an advisory, or cannot fetch what it audits against.
- Run both audits in every run, whichever fails.
- Be startable by hand (`workflow_dispatch`).

**Must not:**
- Run on pushes or pull requests (`ci.yml` does).
- Build, test, publish or push anything, or write to the repository, issues or packages.
- Pass when an audit could not run.

### FR-3: The area doc states the rules and the response

`release-and-deploy.md` gains the facts of FR-1 and FR-2 and the response to a red audit, each with its source, in the shape the area docs' README gives.

**Must:**
- Name `.github/workflows/<the new file>` in its list of workflows and in Scope.
- Add this spec's number to Sources.

**Must not:**
- Restate the rules in CLAUDE.md (documentation rule).
- Edit a shipped spec.

## Non-Functional Requirements

### Performance

- The daily run finishes in under 10 minutes and normally in a few minutes (the audits in `checks` take about a second each, after setting up Ruby and the gems). GitHub may start a scheduled run late; "within 24 hours" counts from the scheduled start, and the spec makes no promise about GitHub's queue.

### Security

- The workflow's token is `contents: read`. It uses no secret and writes nothing.
- Its actions are pinned to a full commit SHA, kept current by Dependabot's `github-actions` updates (area doc rule on pinning; issue #132).
- It reads advisory data from the sources the audits already use (the Ruby advisory database and the importmap audit's service), and adds no new one.

### Reliability

- Both audits fail closed: no network, or an unreadable lockfile, is a red run, never a pass.
- The daily run is independent of `ci.yml`: it cannot delay, or be blocked by, a pull request's checks.

### Cost per account (hosted-door rule 4)

- None. The feature adds no storage and no background work per account. It adds one scheduled job per day for the repository, under 10 minutes of runner time, shared by every account of every instance because it concerns the code's dependencies and not any instance's data.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| An advisory is published against a locked gem | The next daily run fails; the log names the gem, its version, the advisory and the fixed version (AC-2.6) |
| An advisory is published against an importmap pin | The same run fails in the importmap audit step, and the gem audit's result is not lost (AC-2.3) |
| Both audits find advisories | One run lists both (AC-2.3) |
| The advisory database cannot be fetched | The run fails; it never passes on stale or missing data (FR-2) |
| Several advisories land at once, and Dependabot opens security pull requests | They arrive as one group pull request, so none is blocked by another's advisory (AC-1.4) |
| Dependabot opens no security pull request for a flagged gem (as on 2026-11-03) | The daily run still fails, and the maintainer follows the documented response (AC-3.2) |
| Dependabot rejects the group's configuration | Insights shows a configuration error for the `bundler` ecosystem; AC-1.3 catches it after merge |
| GitHub starts the scheduled run late, or skips one | The next day's run catches the same advisory; no promise is made about a single run |
| The daily run fails and nobody reads the notification | The failed run stays listed for `main` in the Actions tab, and the next pull request's `checks` run fails too (the existing gate) |

## Decisions

Rulings of the maintainer, 2026-11-03, in the session that diagnosed the blockade:

1. **One spec for both parts.** The outcome is stated as one sentence: when an advisory lands on a locked dependency, the maintainer is told within a day and the fix is one pull request. (North star: one outcome, one PR.)
2. **The daily run covers both audits,** `bin/bundler-audit` and `bin/importmap audit`: they share the failure mode (a newly published advisory turns an unchanged lockfile red) and cost seconds.
3. **The notice is a failed run and GitHub's own notification.** The workflow files no issue and needs no write permission. Who GitHub notifies of a scheduled run is an open question.
4. **The cause of the silent security updates is unknown,** and stays an open question. The daily audit and the documented response are the safety net until it is answered.
5. **The full SDD flow** (spec, plan, review, execution) is used, though the change is small.
6. **Scope:** grouped security updates and the daily audit. `allow: indirect` for version updates is not included.

## Open Questions

- [NEEDS CLARIFICATION: why did Dependabot's security updates open no pull request for addressable, loofah, nokogiri or rails-html-sanitizer between the advisories of 2026-11-02 and the fix on 2026-11-03? The maintainer can read it from Security, Dependabot (filter Closed) or Insights, Dependency graph, Dependabot. If no alert was created, Story 1's group is inert for these gems; the candidate then is `allow: indirect` with a group, which Decision 6 leaves out, and this spec would need an update first (`sdd-spec-update`)]
- [NEEDS CLARIFICATION: who will GitHub notify of a scheduled run? Its documentation says the user who initially created the workflow, replaced by whoever later changes the cron syntax or re-enables the workflow. The file reaches `main` through a pull request opened by the cloud session's GitHub integration and merged by the maintainer, and it is not known which account GitHub counts as the creator. A hand run notifies only whoever starts it, so it cannot show this; only the first scheduled failure can. Does the maintainer accept that, with the failed run listed in the Actions tab and the next pull request's red `checks` as the backstops, or want the workflow's cron line to be touched in a commit of the maintainer's own after merge, to make them its recipient?]

## Out of Scope (Future Considerations)

- `allow: indirect`, with a group, for Dependabot's version updates (the fallback if the open question's answer is "no alert").
- A scheduled run of `bin/brakeman` or of the whole of `bin/ci checks`: a new Brakeman release can also turn an unchanged tree red (`.claude/memory/brakeman-ensure-latest.md`). Another candidate, with its own failure mode.
- Filing an issue for a failed daily run (Decision 3 declined it).
- A cooldown or schedule tuned for security-relevant gems.
