---
date: 2026-11-10
spec: 060 (#249)
tags: [sdd, rulings, documents, previews]
---

# Lesson: a maintainer's ruling drifted in the first draft of the documents, and only a read against the ruling caught it

## Context

Spec 060's decision 9 was ruled by the maintainer from a phone mock-up: the zone table's phone line carries the Proxy tag and the legality marker under the card's name. The spec's own AC-3.8 and the plan's markup drew one legality marker beside the name at every width, a simplification made while writing the criteria.

## What happened

- The tests, the CSS and the first documents all agreed with AC-3.8, so every example passed. The drift showed only when the documents batch reported "the marker follows the name at every width; decision 9 says under the name on a phone", and the supervisor read the ruling again.
- The fix was small (spec 1.0.3: the marker is written twice, as the set already is, beside the name from 640px and in the `c-table__sub` line below it), but it touched the spec, the plan, one builder and one document, and it had to be recorded as a patch the maintainer had not seen.

## What to do next time

When a spec criterion paraphrases a ruling, quote the ruling in the criterion or its decision line, and after each batch read the ruling list against what the batch produced (documents, previews, builders), not the criteria alone: criteria can drift from the rulings and a green suite proves only the criteria. Ask each implementer to report every place the output differs from the ruling or the plan, as the documents batch did here.

## Signals to watch for

- A criterion shorter than the ruling it came from.
- Tests, CSS and documents that all agree with one another and were all written from the same paraphrase.
- A ruling made from a mock-up at one width and a criterion written for all widths.
