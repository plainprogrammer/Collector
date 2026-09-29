# Collector Foundation

> Loaded every session. To amend, follow the Amendment Process below.

## Mission
Collector is a self-hostable, multi-tenant web application for tracking collectibles, starting with Magic: The Gathering cards.

## Principles
1. **Easy to self-host, painless to upgrade.** Anyone can stand up an instance with minimal setup and no required proprietary services. Every release upgrades in place: migrations are reversible or forward-safe, never lose data, and breaking changes ship with a documented upgrade path.
2. **Users own their data.** Collections are fully exportable and importable in open, documented formats. Nothing about a user's data is locked into this app or any third party.
3. **Collectible-agnostic core.** The core domain (collections, items, conditions, quantities, valuations) is independent of any single collectible type. MTG-specific behavior lives behind a clear extension boundary so new collectible types can be added without rewriting the core.
4. **Resilient to upstream sources.** External data sources (card databases, price feeds) are treated as unreliable: their data is cached locally, validated before persistence, and a source change or outage degrades gracefully without corrupting user collection data.
5. **Tested before merge.** Nothing merges without a passing test suite, and new or changed behavior ships with tests that cover it.

## Operational Context
Steering files in `.claude/memory/steering/` carry project-specific operational context
(tech stack, test strategy, conventions, team practices). Each file's `loaded-by`
frontmatter lists which skills silently incorporate it during that skill's session.
Edit steering files freely — they are not subject to the amendment process.

## Amendment Process
Changing a principle requires: (1) documenting the proposed change and its rationale, (2) explicit approval from the project maintainer(s), and (3) a backwards-compatibility check against existing specs, code, and self-hosted deployments before adoption.
