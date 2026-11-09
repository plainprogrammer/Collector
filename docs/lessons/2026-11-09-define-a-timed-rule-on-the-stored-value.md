---
date: 2026-11-09
spec: 049
tags: [specs, sessions, acceptance-criteria]
---

# Lesson: define a timed rule on the value the app stores, not on the event it lags

## Context

Spec 049 ends a session after 30 days without use, and records use at most once a day so ordinary requests don't write.

## What happened

The first draft defined "expired" as "its last use is 30 days or more ago". The app never knows the true last use: it knows the stamp, which lags it by under 24 hours. AC-1.1 ("last use 29 days and 23 hours ago: signed in") could not be proved, and the sweep's meaning of "expired" was ambiguous. The spec review (round 1, M1) caught it.

## What to do next time

- Define the rule on the stored value ("the stamp is 30 days old or more") and state the derived guarantee separately: a session used within 29 days is never expired, one unused for 30 days always is.
- Write the criteria's boundaries in terms of the stored value too.
