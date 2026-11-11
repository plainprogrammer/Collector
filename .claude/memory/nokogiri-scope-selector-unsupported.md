---
name: nokogiri-scope-selector-unsupported
description: Nokogiri 1.19 in this repo raises on a `:scope > child` CSS selector; use `xpath("./child")` for direct children in request-spec HTML checks
metadata:
  type: reference
---

A request-spec example that reads "the direct options of a select, outside any optgroup" with `select.css(":scope > option")` raises under Nokogiri 1.19.4 (the visitor turns `:scope` into `nokogiri:scope(.)`), so the example errors and can never pass. Found by a plan review in spec 065 (#252), 2026-11-10, before any example was written.

**Why:** the plan's first draft used `:scope > option` in five places; every one would have been an error, not a red-for-the-right-reason failure.

**How to apply:** use `select.xpath("./option")` for direct children, and `html.css("select > option")` on a fragment that holds the select (a normal child combinator needs no `:scope`). Related: [[pr-screenshots-workflow]].
