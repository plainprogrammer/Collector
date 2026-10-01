---
name: migrate-schema-noise
description: db:migrate regenerates the cable/cache/queue schema files with noise; rollback needs the :primary namespace
metadata:
  type: reference
---

In this multi-database app (primary, cache, queue, cable), `bin/rails db:migrate` also regenerates `db/cable_schema.rb`, `db/cache_schema.rb` and `db/queue_schema.rb`. It adds an auto-generated header, bumps them to `Schema[8.1]` and reorders `queue_schema.rb`. None of that comes from the migration.

- After migrating, restore them with `git checkout -- db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb`, and commit only `db/schema.rb`.
- Plain `bin/rails db:rollback` aborts ("You're using a multiple database application…"). Use `bin/rails db:rollback:primary STEP=n`, then `db:migrate:primary`, and check `git diff --exit-code db/schema.rb`.

Seen during spec 006 (2026-09-30). Related: [[precommit-hook-staging]].
