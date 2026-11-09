---
date: 2026-11-09
spec: 055 (#77)
tags: [plans, review, css, guards]
---

# Lesson: plan review caught a layout change and a guard word that no example would fail on

## Context

Spec 055's plan wrapped the start button in a new `div` and added comments to files under the core-boundary guard.

## What happened

Two defects were found by a reviewer reading, before any code ran:

- Moving the `c-operation__start` class from the start form to a wrapper `div` would have changed every panel's single-button layout, because the form had been the flex container. The plan gained `.c-operation__start form { display:flex; }`.
- A comment containing the word "art" in `catalog/operation.rb` would have failed `spec/admin_catalog_core_spec.rb`, whose regex scans those files for "art" as a word. The reviewer found it by reading the guard's regex; the plan's own run list did not include the guard until the reviewer added it.

## What to do next time

When a plan edits markup that other components share, name what the old element contributed (display, alignment) and keep it. When a plan adds comments to files a word-scan guard covers, read the guard's regex and add the guard to that task's run.

## Signals to watch for

- A class moving from one element to another in a view.
- New comments in a file listed by a `*_core_spec.rb` guard.
