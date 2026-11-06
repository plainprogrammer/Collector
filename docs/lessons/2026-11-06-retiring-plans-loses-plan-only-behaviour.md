---
date: 2026-11-06
spec: "027"
tags: [documentation, area-docs, plans]
---

# Lesson: look in a plan for what the code does before the plan is retired

## Context

Spec 027 slice C for the scanner (#107) retired six plans (specs 005, 007–011), 17,000 lines. Some behaviour was decided in a plan and never in a spec.

## What happened

- The scanner's Content-Security-Policy has `object-src`, `base-uri`, `form-action`, `frame-ancestors` and `font-src` directives. Spec 007 AC-2.4 and ADR 0001 name none of them; they are in spec 007's plan (around line 1336). Once the plan is retired, the code is their only record.
- Reading the plans end to end was not possible; searching them for the code's own directives, constants and comments was, and it found the three behaviours that became issue #219.

## What to do next time

- Before retiring a plan, `git grep` its text for the identifiers of the code the area doc covers (directive names, constants, setting names) and list the hits that no spec criterion or ADR states. Each is a "no spec source" behaviour for an issue.
- Do it before the retire commit: afterwards the plan is only in history.

## Signals to watch for

- A constant, directive or setting in the code with a comment but no AC to cite.
- A plan listing code blocks for a file the spec only describes in outline.
