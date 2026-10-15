---
date: 2026-10-14
spec: "022"
tags: [design-system, specs, briefs]
---

# Lesson: Check the design system before taking a brief's UI placement

## Context

The brief for #38 listed "a link from the collection page" under ownership. The first spec draft put an "Export" button in the collection page's head, beside "Scan cards" and "Add items".

## What happened

While looking for a download icon, a search of `docs/design-system/` turned up the Navigation rule: "Profile, settings and import/export live in the avatar menu (wide) or More (phone), never in the main navigation." `AppHeader.md` and the `CollectionPagePhone` preview say the same. The spec was revised to put the link in the account menu plus More, and the conflict was put to the maintainer as a ruling with a recommendation. The maintainer chose the design system. The account menu is on the collection page, so the brief's intent was still met.

## What to do next time

Before specifying where a new control goes, search `docs/design-system/README.md` (Navigation, Layout) and the component docs and previews for the feature's name (export, import, settings, profile). When a brief's placement conflicts with them, ask for a ruling and recommend the design system's placement; don't silently follow either. Remember that More must mirror the account menu (`MorePage.md`), and that `spec/requests/admin/navigation_spec.rb` compares both link lists exactly.

## Signals to watch for

- A brief that names a page for a control ("a link from X", "a button on Y").
- Account-level actions: export, import, settings, profile, sign-out.
- A new item in the account menu without a matching row on More.
