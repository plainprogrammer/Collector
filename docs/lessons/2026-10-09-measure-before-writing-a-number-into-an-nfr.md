---
date: 2026-10-09
spec: "014"
tags: [nfr, estimates, image-size, verification]
---

# Lesson: Measure before writing a number into an NFR

## Context

Spec 014 added `ruby-vips` to the bundle so Active Storage variants work in the image. Its image-size NFR said the image would grow "by at most the `ruby-vips` and `ffi` gems (under 1 MB, per spec 008 `research.md` §7)".

## What happened

The figure was an estimate carried over from another spec's research. Two spec reviews and two plan reviews passed it, because each checked the sentence against its source and none measured it. The verification unit ran `du -sk` in the built image: `ruby-vips` 2.3.0 was 644 KB and `ffi` 1.17.4 was 2,056 KB, about 2.7 MB together. The NFR was "not met as worded", the maintainer accepted the growth, and the spec needed a PATCH (1.1.1) after the code was finished.

The plan had already locked the new gems in a scratch bundle to check the lockfile diff. Measuring the two gem directories there would have taken one command.

A second trap sat beside it: the whole-image comparison showed 20.7 MB of growth, most of it from a duplicate OCR engine in local builds (issue #31) and from other changes since the older image. Only the per-path measurement isolated the feature.

## What to do next time

When an NFR states a number, measure it during planning, or write the bound without a figure ("at most the two gems"). Treat a figure quoted from older research as an estimate until something in the plan measures it. When measuring image growth, measure the paths that changed inside the image, not the two images' total sizes.

## Signals to watch for

- An NFR cites a number with "per <another spec's> research".
- A plan that already builds or installs the thing in scratch but doesn't measure it.
- A review that confirms a figure matches its source, with no command behind it.
- Two images compared by total size when they were built from different commits or different contexts.
