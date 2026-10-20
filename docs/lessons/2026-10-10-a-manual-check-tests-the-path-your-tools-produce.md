---
date: 2026-10-10
spec: "015"
tags: [manual-verification, solid-queue, restarts, plans]
---

# Lesson: A manual check tests the path your tools produce

## Context

Spec 015's plan ended with a manual check: press "Refresh now", stop the development server while the sync runs, start it again. It expected the job to run again by itself, the earlier run to be listed as failed with "interrupted", and the new run to proceed (AC-3.3).

## What happened

The server ran as a background task and was stopped with the harness's task stop. That stop was a kill, not a graceful shutdown: the job stayed claimed and its run stayed running. After the restart nothing re-ran. About 5 minutes after the worker's last heartbeat, Solid Queue failed the job with `ProcessPrunedError`, and an admin's Retry then closed the old run as interrupted and started a new one.

So the check proved the spec's crash path (fail after about 5 minutes, then Retry works) and not the graceful path the plan's sentence described. The spec's Error Scenarios table names both; the plan's step named only "stop the server", which doesn't say which one you get. The result was only reported correctly because the queue's state was inspected between the stop and the restart.

## What to do next time

When a plan has a manual restart or failure check, name the mechanism it depends on (a SIGTERM to Puma, a kill, a pulled network) and which spec scenario each one proves. After the stop, look at the recorded state before restarting, and report the path that was actually exercised. List the other path as unchecked.

## Signals to watch for

- A manual step that says "stop" or "restart" without saying how.
- A spec with two recovery paths (graceful and crash) and a plan with one check.
- An expected result ("runs again by itself") that doesn't appear within seconds of the restart.
- A server run under a task runner whose stop signal you haven't checked.
