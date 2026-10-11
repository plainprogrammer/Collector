# 0017: Row-level tenancy, one user per account

## Status

Accepted (recorded 2026-10-11, after the fact; decided in spec 004)

**Date:** 2026-10-11
**Feature:** 004-design-system-collection

## Context

Collector is multi-tenant: several collectors share one instance. [Spec 004](../specs/004-design-system-collection/spec.md) added accounts and sign-in, and listed "multiple users sharing one account, or seeing another collector's items" as a non-goal. The tenancy rule was recorded in `.claude/rules/multi-tenancy.md`, with no ADR. This one records it as the [north star](../north-star.md) is written, because the maintainer ruled on 2026-10-11 that personal and household collections side by side come after 1.0, with no early decision on the ownership model.

## Decision

Every collector-owned table carries `account_id`. A request resolves `Current.account` once and fails closed when there is none, and every query on collector-owned data is scoped through it. Jobs and broadcasts must carry and restore the account; this is a rule so far, since no account-scoped job or broadcast exists yet. Catalog data is global and has no `account_id`.

An account has exactly one user (`users.account_id` has a unique index), and a user sees only their own account's data.

## Consequences

- Isolation is one rule that a request spec can prove per resource: another account's record returns 404.
- The admin flag is on the user and governs the instance's operations. It gives no view of the items in another account's collection. The admin users page does show each account's copy count, and deleting a user deletes their collection (spec 004 AC-5.1, AC-5.4). The north star's "the operator is not the user" rule allows both as account management, and forbids an admin page from showing or editing the items themselves.
- Family members start on separate private accounts. No collector can see or edit another's collection.
- Personal and household collections side by side will supersede the one-user half of this decision. The export format will need a version bump and the schema will need migrations then. The maintainer accepted that cost on 2026-10-11 in preference to deciding the model before the export format is designed.
- Until then, specs shouldn't assume that an account will always have one user where it costs nothing to avoid it, but they aren't required to design for more.
