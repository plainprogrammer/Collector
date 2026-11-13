---
date: 2026-11-13
spec: 082 (#344), with 084 (#374)
tags: [parallel-work, merges, ci, specs]
---

# Lesson: the branch that merges second owns the first branch's page lists

## Context

Specs 082 and 084 ran in parallel and both touched the footer. The coordinator's plan let them meet on one file: the shared partial `layouts/_notice_lines.html.erb`, with no locals, created by both under the same name so the merge was a take-theirs on that file. Spec 084 merged first; spec 082 removed the scanner's footer (its small print moved into the sheets' foot).

## What happened

The merge itself went as planned: one add/add conflict on the partial, taken from `main`, and textual conflicts in the layout and the documents. But spec 084 had also added `spec/requests/licence_line_spec.rb`, whose first example walks a list of pages and expects a footer on each, the scanner among them. Nothing conflicted there, the targeted runs after the merge did not include it, and only the full `bin/ci` found it (1 failure in 4,764). The coordinator then asked that the scanner keep an example of its own (the licence line in each sheet's foot and the noscript notice) rather than leave the list.

## What to do next time

- After merging a sibling spec, list the spec files it added or changed (`git diff --name-only <merge-base>..origin/main -- spec`) and grep them for the routes and selectors your branch changed (`scanner_path`, `footer.c-footer`), before asking for a full CI slot.
- When your branch makes an exception to a sibling spec's rule ("every page has a footer"), replace its example for your page with one that proves how your page meets the rule, and record the exception in both specs' index rows.

## Signals to watch for

- A sibling spec whose rule says "every page" while your spec removes or moves that part on one page.
- A merge with no conflict in a spec file that iterates a list of paths.
