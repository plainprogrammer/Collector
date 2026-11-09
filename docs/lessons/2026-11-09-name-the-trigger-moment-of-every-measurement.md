---
date: 2026-11-09
spec: none
tags: [measurement, reporting]
---

# Lesson: name the trigger moment of every measurement

## Context

While reporting #177's cause I wrote that stops "15 s after boot or later" were always graceful (18 of 18), and the same figure went into a draft of the area doc.

## What happened

Those runs polled `/up` every 2 s and stopped at the first answer, so they fired within about 2 s of Puma's boot, not 15 s later. The review caught the doc's version; the report had already gone out. The claim was backwards for the point the doc was making: it was the very moment where stops can fail.

## What to do next time

- Put the trigger and its timing next to each count ("stopped at the first `/up` poll, 18/18") when it is first written down, in a report or a doc.
- Re-read a count against the script that produced it before it goes into a document that rules on a limit.
