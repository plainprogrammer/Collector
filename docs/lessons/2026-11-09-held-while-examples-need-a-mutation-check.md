---
date: 2026-11-09
spec: none
tags: [testing, system-specs, poll, hotwire]
---

# Lesson: A "held while Y" example can pass because an earlier step tripped another hold

## Context

[#111](https://github.com/plainprogrammer/Collector/issues/111) made a tab shown again refresh the polled admin pages at once, under the `poll` controller's other two pauses (an open menu, Turbo busy). It was a direct fix with no spec; the rulings are on the issue.

## What happened

- The first system example hid the tab, called a tick, showed the tab (one refresh), then opened a menu and showed the tab again, and expected no second refresh. It passed.
- It passed for the wrong reason. The first refresh calls `Turbo.visit`, which marks `<html>` `aria-busy` at once, so the menu case was held by the busy pause and never reached the menu check. The implementation review found this by reading the controller and Turbo's visit code.
- Dropping the menu check from the controller left the example green. After clearing `aria-busy` before the menu case, the same mutation reads `[0, 1, 2]` instead of `[0, 1, 1]`.

## What to do next time

- In an example that proves something is held while a condition is true, reset every state an earlier step in the example may have set (here `aria-busy`) before the case, or run that case first.
- Mutation-check each such case: remove the guard under test, run the example, and expect red, then restore the guard. A "held" assertion that stays green without its guard proves nothing.

## Signals to watch for

- An example with several pauses or guards in a row, where an earlier step starts a visit, a request or a job.
- A "nothing happened" expectation (a count that stays the same) that has never been seen failing.
