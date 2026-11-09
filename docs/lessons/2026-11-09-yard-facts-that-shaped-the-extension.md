---
date: 2026-11-09
spec: 054 (#103)
tags: [yard, documentation, tooling]
---

# Lesson: what YARD 0.9.45 does that decided the design of spec 054

## Context

Spec 054 adopts YARD for the Ruby API with the area docs and ADRs as pages. A spike outside the repository, the spec's plan reviews and the implementation found these behaviours; each one changed the design or caught a bug.

## What happened

- **No Markdown gem is needed.** YARD's built-in renderer is the first of its Markdown providers and is always present; `--markup markdown` rendered the area docs' tables and headings with it.
- **The pages' relative links don't work in the site.** The area docs link as `x.md` and `../adr/….md`, YARD names its pages `file.<name>.html`, and it rewrites none of them. That made the link extension (`script/yard/links.rb`) necessary.
- **A heading's id is its source text with every character that isn't a letter or digit turned into an underscore** (`A workflow run (`ci.yml`)` becomes `A_workflow_run___ci_yml__`), not GitHub's slug; a fragment link needs mapping.
- **`@see file:name.md` renders a link; `@see {file:name.md}` warns** ("should not be wrapped in {}"). A target that doesn't exist renders a dead link with **no** warning.
- **`yard doc` parses its options a second time** for its statistics pass, so a `--load` script runs twice: without `return if defined?(YardLinks)` Ruby prints "already initialized constant" lines on every run.
- **YARD builds throwaway `ExtraFileObject`s for `@see file:` links**; a hook that records every file object puts bogus pages in its map, so it checks `File.file?`.
- **`doc/` is never cleared**: a page whose source was deleted leaves its generated file behind.
- **`--fail-on-warning` reads `log.warned`**, so a `YARD::Logger.instance.warn` from an extension fails the build like YARD's own warnings.
- **`{…}` in a comment is YARD's link syntax**: three comments warned (`{name,collector}`, `{id}` twice, both `{id}` from one line), fixed with backticks.

## What to do next time

When a spec leans on a library's behaviour, spike it outside the repository before the spec is final, and write the behaviour into the spec's Problem Statement as a measured fact. Put YARD-bound code behind its own specs that run a real `yard doc` over a fixture, so a YARD release that changes one of these fails them.

## Signals to watch for

- Ruby constant-redefinition lines in `bin/yard doc` output.
- A page in `doc/` with no source file.
- A heading link that opens a page but not the heading.
