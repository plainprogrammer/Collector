---
date: 2026-10-08
spec: "011"
tags: [git, rebase, plan, docker, adr, process]
---

# Lesson: Rebasing an unbuilt plan over build changes on main

## Context

Spec 011's branch held only planning docs (PRD, spec, a 16-phase plan, ADRs) when it was rebased onto `main` after spec 012 (GHCR image publishing) merged.

## What happened

- The rebase reported no conflicts, but two things were broken anyway.
- **ADR number:** spec 012 had added ADRs 0008–0010, so spec 011's ADR 0008 collided by number. It was renumbered 0011, with references updated in the plan and memory.
- **Build context:** spec 012's new `.dockerignore` keeps `/script` out of the image. Phase 15 of the plan runs `script/scanner/art_decoder_fingerprints.rb` inside the production image, so that step would have failed. It now mounts `script/scanner` into the container.
- The plan's other Dockerfile, CI and `bin/setup` edits still fit `main`'s versions; the anchors they edit around hadn't moved.
- A plain branch push ran no CI, because the workflow runs only on pull requests and `main`. A draft PR exercised the new image builds.

## What to do next time

1. After rebasing a branch whose plan isn't built yet, list the files `main` changed (`git diff --stat <old base>..origin/main`).
2. Search the plan for every command and code block that touches those files, especially `Dockerfile`, `.dockerignore`, `.github/workflows`, `bin/setup` and `config/ci.rb`. Check each against `main`'s version.
3. Check numbered artifacts that `main` may have taken (ADRs, migration timestamps against `db/schema.rb`).
4. Open a draft PR to run CI; pushing a branch doesn't run it.

## Signals to watch for

- `main` merged build, CI or image work while the branch was planning.
- `main` added ADRs or migrations.
- The plan runs repository files inside a container.
