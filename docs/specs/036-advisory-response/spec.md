# Feature 036: Advisory Response for Locked Dependencies

**Status:** Approved by the maintainer (2026-11-03), after two Mode A reviews
**Version:** 1.0.0
**Created:** 2026-11-03
**Last Updated:** 2026-11-03
**Branch:** `claude/happy-fermi-y30wzq` (the cloud session's designated branch; the convention's `036-advisory-response` is not used because the session is bound to this name)
**Issue:** [#164](https://github.com/plainprogrammer/Collector/issues/164)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-03 | Approved by the maintainer, with the Dependabot-alerts question left deferred and owned (Open Questions, Decision 4). Status and version only; no requirement, criterion or decision changes |
| 0.2.1 | 2026-11-03 | Revised after the second Mode A review of 0.2.0 (NEEDS REVISION, no blocking finding; each finding checked). **The repository is public, not private:** 0.2.0 said "private now (ADR 0008)" without checking the live state, so the 60-day disabling of an idle scheduled workflow and the public run logs now apply (Error Scenarios, NFR Security; removed from Out of Scope). **AC-2.10** names its route (a commit the maintainer authors and pushes to the unprotected `main`) and updates the area doc's schedule row in the same commit. **AC-2.3 and AC-2.9** are rewritten so the YAML can show them and so they don't contradict each other (an audit step runs only after a successful setup, and the second runs after the first fails); AC-2.9 joins the RSpec list. **AC-2.11** added for the rule against a cached advisory database. **AC-2.6's** reason for the order is restated as a precaution, not a documented rule. Clarified AC-1.2, AC-2.3's trigger and the open question's handling (deferred, owned, not blocking). No change of intent (PATCH) |
| 0.2.0 | 2026-11-03 | Revised after the Mode A review of 0.1.0 (NEEDS REVISION; each finding checked against the repository and GitHub's documentation) and the maintainer's rulings of the same day (Decisions 2, 7–9). **FR-2** audits the commit a run is on, not always the default branch, which AC-2.6's hand run needs; the verification order is stated (AC-2.7 before AC-2.6). **Importmap:** its audit checks nothing while no pin carries a version, so the claims that assumed otherwise are removed (Goal 1, Error Scenarios, NFRs, FR-2) and Decision 2's premise is corrected. **Facts corrected:** 12 of the 16 Dependabot pull requests were opened on a Tuesday and 4 on one Wednesday; security updates opened nothing for sqlite3 either, so the open question covers all five gems. **Added:** the cron's time (Decision 8), the notification recipient's post-merge step (AC-2.10, Decision 7), the Named-constants row (FR-3), a "never a cached advisory database" rule, a setup-failure criterion (AC-2.9), the grouped-security-updates repository setting and the issue (Decision 9). Open question about the notification recipient resolved by Decision 7 |
| 0.1.0 | 2026-11-03 | First draft, from the diagnosis of the 2026-11-03 blockade (PRs [#157](https://github.com/plainprogrammer/Collector/pull/157)–[#162](https://github.com/plainprogrammer/Collector/pull/162)) and the maintainer's rulings of the same day (Decisions 1–6) |

---

## Problem Statement

On 2026-11-03 five Dependabot pull requests (#157–#161) all failed the `checks` job, though none of them touched what failed: `bin/bundler-audit` reported published advisories against five gems already locked on `main` (addressable 2.9.0, loofah 2.25.2, nokogiri 1.19.4, rails-html-sanitizer 1.7.1, sqlite3 2.10.1). Only sqlite3 had a Dependabot pull request, and that one could not go green alone, because the other four advisories still failed its audit. The maintainer fixed the five gems by hand in [#162](https://github.com/plainprogrammer/Collector/pull/162).

Three things combined:

- **Dependabot's version updates skipped four of the five gems.** They keep up to date the dependencies a manifest names explicitly. addressable, loofah, nokogiri and rails-html-sanitizer are dependencies of dependencies, so they were never eligible; all 16 Dependabot pull requests the repository has had are direct gems or GitHub Actions. Version updates also run weekly (12 of the 16 pull requests were opened on a Tuesday, the other four on one Wednesday) and apply Dependabot's default 3-day cooldown, so a direct gem's fix released on 2026-11-02 would have waited for the following week's run.
- **Dependabot's security updates, which are enabled, opened nothing for any of the five gems.** Not for the four transitive ones, and not for sqlite3, a direct gem whose fix was released on 2026-10-26: #161 carries the same labels as the version updates and was opened with the weekly batch. Security updates start from Dependabot alerts and the cooldown doesn't apply to them (Dependabot's documentation), so they were the way these fixes should have arrived. Why they didn't is not known (Open Questions).
- **Nothing runs the audits between pull requests.** The audit runs when someone opens a pull request or pushes to `main`, so an advisory published on a Monday is first seen when the next run happens to start.

When several advisories land together, a fix pull request per gem cannot pass: each is blocked by the others' advisories. A batch can only be fixed by one pull request that carries every fix.

## Goals

- A new advisory against a locked gem turns a run red within a day of the advisory reaching the Ruby advisory database, without waiting for a pull request or a push. (GitHub may start a scheduled run late; the day is counted to the next scheduled start.)
- When Dependabot opens security-update pull requests for the Ruby gems, they arrive as one pull request, so a batch of advisories can be fixed together.
- The response to a red audit is written down, so the fix is one pull request that updates every flagged gem and nothing else.

## Non-Goals

- Changing the audit gate: `config/ci.rb`'s two audit steps and the `checks` job stay as they are. A red audit still blocks every pull request; that is the gate working (security rule: gate CI on `bin/bundler-audit` and `bin/importmap audit`).
- Making Dependabot's version updates cover transitive gems (`allow: indirect` or `all`). Ruled out for now (Decision 6).
- Changing Dependabot's schedule, its cooldown, its pull request limit or the `github-actions` entry.
- Auto-merging, or auto-rebasing, Dependabot pull requests.
- Finding out why the security updates opened nothing. That is an open question for the maintainer to answer from the Dependabot alerts, and it decides whether Story 1 can ever fire.
- Dependabot for the base image (as spec 012's Non-Goals).

## Users and Context

**Primary users:** the maintainer, who is also the operator of the family instance and the only person who merges.
**Secondary users:** self-hosters, who receive fixes sooner because the maintainer learns of them sooner.
**Usage context:** advisories are published on the ecosystems' own schedule, at any hour, in batches. The maintainer works in short sessions and reads GitHub's failed-run emails and the pull request list, not a dashboard.
**User mental model:** "Dependabot keeps things up to date, and CI tells me when something is wrong." The 2026-11-03 blockade broke the first half: Dependabot did not produce the fix, and CI told the maintainer only by failing five unrelated pull requests at once.

**Hosted-door rules ([north star](../../north-star.md#hosted-door-rules)):** the first three don't apply (no catalog source, no admin page, no collector choice). The fourth is stated in Non-Functional Requirements: the feature costs nothing per account.

**Area docs this changes:** [`release-and-deploy.md`](../../architecture/release-and-deploy.md) (the Dependabot bullet, the workflow list in Scope, the Named constants table). **Also changes:** the roadmap's housekeeping lane (a line for #164). **Supersedes:** nothing; the area doc's sentence "Dependabot covers gems and GitHub Actions" (spec 001 AC-2.6, FR-4) stays true.

## User Stories

### Story 1: A batch of security fixes arrives as one pull request

**As the** maintainer
**I want** Dependabot's security-update pull requests for the Ruby gems to come as one group
**So that** advisories that land together are fixed together, and no fix is blocked by another's advisory

**Acceptance criteria:**

- [ ] **AC-1.1** Given `.github/dependabot.yml` When it is parsed Then its `bundler` entry defines a group whose `applies-to` is `security-updates` and whose `patterns` is `["*"]`
- [ ] **AC-1.2** Given `.github/dependabot.yml` When it is parsed Then the `bundler` entry's `schedule.interval` is still `weekly` and its `open-pull-requests-limit` is still `10` and the `github-actions` entry is unchanged
- [ ] **AC-1.3** Given the change is merged When Dependabot next reads the repository Then Insights, Dependency graph, Dependabot shows the `bundler` ecosystem's last job with no configuration error (recorded by reading, in `verification.md`). This shows that the file is valid, not that the group works; editing the file also starts a version-update run, which may open pull requests
- [ ] **AC-1.4** Given two or more locked gems have advisories and Dependabot opens security-update pull requests for them When the pull requests appear Then the Ruby gems' security updates are in one pull request (observed when it next happens and then recorded in `verification.md`; the spec does not wait for it, because it needs an advisory)

### Story 2: A red audit is noticed within a day

**As the** maintainer
**I want** the dependency audits to run every day on `main`
**So that** a new advisory reaches me as a failed run before it blocks a pull request

**Acceptance criteria:**

- [ ] **AC-2.1** Given the new workflow file When it is parsed Then its triggers are exactly one `schedule` entry that runs once a day, at a minute other than 0, and `workflow_dispatch`, and it does not run on `push` or `pull_request`
- [ ] **AC-2.2** Given the workflow When it is parsed Then one job runs `bin/bundler-audit` and `bin/importmap audit` as separate steps, neither step has `continue-on-error`, and neither command is followed by anything that hides its exit status
- [ ] **AC-2.3** Given the workflow When it is parsed Then the second audit step runs after the first even when the first fails, and runs only when every setup step succeeded and the run was not cancelled, so one run lists the advisories of both
- [ ] **AC-2.4** Given the workflow When it is parsed Then its top-level `permissions` are exactly `contents: read` and its job asks for nothing wider, every `uses:` line is pinned to a full commit SHA with its version in a trailing comment, and every action is one `ci.yml` already uses at the same SHA
- [ ] **AC-2.5** Given the workflow When it is parsed Then the job has a timeout of 10 minutes or less
- [ ] **AC-2.6** Given a throwaway branch cut from `main` after the merge, pushed by the maintainer, whose `Gemfile.lock` locks a gem version with a published advisory When the workflow is started by hand against that branch Then the run fails and its log lists the gem, its locked version, the advisory and the fixed version (verified after merge, and recorded in `verification.md`; GitHub documents that a workflow started by hand must exist on the default branch, which the merge satisfies, and the run of AC-2.7 comes first as a precaution, not a documented rule)
- [ ] **AC-2.7** Given `main` has no advisories When the workflow is started by hand on `main`, the first run after the merge Then the run passes
- [ ] **AC-2.8** Given the failed hand run of AC-2.6 When the maintainer opens the repository's Actions tab Then the run is listed as failed, and the maintainer, who started it, was notified by GitHub as their notification settings for Actions say (recorded in `verification.md`). This shows the settings work, not who a scheduled run notifies (AC-2.10)
- [ ] **AC-2.9** Given the workflow When it is parsed Then neither audit step can run unless checkout, Ruby setup and gem installation all succeeded, so a failed setup leaves the run red and no audit step reports a pass
- [ ] **AC-2.10** Given the workflow is merged When the maintainer authors a commit of their own that changes the workflow's cron schedule (for example, to another minute of the same hour) and updates the area doc's schedule row to match, and pushes it to `main` themselves Then `main` holds that commit, so GitHub counts the maintainer as the person to notify of scheduled runs (GitHub's documented rule; the effect is seen only at the first scheduled run, so the criterion is the commit, recorded in `verification.md`). `main` has no branch protection, so a direct push works, and the pre-push hook that runs `bin/ci` belongs to Claude Code, not to git
- [ ] **AC-2.11** Given the workflow When it is parsed Then it keeps no copy of the Ruby advisory database between runs: no cache step names the database's directory, or the gem audit step asks for an update

### Story 3: The response to a red audit is written down

**As the** maintainer
**I want** the area doc to say how a red audit is fixed
**So that** the fix is one pull request, not a pull request per gem

**Acceptance criteria:**

- [ ] **AC-3.1** Given the area doc `release-and-deploy.md` When it is read Then it states that Dependabot's version updates cover direct gems only, that its security updates for the Ruby gems are one group, and that the daily workflow runs both audits on `main`; it names the workflow in Scope and adds the schedule to the Named constants table; each statement has its source (spec 036 and the Dependabot documentation)
- [ ] **AC-3.2** Given the area doc When it is read Then it states the response to a red gem audit: run `bin/bundler-audit`, update every flagged gem in one change with `bundle update --conservative <gems>`, run `bin/ci checks` and the suite, and open one pull request
- [ ] **AC-3.3** Given the area doc When it is read Then it states that no importmap pin carries a version today, so the importmap audit has nothing to audit and no response to it is defined until one does
- [ ] **AC-3.4** Given the README's sentence "Dependabot keeps gems and GitHub Actions up to date" When it is read against the new behaviour Then it is still true, or it is corrected in the same pull request

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
- Depend on the repository's "Grouped security updates" setting, which combines with the file's groups (Dependabot documentation) and is a setting, not a reviewed change.

### FR-2: A daily run of both audits

A workflow file, separate from `ci.yml`, runs the two audits once a day and on request, at the same two commands as `config/ci.rb`'s security audit steps.

**Must:**
- Audit the commit the run is on: for a scheduled run, the default branch's head; for a run started by hand, the ref it was started on.
- Use advisory data fetched during the run, never a copy kept from an earlier run (`bin/bundler-audit` downloads the Ruby advisory database only when it is missing, so a runner must not keep it between runs, or the run must ask for an update).
- Fail the run when `bin/bundler-audit` reports an advisory or cannot fetch what it audits against, and when anything before the audits fails (checkout, Ruby, gem installation).
- Run both audits in every run, whichever fails.
- Be startable by hand (`workflow_dispatch`).
- Run at a minute other than 0 (GitHub delays scheduled runs at the start of every hour).

**Must not:**
- Run on pushes or pull requests (`ci.yml` does).
- Build, test, publish or push anything, or write to the repository, issues or packages.
- Pass when `bin/bundler-audit` could not run.
- Claim that the importmap audit checks anything while no pin carries a version (`bin/importmap audit` then reports no vulnerable packages without checking one).

### FR-3: The area doc states the rules and the response

`release-and-deploy.md` gains the facts of FR-1 and FR-2 and the responses of Story 3, each with its source, in the shape the area docs' README gives.

**Must:**
- Name the new workflow in Scope and in its list of workflows, and add its schedule to the Named constants table beside the cleanup schedule.
- Add this spec's number to Sources.

**Must not:**
- Restate the rules in CLAUDE.md (documentation rule).
- Edit a shipped spec.

## Non-Functional Requirements

### Performance

- The daily run finishes in under 10 minutes and normally in a few minutes (each audit takes about a second, after setting up Ruby and the gems). GitHub may start a scheduled run late, and may drop one under high load; "within a day" counts from the advisory reaching the Ruby advisory database to the next scheduled start, and the spec makes no promise about GitHub's queue.

### Security

- The workflow's token is `contents: read`. It uses no secret and writes nothing.
- Its actions are pinned to a full commit SHA, kept current by Dependabot's `github-actions` updates (area doc rule on pinning; issue #132).
- It reads advisory data from the sources the audits already use (the Ruby advisory database and, once a pin carries a version, the importmap audit's service), and adds no new one.
- Its run logs are public, as the repository is. They hold only what the public lockfile and the public advisories already say.

### Reliability

- `bin/bundler-audit` fails closed: no network, or an unreadable lockfile, is a red run, never a pass.
- The importmap audit's result is whatever `bin/importmap audit` reports; no fail-closed behaviour is claimed for it, because with no versioned pin it checks nothing.
- The daily run is independent of `ci.yml`: it cannot delay, or be blocked by, a pull request's checks.

### Cost per account (hosted-door rule 4)

- None. The feature adds no storage and no background work per account. It adds one scheduled job per day for the repository, under 10 minutes of runner time, shared by every account of every instance because it concerns the code's dependencies and not any instance's data.

### Testability

- The file criteria (AC-1.1, AC-1.2, AC-2.1 to AC-2.5, AC-2.9, AC-2.11) are RSpec examples that parse the YAML, as spec 012's criteria for `ci.yml` and `ghcr-cleanup.yml` are (`spec/image_publishing_spec.rb`). The criteria that need GitHub (AC-1.3, AC-1.4, AC-2.6 to AC-2.8, AC-2.10) are verified by reading or observing, and recorded in `verification.md`. The document criteria (Story 3) are verified by reading (`.claude/rules/testing.md`).

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| An advisory is published against a locked gem | The next daily run fails; the log names the gem, its version, the advisory and the fixed version (AC-2.6) |
| An advisory is published against a versioned importmap pin (none exists today) | The same run fails in the importmap audit step, and the gem audit's result is not lost (AC-2.3) |
| Both audits find advisories | One run lists both (AC-2.3) |
| The Ruby advisory database cannot be fetched | The run fails; it never passes on stale or missing data (FR-2) |
| Checkout, Ruby setup or gem installation fails | The run is red and neither audit is reported as passed (AC-2.9) |
| Several advisories land at once, and Dependabot opens security pull requests | They arrive as one group pull request, so none is blocked by another's advisory (AC-1.4) |
| Dependabot opens no security pull request for a flagged gem (as on 2026-11-03) | The daily run still fails, and the maintainer follows the documented response (AC-3.2) |
| Dependabot rejects the group's configuration | Insights shows a configuration error for the `bundler` ecosystem; AC-1.3 catches it after merge |
| The repository's "Grouped security updates" setting is on, or a version-update pull request is already open for a gem the group also updates | Not verified: Dependabot's documentation says the setting combines with the file's groups and may close open pull requests and open grouped ones. Recorded in `verification.md` if seen |
| GitHub starts the scheduled run late, or drops one | The next day's run catches the same advisory; no promise is made about a single run |
| The daily run fails and nobody reads the notification | The failed run stays listed in the Actions tab, and the next pull request's `checks` run fails too (the existing gate) |
| GitHub disables the scheduled workflow after 60 days without repository activity (the repository is public; GitHub's documentation) | Daily runs stop without a failed run. The next pull request's `checks` still gate, and re-enabling the workflow in the Actions tab restarts it and, by GitHub's rule, makes whoever re-enables it the recipient (Decision 7) |

## Decisions

Rulings of the maintainer, 2026-11-03, in the session that diagnosed the blockade, unless noted:

1. **One spec for both parts.** The outcome is stated as one sentence: when an advisory lands on a locked dependency, the maintainer is told within a day and the fix is one pull request. (North star: one outcome, one PR.)
2. **The daily run covers both audits,** `bin/bundler-audit` and `bin/importmap audit`: it repeats the two security steps of `config/ci.rb`, so drift in either shows up the same way. *Premise corrected in 0.2.0:* no importmap pin carries a version, so `bin/importmap audit` checks nothing today; the maintainer kept it, with the spec saying so (AC-3.3, FR-2).
3. **The notice is a failed run and GitHub's own notification.** The workflow files no issue and needs no write permission.
4. **The cause of the silent security updates is unknown,** and stays an open question. The daily audit and the documented response are the safety net until it is answered.
5. **The full SDD flow** (spec, plan, review, execution) is used, though the change is small.
6. **Scope:** grouped security updates and the daily audit. `allow: indirect` for version updates is not included.
7. **The notification recipient is the maintainer, by a post-merge commit of their own** that changes the workflow's cron schedule and updates the area doc's schedule row to match, pushed by the maintainer to `main` (AC-2.10). GitHub notifies the user who initially created a scheduled workflow, or who later changes its cron syntax or re-enables it (documented), and the file arrives through a pull request opened by the cloud session's GitHub integration, so which account counts as the creator isn't known. The failed run in the Actions tab and the next pull request's red `checks` stay as backstops.
8. **The schedule is daily at 05:17 UTC to start with** (a judgement call, to be changed by the maintainer's own commit under Decision 7): off the hour, because GitHub delays scheduled runs at the start of every hour, and before the working day.
9. **An issue was opened** ([#164](https://github.com/plainprogrammer/Collector/issues/164), housekeeping, on the 1.0 milestone), and the roadmap's housekeeping lane gets a line for it, as the roadmap's tracking rule asks. The implementing pull request closes it.

## Open Questions

- **Deferred, unanswered (Decision 4): why did Dependabot's security updates open no pull request for any of the five gems** (addressable, loofah, nokogiri, rails-html-sanitizer, and sqlite3, which is direct)? **Owner:** the maintainer, who can read it from Security, Dependabot (filter Closed) or Insights, Dependency graph, Dependabot. **What each answer does:** the answer is recorded in `verification.md`. If an alert existed and Dependabot reported an error, the error's text goes there and Story 1 stands. If no alert was created, Story 1's group is inert; `sdd-spec-update` follows before any work on `allow: indirect`, which Decision 6 leaves out. **Why it does not block the plan:** no requirement depends on the answer; the daily audit (Story 2) and the written response (Story 3) work either way. The marker is left off on purpose, because the skill rule is that an approved spec has no `[NEEDS CLARIFICATION]` item, and this one changes no requirement; the maintainer can overrule that at approval.

## Out of Scope (Future Considerations)

- `allow: indirect`, with a group, for Dependabot's version updates (the fallback if the open question's answer is "no alert").
- Enabling the repository's "Grouped security updates" setting: a setting that a pull request can't review. It combines with the file's group, so it can be turned on later without changing this spec.
- A scheduled run of `bin/brakeman` or of the whole of `bin/ci checks`: a new Brakeman release can also turn an unchanged tree red (`.claude/memory/brakeman-ensure-latest.md`). Another candidate, with its own failure mode.
- Filing an issue for a failed daily run (Decision 3 declined it).
- A cooldown or schedule tuned for security-relevant gems.
- Keeping a scheduled workflow enabled through a quiet spell (see the Error Scenarios row): a repository with commits at least every 60 days never meets it.
