---
date: 2026-11-06
issue: "217"
tags: [testing, smoke, shell, ci, flaky]
---

# Lesson: `curl | grep -q` under pipefail fails on a page that has the match

## Context

`bin/backup-smoke` failed three times on `Image (linux/arm64)` (amd64 green on the same commits) at "the lot isn't on the collection page", after a restore whose state check had passed. The check was `curl -s … /collection | grep -q "Smoke Dragon" || fail …` in a script under `set -euo pipefail`.

## What happened

The local app never failed: 20 clean runs of the unmodified script, then about 3,800 more trials of the pipe against the real restored instance, idle and with the VM's CPUs saturated. The mechanism was found by reading the pipe, then measured with a probe: `grep -q` exits at the first read that holds a match, so if curl still has bytes to write it gets EPIPE (exit 23), and `pipefail` makes the pipeline fail although the page held the lot.

Two things hid it. macOS's BSD grep buffers before it matches, so the host never showed it; GNU grep (CI's Ubuntu, and the Debian collector image) did. And the real page arrives in varying pieces (13,516 bytes; one receive, or 2,873+4,096+6,547, or 6,957+6,559, seen with `curl --trace-ascii`), with the first `Smoke Dragon` at byte 11,235 and only about 2.3 KB after it. With GNU grep, a page of that shape sent in two writes 5 ms apart failed 100 of 100 times at a 13,000-byte split, 2 of 100 at 12,000, and never unsplit; capturing the body first and then grepping never failed.

## Resolution ([#217](https://github.com/plainprogrammer/Collector/issues/217))

The scripts capture a command's output (or the page, to a file) first and test it after; `spec/smoke_scripts_spec.rb` sweeps `bin/backup-smoke`, `bin/image-smoke` and `bin/upgrade-smoke` for a pipe into `head` or a quitting grep, and a failed check now prints the status, size, redirect, the `session_id` cookie's presence and the first 300 bytes. The CI trigger itself is not shown: the issue closes after green arm64 jobs on `main`. `bin/image-smoke` already said "no pipe can end early under pipefail" for its own task output; the page fetch in the other script did not follow it.

## What to do next time

- Under `pipefail`, never end a pipe in `grep -q`, `grep -m` or `head`: capture, then test (`grep -q … <<<"$out"`).
- Reproduce a shell flake with the CI's tools: GNU grep in the image, not the host's BSD grep.
- Size a synthetic probe from the real response (length, where the match sits, how it arrives), and say plainly what the probe does not prove.

## Signals to watch for

- A smoke or CI script that passes locally on macOS and fails on a Linux runner at a `grep -q`, `head` or `read` on the end of a pipe.
- A check whose failure message names the missing thing but prints nothing of what came back.
