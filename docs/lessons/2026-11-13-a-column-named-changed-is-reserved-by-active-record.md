---
date: 2026-11-13
spec: 089 (#365)
tags: [migrations, active-record, specs, reviews]
---

# Lesson: a column named `changed` can't be a model's attribute

## Context

Spec 089's decision 2 named the run's counts `quotes_seen`, `unchanged`, `changed`, `added`, `removed` and more, as columns of `price_refresh_runs`; four acceptance criteria repeated the name. The spec went through two review rounds, the plan through two more, and the first migration was written and committed.

## What happened

The first model of the table, written in Phase 2, raised `ActiveRecord::DangerousAttributeError: changed is defined by Active Record` on every `create!`. `changed`, `changed?` and `changed=` are Active Record's dirty-tracking methods, so the name can't be an attribute, and overriding the check would break dirty tracking. Nothing in four review rounds noticed, because no reviewer builds a model.

## What to do next time

- When a spec or a plan names columns, check each name against Active Record's reserved methods (`changed`, `changes`, `save`, `errors`, `attributes`, `new_record?` and the like) before the spec is approved; a one-line `ActiveRecord::Base.dangerous_attribute_method?(name)` in a scratch runner call settles it. Put the check in the review brief for any spec that adds a table.
- A fix after a migration is committed but unreleased is a second migration (`rename_column`) when the development database has already applied the first and `db:rollback` is off limits; the area doc says why there are two.

## Signals to watch for

- A count or a state named after a verb's participle (`changed`, `saved`, `destroyed`, `errors`) in a column table.
