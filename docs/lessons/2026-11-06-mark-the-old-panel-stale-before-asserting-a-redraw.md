---
date: 2026-11-06
spec: "047"
tags: [system-specs, turbo, focus, testing]
---

# Lesson: Mark the old panel stale before asserting a redraw

## Context

Spec 047's system examples check that focus is on "Set" and the status says "Cards you scan now: …" after "Set" replaces the sitting panel with a Turbo Stream. Two steps repeated a "Set" whose answer is the same sentence as before, and one clicked "Set" with no sitting open.

## What happened

The first plan draft waited on the status text and then on `…:focus`. Both already held on the OLD panel: the status line carried the same sentence, and the click or Enter had focused the old "Set" button (Turbo disables the submitter only after the request starts). The example could pass with no feature at all, and the red run of those steps proved nothing. The Opus plan review caught it by reading the plan, not by running anything.

## What to do next time

Before the action, mark the node the redraw replaces (`document.getElementById('scanner_sitting').dataset.stale = '1'`), act, and wait for `have_no_css("#scanner_sitting[data-stale]")`: only a replaced panel loses the mark. Then assert focus and text. Use the mark whenever the answer's text or the focused control can equal what is already on the page.

## Signals to watch for

- A redraw whose answer repeats the previous text (a repeated Set, a clear with nothing to clear).
- A focus assertion straight after a click or Enter on the control that is about to be replaced.
- An example that is green in its first run before the code exists.
