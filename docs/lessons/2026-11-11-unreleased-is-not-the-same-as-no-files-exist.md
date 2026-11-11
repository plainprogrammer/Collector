---
date: 2026-11-11
spec: 068 (#254)
tags: [export-format, versions, edge, plans]
---

# Lesson: "no release has shipped it" is not "no file of it exists": the edge images write the format

## Context

Spec 068 adds proxies to the export. The issue design said: extend version 4 if no release has shipped it, otherwise raise the version. The latest tag is `v0.2.1`, whose tree has no `v4.schema.json`, so the spec extended version 4. Its first drafts made the new `proxies` list optional, so a version 4 file without it was still read.

## What happened

- The spec review found that CI publishes `edge` and `sha-*` images from every push to `main`. An instance running one of those already writes version 4 files, without `proxies`. "Unreleased" was true of the tags and not of the files.
- That made the decision a real choice with a cost on each side: a required list refuses an edge-written file as not well-formed; an optional list reads it as an older file and leaves proxies alone, and an older edge instance reading a file with proxies drops them silently. The maintainer ruled it required: a version 4 file without `proxies` is refused as any schema-invalid file is, and edge-written files are not supported.
- The cost showed up later, in the plan reviews: a required list means every version 4 file built by hand is refused until it carries `proxies`. The reviews found 29 example files, `import_file_v4`, two local `file_v4` helpers (`collection_import_spec`, `collection_import_previews_spec`), the round-trip spec's `as_current_version` and the deck timing spec, none of which the first plan named.

## What to do next time

When a spec extends or tightens a format version because it is unreleased, (1) check what the edge channel publishes (`docs/architecture/release-and-deploy.md`, `docs/releasing.md`) and write the edge consequence into the decision and ask the maintainer for the ruling at the spec gate, not in review; and (2) before the first plan review, grep `spec/` and `docs/export-format/examples/` for every file, helper and fixture that builds that version (`grep -rn "format_version" spec docs/export-format`) and list each one in the plan task that makes the field required.

## Signals to watch for

- A decision that says "no release has shipped version N" and so changes version N in place.
- A new required field in an export or import format, or a new required list.
- A plan that adds a field to the format and names only the schema, the document and one spec.
