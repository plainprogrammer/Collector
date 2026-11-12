---
date: 2026-11-11
spec: 069 (#256)
tags: [testing, system-specs, narrow-frame, phone-width, acceptance-criteria, design-system]
---

# Lesson: a phone-width criterion needs a measured chain from the viewport to the box, and a 360px test frame is not a 360px phone

## Context

Spec 069 AC-5.3 said the open shape panel's parts "fit in the 279px inside it" at 360px. The 279px came from spec 060 AC-2.4 and the design system's `DeckShape.md` ("313px wide, 279px inside"). The spec review, the plan review (two rounds) and the plan's example all kept it. The worst-case fixture put "1,357" in the 6+ column, which fits its column by a fraction of a pixel.

## What happened

- The first system example, run in a 360px narrow frame, measured a 263px interior, not 279px, and the count overflowed its column by about 1.85px. Two things the number had left out: the page's default 8px body margin (the app's CSS doesn't reset it), and the classic scrollbar (15px on the Mac) that `spec/support/system.rb` forces for CI parity (#271) and a phone doesn't have.
- A real 360px viewport gives 278px: 360 − 16 (body) − 32 (page padding) − 2 (border) − 32 (panel padding). The example therefore runs in a 375px frame (a 360px viewport) and asserts 278px, with the count's room in its column (+0.28px) asserted too.
- The classic scrollbar's width is platform-dependent: 15px on the Mac, about 12px on the Linux CI runner. The first push's CI showed an interior of 281px where the Mac measured 278px (`(375 − 12) − 16 − 32 − 2 − 32`), so the example sizes the frame from the measured scrollbar (`innerWidth - documentElement.clientWidth`, a frame of 360 + scrollbar) and asserts the viewport is 360px. A spec states the phone's 360px viewport, not a frame size.
- The plan review had already caught a related slip: the aside's 640px threshold is on the page container, not the frame, so a 640px frame is a 545px container and still shows the fold; the aside needs a frame of 735px or more.
- The implementation review (Mode B), not the spec or plan reviews, found that the approved 279px could not be met as built, so the example proved a different width than the spec said; a deviation note was not enough, and spec v0.2.2 (a PATCH) reworded the criterion. A related open issue is #318: `open_in_narrow_frame` compares `scrollWidth` with `innerWidth`, so overflow hidden by a scrollbar's width goes unseen.

## What to do next time

When a spec or plan states a width ("fits in 279px at 360px"), write the chain that produces it: viewport, minus the scrollbar if the frame has one, minus the body margin, the page padding, the borders and the component's padding. Say which frame models a phone: with the Mac's 15px scrollbar a 375px frame is a 360px viewport and a 360px frame the harsher 345px case; the width differs by platform, so size the frame from the measured scrollbar (360 + scrollbar). Put breakpoints on the page container (`@container page`), not the frame: container = frame − scrollbar − 16 − page padding. Measure the chain once in headless Firefox while writing the spec, not at implementation. A criterion whose number can't be met as built is a spec update (`sdd-spec-update`), not a deviation entry.

## Signals to watch for

- A width in an acceptance criterion copied from a component document whose arithmetic isn't shown.
- A narrow-frame example at 360px whose assertion names a pixel interior, with no mention of the scrollbar or the body margin.
- A fixture with a four-digit count in a narrow column: it measures the margin, not the layout.
