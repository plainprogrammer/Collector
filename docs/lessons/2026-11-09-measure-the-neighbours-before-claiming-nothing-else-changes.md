---
date: 2026-11-09
spec: none
tags: [css, tables, testing, bug-fix]
---

# Lesson: measure the neighbouring specs' scenarios before claiming "nothing else changes"

## Context

#208: just above the 640px breakpoint the collection table was up to about 25px wider than its container. The ruling was to let the widest column give in `additions.css`. The brief also said the phone layout, 1280px and spec 048's long place name must stay as they were.

## What happened

The first build (the name `div` clamped to one line from 640px up) passed the new fit examples and spec 048's own examples, and the 1280px shots were pixel-identical. A read-only review then reasoned that auto table layout shares a shortfall between columns in proportion to how far each can shrink, so a shrinkable name column takes a share beside a long place name. A throwaway probe confirmed it: with spec 048's 60-character place the card name was cut at 800, 900 and 1024px frames, where it had stayed whole and the place wrapped. Spec 048's examples never looked at the card name. The fix was to clamp only in the band that overflows (containers of 640 to 699px).

The review also found that a clamp on the `div` around a link scrolls the `div` when the link is focused (the link's hidden second line) and clips the focus ring. The clamp now sits on the link.

## What to do next time

- For a "nothing else changes" claim, write a throwaway probe that measures the neighbouring specs' scenarios (here the long place name at 800 to 1024px) before and after, with the old rule injected as a `<style>`. Passing the neighbours' examples shows only what they assert.
- To let one `nowrap` table column give, lower only its minimum (`white-space:normal`, `overflow-wrap:anywhere`, a one-line clamp); `width`, `max-width` and `contain` also zero its natural width. Scope it to the band that overflows, since a shrinkable column takes a share of the shortfall at every width.
- Put a line clamp on the link, not on a clipping box around it; look at the focused state in a screenshot.
