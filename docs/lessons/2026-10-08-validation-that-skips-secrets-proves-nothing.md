---
date: 2026-10-08
spec: "012"
tags: [kamal, secrets, verification]
---

# Lesson: A config check that doesn't resolve secrets can't prove a deploy works

## Context

Spec 012 pointed `config/deploy.yml` at GHCR with an active `KAMAL_REGISTRY_PASSWORD` entry. AC-5.4 also required `.kamal/secrets` to read that password from the environment. Agents can't read that file, so the check was the maintainer's.

## What happened

`bin/kamal config` validated the new registry block on every run, but it never resolves secrets. The maintainer's first check, `grep -c KAMAL_REGISTRY_PASSWORD .kamal/secrets`, returned 4 and looked like a pass. An anchored `grep -c '^KAMAL_REGISTRY_PASSWORD='` returned 0: every mention was in the stock file's commented examples. A real `bin/kamal deploy` would have failed to resolve the registry password. The maintainer added the assignment in `63596c6`.

## What to do next time

When an acceptance criterion depends on a secret resolving, check for an uncommented assignment with an anchored, masked grep (`grep -n NAME file | sed -E 's/=.*/=<masked>/'`), not a substring count. Don't count `kamal config` passing as evidence that secrets resolve.

## Signals to watch for

- A configuration check passes while the secret it relies on was never resolved.
- A count above 1 for a name in a file known to carry example comments.
- A secrets file that has never been edited since `rails new`.
