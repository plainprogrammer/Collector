---
date: 2026-09-29
spec: "001"
tags: [podman, compose, yaml, verification]
---

# Lesson: Container and verification-script gotchas on this machine

## Context

Feature 001, Compose verification with rootless Podman + podman-compose, and per-commit RSpec checks.

## What happened

- `SECRET_KEY_BASE: ${SECRET_KEY_BASE:?... (generate with: openssl rand -hex 64)}` is invalid YAML — the `with: ` inside the unquoted value parses as a mapping. Quoting fixed it.
- `openssl` isn't installed on the dev host; `ruby -rsecurerandom -e 'print SecureRandom.hex(64)'` works.
- Rootless Podman healthchecks run without extra setup (container healthy in ~11s).
- A per-commit check grepping `^[0-9]+ examples` falsely failed single-example commits (RSpec prints "1 example"), and `PIPESTATUS` after `out=$(...)` reported grep's exit, not RSpec's.

## What to do next time

Quote Compose interpolations that contain `: `. Generate secrets with Ruby here. In verification loops, capture the command's own exit code (`cmd > file; rc=$?`) and match `examples?`. Before calling a failure real, reproduce it in isolation.

## Signals to watch for

YAML "mapping values are not allowed" errors; "NO OUTPUT" results in loops; empty secret values in Compose.
