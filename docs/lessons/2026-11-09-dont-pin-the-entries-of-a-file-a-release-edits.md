---
date: 2026-11-09
spec: 049
tags: [testing, upgrade-proof, release]
---

# Lesson: a spec must not pin the entries of a file the release procedure edits

## Context

Spec 049 lists two dropped columns in `script/upgrade/expected_changes.yml`, and the shipped example "ships empty and valid" failed once the file had entries.

## What happened

The plan's replacement asserted the exact two entries. At Gate B the coordinator pointed out that `docs/releasing.md` step 7 deletes the entries after the next tag, so the pin would have turned red at the release.

## What to do next time

- For a file the release procedure edits, assert that it is valid (no errors, no retired entries, every entry names a migration of the working tree), not what it holds.
- If an entry must be pinned, put the example beside the entry, in the spec that adds it, so the release step can delete both.
