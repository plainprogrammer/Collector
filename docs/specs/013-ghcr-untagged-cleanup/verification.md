# Verification: Clean Up Untagged GHCR Package Versions (spec 013)

**Spec:** [spec.md](spec.md) v1.1.2 · **Plan:** [plan.md](plan.md) Phase 5 · **Recorded:** 2026-10-08 ·
**Branch:** `013-ghcr-untagged-cleanup`

Evidence for every acceptance criterion. The selection rule, the client and the run are covered by
`spec/lib/collector/ghcr_cleanup_spec.rb`, `spec/lib/collector/ghcr_cleanup/client_spec.rb` and
`spec/lib/collector/ghcr_cleanup/run_spec.rb`; the workflow, image exclusions and docs by
`spec/image_publishing_spec.rb`. All four run in `bin/ci`, with WebMock blocking real HTTP. Criteria that need
the live package are recorded under "Live cleanup (post-merge)" (2026-10-08 to 2026-10-20).

## Commits

`git log --oneline main..HEAD` at the time of recording:

```text
45f855e ci(ghcr-cleanup): add the weekly cleanup workflow, image exclusions and docs
5d4c708 feat(ghcr-cleanup): add the run and bin/ghcr-cleanup
15c5f30 feat(ghcr-cleanup): add the packages API and registry client
f3666ce feat(ghcr-cleanup): add the orphan-unit selection rule
df72ee0 docs(013): fallback token is a classic PAT (spec v1.1.2)
e064dab docs(013): add implementation plan
1dff216 docs(013): apply second review pass wording (v1.1.1)
ccbab79 docs(013): order AC-3.9 after AC-3.8
cd755ae docs(013): apply spec review fixes (v1.1.0)
8b86d65 docs(013): approve spec
7553d5f docs(013): add spec and accept ADR 0011
b8f7c87 docs(013): apply PRD review fixes
6f0690b docs(013): add PRD and ADR 0011 for GHCR untagged cleanup
```

## Local gate: `bin/ci`

Run on 2026-10-08 at `45f855e`. Every step passed (`✅ Continuous Integration passed in 2m19.55s`).

| Step | Result |
|---|---|
| Setup | passed in 4.30s |
| Style: Ruby (RuboCop) | 370 files inspected, no offenses detected; passed in 3.70s |
| Security: Brakeman | no warnings; passed in 5.46s |
| Security: Gem audit (bundler-audit) | no vulnerabilities found; passed in 0.57s |
| Security: Importmap audit | no vulnerable packages found; passed in 1.43s |
| Tests: RSpec | 788 examples, 0 failures (seed 51071); passed in 2m4.09s |

## Live dry run (AC-4.1, AC-4.3 so far)

`GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup` from the development machine, with the maintainer's `gh` token.
First run in Phase 3 on 2026-10-08; repeated at 2026-10-08T18:35:28Z with the same result and exit status 0:

```text
Dry run: nothing is deleted (pass --delete to delete).
too young sha256:f03eb8274a903d8a69dc3959da1a59ef4cc3980eb9580573de0008f500bca994 created 2026-10-08T14:42:46Z tags (none): orphan manifest list, unit age 0d 3h
too young sha256:90ceeb5c0550695d30c9ef61f951a2f90e40fa397937d8013c5aa0693ffe8c63 created 2026-10-08T14:42:15Z tags (none): unreferenced image, unit age 0d 3h
too young sha256:0f9c9927048e8546dd4a6cd04188cf1c892b41255dec878cddb3733293da28de created 2026-10-08T14:42:03Z tags (none): unreferenced image, unit age 0d 3h
18 versions: 5 tagged, 10 referenced, 3 too young, 0 selected
```

- The four disjoint counts sum to the 18 versions in the package (AC-4.1).
- The only orphan unit is `f03eb8274a90…` with its children `90ceeb5c0550…` and `0f9c9927048e…`, reported as too
  young with its age; the 10 per-architecture children of the five tagged lists are referenced and kept; nothing
  was deleted (AC-4.3, too-young half). The unit is selectable after 2026-10-15T14:42:46Z.
- Every tagged list passed the AC-3.8 platform check, since the run did not fail closed.

## Pull request CI (AC-5.2 image half)

Run [37854725995](https://github.com/plainprogrammer/Collector/actions/runs/37854725995) on PR
[#26](https://github.com/plainprogrammer/Collector/pull/26), commit `3d8b15c`, completed 2026-10-08:

| Job | Result |
|---|---|
| `ci` (`bin/ci`) | success |
| Image (linux/amd64) | success |
| Image (linux/arm64) | success |
| Publish manifest list | skipped (pull requests never publish) |

Both `Smoke test` steps print `== development-only paths and secrets must be absent` followed by
`OK: collector:smoke passed the smoke test`; the absent-path list includes `bin/ghcr-cleanup` and
`lib/collector/ghcr_cleanup.rb`, so neither is in the image on either architecture, and the image still boots.

## Live cleanup (post-merge)

Main is at `ff43b15` (PRs #26 and #27); `edge` and `sha-ff43b15` were published by CI run
[37861087603](https://github.com/plainprogrammer/Collector/actions/runs/37861087603), so the package has 21 versions.

### Step 1: manual dry run of the workflow (2026-10-08T23:53Z)

Run [37861909201](https://github.com/plainprogrammer/Collector/actions/runs/37861909201), `workflow_dispatch` on
`main` with `dry_run=true`, completed with `success`:

| Job | Result |
|---|---|
| `dry-run` | success (10 s) |
| `delete` | skipped |

The `Dry run` step ran `bin/ghcr-cleanup` with `GH_TOKEN: ***` (the workflow's `GITHUB_TOKEN`, masked) and printed:

```
Dry run: nothing is deleted (pass --delete to delete).
too young sha256:f03eb8274a903d8a69dc3959da1a59ef4cc3980eb9580573de0008f500bca994 created 2026-10-08T14:42:46Z tags (none): orphan manifest list, unit age 0d 9h
too young sha256:90ceeb5c0550695d30c9ef61f951a2f90e40fa397937d8013c5aa0693ffe8c63 created 2026-10-08T14:42:15Z tags (none): unreferenced image, unit age 0d 9h
too young sha256:0f9c9927048e8546dd4a6cd04188cf1c892b41255dec878cddb3733293da28de created 2026-10-08T14:42:03Z tags (none): unreferenced image, unit age 0d 9h
21 versions: 6 tagged, 12 referenced, 3 too young, 0 selected
```

This shows that a run started by hand is a dry run by default, carried out by the job without `packages: write`
(AC-4.2). It also shows that the workflow token can list the package through the `/users/` endpoint and read
every tagged manifest list. The counts match a local dry run at the same commit
(`21 versions: 6 tagged, 12 referenced, 3 too young, 0 selected`): the new `edge` list's two images are referenced,
and the only orphan unit is still `f03eb827…`, too young until 2026-10-15T14:42:46Z.

### Scheduled run, Sunday 2026-10-11 (started 12:26Z)

Run [38139288459](https://github.com/plainprogrammer/Collector/actions/runs/38139288459), `schedule`, started 6 h 27 min
after the 06:00 UTC cron: `delete` success, `dry-run` skipped. The unit was still inside the grace period, so it
deleted nothing: `36 versions: 11 tagged, 22 referenced, 3 too young, 0 selected` (the `f03eb827…` unit at 2d 21h).

### Step 2: local dry run after the grace period — not run separately

The maintainer didn't run the local dry run between 2026-10-15T14:42:46Z and the Sunday scheduled run, which made
the first deletion. The scheduled run prints its selection before deleting, from the same plan a dry run makes, so
that output (step 3) shows the selected half of AC-4.3: exactly the three `f03eb827…` unit members, nothing tagged
or referenced. Step 5's dry run from the development machine is the AC-4.3 check on the day of verification.

### Step 3: first deleting run, Sunday 2026-10-18 (started 10:42Z)

Run [39120330257](https://github.com/plainprogrammer/Collector/actions/runs/39120330257), `schedule`, started 4 h 42 min
after the cron: `dry-run` skipped, `delete` success. The `Delete` step ran `bin/ghcr-cleanup --delete` with the
workflow's `GITHUB_TOKEN` and printed:

```
select sha256:f03eb8274a903d8a69dc3959da1a59ef4cc3980eb9580573de0008f500bca994 created 2026-10-08T14:42:46Z tags (none): orphan manifest list, unit age 9d 20h
select sha256:90ceeb5c0550695d30c9ef61f951a2f90e40fa397937d8013c5aa0693ffe8c63 created 2026-10-08T14:42:15Z tags (none): unreferenced image, unit age 9d 20h
select sha256:0f9c9927048e8546dd4a6cd04188cf1c892b41255dec878cddb3733293da28de created 2026-10-08T14:42:03Z tags (none): unreferenced image, unit age 9d 20h
135 versions: 44 tagged, 88 referenced, 0 too young, 3 selected
deleted sha256:f03eb8274a903d8a69dc3959da1a59ef4cc3980eb9580573de0008f500bca994
deleted sha256:90ceeb5c0550695d30c9ef61f951a2f90e40fa397937d8013c5aa0693ffe8c63
deleted sha256:0f9c9927048e8546dd4a6cd04188cf1c892b41255dec878cddb3733293da28de
```

The list was deleted first, then its two images (AC-1.2). No `ghcr-cleanup:` line followed and the job succeeded,
so the post-delete check re-read all 44 tagged lists and found every child of each (AC-2.4); it took 6.5 s, between
the last `deleted` line (10:42:58.83Z) and the end of the step (10:43:05.36Z). The workflow's `GITHUB_TOKEN` may
delete (Open Question). Count: 135 before; after it, step 5 found the same 44 tagged and 88 referenced versions plus
only new, young ones, so the 3 are gone and nothing else was.

### Step 4: anonymous pulls (2026-10-20, about 14:40Z)

Pulled with an empty auth file (`podman pull --authfile <empty {}> --arch …`), so no credentials were sent. 0.2.0
and 0.2.1 were released after 0.1.0 and are included; `latest` is 0.2.1 (same image ids).

```
latest amd64 -> linux/amd64 1bfcb6b1df37
latest arm64 -> linux/arm64 77f4ac1705cb
0.1.0 amd64 -> linux/amd64 f6659f76c07d
0.1.0 arm64 -> linux/arm64 66f470533ab0
0.2.0 amd64 -> linux/amd64 bd11d4304e47
0.2.0 arm64 -> linux/arm64 3459669349c9
0.2.1 amd64 -> linux/amd64 1bfcb6b1df37
0.2.1 arm64 -> linux/arm64 77f4ac1705cb
edge amd64 -> linux/amd64 c9d72a8ebc23
edge arm64 -> linux/arm64 480dc07d5bb1
```

Every tag pulls on both architectures, each the one it asked for (AC-2.5).

### Step 5: second dry run (2026-10-20, about 14:40Z)

`GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup` from the development machine, while three CI runs on `main` were
publishing (their images are pushed minutes before the manifest list that references them):

```
Dry run: nothing is deleted (pass --delete to delete).
too young sha256:03fff3e07e3d100c6ba5a9d3ed2ad25a28974f3d0e441b3e9db422cd062492dc created 2026-10-20T14:39:59Z tags (none): unreferenced image, unit age 0d 0h
too young sha256:0af27cd2a5f903efa6c83d5ccc0a8d5ede9b4994183e6663185f84e788cc8ae4 created 2026-10-20T14:39:51Z tags (none): unreferenced image, unit age 0d 0h
too young sha256:16ae95b7c3b6383e9ece30714cf804e4eb378735ebc73c1adb6505849ba12d0d created 2026-10-20T14:39:48Z tags (none): unreferenced image, unit age 0d 0h
too young sha256:af1248841db5059a49e7689056d52326612d77b92d486fdfd29ddd7dcf6960b7 created 2026-10-20T14:38:58Z tags (none): unreferenced image, unit age 0d 0h
136 versions: 44 tagged, 88 referenced, 4 too young, 0 selected
```

Nothing is selected after the first deletion (AC-1.6). The in-flight images are reported as too young with their
ages and nothing is deleted, and no orphan unit is past the grace period, so the selection (none) is exactly the
orphan units past it (AC-4.3). It also shows the grace period protecting a publish in progress.

## Acceptance criteria

| AC | Evidence | Status |
|---|---|---|
| AC-1.1 | `ghcr_cleanup_spec.rb` `.plan` "selects an unreferenced image past the grace period (AC-1.1)" | ✓ |
| AC-1.2 | `ghcr_cleanup_spec.rb` `.plan` "selects an orphan list with its children, list first (AC-1.2, FR-1)"; `run_spec.rb` "deletes the orphan unit, list first, and nothing a tag needs (AC-1.2, AC-2.2, FR-1)" and, with the real client against stubbed GitHub and GHCR, "deletes the orphan unit and checks the tag's children (AC-1.2, AC-2.4)" ; live: step 3 under "Live cleanup", run [39120330257](https://github.com/plainprogrammer/Collector/actions/runs/39120330257) deleted the `f03eb827…` list, then its two images | ✓ |
| AC-1.3 | `ghcr_cleanup_spec.rb` `.plan` "keeps a unit whose list is inside the grace period although its children are not (AC-1.3)" | ✓ |
| AC-1.4 | `ghcr_cleanup_spec.rb` `.plan` "keeps a young unreferenced image (AC-1.4)" | ✓ |
| AC-1.5 | `image_publishing_spec.rb` `.github/workflows/ghcr-cleanup.yml` "runs weekly and by hand, never on pushes or pull requests (AC-1.5, FR-4)" and "deletes on the schedule or an unticked dry_run, the only job with packages: write (AC-1.5, FR-4)" | ✓ |
| AC-1.6 | `run_spec.rb` "deletes nothing on a second run (AC-1.6)" ; live: step 5 under "Live cleanup", `136 versions: 44 tagged, 88 referenced, 4 too young, 0 selected` | ✓ |
| AC-2.1 | `ghcr_cleanup_spec.rb` `.plan` "keeps tagged versions of any age, with several tags (AC-2.1)"; live dry run: 5 tagged, none selected | ✓ |
| AC-2.2 | `ghcr_cleanup_spec.rb` `.plan` "keeps old children of a tagged list (AC-2.2)"; `run_spec.rb` "deletes the orphan unit, list first, and nothing a tag needs (AC-1.2, AC-2.2, FR-1)"; live dry run: 10 referenced | ✓ |
| AC-2.3 | `ghcr_cleanup_spec.rb` `.plan` "deletes an old list but keeps a child it shares with a tagged list (AC-2.3)" | ✓ |
| AC-2.4 | `run_spec.rb` "fails naming the tag and digest when a tag's child is missing after deleting (AC-2.4)" and "deletes the orphan unit and checks the tag's children (AC-1.2, AC-2.4)"; `client_spec.rb` `#fetchable?` "answers from a HEAD with the same Accept (AC-2.4)" ; live: step 3, run [39120330257](https://github.com/plainprogrammer/Collector/actions/runs/39120330257): the post-delete check passed over 44 tagged lists | ✓ |
| AC-2.5 | Anonymous `podman pull` of `latest`, `0.1.0`, `0.2.0`, `0.2.1`, `edge` on amd64 and arm64 after the first deleting run: step 4 under "Live cleanup", ten pulls, each the architecture asked for | ✓ |
| AC-3.1 | `client_spec.rb` `#versions` "fails naming the request, not the token, when the API refuses (AC-3.1)" and "fails on a response that is not a version list (AC-3.1)" | ✓ |
| AC-3.2 | `client_spec.rb` `#versions` "reads every page by number until a short page (AC-3.2, FR-3)" | ✓ |
| AC-3.3 | `client_spec.rb` `#manifest` "fails naming the request when the registry answers otherwise (AC-3.3)"; `run_spec.rb` "deletes nothing when a tagged manifest can't be read, naming the tag (AC-3.3)" | ✓ |
| AC-3.4 | `ghcr_cleanup_spec.rb` `.referenced` "fails closed on a tag pointing at a single image (AC-3.4)" | ✓ |
| AC-3.5 | `ghcr_cleanup_spec.rb` `.plan` "fails closed on a candidate with an unknown media type (AC-3.5)"; `run_spec.rb` "deletes nothing when a candidate can't be read, naming the digest (AC-3.5)" | ✓ |
| AC-3.6 | `client_spec.rb` `#delete` "raises Refused naming the version and status on any other answer (AC-3.6)"; `run_spec.rb` "stops at a refused delete, still checks the tags, and fails naming it (AC-3.6)" and "stops at a failed delete request and still checks the tags (AC-3.6)" | ✓ |
| AC-3.7 | `ghcr_cleanup_spec.rb` `.token_from` "fails naming GH_TOKEN when neither is set (AC-3.7)"; `bin/ghcr-cleanup` "exits before any request without a token, naming GH_TOKEN (AC-3.7)" | ✓ |
| AC-3.8 | `ghcr_cleanup_spec.rb` `.referenced` "fails closed on a tagged list without exactly amd64 and arm64 (AC-3.8)" | ✓ |
| AC-3.9 | `client_spec.rb` `#delete` "deletes by id, and treats a 404 as already deleted (AC-3.9)"; `run_spec.rb` "reports a 404 on delete as already deleted and carries on (AC-3.9)" | ✓ |
| AC-4.1 | `ghcr_cleanup_spec.rb` `.plan` "counts four disjoint buckets that sum to the version total (AC-4.1)"; `run_spec.rb` "dry-runs by default: deletes nothing and reports each selection and the counts (AC-4.1, FR-3)"; live dry run above | ✓ |
| AC-4.2 | `image_publishing_spec.rb` `.github/workflows/ghcr-cleanup.yml` "dry-runs by hand by default, without packages: write (AC-4.2, FR-4)"; live: step 1 under "Live cleanup", run [37861909201](https://github.com/plainprogrammer/Collector/actions/runs/37861909201) (`dry-run` success, `delete` skipped) | ✓ |
| AC-4.3 | `run_spec.rb` "reports young units with their ages (AC-4.3)"; live dry run above: the `f03eb827…` unit too young, 0 selected, nothing deleted ; selected half: step 3's selection (the scheduled run, as step 2 wasn't run separately); on the day of verification, step 5 | ✓ |
| AC-5.1 | `image_publishing_spec.rb` `docs/releasing.md` "documents the cleanup: rule, grace period, schedule, manual and local runs, failures, token (AC-5.1)" | ✓ |
| AC-5.2 | `image_publishing_spec.rb` `.dockerignore` "keeps the GHCR cleanup command out of the image and the smoke test checks it (AC-5.2, FR-5)" ; PR CI run [37854725995](https://github.com/plainprogrammer/Collector/actions/runs/37854725995) below | ✓ |

## Open Question: can GITHUB_TOKEN delete?

**Answered (2026-10-18): yes.** Run [39120330257](https://github.com/plainprogrammer/Collector/actions/runs/39120330257) deleted the three `f03eb827…` unit members with the workflow's `GITHUB_TOKEN` (`packages: write`); no fallback token is needed. Before that run: answered by the first deleting run of the **GHCR cleanup** workflow after the merge. A run that prints
`deleted` for the three `f03eb827…` unit members answers yes. A refused delete (`answered 403`) answers no: follow
the token fallback in `docs/releasing.md` (a classic personal access token with `read:packages` and
`delete:packages` in a repository secret).

## Post-merge verification (maintainer)

What is still owed, and only the live package can show: the workflow's token can list (AC-4.2) and delete (Open
Question) package versions, the first real delete leaves every tag intact (AC-1.2, AC-2.4, AC-2.5), and a second
run finds nothing (AC-1.6). Run the steps in order; each says what to expect and what to record. Commands assume a
checkout of `main` after the merge, with `gh` logged in as `plainprogrammer`. `gh workflow run` needs the workflow
file on `main`, so none of this works before the merge.

### Step 1: manual dry run of the workflow (any time after the merge) — done 2026-10-08, see "Live cleanup"

```sh
gh workflow run ghcr-cleanup.yml -f dry_run=true
sleep 5; run=$(gh run list --workflow ghcr-cleanup.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status
gh run view "$run" --json jobs --jq '.jobs[] | .name + ": " + .conclusion'
gh run view "$run" --log | grep -E 'Dry run|select|too young|versions:'
```

(Or Actions → **GHCR cleanup** → **Run workflow**, leaving `dry_run` ticked.)

**Expect:** `dry-run: success` and `delete: skipped`; the log shows `Dry run: nothing is deleted` and a counts line
summing to the package's version total. Before 2026-10-15T14:42:46Z the `f03eb827…` unit is `too young`. A
`GET https://api.github.com/users/… answered 401/403` failure means the workflow token cannot list the package:
stop and follow the token fallback in `docs/releasing.md`.

**Record:** the run URL and its counts line under AC-4.2.

### Step 2: local dry run after the grace period (after 2026-10-15T14:42:46Z) — not run separately; see "Live cleanup"

```sh
GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup
```

**Expect:** exit 0; three `select` lines for `sha256:f03eb827…` (orphan manifest list), `sha256:90ceeb5c…` and
`sha256:0f9c9927…` (unreferenced image), plus any newer orphan units (a re-run or a failed publish since
2026-10-08 adds some); nothing else selected; the counts sum to the version total.

**Record:** the full output under AC-4.3 (selected half). If anything tagged, or a child of a tagged list, appears
as `select`, stop: do not run step 3, and open an issue with the output.

### Step 3: the first deleting run — done 2026-10-18, see "Live cleanup"

Either wait for the scheduled run (Sunday 2026-10-18 06:00 UTC) or start one:

```sh
gh workflow run ghcr-cleanup.yml -f dry_run=false
sleep 5; run=$(gh run list --workflow ghcr-cleanup.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$run" --exit-status
gh run view "$run" --json jobs --jq '.jobs[] | .name + ": " + .conclusion'
gh run view "$run" --log | grep -E 'Deleting|deleted|select|versions:|ghcr-cleanup:'
```

**Expect:** `dry-run: skipped`, `delete: success`; `deleted sha256:f03eb827…` before `deleted sha256:90ceeb5c…` and
`deleted sha256:0f9c9927…` (list first); no `ghcr-cleanup:` failure line, which means the post-delete check found
every tag's children. Then `gh api '/users/plainprogrammer/packages/container/collector/versions?per_page=100'
--jq 'length'` is three fewer than before.

**If it fails:**

- `DELETE … answered 401` or `answered 403`: the workflow token may not delete (the Open Question's "no"). Nothing
  after that version was deleted. Follow the token fallback in `docs/releasing.md` (classic PAT, secret
  `GHCR_CLEANUP_TOKEN`) on a branch, merge it, and repeat this step.
- `… child sha256:… is missing`: a tag lost an image. Run step 4 at once to see which tags still pull, and open an
  issue with the log; do not re-run the cleanup until it is understood.
- Any other `ghcr-cleanup:` line: the run failed closed before or while deleting; the line names the cause.
  Investigate before re-running (`docs/releasing.md`).

**Record:** the run URL, the `deleted` lines, the version count before and after, under AC-1.2 and AC-2.4; the
Open Question's answer (yes, or no plus the fallback taken).

### Step 4: anonymous pulls of every published tag on both architectures (AC-2.5) — done 2026-10-20, see "Live cleanup"

```sh
podman logout ghcr.io
for tag in latest 0.1.0 edge; do
  for arch in amd64 arm64; do
    podman pull --quiet --arch "$arch" "ghcr.io/plainprogrammer/collector:$tag" >/dev/null &&
      echo "$tag $arch $(podman image inspect --format '{{.Os}}/{{.Architecture}}' "ghcr.io/plainprogrammer/collector:$tag")"
  done
done
```

**Expect:** six lines, each ending in the architecture it asked for (`latest amd64 linux/amd64`, `latest arm64
linux/arm64`, …), with no pull error. Add any `X.Y.Z` released since 0.1.0 to the list.

**Record:** the six lines under AC-2.5.

### Step 5: a second dry run (AC-1.6) — done 2026-10-20, see "Live cleanup"

```sh
GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup | tail -1
```

**Expect:** `… 0 selected` (orphans younger than 7 days may show as `too young`).

**Record:** the counts line under AC-1.6.

## Recording the evidence

When steps 1–5 are done (step 1 can be recorded on its own earlier):

1. Create a branch from `main` named per `docs/git-convention.md`, e.g. `013-live-cleanup-evidence`.
2. In this file:
   - Add a section `## Live cleanup (post-merge)` after "Pull request CI", with one subsection per step: the date
     and time (UTC), the run URL where there is one, and the output recorded above, in fenced blocks.
   - In the acceptance-criteria table, replace each "pending" note with a pointer to that evidence and set the
     status to ✓: AC-1.2 and AC-2.4 (step 3), AC-1.6 (step 5), AC-2.5 (step 4), AC-4.2 (step 1), AC-4.3
     (step 2).
   - Under "Open Question: can GITHUB_TOKEN delete?", replace **Pending.** with **Answered (date): yes** and the
     step 3 run URL, or **no**, the refused status, and the fallback taken (the PR that switched to
     `GHCR_CLEANUP_TOKEN`).
   - Tick the steps above.
3. If the answer was "no", also update the Open Question in `spec.md` with a PATCH (`sdd-spec-update`).
4. Commit `docs(013): record live cleanup evidence`, open a PR, and on merge close issue #17 with a link to it.
   Remove the #17 entry from `.claude/memory/spec-012-followups.md` in the same PR.

If a step's result deviates from its **Expect**, record what happened as it is, mark that AC ⚠ with the
deviation, and decide the fix before closing #17.
