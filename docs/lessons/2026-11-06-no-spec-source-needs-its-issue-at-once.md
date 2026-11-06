---
date: 2026-11-06
spec: "027"
tags: [documentation, area-docs, review]
---

# Lesson: a behaviour marked "no spec source" gets its issue in the same commit

## Context

The tenancy and accounts area doc (#106) marked behaviours "no spec source" and linked one combined issue, #218.

## What happened

The first draft of #218 had four items. A fifth (a sign-up without `password_confirmation` isn't checked for a match) turned up while reading the spec's wording against `has_secure_password`. A sixth, measurement mode answering only local requests, was in the doc marked "no spec source" with no issue until the implementation review noticed it. Both came from guard clauses in concerns the doc already named, not from the spec's list.

## What to do next time

- When the doc marks a behaviour "no spec source", add it to the open issue in the same commit, so the marker never lacks a link.
- After the first draft, re-read each `before_action` and guard in the concerns the doc names, and ask for each: which spec criterion says this?
- Retitle the issue when its count changes (the doc says "six" in three places).
