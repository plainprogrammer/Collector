---
name: css-shell-state-by-class
description: For a CSS rule that depends on whether the layout rendered something, the maintainer chose a class set by the layout over a :has() selector (spec 018, 2026-10-11)
metadata:
  type: feedback
---

When a rule depends on whether an element is present (spec 018: `c-main` gives up its tab bar clearance when a footer follows it), have the layout put a class on the shell (`<body class="c-shell c-shell--footed">`, rule `.c-shell--footed > .c-main`) and hang the rule on that. Don't use `:has()`.

**What was said:** on 2026-10-11 the maintainer approved spec 018's plan with one change. As relayed by the Orca coordinator: "for the phone layout the maintainer prefers a body class over the :has() selector, and wants the footer to scroll with the page content in the same scroll area that the fixed tab bar sits over, its last line stopping above the bar." The plan had flagged `:has()` as the first use of that selector in the stylesheets and offered a body class as the alternative. No reason was given beyond the preference.

**Why (my interpretation, not the maintainer's words):** no rule then depends on a newer browser, and the state is visible in the markup, where a request spec can assert it.

**How to apply:** offer the class as the plan's choice, not as the alternative. A new class on `<body>` changes every page's shell: search the specs for exact class-string assertions before running them (`spec/requests/design_system_spec.rb` expected the bare `class="c-shell"` and failed only in the whole-suite run). Assert the class both ways in a request spec, present with the element and absent without it. Related: [[headless-firefox-narrow-frame]].
