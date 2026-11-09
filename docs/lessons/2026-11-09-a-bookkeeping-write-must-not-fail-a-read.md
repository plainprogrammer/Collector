---
date: 2026-11-09
spec: 049
tags: [sqlite, requests, reliability]
---

# Lesson: a bookkeeping write on a read must not be able to fail the request

## Context

Spec 049's daily session stamp is written by the first request of the day, which is often a GET.

## What happened

The plan and its reviews passed `session.update!` as written. The implementation review found that SQLite's 5 s busy timeout (for example behind a long catalog-refresh batch) raises `ActiveRecord::StatementTimeout` there, turning an ordinary page view into a 500, for a value the spec allows to lag.

## What to do next time

- When a request writes only to record something that may lag (a last-seen stamp, a counter), rescue `ActiveRecord::StatementTimeout` and `SQLite3::BusyException`, log one line and skip it; the next request tries again.
- Never let that rescue reach the decision the request exists for (here, whether the session is valid).
- Ask of every write on a read path: what does the page do if this fails?
