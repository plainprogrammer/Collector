---
date: 2026-11-06
spec: "037"
tags: [views, escaping, helpers, specs]
---

# Lesson: a helper that returns a sentence escapes its own quotes; put copy with literal quotes in a partial

## Context

Spec 037 (filter the collection by location) needed one empty sentence for every combination of the name and location filters, in the grid, the table and bulk mode. The plan drafted it as a helper, `no_match_message(listing)`, returning a plain String built with interpolation.

## What happened

The helper rendered the right text in a browser, but three existing request specs failed. They assert the raw body (`include(%(No cards in your collection match "zzz".))`), and `<%= helper %>` escapes the whole String, so the template's literal straight quotes became `&quot;`. Before, the sentence lived in the template (`match "<%= @listing.query %>".`), where only the query was escaped and the quotes stayed raw. The fix that avoids `html_safe` (which the security rules forbid near user content) was to move the sentence to a partial, `collections/_no_match.html.erb`, so ERB escapes only the interpolated query and location name.

## What to do next time

When copy mixes literal quotes or other HTML-significant characters with user text, put it in a partial, not a helper returning a String, unless the helper builds it with `safe_join`/`tag` over parts that are already safe. Run the existing specs for the page right after moving any copy out of a template.

## Signals to watch for

- A plan that moves template copy into a helper "to share it".
- Existing specs that assert `response.body` includes a sentence with `"`, `&`, `<` or `>` in it.
