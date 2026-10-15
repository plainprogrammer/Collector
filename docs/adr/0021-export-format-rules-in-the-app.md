# 0021: The app checks export files with `json_schemer` and its own copy of the schema

## Status

Accepted (2026-10-15; the maintainer ruled on it with spec 025's decisions 5 and 12).

**Date:** 2026-10-15
**Feature:** 025-import-preview

## Context

Spec 025 builds the first reader of the export format: a collector uploads a file and sees what applying it would do. The reader has to decide whether the file is well-formed, which the format defines as passing [`v1.schema.json`](../export-format/v1.schema.json) plus five rules a schema can't state ([ADR 0020](0020-export-format.md)).

Until now only the test suite applied those rules:

- `spec/support/export_format_rules.rb` holds them, and checks the schema with `json_schemer`, a gem in the `:test` group, loaded with `require: false`.
- The schema lives in `docs/export-format/`. `.dockerignore` keeps `docs/` out of the published image.
- ADR 0020's consequences say an import that validates files in the running app "has to decide where its copy of the rules lives".

Measured while specifying (development machine): checking a 50,000-lot file against the whole schema with `json_schemer` takes 6 to 8.4 seconds. Parsing it takes about 0.16 seconds.

## Options considered

### Option A: `json_schemer` in the app, with an in-app copy of the schema (chosen)

`json_schemer` moves to the app's bundle. A copy of `v1.schema.json` sits beside the app's rules, and the suite checks that the copy is byte-identical to the one in `docs/`. The five further rules move from the suite's support file into an app model, which the support file then calls.

**Pros:**
- One statement of the schema, checked by the same library in the app and in the suite. The examples' expected problems (`examples/problems.json`) test the app's code directly.
- No hand-written copy of what the schema says, so nothing can drift.

**Cons:**
- `json_schemer` and its dependencies (hana, regexp_parser, simpleidn) join the app's runtime bundle. (The image already installed them, since it leaves out only the development group.) bundler-audit covers them.
- It is slow on large files: about 7 seconds at 50,000 lots.
- Two copies of the schema file exist. A spec keeps them identical.

### Option B: Hand-written checks, no gem at run time

The app checks each rule in Ruby, and the suite proves that it agrees with the schema on every example and variant.

**Pros:**
- Fast (well under a second at 50,000 lots).
- No new gem in the image.

**Cons:**
- A second statement of the rules, kept equal to the schema only by the examples the suite happens to try.

### Option C: Ship `docs/export-format/` in the image

The app reads the schema from `docs/` at run time, with `json_schemer` as in Option A.

**Pros:**
- One schema file.

**Cons:**
- It couples a documentation folder to the running app and changes `.dockerignore`'s rule that `docs/` stays out of the public image.

## Decision

**Option A.** The rules live in `ExportFormat::Rules` (`app/models/export_format/rules.rb`). It reads `app/models/export_format/v1.schema.json`, a byte-identical copy of `docs/export-format/v1.schema.json`. `json_schemer` is in the default group of the `Gemfile`, still `require: false` and required by `ExportFormat::Rules`. `spec/support/export_format_rules.rb` delegates well-formedness and lot identity to it.

The time the schema check takes is accepted: the maintainer set the import preview's bar at 50,000 rows in under 30 seconds (spec 025 decision 12) rather than hand-write the lot checks.

**Amendment (2026-10-15, the maintainer's ruling under spec 025 decision 13).** Checked in one call, `json_schemer` holds a tree of results for the whole file: on a 50,000-lot file that grew the process by about 850 MB to 1 GB, against a bar of 500 MB. So `ExportFormat::Rules` checks the file with its lots left empty, then each lot on its own against the schema's `$defs/lot` (`ExportFormat::Rules.lot_schemer`), with each lot's pointers prefixed `/lots/<i>`, and maps a lot's errors to problems before it checks the next. It is still the one schema, checked by `json_schemer`; the suite proves that this finds the same problems, in the same order, as a check of the whole file.

## Consequences

- The schema's copy and its original change together. A new format version adds `v<N>.schema.json` in both places, and the identity spec fails until it does.
- The well-formedness rules are now app code, so they are covered by the app's own specs as well as the examples.
- No result tree for the whole file is held: the schema check's memory is that of one lot at a time (amendment above). The schema has to keep the lot as `$defs/lot`, the target of `properties.lots.items`; a later version that changes that shape changes this check too.
- A very large file takes seconds to check. The upload limit of 32 MB (spec 025 decision 6) bounds how long.
- Option B stays available: if the bar is ever missed, hand-written lot checks proved against the schema can replace the per-lot schema pass, through an ADR that supersedes this one.
