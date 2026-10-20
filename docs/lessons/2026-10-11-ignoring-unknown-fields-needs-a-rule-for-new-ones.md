---
date: 2026-10-11
spec: "017"
tags: [spec-writing, versioning, data-portability]
---

# Lesson: "Readers ignore unknown fields" needs a rule for which new fields are free

## Context

Spec 017 set the export format's versioning rule. The outline the maintainer agreed said that the version rises when an older reader would misread a file, that new optional fields don't raise it, and that readers ignore fields they don't know.

## What happened

Each of the three reads as sensible, and together they lose data. Locations are the next extension. Had they arrived as a new optional field, a version-1 reader would have ignored it, restored the collection without any location, and reported the same collection. Nothing would have been misread; something would have been dropped without a word. The Mode A review found it by walking the next known extension through the rule.

The maintainer ruled for the narrower rule: a new field that holds data the collector owns raises the version, and only information-only fields are free. A field that a reader doesn't know, at a version it does know, is then always safe to ignore. [ADR 0020](../adr/0020-export-format.md) records both options under "What raises the version".

## What to do next time

When a format lets readers ignore unknown fields, state which new fields may be added without a version change, and test the rule against the next extension already on the roadmap. Ask what an old reader does with a new file, and whether the user would notice.

## Signals to watch for

- "Additive changes are backwards compatible" in a format that is also the user's backup.
- A versioning rule phrased only as "misread", with no word about loss.
- A comparison rule ("the same collection") that ignores unknown fields, beside a rule that lets data arrive in them.
