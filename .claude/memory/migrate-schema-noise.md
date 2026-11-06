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

**After `bin/ci` too (spec 038, 2026-11-06):** a `bin/ci` run, including the pre-push gate's, can leave `db/schema.rb` modified with the `solid_queue_*` tables, because the test database loads them for the admin pages' specs. A later `git merge origin/main` then aborts with "Your local changes … would be overwritten". Check `git diff db/schema.rb` before merging and restore it with `git checkout db/schema.rb`. When a merge conflicts in `db/schema.rb`, take either side and regenerate it with `bin/rails db:migrate`, which keeps every migration, rather than hand-editing.
