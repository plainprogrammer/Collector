---
date: 2026-10-12
spec: "020"
tags: [specification, documents, tests, review]
---

# Lesson: Search spec/ for examples that pin a document before specifying a change to it

## Context

Spec 020 (issue #63) began as a rewrite of the README's stale first paragraph and grew, by the maintainer's choice, into a check of every claim in the file.

## What happened

The first draft of the spec said the result would be "checked by hand and recorded, with no automated test", and gave as its reason that a test of the README's wording would fail on every honest edit. I recommended that to the maintainer as the brittle option to avoid. The first spec review then found `spec/readme_spec.rb`: eight examples that already pinned README phrases and section order, added by the plans of six earlier specs. The spec's reasoning described, as a hypothetical, a file the repository already had, and a correction to any pinned phrase would have failed `bin/ci` with the spec silent on whether the expectation could be edited.

The maintainer's answer was to remove that file, and then every other example that checks a prose document (decision 7). Two more review passes were needed to carry that through.

## What to do next time

Before writing a spec that changes a document, a configuration file or any file the app doesn't load, search `spec/` for examples that read it (`grep -rnE '<file name>|docs/' spec --include='*.rb'`), and state in the spec what happens to each. Do it before recommending a verification approach to the maintainer.

## Signals to watch for

- A spec that says "no automated test" for a file nobody has searched the suite for.
- A rationale phrased as a hypothetical ("a test of X would be brittle").
- A repository with file-shape specs at the top of `spec/` (`*_files_spec.rb`, `project_config_spec.rb`).
