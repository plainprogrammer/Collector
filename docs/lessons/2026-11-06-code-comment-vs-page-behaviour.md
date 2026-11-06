---
date: 2026-11-06
spec: "027"
tags: [documentation, area-docs, review]
---

# Lesson: a code comment can describe an effect the page's head undoes

## Context

Writing `docs/architecture/scanner.md` (spec 027 slice C, #107). `scanner/recognition.js` keeps its OCR worker in a module variable, and its comment says "kept across Turbo visits".

## What happened

- The first draft repeated the comment as a rule: "the OCR worker is kept for the page session across Turbo visits", and filed it as a behaviour with no spec source.
- The read-only review found that the scanner's head (`scanners/_head.html.erb`) sets `turbo-visit-control: reload`, so every visit is a full page load, the module is evaluated again and the worker is created again. The behaviour the comment describes never happens.
- The doc and issue #219 were rewritten to say what the code does, and the question to the maintainer changed with it.

## What to do next time

- For a claim about how long something lives (a worker, a stream, a cache), read the layer above the module: the page's head and meta tags, the Turbo settings, the controller that mounts it. A module's own comment says what its author meant.
- Name the comment as the source of the intent and the page as the source of the effect.

## Signals to watch for

- "kept", "reused" or "persists" in a code comment next to a module-level variable.
- A page that asks Turbo for a full load or sets `no-cache` for a snapshot.
