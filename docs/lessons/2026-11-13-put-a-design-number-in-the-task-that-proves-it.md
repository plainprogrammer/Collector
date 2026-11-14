---
date: 2026-11-13
spec: 088 (#345)
tags: [plans, design-system, layout]
---

# Lesson: put a design number in the task that proves it

## Context

Spec 088 decision 13 changed two layout numbers of spec 080 (the images' floor 160px to 96px, a 64px strip under 600px), a visible design change the maintainer was told of and might rule differently on.

## What happened

The first plan wrote the numbers into the CSS in the skeleton task and proved them in a later task, so the later task's examples would never have gone red, and the numbers sat in two places. The plan review (M5) moved the CSS into the task that measures it: its examples fail first on spec 080's old numbers, then pass when the two values are written, and a different ruling is a change to those two places and their examples. The measured boxes also corrected the spec's own arithmetic (AC-5.2 computed a 22px scroll; it is 6px).

## What to do next time

- Write a number that is a design decision in the task that proves it, with its failing example before it; keep it in one place (a custom property and one container block) and say so in the area doc's Named constants.
- Record measured boxes, and correct the spec's arithmetic when they differ (a patch version).

## Signals to watch for

- A plan whose CSS task and measuring task are different tasks, or a number repeated in a rule, a comment and a document.
