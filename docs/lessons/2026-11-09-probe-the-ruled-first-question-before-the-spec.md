---
date: 2026-11-09
spec: 053
tags: [specs, process, evidence]
---

# Lesson: answer a ruled "first question" with a throwaway probe before writing the spec

## Context

Issue #176's rulings said to confirm first what the scanner does with an index built with other settings or for an older catalog, and to shape the spec by the answer.

## What happened

The answer was in four files (`MTG::Art.page_config`, the art route's controller, `art.js`'s `parseIndex`, the card reader controller), and an existing system example already covered one half. A throwaway request example of about 20 lines (a drifted build and file; `page_config`, the route's status, the header digest against the page's) settled both halves in one run: settings drift is served with 200 and refused in the browser, catalog drift is served and used. The spec's Problem Statement cites it, and its two permanent pinning examples (AC-4.1, AC-4.2) came from it.

## What to do next time

- When a ruling says "confirm X first", run X as a throwaway example (outside the repo, in the scratchpad) before drafting states, and keep the useful part as a pinning example so the claim in the spec can't drift.
- Look for an existing example of half the question before writing the probe.
