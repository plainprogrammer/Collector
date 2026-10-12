---
date: 2026-10-11
spec: "018"
tags: [testing, system-specs, layout, css, planning]
---

# Lesson: A change to the layout needs the whole suite, and each new rule broken once

## Context

Spec 018 added a footer to the application layout, so to every page. The plan's code was prototyped and run before the plan was written: a model spec, a request spec, a file-content spec and a system spec for the footer, all green together, with RuboCop clean.

## What happened

Four things were wrong that the feature's own specs, run on their own, didn't show.

- **An example relied on the window an earlier example left.** "The footer follows short content, not pushed to the viewport's bottom" asserted the footer's bottom against the window's height. Alone, the window was 1400 × 1400. In the whole suite it followed an example whose driver had made the window smaller, and it failed by one pixel. The fix was for the example to set its own window size.
- **Two script calls raced a page that was still changing.** The scanner page grows while the camera starts. The spec measured the footer in one call and the scanner in the next, and in the whole suite the page grew between them. The fix was one call that measures both.
- **A late, small revision broke a distant assertion.** After the plan was reviewed, the maintainer asked for a class on `<body>` in place of a `:has()` selector. The revised phases were re-proved red then green on their own files. The whole suite then failed in `spec/requests/design_system_spec.rb`, which asserted the exact string `class="c-shell"`. Nothing in the feature's files pointed at it.
- **One rule was tested by nothing.** Removing each new CSS rule in turn showed that the rule taking `c-main`'s bottom padding away could go and every example still passed: the spec compared the footer's top with the main element's bottom, which are equal whatever the padding. An assertion on the padding itself was added.

A fifth, found by the plan's reviewer by arithmetic: the phone-width frame was 480px tall and the shortest page about 470px, so "the page scrolls" held by font metrics. The frame is now 320px.

## What to do next time

When a change touches the layout or the shell, run the whole suite after every revision of the code, however small or late, and run the system specs under more than one seed. Don't accept "the phase's own specs are green" as the state of a layout change.

For each new CSS rule, remove it once and see an example fail. If none does, the rule has no test.

In a system example, set the window size the example needs, and take every measurement that is compared in one script call.

## Signals to watch for

- An assertion against `innerHeight`, a window size or "the bottom of the viewport".
- Two `evaluate_script` calls whose results are compared, on a page with a camera, a poll or lazy content.
- A new attribute or class on `<html>`, `<body>` or the app header, and specs elsewhere that match markup as an exact string.
- A geometric assertion that would hold with the new rule deleted.
- A plan revision described as "one line" after the full run was done.
