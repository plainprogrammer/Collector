---
name: turbo-stream-string-is-html-safe
description: turbo_stream.update/replace with a plain String marks it html_safe; escape any text holding a card or place name, or use a partial
metadata:
  type: feedback
---

`turbo_stream.update(target, "some text")` (and `replace`, `append` …) passes a String template through `.html_safe` inside turbo-rails' `turbo_stream_action_tag`, so the string is inserted as HTML, not text. Spec 082's answers write sentences such as "Added Lightning Bolt MOM · 123, foil" and the list title "This sitting: 2 cards, in Blue binder" straight into stream targets; a location named `<b>bold</b>` would have rendered as markup.

**Why:** found while planning spec 082 (2026-11-13); the plan review confirmed it and `spec/requests/scanner/sitting_entries_spec.rb` pins the escaping with a place named `<b>bold</b>`.

**How to apply:** in a controller or concern, wrap any text that can contain a user's or the catalog's words with `ERB::Util.html_escape(...)` before giving it to a stream, or render a partial (`partial:` with locals escapes as a view does). Plan and code reviews check every `turbo_stream.*(target, <string>)` call. An empty string (`""`) is safe. Related: [[plan-reviews-run-the-code]].
