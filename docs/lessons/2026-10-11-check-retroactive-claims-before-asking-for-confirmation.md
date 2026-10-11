---
date: 2026-10-11
spec: "none (north star, roadmap, ADRs 0016–0019)"
tags: [adrs, planning, reviews, maintainer-rulings]
---

# Lesson: Check retroactive claims before asking for confirmation

## Context

The north-star interview ended with four retroactive ADRs (0016–0019) for decisions made in specs 001, 002 and 004. Each ADR's decision and consequences were presented to the maintainer, who confirmed all four as accurate. The interview also adopted four "hosted-door" rules that every future spec is checked against.

## What happened

A read-only review then checked the written set against the code, and found two of the four confirmed statements wrong:

- ADR 0017 said the admin flag gives no view of another account's collection. The admin users page shows each account's copy count, and deleting a user deletes their collection (spec 004 AC-5.1, AC-5.4).
- ADR 0019 listed a language as something that could distinguish copies within a lot. Language is part of the catalog entry a lot points at.

ADR 0018's "core code never names a collectible" was also broader than what the repository enforces.

The same gap showed in the rules. "The operator is not the user" was adopted as binding, worded as "an admin page or task shows or changes a collector's data", before anyone checked it against shipped behaviour. Spec 004's admin user management already broke it, and it took a second ruling to narrow it to the items in a collection.

The maintainer's confirmations were given in good faith on statements that read as plausible. A confirmation records what the maintainer intends; it doesn't verify a claim about the code.

## What to do next time

Before asking the maintainer to confirm a statement about existing behaviour, check it against the code and the spec that decided it, and cite what was checked. Before proposing a rule for future work, check it against what already ships, and present any existing breach with the rule so the wording is ruled on once. Keep the read-only review of the written set as well: it found what the drafting pass missed.

## Signals to watch for

- "Never", "no" or "only" in a retroactive ADR's decision or consequences.
- A list of examples written from memory of the model ("a language, a sitting, an owner").
- A new rule whose subject already has shipped code (admin pages, settings, sources).
- A confirmation request that cites no file, schema line or acceptance criterion.
