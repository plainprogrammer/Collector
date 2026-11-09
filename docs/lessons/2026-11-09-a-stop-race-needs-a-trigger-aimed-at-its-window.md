---
date: 2026-11-09
spec: none
tags: [debugging, containers, solid-queue, puma, smoke]
---

# Lesson: a shutdown race needs a trigger aimed at its window

## Context

#177: the upgrade proof's container stop was sometimes killed at the end of its 30 s grace (exit 137), on CI runners only. Stops on this machine never failed.

## What happened

The first local stops (at the first `/up` poll, 2 s granularity: idle, a job queued, under load, after a second boot) were graceful 18 of 18, so the cause had to be about the moment of the stop. Solid Queue's Puma plugin has two start-up windows: before its forked supervisor has trapped signals, where the INT is swallowed and Puma's `Process.wait` never returns (exit 137), and while the supervisor's dispatcher, worker and scheduler boot, where their TERM is lost and the supervisor waits its 5 s `shutdown_timeout`.

Stopping at the first `/up` answer, as the harness does, only ever hit the second window (3 of 15 took about 5.8 s). The first needed a stop within about 0.1 s of Puma's boot. My first trigger, `docker logs -f | while read ... break`, could not give that: the pipeline does not end until `docker logs` writes another line, so the stop always came after the supervisor had started. Polling `docker logs` every 20 ms for Puma's "Use Ctrl-C to stop" line did: 8 of 15 stops exited 137 at 30.5-31 s. `docker run --cpus=0.3` widens both windows (every stop took 4-12 s), which is how a slower CI runner reaches them by chance.

Solid Queue 1.7.2 does not change the plugin; the maintainer ruled the operator side a known limit and the proof now waits for the three `Started` log lines before it stops an instance (`release-and-deploy.md`, An upgrade).

## What to do next time

- Time a stop against a log line, not against a health check, and poll the log; do not pipe `logs -f` into a reader that is meant to stop early.
- Slow the container (`--cpus`) to find out whether a flake is a window that a slower machine widens.
- A first trigger that never fails is not evidence of no race; say which moment each measurement fired at.
