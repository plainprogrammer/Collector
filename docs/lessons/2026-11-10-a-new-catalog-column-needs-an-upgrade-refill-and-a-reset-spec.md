---
date: 2026-11-10
spec: 058 (#250)
tags: [catalog, migrations, refresh, specs]
---

# Lesson: a new catalog column fills only if the refresh is made to rewrite the row, and a spec has to reset what a real upgrade has

## Context

Spec 058 added a nullable `mtg_cards.mana_value` filled from Scryfall's `cmc`. The migration is the easy part: a migrated instance has NULLs and nothing writes the column until a refresh does, and a refresh is built to skip work it has already done.

## What happened

- **A refresh skips what it already holds, twice.** A scheduled run whose bulk-file version was already applied ends `skipped`, and inside an applied run `Catalog::Refresh#queue_identity` writes an identity only when its stored `content_digest` differs. An upgraded instance with an unchanged Scryfall file would never fill the column. The identity digest includes the extension, so adding the key to the mapper changes every digest (the rewrite), and `Source#reapply?` gained a second reason ("cards exist and none has a mana value") so the skip doesn't hide it. Spec 011 had met the same problem for artwork ids.
- **The refresh spec proved nothing until it reset the digests.** A spec that refreshes, nulls the column and refreshes again fills nothing back: the stored digests already match. The examples go through `become_pre_upgrade`, which nulls `mana_value` and sets every identity's `content_digest` to an old value, which is what an upgraded instance holds. The plan's first draft missed this; the plan review caught it (round 1, blocking).
- **The mapper must not `fetch` the new key.** A real `reversible_card` (Secret Lair) has no top-level `cmc`; a `fetch` raises, the record becomes `Malformed` and the card silently leaves the catalog. Read `cmc`, else the front face's, else nil, and accept only a `Numeric` (`Float("x")` raises too).
- **`db:migrate:redo` aborts in this four-database app**; `db:migrate:redo:primary` is the reversibility check. The spec named the plain task and needed a 1.0.3.
- **A migration's class name follows the acronym inflection:** `add_mana_value_to_mtg_cards.rb` defines `AddManaValueToMTGCards`, and `AddManaValueToMtgCards` fails with a `NameError`. The spec and plan spelled it the other way.

## What to do next time

For a column that existing rows get from the catalog source, specify three things together: the mapper's reading (which cannot raise on a missing key), what makes the refresh rewrite existing rows (the digest) and what makes a scheduled run not skip it (`#reapply?`). Write the refresh specs against the state a real upgrade leaves, not against a state a refresh just made. Read a Secret Lair or other unusual layout's real object before writing the mapper's spec.

## Signals to watch for

A spec for a refresh change that passes without ever failing first; a mapper written with `fetch` or `Float()`; a plan step naming a rake task without checking it in a multi-database app.
