---
scope: team-practices
loaded-by: sdd-plan, sdd-review, using-git
---

# Team Practices

## Branching
See `docs/git-convention.md`.

## Code Review
[Edit to match reality — e.g. maintainer approval required before merge to main]

## Release Process
Tag `main` with an annotated `vX.Y.Z` tag; CI publishes the image (`docs/releasing.md`). Migrations are safe to run from any prior version; breaking changes ship with upgrade notes in the README.
