# 0025: A lot's location is part of its identity; a location that holds copies can't be removed

## Status

Accepted (2026-10-24). Written with the plan for spec 032; the decisions were ruled by the maintainer in spec 032 decisions 1 and 3 (2026-10-23), and the maintainer's approval of the plan on 2026-10-24 accepted it. On acceptance it supersedes the open question in [ADR 0019](0019-lot-as-the-unit-of-ownership.md) and one consequence of [ADR 0023](0023-locations-make-export-format-version-2.md) (below); both stay Accepted and get a pointer on their Status lines. It took the number 0025 because 0024 was the last on `origin/main` and no other branch had written one (checked 2026-10-23); the YARD ADR that the roadmap expected to take 0025 takes the next free number.

**Date:** 2026-10-23
**Feature:** 032-lot-in-a-location

## Context

[ADR 0019](0019-lot-as-the-unit-of-ownership.md) made the lot, a quantity of one printing with a finish, a condition and a price paid, the unit of ownership, and left one question open: the design system says a physical copy is in exactly one place at a time, yet a lot is many identical copies, and four copies of one printing can sit in two binders. [Spec 029](../specs/029-manage-locations/spec.md) then gave a collector places to name ([ADR 0023](0023-locations-make-export-format-version-2.md)) with nothing in them. [Spec 032](../specs/032-lot-in-a-location/spec.md) lets a lot be in one, and this ADR records how.

Facts that shape the choice:

- The code defines "the same lot" in a few places only: `Lot.key_for` and the unique index on `[account_id, catalog_entry_id, lot_key]`, the bulk condition change (`Lot::ConditionChange`), the bulk removal and its undo (`BulkRemoval`), and the apply of an import (`CollectionImport::Apply`). Each rebuilds the key.
- SQLite treats NULLs in a unique index as distinct, so an unplaced lot can't be told apart by a nullable column in the index. The key text already carries the lot's identity.
- The export names a lot by its values and a location by its name, never by an internal id (ADR 0020), and the apply is a replace in one all-or-nothing transaction (spec 028).
- Later specs in the theme (#46 location on tiles and rows, #47 filter, #48 "Move to…", #49 and #50 decks and "Free to use") each read or change one column of a lot.
- The migration runs unattended on a self-hoster's instance, on SQLite, where adding a foreign key to `lots` by Rails' table copy would, inside a transaction, drop the table the marks, number-entry lines and scanner entries point at.

## Options considered

### Option A: The location joins the lot's identity (chosen)

A lot's identity is its printing, finish, condition, price paid and location. Copies that share all five are one lot (1 to 9,999 copies); copies that differ only in place are different lots. A lot is in one location or in none (*unplaced*), and every copy of it is there.

**Pros:** it changes only what "the same lot" means, in the places that already define it; a copy is in exactly one place by construction; every later spec in the theme is a change of one column, a filter on one column, or the merge machinery bulk "Set condition" already has; the import matches on one more value with the same outcomes; the export gains one field per lot. **Cons:** a lot no longer means "all my copies of this finish, condition and price", and moving some copies is a split; a printing in several places is several lots.

### Option B: Quantity divided among places

The lot's identity is unchanged; another table says how many of the lot's copies are in which location, the rest unplaced.

**Pros:** the lot is as it was. **Cons:** every writer of a lot's quantity (adding, editing, merging, the bulk undo, the typed and scanner undo, the import) must keep a second table consistent, the failure a collector sees only when the counts disagree; a row of the table or the export may have several places; "changed" in the import must also compare placements. Not chosen.

### Option C: A location on the lot, outside its identity

One lot per printing, finish, condition and price, with one place.

**Pros:** the merge is unchanged. **Cons:** four identical copies can't be in two binders, which fails the 1.0 test for split copies. Not chosen.

### (Option D: a row per copy)

Reverses ADR 0019: thousands of rows for a playset-heavy collection. Not considered further.

## Decision

- **A lot's identity is its printing, finish, condition, price paid and location** (Option A). The 9,999 cap is per lot, so per place. An account never holds two lots of one identity; the unique index on `[account_id, catalog_entry_id, lot_key]` keeps backing this.
- **`lots.location_id`** is a nullable integer with a foreign key to `locations` that refuses deleting a location a lot is in (`ON DELETE RESTRICT`) and an index. The migration adds one empty column, the index and the foreign key with SQLite's `ADD COLUMN … REFERENCES`, which does not copy the table, and changes no value.
- **`lot_key` carries the place.** An unplaced lot's key is the key it has today (`finish|condition|price`), so the previous release's rows need no rewrite and keep their index entry. A placed lot's key is that text, `|`, and the location's **id** (`finish|condition|price|7`). The id, not the name, so renaming a location keeps every key.
- **A location that holds copies can't be removed** (spec 032 decision 3, ruled against the draft's recommendation to unplace and merge). The refusal says how many lots and copies it holds, lists the first 100, and the collector moves them out one lot at a time until #48. Removing never unplaces, merges or deletes a lot, so a removal can't pass the cap. The database refuses it too (the foreign key). The apply of an import is the one path that removes a location that held lots, and only in the same plan that removes those lots, lots first.
- **Older files are read as unplaced** (spec 032 decision 7): a version 1 or 2 file has no place on its lots, and its lots match the account's unplaced lots of the same printing, finish, condition and price, because applying is a restore.
- **Export format version 3** adds one required field to each lot, `location` (the location's name as stored, or `null`), and the lot's identity in the format becomes six values. A missing `location` in a version 3 file is malformed; it is never read as `null`. The location is compared by comparison key, as locations are (ADR 0023). `v1` and `v2` and their copies and examples never change. The preview and the apply read versions 1 to 3.

## Consequences

- A printing in two binders is two lots with two quantities; the card page lists a row per lot with its location; the collection grid and table do not change until #46 and #47.
- Typed entry, the scanner, the quick add and the bulk actions keep working and add unplaced copies, merging into the unplaced lot of the identity, until #51 and #56 give them a choice.
- Bulk "Set condition" merges only lots of one place. A bulk removal saves each lot's location; its Undo restores a lot whose location has since been removed unplaced, merges restored rows that then share an identity, and applies the cap to the merged total.
- The key is built in four places (`Lot.key_for`, `BulkRemoval`, the raw SQL of `Lot::ConditionChange#update_alone!`, and the apply's attribute builder); a spec per place proves each carries the place.
- Deleting an account deletes its lots before its locations, which the restrict foreign key makes the order of the `has_many` declarations matter for; a spec guards it.
- The apply's write order changes to: delete the removed lots, delete and upsert the locations, read the account's locations once, build the lots' keys, upsert the lots. All still in spec 028's one write transaction, in a bounded number of statements.
- An older reader of format version 2 ignores `location` on a version 3 lot and would lose the place; the file says it is version 3, so a reader that does not know it refuses it as newer (accepted, as ADR 0023 accepted it for version 2).
- Rolling the migration back is refused while any lot is in a location, with a message that says why; with none it is clean. The rollback rebuilds `lots` outside a transaction so the tables that point at it keep their rows.
- Cost per account: one integer per lot and its index entry, and the place in a placed lot's key, about 30 bytes a placed lot; no new table, job or cache entry.
- This ADR supersedes ADR 0019's open question for locations and the sentence of ADR 0023's Consequences that said deleting a location "sets copies back to 'no location' and nothing else". ADR 0023 stays Accepted for the rest (locations make version 2, lots in them version 3), and its Decision bullet "The preview and the apply read versions 1 and 2" reads versions 1 to 3 from now on.
