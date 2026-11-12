---
date: 2026-11-11
spec: 067 (#302)
tags: [testing, system-specs, rack_test, accessibility]
---

# Lesson: a no-script system example runs under `rack_test` only if `driven_by` comes before the sign-in, and the global after hook must not resize a window that isn't there

## Context

Spec 067 AC-5.1 and AC-3.1 ask for the deck shortcut to work in a browser without scripting. The project's system specs all run in headless Firefox, so the no-script example had to switch the group to `rack_test`.

## What happened

- `driven_by :rack_test` has to be declared in a `before` that runs ahead of the `let!(:user) { system_sign_in_as(...) }` that signs in, so the sign-in goes through `rack_test` too (`system_sign_in_as` is a plain form, so it works there). The global `config.before(:each, type: :system)` in `spec/support/system.rb` picks Firefox first and the group's own `before` then wins.
- The first run failed in the after hook, not in the example: `spec/support/system.rb` called `page.current_window.resize_to` after every system example, and `rack_test` has no window (`Capybara::NotSupportedByDriverError`). The hook now skips the resize unless `page.driver` is a `Capybara::Selenium::Driver`.
- RuboCop's `RSpec/MultipleDescribes` rejected a second top-level `RSpec.describe` for the no-script group, so the file has one describe with a "with scripting" and a "without scripting" context, and a `before` with `driven_by` in one context only.
- The example asserts `page.driver` is a `Capybara::RackTest::Driver`: without that line a later change to the support hook could put the example back in a browser that runs script, and it would still pass while proving nothing.

## What to do next time

For a "works without scripting" criterion, write the example in its own context with `before { driven_by :rack_test }` declared before the `let!` that signs in, assert the driver, and run the whole scenario in it (see the next lesson on why not part of it). Don't copy the Firefox examples' viewport, focus-ring or narrow-frame checks into it: `rack_test` runs no layout and no script.

Spec 070 (#257) adds one more `rack_test` fact: a menu drawn as a closed `<details>` hides its links from `rack_test`, which can't open it (a no-script browser opens it natively). The example asserts the row's `details > summary[aria-label=…]` exists, then clicks the link with `visible: :all`, scoped to the row's section (a bare `within("details.c-menu")` is ambiguous when the page has several menus). The menu is closed again after every redirect, so each click needs the same treatment.

## Signals to watch for

- A new system example that needs no script but runs in Firefox, so nothing shows that it works without script.
- A `Capybara::NotSupportedByDriverError` from a global hook (resize, screenshot, window handles) the first time an example uses another driver.
- A second top-level `RSpec.describe` in a system spec file added only to change the driver.
