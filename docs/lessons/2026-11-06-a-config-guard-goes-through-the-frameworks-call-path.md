---
date: 2026-11-06
spec: "044"
tags: [rails, configuration, testing, spec-review]
---

# Lesson: A guard on a framework setting goes through the framework's own call path

## Context

Spec 044 set `config.action_view.field_error_proc` app-wide so no refused form renders Rails' `field_with_errors` wrapper, and wanted one guard example that covers forms added later, before their own specs exist.

## What happened

The draft criterion (AC-1.1) called `ActionView::Base.field_error_proc` directly and expected the tag back. The round 1 spec review showed it proved nothing: Rails applies the key in the ActionView railtie (`on_load`, `send "#{k}="`) and calls the proc with `instance_exec` only when an attribute has errors. A key Rails never applied, or a later override, would still pass a direct call of the app's own lambda, and the Error Scenarios row claiming that a signature change "fails AC-1.1" was wrong too: such a change fails in the form renders, not in a direct call.

The criterion was rewritten to render `form_with model:` for a named `ActiveModel::Model` record with an error (`stub_const` names the class, because `ActiveModel::Name` refuses an anonymous one; `url: "/"` because the record has no route) through `ApplicationController.render(inline:, locals:, layout: false)`, and to compare the output with the same render without the error. It was red with Rails' default proc (two wrapper `div`s) and green with the config line, and the implementation review confirmed it by resetting the proc in memory.

## What to do next time

Guard a framework setting by exercising the framework path that reads it, not by reading the setting back or calling it. Prove the guard red with the setting absent before relying on it, and check the "this fails when…" claims in Error Scenarios against where the framework would actually fail.

## Signals to watch for

- A guard that asserts a config value, or calls a configured lambda or proc directly.
- An Error Scenario that says a guard "fails" on an upgrade without naming the call that would fail.
