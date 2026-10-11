# 0019: The lot is the unit of ownership

## Status

Accepted (recorded 2026-10-11, after the fact; decided in spec 004)

**Date:** 2026-10-11
**Feature:** 004-design-system-collection

## Context

A collection of a few thousand items is the normal case, and many of them are identical copies: a playset, a box of commons. [Spec 004](../specs/004-design-system-collection/spec.md) chose how ownership is stored (FR-6), and specs 006 and 009 built the table view, bulk editing and the scanner's adds on it. The choice lives in spec 004 and `app/models/lot.rb`, with no ADR. This one records it as the [north star](../north-star.md) is written, because locations are a 1.0 theme and press on it directly.

## Decision

A collector owns lots, not individual copies. A lot is a quantity (1 to 9,999) of one catalog entry with the same finish, condition and price paid, owned by one account. Adding or editing copies so that two lots become identical merges them, and a unique index on the account, the entry and the lot's key backs that up. Finish and condition are values that the collectible's vocabulary defines; the core doesn't interpret them.

## Consequences

- Thousands of identical copies are a handful of rows, and the collection's counts are sums of quantities.
- A single copy has no identity of its own. Nothing can be recorded about one copy of a lot without splitting the lot.
- **Open question for locations.** The design system says a physical copy is in exactly one place at a time. Four copies of one printing in two binders means either the location joins the lot's identity, so the lot splits by place, or a lot's quantity is divided among places in another table. The [roadmap](../roadmap.md)'s item 10 decides this in its own ADR.
- Anything else that later distinguishes copies (a sitting, an owner within a household) meets the same question.
- The export format (roadmap item 2) describes lots, so a change to a lot's identity is a change to the format.
