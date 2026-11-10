---
name: design-system-guard-and-rubocop-traps
description: Adding CSS to additions.css or a browser spec for it trips spec/design_system_files_spec.rb's block counts and three RuboCop cops; the rules to follow
metadata:
  type: reference
---

`spec/design_system_files_spec.rb` finds a block of `app/assets/stylesheets/collector/additions.css` by its heading comment and counts the rules up to the next heading: "spec 019" appears once, "spec 021" once, the image-fit block has no "font", the untabbed-shell block has 3 rules. A rule added without its own heading is counted in the block above it.

**Why:** found while adding four blocks in spec 057 (grouped select, location cap, three-stat strip, header logo swap), each of which needed its own `(spec NNN …)` heading.

**How to apply:** give every new CSS block its own `/* ---------- Name (spec NNN …) ---------- */` heading, never reuse the text "spec 019" or "spec 021" in a comment, and run `bin/rspec spec/design_system_files_spec.rb` after any `additions.css` edit. In a new system or unit spec, RuboCop flags `RSpec/LeakyConstantDeclaration` (no constants in a `describe`; use methods), `RSpec/DescribeClass` (a string `describe` of a file, not a class, needs an `Exclude` line with its reason in `.rubocop.yml`, as `spec/design_system_tokens_spec.rb` has) and `RSpec/ExampleLength` (15 lines; move the measure into a helper). For a width check use `open_in_narrow_frame` (an iframe, since the window can't go below 500px) and remember classic scrollbars take 15px: a 640px frame has a 625px layout width. See [[headless-firefox-narrow-frame]] and [[design-system-owned-in-code]].

**A component with no view yet (spec 060, 2026-11-10):** to prove CSS before any view exists, add the component's markup to a real page inside a wrapper `div` whose class is the container (`c-page` or `c-collection`) and whose inline width the example sets; the nearest named container answers, so no window resizing is needed above or below 640px. Strip the host page first (a `blank_host` helper: `main.className = "c-main c-page"` and `replaceChildren()`): the Locations page's `main` carries `c-locations`, whose rules give every `.c-btn` and `.c-input` a 44px floor and would pass a size example without the new rule. Scope every selector to the probe's own id. A `type: :system` spec needs no `RSpec/DescribeClass` exclusion (unlike a unit spec of a file). Append new blocks at the END of `additions.css`: an earlier same-specificity rule later in the file (here `.c-choices` at line 195) would beat a block placed before it. Related: [[headless-firefox-narrow-frame]].

