---
date: 2026-11-10
spec: 061 (restates 048 AC-1.8), issues #271, #288
tags: [testing, system-specs, layout, specs]
---

# Lesson: a wrap criterion needs a measured margin, stated at the width a phone has

## Context

Spec 048 AC-1.8 said a five-character set code wraps the table row's phone line at 360px. It was written from a probe in a 360px frame. The suite's Firefox draws a 15px classic scrollbar, so the probe's content was 345px wide, and a real phone (overlay scrollbars, 360px of content) fits that line with about 8px to spare. #271 found it when the Mac's scrollbar setting flipped the example; #288 asked for the criterion to be restated, and spec 061 did it.

## What happened

- The first measurement that mattered was not the wrap but the **room**: the width the line's cell has. In the table's auto layout the name column takes all the width the other columns leave, so the room moved one for one with the content width (131, 146, 161px at 330, 345, 360px). A line that fits reports its own width as its room, so the room can only be read from a line that wraps.
- That made the margin computable at any scrollbar setting: unwrapped width minus (room + scrollbar width). The old line was at −7.6 in the suite and +8 on a phone; the new one (PLST · PCY-132 · Etched · NM · EN, 184px) is +23.15 at both, which was shown with a classic and a one-off overlay run.
- Sweeping frame widths 345, 360 and 375 with classic scrollbars gave content widths of 330, 345 and 360px, so the probe covered the phone's width without changing the browser's scrollbar setting.
- Choosing the line from the vocabulary's real values (a The List code and number, the Etched finish) found a 23px margin without inventing data.

## What to do next time

- State a wrap or fit criterion at the content width a real device has, and say how much the line must overflow by; assert the margin with a message that prints the numbers, so a font or gutter change fails loudly instead of flipping by a few pixels.
- Read the scrollbar's width from the frame (`innerWidth - documentElement.clientWidth`) instead of assuming it, and add it to the room.
- A line that passes by under about 15px (a scrollbar) depends on the scrollbar. Probe at two scrollbar settings, or at frames 15px apart, before writing the number into a spec.
- An example that passes prints nothing: if its numbers go in `verification.md`, print them with a temporary logging line and say in the evidence that it was temporary and reverted.
