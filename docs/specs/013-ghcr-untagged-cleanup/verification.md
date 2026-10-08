# Verification: Clean Up Untagged GHCR Package Versions (spec 013)

**Spec:** [spec.md](spec.md) v1.1.2 · **Plan:** [plan.md](plan.md) Phase 5 · **Recorded:** 2026-10-08 ·
**Branch:** `013-ghcr-untagged-cleanup`

Evidence for every acceptance criterion. The selection rule, the client and the run are covered by
`spec/lib/collector/ghcr_cleanup_spec.rb`, `spec/lib/collector/ghcr_cleanup/client_spec.rb` and
`spec/lib/collector/ghcr_cleanup/run_spec.rb`; the workflow, image exclusions and docs by
`spec/image_publishing_spec.rb`. All four run in `bin/ci`, with WebMock blocking real HTTP. Criteria that need
the pull request's image builds or the live package are marked pending below.

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

## Acceptance criteria

| AC | Evidence | Status |
|---|---|---|
| AC-1.1 | `ghcr_cleanup_spec.rb` `.plan` "selects an unreferenced image past the grace period (AC-1.1)" | ✓ |
| AC-1.2 | `ghcr_cleanup_spec.rb` `.plan` "selects an orphan list with its children, list first (AC-1.2, FR-1)"; `run_spec.rb` "deletes the orphan unit, list first, and nothing a tag needs (AC-1.2, AC-2.2, FR-1)" and, with the real client against stubbed GitHub and GHCR, "deletes the orphan unit and checks the tag's children (AC-1.2, AC-2.4)" | ✓ (live delete pending: maintainer, after merge) |
| AC-1.3 | `ghcr_cleanup_spec.rb` `.plan` "keeps a unit whose list is inside the grace period although its children are not (AC-1.3)" | ✓ |
| AC-1.4 | `ghcr_cleanup_spec.rb` `.plan` "keeps a young unreferenced image (AC-1.4)" | ✓ |
| AC-1.5 | `image_publishing_spec.rb` `.github/workflows/ghcr-cleanup.yml` "runs weekly and by hand, never on pushes or pull requests (AC-1.5, FR-4)" and "deletes on the schedule or an unticked dry_run, the only job with packages: write (AC-1.5, FR-4)" | ✓ |
| AC-1.6 | `run_spec.rb` "deletes nothing on a second run (AC-1.6)" | ✓ (live second run pending: maintainer, after merge) |
| AC-2.1 | `ghcr_cleanup_spec.rb` `.plan` "keeps tagged versions of any age, with several tags (AC-2.1)"; live dry run: 5 tagged, none selected | ✓ |
| AC-2.2 | `ghcr_cleanup_spec.rb` `.plan` "keeps old children of a tagged list (AC-2.2)"; `run_spec.rb` "deletes the orphan unit, list first, and nothing a tag needs (AC-1.2, AC-2.2, FR-1)"; live dry run: 10 referenced | ✓ |
| AC-2.3 | `ghcr_cleanup_spec.rb` `.plan` "deletes an old list but keeps a child it shares with a tagged list (AC-2.3)" | ✓ |
| AC-2.4 | `run_spec.rb` "fails naming the tag and digest when a tag's child is missing after deleting (AC-2.4)" and "deletes the orphan unit and checks the tag's children (AC-1.2, AC-2.4)"; `client_spec.rb` `#fetchable?` "answers from a HEAD with the same Accept (AC-2.4)" | ✓ (live post-delete check pending: maintainer, after merge) |
| AC-2.5 | Anonymous `podman pull` of `latest`, `0.1.0`, `edge` on amd64 and arm64 after the first deleting run | pending: maintainer, after merge |
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
| AC-4.2 | `image_publishing_spec.rb` `.github/workflows/ghcr-cleanup.yml` "dry-runs by hand by default, without packages: write (AC-4.2, FR-4)" | ✓ (workflow file); live manual dry run pending: maintainer, after merge |
| AC-4.3 | `run_spec.rb` "reports young units with their ages (AC-4.3)"; live dry run above: the `f03eb827…` unit too young, 0 selected, nothing deleted | ✓ (too-young half); selected half pending: maintainer, after 2026-10-15T14:42:46Z |
| AC-5.1 | `image_publishing_spec.rb` `docs/releasing.md` "documents the cleanup: rule, grace period, schedule, manual and local runs, failures, token (AC-5.1)" | ✓ |
| AC-5.2 | `image_publishing_spec.rb` `.dockerignore` "keeps the GHCR cleanup command out of the image and the smoke test checks it (AC-5.2, FR-5)" | ✓ (files); image half pending: PR image builds |

## Open Question: can GITHUB_TOKEN delete?

**Pending.** Answered by the first deleting run of the **GHCR cleanup** workflow after the merge. A run that prints
`deleted` for the three `f03eb827…` unit members answers yes. A refused delete (`answered 403`) answers no: follow
the token fallback in `docs/releasing.md` (a classic personal access token with `read:packages` and
`delete:packages` in a repository secret).

## Maintainer steps after merge

- [ ] **After the merge:** Actions → **GHCR cleanup** → **Run workflow** with `dry_run` ticked. Expect: only the
  `dry-run` job runs, green, and its log matches the local dry run (AC-4.2; confirms the workflow token can list the
  package through the `/users/` endpoint).
- [ ] **After 2026-10-15T14:42:46Z:** a local dry run lists the three `f03eb827…` unit members as `select`
  (AC-4.3). Then Actions → **GHCR cleanup** → **Run workflow** with `dry_run` unticked (or wait for the Sunday
  2026-10-18 06:00 UTC run). Expect: only the `delete` job runs, it prints `deleted` for the three, and it ends
  green after its post-delete check (AC-1.2, AC-2.4). A refused delete (`answered 403`) answers the Open Question
  the other way: follow the token fallback in `docs/releasing.md`.
- [ ] **After that run (AC-2.5):**

  ```sh
  podman logout ghcr.io
  for tag in latest 0.1.0 edge; do
    for arch in amd64 arm64; do podman pull --arch "$arch" "ghcr.io/plainprogrammer/collector:$tag"; done
  done
  ```

  Expect: six successful pulls. A second dry run prints `0 selected` (AC-1.6).
- [ ] Record the workflow run URLs, the pull output and the Open Question's answer in `verification.md`; commit
  `docs(013): record live cleanup evidence`; close issue #17.
