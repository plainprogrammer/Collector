---
date: 2026-10-08
spec: "012"
tags: [smoke-test, first-run, containers]
---

# Lesson: Black-box checks on a fresh instance meet the first-run redirect

## Context

Spec 012's plan added `bin/image-smoke`, which boots a built image and probes its pages, assets and rake tasks, in CI and locally.

## What happened

The draft script checked that `/session/new` answers 200 straight after boot. On a fresh instance, the `FirstRun` concern redirects every page except `/up` and the OCR assets to `/registration/new` until a user exists, so the check would have answered 302 and failed every build. The plan review caught it by reproducing the sequence in a throwaway request spec. The script now checks the registration page, creates the admin with `collector:user`, and only then probes the sign-in page and the scanner.

## What to do next time

Any black-box check against a freshly booted Collector, beyond `/up`, either creates the admin first or asserts the first-run registration page. When writing such a check, read the controller concerns (`FirstRun`, `Authentication`) for redirects that depend on database state.

## Signals to watch for

- Smoke tests, health probes or demo scripts that run against an empty database.
- An unexpected 302 to `/registration/new`.
