---
name: separate-runner-memory-measurement
description: How a memory bar is measured (spec 032 method, repeated for spec 062): a throwaway runner in its own process against a scratch SQLite file, whole requests, ps rss; measure twice
metadata:
  type: reference
---

A memory bar (the import's 500 MB, spec 025/028/032/062) is measured in a **separate process**, not in an RSpec timing spec: the test process holds the request body, the parsed file and the framework, so its figures differ from a runner's.

**Recipe** (spec 032 "Machine and method", spec 062 `verification.md` "AC-8.10's memory bar"):
- A throwaway script in the session scratchpad, never committed, run with `SCENARIO=<name> RAILS_ENV=test DATABASE_URL=sqlite3:tmp/measure/<fresh name>.sqlite3 bin/rails runner <path>`, one fresh file per run, `rm -f tmp/measure/*.sqlite3` afterwards (`tmp/` is git-ignored; nothing under `storage/` is touched).
- Whole requests through `ActionDispatch::Integration::Session` (sign in, the preview's POST, the apply's POST, the export's GET); RSS is `ps -o rss= -p <pid>` before and after, with the peak sampled every 50 ms; the write transaction is the longest `transaction.active_record` duration seen. Build the data with `insert_all` and a few factories, not one record at a time.
- **The schema step:** a `bin/rails db:schema:load` is refused by a deny rule, even with `RAILS_ENV=test` and a scratch `DATABASE_URL`, and a command the maintainer said they would approve was still denied. For spec 062 the maintainer allowed one thing, once: the runner loading `db/schema.rb` in its own process behind guards (abort unless `Rails.env.test?` and the connection's database path ends in `tmp/measure/<name>.sqlite3`). That is not a standing permission: ask again next time, and stop at the first denial rather than trying another form.

**Measure twice, and say how thin the headroom is.** The first preview of the same 24 MB file grew 359 MB in one run and 496 MB in the next (baseline without decks: 409 and 420 MB), against a 500 MB bar. The spread between runs is larger than anything the feature added.

Related: [[pr-screenshots-workflow]], [[reproduce-ci-with-seed]].
