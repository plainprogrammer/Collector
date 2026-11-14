---
date: 2026-11-13
spec: 088 (#345)
tags: [scanner, hotwire, turbo, focus]
---

# Lesson: a pane derived from markup flickers when a part of it hides mid-flow

## Context

The scanner's `scan-shell` controller sets `c-scan--result` from the markup: the pane shows while `#scanner_result`, the pane's `#status` or the send-failure block holds something (spec 082 decision 19). Spec 088's "Send again" empties `#status`, sends, and hides the failure block.

## What happened

Between the hide and the answer nothing in the pane was filled, so `scan-shell` dispatched `changed({ result: false })`: the pane closed, the strip's name and collector line were cleared, the frozen frame was hidden, and when the answer then opened the selection the pane rose again with an empty strip. The implementation review found it (M2); the examples had checked only the panel after "Send again". Separately, a fixed number of animation frames was no reliable wait for a Turbo Stream, which Turbo applies after a repaint; the reader now waits for the answer's effect (the result class, or the status line's text changing), and drops a sentence meant for a pane that never opened.

## What to do next time

- When state is derived from markup, write each answer so no intermediate markup looks like "no result": keep a part shown until the render that replaces it, in the same render as the answer.
- Wait for an effect, not for a number of frames, and give a sentence for a part that may never open a way to be dropped.
- An example for a retry flow asserts what the page holds after the retry (the strip's texts, no close and reopen), not only that it works.

## Signals to watch for

- A controller that sets a state class from "is anything in these regions" and a flow that empties then refills a region.
- A script that waits `n` frames after `Turbo.renderStreamMessage`.
