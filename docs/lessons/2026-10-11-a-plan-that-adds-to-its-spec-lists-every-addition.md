---
date: 2026-10-11
spec: "017"
tags: [planning, review, spec-writing]
---

# Lesson: A plan that adds to its spec lists every addition, and patches every sentence

## Context

Spec 017 defined the export format and left the field names and the schema to the plan. Writing the schema and the format document meant deciding things the approved spec hadn't said.

## What happened

The plan listed four additions to the spec for the maintainer to rule on. It had made two more without noticing: a file may not start with a byte order mark, and the collection view is required. Both came from the schema and the parser, not from a decision anyone remembered making. The plan reviewer found them only because its brief asked for "every unlisted deviation".

The plan's Phase 0 then wrote the approved additions into the spec by replacing exact sentences. Four other sentences that spoke of the same things stayed as they were: FR-3 still named two required profile fields, FR-9's lead still named two marks where there were now three, Open Questions still counted decisions to 19, and the glossary's "resolvable" didn't allow a `null` finish. The implementation review found them, and the spec went to 1.2.1.

## What to do next time

- Before listing a plan's additions, walk the artefact's rules against the spec's error table row by row: every `required`, every pattern, every case the parser rejects. Each one is in the spec, or it is an addition.
- Ask the plan reviewer for unlisted deviations in so many words.
- When a phase patches the spec, grep the whole spec for each concept the patch touches, and patch every sentence that mentions it, not only the one the change was written against.

## Signals to watch for

- A schema or validator stricter than the prose it implements.
- A spec patch described as "replace this sentence with that one".
- A count in the spec ("two marks", "decisions 15 to 19") near something a patch adds to.
