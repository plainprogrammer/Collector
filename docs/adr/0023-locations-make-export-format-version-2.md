# 0023: Locations make the export format version 2; putting lots in them makes version 3

## Status

Proposed (2026-10-21). Written with the plan for spec 029; the decision was ruled by the maintainer in spec 029 decision 1 (2026-10-20). The maintainer's approval of the plan accepts it. It supersedes one consequence of [ADR 0020](0020-export-format.md) (below); ADR 0020 stays Accepted and gets a pointer on its Status line.

**Date:** 2026-10-21
**Feature:** 029-manage-locations

## Context

[ADR 0020](0020-export-format.md) and the format document's "Versions" section raise the version for "a new field that holds data the collector owns", because a reader of the earlier version ignores fields it doesn't know and would drop the data without a word. ADR 0020's Consequences expected that "the spec that puts a lot in a location raises the format to version 2". Spec 029 comes first: it adds the places themselves (a binder, a box) and nothing else, so a collector's set of locations exists before any lot can be in one (issue #45, which needs its own ADR on how a lot sits in more than one place, [ADR 0019](0019-lot-as-the-unit-of-ownership.md)).

The set of locations is data the collector owns, so by ADR 0020's own rule it raises the version when it is added. Facts that shape the choice:

- `main` publishes `edge` images, so a collector can hold a file written by this change the day it merges. The format's rule is that the meaning of a released version never changes, and the format cannot know whether a file counts as released.
- A file carries no internal id, so a location in a file is its name; #45 will name a location from a lot by that name.
- The export always writes the newest version (spec 029 decision 2), so once it writes version 2 the preview and the apply (specs 025, 028) must read it, or a collector's own file would be refused as newer.

## Options considered

### Option A: Locations are version 2; lots in locations are version 3 (chosen)

**Pros:** each released shape is final; a version-1 file stays readable and its meaning never changes; the preview and apply read versions 1 and 2, each against its own schema. **Cons:** it spends a version number on a field that holds only names, and the format document, schema, examples and Coverage tables all change with this spec.

### Option B: Ship version 2 here and let #45 change version 2 before any release carries it

**Pros:** saves a version number. **Cons:** fragile: a collector can hold a version 2 file from `edge` before #45 merges, and the rule that a released version never changes would then be broken or unenforceable. Not chosen.

### Option C: Write version 1 for an account without locations, version 2 otherwise

**Pros:** older instances can read the exports of accounts that don't use locations. **Cons:** two shapes to read and test, and a file whose version depends on its content. The maintainer ruled (spec 029 decision 2) that the export always writes the newest version.

## Decision

- **Version 2** adds one required top-level field, `locations`: a list (at most 500 elements, possibly empty) of objects with one field, `name`. Lots are unchanged. `v2.schema.json` states it, and `v1.schema.json` stays as it was.
- A location's identity in a file is the **comparison key** of its name: the Unicode full case folding of the name after NFC normalisation. A file never holds two locations with the same key (`duplicate_location`, a rule a schema can't state). A name is 1 to 60 code points with no Cc or Cf character and no White_Space other than single spaces between words.
- A reader **normalises each name on read** (NFC, then trim and collapse White_Space), so a name in another normalisation form is well-formed and is read as its NFC spelling. "The same collection" compares location names exactly as written.
- The preview and the apply **read versions 1 and 2**. A version 2 file replaces the collector's locations by comparison key (added, renamed, unchanged, removed); a version 1 file leaves them alone, because the format must not read a missing field as "none".
- **Putting lots in locations (#45) raises the format to version 3.** Removing a location never removes copies (spec 029 decision 3).
- This ADR supersedes the part of ADR 0020's Consequences that says the spec that puts a lot in a location raises the format to version 2. Spec 017 decision 14 and the roadmap's item 10 said the same; spec 029's Supersedes table records them, and the roadmap file is edited in the implementation pull request.

## Consequences

- An instance that reads only version 1 can't read exports written from now on; the file says it is newer, as the format requires (accepted by the maintainer).
- `ExportFormat::Rules` reads each version against its own schema, and the app keeps a byte-identical copy of every schema ([ADR 0021](0021-export-format-rules-in-the-app.md)). The Coverage tables list the `locations` table and its columns, and the suite fails until they do.
- The model and `v2.schema.json` agree on what a well-formed name is; a spec tries every Unicode scalar value to prove it. A rare name whose NFC form is longer than 60 code points (U+0344 decomposes to two) is refused by the preview and the apply as a whole; that limit is accepted.
- A collector who restores a version 2 file onto an account gets the file's locations, with the ids of kept locations unchanged, so anything that later points at a location stays pointed.
- Version 3 will need its own schema, examples and ADR-sized decision about how a lot is divided among places; this ADR binds only that deleting a location sets copies back to "no location" and nothing else.
- Self-hosters get one new migration (the `locations` table), safe to run unattended from any prior version.
