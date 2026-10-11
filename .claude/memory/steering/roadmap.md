---
scope: roadmap
loaded-by: sdd-brainstorm, sdd-specify, sdd-plan, sdd-review
---

# North Star and Roadmap

Read `docs/north-star.md` and `docs/roadmap.md` before brainstorming or specifying anything.

- **Goal:** the maintainer's and their family's real collection on an instance they run, with a hosted service kept possible. 1.0 is an outcome (three checks in the north star), with no date.
- **Check every spec against the four hosted-door rules:** source terms allow hosting; the operator is not the user (no admin page shows or edits the items in a collection); collector choices are stored per account or user; bounded cost per account.
- **Spec rules:** one outcome, one PR (a title that needs "and" is split); spikes are separate from builds and the maintainer rules on their findings; a spec that adds collector-owned data extends the export in the same PR.
- **Order:** data safety, typed entry, locations, scanner bulk entry, comics (conditional on the research ruling; the research is deferred, ruling 26). Take the next candidate from the roadmap; don't specify ahead.
- **Don't re-ask** what the roadmap's decision log records. A new ruling goes into that log with its date.
- **Foundational ADRs:** 0016 (SQLite), 0017 (tenancy, one user per account), 0018 (catalog core), 0019 (lots). Index in `docs/adr/README.md`.
