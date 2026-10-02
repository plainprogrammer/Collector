---
name: check-corpus-availability
description: Before specifying a measurement on physical items (cards, devices), confirm they'll still be available when the run happens
metadata:
  type: feedback
---

When a spec or plan depends on re-measuring the same physical items, such as "re-capture the same 50 cards", ask whether those items will still be available at measurement time. Record the answer in the spec's decisions.

**Why:** spec 007 v1 was built around re-capturing Phase 0's 50 cards live. At the measured-run checkpoint (2026-10-01), the maintainer said the cards had been borrowed from two collections and returned. That forced a MAJOR spec update (v2.0.0) to a photo replay, and the live question was answered only on biased tuning cards.

**How to apply:** at `sdd-specify` time, ask where the physical items come from and whether they'll be at hand for the run. If they might not be, design the measurement around items the maintainer owns, or plan a fallback (a photo replay, a new corpus) up front. Related: [[card-scanner-direction]], [[work-ahead-of-human-checkpoints]].
