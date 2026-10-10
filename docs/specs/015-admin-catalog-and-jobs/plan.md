# Implementation Plan: Admin Catalog Operations and Jobs

**Spec:** docs/specs/015-admin-catalog-and-jobs/spec.md (v1.1.2, Approved, reviewed twice)
**Decisions:** [ADR 0014](../../adr/0014-hand-built-admin-jobs-console.md) (hand-built jobs pages on Solid Queue's models), [ADR 0015](../../adr/0015-admin-progress-by-polling.md) (live progress by polling with Turbo morph refreshes), both Accepted
**Created:** 2026-10-09
**Revised:** 2026-10-10, after a read-only plan review (Fable, NEEDS REVISION for one manual script; Phases 0 to 8 confirmed byte-for-byte against the phase commits and traced by hand).
- **Blocking fix:** Phase 9's first benchmark script passed JSON strings for columns Solid Queue already serializes, which would have made `/admin/jobs` raise; it now passes hashes.
- **Other fixes:** `Catalog::Refresh::Progress` no longer fails on a report that comes before any stage; the queue lookup and the job entry pass over a row whose arguments aren't a job's envelope (an example for each); the cadence examples step by exact binary fractions; Phase 1's stated failure names the right example; looking at the pages (Phase 7) is on the maintainer's list; the second benchmark says to turn art matching off.
- **Renumbered** from feature 014 (and ADRs 0013, 0014): a spec 014 with ADR 0013 exists on another branch.
**Approved:** 2026-10-10 (maintainer).
**Data model:** [data-model.md](data-model.md). **Contracts:** [contracts/api.md](contracts/api.md).

**How this plan was made.** Every code block below was written, run and linted before the plan was: the feature was prototyped on a throwaway local branch, then replayed as one commit per phase (`015-plan-phases`, commits `7b6af35` to `81a6237`), with that phase's specs and RuboCop green at each commit and the whole suite, Brakeman and RuboCop green at the last (1,107 examples, 0 failures). The blocks are rendered from those commits by script, so a new file is shown whole and a changed file as the exact diff. That branch is local only and is deleted once this plan is executed.

## Global Constraints

- The core's admin catalog code names no collectible type, source or operation: none of the whole words `MTG`, `Scryfall` or `Art` (AC-5.4). A type reaches the page only through its source's optional hooks.
- A refresh's stall threshold is 15 minutes (`Catalog::RefreshRun::STALL_AFTER`) and applies only to run records. The refresh job's queue concurrency lock stays 6 hours (`Catalog::RefreshJob::LOCK_FOR`) (FR-1).
- Progress is recorded at least every 5,000 records seen or every 5 seconds, at most once a second, and never inside a batch's write transaction (AC-2.9, FR-1).
- Nothing starts a refresh except an admin's start request, the schedule or the rake task (FR-6). No operation runs inline in a request, and no page render calls the source (FR-3).
- Every page and action of this feature is behind `AdminOnly` (404 for members). Start, retry and discard are non-GET. Request parameters never choose a class or method: only a job id, a registered catalog type and one of that type's operation keys (FR-7).
- Retry and discard apply only to failed jobs, through Solid Queue's own `retry` and `discard`. No pausing, no bulk actions (FR-5, ADR 0014).
- Live updates are polling only, about every 2 seconds, only while work is in flight. Jobs never broadcast or render (FR-4, ADR 0015).
- Times are absolute UTC, `9 Oct 2026 03:15 UTC`; last progress, heartbeats and job times also get a relative form (FR-8).
- Lists: 5 recent runs per catalog type, 25 jobs per page.
- UI uses the Collector design system's tokens and `c-*` classes; every new pattern gets a doc under `docs/design-system/components/` and a line in its README. Copy is sentence case, says "you", and has no exclamation marks.
- Jobs and runs are global (no `account_id`); nothing here is tenant data.
- The migration is additive, reversible and safe for unattended `db:prepare`. After `bin/rails db:migrate`, restore `db/{cable,cache,queue}_schema.rb` with `git checkout` (they are rewritten as noise).
- No new gem, no Node.
- `bin/ci` passes at every commit: each phase commits its specs with its code, never a failing spec.
- Commits are Conventional Commits, one per phase, with the attribution trailer. Stage and commit in separate commands (the pre-commit hook reads the command text).

---

## Goal

Admins can load, refresh and watch the catalog and the art index from `/admin/catalog`, and see, retry and discard background jobs at `/admin/jobs`, with members told when the catalog isn't loaded.

**Facts established during planning (2026-10-09), each checked by running it:**

- **Solid Queue's tables load into the test database.** `load "db/queue_schema.rb"` inside `ActiveRecord::Migration.suppress_messages` creates the 13 `solid_queue_*` tables in the single test database. Its `define(version: 1)` leaves a row `"1"` in `schema_migrations`; deleting it leaves `needs_migration?` false. With `ActiveJob::Base.queue_adapter = :solid_queue` for one example, `perform_later` writes a `solid_queue_jobs` row and a ready execution, a second `Catalog::RefreshJob` for the same type gets a blocked execution, and `set(wait:)` a scheduled one. No worker runs. Transactional tests roll all of it back.
- **A job's lock is released when it fails or finishes** (`unblock_next_blocked_job` is public on `SolidQueue::Job`), so the test helpers call it; without it a retried refresh job is blocked behind its own earlier lock.
- **`window.Turbo` is a module namespace object**: its `visit` can't be replaced from a spec. The poll controller's held states are tested by listening for `turbo:visit`.
- **A flex or grid row's text reaches Capybara with newlines.** Browser specs match such text with `normalize_ws: true`.
- **ERB escapes an apostrophe in a helper's string** (`hasn&#39;t`), and an existing search spec matches the raw sentence. The not-loaded sentence is literal template text.
- **`c-table__item` is `display:flex`** and belongs on a `div` inside the cell, as the collection table uses it; on a `td` it breaks the row.
- **`.c-table td` is `white-space:nowrap`.** The jobs table's job cell opts out (`c-jobs__job`) so a long error wraps at 360px.
- **`Catalog::Refresh#flush` runs only once 1,000 changed rows are pending**, so progress is driven by records seen and time (`Catalog::Refresh::Progress`).
- **`Catalog::RefreshJob`'s lock duration was `Catalog::RefreshRun::STALE_AFTER`** (6 hours), pinned by `spec/jobs/catalog/refresh_job_spec.rb`. The run's constant is renamed `STALL_AFTER` (15 minutes) and the job gets its own `LOCK_FOR`.
- **A failed job is unfinished** (`finished_at` nil, with a failed execution), so "in flight" leaves failed jobs out.
- **Float steps drift**: a fake clock stepping by 0.0001 puts the 10,000th record a hair under one second. The cadence spec steps by exact binary fractions (`1.0 / 4_096`, `1.0 / 8_192`, `0.015625`).
- **The date in specs is UTC**, which can be a day ahead of the dev machine's local date; time-dependent examples use `travel_to(Time.utc(…))`.

**Plan decisions (not spelled out in the spec):**

- **Names.** `Catalog::Health` (one per catalog type: counts, last applied run, next scheduled run, operations, recent runs). `Catalog::Operation` (the interface, with value objects `Stage`, `Meter`, `Fact`), `Catalog::Operation::Queue` (what the queue holds for an operation's job), `Catalog::RefreshOperation`, `MTG::Art::Operation`. `BackgroundJobs::List` and `BackgroundJobs::Entry` for the jobs pages. `AdminHelper` for times and words.
- **Routes.** `/admin/catalog` is a singular resource, so the page is `Admin::CatalogsController#show` (the PRD said `#index`). Starts are `POST /admin/catalog/operation_starts` with `collectible_type` and `operation`. Jobs: `resources :jobs, only: %i[index show]` with nested singular `retry` (create) and `discard` (new, create).
- **Source hooks** (all optional, like `status_lines`): instance `progress=(callable)`, which the source calls with `(done, total)` during the download and while reading the file; class `.title`; class `.operations(collectible_type)`.
- **Run columns:** `stage`, `stage_done`, `stage_total`, `job_id`, `heartbeat_at` (see data-model.md). A run recorded before the migration has none; its last progress is its `started_at`.
- **Stage before the download.** The run enters the download stage as soon as it starts, so checking the languages and the current version count as downloading. A run skipped as already applied keeps that stage; skipped runs show no stages.
- **Progress cadence.** Written when at least 1 second has passed since the last write and either 5,000 records were seen or 2 seconds passed (2 seconds is inside the spec's 5).
- **A button with no label means no button.** `MTG::Art::Operation#start_label` is nil with art matching off (AC-4.6); with it on and the catalog not loaded, the button is shown disabled (AC-4.5).
- **The failed-job link** shows only while the failed run is the one on show and a job of that class is in the failed list.
- **Stage words:** "Done", "In progress", "Stopped here" (where a run failed or was interrupted), "Waiting".
- **The job page polls while any job is running or queued** (AC-6.10), by three `exists?` queries.
- **Jobs list reuses** `Catalog::Pagination` and the `catalog/pagination` partial.
- **The not-loaded notice** has the id `catalog_not_loaded` (the scanner page has other alert messages).
- **The avatar menu** gets the Catalog and Jobs links too: it is the More page's wide-screen twin.

**Pre-implementation gates:**

- **Simplicity:** three components: the refresh's record of its own progress (run columns, `Progress`, source hook); operations and health (what the catalog page renders); the jobs pages. No dependency added.
- **Anti-abstraction:** Rails and Solid Queue are used directly (`SolidQueue::Job`, its executions, `retry`, `discard`, `RecurringTask#next_time`). `Catalog::Operation` is an interface the spec requires (AC-5.3, AC-5.4), with two implementations and a third in tests. `BackgroundJobs::Entry` wraps one queue record for display; there is no parallel job model.
- **Integration-first:** the request contracts are in `contracts/api.md`; each page's request spec is written before its controller and views.

**Still needs a run or the maintainer:**

- The two manual benchmarks (NFR Performance), on the development machine with a loaded catalog (Phase 9). The refresh timing calls Scryfall's `/bulk-data` and may download a new bulk file.
- A real refresh watched in a browser, and a real restart mid-refresh (Phase 9), which need the development server.
- Looking at the pages in light and dark at 1280px and 390px (Phase 7), which needs the development server too. The planner looked at them in light mode only.

---

## Phase 0: Solid Queue's tables in the test database

**Implements:** NFR Reliability (tests against the queue's real tables) | **Satisfies:** (test infrastructure for AC-2.1 to AC-2.3, AC-3.2, AC-3.6, AC-3.7, AC-4.3, AC-4.4, Story 6)
**Files:** `spec/solid_queue_helpers_spec.rb`, `spec/support/solid_queue.rb`
**Interfaces:** Consumes: nothing. Produces: the tag `:solid_queue` (queues through Solid Queue for one example), and the helpers `queue_job(job_class, *arguments, wait: nil) → SolidQueue::Job`, `claim_job(job)`, `fail_job(job, error = RuntimeError.new("it broke"))`, `finish_job(job)`, each returning the reloaded job. `SolidQueueHelpers.load_tables` runs once before the suite.

The test environment has one database and the `:test` adapter. This phase loads Solid Queue's tables into it and gives specs a way to queue real queue records and move them as a worker would, without a worker.

- [ ] Create `spec/solid_queue_helpers_spec.rb`:

```ruby
require "rails_helper"

# Spec 015 NFR Reliability: the admin pages' specs run against Solid Queue's real tables, with jobs queued through its
# adapter and never performed by a worker (spec/support/solid_queue.rb).
RSpec.describe SolidQueueHelpers, type: :model do
  it "leaves the :test adapter in place for examples that don't ask for the queue", :aggregate_failures do
    expect(ActiveJob::Base.queue_adapter).to be_a(ActiveJob::QueueAdapters::TestAdapter)
    expect { Catalog::RefreshJob.perform_later("mtg") }.to have_enqueued_job(Catalog::RefreshJob)
    expect(SolidQueue::Job.count).to eq(0)
  end

  it "loads the queue's tables without leaving its schema version behind", :aggregate_failures do
    expect(ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")).to be(true)
    expect(ActiveRecord::Base.connection_pool.schema_migration.versions).not_to include("1")
    expect(ActiveRecord::Base.connection_pool.migration_context.needs_migration?).to be(false)
  end

  context "with an example tagged :solid_queue", :solid_queue do
    it "queues through Solid Queue, honouring a job's concurrency limit", :aggregate_failures do
      ready = queue_job(Catalog::RefreshJob, "mtg", "manual")
      blocked = queue_job(Catalog::RefreshJob, "mtg", "scheduled")

      expect(ready).to be_ready
      expect(blocked).to be_blocked
      expect(ready.arguments["arguments"]).to eq(%w[mtg manual])
    end

    it "schedules a job for later with wait:" do
      freeze_time do
        expect(queue_job(MTG::Art::BuildJob, wait: 5.minutes)).to be_scheduled.and have_attributes(scheduled_at: 5.minutes.from_now)
      end
    end

    it "moves a job as a worker would: claimed, then failed with its error, releasing the next", :aggregate_failures do
      job = queue_job(Catalog::RefreshJob, "mtg", "manual")
      waiting = queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(claim_job(job)).to be_claimed
      expect(fail_job(job, ArgumentError.new("no"))).to be_failed
      expect(job.failed_execution).to have_attributes(exception_class: "ArgumentError", message: "no", backtrace: be_present)
      expect(waiting.reload).to be_ready
    end

    it "finishes a job, keeping its record" do
      expect(finish_job(queue_job(MTG::Art::BuildJob))).to be_finished
    end
  end

  it "starts every example with an empty queue" do
    expect(SolidQueue::Job.count).to eq(0)
  end
end
```

- [ ] Run: `bin/rspec spec/solid_queue_helpers_spec.rb` — expect: FAIL (`uninitialized constant SolidQueueHelpers`).
- [ ] Create `spec/support/solid_queue.rb`:

```ruby
# The admin pages read Solid Queue's own tables (spec 015, ADR 0014). The test environment has one database and the
# :test job adapter, so the queue's tables are loaded into that database once per run, and an example tagged
# :solid_queue queues its jobs through Solid Queue's adapter. No worker runs in tests: a queued job stays queued until
# the example moves it with the helpers below.
module SolidQueueHelpers
  # db/queue_schema.rb, loaded only when the tables are missing (a fresh or just-reloaded test database). Its
  # `define(version: 1)` would leave a stray version in schema_migrations, so that row is removed again.
  def self.load_tables
    return if ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")

    ActiveRecord::Migration.suppress_messages { load Rails.root.join("db/queue_schema.rb") }
  ensure
    ActiveRecord::Base.connection_pool.schema_migration.delete_version("1")
  end

  # Queues a job through Solid Queue and returns the queue's record of it. With wait:, it is scheduled for later.
  def queue_job(job_class, *arguments, wait: nil)
    job = wait ? job_class.set(wait:).perform_later(*arguments) : job_class.perform_later(*arguments)
    SolidQueue::Job.find(job.provider_job_id)
  end

  # As if a worker had picked the job up.
  def claim_job(job)
    process = SolidQueue::Process.register(kind: "Worker", pid: job.id, name: "worker-#{job.id}")
    clear_executions(job)
    SolidQueue::ClaimedExecution.create!(job_id: job.id, process_id: process.id)
    job.reload
  end

  # As if the job had raised and run out of retries: it moves to the queue's failed list.
  def fail_job(job, error = RuntimeError.new("it broke"))
    error.set_backtrace([ "app/models/example.rb:1:in 'call'", "app/jobs/example_job.rb:2:in 'perform'" ]) unless error.backtrace
    clear_executions(job)
    job.failed_with(error)
    job.unblock_next_blocked_job # a worker gives the concurrency lock back when a job ends, however it ends
    job.reload
  end

  # As if the job had run to its end.
  def finish_job(job)
    clear_executions(job)
    job.finished!
    job.unblock_next_blocked_job
    job.reload
  end

  private
    def clear_executions(job)
      [ SolidQueue::ReadyExecution, SolidQueue::BlockedExecution, SolidQueue::ScheduledExecution, SolidQueue::ClaimedExecution ]
        .each { |executions| executions.where(job_id: job.id).delete_all }
      job.reload
    end
end

RSpec.configure do |config|
  config.include SolidQueueHelpers

  config.before(:suite) { SolidQueueHelpers.load_tables }

  config.around(:each, :solid_queue) do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :solid_queue
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original
  end
end
```

- [ ] Run: `bin/rspec spec/solid_queue_helpers_spec.rb` — expect: PASS (7 examples).
- [ ] Run: `bin/rspec spec/models spec/jobs` — expect: PASS (the suite is unaffected: untagged examples keep the `:test` adapter).
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `test(queue): load Solid Queue's tables in the test database (015)`

---

## Phase 1: Run records: job, heartbeat, stage and the stall rule

**Implements:** FR-1 | **Satisfies:** AC-2.15, AC-3.3, AC-3.4, AC-3.8, and the model half of AC-3.2, AC-3.5, AC-3.6, AC-2.16
**Files:** `db/migrate/20261009100001_add_progress_to_catalog_refresh_runs.rb`, `db/schema.rb`, `app/models/catalog/refresh_run.rb`, `app/jobs/catalog/refresh_job.rb`, `app/models/catalog/refresh.rb`, `spec/factories/catalog.rb`, `spec/models/catalog/refresh_run_spec.rb`, `spec/jobs/catalog/refresh_job_spec.rb`, `spec/models/catalog/refresh_spec.rb`
**Interfaces:** Consumes: nothing. Produces: columns `stage`, `stage_done`, `stage_total`, `job_id`, `heartbeat_at` on `catalog_refresh_runs`; `Catalog::RefreshRun::STALL_AFTER` (15 minutes; `STALE_AFTER` is gone), `STAGES`, `ALREADY_RUNNING`, `INTERRUPTED`; `.start!(collectible_type, trigger:, job_id: nil)`; scopes `.stalled`, `.attempted`; `#progress!(stage:, done: nil, total: nil, counts: {})`, `#last_progress_at`, `#stalled?`, `#stalled_minutes`, `#status_label(job_claimed: false)`, `#status_line(job_claimed: false)`; `Catalog::RefreshJob::LOCK_FOR` (6 hours); `Catalog::Refresh.new(collectible_type, trigger:, source:, job_id: nil)`; the factory trait `:running`.

A run learns which job runs it and when it last made progress. A refresh that starts closes a run that made no progress for 15 minutes, or that belongs to the starting job itself, instead of skipping. The job's 6-hour lock gets its own constant so the two can't be confused.

- [ ] Change `spec/factories/catalog.rb` (apply this diff exactly):

```diff
--- a/spec/factories/catalog.rb
+++ b/spec/factories/catalog.rb
@@ -50,5 +50,13 @@ FactoryBot.define do
     status { "applied" }
     started_at { 1.hour.ago }
     finished_at { 30.minutes.ago }
+
+    trait :running do
+      status { "running" }
+      trigger { "manual" }
+      started_at { 2.minutes.ago }
+      heartbeat_at { started_at }
+      finished_at { nil }
+    end
   end
 end
```

- [ ] Change `spec/models/catalog/refresh_run_spec.rb` (apply this diff exactly):

```diff
--- a/spec/models/catalog/refresh_run_spec.rb
+++ b/spec/models/catalog/refresh_run_spec.rb
@@ -6,27 +6,56 @@ RSpec.describe Catalog::RefreshRun, type: :model do
       expect(described_class.start!("mtg", trigger: "manual")).to be_running
     end
 
-    it "records a skip when a run younger than 6 hours is running", :aggregate_failures do
-      create(:catalog_refresh_run, status: "running", started_at: 5.hours.ago, finished_at: nil)
+    it "records the job running it and starts the heartbeat (spec 015 FR-1)", :aggregate_failures do
+      freeze_time do
+        run = described_class.start!("mtg", trigger: "manual", job_id: "job-1")
+
+        expect(run).to have_attributes(job_id: "job-1", heartbeat_at: Time.current, stage: nil)
+      end
+    end
+
+    it "records a skip while a run that made progress in the last 15 minutes is running (AC-3.4)", :aggregate_failures do
+      create(:catalog_refresh_run, :running, started_at: 5.hours.ago, heartbeat_at: 14.minutes.ago, job_id: "job-1")
       allow(Rails.logger).to receive(:info)
 
-      run = described_class.start!("mtg", trigger: "manual")
+      run = described_class.start!("mtg", trigger: "manual", job_id: "job-2")
 
       expect(run).to be_skipped
       expect(run.message).to eq("already running")
       expect(Rails.logger).to have_received(:info).with(a_string_including('"status":"skipped"'))
     end
 
-    it "marks a run running for 6 hours or more as interrupted and proceeds", :aggregate_failures do
-      stale = create(:catalog_refresh_run, status: "running", started_at: 7.hours.ago, finished_at: nil)
+    it "closes a run with no progress for 15 minutes as interrupted and proceeds (AC-3.3)", :aggregate_failures do
+      stale = create(:catalog_refresh_run, :running, started_at: 1.hour.ago, heartbeat_at: 16.minutes.ago, stage: "sync")
 
       run = described_class.start!("mtg", trigger: "scheduled")
 
-      expect(stale.reload).to be_failed
-      expect(stale.message).to eq("interrupted")
+      expect(stale.reload).to have_attributes(status: "failed", message: "interrupted", stage: "sync")
+      expect(run).to be_running
+    end
+
+    it "closes the starting job's own running run at once and proceeds (AC-3.3)", :aggregate_failures do
+      own = create(:catalog_refresh_run, :running, started_at: 2.minutes.ago, heartbeat_at: 1.minute.ago, job_id: "job-1")
+
+      run = described_class.start!("mtg", trigger: "manual", job_id: "job-1")
+
+      expect(own.reload).to have_attributes(status: "failed", message: "interrupted")
       expect(run).to be_running
     end
 
+    it "never matches runs without a job id to a refresh started without one (AC-3.3)" do
+      create(:catalog_refresh_run, :running, started_at: 2.minutes.ago, heartbeat_at: 1.minute.ago, job_id: nil)
+
+      expect(described_class.start!("mtg", trigger: "manual", job_id: nil)).to be_skipped
+    end
+
+    it "reads a run recorded before heartbeats by its start time", :aggregate_failures do
+      old = create(:catalog_refresh_run, :running, started_at: 16.minutes.ago, heartbeat_at: nil)
+
+      expect(described_class.start!("mtg", trigger: "manual")).to be_running
+      expect(old.reload.message).to eq("interrupted")
+    end
+
     it "ignores runs of other collectible types" do
       create(:catalog_refresh_run, collectible_type: "other", status: "running", started_at: 1.hour.ago, finished_at: nil)
 
@@ -34,6 +63,56 @@ RSpec.describe Catalog::RefreshRun, type: :model do
     end
   end
 
+  describe ".attempted (spec 015 AC-2.16)" do
+    it "leaves out runs skipped because another was running, and only those" do
+      applied = create(:catalog_refresh_run, started_at: 3.hours.ago)
+      already_applied = create(:catalog_refresh_run, status: "skipped", message: "v1 already applied", started_at: 2.hours.ago)
+      create(:catalog_refresh_run, status: "skipped", message: "already running", started_at: 1.hour.ago)
+
+      expect(described_class.attempted.recent).to eq([ already_applied, applied ])
+    end
+  end
+
+  describe "#progress! (spec 015 FR-1)" do
+    it "records the stage, how far through it is, the counts so far and the heartbeat", :aggregate_failures do
+      run = described_class.start!("mtg", trigger: "manual")
+
+      travel 1.minute do
+        run.progress!(stage: "sync", done: 40, total: 100, counts: { seen: 7, inserted: 2 })
+
+        expect(run.reload).to have_attributes(stage: "sync", stage_done: 40, stage_total: 100, seen_count: 7,
+          inserted_count: 2, heartbeat_at: Time.current, status: "running")
+      end
+    end
+
+    it "rejects a stage that isn't one of the four" do
+      run = described_class.start!("mtg", trigger: "manual")
+
+      expect { run.progress!(stage: "polish") }.to raise_error(ActiveRecord::RecordInvalid)
+    end
+  end
+
+  describe "#status_label and #status_line (spec 015 AC-3.2, AC-3.5, AC-3.6)" do
+    let(:run) { create(:catalog_refresh_run, :running, started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago) }
+
+    it "is the plain status while the run makes progress or has ended", :aggregate_failures do
+      expect(create(:catalog_refresh_run, :running, heartbeat_at: 1.minute.ago).status_label).to eq("running")
+      expect(create(:catalog_refresh_run, status: "failed").status_label).to eq("failed")
+    end
+
+    it "is interrupted for a stalled run whose job is gone" do
+      expect(run.status_label(job_claimed: false)).to eq("interrupted")
+    end
+
+    it "is running with the minutes without progress while the stalled run's job is still claimed" do
+      expect(run.status_label(job_claimed: true)).to eq("running (no progress for 20 minutes)")
+    end
+
+    it "prints the label in the status line" do
+      expect(run.status_line(job_claimed: false)).to include("  interrupted  ")
+    end
+  end
+
   describe ".applied?" do
     it "matches source version and language set", :aggregate_failures do
       create(:catalog_refresh_run, source_version: "v1", languages: "en")
```

- [ ] Change `spec/jobs/catalog/refresh_job_spec.rb` (apply this diff exactly):

```diff
--- a/spec/jobs/catalog/refresh_job_spec.rb
+++ b/spec/jobs/catalog/refresh_job_spec.rb
@@ -4,17 +4,18 @@ RSpec.describe Catalog::RefreshJob, type: :job do
   it "allows one refresh per collectible type at a time, queuing the rest", :aggregate_failures do
     expect(described_class.concurrency_limit).to eq(1)
     expect(described_class.concurrency_on_conflict).to eq(:block)
-    expect(described_class.concurrency_duration).to eq(Catalog::RefreshRun::STALE_AFTER)
+    expect(described_class.concurrency_duration).to eq(6.hours) # not the run's 15-minute stall threshold (spec 015 FR-1)
     expect(described_class.new("mtg").concurrency_key).to eq("Catalog::RefreshJob/mtg")
   end
 
-  it "runs a refresh for the collectible type and trigger" do
+  it "runs a refresh for the collectible type and trigger, under its own job id (spec 015 FR-1)" do
     refresh = instance_double(Catalog::Refresh, call: nil)
     allow(Catalog::Refresh).to receive(:new).and_return(refresh)
+    job = described_class.new("mtg", "scheduled")
 
-    described_class.perform_now("mtg", "scheduled")
+    job.perform_now
 
-    expect(Catalog::Refresh).to have_received(:new).with("mtg", trigger: "scheduled")
+    expect(Catalog::Refresh).to have_received(:new).with("mtg", trigger: "scheduled", job_id: job.job_id)
   end
 
   it "retries transient source errors" do
```

- [ ] Change `spec/models/catalog/refresh_spec.rb` (apply this diff exactly):

```diff
--- a/spec/models/catalog/refresh_spec.rb
+++ b/spec/models/catalog/refresh_spec.rb
@@ -177,12 +177,37 @@ RSpec.describe Catalog::Refresh, type: :model do
   end
 
   it "records a skip without touching the catalog while another run is in progress", :aggregate_failures do
-    create(:catalog_refresh_run, collectible_type: "fake", status: "running", started_at: 1.hour.ago, finished_at: nil)
+    create(:catalog_refresh_run, :running, collectible_type: "fake")
 
     expect(refresh).to be_skipped
     expect(Catalog::Entry.count).to eq(0)
   end
 
+  describe "the job running it (spec 015 FR-1)" do
+    it "records the job running it, and closes that job's own running run when it starts again (AC-3.3)", :aggregate_failures do
+      left = create(:catalog_refresh_run, :running, collectible_type: "fake", job_id: "job-1")
+
+      run = described_class.new("fake", trigger: "manual", source:, job_id: "job-1").call
+
+      expect(run).to have_attributes(status: "applied", job_id: "job-1")
+      expect(left.reload).to have_attributes(status: "failed", message: "interrupted")
+    end
+
+    it "gives the same catalog when a job runs again after being interrupted partway (AC-3.8)", :aggregate_failures do
+      source.entries = [ entry_record("a"), entry_record("b"), entry_record("c") ]
+      source.fail_at = 2
+      expect { described_class.new("fake", trigger: "manual", source:, job_id: "job-1").call }.to raise_error(RuntimeError)
+      Catalog::RefreshRun.recent.first.update!(status: "running", finished_at: nil) # as a killed worker leaves it
+      source.fail_at = nil
+
+      run = described_class.new("fake", trigger: "manual", source:, job_id: "job-1").call
+
+      expect(run).to have_attributes(status: "applied", seen_count: 3)
+      expect(Catalog::Entry.active.pluck(:external_key)).to contain_exactly("a", "b", "c")
+      expect(Catalog::RefreshRun.where(status: "running")).to be_empty
+    end
+  end
+
   describe "the name index (spec 007 AC-3.9)" do
     def names(text) = Catalog::NameIndex.new("fake", source_class: FakeCatalogSource).search(text).map(&:name)
 
```

- [ ] Run: `bin/rspec spec/models/catalog/refresh_run_spec.rb spec/jobs/catalog/refresh_job_spec.rb spec/models/catalog/refresh_spec.rb` — expect: FAIL (unknown attributes `heartbeat_at` and `job_id`; `start!` and `Catalog::Refresh.new` don't take `job_id`; the job doesn't pass its id). The lock-duration example passes already: 6 hours is today's value.
- [ ] Create `db/migrate/20261009100001_add_progress_to_catalog_refresh_runs.rb`:

```ruby
# Spec 015 FR-1: a refresh run records where it is while it runs (its stage, and how far through it), when it last made
# progress (the heartbeat the stall rule reads) and which job runs it (so a job that starts again closes its own run).
# Additive and nullable: runs recorded before this migration keep working, with no stage, heartbeat or job.
class AddProgressToCatalogRefreshRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :catalog_refresh_runs, bulk: true do |t|
      t.string :stage
      t.bigint :stage_done
      t.bigint :stage_total
      t.string :job_id
      t.datetime :heartbeat_at
    end
  end
end
```

- [ ] Run: `bin/rails db:migrate && git checkout db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb && bin/rails db:rollback:primary && bin/rails db:migrate && git checkout db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb` — expect: the migration runs up, down and up; `git status --short db/` shows only `db/schema.rb` and the new migration.
- [ ] Check `db/schema.rb` changed exactly like this (the schema dump writes it; don't edit it by hand):

```diff
--- a/db/schema.rb
+++ b/db/schema.rb
@@ -10,7 +10,7 @@
 #
 # It's strongly recommended that you check this file into your version control system.
 
-ActiveRecord::Schema[8.1].define(version: 2026_10_07_100003) do
+ActiveRecord::Schema[8.1].define(version: 2026_10_09_100001) do
   create_table "accounts", force: :cascade do |t|
     t.datetime "created_at", null: false
     t.datetime "updated_at", null: false
@@ -109,6 +109,11 @@ ActiveRecord::Schema[8.1].define(version: 2026_10_07_100003) do
     t.datetime "finished_at"
     t.datetime "created_at", null: false
     t.datetime "updated_at", null: false
+    t.string "stage"
+    t.bigint "stage_done"
+    t.bigint "stage_total"
+    t.string "job_id"
+    t.datetime "heartbeat_at"
     t.index ["collectible_type", "status", "started_at"], name: "idx_on_collectible_type_status_started_at_ed4a804a4c"
   end
 
```

- [ ] Change `app/models/catalog/refresh_run.rb` (apply this diff exactly):

```diff
--- a/app/models/catalog/refresh_run.rb
+++ b/app/models/catalog/refresh_run.rb
@@ -1,27 +1,42 @@
-# One attempt to apply a catalog source's data, with its outcome and counts.
+# One attempt to apply a catalog source's data, with its outcome and counts. While it runs it also records its stage,
+# how far through that stage it is and when it last made progress (spec 015 FR-1).
 class Catalog::RefreshRun < ApplicationRecord
-  STALE_AFTER = 6.hours
+  # No progress for this long means the run stalled; a refresh that starts then closes it as interrupted (spec 015
+  # AC-3.3). The job's queue lock is separate and much longer (Catalog::RefreshJob::LOCK_FOR).
+  STALL_AFTER = 15.minutes
   TRIGGERS = %w[scheduled manual].freeze
   COUNTS = %i[seen inserted updated retired restored malformed].freeze
+  STAGES = %w[download sync retire index].freeze
+  ALREADY_RUNNING = "already running".freeze
+  INTERRUPTED = "interrupted".freeze
+  LAST_PROGRESS = Arel.sql("COALESCE(heartbeat_at, started_at)")
 
   enum :status, { running: "running", applied: "applied", skipped: "skipped", failed: "failed" }, validate: true
 
   validates :collectible_type, :started_at, presence: true
   validates :trigger, inclusion: { in: TRIGGERS }
+  validates :stage, inclusion: { in: STAGES }, allow_nil: true
 
   scope :for_type, ->(collectible_type) { where(collectible_type:) }
   scope :recent, -> { order(started_at: :desc, id: :desc) }
+  scope :stalled, -> { running.where(LAST_PROGRESS.lteq(STALL_AFTER.ago)) }
+  # Every run but the ones skipped because another was running: what the catalog page shows as "the" run (AC-2.16).
+  scope :attempted, -> { where.not(status: :skipped, message: ALREADY_RUNNING) }
 
-  # Records a new attempt. A run left "running" for STALE_AFTER is marked
-  # failed ("interrupted"); a younger one makes this attempt a skip.
-  def self.start!(collectible_type, trigger:)
+  # Records a new attempt. A run still marked running is closed as failed ("interrupted") when it has made no
+  # progress for STALL_AFTER, or when it belongs to the job that is starting now (the queue re-ran the job after a
+  # restart, or an admin retried it). Any other running run makes this attempt a skip.
+  def self.start!(collectible_type, trigger:, job_id: nil)
     transaction do
       runs = for_type(collectible_type)
-      runs.running.where(started_at: ..STALE_AFTER.ago).find_each { |run| run.finish!(:failed, message: "interrupted") }
+      left_behind = runs.stalled
+      left_behind = left_behind.or(runs.running.where(job_id:)) if job_id.present?
+      left_behind.find_each { |run| run.finish!(:failed, message: INTERRUPTED) }
 
       already_running = runs.running.exists?
-      run = create!(collectible_type:, trigger:, status: :running, started_at: Time.current)
-      run.finish!(:skipped, message: "already running") if already_running
+      now = Time.current
+      run = create!(collectible_type:, trigger:, job_id:, status: :running, started_at: now, heartbeat_at: now)
+      run.finish!(:skipped, message: ALREADY_RUNNING) if already_running
       run
     end
   end
@@ -32,16 +47,39 @@ class Catalog::RefreshRun < ApplicationRecord
 
   def self.last_applied = applied.order(finished_at: :desc).first
 
+  # The run's place in its work, written as it goes: the stage, how far through it (when the source says), and the
+  # counts so far. Each write is also the heartbeat.
+  def progress!(stage:, done: nil, total: nil, counts: {})
+    update!(stage:, stage_done: done, stage_total: total, heartbeat_at: Time.current, **count_columns(counts))
+  end
+
   def finish!(status, message: nil, counts: {})
-    update!(status:, message:, finished_at: Time.current, **counts.transform_keys { |name| :"#{name}_count" })
+    update!(status:, message:, finished_at: Time.current, **count_columns(counts))
     Rails.logger.info(ActiveSupport::JSON.encode(event: "catalog.refresh.finished", collectible_type:,
       trigger:, status:, source_version:, languages:, message:, **self.counts))
   end
 
   def counts = COUNTS.index_with { |name| public_send(:"#{name}_count") }
 
-  def status_line
-    [ started_at.utc.iso8601, finished_at&.utc&.iso8601 || "-", status, trigger, source_version || "-",
+  def last_progress_at = heartbeat_at || started_at
+
+  def stalled? = running? && last_progress_at <= STALL_AFTER.ago
+
+  def stalled_minutes = ((Time.current - last_progress_at) / 60).floor
+
+  # The status as the catalog page and `catalog:status` word it. A stalled run is interrupted unless its job is still
+  # claimed by a worker (job_claimed), which only the queue knows (spec 015 AC-3.2, AC-3.5, AC-3.6).
+  def status_label(job_claimed: false)
+    return status unless stalled?
+
+    job_claimed ? "running (no progress for #{stalled_minutes} minutes)" : INTERRUPTED
+  end
+
+  def status_line(job_claimed: false)
+    [ started_at.utc.iso8601, finished_at&.utc&.iso8601 || "-", status_label(job_claimed:), trigger, source_version || "-",
       counts.map { |name, value| "#{name}=#{value}" }.join(" "), message ].compact.join("  ")
   end
+
+  private
+    def count_columns(counts) = counts.transform_keys { |name| :"#{name}_count" }
 end
```

- [ ] Change `app/jobs/catalog/refresh_job.rb` (apply this diff exactly):

```diff
--- a/app/jobs/catalog/refresh_job.rb
+++ b/app/jobs/catalog/refresh_job.rb
@@ -1,14 +1,19 @@
 # Runs a catalog refresh in the background. Queued weekly by
 # config/recurring.yml and on demand by `bin/rails "catalog:refresh[mtg]"`.
 class Catalog::RefreshJob < ApplicationJob
+  # How long the queue holds a second refresh for the same type back when the first never reports its end. It is not
+  # the run's stall threshold (Catalog::RefreshRun::STALL_AFTER, minutes): a waiting refresh must never start while
+  # another's job may still be working (spec 015 FR-1).
+  LOCK_FOR = 6.hours
+
   queue_as :sync
 
   # A second refresh for the same type waits for the first (Catalog::RefreshRun.start! guards the edge cases).
-  limits_concurrency to: 1, key: ->(collectible_type, *) { collectible_type }, duration: Catalog::RefreshRun::STALE_AFTER
+  limits_concurrency to: 1, key: ->(collectible_type, *) { collectible_type }, duration: LOCK_FOR
 
   retry_on Catalog::Sources::TransientError, ActiveRecord::StatementTimeout, wait: :polynomially_longer, attempts: 3
 
   def perform(collectible_type, trigger = "manual")
-    Catalog::Refresh.new(collectible_type, trigger:).call
+    Catalog::Refresh.new(collectible_type, trigger:, job_id:).call
   end
 end
```

- [ ] Change `app/models/catalog/refresh.rb` (apply this diff exactly):

```diff
--- a/app/models/catalog/refresh.rb
+++ b/app/models/catalog/refresh.rb
@@ -4,15 +4,16 @@
 class Catalog::Refresh
   BATCH_SIZE = 1_000
 
-  def initialize(collectible_type, trigger:, source: Catalog.source_for(collectible_type))
+  def initialize(collectible_type, trigger:, source: Catalog.source_for(collectible_type), job_id: nil)
     @collectible_type = collectible_type
     @trigger = trigger
     @source = source
+    @job_id = job_id
     @counts = Hash.new(0)
   end
 
   def call
-    @run = Catalog::RefreshRun.start!(@collectible_type, trigger: @trigger)
+    @run = Catalog::RefreshRun.start!(@collectible_type, trigger: @trigger, job_id: @job_id)
     return @run unless @run.running?
 
     languages = @source.languages
```

- [ ] Run: `bin/rspec spec/models/catalog spec/jobs/catalog spec/tasks` — expect: PASS.
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `feat(catalog): refresh runs record their job, heartbeat and stage; stall after 15 minutes (015)`

---

## Phase 2: A refresh records its stage and progress

**Implements:** FR-1, FR-2 (the hook) | **Satisfies:** AC-2.4 (stages recorded), AC-2.8, AC-2.9, AC-3.1 (stage kept on failure)
**Files:** `app/models/catalog/refresh/progress.rb`, `app/models/catalog/refresh.rb`, `app/models/catalog/sources.rb`, `spec/models/catalog/refresh/progress_spec.rb`, `spec/models/catalog/refresh_spec.rb`, `spec/support/fake_catalog_source.rb`
**Interfaces:** Consumes: `Catalog::RefreshRun#progress!(stage:, done:, total:, counts:)` (Phase 1). Produces: `Catalog::Refresh::Progress.new(run, counts, clock: CLOCK)` with `#stage(name)`, `#at(done, total)`, `#seen`; `Catalog::Refresh.new(…, job_id: nil, clock: Progress::CLOCK)`; the optional source hook `#progress=(callable)`, called with `(done, total)`; `ReportingCatalogSource` in the spec support.

The refresh enters each of its four stages by name and writes how far it is on a schedule of its own: records seen and time, not rows changed. A source may say how far through its download or file it is; one that can't is still tracked by stage and counts.

- [ ] Create `spec/models/catalog/refresh/progress_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Catalog::Refresh::Progress, type: :model do
  subject(:progress) { described_class.new(run, counts, clock: -> { now[0] }) }

  let(:run) { Catalog::RefreshRun.start!("fake", trigger: "manual") }
  let(:counts) { Hash.new(0) }
  let(:now) { [ 0.0 ] }
  let(:writes) { [] }

  before do
    allow(run).to receive(:progress!).and_wrap_original do |original, **written|
      writes << written.slice(:stage, :done, :total).values + [ written[:counts][:seen] ]
      original.call(**written)
    end
    progress.stage("sync")
  end

  # Sees records one by one, each taking the given seconds, and counts them as the refresh does.
  def see(records, seconds_each:)
    records.times do
      now[0] += seconds_each
      counts[:seen] += 1
      progress.seen
    end
  end

  it "writes a stage at once, without a place in it", :aggregate_failures do
    expect(writes).to eq([ [ "sync", nil, nil, 0 ] ])
    expect(run.reload).to have_attributes(stage: "sync", stage_done: nil, stage_total: nil)
  end

  it "writes every 5,000 records seen (spec 015 AC-2.9)" do
    see(12_000, seconds_each: 1.0 / 4_096) # 5,000 records take about 1.22 seconds

    expect(writes.map(&:last)).to eq([ 0, 5_000, 10_000 ])
  end

  it "writes when 2 seconds pass with fewer records, well inside the 5 seconds asked (AC-2.9)" do
    see(160, seconds_each: 0.015625) # 2.5 seconds, 160 records; 2 seconds are up at the 128th

    expect(writes.map(&:last)).to eq([ 0, 128 ])
  end

  it "never writes more than once a second (AC-2.9)" do
    see(12_000, seconds_each: 1.0 / 8_192) # 5,000 records take about 0.61 seconds; a second is up at the 8,192nd

    expect(writes.map(&:last)).to eq([ 0, 8_192 ])
  end

  it "records where the source says it is, on the same schedule", :aggregate_failures do
    progress.at(10, 100)
    now[0] += 2
    progress.at(60, 100)

    expect(writes.last).to eq([ "sync", 60, 100, 0 ])
    expect(writes.size).to eq(2)
  end

  it "forgets the place when the stage changes" do
    now[0] += 2
    progress.at(60, 100)
    progress.stage("retire")

    expect(writes.last).to eq([ "retire", nil, nil, 0 ])
  end

  it "writes a report that comes before any stage, instead of failing", :aggregate_failures do
    early = described_class.new(run, counts, clock: -> { now[0] })

    expect { early.at(1, 2) }.not_to raise_error
    expect(run.reload).to have_attributes(stage: nil, stage_done: 1, stage_total: 2)
  end

  it "writes with the real clock by default" do
    expect { described_class.new(run, counts).stage("index") }.to change { run.reload.stage }.to("index")
  end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/refresh/progress_spec.rb` — expect: FAIL (`uninitialized constant Catalog::Refresh::Progress`).
- [ ] Create `app/models/catalog/refresh/progress.rb`:

```ruby
# Writes a refresh run's progress while it works (spec 015 FR-1): at once when the stage changes, and otherwise at most
# once a second, as soon as 5,000 records were seen or 2 seconds passed since the last write (AC-2.9 asks for every
# 5,000 records or 5 seconds). How often it writes depends on work done and time, never on how many rows changed.
class Catalog::Refresh::Progress
  EVERY_RECORDS = 5_000
  EVERY_SECONDS = 2
  AT_MOST_EVERY_SECONDS = 1
  CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

  def initialize(run, counts, clock: CLOCK)
    @run = run
    @counts = counts
    @clock = clock
    @records = 0
    @written_at = -Float::INFINITY # nothing written yet: a report before any stage is due at once
  end

  # Enters a stage: written at once, so the page never shows the stage before.
  def stage(name)
    @stage = name
    @done = @total = nil
    write
  end

  # How far through the stage the source says it is (bytes received of the download, bytes read of the file).
  def at(done, total)
    @done = done
    @total = total
    write if due?
  end

  # One more record seen.
  def seen
    @records += 1
    write if due?
  end

  private
    def due?
      elapsed = @clock.call - @written_at
      elapsed >= AT_MOST_EVERY_SECONDS && (@records >= EVERY_RECORDS || elapsed >= EVERY_SECONDS)
    end

    def write
      @run.progress!(stage: @stage, done: @done, total: @total, counts: @counts)
      @records = 0
      @written_at = @clock.call
    end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/refresh/progress_spec.rb` — expect: PASS (8 examples).
- [ ] Change `spec/support/fake_catalog_source.rb` (apply this diff exactly):

```diff
--- a/spec/support/fake_catalog_source.rb
+++ b/spec/support/fake_catalog_source.rb
@@ -42,6 +42,25 @@ class FakeCatalogSource
   end
 end
 
+# A source with the optional progress hook (spec 015 FR-2): it says how far through the download and the file it is.
+class ReportingCatalogSource < FakeCatalogSource
+  attr_writer :progress
+
+  def download(version, dir:)
+    @progress&.call(50, 100)
+    @progress&.call(100, 100)
+    super
+  end
+
+  def each_entry(path, languages:)
+    index = 0
+    super do |record|
+      @progress&.call(index += 1, entries.size)
+      yield record
+    end
+  end
+end
+
 module CatalogRecordHelpers
   def identity_record(key = "bolt", name: "Lightning Bolt", extension: {})
     Catalog::Sources::IdentityRecord.new(external_key: key, name:, extension:)
```

- [ ] Change `spec/models/catalog/refresh_spec.rb` (apply this diff exactly):

```diff
--- a/spec/models/catalog/refresh_spec.rb
+++ b/spec/models/catalog/refresh_spec.rb
@@ -208,6 +208,57 @@ RSpec.describe Catalog::Refresh, type: :model do
     end
   end
 
+  describe "stage and progress (spec 015 FR-1)" do
+    # Every write of the run's progress, in order, as [stage, done, total, seen so far].
+    def progress_writes
+      writes = []
+      allow_any_instance_of(Catalog::RefreshRun).to receive(:progress!).and_wrap_original do |original, **progress| # rubocop:disable RSpec/AnyInstance -- the run is created inside the refresh
+        writes << [ progress[:stage], progress[:done], progress[:total], progress[:counts][:seen] ]
+        original.call(**progress)
+      end
+      writes
+    end
+
+    it "passes through the four stages in order and keeps the last one (AC-2.4)", :aggregate_failures do
+      writes = progress_writes
+
+      run = refresh
+
+      expect(writes.map(&:first)).to eq(%w[download sync retire index])
+      expect(run).to have_attributes(status: "applied", stage: "index")
+    end
+
+    it "keeps the stage reached when the run fails (AC-3.1)", :aggregate_failures do
+      source.fail_at = 1
+
+      expect { refresh }.to raise_error(RuntimeError)
+      expect(Catalog::RefreshRun.recent.first).to have_attributes(status: "failed", stage: "sync", seen_count: 1)
+    end
+
+    context "with a source that reports how far it is" do
+      let(:source) { ReportingCatalogSource.new(sets: [ set_record("lea") ], entries: [ entry_record("a"), entry_record("b") ]) }
+      let(:now) { [ 0.0 ] }
+      let(:clock) { -> { now[0] += 3 } } # every look at the clock is 3 seconds later, so every report is due
+
+      it "records bytes of the download and of the file, with the counts so far (AC-2.5, AC-2.6)", :aggregate_failures do
+        writes = progress_writes
+
+        described_class.new("fake", trigger: "manual", source:, clock:).call
+
+        expect(writes).to include([ "download", 50, 100, 0 ], [ "download", 100, 100, 0 ], [ "sync", 1, 2, 0 ], [ "sync", 2, 2, 1 ])
+        expect(writes.last).to eq([ "index", nil, nil, 2 ])
+      end
+    end
+
+    it "works with a source that reports nothing: stages and counts only (AC-2.8)" do
+      writes = progress_writes
+
+      refresh
+
+      expect(writes.map { |_stage, done, total, _seen| [ done, total ] }.uniq).to eq([ [ nil, nil ] ])
+    end
+  end
+
   describe "the name index (spec 007 AC-3.9)" do
     def names(text) = Catalog::NameIndex.new("fake", source_class: FakeCatalogSource).search(text).map(&:name)
 
```

- [ ] Run: `bin/rspec spec/models/catalog/refresh_spec.rb` — expect: FAIL (the stage and progress examples: nothing writes progress yet).
- [ ] Change `app/models/catalog/refresh.rb` (apply this diff exactly):

```diff
--- a/app/models/catalog/refresh.rb
+++ b/app/models/catalog/refresh.rb
@@ -1,14 +1,17 @@
 # Applies a catalog source's current data: writes only changed rows in short
 # batches, retires entries the source no longer lists (only after a complete
-# pass), restores ones that come back, and records a Catalog::RefreshRun.
+# pass), restores ones that come back, and records a Catalog::RefreshRun. While it works it records the run's stage
+# and progress (spec 015 FR-1): download, sync, retire, index.
 class Catalog::Refresh
   BATCH_SIZE = 1_000
 
-  def initialize(collectible_type, trigger:, source: Catalog.source_for(collectible_type), job_id: nil)
+  def initialize(collectible_type, trigger:, source: Catalog.source_for(collectible_type), job_id: nil,
+    clock: Progress::CLOCK)
     @collectible_type = collectible_type
     @trigger = trigger
     @source = source
     @job_id = job_id
+    @clock = clock
     @counts = Hash.new(0)
   end
 
@@ -16,15 +19,20 @@ class Catalog::Refresh
     @run = Catalog::RefreshRun.start!(@collectible_type, trigger: @trigger, job_id: @job_id)
     return @run unless @run.running?
 
+    track_progress
+    @progress.stage("download")
     languages = @source.languages
     version = @source.current_version(languages:)
     @run.update!(source_version: version, languages: languages.join(","))
     return skip(version) if already_applied?(version) && !reapply?
 
     path = @source.download(version, dir: Rails.configuration.x.catalog_download_dir.join(@collectible_type))
+    @progress.stage("sync")
     sync_sets
     sync_entries(path, languages)
+    @progress.stage("retire")
     retire_unseen
+    @progress.stage("index")
     name_index.rebuild
     @run.finish!(:applied, counts: @counts)
     after_refresh
@@ -35,6 +43,13 @@ class Catalog::Refresh
   end
 
   private
+    # Optional source hook (app/models/catalog/sources.rb): a source that can say how far through a download or a file
+    # it is takes a callable and calls it with (done, total). One that can't is still tracked by stage and counts.
+    def track_progress
+      @progress = Progress.new(@run, @counts, clock: @clock)
+      @source.progress = @progress.method(:at) if @source.respond_to?(:progress=)
+    end
+
     def already_applied?(version)
       @trigger == "scheduled" &&
         Catalog::RefreshRun.applied?(@collectible_type, source_version: version, languages: @run.languages)
@@ -75,20 +90,25 @@ class Catalog::Refresh
       @pending_identities = []
 
       @source.each_entry(path, languages:) do |record|
-        next record_malformed(record) if record.is_a?(Catalog::Sources::Malformed)
-        next if @seen.include?(record.external_key) # duplicate line in the source
-
-        @counts[:seen] += 1
-        @seen << record.external_key
-        queue_identity(record.identity)
-        queue_entry(record)
-        flush if @pending_entries.size >= BATCH_SIZE || @pending_identities.size >= BATCH_SIZE
+        sync_entry(record)
+        @progress.seen # outside the batch's transaction, which flush has closed by now
       end
       flush
       # An unreadable file must not look like "everything was removed upstream".
       raise Catalog::Sources::Error, "no valid records (#{@counts[:malformed]} malformed)" if @counts[:seen].zero?
     end
 
+    def sync_entry(record)
+      return record_malformed(record) if record.is_a?(Catalog::Sources::Malformed)
+      return if @seen.include?(record.external_key) # duplicate line in the source
+
+      @counts[:seen] += 1
+      @seen << record.external_key
+      queue_identity(record.identity)
+      queue_entry(record)
+      flush if @pending_entries.size >= BATCH_SIZE || @pending_identities.size >= BATCH_SIZE
+    end
+
     def queue_identity(identity)
       return unless @identities_checked.add?(identity.external_key)
 
```

- [ ] Change `app/models/catalog/sources.rb` (apply this diff exactly):

```diff
--- a/app/models/catalog/sources.rb
+++ b/app/models/catalog/sources.rb
@@ -13,6 +13,9 @@
 #   #each_entry(path, languages:) { |EntryRecord or Malformed| }   streamed, filtered to languages
 #   #reapply?                           optional: true to apply a version again although it was applied (asked before a skip)
 #   #after_refresh(run)                 optional: called after an applied run, or one skipped as already applied
+#   #progress=(callable)                optional: the refresh sets it; the source calls it with (done, total) while it
+#                                       downloads (bytes received, expected size) and while each_entry reads (bytes of the
+#                                       file read, its size), so the run can show a percentage (spec 015 FR-2)
 module Catalog::Sources
   SetRecord = Data.define(:code, :name, :released_on, :parent_code) do
     def digest = Catalog::Sources.digest(to_h)
```

- [ ] Run: `bin/rspec spec/models/catalog spec/jobs/catalog` — expect: PASS.
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `feat(catalog): a refresh records its stage and progress as it works (015)`

---

## Phase 3: The Scryfall source reports its progress

**Implements:** FR-2 | **Satisfies:** AC-2.5, AC-2.6 (the source's half)
**Files:** `app/models/mtg/scryfall/client.rb`, `app/models/mtg/scryfall/source.rb`, `spec/models/mtg/scryfall/client_spec.rb`, `spec/models/mtg/scryfall/source_spec.rb`
**Interfaces:** Consumes: the hook `#progress=(callable)` (Phase 2). Produces: `MTG::Scryfall::Client#download(url, to:) { |bytes_received| }`; `MTG::Scryfall::Source#progress=`, called with bytes received and the published size during `#download` (once with the whole size for a file it already has), and with compressed bytes read and the file's size for every line of `#each_entry`.

The bulk file's size is published, and the file is read front to back, so both percentages come for free.

- [ ] Change `spec/models/mtg/scryfall/client_spec.rb` (apply this diff exactly):

```diff
--- a/spec/models/mtg/scryfall/client_spec.rb
+++ b/spec/models/mtg/scryfall/client_spec.rb
@@ -54,6 +54,16 @@ RSpec.describe MTG::Scryfall::Client, type: :model do
 
       expect(io.string).to eq("abc")
     end
+
+    it "yields the bytes received so far to a block (spec 015 FR-2)", :aggregate_failures do
+      stub_request(:get, "https://data.scryfall.io/f.jsonl.gz").to_return(body: "abcde")
+      received = []
+
+      client.download("https://data.scryfall.io/f.jsonl.gz", to: StringIO.new) { |bytes| received << bytes }
+
+      expect(received).to eq(received.sort)
+      expect(received.last).to eq(5)
+    end
   end
 
   describe "#fetch_image (spec 011 AC-3.4)" do
```

- [ ] Change `spec/models/mtg/scryfall/source_spec.rb` (apply this diff exactly):

```diff
--- a/spec/models/mtg/scryfall/source_spec.rb
+++ b/spec/models/mtg/scryfall/source_spec.rb
@@ -107,6 +107,51 @@ RSpec.describe MTG::Scryfall::Source, type: :model do
     end
   end
 
+  describe "progress (spec 015 FR-2)" do
+    let(:reports) { [] }
+
+    before { source.progress = ->(done, total) { reports << [ done, total ] } }
+
+    it "reports bytes received of the published size while downloading (AC-2.5)", :aggregate_failures do
+      stub_scryfall(cards: [ scryfall_card ])
+      version = source.current_version(languages: [ "en" ])
+
+      size = source.download(version, dir:).size
+
+      expect(reports.last).to eq([ size, size ])
+      expect(reports.map(&:first)).to eq(reports.map(&:first).sort)
+    end
+
+    it "reports the whole size at once for a file it already has" do
+      stub_scryfall(cards: [ scryfall_card ])
+      version = source.current_version(languages: [ "en" ])
+      size = source.download(version, dir:).size
+      reports.clear
+
+      source.download(version, dir:)
+
+      expect(reports).to eq([ [ size, size ] ])
+    end
+
+    it "reports compressed bytes read of the file's size for every line, kept or not (AC-2.6)", :aggregate_failures do
+      path = dir.join("f.jsonl.gz")
+      path.binwrite(gzip_jsonl([ scryfall_card("id" => "en-1"), scryfall_card("id" => "de-1", "lang" => "de"), "{not json" ]))
+
+      source.each_entry(path, languages: [ "en" ]) { |_record| nil }
+
+      expect(reports.size).to eq(3)
+      expect(reports).to all(eq([ path.size, path.size ])) # a small file is read in one block
+    end
+
+    it "reads without a progress callable, as before" do
+      path = dir.join("f.jsonl.gz")
+      path.binwrite(gzip_jsonl([ scryfall_card("id" => "en-1") ]))
+      source.progress = nil
+
+      expect { |block| source.each_entry(path, languages: [ "en" ], &block) }.to yield_control.once
+    end
+  end
+
   describe "#each_set" do
     it "yields a record per set" do
       stub_scryfall(cards: [], sets: [ scryfall_set, scryfall_set("code" => "neo", "name" => "Kamigawa") ])
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall` — expect: FAIL (the download yields nothing; `undefined method 'progress='`).
- [ ] Change `app/models/mtg/scryfall/client.rb` (apply this diff exactly):

```diff
--- a/app/models/mtg/scryfall/client.rb
+++ b/app/models/mtg/scryfall/client.rb
@@ -31,13 +31,18 @@ class MTG::Scryfall::Client
     raise Catalog::Sources::TransientError, "GET #{uri} still rate limited after #{MAX_ATTEMPTS} attempts"
   end
 
+  # Streams the body into the given IO. With a block, yields the bytes received so far after each chunk (spec 015 FR-2).
   def download(url, to:)
     uri = URI(url)
+    received = 0
     request(uri) do |http, request|
       http.request(request) do |response|
         raise Catalog::Sources::TransientError, "GET #{uri} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
 
-        response.read_body { |chunk| to.write(chunk) }
+        response.read_body do |chunk|
+          to.write(chunk)
+          yield received += chunk.bytesize if block_given?
+        end
       end
     end
   end
```

- [ ] Change `app/models/mtg/scryfall/source.rb` (apply this diff exactly):

```diff
--- a/app/models/mtg/scryfall/source.rb
+++ b/app/models/mtg/scryfall/source.rb
@@ -13,6 +13,9 @@ class MTG::Scryfall::Source
   # Spec 011 AC-3.11: extra lines for `catalog:status[mtg]`.
   def self.status_lines = [ MTG::Art.status_line ]
 
+  # Spec 015 FR-2: a callable the refresh sets; called with (done, total) bytes of the download, then of the file read.
+  attr_writer :progress
+
   def initialize(client: MTG::Scryfall::Client.new, env: ENV)
     @client = client
     @env = env
@@ -50,7 +53,11 @@ class MTG::Scryfall::Source
     expected = Integer(file.fetch("compressed_size"))
     path = dir.join("#{version}.jsonl.gz")
     dir.mkpath
-    fetch(file.fetch("jsonl_download_uri"), path, expected) unless path.exist? && path.size == expected
+    if path.exist? && path.size == expected
+      @progress&.call(expected, expected)
+    else
+      fetch(file.fetch("jsonl_download_uri"), path, expected)
+    end
     prune(dir)
     path
   end
@@ -66,10 +73,14 @@ class MTG::Scryfall::Source
 
   def each_entry(path, languages:)
     allowed = languages.to_set
-    Zlib::GzipReader.open(path) do |gzip|
-      gzip.each_line do |line|
-        record = entry_or_malformed(line, allowed)
-        yield record if record
+    size = File.size(path)
+    File.open(path, "rb") do |file|
+      Zlib::GzipReader.wrap(file) do |gzip|
+        gzip.each_line do |line|
+          @progress&.call(file.pos, size) # compressed bytes read so far: the reader takes the file in blocks
+          record = entry_or_malformed(line, allowed)
+          yield record if record
+        end
       end
     end
   end
@@ -77,7 +88,9 @@ class MTG::Scryfall::Source
   private
     def fetch(url, path, expected)
       partial = Pathname("#{path}.part")
-      File.open(partial, "wb") { |io| @client.download(url, to: io) }
+      File.open(partial, "wb") do |io|
+        @client.download(url, to: io) { |received| @progress&.call(received, expected) }
+      end
       return partial.rename(path) if partial.size == expected
 
       actual = partial.size
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall spec/models/catalog` — expect: PASS.
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `feat(mtg): the Scryfall source reports download and file progress (015)`

---

## Phase 4: Operations, their place in the queue, and each type's health

**Implements:** FR-2 (operations hook), FR-3 (starting), the model side of Stories 2, 3 and 5 | **Satisfies:** AC-2.1 to AC-2.8 and AC-2.13, AC-2.14, AC-2.16 (as the operation presents them), AC-3.1, AC-3.2, AC-3.5, AC-3.6, AC-3.7, AC-5.1, AC-5.2, AC-5.3, AC-5.5, AC-5.6 (lookup)
**Files:** `app/models/catalog/operation.rb`, `app/models/catalog/operation/queue.rb`, `app/models/catalog/refresh_operation.rb`, `app/models/catalog/health.rb`, `app/models/catalog.rb`, `app/models/catalog/sources.rb`, `lib/tasks/catalog.rake`, `spec/models/catalog/operation/queue_spec.rb`, `spec/models/catalog/refresh_operation_spec.rb`, `spec/models/catalog/health_spec.rb`, `spec/models/catalog_spec.rb`, `spec/tasks/catalog_rake_spec.rb`, `spec/support/fake_catalog_source.rb`
**Interfaces:** Consumes: the `:solid_queue` tag and helpers (Phase 0); `Catalog::RefreshRun` scopes and labels (Phase 1). Produces: `Catalog::Operation` (subclass provides `key`, `title`, `start_label`, `queued_notice`, `in_flight_notice`, `job_class`, `summary`, `record_running?`; may provide `job_arguments`, `queue_argument`, `stages`, `meter`, `facts`, `unavailable_reason`; gets `queue`, `in_flight?`, `failed_job?`, `startable?`, `start → true/false`, `to_param`), with `Stage(label, state, meter, note)`, `Meter(label, done, total, text)#percent`, `Fact(label, value, relative)`; `Catalog::Operation::Queue.new(job_class, first_argument = nil)` with `any?`, `failed?`, `claimed?(active_job_id = nil)`, `retry_at`; `Catalog::RefreshOperation#state` (`:never`, `:queued`, `:running`, `:stalled`, `:interrupted`, `:applied`, `:skipped`, `:failed`), `#run`, `#status_label(run)`; `Catalog::Health.all`, `.find(type)` (raises `ActiveRecord::RecordNotFound`), `#title`, `#loaded?`, `#entries_count`, `#last_applied`, `#next_refresh_at`, `#languages`, `#refresh`, `#operations`, `#operation(key)`, `#in_flight?`, `#recent_runs`; `Catalog.title_for(type)`, `Catalog.unloaded_titles`; the optional source class hooks `.title` and `.operations(collectible_type)`; the spec support's `OtherCatalogSource`, `OtherCatalogOperation`, `OtherCatalogJob` and the tag `:other_catalog` (registers the type `"other"`).

Everything the catalog page will show is worked out here, away from any view: what an operation is, whether its job is in the queue, what the refresh's latest run and the queue together mean, and what a catalog type holds. `catalog:status` words a stalled run the same way.

- [ ] Create `spec/models/catalog/operation/queue_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Catalog::Operation::Queue, :solid_queue, type: :model do
  subject(:queue) { described_class.new(Catalog::RefreshJob, "mtg") }

  it "holds nothing when no job is queued", :aggregate_failures do
    expect(queue).not_to be_any
    expect(queue).not_to be_failed
    expect(queue).not_to be_claimed
    expect(queue.retry_at).to be_nil
  end

  it "counts a job for the type whatever its trigger, ready or waiting on the concurrency limit (spec 015 glossary)", :aggregate_failures do
    queue_job(Catalog::RefreshJob, "mtg", "scheduled")
    expect(described_class.new(Catalog::RefreshJob, "mtg")).to be_any

    waiting = queue_job(Catalog::RefreshJob, "mtg", "manual")
    expect(waiting.blocked_execution).to be_present
    expect(described_class.new(Catalog::RefreshJob, "mtg")).to be_any
  end

  it "ignores jobs of another type, of another class, and finished ones", :aggregate_failures do
    queue_job(Catalog::RefreshJob, "other", "manual")
    queue_job(MTG::Art::BuildJob)
    finish_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(queue).not_to be_any
    expect(described_class.new(MTG::Art::BuildJob)).to be_any
  end

  it "passes over a row whose arguments aren't a job's envelope" do
    queue_job(Catalog::RefreshJob, "mtg", "manual").update_columns(arguments: "not an envelope") # rubocop:disable Rails/SkipsModelValidations -- a row nothing in the app would write

    expect(queue).not_to be_any
  end

  it "knows when a worker holds a job, and which one", :aggregate_failures do
    job = claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(queue).to be_claimed
    expect(queue.claimed?(job.active_job_id)).to be(true)
    expect(queue.claimed?("another-job")).to be(false)
  end

  it "gives the time a job waiting to retry is due" do
    freeze_time do
      queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 5.minutes)

      expect(queue).to be_any.and have_attributes(retry_at: 5.minutes.from_now)
    end
  end

  it "reports a failed job as failed, not in flight", :aggregate_failures do
    fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(queue).to be_failed
    expect(queue).not_to be_any
  end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/operation/queue_spec.rb` — expect: FAIL (`uninitialized constant Catalog::Operation`).
- [ ] Create `app/models/catalog/operation.rb`:

```ruby
# Something an admin can start for a catalog type and watch on the admin catalog page (spec 015 FR-2). The core has
# one, the refresh (Catalog::RefreshOperation); a source adds others through its optional .operations hook
# (app/models/catalog/sources.rb). The page knows only this interface, so it never names a source or what it builds.
#
# A subclass provides:
#   key                 String naming it in the start request ("refresh")
#   title               what the panel calls it ("Refresh")
#   start_label         its button ("Refresh now")
#   queued_notice       said after it was queued ("Refresh queued.")
#   in_flight_notice    said when it was already queued or running
#   job_class           the job that does the work, and job_arguments for it
#   summary             one sentence on where it stands, starting with its state in a word
#   record_running?     true while its own run record says it is working
# and may provide queue_argument, stages, meter, facts and unavailable_reason.
class Catalog::Operation
  # One step of an operation: its state is :done, :current, :stopped (where a run failed or was interrupted) or :pending.
  Stage = Data.define(:label, :state, :meter, :note)

  # How far through something is. Without a total there is no percentage, only the text.
  Meter = Data.define(:label, :done, :total, :text) do
    def percent = total.to_i.positive? ? (done.to_i * 100 / total).clamp(0, 100) : nil
  end

  # A labelled fact under the summary. The value is a String, an Integer or a Time; relative asks for "2 minutes ago" too.
  Fact = Data.define(:label, :value, :relative)

  attr_reader :collectible_type

  def initialize(collectible_type)
    @collectible_type = collectible_type
  end

  def to_param = key
  def job_arguments = []

  # The job's first argument when its jobs are per catalog type; nil when the job takes none.
  def queue_argument = nil

  def stages = []
  def meter = nil
  def facts = []

  # Why it can't be started at all right now, whatever is in flight (a setting that is off, something missing).
  def unavailable_reason = nil

  def queue = @queue ||= Queue.new(job_class, queue_argument)

  # Spec 015 glossary: an unfinished job for it is in the queue, or its run record is running.
  def in_flight? = queue.any? || record_running?

  # True when a job of its is in the queue's failed list, so the page links there.
  def failed_job? = queue.failed?

  def startable? = unavailable_reason.nil? && !in_flight?

  # Queues its job unless it is unavailable or already in flight. True when it queued one.
  def start = startable? && job_class.perform_later(*job_arguments).present?

  private
    def fact(label, value, relative: false) = Fact.new(label:, value:, relative:)
end
```

- [ ] Create `app/models/catalog/operation/queue.rb`:

```ruby
# What the job queue holds for an operation's job (spec 015 glossary, "In flight"): its unfinished jobs, whoever queued
# them and with whatever other arguments, read from Solid Queue's own records (ADR 0014). Given a first argument (the
# catalog type), only jobs queued with it count. A failed job is unfinished too, but it is not in flight.
class Catalog::Operation::Queue
  def initialize(job_class, first_argument = nil)
    @job_class = job_class
    @first_argument = first_argument
  end

  def any? = in_flight.any?

  def failed? = jobs.any?(&:failed?)

  # True when a worker holds one of the jobs; with an Active Job id, when it holds that job.
  def claimed?(active_job_id = nil)
    in_flight.any? { |job| job.claimed? && (active_job_id.nil? || job.active_job_id == active_job_id) }
  end

  # When the earliest job waiting for a later time (a retry backing off) is due, or nil when none is.
  def retry_at = in_flight.select(&:scheduled?).filter_map(&:scheduled_at).min

  private
    def in_flight = jobs.reject(&:failed?)

    def jobs
      @jobs ||= SolidQueue::Job.where(class_name: @job_class.name, finished_at: nil)
        .includes(:failed_execution, :claimed_execution, :scheduled_execution)
        .select { |job| @first_argument.nil? || first_argument_of(job) == @first_argument }
    end

    # A row whose stored arguments aren't Active Job's envelope (nothing the app queues) matches no type.
    def first_argument_of(job) = (Array(job.arguments["arguments"]).first if job.arguments.is_a?(Hash))
end
```

- [ ] Run: `bin/rspec spec/models/catalog/operation/queue_spec.rb` — expect: PASS (7 examples).
- [ ] Create `spec/models/catalog/refresh_operation_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Catalog::RefreshOperation, :solid_queue, type: :model do
  subject(:operation) { described_class.new("mtg") }

  def run(**attributes) = create(:catalog_refresh_run, **attributes)

  def running(**attributes) = create(:catalog_refresh_run, :running, **attributes)

  it "is the refresh, started with the manual trigger", :aggregate_failures do
    expect(operation).to have_attributes(key: "refresh", title: "Refresh", start_label: "Refresh now",
      job_class: Catalog::RefreshJob, job_arguments: %w[mtg manual])
    expect(operation.queued_notice).to eq("Refresh queued.")
    expect(operation.in_flight_notice).to eq("A refresh is already queued or running.")
  end

  context "when nothing has run and nothing is queued" do
    it "has never run and can start", :aggregate_failures do
      expect(operation).to have_attributes(state: :never, summary: "No refresh has run yet.", stages: [], facts: [])
      expect(operation).to be_startable
    end

    it "queues one manual refresh job for the type (spec 015 AC-2.1)", :aggregate_failures do
      expect(operation.start).to be(true)
      expect(SolidQueue::Job.sole.arguments["arguments"]).to eq(%w[mtg manual])
    end
  end

  context "when its job is in the queue" do
    it "is queued and can't be started again, whatever queued the job (AC-2.2, AC-2.3)", :aggregate_failures do
      queue_job(Catalog::RefreshJob, "mtg", "scheduled")

      expect(operation).to have_attributes(state: :queued, summary: "Queued.", stages: [], facts: [])
      expect(operation).to be_in_flight
      expect(operation.start).to be(false)
      expect(SolidQueue::Job.count).to eq(1)
    end

    it "doesn't describe an earlier run as the queued one" do
      run(status: "applied")
      queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(operation).to have_attributes(state: :queued, summary: "Queued.", facts: [])
    end

    it "isn't held back by another type's job" do
      queue_job(Catalog::RefreshJob, "other", "manual")

      expect(operation).to be_startable
    end
  end

  context "when a run is running" do
    it "lists the four stages around the current one, with the download in bytes (AC-2.4, AC-2.5)", :aggregate_failures do
      running(stage: "download", stage_done: 41_200_000, stage_total: 82_400_000)

      expect(operation).to have_attributes(state: :running, summary: "Running.")
      expect(operation.stages.map { |stage| [ stage.label, stage.state ] })
        .to eq([ [ "Download", :current ], [ "Sync cards", :pending ], [ "Retire missing cards", :pending ], [ "Rebuild name index", :pending ] ])
      expect(operation.stages.first.meter).to have_attributes(percent: 50, text: "39.3 MB of 78.6 MB", label: "Download")
    end

    it "shows the share of the file read and the counts so far while syncing (AC-2.6)", :aggregate_failures do
      running(stage: "sync", stage_done: 61, stage_total: 100, seen_count: 66_140, inserted_count: 18, updated_count: 312)

      download, sync, = operation.stages
      expect(download).to have_attributes(state: :done, meter: nil, note: nil)
      expect(sync.meter).to have_attributes(percent: 61, text: nil)
      expect(sync.note).to eq("66,140 seen · 18 inserted · 312 updated")
    end

    it "marks retiring and the name index current without a percentage (AC-2.7)", :aggregate_failures do
      running(stage: "retire")

      expect(operation.stages.map(&:state)).to eq(%i[done done current pending])
      expect(operation.stages.third).to have_attributes(meter: nil, note: nil)
    end

    it "shows bytes received without a percentage when the size is unknown", :aggregate_failures do
      running(stage: "download", stage_done: 1_048_576, stage_total: nil)

      expect(operation.stages.first.meter).to have_attributes(percent: nil, text: "1 MB")
    end

    it "shows a source's stage without a meter when it reports no progress (AC-2.8)" do
      running(stage: "sync", seen_count: 12)

      expect(operation.stages.second).to have_attributes(state: :current, meter: nil, note: "12 seen · 0 inserted · 0 updated")
    end

    it "gives when it started, its trigger and its last progress, and can't be started (AC-2.2, AC-2.4)", :aggregate_failures do
      freeze_time do
        running(stage: "sync", started_at: 3.minutes.ago, heartbeat_at: 10.seconds.ago)

        expect(operation.facts.map { |fact| [ fact.label, fact.value, fact.relative ] })
          .to eq([ [ "Started", 3.minutes.ago, false ], [ "Trigger", "manual", false ], [ "Last progress", 10.seconds.ago, true ] ])
        expect(operation).not_to be_startable
      end
    end
  end

  context "when a run made no progress for 15 minutes" do
    let!(:stalled) { running(stage: "sync", started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1") }

    it "is interrupted once no worker holds its job, and can start again (AC-3.2)", :aggregate_failures do
      expect(operation).to have_attributes(state: :interrupted, summary: "Interrupted while syncing cards.")
      expect(operation.stages.map(&:state)).to eq(%i[done stopped pending pending])
      expect(operation).to be_startable
      expect(operation.status_label(stalled)).to eq("interrupted")
    end

    it "stays closed to a new start while a refresh job for the type is still unfinished in the queue (AC-3.2)" do
      queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(operation).to have_attributes(state: :interrupted, startable?: false)
    end

    it "is still running, with the minutes, while a worker holds its job (AC-3.6)", :aggregate_failures do
      claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual")).update!(active_job_id: "job-1")

      expect(operation).to have_attributes(state: :stalled, summary: "Running, no progress for 20 minutes.")
      expect(operation.stages.second.state).to eq(:current)
      expect(operation).not_to be_startable
      expect(operation.status_label(stalled)).to eq("running (no progress for 20 minutes)")
    end

    it "isn't kept running by a worker holding another job" do
      claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

      expect(operation.state).to eq(:interrupted)
    end
  end

  context "when the last run ended" do
    it "shows an applied run's counts, version and finish time (AC-2.13)", :aggregate_failures do
      run(status: "applied", source_version: "v7", seen_count: 106_636, updated_count: 12, stage: "index")

      expect(operation).to have_attributes(state: :applied, summary: "Applied.", stages: [])
      expect(operation.facts.to_h { |fact| [ fact.label, fact.value ] }).to include("Source version" => "v7",
        "Counts" => "106,636 seen · 0 inserted · 12 updated · 0 retired · 0 restored · 0 malformed", "Finished" => be_a(Time))
      expect(operation).to be_startable
    end

    it "shows a skipped run with its message (AC-2.14)" do
      run(status: "skipped", message: "v7 already applied")

      expect(operation).to have_attributes(state: :skipped, summary: "Skipped: v7 already applied.")
    end

    it "shows the run before one skipped because another was running (AC-2.16)", :aggregate_failures do
      run(status: "applied", started_at: 2.hours.ago, source_version: "v7")
      2.times { |n| run(status: "skipped", message: "already running", started_at: (60 - n).minutes.ago) }

      expect(operation.state).to eq(:applied)
      expect(operation.run.source_version).to eq("v7")
    end

    it "shows a failed run with the stage it failed in and its message (AC-3.1)", :aggregate_failures do
      run(status: "failed", stage: "sync", message: "RuntimeError: source exploded")

      expect(operation).to have_attributes(state: :failed, summary: "Failed while syncing cards: RuntimeError: source exploded")
      expect(operation.stages.map(&:state)).to eq(%i[done stopped pending pending])
      expect(operation).not_to be_failed_job
    end

    it "words a failure recorded before stages without one" do
      run(status: "failed", stage: nil, message: "IntegrityError: short file")

      expect(operation).to have_attributes(summary: "Failed: IntegrityError: short file", stages: [])
    end

    it "knows when the failed run's job is in the queue's failed list (AC-3.1)" do
      run(status: "failed", stage: "download", message: "TransientError: 503")
      fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

      expect(operation).to be_failed_job.and be_startable
    end

    it "doesn't point at an old failed job once a later run is on show" do
      fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
      run(status: "applied")

      expect(operation).not_to be_failed_job
    end

    it "shows a failed run whose job waits to retry as queued, retrying at its time (AC-3.7)", :aggregate_failures do
      freeze_time do
        run(status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503")
        queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)

        expect(operation).to have_attributes(state: :queued, startable?: false, failed_job?: false,
          summary: "Queued to retry. The last run failed while downloading: Catalog::Sources::TransientError: 503")
        expect(operation.facts.first).to have_attributes(label: "Retrying at", value: 3.minutes.from_now)
        expect(operation.stages.first.state).to eq(:stopped)
      end
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/refresh_operation_spec.rb` — expect: FAIL (`uninitialized constant Catalog::RefreshOperation`).
- [ ] Create `app/models/catalog/refresh_operation.rb`:

```ruby
# The refresh of one catalog type as the admin catalog page shows it (spec 015 Stories 2 and 3): the latest run that
# wasn't skipped because another was running (AC-2.16), what the job queue holds, and what follows from the two.
class Catalog::RefreshOperation < Catalog::Operation
  STAGES = { "download" => "Download", "sync" => "Sync cards", "retire" => "Retire missing cards",
             "index" => "Rebuild name index" }.freeze
  DOING = { "download" => "downloading", "sync" => "syncing cards", "retire" => "retiring missing cards",
            "index" => "rebuilding the name index" }.freeze
  SYNC_COUNTS = %i[seen inserted updated].freeze

  def key = "refresh"
  def title = "Refresh"
  def start_label = "Refresh now"
  def queued_notice = "Refresh queued."
  def in_flight_notice = "A refresh is already queued or running."
  def job_class = Catalog::RefreshJob
  def job_arguments = [ collectible_type, "manual" ]
  def queue_argument = collectible_type

  def run
    return @run if defined?(@run)

    @run = Catalog::RefreshRun.for_type(collectible_type).attempted.recent.first
  end

  # :never, :queued, :running, :stalled, :interrupted, :applied, :skipped or :failed.
  def state
    @state ||=
      if run&.running? then running_state
      elsif queue.any? then :queued
      else run ? run.status.to_sym : :never
      end
  end

  def record_running? = %i[running stalled].include?(state)

  # The page links to the failed list only for the failed run on show (spec 015 AC-3.1).
  def failed_job? = state == :failed && super

  # What `catalog:status` and the recent-runs list call a run: a stalled one is interrupted unless its job is still
  # claimed by a worker (spec 015 AC-3.2, AC-3.5, AC-3.6).
  def status_label(run) = run.status_label(job_claimed: job_claimed?(run))

  def summary
    case state
    when :never then "No refresh has run yet."
    when :queued then retrying? ? "Queued to retry. The last run #{failed_summary.downcase_first}" : "Queued."
    when :running then "Running."
    when :stalled then "Running, no progress for #{run.stalled_minutes} minutes."
    when :interrupted then [ "Interrupted", doing ].compact.join(" while ") + "."
    when :applied then "Applied."
    when :skipped then "Skipped: #{run.message}."
    when :failed then failed_summary
    end
  end

  # The four stages of the run in view, while it runs and after it failed or was interrupted.
  def stages
    return [] unless shown_run&.stage && (shown_run.running? || shown_run.failed?)

    reached = STAGES.keys.index(shown_run.stage)
    STAGES.each_with_index.map do |(name, label), index|
      here = index == reached
      Stage.new(label:, state: stage_state(index, reached), meter: (stage_meter(name) if here), note: (stage_note(name) if here))
    end
  end

  def facts
    retry_fact = [ (fact("Retrying at", queue.retry_at) if state == :queued && queue.retry_at) ].compact
    return retry_fact unless shown_run

    retry_fact + [
      fact("Started", shown_run.started_at), fact("Trigger", shown_run.trigger),
      (fact("Last progress", shown_run.last_progress_at, relative: true) if shown_run.running?),
      (fact("Finished", shown_run.finished_at) if shown_run.finished_at),
      (fact("Source version", shown_run.source_version) if shown_run.source_version),
      (fact("Counts", counts_text(Catalog::RefreshRun::COUNTS)) if shown_run.applied?)
    ].compact
  end

  private
    def running_state
      return :running unless run.stalled?

      job_claimed?(run) ? :stalled : :interrupted
    end

    def job_claimed?(run) = run.job_id.present? && queue.claimed?(run.job_id)

    # A failed run whose job waits to run again (spec 015 AC-3.7).
    def retrying? = state == :queued && queue.retry_at.present? && run&.failed?

    # The run the stages and facts describe: none while a new refresh is queued, unless it is the failed run's retry.
    def shown_run = (run if state != :queued || retrying?)

    def doing = DOING[run.stage]

    def failed_summary = [ "Failed", doing ].compact.join(" while ") + ": #{run.message}"

    def stage_state(index, reached)
      return :done if index < reached
      return :pending if index > reached

      record_running? ? :current : :stopped
    end

    def stage_meter(name)
      return unless run.stage_done

      Meter.new(label: STAGES.fetch(name), done: run.stage_done, total: run.stage_total, text: (bytes_text if name == "download"))
    end

    def bytes_text
      [ run.stage_done, run.stage_total ].compact.map { |bytes| ActiveSupport::NumberHelper.number_to_human_size(bytes) }.join(" of ")
    end

    def stage_note(name) = (counts_text(SYNC_COUNTS) if name == "sync")

    def counts_text(names)
      names.map { |name| "#{ActiveSupport::NumberHelper.number_to_delimited(run.counts.fetch(name))} #{name}" }.join(" · ")
    end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/refresh_operation_spec.rb` — expect: PASS (24 examples).
- [ ] Change `spec/support/fake_catalog_source.rb` (apply this diff exactly):

```diff
--- a/spec/support/fake_catalog_source.rb
+++ b/spec/support/fake_catalog_source.rb
@@ -61,6 +61,40 @@ class ReportingCatalogSource < FakeCatalogSource
   end
 end
 
+# A test-only catalog type with a name of its own and one extra operation (spec 015 AC-5.3): registered for one
+# example with `:other_catalog`, as the type "other".
+class OtherCatalogSource < FakeCatalogSource
+  def self.title = "Pocket Monsters"
+  def self.operations(collectible_type) = [ OtherCatalogOperation.new(collectible_type) ]
+end
+
+class OtherCatalogOperation < Catalog::Operation
+  def key = "price_sync"
+  def title = "Price sync"
+  def start_label = "Sync prices"
+  def queued_notice = "Price sync queued."
+  def in_flight_notice = "A price sync is already queued or running."
+  def job_class = OtherCatalogJob
+  def job_arguments = [ collectible_type ]
+  def queue_argument = collectible_type
+  def summary = "Never synced."
+  def record_running? = false
+  def meter = Meter.new(label: "Prices", done: 1, total: 4, text: "1 of 4 prices")
+end
+
+class OtherCatalogJob < ApplicationJob
+  def perform(_collectible_type) = nil
+end
+
+RSpec.configure do |config|
+  config.around(:each, :other_catalog) do |example|
+    Catalog.sources["other"] = "OtherCatalogSource"
+    example.run
+  ensure
+    Catalog.sources.delete("other")
+  end
+end
+
 module CatalogRecordHelpers
   def identity_record(key = "bolt", name: "Lightning Bolt", extension: {})
     Catalog::Sources::IdentityRecord.new(external_key: key, name:, extension:)
```

- [ ] Create `spec/models/catalog/health_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Catalog::Health, type: :model do
  subject(:health) { described_class.new("mtg") }

  describe ".all and .find" do
    it "has one per registered type, in name order (spec 015 AC-5.1)", :other_catalog do
      expect(described_class.all.map(&:collectible_type)).to eq(%w[mtg other])
    end

    it "finds a registered type and raises not found for any other (AC-5.6)", :aggregate_failures do
      expect(described_class.find("mtg").collectible_type).to eq("mtg")
      expect { described_class.find("pokemon") }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  it "is titled by its source, or by its type when the source gives no title", :aggregate_failures, :other_catalog do
    expect(described_class.new("other").title).to eq("Pocket Monsters")
    Catalog.sources["plain"] = "FakeCatalogSource"
    expect(described_class.new("plain").title).to eq("Plain")
  ensure
    Catalog.sources.delete("plain")
  end

  it "counts the type's entries that aren't retired (AC-5.1)" do
    create(:catalog_entry)
    create(:catalog_entry, :retired)
    create(:catalog_entry, collectible_type: "other")

    expect(health.entries_count).to eq(1)
  end

  it "is loaded once the type has an applied refresh (glossary)", :aggregate_failures do
    create(:catalog_refresh_run, status: "failed")
    create(:catalog_refresh_run, collectible_type: "other")
    expect(health).not_to be_loaded

    applied = create(:catalog_refresh_run, source_version: "v7")
    expect(described_class.new("mtg")).to be_loaded.and have_attributes(last_applied: applied)
  end

  describe "#next_refresh_at (AC-5.5)" do
    def schedule(key, arguments)
      SolidQueue::RecurringTask.create!(key:, class_name: "Catalog::RefreshJob", arguments:, schedule: "every monday at 3:15am", static: true)
    end

    it "is nil when nothing is scheduled for the type" do
      schedule("refresh_other_catalog", %w[other scheduled])

      expect(health.next_refresh_at).to be_nil
    end

    it "is the next run of the type's recurring refresh, whatever its trigger argument" do
      schedule("refresh_mtg_catalog", %w[mtg scheduled])

      travel_to Time.utc(2026, 10, 9, 12) do
        expect(health.next_refresh_at).to eq(Time.utc(2026, 10, 12, 3, 15))
      end
    end
  end

  it "gives the configured languages, or why the setting can't be read (AC-1.4)", :aggregate_failures do
    expect(health.languages).to eq("EN")
    allow(Catalog).to receive(:source_for).and_return(FakeCatalogSource.new(languages: Catalog::Sources::ConfigurationError.new("unsupported language code(s): xx")))
    expect(health.languages).to eq("unsupported language code(s): xx")
  end

  describe "#operations" do
    it "is the refresh alone for a source that adds none (AC-5.2)" do
      Catalog.sources["plain"] = "FakeCatalogSource"
      expect(described_class.new("plain").operations.map(&:key)).to eq([ "refresh" ])
    ensure
      Catalog.sources.delete("plain")
    end

    it "is the refresh, then what the source adds (AC-5.3)", :aggregate_failures, :other_catalog do
      other = described_class.new("other")

      expect(other.operations.map(&:key)).to eq(%w[refresh price_sync])
      expect(other.refresh).to be_a(Catalog::RefreshOperation)
      expect(other.operation("price_sync").title).to eq("Price sync")
      expect(other.operation("missing")).to be_nil
    end
  end

  it "is in flight while any of its operations is", :solid_queue do
    expect { queue_job(Catalog::RefreshJob, "mtg", "scheduled") }.to change { described_class.new("mtg").in_flight? }.from(false).to(true)
  end

  it "lists the 5 most recent runs, skipped ones included (AC-5.1, AC-2.16)", :aggregate_failures do
    7.times { |n| create(:catalog_refresh_run, started_at: (n + 1).hours.ago, source_version: "v#{n}") }
    skipped = create(:catalog_refresh_run, status: "skipped", message: "already running", started_at: 1.minute.ago)

    expect(health.recent_runs.size).to eq(5)
    expect(health.recent_runs.first).to eq(skipped)
  end
end
```

- [ ] Change `spec/models/catalog_spec.rb` (apply this diff exactly):

```diff
--- a/spec/models/catalog_spec.rb
+++ b/spec/models/catalog_spec.rb
@@ -21,4 +21,18 @@ RSpec.describe Catalog, type: :model do
   it "allows images and links only from registered sources' hosts" do
     expect(described_class.allowed_hosts).to contain_exactly("scryfall.com", "cards.scryfall.io", "svgs.scryfall.io")
   end
+
+  describe ".title_for and .unloaded_titles (spec 015 glossary)" do
+    it "names a type by its source's title", :other_catalog do
+      expect(described_class.title_for("other")).to eq("Pocket Monsters")
+    end
+
+    it "lists the types with no applied refresh, by title", :aggregate_failures, :other_catalog do
+      create(:catalog_refresh_run, collectible_type: "other", status: "failed")
+      expect(described_class.unloaded_titles).to eq([ described_class.title_for("mtg"), "Pocket Monsters" ])
+
+      create(:catalog_refresh_run, collectible_type: "other", status: "applied")
+      expect(described_class.unloaded_titles).to eq([ described_class.title_for("mtg") ])
+    end
+  end
 end
```

- [ ] Run: `bin/rspec spec/models/catalog/health_spec.rb spec/models/catalog_spec.rb` — expect: FAIL (`uninitialized constant Catalog::Health`, `undefined method 'title_for'`).
- [ ] Create `app/models/catalog/health.rb`:

```ruby
# One catalog type as the admin catalog page shows it (spec 015 Story 5): how many entries it holds, its last applied
# refresh, when the next one is scheduled, what an admin can start for it, and its recent runs.
class Catalog::Health
  RECENT_RUNS = 5

  attr_reader :collectible_type

  def self.all = Catalog.sources.keys.sort.map { |collectible_type| new(collectible_type) }

  # Raises ActiveRecord::RecordNotFound for a type that isn't registered, so a request naming one answers 404.
  def self.find(collectible_type)
    raise ActiveRecord::RecordNotFound, "unknown catalog type" unless Catalog.sources.key?(collectible_type.to_s)

    new(collectible_type.to_s)
  end

  def initialize(collectible_type)
    @collectible_type = collectible_type
  end

  def title = Catalog.title_for(collectible_type)

  def loaded? = last_applied.present?

  def entries_count = @entries_count ||= Catalog::Entry.active.where(collectible_type:).count

  def last_applied
    return @last_applied if defined?(@last_applied)

    @last_applied = Catalog::RefreshRun.for_type(collectible_type).last_applied
  end

  # When the schedule next queues a refresh for this type, or nil when nothing is scheduled (as in development).
  def next_refresh_at
    SolidQueue::RecurringTask.where(class_name: Catalog::RefreshJob.name)
      .select { |task| Array(task.arguments).first == collectible_type }.filter_map(&:next_time).min
  end

  # The languages the source is set to take, or the reason the setting can't be read.
  def languages
    Catalog.source_for(collectible_type).languages.map(&:upcase).join(", ")
  rescue Catalog::Sources::ConfigurationError => error
    error.message
  end

  def refresh = operations.first

  # The refresh first, then whatever the source adds (optional hook, app/models/catalog/sources.rb).
  def operations
    @operations ||= begin
      source = Catalog.source_class(collectible_type)
      [ Catalog::RefreshOperation.new(collectible_type), *(source.operations(collectible_type) if source.respond_to?(:operations)) ]
    end
  end

  def operation(key) = operations.find { |operation| operation.key == key.to_s }

  def in_flight? = operations.any?(&:in_flight?)

  def recent_runs = @recent_runs ||= Catalog::RefreshRun.for_type(collectible_type).recent.limit(RECENT_RUNS).to_a
end
```

- [ ] Change `app/models/catalog.rb` (apply this diff exactly):

```diff
--- a/app/models/catalog.rb
+++ b/app/models/catalog.rb
@@ -17,5 +17,17 @@ module Catalog
     collecting.fetch(collectible_type) { raise ArgumentError, "unknown collectible type: #{collectible_type}" }.constantize
   end
 
+  # What people call a type's catalog: the source's optional .title, or the type's own name.
+  def self.title_for(collectible_type)
+    source = source_class(collectible_type)
+    source.respond_to?(:title) ? source.title : collectible_type.to_s.humanize
+  end
+
+  # The titles of the catalog types with no applied refresh yet (spec 015 glossary, "Loaded"), in one query.
+  def self.unloaded_titles
+    loaded = Catalog::RefreshRun.applied.where(collectible_type: sources.keys).distinct.pluck(:collectible_type)
+    (sources.keys - loaded).sort.map { |collectible_type| title_for(collectible_type) }
+  end
+
   def self.allowed_hosts = sources.values.flat_map { |name| name.constantize::ALLOWED_HOSTS }.uniq
 end
```

- [ ] Change `app/models/catalog/sources.rb` (apply this diff exactly):

```diff
--- a/app/models/catalog/sources.rb
+++ b/app/models/catalog/sources.rb
@@ -16,6 +16,8 @@
 #   #progress=(callable)                optional: the refresh sets it; the source calls it with (done, total) while it
 #                                       downloads (bytes received, expected size) and while each_entry reads (bytes of the
 #                                       file read, its size), so the run can show a percentage (spec 015 FR-2)
+#   .title                              optional: what the admin catalog page calls this catalog ("Magic: The Gathering")
+#   .operations(collectible_type)       optional: extra Catalog::Operation objects for the admin catalog page
 module Catalog::Sources
   SetRecord = Data.define(:code, :name, :released_on, :parent_code) do
     def digest = Catalog::Sources.digest(to_h)
```

- [ ] Run: `bin/rspec spec/models/catalog/health_spec.rb spec/models/catalog_spec.rb` — expect: PASS.
- [ ] Change `spec/tasks/catalog_rake_spec.rb` (apply this diff exactly):

```diff
--- a/spec/tasks/catalog_rake_spec.rb
+++ b/spec/tasks/catalog_rake_spec.rb
@@ -31,6 +31,20 @@ RSpec.describe "catalog rake tasks", type: :task do # rubocop:disable RSpec/Desc
       expect(lines.second).to include("v10", "applied", "scheduled")
     end
 
+    it "marks a run with no progress for 15 minutes interrupted (spec 015 AC-3.5)" do
+      create(:catalog_refresh_run, :running, started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1")
+
+      expect { Rake::Task["catalog:status"].invoke("mtg") }.to output(/  interrupted  manual/).to_stdout
+    end
+
+    it "prints a stalled run whose job a worker still holds as running, as the page does (AC-3.5, AC-3.6)", :solid_queue do
+      create(:catalog_refresh_run, :running, started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1")
+      claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual")).update!(active_job_id: "job-1")
+
+      expect { Rake::Task["catalog:status"].invoke("mtg") }
+        .to output(/  running \(no progress for 20 minutes\)  manual/).to_stdout
+    end
+
     it "says when there are no runs" do
       expect { Rake::Task["catalog:status"].invoke("mtg") }.to output(/No mtg refresh runs yet/).to_stdout
     end
```

- [ ] Run: `bin/rspec spec/tasks/catalog_rake_spec.rb` — expect: FAIL (the stalled run whose job is claimed prints as interrupted).
- [ ] Change `lib/tasks/catalog.rake` (apply this diff exactly):

```diff
--- a/lib/tasks/catalog.rake
+++ b/lib/tasks/catalog.rake
@@ -10,10 +10,12 @@ namespace :catalog do
   desc 'Show the 10 most recent catalog refresh runs (default mtg): bin/rails "catalog:status[mtg]"'
   task :status, [ :collectible_type ] => :environment do |_task, args|
     collectible_type = args[:collectible_type] || "mtg"
+    source = Catalog.source_class(collectible_type)
     runs = Catalog::RefreshRun.for_type(collectible_type).recent.limit(10)
     puts "No #{collectible_type} refresh runs yet." if runs.none?
-    runs.each { |run| puts run.status_line }
-    source = Catalog.source_class(collectible_type)
+    # A stalled run reads as the admin catalog page words it: interrupted, or still running when its job is (spec 015 AC-3.5).
+    queue = Catalog::Operation::Queue.new(Catalog::RefreshJob, collectible_type)
+    runs.each { |run| puts run.status_line(job_claimed: run.job_id.present? && queue.claimed?(run.job_id)) }
     source.status_lines.each { |line| puts line } if source.respond_to?(:status_lines)
   end
 end
```

- [ ] Run: `bin/rspec spec/models/catalog spec/models/catalog_spec.rb spec/jobs spec/tasks && bin/rails zeitwerk:check` — expect: PASS, and "All is good!".
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `feat(catalog): operations, their place in the queue, and each type's health (015)`

---

## Phase 5: The art index as a catalog operation

**Implements:** FR-2 (MTG's hooks), Story 4 | **Satisfies:** AC-4.1 to AC-4.9 (as the operation presents them)
**Files:** `app/models/mtg/art/operation.rb`, `app/models/mtg/scryfall/source.rb`, `app/models/mtg/art.rb`, `spec/models/mtg/art/operation_spec.rb`, `spec/models/mtg/scryfall/source_spec.rb`, `spec/models/mtg/art_spec.rb`, `spec/jobs/catalog/refresh_job_spec.rb`
**Interfaces:** Consumes: `Catalog::Operation` and its `Queue` (Phase 4). Produces: `MTG::Art::Operation` (`key` `"art_index"`, `#state`: `:off`, `:queued`, `:building`, `:interrupted`, `:never`, `:ready`, `:failed`; `#build`); `MTG::Scryfall::Source.title` (`"Magic: The Gathering"`) and `.operations(collectible_type)`.

MTG says what its catalog is called and offers its one extra operation. The art build keeps its own stall and job-id rules (spec 011); this only presents them. `catalog:status`'s never-built line now mentions the page (AC-4.1).

- [ ] Create `spec/models/mtg/art/operation_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MTG::Art::Operation, :solid_queue, type: :model do
  subject(:operation) { described_class.new("mtg") }

  def loaded = create(:catalog_refresh_run, status: "applied")

  def build(**attributes) = create(:mtg_art_build, **attributes)

  context "with art matching off" do
    it "says how to turn it on and offers no button (spec 015 AC-4.6)", :aggregate_failures do
      loaded

      expect(operation).to have_attributes(state: :off, start_label: nil, startable?: false,
        summary: "Art matching is off. Set COLLECTOR_MTG_ART_MATCHING=true to turn it on.")
      expect(operation.start).to be(false)
    end
  end

  context "with art matching on", :art_matching do
    it "is the art index build", :aggregate_failures do
      expect(operation).to have_attributes(key: "art_index", title: "Art index", start_label: "Build art index",
        job_class: MTG::Art::BuildJob, job_arguments: [], queue_argument: nil)
      expect(operation.queued_notice).to eq("Art index build queued.")
      expect(operation.in_flight_notice).to eq("An art index build is already queued or running.")
    end

    it "needs the catalog refreshed first (AC-4.5)", :aggregate_failures do
      expect(operation).to have_attributes(state: :never, startable?: false,
        summary: "Refresh the catalog first: the art index is built from its cards.")
      expect(operation.start).to be(false)
      expect(SolidQueue::Job.count).to eq(0)
    end

    it "has never been built, and queues one build job when started (AC-4.1, AC-4.3)", :aggregate_failures do
      loaded

      expect(operation).to have_attributes(state: :never,
        summary: "No build has run yet. One starts after the next catalog refresh, or you can start it here.")
      expect(operation.start).to be(true)
      expect(SolidQueue::Job.sole.class_name).to eq("MTG::Art::BuildJob")
    end

    it "is queued while its job is in the queue, and can't be started again (AC-4.4)", :aggregate_failures do
      loaded
      queue_job(MTG::Art::BuildJob)

      expect(operation).to have_attributes(state: :queued, summary: "Queued.", startable?: false)
      expect(operation.start).to be(false)
      expect(SolidQueue::Job.count).to eq(1)
    end

    it "shows a running build's progress, counts and heartbeat (AC-4.2)", :aggregate_failures do
      loaded
      freeze_time do
        build(status: "running", finished_at: nil, heartbeat_at: 20.seconds.ago, total_count: 31_904,
          fingerprinted_count: 7_976, fetched_count: 1_200, failed_count: 3)

        expect(operation).to have_attributes(state: :building, summary: "Building.", startable?: false)
        expect(operation.meter).to have_attributes(percent: 25, text: "7,976 of 31,904 artworks fingerprinted")
        expect(operation.facts.map { |fact| [ fact.label, fact.value, fact.relative ] }).to include(
          [ "Images fetched", 1_200, false ], [ "Failed images", 3, false ], [ "Last heartbeat", 20.seconds.ago, true ])
      end
    end

    it "is interrupted when the heartbeat stopped, and can be built again (AC-4.1)", :aggregate_failures do
      loaded
      build(status: "running", finished_at: nil, heartbeat_at: 11.minutes.ago, total_count: 10, fingerprinted_count: 3)

      expect(operation).to have_attributes(state: :interrupted, startable?: true,
        summary: "Interrupted. Build it again to carry on from where it stopped.")
      expect(operation.meter.percent).to eq(30)
    end

    it "shows a finished build's counts and finish time (AC-4.7)", :aggregate_failures do
      loaded
      build(indexed_count: 31_904, without_image_count: 12, failed_count: 3)

      expect(operation).to have_attributes(state: :ready, summary: "Ready.", meter: nil, startable?: true)
      expect(operation.facts.to_h { |fact| [ fact.label, fact.value ] })
        .to include("Artworks indexed" => 31_904, "Without an image" => 12, "Failed images" => 3, "Finished" => be_a(Time))
    end

    it "shows a failed build's message and the index still in use (AC-4.8)", :aggregate_failures do
      loaded
      build(status: "failed", message: "Errno::ENOSPC: No space left on device")

      expect(operation).to have_attributes(state: :failed, summary: "Failed: Errno::ENOSPC: No space left on device")
      expect(operation.facts.to_h { |fact| [ fact.label, fact.value ] }).to include("Index in use" => "none")
    end

    it "names the index a failed build left in use (AC-4.8)" do
      loaded
      kept = MTG::Art::Index.write!("default-cards-1", [])
      build(status: "failed", message: "boom")

      expect(operation.facts.last).to have_attributes(label: "Index in use", value: kept.basename.to_s)
    end

    it "ignores a build skipped because another was running, as the status line does" do
      loaded
      build(indexed_count: 9, started_at: 2.hours.ago)
      build(status: "skipped", message: "already running", started_at: 1.hour.ago)

      expect(operation.state).to eq(:ready)
    end
  end
end
```

- [ ] Change `spec/models/mtg/scryfall/source_spec.rb` (apply this diff exactly):

```diff
--- a/spec/models/mtg/scryfall/source_spec.rb
+++ b/spec/models/mtg/scryfall/source_spec.rb
@@ -152,6 +152,13 @@ RSpec.describe MTG::Scryfall::Source, type: :model do
     end
   end
 
+  describe ".title and .operations (spec 015 FR-2)" do
+    it "names the catalog and offers the art index as its one extra operation", :aggregate_failures do
+      expect(described_class.title).to eq("Magic: The Gathering")
+      expect(described_class.operations("mtg").map(&:key)).to eq([ "art_index" ])
+    end
+  end
+
   describe "#each_set" do
     it "yields a record per set" do
       stub_scryfall(cards: [], sets: [ scryfall_set, scryfall_set("code" => "neo", "name" => "Kamigawa") ])
```

- [ ] Change `spec/models/mtg/art_spec.rb` (apply this diff exactly):

```diff
--- a/spec/models/mtg/art_spec.rb
+++ b/spec/models/mtg/art_spec.rb
@@ -51,7 +51,8 @@ RSpec.describe MTG::Art, type: :model do
     end
 
     it "says when no build has run yet", :art_matching do
-      expect(described_class.status_line).to eq("Art matching: on; no build has run yet (it starts after the next catalog refresh)")
+      expect(described_class.status_line)
+        .to eq("Art matching: on; no build has run yet (it starts after the next catalog refresh, or from the admin catalog page)")
     end
 
     it "reports a running build's progress", :art_matching do
```

- [ ] Change `spec/jobs/catalog/refresh_job_spec.rb` (apply this diff exactly):

```diff
--- a/spec/jobs/catalog/refresh_job_spec.rb
+++ b/spec/jobs/catalog/refresh_job_spec.rb
@@ -18,6 +18,14 @@ RSpec.describe Catalog::RefreshJob, type: :job do
     expect(Catalog::Refresh).to have_received(:new).with("mtg", trigger: "scheduled", job_id: job.job_id)
   end
 
+  it "is followed by the art build when it applies with art matching on, as a scheduled refresh is (spec 015 AC-4.9)", :art_matching do
+    stub_scryfall(cards: [ scryfall_card ])
+
+    expect { described_class.perform_now("mtg", "manual") }.to have_enqueued_job(MTG::Art::BuildJob).once
+  ensure
+    FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir)
+  end
+
   it "retries transient source errors" do
     allow(Catalog::Refresh).to receive(:new).and_raise(Catalog::Sources::TransientError, "timeout")
 
```

- [ ] Run: `bin/rspec spec/models/mtg/art/operation_spec.rb spec/models/mtg/scryfall/source_spec.rb spec/models/mtg/art_spec.rb spec/jobs/catalog/refresh_job_spec.rb` — expect: FAIL (`uninitialized constant MTG::Art::Operation`, `undefined method 'title'`, the never-built wording). The new refresh job example passes already: it pins today's behaviour for AC-4.9.
- [ ] Create `app/models/mtg/art/operation.rb`:

```ruby
# The art index build as the admin catalog page shows it (spec 015 Story 4): MTG's one extra operation, offered through
# the source's .operations hook. Its state agrees with the art line of `catalog:status` (MTG::Art.status_line).
class MTG::Art::Operation < Catalog::Operation
  OFF = "Art matching is off. Set #{MTG::Art::ENV_NAME}=true to turn it on.".freeze
  NEEDS_CATALOG = "Refresh the catalog first: the art index is built from its cards.".freeze

  def key = "art_index"
  def title = "Art index"
  def queued_notice = "Art index build queued."
  def in_flight_notice = "An art index build is already queued or running."
  def job_class = MTG::Art::BuildJob

  # No button at all with art matching off (AC-4.6).
  def start_label = ("Build art index" if MTG::Art.enabled?)

  def unavailable_reason
    return OFF unless MTG::Art.enabled?

    NEEDS_CATALOG unless catalog_loaded?
  end

  def build
    return @build if defined?(@build)

    @build = MTG::ArtBuild.latest
  end

  # :off, :queued, :building, :interrupted, :never, :ready or :failed.
  def state
    @state ||=
      if !MTG::Art.enabled? then :off
      elsif build&.running? then build.stale? ? :interrupted : :building
      elsif queue.any? then :queued
      elsif build.nil? then :never
      else build.finished? ? :ready : :failed
      end
  end

  def record_running? = state == :building

  def failed_job? = state == :failed && super

  def summary
    case state
    when :off then OFF
    when :queued then "Queued."
    when :building then "Building."
    when :interrupted then "Interrupted. Build it again to carry on from where it stopped."
    when :never then catalog_loaded? ? "No build has run yet. One starts after the next catalog refresh, or you can start it here." : NEEDS_CATALOG
    when :ready then "Ready."
    when :failed then "Failed: #{build.message}"
    end
  end

  def meter
    return unless %i[building interrupted].include?(state)

    Meter.new(label: "Artworks fingerprinted", done: build.fingerprinted_count, total: build.total_count,
      text: "#{delimited(build.fingerprinted_count)} of #{delimited(build.total_count)} artworks fingerprinted")
  end

  def facts
    case state
    when :building, :interrupted
      [ fact("Started", build.started_at), fact("Images fetched", build.fetched_count), fact("Failed images", build.failed_count),
        fact("Last heartbeat", build.heartbeat_at, relative: true) ]
    when :ready
      [ fact("Finished", build.finished_at), fact("Artworks indexed", build.indexed_count),
        fact("Without an image", build.without_image_count), fact("Failed images", build.failed_count) ]
    when :failed
      [ fact("Finished", build.finished_at), fact("Index in use", MTG::Art::Index.current&.basename&.to_s || "none") ]
    else []
    end
  end

  private
    def catalog_loaded?
      return @catalog_loaded if defined?(@catalog_loaded)

      @catalog_loaded = Catalog::RefreshRun.for_type(collectible_type).applied.exists?
    end

    def delimited(number) = ActiveSupport::NumberHelper.number_to_delimited(number)
end
```

- [ ] Change `app/models/mtg/scryfall/source.rb` (apply this diff exactly):

```diff
--- a/app/models/mtg/scryfall/source.rb
+++ b/app/models/mtg/scryfall/source.rb
@@ -13,6 +13,10 @@ class MTG::Scryfall::Source
   # Spec 011 AC-3.11: extra lines for `catalog:status[mtg]`.
   def self.status_lines = [ MTG::Art.status_line ]
 
+  # Spec 015 FR-2: the name the admin catalog page gives this catalog, and what it can start besides the refresh.
+  def self.title = "Magic: The Gathering"
+  def self.operations(collectible_type) = [ MTG::Art::Operation.new(collectible_type) ]
+
   # Spec 015 FR-2: a callable the refresh sets; called with (done, total) bytes of the download, then of the file read.
   attr_writer :progress
 
```

- [ ] Change `app/models/mtg/art.rb` (apply this diff exactly):

```diff
--- a/app/models/mtg/art.rb
+++ b/app/models/mtg/art.rb
@@ -36,7 +36,7 @@ module MTG::Art
     return "Art matching: off (set #{ENV_NAME}=true to turn it on)" unless enabled?
 
     run = MTG::ArtBuild.latest
-    return "Art matching: on; no build has run yet (it starts after the next catalog refresh)" unless run
+    return "Art matching: on; no build has run yet (it starts after the next catalog refresh, or from the admin catalog page)" unless run
 
     progress = "#{run.fetched_count} images fetched, #{run.fingerprinted_count} of #{run.total_count} artworks fingerprinted"
     if run.running? && run.stale?
```

- [ ] Run: `bin/rspec spec/models spec/jobs spec/tasks` — expect: PASS.
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `feat(mtg): the art index as a catalog operation (015)`

---

## Phase 6: The jobs pages

**Implements:** FR-4, FR-5, FR-7, FR-8 | **Satisfies:** AC-6.1 to AC-6.11, AC-7.1 and AC-7.2 (jobs), and the poll controller for AC-2.10 to AC-2.12
**Files:** `app/models/background_jobs.rb`, `app/models/background_jobs/list.rb`, `app/models/background_jobs/entry.rb`, `app/controllers/admin/jobs_controller.rb`, `app/controllers/admin/jobs/retries_controller.rb`, `app/controllers/admin/jobs/discards_controller.rb`, `app/views/admin/jobs/index.html.erb`, `app/views/admin/jobs/show.html.erb`, `app/views/admin/jobs/discards/new.html.erb`, `app/helpers/admin_helper.rb`, `app/javascript/controllers/poll_controller.js`, `app/assets/stylesheets/collector/additions.css`, `config/routes.rb`, `docs/design-system/components/AdminJobs.md`, `docs/design-system/README.md`, `spec/models/background_jobs/list_spec.rb`, `spec/models/background_jobs/entry_spec.rb`, `spec/requests/admin/jobs_spec.rb`, `spec/system/admin_jobs_spec.rb`, `spec/support/query_counting.rb`, `spec/design_system_files_spec.rb`
**Interfaces:** Consumes: the `:solid_queue` tag and helpers (Phase 0); `Catalog::Pagination` and the partial `catalog/pagination` (existing). Produces: routes `admin_jobs_path`, `admin_job_path(id)`, `admin_job_retry_path(id)`, `new_admin_job_discard_path(id)`, `admin_job_discard_path(id)`; `BackgroundJobs::List.new(state:, page: nil)` with `STATES`, `#state`, `#counts`, `#entries`, `#pagination`, `#live?`, and `.live?`; `BackgroundJobs::Entry.find(id)` with `#state`, `#state_label`, `#failed?`, `#arguments`, `#arguments_text`, `#short_arguments`, `#list_note`, `#attempts`, `#queued_at`, `#due_at`, `#started_at`, `#failed_at`, `#listed_at`, `#error_class`, `#error_message`, `#error_line`, `#backtrace`, `#retry → true/false`, `#discard → true/false`; helpers `utc_time(time)`, `relative_time(time)`, `utc_time_with_relative(time)`, `admin_jobs_time_heading(state)`; the Stimulus controller `poll` (value `interval`, default 2000; method `refresh()`); the spec helper `count_queries { }` for request specs.

The jobs pages come before the catalog page, which links to them. They read Solid Queue's execution tables, offer retry and discard for failed jobs only, and keep themselves current with the new `poll` controller while a job is running or queued.

- [ ] Create `spec/models/background_jobs/list_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe BackgroundJobs::List, :solid_queue, type: :model do
  def list(state = "failed", page: nil) = described_class.new(state:, page:)

  def ids(state) = list(state).entries.map(&:id)

  it "counts the jobs in each state, with jobs waiting on a concurrency limit among the queued (spec 015 AC-6.1)" do
    fail_job(queue_job(MTG::Art::BuildJob))
    claim_job(queue_job(MTG::Art::BuildJob))
    queue_job(Catalog::RefreshJob, "mtg", "manual")
    queue_job(Catalog::RefreshJob, "mtg", "manual") # blocked behind the first
    queue_job(MTG::Art::BuildJob, wait: 5.minutes)
    finish_job(queue_job(MTG::Art::BuildJob))

    expect(list.counts).to eq("failed" => 1, "running" => 1, "queued" => 2, "scheduled" => 1)
  end

  it "shows the failed list for an unknown state", :aggregate_failures do
    expect(list("paused").state).to eq("failed")
    expect(list("queued").state).to eq("queued")
  end

  describe "#entries (AC-6.2)" do
    it "lists failed jobs, the latest failure first" do
      first = queue_job(MTG::Art::BuildJob)
      second = queue_job(MTG::Art::BuildJob)
      travel_to(2.minutes.ago) { fail_job(second) }
      fail_job(first)

      expect(ids("failed")).to eq([ first.id, second.id ])
    end

    it "lists running jobs, the latest start first" do
      first = queue_job(MTG::Art::BuildJob)
      second = queue_job(MTG::Art::BuildJob)
      travel_to(2.minutes.ago) { claim_job(first) }
      claim_job(second)

      expect(ids("running")).to eq([ second.id, first.id ])
    end

    it "lists queued jobs oldest first, ready and waiting together", :aggregate_failures do
      ready = travel_to(3.minutes.ago) { queue_job(Catalog::RefreshJob, "mtg", "manual") }
      waiting = travel_to(2.minutes.ago) { queue_job(Catalog::RefreshJob, "mtg", "scheduled") }
      other = queue_job(MTG::Art::BuildJob)

      expect(ids("queued")).to eq([ ready.id, waiting.id, other.id ])
      expect(list("queued").entries.map(&:state)).to eq(%i[queued waiting queued])
    end

    it "lists scheduled jobs, the soonest due first" do
      later = queue_job(MTG::Art::BuildJob, wait: 10.minutes)
      sooner = queue_job(MTG::Art::BuildJob, wait: 5.minutes)

      expect(ids("scheduled")).to eq([ sooner.id, later.id ])
    end

    it "shows 25 jobs a page and clamps the page to those there are", :aggregate_failures do
      26.times { fail_job(queue_job(MTG::Art::BuildJob)) }

      expect(list("failed").entries.size).to eq(25)
      expect(list("failed", page: "2").entries.size).to eq(1)
      expect(list("failed", page: "99").pagination).to have_attributes(page: 2, total_pages: 2)
      expect(list("failed", page: "nope").pagination.page).to eq(1)
    end
  end

  describe "#live? and .live? (AC-6.10)" do
    it "is live only while a job is running or queued, not for failed or scheduled ones", :aggregate_failures do
      fail_job(queue_job(MTG::Art::BuildJob))
      queue_job(MTG::Art::BuildJob, wait: 5.minutes)
      expect([ list.live?, described_class.live? ]).to eq([ false, false ])

      queued = queue_job(Catalog::RefreshJob, "mtg", "manual")
      expect([ list.live?, described_class.live? ]).to eq([ true, true ])

      claim_job(queued)
      expect([ list.live?, described_class.live? ]).to eq([ true, true ])
    end

    it "is live for a job waiting on a concurrency limit alone" do
      queue_job(Catalog::RefreshJob, "mtg", "manual").ready_execution.delete
      queue_job(Catalog::RefreshJob, "mtg", "manual")

      expect(described_class.live?).to be(true)
    end
  end
end
```

- [ ] Create `spec/models/background_jobs/entry_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe BackgroundJobs::Entry, :solid_queue, type: :model do
  def entry(job) = described_class.find(job.id)

  it "raises not found for a job the queue doesn't have" do
    expect { described_class.find(0) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "describes a queued job by the arguments it was queued with (spec 015 AC-6.2, AC-6.5)", :aggregate_failures do
    job = entry(queue_job(Catalog::RefreshJob, "mtg", "manual"))

    expect(job).to have_attributes(class_name: "Catalog::RefreshJob", queue_name: "sync", priority: 0, attempts: 0,
      arguments: %w[mtg manual], arguments_text: '["mtg","manual"]', short_arguments: '["mtg","manual"]',
      list_note: '["mtg","manual"]',
      state: :queued, state_label: "Queued", failed?: false, due_at: nil, started_at: nil, failed_at: nil)
    expect(job.listed_at).to eq(job.queued_at)
    expect(job.to_param).to eq(job.id.to_s)
  end

  it "shortens long arguments for a list row" do
    job = entry(queue_job(Catalog::RefreshJob, "x" * 200, "manual"))

    expect(job.short_arguments.length).to eq(80)
  end

  it "knows each state and the time that matters to it", :aggregate_failures do
    freeze_time do
      waiting = queue_job(Catalog::RefreshJob, "mtg", "manual") && entry(queue_job(Catalog::RefreshJob, "mtg", "manual"))
      scheduled = entry(queue_job(MTG::Art::BuildJob, wait: 5.minutes))
      running = entry(claim_job(queue_job(MTG::Art::BuildJob)))
      finished = entry(finish_job(queue_job(MTG::Art::BuildJob)))

      expect(waiting).to have_attributes(state: :waiting, state_label: "Queued, waiting", list_note: '["mtg","manual"] · waiting')
      expect(scheduled.list_note).to be_nil # a job without arguments has nothing to note
      expect(scheduled).to have_attributes(state: :scheduled, due_at: 5.minutes.from_now, listed_at: 5.minutes.from_now)
      expect(running).to have_attributes(state: :running, started_at: Time.current, listed_at: Time.current)
      expect(finished).to have_attributes(state: :finished, state_label: "Finished", finished_at: Time.current, failed?: false)
    end
  end

  context "with a failed job" do
    let(:job) { fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"), Catalog::Sources::TransientError.new("GET /bulk-data returned 503\nmore")) }

    it "gives the error, its first line for a list row, and the backtrace (AC-6.3, AC-6.5)", :aggregate_failures do
      expect(entry(job)).to have_attributes(state: :failed, failed?: true, error_class: "Catalog::Sources::TransientError",
        error_message: "GET /bulk-data returned 503\nmore", error_line: "Catalog::Sources::TransientError: GET /bulk-data returned 503",
        backtrace: [ "app/models/example.rb:1:in 'call'", "app/jobs/example_job.rb:2:in 'perform'" ])
      expect(entry(job).listed_at).to eq(entry(job).failed_at)
    end

    it "queues it to run again and takes it off the failed list (AC-6.6)", :aggregate_failures do
      expect(entry(job).retry).to be(true)
      expect(entry(job)).to have_attributes(state: :queued, failed?: false)
      expect(SolidQueue::FailedExecution.count).to eq(0)
    end

    it "removes it for good (AC-6.7)", :aggregate_failures do
      expect(entry(job).discard).to be(true)
      expect(SolidQueue::Job.count).to eq(0)
    end

    it "never touches a refresh run or an art build by retrying or discarding (AC-6.11)" do
      run = create(:catalog_refresh_run, status: "failed", job_id: job.active_job_id)
      build = create(:mtg_art_build, status: "failed")

      expect { entry(job).retry && entry(fail_job(queue_job(MTG::Art::BuildJob))).discard }
        .not_to(change { [ run.reload.attributes, build.reload.attributes ] })
    end
  end

  it "refuses to retry or discard a job that isn't failed, changing nothing (AC-6.8)", :aggregate_failures do
    queued = queue_job(MTG::Art::BuildJob)
    running = claim_job(queue_job(MTG::Art::BuildJob))

    expect([ entry(queued).retry, entry(queued).discard, entry(running).retry, entry(running).discard ]).to all(be(false))
    expect(SolidQueue::Job.count).to eq(2)
  end

  it "refuses when another admin handled the failed job in between (AC-6.8)", :aggregate_failures do
    stale = entry(fail_job(queue_job(MTG::Art::BuildJob)))
    stale.state # loaded as failed
    SolidQueue::FailedExecution.sole.retry

    expect(stale.retry).to be(false)
    expect(SolidQueue::Job.sole).to be_ready
  end

  it "describes, retries and discards a job whose class no longer exists (Error Scenarios)", :aggregate_failures do
    job = fail_job(queue_job(MTG::Art::BuildJob))
    job.update_columns(class_name: "Removed::InAnUpgradeJob") # rubocop:disable Rails/SkipsModelValidations -- as an upgrade leaves it

    expect(entry(job)).to have_attributes(class_name: "Removed::InAnUpgradeJob", state: :failed, arguments: [])
    expect(entry(job).retry).to be(true)
    expect(entry(job).state).to eq(:queued)
    expect(entry(fail_job(SolidQueue::Job.sole)).discard).to be(true)
  end

  it "describes a row whose arguments aren't a job's envelope, without failing", :aggregate_failures do
    job = queue_job(MTG::Art::BuildJob)
    job.update_columns(arguments: "not an envelope") # rubocop:disable Rails/SkipsModelValidations -- a row nothing in the app would write

    expect(entry(job)).to have_attributes(arguments: [], arguments_text: "[]", attempts: 0, list_note: nil)
  end

  it "shows the queue's own maintenance job by its command (glossary)" do
    job = SolidQueue::Job.enqueue(SolidQueue::RecurringJob.new("SolidQueue::Job.clear_finished_in_batches"))

    expect(entry(job)).to have_attributes(class_name: "SolidQueue::RecurringJob",
      arguments_text: '["SolidQueue::Job.clear_finished_in_batches"]')
  end
end
```

- [ ] Run: `bin/rspec spec/models/background_jobs` — expect: FAIL (`uninitialized constant BackgroundJobs`).
- [ ] Create `app/models/background_jobs.rb`:

```ruby
# The app's background jobs as the admin jobs page shows them (spec 015 Story 6), read from Solid Queue's own records
# (ADR 0014): every job in every queue, the queue's own maintenance jobs included.
module BackgroundJobs
end
```

- [ ] Create `app/models/background_jobs/list.rb`:

```ruby
# The jobs in one state, a page at a time, with how many are in each state (spec 015 AC-6.1, AC-6.2). The states are the
# queue's execution tables: failed, claimed by a worker (running), ready or blocked by a concurrency limit (queued), and
# due later (scheduled). Each state orders by the time that matters to it.
class BackgroundJobs::List
  STATES = %w[failed running queued scheduled].freeze
  PER_PAGE = 25
  ORDERS = {
    "failed" => Arel.sql("solid_queue_failed_executions.created_at DESC, solid_queue_jobs.id DESC"),
    "running" => Arel.sql("solid_queue_claimed_executions.created_at DESC, solid_queue_jobs.id DESC"),
    "queued" => Arel.sql("solid_queue_jobs.created_at ASC, solid_queue_jobs.id ASC"),
    "scheduled" => Arel.sql("solid_queue_scheduled_executions.scheduled_at ASC, solid_queue_jobs.id ASC")
  }.freeze

  attr_reader :state

  # True while any job is running or queued: the jobs pages keep themselves current then (AC-6.10).
  def self.live?
    SolidQueue::ClaimedExecution.exists? || SolidQueue::ReadyExecution.exists? || SolidQueue::BlockedExecution.exists?
  end

  # An unknown state shows the failed list; the page number is clamped to the pages there are.
  def initialize(state:, page: nil)
    @state = STATES.include?(state) ? state : STATES.first
    @requested_page = page
  end

  def counts
    @counts ||= { "failed" => SolidQueue::FailedExecution.count, "running" => SolidQueue::ClaimedExecution.count,
                  "queued" => SolidQueue::ReadyExecution.count + SolidQueue::BlockedExecution.count,
                  "scheduled" => SolidQueue::ScheduledExecution.count }
  end

  def live? = counts["running"].positive? || counts["queued"].positive?

  def pagination
    @pagination ||= Catalog::Pagination.for(total_count: counts.fetch(state), requested_page: @requested_page, per_page: PER_PAGE)
  end

  def entries
    @entries ||= jobs.order(ORDERS.fetch(state)).offset(pagination.offset).limit(PER_PAGE)
      .preload(:failed_execution, :claimed_execution, :ready_execution, :blocked_execution, :scheduled_execution)
      .map { |job| BackgroundJobs::Entry.new(job) }
  end

  private
    def jobs
      case state
      when "failed" then SolidQueue::Job.joins(:failed_execution)
      when "running" then SolidQueue::Job.joins(:claimed_execution)
      when "scheduled" then SolidQueue::Job.joins(:scheduled_execution)
      else
        SolidQueue::Job.where(id: SolidQueue::ReadyExecution.select(:job_id))
          .or(SolidQueue::Job.where(id: SolidQueue::BlockedExecution.select(:job_id)))
      end
    end
end
```

- [ ] Create `app/models/background_jobs/entry.rb`:

```ruby
# One job in the queue as the admin jobs pages show it (spec 015 AC-6.2 to AC-6.9): what it is, where it stands, and,
# for a failed one, why. Only a failed job can be retried or discarded, through the queue's own operations.
class BackgroundJobs::Entry
  STATE_LABELS = { failed: "Failed", running: "Running", waiting: "Queued, waiting", queued: "Queued",
                   scheduled: "Scheduled", finished: "Finished", unknown: "Unknown" }.freeze
  SHORT = 80

  attr_reader :job

  delegate :id, :class_name, :queue_name, :priority, :finished_at, to: :job

  # Raises ActiveRecord::RecordNotFound when the queue has no such job, so the request answers 404.
  def self.find(id) = new(SolidQueue::Job.find(id))

  def initialize(job)
    @job = job
  end

  def to_param = id.to_s

  # :failed, :running, :waiting (queued, blocked by a concurrency limit), :queued, :scheduled or :finished.
  def state
    if job.finished? then :finished
    elsif job.failed? then :failed
    elsif job.claimed? then :running
    elsif job.blocked? then :waiting
    elsif job.ready? then :queued
    elsif job.scheduled? then :scheduled
    else :unknown
    end
  end

  def state_label = STATE_LABELS.fetch(state)

  def failed? = state == :failed

  # The arguments the job was queued with, not the queue's envelope around them.
  def arguments = Array(envelope["arguments"])
  def arguments_text = ActiveSupport::JSON.encode(arguments)
  def short_arguments = arguments_text.truncate(SHORT)

  # Under the job's name in a list: its arguments when it has any, and that it waits on a concurrency limit.
  def list_note = [ (short_arguments if arguments.any?), ("waiting" if state == :waiting) ].compact.join(" · ").presence

  def attempts = envelope["executions"].to_i

  def queued_at = job.created_at
  def due_at = (job.scheduled_at if state == :scheduled)
  def started_at = job.claimed_execution&.created_at
  def failed_at = job.failed_execution&.created_at

  # The time the lists show and order by, for the state the job is in.
  def listed_at
    case state
    when :failed then failed_at
    when :running then started_at
    when :scheduled then job.scheduled_at
    when :finished then finished_at
    else queued_at
    end
  end

  def error_class = job.failed_execution&.exception_class
  def error_message = job.failed_execution&.message.to_s
  def backtrace = Array(job.failed_execution&.backtrace)

  # The exception class and the first line of its message, for a list row.
  def error_line = "#{error_class}: #{error_message.lines.first.to_s.strip}".truncate(2 * SHORT)

  # Queues a failed job to run again. False, changing nothing, when it isn't failed (any more).
  def retry
    return false unless failed?

    job.failed_execution.retry
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  # Removes a failed job for good. False, changing nothing, when it isn't failed (any more).
  def discard
    return false unless failed?

    job.failed_execution.discard
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  private
    # Active Job's record of the job, or nothing for a row that isn't one (nothing the app queues).
    def envelope = job.arguments.is_a?(Hash) ? job.arguments : {}
end
```

- [ ] Run: `bin/rspec spec/models/background_jobs` — expect: PASS (22 examples).
- [ ] Use the `collector-design-system` skill and read `docs/design-system/README.md` and the docs for `Chip`, `Menu`, `TableActions`, `ConfirmPage`, `Pager`, `EmptyState` and `Details` before writing the views below (CLAUDE.md).
- [ ] Create `spec/support/query_counting.rb`:

```ruby
# Counts the SQL queries a block runs, leaving out cached ones, schema lookups and transaction statements, so a spec
# can show a page's database work doesn't grow with its data.
module QueryCounting
  def count_queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
end

RSpec.configure { |config| config.include QueryCounting, type: :request }
```

- [ ] Create `spec/requests/admin/jobs_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin jobs pages", :solid_queue, type: :request do
  let(:admin) { create(:admin) }

  def page = Nokogiri::HTML5(response.body)

  # The node's text as a reader meets it: every piece of text, in order, a space apart.
  def text(node) = node.xpath(".//text()").map(&:text).join(" ").squish

  def rows = page.css(".c-jobs tbody tr")

  def failed_refresh(message = "GET /bulk-data returned 503")
    fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"), Catalog::Sources::TransientError.new(message))
  end

  context "when signed in as an admin" do
    before { sign_in_as(admin) }

    describe "the list (spec 015 AC-6.1 to AC-6.4)" do
      it "shows the failed list by default, with each state's count on its filter", :aggregate_failures do
        failed_refresh
        claim_job(queue_job(MTG::Art::BuildJob))
        2.times { queue_job(Catalog::RefreshJob, "mtg", "manual") }
        queue_job(MTG::Art::BuildJob, wait: 5.minutes)

        get admin_jobs_path

        filters = page.css(".c-jobs__filters button")
        expect(filters.map { |filter| [ text(filter), filter["aria-pressed"], filter["value"] ] }).to eq([ [ "Failed 1", "true", "failed" ],
          [ "Running 1", "false", "running" ], [ "Queued 2", "false", "queued" ], [ "Scheduled 1", "false", "scheduled" ] ])
        expect(rows.size).to eq(1)
        expect(text(page.at_css(".c-pagehead__stats"))).to eq("1 failed job")
      end

      it "shows a failed job's class, arguments, queue, failure time and error line, with its actions (AC-6.2, AC-6.3)", :aggregate_failures do
        job = travel_to(Time.utc(2026, 10, 9, 3, 15)) { failed_refresh("GET /bulk-data returned 503\nand more") }

        travel_to(Time.utc(2026, 10, 9, 3, 25)) { get admin_jobs_path(status: "failed") }

        cells = rows.first.css("td").map { |cell| text(cell) }
        expect(cells.first).to start_with('Catalog::RefreshJob ["mtg","manual"] Catalog::Sources::TransientError: GET /bulk-data returned 503 sync')
        expect(cells.first).not_to include("and more")
        expect(cells[1..2]).to eq([ "sync", "9 Oct 2026 03:15 UTC (10 minutes ago)" ])
        expect(rows.first.at_css("td a")["href"]).to eq(admin_job_path(job.id))
        expect(rows.first.at_css("form")["action"]).to eq(admin_job_retry_path(job.id))
        expect(rows.first.at_css(".c-menu__item--danger")["href"]).to eq(new_admin_job_discard_path(job.id))
      end

      it "marks queued jobs held by a concurrency limit as waiting, and offers them no actions (AC-6.2, AC-6.9)", :aggregate_failures do
        2.times { queue_job(Catalog::RefreshJob, "mtg", "manual") }

        get admin_jobs_path(status: "queued")

        expect(rows.map { |row| text(row.at_css(".c-jobs__detail")) }).to eq([ '["mtg","manual"]', '["mtg","manual"] · waiting' ])
        expect(page.css(".c-jobs .c-menu, .c-jobs form")).to be_empty
        expect(text(page.at_css(".c-jobs thead"))).to eq("Job Queue Queued Actions")
      end

      it "lists scheduled jobs with when they are due" do
        travel_to(Time.utc(2026, 10, 9, 3, 15)) do
          queue_job(MTG::Art::BuildJob, wait: 3.minutes)
          get admin_jobs_path(status: "scheduled")
        end

        expect(text(rows.first.css("td")[2])).to eq("9 Oct 2026 03:18 UTC (in 3 minutes)")
      end

      it "says when a state has no jobs (AC-6.4)", :aggregate_failures do
        get admin_jobs_path(status: "running")
        expect(text(page.at_css(".c-empty"))).to eq("No running jobs.")

        get admin_jobs_path(status: "nonsense")
        expect(text(page.at_css(".c-empty"))).to eq("No failed jobs.")
      end

      it "shows 25 jobs a page, with the pager keeping the state (AC-6.2)", :aggregate_failures do
        26.times { fail_job(queue_job(MTG::Art::BuildJob)) }

        get admin_jobs_path(status: "failed")
        expect(rows.size).to eq(25)
        expect(page.at_css(".c-pager a[rel=next]")["href"]).to eq(admin_jobs_path(status: "failed", page: 2))

        get admin_jobs_path(status: "failed", page: 2)
        expect(rows.size).to eq(1)
      end

      it "keeps itself current only while a job is running or queued (AC-6.10)", :aggregate_failures do
        failed_refresh
        queue_job(MTG::Art::BuildJob, wait: 5.minutes)
        get admin_jobs_path
        expect(page.at_css("[data-controller~='poll']")).to be_nil

        queue_job(MTG::Art::BuildJob)
        get admin_jobs_path
        expect(page.at_css("main")["data-controller"]).to eq("poll")
      end

      it "runs the same queries however many jobs it lists (NFR)" do
        2.times { failed_refresh }
        few = count_queries { get admin_jobs_path }
        9.times { failed_refresh }
        6.times { queue_job(MTG::Art::BuildJob) }

        expect(count_queries { get admin_jobs_path }).to eq(few)
      end
    end

    describe "a job's page (AC-6.5)" do
      it "shows a failed job in full, with Retry and Discard", :aggregate_failures do
        job = travel_to(Time.utc(2026, 10, 9, 3, 15)) { failed_refresh("GET /bulk-data returned <503>") }

        travel_to(Time.utc(2026, 10, 9, 3, 25)) { get admin_job_path(job.id) }

        main = text(page.at_css("main"))
        expect(main).to include("Catalog::RefreshJob Failed", "Queue sync", "Priority 0", "Attempts 0",
          "Queued 9 Oct 2026 03:15 UTC (10 minutes ago)", "Failed 9 Oct 2026 03:15 UTC (10 minutes ago)", 'Arguments ["mtg","manual"]',
          "Catalog::Sources::TransientError : GET /bulk-data returned <503>", "app/models/example.rb:1:in 'call'")
        expect(response.body).to include("returned &lt;503&gt;")
        expect(page.at_css("main form")["action"]).to eq(admin_job_retry_path(job.id))
        expect(page.at_css("main a.c-btn--danger")["href"]).to eq(new_admin_job_discard_path(job.id))
      end

      it "shows a running, a scheduled and a finished job without actions (AC-6.5, AC-6.9)", :aggregate_failures do
        running = claim_job(queue_job(MTG::Art::BuildJob))
        scheduled = queue_job(MTG::Art::BuildJob, wait: 5.minutes)
        finished = finish_job(queue_job(MTG::Art::BuildJob))

        { running => [ "Running", "Started" ], scheduled => [ "Scheduled", "Due" ], finished => [ "Finished", "Finished" ] }.each do |job, (state, label)|
          get admin_job_path(job.id)
          expect(text(page.at_css(".c-pagehead__stats"))).to eq(state)
          expect(page.css(".c-details dt").map { |term| text(term) }).to include(label)
          expect(page.css("main form, main a.c-btn--danger")).to be_empty
        end
      end

      it "renders a job whose class no longer exists (Error Scenarios)", :aggregate_failures do
        job = failed_refresh
        job.update_columns(class_name: "Removed::InAnUpgradeJob") # rubocop:disable Rails/SkipsModelValidations -- as an upgrade leaves it

        get admin_job_path(job.id)

        expect(response).to have_http_status(:ok)
        expect(text(page.at_css("h1"))).to eq("Removed::InAnUpgradeJob")
      end

      it "keeps itself current only while a job is running or queued (AC-6.10)", :aggregate_failures do
        job = failed_refresh
        get admin_job_path(job.id)
        expect(page.at_css("[data-controller~='poll']")).to be_nil

        queue_job(MTG::Art::BuildJob)
        get admin_job_path(job.id)
        expect(page.at_css("main")["data-controller"]).to eq("poll")
      end

      it "answers 404 for a job the queue doesn't have" do
        get admin_job_path(0)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "retrying (AC-6.6, AC-6.8)" do
      it "queues a failed job again and says so", :aggregate_failures do
        job = failed_refresh

        post admin_job_retry_path(job.id)

        expect(response).to redirect_to(admin_jobs_path(status: "failed")).and have_http_status(:see_other)
        expect(flash[:notice]).to eq("Retrying Catalog::RefreshJob.")
        expect(SolidQueue::FailedExecution.count).to eq(0)
        expect(job.reload).to be_ready
      end

      it "changes nothing for a job that isn't failed, and says so", :aggregate_failures do
        job = queue_job(MTG::Art::BuildJob)

        post admin_job_retry_path(job.id)

        expect(response).to redirect_to(admin_jobs_path)
        expect(flash[:alert]).to eq("That job isn't failed any more.")
        expect(job.reload).to be_ready
      end

      it "answers 404 for a job that is gone" do
        post admin_job_retry_path(0)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "discarding (AC-6.7, AC-6.8)" do
      it "asks first, naming the job and what happens", :aggregate_failures do
        job = failed_refresh

        get new_admin_job_discard_path(job.id)

        expect(text(page.at_css(".c-confirm"))).to eq("Discard Catalog::RefreshJob? This removes the failed job " \
          '(["mtg","manual"]) from the queue. It won\'t run again, and it can\'t be undone. Discard Catalog::RefreshJob Cancel')
        expect(page.at_css(".c-confirm form")["action"]).to eq(admin_job_discard_path(job.id))
        expect(page.at_css(".c-confirm a")["href"]).to eq(admin_jobs_path(status: "failed"))
        expect(SolidQueue::Job.count).to eq(1)
      end

      it "removes the job on confirmation and says so", :aggregate_failures do
        job = failed_refresh

        post admin_job_discard_path(job.id)

        expect(response).to redirect_to(admin_jobs_path(status: "failed")).and have_http_status(:see_other)
        expect(flash[:notice]).to eq("Discarded Catalog::RefreshJob.")
        expect(SolidQueue::Job.count).to eq(0)
      end

      it "changes nothing for a job that isn't failed, on either step", :aggregate_failures do
        job = claim_job(queue_job(MTG::Art::BuildJob))

        get new_admin_job_discard_path(job.id)
        expect(response).to redirect_to(admin_jobs_path)
        post admin_job_discard_path(job.id)
        expect(flash[:alert]).to eq("That job isn't failed any more.")
        expect(job.reload).to be_claimed
      end

      it "answers 404 for a job that is gone" do
        post admin_job_discard_path(0)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  it "is invisible to a member: 404 everywhere, and nothing changes (AC-7.1)", :aggregate_failures do
    job = failed_refresh
    sign_in_as(create(:user))

    [ -> { get admin_jobs_path }, -> { get admin_job_path(job.id) }, -> { post admin_job_retry_path(job.id) },
      -> { get new_admin_job_discard_path(job.id) }, -> { post admin_job_discard_path(job.id) } ].each do |request|
      request.call
      expect(response).to have_http_status(:not_found)
    end
    expect(job.reload).to be_failed
  end

  it "sends a visitor who isn't signed in to sign in (AC-7.2)", :aggregate_failures do
    create(:admin)
    job = failed_refresh

    [ -> { get admin_jobs_path }, -> { post admin_job_retry_path(job.id) }, -> { post admin_job_discard_path(job.id) } ].each do |request|
      request.call
      expect(response).to redirect_to(new_session_path)
    end
    expect(job.reload).to be_failed
  end
end
```

- [ ] Create `spec/system/admin_jobs_spec.rb`:

```ruby
require "rails_helper"

# Spec 015 Story 6 in a browser: an admin retries one failed job and discards another, and the page keeps itself
# current while a job is queued. No worker runs in tests, so the example plays the worker's part.
RSpec.describe "Admin jobs page", :solid_queue, type: :system do
  let(:admin) { create(:admin) }
  # Calls the poll controller's refresh by hand in each state that should hold it, then once more with nothing in the
  # way, and returns the visits Turbo started: [[path, action], …].
  let(:held_refreshes_js) { <<~JS }
    (() => {
      const poll = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("main"), "poll")
      clearInterval(poll.timer)
      const visits = []
      document.addEventListener("turbo:visit", (event) => visits.push([ new URL(event.detail.url).pathname, event.detail.action ]))
      const menu = document.querySelector("details.c-menu")
      menu.open = true; poll.refresh()
      menu.open = false
      document.documentElement.setAttribute("aria-busy", "true"); poll.refresh()
      document.documentElement.removeAttribute("aria-busy")
      Object.defineProperty(document, "hidden", { value: true, configurable: true }); poll.refresh()
      delete document.hidden
      poll.refresh()
      return visits
    })()
  JS

  def failed_job(job_class, *arguments, message:) = fail_job(queue_job(job_class, *arguments), RuntimeError.new(message))

  def open_actions(job)
    find("summary[aria-label='Actions for #{job.class_name} #{job.id}']").click
  end

  it "retries a failed job from its row (AC-6.6)", :aggregate_failures do
    refresh = failed_job(Catalog::RefreshJob, "mtg", "manual", message: "the download broke")
    system_sign_in_as(admin)
    visit admin_jobs_path
    expect(page).to have_css(".c-filter[aria-pressed='true']", text: "Failed 1", normalize_ws: true)

    open_actions(refresh)
    click_button "Retry"

    expect(page).to have_css("#status", text: "Retrying Catalog::RefreshJob.")
    expect(page).to have_css(".c-filter", text: "Queued 1", normalize_ws: true)
    expect(page).to have_css(".c-empty", text: "No failed jobs.")
  end

  it "discards a failed job only after it is confirmed (AC-6.7)", :aggregate_failures do
    build = failed_job(MTG::Art::BuildJob, message: "the disk is full")
    system_sign_in_as(admin)
    visit admin_jobs_path
    open_actions(build)
    click_link "Discard…"
    expect(page).to have_css("h1", text: "Discard MTG::Art::BuildJob?")
    click_link "Cancel"
    expect(page).to have_text("the disk is full")

    open_actions(build)
    click_link "Discard…"
    click_button "Discard MTG::Art::BuildJob"

    expect(page).to have_css("#status", text: "Discarded MTG::Art::BuildJob.")
    expect(page).to have_css(".c-empty", text: "No failed jobs.")
    expect(SolidQueue::Job.count).to eq(0)
  end

  it "opens a failed job's page with its error and backtrace, and retries it there (AC-6.5, AC-6.6)", :aggregate_failures do
    failed_job(Catalog::RefreshJob, "mtg", "manual", message: "the download broke")
    system_sign_in_as(admin)
    visit admin_jobs_path

    click_link "Catalog::RefreshJob"
    expect(page).to have_css("h1", text: "Catalog::RefreshJob")
    expect(page).to have_css(".c-pre", text: "app/models/example.rb:1:in 'call'")

    click_button "Retry"
    expect(page).to have_css("#status", text: "Retrying Catalog::RefreshJob.")
  end

  it "shows jobs changing state by itself, and stops asking when none is running or queued (AC-6.10)", :aggregate_failures do
    job = queue_job(MTG::Art::BuildJob)
    system_sign_in_as(admin)
    visit admin_jobs_path(status: "queued")
    expect(page).to have_css(".c-jobs tbody tr", count: 1)

    using_wait_time(5) do
      claim_job(job)
      expect(page).to have_css(".c-filter", text: "Running 1", normalize_ws: true)
      expect(page).to have_css(".c-empty", text: "No queued jobs.")

      fail_job(job)
      expect(page).to have_css(".c-filter", text: "Failed 1", normalize_ws: true)
      expect(page).to have_no_css("[data-controller~='poll']")
    end
  end

  it "holds its refresh while a menu is open, Turbo is busy or the tab is hidden (FR-4)", :aggregate_failures do
    queue_job(MTG::Art::BuildJob)
    system_sign_in_as(admin)
    visit admin_jobs_path
    expect(page).to have_css("main[data-controller~='poll']")

    expect(page.evaluate_script(held_refreshes_js)).to eq([ [ admin_jobs_path, "replace" ] ])
  end
end
```

- [ ] Change `spec/design_system_files_spec.rb` (apply this diff exactly):

```diff
--- a/spec/design_system_files_spec.rb
+++ b/spec/design_system_files_spec.rb
@@ -17,7 +17,8 @@ RSpec.describe "Design system files" do
   it "documents every new pattern and lists it in the README", :aggregate_failures do
     new_patterns = %w[StatusMessage Form AuthPage ConfirmPage SearchResults TileAdd FinishBadge FilterSelect Pager EmptyState
       Details SingleStat MorePage AdminUsers TableActions SystemLogo
-      SortHeader StatusAction BulkConfirmPage ChoicePage BulkForm ViewSwitchForm TableItemLink Scanner]
+      SortHeader StatusAction BulkConfirmPage ChoicePage BulkForm ViewSwitchForm TableItemLink Scanner
+      AdminJobs]
     readme = root.join("docs/design-system/README.md").read
     new_patterns.each do |name|
       expect(root.join("docs/design-system/components/#{name}.md")).to exist
```

- [ ] Run: `bin/rspec spec/requests/admin/jobs_spec.rb spec/system/admin_jobs_spec.rb spec/design_system_files_spec.rb` — expect: FAIL (`undefined method 'admin_jobs_path'`; no `AdminJobs.md`).
- [ ] Change `config/routes.rb` (apply this diff exactly):

```diff
--- a/config/routes.rb
+++ b/config/routes.rb
@@ -74,6 +74,14 @@ Rails.application.routes.draw do
       resource :deletion, only: :new, module: :users
     end
     resource :sign_up_setting, only: :update
+
+    # Background jobs (spec 015).
+    resources :jobs, only: %i[index show] do
+      scope module: :jobs do
+        resource :retry, only: :create
+        resource :discard, only: %i[new create]
+      end
+    end
   end
 
   # Defines the root path route ("/")
```

- [ ] Create `app/helpers/admin_helper.rb`:

```ruby
# What the admin pages share (spec 015): times in UTC (FR-8).
module AdminHelper
  # "9 Oct 2026 03:15 UTC", in a <time> element carrying the exact instant.
  def utc_time(time) = time_tag(time.utc, time.utc.strftime("%-d %b %Y %H:%M UTC"))

  # "2 minutes ago", or "in 3 minutes" for a time still to come.
  def relative_time(time)
    words = distance_of_time_in_words(Time.current, time)
    time.future? ? "in #{words}" : "#{words} ago"
  end

  # The UTC time with the relative form after it: "9 Oct 2026 03:15 UTC (2 minutes ago)".
  def utc_time_with_relative(time) = safe_join([ utc_time(time), " (#{relative_time(time)})" ])

  JOBS_TIME_HEADINGS = { "failed" => "Failed", "running" => "Started", "queued" => "Queued", "scheduled" => "Due" }.freeze

  # The heading of the jobs list's time column: the time that matters to the state shown.
  def admin_jobs_time_heading(state) = JOBS_TIME_HEADINGS.fetch(state)
end
```

- [ ] Create `app/controllers/admin/jobs_controller.rb`:

```ruby
# The admin jobs pages (spec 015 Story 6, ADR 0014): the queue's jobs by state, and one job in full.
class Admin::JobsController < ApplicationController
  include AdminOnly

  def index
    @list = BackgroundJobs::List.new(state: params[:status].to_s, page: params[:page])
  end

  def show
    @job = BackgroundJobs::Entry.find(params[:id])
    @live = BackgroundJobs::List.live?
  end
end
```

- [ ] Create `app/controllers/admin/jobs/retries_controller.rb`:

```ruby
# Queues a failed job to run again (spec 015 AC-6.6, AC-6.8).
class Admin::Jobs::RetriesController < ApplicationController
  include AdminOnly

  def create
    job = BackgroundJobs::Entry.find(params[:job_id])
    if job.retry
      redirect_to admin_jobs_path(status: "failed"), notice: "Retrying #{job.class_name}.", status: :see_other
    else
      redirect_to admin_jobs_path, alert: "That job isn't failed any more.", status: :see_other
    end
  end
end
```

- [ ] Create `app/controllers/admin/jobs/discards_controller.rb`:

```ruby
# Removes a failed job, after a confirmation page that works without scripting (spec 015 AC-6.7, AC-6.8).
class Admin::Jobs::DiscardsController < ApplicationController
  include AdminOnly

  before_action :set_job

  def new
    redirect_to admin_jobs_path, alert: "That job isn't failed any more.", status: :see_other unless @job.failed?
  end

  def create
    if @job.discard
      redirect_to admin_jobs_path(status: "failed"), notice: "Discarded #{@job.class_name}.", status: :see_other
    else
      redirect_to admin_jobs_path, alert: "That job isn't failed any more.", status: :see_other
    end
  end

  private
    def set_job = @job = BackgroundJobs::Entry.find(params[:job_id])
end
```

- [ ] Create `app/views/admin/jobs/index.html.erb`:

```erb
<% content_for :title, "Jobs · Collector" %>
<%= render "layouts/appbar", section: nil %>
<%# The page keeps itself current only while a job is running or queued (spec 015 AC-6.10). %>
<%= tag.main class: "c-main", data: { controller: ("poll" if @list.live?) } do %>
  <div class="c-pagehead">
    <div><h1 class="c-pagehead__title">Jobs</h1><p class="c-pagehead__stats"><%= pluralize(@list.counts.fetch("failed"), "failed job") %></p></div>
  </div>

  <%= form_with url: admin_jobs_path, method: :get, class: "c-jobs__filters" do %>
    <% BackgroundJobs::List::STATES.each do |state| %>
      <%= button_tag name: "status", value: state, class: "c-filter", aria: { pressed: state == @list.state } do %><%= state.humanize %> <span class="c-jobs__count"><%= number_with_delimiter(@list.counts.fetch(state)) %></span><% end %>
    <% end %>
  <% end %>

  <% if @list.entries.empty? %>
    <p class="c-empty">No <%= @list.state %> jobs.</p>
  <% else %>
    <div class="c-collection">
      <table class="c-table c-jobs">
        <thead><tr><th>Job</th><th class="is-opt">Queue</th><th class="is-opt"><%= admin_jobs_time_heading(@list.state) %></th><th><span class="c-sr">Actions</span></th></tr></thead>
        <tbody>
          <% @list.entries.each do |job| %>
            <tr>
              <td class="c-jobs__job">
                <div class="c-table__item"><div>
                  <%= link_to job.class_name, admin_job_path(job) %>
                  <% if job.list_note %><span class="c-jobs__detail"><%= job.list_note %></span><% end %>
                  <% if job.failed? %><span class="c-jobs__detail"><%= job.error_line %></span><% end %>
                  <span class="c-table__sub"><%= job.queue_name %> · <%= utc_time_with_relative(job.listed_at) %></span>
                </div></div>
              </td>
              <td class="is-opt is-data"><%= job.queue_name %></td>
              <td class="is-opt"><%= utc_time_with_relative(job.listed_at) %></td>
              <td class="c-table__actions">
                <% if job.failed? %>
                  <details class="c-menu" data-controller="menu">
                    <summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for <%= job.class_name %> <%= job.id %>"><%= render "icons/more" %></summary>
                    <div class="c-menu__list">
                      <%= button_to "Retry", admin_job_retry_path(job), class: "c-menu__item", form: { class: "c-menu__form" } %>
                      <div class="c-menu__sep"></div>
                      <%= link_to "Discard…", new_admin_job_discard_path(job), class: "c-menu__item c-menu__item--danger" %>
                    </div>
                  </details>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    <%= render "catalog/pagination", pagination: @list.pagination, link_params: { status: @list.state } %>
  <% end %>
<% end %>
<%= render "layouts/tabbar", section: nil %>
```

- [ ] Create `app/views/admin/jobs/show.html.erb`:

```erb
<% content_for :title, "#{@job.class_name} · Jobs · Collector" %>
<%= render "layouts/appbar", section: nil, detail: true, back_path: admin_jobs_path %>
<%= tag.main class: "c-main c-page", data: { controller: ("poll" if @live) } do %>
  <ol class="c-crumbs"><li><%= link_to "Jobs", admin_jobs_path %></li><li><%= @job.class_name %></li></ol>
  <div class="c-pagehead">
    <div><h1 class="c-pagehead__title c-job__title"><%= @job.class_name %></h1><p class="c-pagehead__stats"><%= @job.state_label %></p></div>
  </div>

  <% if @job.failed? %>
    <div class="c-form__actions c-job__actions">
      <%= button_to "Retry", admin_job_retry_path(@job), class: "c-btn c-btn--primary" %>
      <%= link_to "Discard…", new_admin_job_discard_path(@job), class: "c-btn c-btn--danger" %>
    </div>
  <% end %>

  <section class="c-job__section">
    <dl class="c-details">
      <div><dt>Queue</dt><dd class="is-data"><%= @job.queue_name %></dd></div>
      <div><dt>Priority</dt><dd class="is-data"><%= @job.priority %></dd></div>
      <div><dt>Attempts</dt><dd class="is-data"><%= @job.attempts %></dd></div>
      <div><dt>Queued</dt><dd><%= utc_time_with_relative(@job.queued_at) %></dd></div>
      <% if @job.due_at %><div><dt>Due</dt><dd><%= utc_time_with_relative(@job.due_at) %></dd></div><% end %>
      <% if @job.started_at %><div><dt>Started</dt><dd><%= utc_time_with_relative(@job.started_at) %></dd></div><% end %>
      <% if @job.failed_at %><div><dt>Failed</dt><dd><%= utc_time_with_relative(@job.failed_at) %></dd></div><% end %>
      <% if @job.finished_at %><div><dt>Finished</dt><dd><%= utc_time_with_relative(@job.finished_at) %></dd></div><% end %>
    </dl>
  </section>

  <section class="c-job__section">
    <div class="c-section__head"><h2 class="c-section__title">Arguments</h2></div>
    <pre class="c-pre"><%= @job.arguments_text %></pre>
  </section>

  <% if @job.failed? %>
    <section class="c-job__section">
      <div class="c-section__head"><h2 class="c-section__title">Error</h2></div>
      <p class="c-job__error"><strong><%= @job.error_class %></strong>: <%= @job.error_message %></p>
      <% if @job.backtrace.any? %><pre class="c-pre"><%= @job.backtrace.join("\n") %></pre><% end %>
    </section>
  <% end %>
<% end %>
<%= render "layouts/tabbar", section: nil %>
```

- [ ] Create `app/views/admin/jobs/discards/new.html.erb`:

```erb
<% content_for :title, "Discard #{@job.class_name} · Collector" %>
<%= render "layouts/appbar", section: nil %>
<main class="c-main c-page">
  <section class="c-confirm">
    <h1 class="c-pagehead__title c-job__title">Discard <%= @job.class_name %>?</h1>
    <p>This removes the failed job (<%= @job.short_arguments %>) from the queue. It won't run again, and it can't be undone.</p>
    <div class="c-form__actions">
      <%= button_to "Discard #{@job.class_name}", admin_job_discard_path(@job), class: "c-btn c-btn--danger" %>
      <%= link_to "Cancel", admin_jobs_path(status: "failed"), class: "c-btn c-btn--secondary" %>
    </div>
  </section>
</main>
<%= render "layouts/tabbar", section: nil %>
```

- [ ] Create `app/javascript/controllers/poll_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

// Keeps a page current while work is in flight (spec 015 FR-4, ADR 0015): every interval it asks Turbo to refresh the
// page, which morphs in what changed and keeps the scroll position. The server renders this controller only while
// something is queued or running, so when the work ends the refreshed page has no controller and the polling stops.
// It waits while the tab is hidden, while Turbo is busy, and while a menu is open (a refresh would close it).
export default class extends Controller {
  static values = { interval: { type: Number, default: 2000 } }

  connect() {
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  refresh() {
    if (document.hidden || document.documentElement.hasAttribute("aria-busy")) return
    if (document.querySelector("details[open]")) return
    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
```

- [ ] Change `app/assets/stylesheets/collector/additions.css` (apply this diff exactly):

```diff
--- a/app/assets/stylesheets/collector/additions.css
+++ b/app/assets/stylesheets/collector/additions.css
@@ -167,3 +167,15 @@
 .c-scanner__hint { margin:0; font:400 14px/20px var(--font-sans); color:var(--ink-muted); }
 /* Art matching's status under the scanner's controls (spec 011 AC-5.1): quiet, like the hint. */
 .c-scanner__art { margin:0; font:400 14px/20px var(--font-sans); color:var(--ink-muted); }
+
+/* ---------- Admin jobs (spec 015): state filters over the jobs table, and one job's page ---------- */
+.c-jobs__filters { display:flex; flex-wrap:wrap; gap:var(--space-2); margin:var(--space-6) 0 var(--space-4); }
+.c-jobs__count { font-family:var(--font-mono); color:var(--ink-muted); }
+.c-jobs td.c-jobs__job { white-space:normal; overflow-wrap:anywhere; }
+.c-jobs__detail { display:block; font:400 12px/16px var(--font-mono); color:var(--ink-muted); }
+.c-job__title { overflow-wrap:anywhere; }
+.c-job__actions { margin:var(--space-4) 0; }
+.c-job__section { margin-top:var(--space-6); }
+.c-job__error { margin:0 0 var(--space-2); font:400 15px/22px var(--font-sans); color:var(--ink); overflow-wrap:anywhere; }
+.c-pre { margin:0; padding:var(--space-3); overflow-x:auto; background:var(--surface-sunken); border-radius:var(--radius-md);
+  font:400 12px/16px var(--font-mono); color:var(--ink); }
```

- [ ] Create `docs/design-system/components/AdminJobs.md`:

````markdown
# AdminJobs

The admin's jobs pages (spec 015): the background jobs by state, one job in full, and the confirmation before a failed job is discarded.

**Markup, the list** — a `c-pagehead`, a GET form of `Chip` filter chips with each state's count, then a `c-table c-jobs` inside `.c-collection`, a `Pager`, or an `EmptyState`.

```html
<form class="c-jobs__filters" action="/admin/jobs" method="get">
  <button name="status" value="failed" class="c-filter" aria-pressed="true">Failed <span class="c-jobs__count">2</span></button>
  <button name="status" value="running" class="c-filter" aria-pressed="false">Running <span class="c-jobs__count">0</span></button>
  …
</form>

<div class="c-collection">
  <table class="c-table c-jobs">
    <thead><tr><th>Job</th><th class="is-opt">Queue</th><th class="is-opt">Failed</th><th><span class="c-sr">Actions</span></th></tr></thead>
    <tbody>
      <tr>
        <td class="c-jobs__job"><div class="c-table__item"><div>
          <a href="/admin/jobs/12">Catalog::RefreshJob</a>
          <span class="c-jobs__detail">["mtg","manual"]</span>
          <span class="c-jobs__detail">Catalog::Sources::TransientError: GET /bulk-data returned 503</span>
          <span class="c-table__sub">sync · 9 Oct 2026 03:15 UTC (10 minutes ago)</span>
        </div></div></td>
        <td class="is-opt is-data">sync</td>
        <td class="is-opt">9 Oct 2026 03:15 UTC (10 minutes ago)</td>
        <td class="c-table__actions">…"…" menu: Retry, Discard…</td>
      </tr>
    </tbody>
  </table>
</div>
```

**Markup, one job** — a detail page (`c-main c-page`, `c-appbar--detail`, `c-crumbs`): the job's class as the title with its state under it, "Retry" and "Discard…" for a failed job, a `Details` list, then its arguments and, for a failed job, the error and backtrace in `pre.c-pre`.

- The filters are a GET form, so the state is in the URL (`?status=failed`) and works without scripting. The pressed chip is the state on show; "Failed" is the default.
- The time column is the one that matters to the state (Failed, Started, Queued, Due) and its heading says which. Times are absolute UTC with the relative form in brackets.
- The job cell wraps (`c-jobs__job`), so a long error never forces sideways scrolling; `c-jobs__detail` lines are mono and `ink-muted`. Queue and time are `is-opt` columns that drop on phones and reappear in the `c-table__sub` line.
- A queued job held back by a concurrency limit says "waiting" after its arguments.
- Only a failed job has actions. "Retry" acts at once and is announced in the status message ("Retrying Catalog::RefreshJob."). "Discard…" leads to a `ConfirmPage` that names the job and says it won't run again.
- An empty state names the state: "No failed jobs."
- `pre.c-pre` is `surface-sunken`, mono, and scrolls sideways inside itself.
- While any job is running or queued, `<main>` carries `data-controller="poll"`: the page refreshes itself about every 2 seconds with a Turbo morph, keeping the scroll position, and stops when no job is running or queued. The refresh waits while a row's menu is open. Nothing on the page needs the script: reloading shows the same thing.
````

- [ ] Change `docs/design-system/README.md` (apply this diff exactly):

```diff
--- a/docs/design-system/README.md
+++ b/docs/design-system/README.md
@@ -94,6 +94,8 @@ App additions (spec 006, in `collector/additions.css`): `SortHeader`, `StatusAct
 
 App additions (spec 007, in `collector/additions.css`): `Scanner`. Upstream it into the published design system before the next export replaces this folder.
 
+App additions (spec 015, in `collector/additions.css`): `AdminJobs`. Upstream it into the published design system before the next export replaces this folder.
+
 ## Logo
 
 - The mark is three fanned cards, the front one vault teal with a foil diamond: a collection, one piece of which is special. It is deliberately game-neutral so it grows past trading cards.
```

- [ ] Run: `bin/rspec spec/requests/admin/jobs_spec.rb spec/system/admin_jobs_spec.rb spec/design_system_files_spec.rb` — expect: PASS.
- [ ] Run: `bin/rspec spec/requests spec/models/background_jobs && bin/brakeman -q --no-pager` — expect: PASS, and no warnings.
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `feat(admin): jobs pages with retry and discard for failed jobs (015)`

---

## Phase 7: The catalog page

**Implements:** FR-3, FR-4, FR-7, FR-8 | **Satisfies:** AC-1.4, AC-2.1 to AC-2.8, AC-2.10 to AC-2.14, AC-2.16, AC-3.1, AC-3.2, AC-3.6, AC-3.7, AC-4.1 to AC-4.8, AC-5.1 to AC-5.3, AC-5.5, AC-5.6, AC-7.1, AC-7.2, AC-7.4
**Files:** `app/controllers/admin/catalogs_controller.rb`, `app/controllers/admin/catalogs/operation_starts_controller.rb`, `app/views/admin/catalogs/show.html.erb`, `app/views/admin/catalogs/_catalog.html.erb`, `app/views/admin/catalogs/_operation.html.erb`, `app/views/admin/catalogs/_meter.html.erb`, `app/views/admin/jobs/index.html.erb`, `app/helpers/admin_helper.rb`, `app/assets/stylesheets/collector/additions.css`, `config/routes.rb`, `docs/design-system/components/AdminCatalog.md`, `docs/design-system/components/StageList.md`, `docs/design-system/components/ProgressMeter.md`, `docs/design-system/components/AdminJobs.md`, `docs/design-system/README.md`, `spec/requests/admin/catalogs_spec.rb`, `spec/requests/admin/jobs_spec.rb`, `spec/system/admin_catalog_spec.rb`, `spec/system/narrow_admin_pages_spec.rb`, `spec/design_system_files_spec.rb`
**Interfaces:** Consumes: `Catalog::Health`, `Catalog::Operation` and its value objects, `Catalog::RefreshOperation#status_label(run)` (Phase 4); `MTG::Art::Operation` (Phase 5); the `poll` controller, `utc_time`, `utc_time_with_relative`, `count_queries`, `admin_jobs_path` (Phase 6); the `:other_catalog` tag (Phase 4). Produces: routes `admin_catalog_path` and `admin_catalog_operation_starts_path` (POST; params `collectible_type`, `operation`); helpers `fact_value(fact)`, `stage_word(stage)`, `refresh_run_outcome(run)`; the element ids `catalog_<type>` (panel) and `<type>_<operation key>` (operation).

One panel per catalog type, rendered only from `Catalog::Health` and its operations, with a start button per operation and the page polling while anything is in flight. The jobs page gets its link back to the catalog.

- [ ] Use the `collector-design-system` skill and read the docs for `EmptyState`, `Details`, `Button` and `AdminJobs` before writing the views below (CLAUDE.md).
- [ ] Create `spec/requests/admin/catalogs_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "Admin catalog page", :solid_queue, type: :request do
  let(:admin) { create(:admin) }

  def page = Nokogiri::HTML5(response.body)

  def panel(collectible_type = "mtg") = page.at_css("#catalog_#{collectible_type}")

  def section(key, collectible_type = "mtg") = page.at_css("##{collectible_type}_#{key}")

  # The node's text as a reader meets it: every piece of text, in order, a space apart.
  def text(node) = node.xpath(".//text()").map(&:text).join(" ").squish

  def start(operation, collectible_type: "mtg") = post admin_catalog_operation_starts_path, params: { collectible_type:, operation: }

  def running(**attributes) = create(:catalog_refresh_run, :running, **attributes)

  context "when signed in as an admin" do
    before { sign_in_as(admin) }

    describe "a catalog that isn't loaded (spec 015 Story 1)" do
      it "says so, with the languages, and makes the refresh the primary action (AC-1.4)", :aggregate_failures do
        get admin_catalog_path

        expect(text(panel.at_css(".c-empty"))).to eq("No cards are loaded yet. The first refresh downloads the source's " \
          "card data and may take several minutes. Languages: EN.")
        expect(section("refresh").at_css("button").to_h).to include("class" => "c-btn c-btn--primary")
        expect(section("refresh").at_css("button")["disabled"]).to be_nil
        expect(page.at_css("[data-controller~='poll']")).to be_nil
      end

      it "drops the empty state once a refresh is in flight" do
        queue_job(Catalog::RefreshJob, "mtg", "manual")

        get admin_catalog_path

        expect(panel.at_css(".c-empty")).to be_nil
      end
    end

    describe "the panel (Story 5)" do
      it "shows the type's title, cards, last applied refresh and next scheduled one (AC-5.1, AC-5.5)", :aggregate_failures do
        create(:catalog_entry)
        create(:catalog_entry, :retired)
        create(:catalog_refresh_run, source_version: "default-cards-7", finished_at: Time.utc(2026, 10, 5, 3, 20))
        SolidQueue::RecurringTask.create!(key: "refresh_mtg_catalog", class_name: "Catalog::RefreshJob",
          arguments: %w[mtg scheduled], schedule: "every monday at 3:15am", static: true)

        travel_to(Time.utc(2026, 10, 9, 12)) { get admin_catalog_path }

        expect(text(panel.at_css("h2"))).to eq("Magic: The Gathering")
        expect(text(panel.at_css(".c-details"))).to eq("Cards 1 Last applied refresh 5 Oct 2026 03:20 UTC default-cards-7 " \
          "Next scheduled refresh 12 Oct 2026 03:15 UTC")
        expect(section("refresh").at_css("button")["class"]).to eq("c-btn c-btn--secondary")
      end

      it "says when no refresh is scheduled, as in development (AC-5.5)" do
        get admin_catalog_path

        expect(text(panel.at_css(".c-details"))).to end_with("Next scheduled refresh Not scheduled")
      end

      it "lists the 5 most recent runs with their trigger, status and outcome (AC-5.1)", :aggregate_failures do
        6.times { |n| create(:catalog_refresh_run, started_at: (n + 2).days.ago, seen_count: 100, updated_count: n) }
        create(:catalog_refresh_run, status: "skipped", message: "already running", trigger: "manual", started_at: Time.utc(2026, 10, 9, 3, 15))

        get admin_catalog_path

        rows = panel.css(".c-runs li").map { |row| text(row) }
        expect(rows.size).to eq(5)
        expect(rows.first).to eq("9 Oct 2026 03:15 UTC manual · skipped already running")
        expect(rows.second).to end_with("scheduled · applied 100 seen · 0 changed")
      end

      it "shows a second type with its own title and extra operation, and starts it (AC-5.3)", :aggregate_failures, :other_catalog do
        get admin_catalog_path

        expect(page.css(".c-panel h2").map { |title| text(title) }).to eq([ "Magic: The Gathering", "Pocket Monsters" ])
        expect(text(section("price_sync", "other"))).to eq("Price sync Sync prices Never synced. 25% 1 of 4 prices")
        expect(section("price_sync", "other").at_css("progress").to_h).to include("value" => "25", "max" => "100", "aria-label" => "Prices")

        start("price_sync", collectible_type: "other")
        expect(flash[:notice]).to eq("Price sync queued.")
        expect(SolidQueue::Job.sole).to have_attributes(class_name: "OtherCatalogJob")
      end

      it "shows only the refresh for a type whose source adds nothing (AC-5.2)" do
        Catalog.sources["plain"] = "FakeCatalogSource"
        get admin_catalog_path
        expect(panel("plain").css(".c-operation__title").map { |title| text(title) }).to eq([ "Refresh" ])
      ensure
        Catalog.sources.delete("plain")
      end
    end

    describe "starting a refresh (Story 2)" do
      it "queues one manual refresh and says so; the panel shows it queued and the page polls (AC-2.1, AC-2.2)", :aggregate_failures do
        start("refresh")

        expect(response).to redirect_to(admin_catalog_path).and have_http_status(:see_other)
        expect(SolidQueue::Job.sole.arguments["arguments"]).to eq(%w[mtg manual])
        follow_redirect!
        expect(text(page.at_css("#status"))).to eq("Refresh queued.")
        expect(text(section("refresh").at_css(".c-operation__summary"))).to eq("Queued.")
        expect(section("refresh").at_css("button")["disabled"]).to be_present
        expect(page.at_css("main")["data-controller"]).to eq("poll")
      end

      it "queues nothing more while one is queued or running, whoever queued it (AC-2.3)", :aggregate_failures do
        queue_job(Catalog::RefreshJob, "mtg", "scheduled")

        start("refresh")

        expect(response).to redirect_to(admin_catalog_path)
        expect(flash[:notice]).to eq("A refresh is already queued or running.")
        expect(SolidQueue::Job.count).to eq(1)
      end

      it "answers 404 for an unknown type or operation, queuing nothing (AC-5.6)", :aggregate_failures do
        start("refresh", collectible_type: "pokemon")
        expect(response).to have_http_status(:not_found)
        start("art_index_rebuild")
        expect(response).to have_http_status(:not_found)
        start("constantize")
        expect(response).to have_http_status(:not_found)
        expect(SolidQueue::Job.count).to eq(0)
      end
    end

    describe "a running refresh (Stories 2 and 3)" do
      it "lists the stages, the download in megabytes with its bar, and when it started (AC-2.4, AC-2.5)", :aggregate_failures do
        travel_to(Time.utc(2026, 10, 9, 3, 17)) do
          running(stage: "download", stage_done: 41_200_000, stage_total: 82_400_000, started_at: Time.utc(2026, 10, 9, 3, 15))
          get admin_catalog_path
        end

        refresh = section("refresh")
        expect(text(refresh.at_css(".c-operation__summary"))).to eq("Running.")
        expect(refresh.css(".c-stages__stage").map { |stage| text(stage) }).to eq([ "Download In progress 50% 39.3 MB of 78.6 MB",
          "Sync cards Waiting", "Retire missing cards Waiting", "Rebuild name index Waiting" ])
        expect(refresh.at_css("[aria-current='step'] progress").to_h).to include("value" => "50", "aria-label" => "Download")
        expect(text(refresh.at_css(".c-details"))).to eq("Started 9 Oct 2026 03:15 UTC Trigger manual " \
          "Last progress 9 Oct 2026 03:15 UTC (2 minutes ago)")
        expect(refresh.at_css("button")["disabled"]).to be_present
      end

      it "shows the share of the file read and the counts while syncing (AC-2.6)" do
        running(stage: "sync", stage_done: 61, stage_total: 100, seen_count: 66_140, inserted_count: 18, updated_count: 312)

        get admin_catalog_path

        expect(text(section("refresh").at_css("[aria-current='step']")))
          .to eq("Sync cards In progress 61% 66,140 seen · 18 inserted · 312 updated")
      end

      it "marks a stage without a percentage current in words alone (AC-2.7, AC-2.8)", :aggregate_failures do
        running(stage: "index")

        get admin_catalog_path

        expect(text(section("refresh").at_css("[aria-current='step']"))).to eq("Rebuild name index In progress")
        expect(section("refresh").at_css("progress")).to be_nil
      end

      it "shows a run with no progress for 15 minutes as interrupted, and lets a refresh start (AC-3.2)", :aggregate_failures do
        running(stage: "sync", started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1")

        get admin_catalog_path

        expect(text(section("refresh").at_css(".c-operation__summary"))).to eq("Interrupted while syncing cards.")
        expect(section("refresh").css(".c-stages__state").map { |state| text(state) }).to eq([ "Done", "Stopped here", "Waiting", "Waiting" ])
        expect(section("refresh").at_css("button")["disabled"]).to be_nil
        expect(text(panel.at_css(".c-runs li"))).to include("manual · interrupted")
        expect(page.at_css("[data-controller~='poll']")).to be_nil
      end

      it "shows it as running with the minutes while a worker still holds its job (AC-3.6)", :aggregate_failures do
        running(stage: "sync", started_at: 1.hour.ago, heartbeat_at: 20.minutes.ago, job_id: "job-1")
        claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual")).update!(active_job_id: "job-1")

        get admin_catalog_path

        expect(text(section("refresh").at_css(".c-operation__summary"))).to eq("Running, no progress for 20 minutes.")
        expect(section("refresh").at_css("button")["disabled"]).to be_present
        expect(text(panel.at_css(".c-runs li"))).to include("manual · running (no progress for 20 minutes)")
      end
    end

    describe "a refresh that ended (Stories 2 and 3)" do
      it "shows an applied run's counts, version and finish time (AC-2.13)", :aggregate_failures do
        create(:catalog_refresh_run, source_version: "default-cards-7", seen_count: 106_636, updated_count: 12,
          started_at: Time.utc(2026, 10, 5, 3, 15), finished_at: Time.utc(2026, 10, 5, 3, 20))

        get admin_catalog_path

        expect(text(section("refresh"))).to eq("Refresh Refresh now Applied. Started 5 Oct 2026 03:15 UTC Trigger scheduled " \
          "Finished 5 Oct 2026 03:20 UTC Source version default-cards-7 " \
          "Counts 106,636 seen · 0 inserted · 12 updated · 0 retired · 0 restored · 0 malformed")
      end

      it "shows a skipped run with its message (AC-2.14)" do
        create(:catalog_refresh_run, status: "skipped", message: "default-cards-7 already applied")

        get admin_catalog_path

        expect(text(section("refresh").at_css(".c-operation__summary"))).to eq("Skipped: default-cards-7 already applied.")
      end

      it "shows a failed run's stage and message, and links to its failed job (AC-3.1)", :aggregate_failures do
        create(:catalog_refresh_run, status: "failed", stage: "sync", message: "Catalog::Sources::Error: no valid records (3 malformed)")
        fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))

        get admin_catalog_path

        expect(text(section("refresh").at_css(".c-operation__summary")))
          .to eq("Failed while syncing cards: Catalog::Sources::Error: no valid records (3 malformed)")
        expect(section("refresh").at_css("a")["href"]).to eq(admin_jobs_path(status: "failed"))
        expect(section("refresh").at_css("button")["disabled"]).to be_nil
      end

      it "shows a failed run whose job waits to retry as queued, without the failed link (AC-3.7)", :aggregate_failures do
        create(:catalog_refresh_run, status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503")
        travel_to(Time.utc(2026, 10, 9, 3, 15)) do
          queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)
          get admin_catalog_path
        end

        refresh = section("refresh")
        expect(text(refresh.at_css(".c-operation__summary")))
          .to eq("Queued to retry. The last run failed while downloading: Catalog::Sources::TransientError: 503")
        expect(text(refresh.at_css(".c-details"))).to start_with("Retrying at 9 Oct 2026 03:18 UTC")
        expect(refresh.at_css("a")).to be_nil
        expect(refresh.at_css("button")["disabled"]).to be_present
      end
    end

    describe "the art index (Story 4)" do
      it "says art matching is off, with the setting and no button (AC-4.6)", :aggregate_failures do
        get admin_catalog_path

        expect(text(section("art_index"))).to eq("Art index Art matching is off. Set COLLECTOR_MTG_ART_MATCHING=true to turn it on.")
        expect(section("art_index").at_css("button")).to be_nil
      end

      it "needs the catalog refreshed first: a disabled button, and a refused start (AC-4.5)", :aggregate_failures, :art_matching do
        get admin_catalog_path
        expect(text(section("art_index"))).to eq("Art index Build art index Refresh the catalog first: the art index is built from its cards.")
        expect(section("art_index").at_css("button")["disabled"]).to be_present

        start("art_index")
        expect(flash[:alert]).to eq("Refresh the catalog first: the art index is built from its cards.")
        expect(SolidQueue::Job.count).to eq(0)
      end

      it "queues one build, shows it queued, and refuses a second (AC-4.3, AC-4.4)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run)

        start("art_index")
        expect(flash[:notice]).to eq("Art index build queued.")
        follow_redirect!
        expect(text(section("art_index").at_css(".c-operation__summary"))).to eq("Queued.")
        expect(section("art_index").at_css("button")["disabled"]).to be_present

        start("art_index")
        expect(flash[:notice]).to eq("An art index build is already queued or running.")
        expect(SolidQueue::Job.where(class_name: "MTG::Art::BuildJob").count).to eq(1)
      end

      it "shows a running build's bar, counts and heartbeat (AC-4.2)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run)
        create(:mtg_art_build, status: "running", finished_at: nil, started_at: Time.utc(2026, 10, 9, 3, 0),
          heartbeat_at: 20.seconds.ago, total_count: 31_904, fingerprinted_count: 7_976, fetched_count: 1_200, failed_count: 3)

        get admin_catalog_path

        expect(text(section("art_index"))).to start_with("Art index Build art index Building. 25% 7,976 of 31,904 artworks fingerprinted " \
          "Started 9 Oct 2026 03:00 UTC Images fetched 1,200 Failed images 3 Last heartbeat")
        expect(section("art_index").at_css("progress")["aria-label"]).to eq("Artworks fingerprinted")
        expect(page.at_css("main")["data-controller"]).to eq("poll")
      end

      it "shows a finished build's counts (AC-4.7) and a failed one's message and index (AC-4.8)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run)
        build = create(:mtg_art_build, indexed_count: 31_904, without_image_count: 12, failed_count: 3, finished_at: Time.utc(2026, 10, 9, 5, 0))
        get admin_catalog_path
        expect(text(section("art_index"))).to eq("Art index Build art index Ready. Finished 9 Oct 2026 05:00 UTC " \
          "Artworks indexed 31,904 Without an image 12 Failed images 3")

        build.update!(status: "failed", message: "Errno::ENOSPC: No space left on device")
        get admin_catalog_path
        expect(text(section("art_index"))).to eq("Art index Build art index Failed: Errno::ENOSPC: No space left on device " \
          "Finished 9 Oct 2026 05:00 UTC Index in use none")
      end
    end

    it "runs the same queries however many runs and jobs there are (NFR)", :aggregate_failures do
      create(:catalog_refresh_run)
      queue_job(Catalog::RefreshJob, "mtg", "manual")
      few = count_queries { get admin_catalog_path }
      8.times { |n| create(:catalog_refresh_run, started_at: (n + 2).hours.ago) }
      3.times { queue_job(Catalog::RefreshJob, "mtg", "manual") }
      4.times { fail_job(queue_job(MTG::Art::BuildJob)) }

      expect(count_queries { get admin_catalog_path }).to eq(few)
      expect(response).to have_http_status(:ok)
    end

    it "links to the jobs page" do
      get admin_catalog_path

      expect(page.at_css(".c-pagehead__actions a")["href"]).to eq(admin_jobs_path)
    end
  end

  it "is invisible to a member: 404, and nothing is queued (AC-7.1)", :aggregate_failures do
    sign_in_as(create(:user))

    get admin_catalog_path
    expect(response).to have_http_status(:not_found)
    start("refresh")
    expect(response).to have_http_status(:not_found)
    expect(SolidQueue::Job.count).to eq(0)
  end

  it "sends a visitor who isn't signed in to sign in (AC-7.2)", :aggregate_failures do
    create(:admin)

    get admin_catalog_path
    expect(response).to redirect_to(new_session_path)
    start("refresh")
    expect(response).to redirect_to(new_session_path)
    expect(SolidQueue::Job.count).to eq(0)
  end
end
```

- [ ] Change `spec/requests/admin/jobs_spec.rb` (apply this diff exactly):

```diff
--- a/spec/requests/admin/jobs_spec.rb
+++ b/spec/requests/admin/jobs_spec.rb
@@ -229,6 +229,12 @@ RSpec.describe "Admin jobs pages", :solid_queue, type: :request do
         expect(response).to have_http_status(:not_found)
       end
     end
+
+    it "links to the catalog page" do
+      get admin_jobs_path
+
+      expect(page.at_css(".c-pagehead__actions a")["href"]).to eq(admin_catalog_path)
+    end
   end
 
   it "is invisible to a member: 404 everywhere, and nothing changes (AC-7.1)", :aggregate_failures do
```

- [ ] Create `spec/system/admin_catalog_spec.rb`:

```ruby
require "rails_helper"

# Spec 015 Stories 1 and 2 in a browser: an admin starts the first refresh from the catalog page and
# watches it go without reloading. No worker runs in tests, so the examples play the job's part by changing its records.
RSpec.describe "Admin catalog page", :solid_queue, type: :system do
  let(:admin) { create(:admin) }

  def summary = find("#mtg_refresh .c-operation__summary")

  def current_stage = find("#mtg_refresh [aria-current='step']")

  # The refresh job in the queue, picked up by a worker and working on the given stage.
  def work_on(stage, **progress)
    job = SolidQueue::Job.sole
    claim_job(job) unless job.claimed?
    run = Catalog::RefreshRun.find_or_create_by!(collectible_type: "mtg", trigger: "manual", status: "running", job_id: job.active_job_id) do |new|
      new.started_at = Time.current
    end
    run.progress!(stage:, **progress)
    run
  end

  def apply(run)
    run.update!(source_version: "default-cards-7")
    run.finish!(:applied, counts: { seen: 108_412, inserted: 108_412 })
    finish_job(SolidQueue::Job.sole)
  end

  it "starts the first refresh from the empty state (AC-1.4, AC-2.1, AC-2.2)", :aggregate_failures do
    system_sign_in_as(admin)
    visit admin_catalog_path
    expect(page).to have_css(".c-empty", text: "No cards are loaded yet.")

    click_button "Refresh now"

    expect(page).to have_css("#status", text: "Refresh queued.")
    expect(summary).to have_text("Queued.")
    expect(page).to have_button("Refresh now", disabled: true)
    expect(SolidQueue::Job.sole.arguments["arguments"]).to eq(%w[mtg manual])
  end

  it "shows a refresh's stages and progress as they change, then stops asking (AC-2.10, AC-2.11)", :aggregate_failures do
    queue_job(Catalog::RefreshJob, "mtg", "manual")
    system_sign_in_as(admin)
    visit admin_catalog_path

    using_wait_time(5) do
      work_on("download", done: 20_600_000, total: 82_400_000)
      expect(current_stage).to have_text("Download In progress 25% 19.6 MB of 78.6 MB", normalize_ws: true)
      run = work_on("sync", done: 61, total: 100, counts: { seen: 66_140, inserted: 66_140 })
      expect(current_stage).to have_text("Sync cards In progress 61% 66,140 seen · 66,140 inserted · 0 updated", normalize_ws: true)
      apply(run)
      expect(summary).to have_text("Applied.")
      expect(page).to have_css("#catalog_mtg .c-details", text: "default-cards-7")
      expect(page).to have_button("Refresh now", disabled: false)
      expect(page).to have_no_css("[data-controller~='poll']") # nothing is in flight: the page stops asking
    end
  end

  it "doesn't ask for updates while nothing is in flight (AC-2.12)", :aggregate_failures do
    create(:catalog_refresh_run)
    system_sign_in_as(admin)

    visit admin_catalog_path

    expect(summary).to have_text("Applied.")
    expect(page).to have_no_css("[data-controller~='poll']")
  end

  it "keeps the scroll position across an update (AC-2.10)", :aggregate_failures do
    8.times { |n| create(:catalog_refresh_run, started_at: (n + 1).days.ago) }
    queue_job(Catalog::RefreshJob, "mtg", "manual")
    system_sign_in_as(admin)
    page.current_window.resize_to(1000, 500)
    visit admin_catalog_path
    expect(summary).to have_text("Queued.")
    page.execute_script("window.scrollTo(0, 150)")

    work_on("retire")

    using_wait_time(5) { expect(summary).to have_text("Running.") }
    expect(page.evaluate_script("window.scrollY")).to eq(150)
  end
end
```

- [ ] Create `spec/system/narrow_admin_pages_spec.rb`:

```ruby
require "rails_helper"

# Spec 015 AC-7.4: the admin catalog and jobs pages fit a phone. Firefox won't open a window narrower than 500px, so
# each page is loaded in a narrow frame (spec/support/narrow_frame.rb), at the design system's 360px floor and at 375px.
RSpec.describe "Admin catalog and jobs pages on a phone", :art_matching, :solid_queue, type: :system do
  let(:long_error) { "Catalog::Sources::TransientError: GET https://api.scryfall.com/bulk-data returned 503 #{"x" * 120}" }

  it "never scroll sideways, whatever they show", :aggregate_failures do
    create(:catalog_refresh_run, source_version: "default-cards-20261005090555", started_at: 2.days.ago, finished_at: 2.days.ago)
    create(:catalog_refresh_run, :running, stage: "sync", stage_done: 61, stage_total: 100, seen_count: 66_140)
    create(:mtg_art_build, status: "running", finished_at: nil, heartbeat_at: Time.current, total_count: 31_904, fingerprinted_count: 7_976)
    failed = fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"), RuntimeError.new(long_error))
    queue_job(MTG::Art::BuildJob)
    system_sign_in_as(create(:admin))

    [ 360, 375 ].each do |width|
      [ admin_catalog_path, admin_jobs_path, admin_jobs_path(status: "queued"), admin_job_path(failed.id),
        new_admin_job_discard_path(failed.id) ].each do |path|
        expect(open_in_narrow_frame(path, width:, ready: "main")).to eq([ width, true ]), "#{path} scrolls sideways at #{width}px"
      end
    end
  end

  it "keeps every action reachable at 375px", :aggregate_failures do
    failed = fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"), RuntimeError.new(long_error))
    system_sign_in_as(create(:admin))

    open_in_narrow_frame(admin_catalog_path, width: 375, ready: "main")
    within_narrow_frame do
      expect(page).to have_button("Refresh now")
      expect(page).to have_link("Jobs", class: "c-admin__add")
    end

    open_in_narrow_frame(admin_jobs_path, width: 375, ready: "main")
    within_narrow_frame do
      find("summary[aria-label='Actions for Catalog::RefreshJob #{failed.id}']").click
      expect(page).to have_button("Retry")
      expect(page).to have_link("Discard…")
    end
  end
end
```

- [ ] Change `spec/design_system_files_spec.rb` (apply this diff exactly):

```diff
--- a/spec/design_system_files_spec.rb
+++ b/spec/design_system_files_spec.rb
@@ -18,7 +18,7 @@ RSpec.describe "Design system files" do
     new_patterns = %w[StatusMessage Form AuthPage ConfirmPage SearchResults TileAdd FinishBadge FilterSelect Pager EmptyState
       Details SingleStat MorePage AdminUsers TableActions SystemLogo
       SortHeader StatusAction BulkConfirmPage ChoicePage BulkForm ViewSwitchForm TableItemLink Scanner
-      AdminJobs]
+      AdminJobs AdminCatalog StageList ProgressMeter]
     readme = root.join("docs/design-system/README.md").read
     new_patterns.each do |name|
       expect(root.join("docs/design-system/components/#{name}.md")).to exist
```

- [ ] Run: `bin/rspec spec/requests/admin spec/system/admin_catalog_spec.rb spec/system/narrow_admin_pages_spec.rb spec/design_system_files_spec.rb` — expect: FAIL (`undefined method 'admin_catalog_path'`; the three component docs are missing).
- [ ] Change `config/routes.rb` (apply this diff exactly):

```diff
--- a/config/routes.rb
+++ b/config/routes.rb
@@ -75,7 +75,10 @@ Rails.application.routes.draw do
     end
     resource :sign_up_setting, only: :update
 
-    # Background jobs (spec 015).
+    # Catalog operations and background jobs (spec 015).
+    resource :catalog, only: :show do
+      resources :operation_starts, only: :create, module: :catalogs
+    end
     resources :jobs, only: %i[index show] do
       scope module: :jobs do
         resource :retry, only: :create
```

- [ ] Change `app/helpers/admin_helper.rb` (apply this diff exactly):

```diff
--- a/app/helpers/admin_helper.rb
+++ b/app/helpers/admin_helper.rb
@@ -1,5 +1,7 @@
-# What the admin pages share (spec 015): times in UTC (FR-8).
+# What the admin catalog and jobs pages share (spec 015): times in UTC (FR-8) and the words for facts and stages.
 module AdminHelper
+  STAGE_WORDS = { done: "Done", current: "In progress", stopped: "Stopped here", pending: "Waiting" }.freeze
+
   # "9 Oct 2026 03:15 UTC", in a <time> element carrying the exact instant.
   def utc_time(time) = time_tag(time.utc, time.utc.strftime("%-d %b %Y %H:%M UTC"))
 
@@ -12,8 +14,27 @@ module AdminHelper
   # The UTC time with the relative form after it: "9 Oct 2026 03:15 UTC (2 minutes ago)".
   def utc_time_with_relative(time) = safe_join([ utc_time(time), " (#{relative_time(time)})" ])
 
+  # A Catalog::Operation::Fact's value as the page shows it: a time in UTC, a number with delimiters, or the text.
+  def fact_value(fact)
+    case fact.value
+    when Time then fact.relative ? utc_time_with_relative(fact.value) : utc_time(fact.value)
+    when Integer then number_with_delimiter(fact.value)
+    else fact.value.to_s
+    end
+  end
+
   JOBS_TIME_HEADINGS = { "failed" => "Failed", "running" => "Started", "queued" => "Queued", "scheduled" => "Due" }.freeze
 
   # The heading of the jobs list's time column: the time that matters to the state shown.
   def admin_jobs_time_heading(state) = JOBS_TIME_HEADINGS.fetch(state)
+
+  def stage_word(stage) = STAGE_WORDS.fetch(stage.state)
+
+  # What a finished refresh run did, in a few words, for the recent-runs list.
+  def refresh_run_outcome(run)
+    return run.message.to_s unless run.applied?
+
+    changed = run.inserted_count + run.updated_count + run.retired_count + run.restored_count
+    "#{number_with_delimiter(run.seen_count)} seen · #{number_with_delimiter(changed)} changed"
+  end
 end
```

- [ ] Create `app/controllers/admin/catalogs_controller.rb`:

```ruby
# The admin catalog page (spec 015 Stories 1 to 5): a panel per catalog type with its health, what can be started for it
# and how that is going. It names no collectible: everything comes from Catalog::Health and its operations.
class Admin::CatalogsController < ApplicationController
  include AdminOnly

  def show
    @catalogs = Catalog::Health.all
  end
end
```

- [ ] Create `app/controllers/admin/catalogs/operation_starts_controller.rb`:

```ruby
# Starts one of a catalog type's operations (spec 015 FR-3): queues its job, never runs it in the request. The type and
# the operation are looked up among what is registered, so an unknown one is a 404 and nothing from the request is ever
# called by name (FR-7).
class Admin::Catalogs::OperationStartsController < ApplicationController
  include AdminOnly

  def create
    operation = Catalog::Health.find(params[:collectible_type]).operation(params[:operation])
    raise ActiveRecord::RecordNotFound unless operation

    if operation.start
      redirect_to admin_catalog_path, notice: operation.queued_notice, status: :see_other
    elsif operation.unavailable_reason
      redirect_to admin_catalog_path, alert: operation.unavailable_reason, status: :see_other
    else
      redirect_to admin_catalog_path, notice: operation.in_flight_notice, status: :see_other
    end
  end
end
```

- [ ] Create `app/views/admin/catalogs/show.html.erb`:

```erb
<% content_for :title, "Catalog · Collector" %>
<%= render "layouts/appbar", section: nil %>
<%# The page keeps itself current only while something is queued or running (spec 015 FR-4). %>
<%= tag.main class: "c-main", data: { controller: ("poll" if @catalogs.any?(&:in_flight?)) } do %>
  <div class="c-pagehead">
    <div><h1 class="c-pagehead__title">Catalog</h1><p class="c-pagehead__stats"><%= pluralize(@catalogs.size, "catalog") %></p></div>
    <div class="c-pagehead__actions"><%= link_to "Jobs", admin_jobs_path, class: "c-btn c-btn--secondary" %></div>
  </div>
  <p><%= link_to "Jobs", admin_jobs_path, class: "c-btn c-btn--secondary c-admin__add" %></p>

  <%= render partial: "admin/catalogs/catalog", collection: @catalogs, as: :catalog %>
<% end %>
<%= render "layouts/tabbar", section: nil %>
```

- [ ] Create `app/views/admin/catalogs/_catalog.html.erb`:

```erb
<%# locals: (catalog:) %>
<section class="c-panel" id="catalog_<%= catalog.collectible_type %>" aria-labelledby="catalog_<%= catalog.collectible_type %>_title">
  <h2 class="c-section__title" id="catalog_<%= catalog.collectible_type %>_title"><%= catalog.title %></h2>
  <% unless catalog.loaded? || catalog.in_flight? %>
    <p class="c-empty">No cards are loaded yet. The first refresh downloads the source's card data and may take several minutes. Languages: <%= catalog.languages %>.</p>
  <% end %>
  <dl class="c-details">
    <div><dt>Cards</dt><dd class="is-data"><%= number_with_delimiter(catalog.entries_count) %></dd></div>
    <div><dt>Last applied refresh</dt>
      <dd><% if catalog.last_applied %><%= utc_time(catalog.last_applied.finished_at) %> <span class="c-tag"><%= catalog.last_applied.source_version %></span><% else %>None yet<% end %></dd></div>
    <div><dt>Next scheduled refresh</dt>
      <dd><% if (next_refresh_at = catalog.next_refresh_at) %><%= utc_time(next_refresh_at) %><% else %>Not scheduled<% end %></dd></div>
  </dl>

  <%= render partial: "admin/catalogs/operation", collection: catalog.operations, as: :operation, locals: { catalog: } %>

  <% if catalog.recent_runs.any? %>
    <section class="c-operation">
      <h3 class="c-operation__title">Recent refreshes</h3>
      <ul class="c-list c-runs">
        <% catalog.recent_runs.each do |run| %>
          <li>
            <span><%= utc_time(run.started_at) %></span>
            <span class="c-list__meta"><%= run.trigger %> · <%= catalog.refresh.status_label(run) %></span>
            <span class="c-list__end"><%= refresh_run_outcome(run) %></span>
          </li>
        <% end %>
      </ul>
    </section>
  <% end %>
</section>
```

- [ ] Create `app/views/admin/catalogs/_operation.html.erb`:

```erb
<%# locals: (operation:, catalog:) %>
<%# One operation of a catalog type (Catalog::Operation): its state in a sentence, its start button, and how far it is. %>
<section class="c-operation" id="<%= catalog.collectible_type %>_<%= operation.key %>">
  <div class="c-operation__head">
    <h3 class="c-operation__title"><%= operation.title %></h3>
    <% if operation.start_label %>
      <%# The refresh is the page's primary action while the catalog isn't loaded (AC-1.4). %>
      <%= button_to operation.start_label, admin_catalog_operation_starts_path,
            params: { collectible_type: catalog.collectible_type, operation: operation.key }, disabled: !operation.startable?,
            class: class_names("c-btn", !catalog.loaded? && operation == catalog.refresh ? "c-btn--primary" : "c-btn--secondary"),
            form: { class: "c-operation__start" } %>
    <% end %>
  </div>
  <p class="c-operation__summary"><%= operation.summary %></p>
  <% if operation.failed_job? %><p class="c-operation__summary"><%= link_to "See its failed job", admin_jobs_path(status: "failed") %></p><% end %>

  <% if operation.stages.any? %>
    <ol class="c-stages">
      <% operation.stages.each do |stage| %>
        <%= tag.li class: "c-stages__stage", aria: { current: ("step" if stage.state == :current) } do %>
          <span class="c-stages__label"><%= stage.label %></span>
          <span class="c-stages__state"><%= stage_word(stage) %></span>
          <% if stage.meter %><%= render "admin/catalogs/meter", meter: stage.meter %><% end %>
          <% if stage.note %><span class="c-stages__note"><%= stage.note %></span><% end %>
        <% end %>
      <% end %>
    </ol>
  <% end %>
  <% if operation.meter %><%= render "admin/catalogs/meter", meter: operation.meter %><% end %>

  <% if operation.facts.any? %>
    <dl class="c-details">
      <% operation.facts.each do |fact| %>
        <div><dt><%= fact.label %></dt><dd><%= fact_value(fact) %></dd></div>
      <% end %>
    </dl>
  <% end %>
</section>
```

- [ ] Create `app/views/admin/catalogs/_meter.html.erb`:

```erb
<%# locals: (meter:) %>
<%# How far through something is (Catalog::Operation::Meter): a bar with its percentage when there is a total, then the words. %>
<div class="c-meter">
  <% if meter.percent %>
    <progress class="c-meter__bar" max="100" value="<%= meter.percent %>" aria-label="<%= meter.label %>"></progress>
    <span class="c-meter__value"><%= meter.percent %>%</span>
  <% end %>
  <% if meter.text %><span class="c-meter__text"><%= meter.text %></span><% end %>
</div>
```

- [ ] Change `app/views/admin/jobs/index.html.erb` (apply this diff exactly):

```diff
--- a/app/views/admin/jobs/index.html.erb
+++ b/app/views/admin/jobs/index.html.erb
@@ -4,7 +4,9 @@
 <%= tag.main class: "c-main", data: { controller: ("poll" if @list.live?) } do %>
   <div class="c-pagehead">
     <div><h1 class="c-pagehead__title">Jobs</h1><p class="c-pagehead__stats"><%= pluralize(@list.counts.fetch("failed"), "failed job") %></p></div>
+    <div class="c-pagehead__actions"><%= link_to "Catalog", admin_catalog_path, class: "c-btn c-btn--secondary" %></div>
   </div>
+  <p><%= link_to "Catalog", admin_catalog_path, class: "c-btn c-btn--secondary c-admin__add" %></p>
 
   <%= form_with url: admin_jobs_path, method: :get, class: "c-jobs__filters" do %>
     <% BackgroundJobs::List::STATES.each do |state| %>
```

- [ ] Change `app/assets/stylesheets/collector/additions.css` (apply this diff exactly):

```diff
--- a/app/assets/stylesheets/collector/additions.css
+++ b/app/assets/stylesheets/collector/additions.css
@@ -179,3 +179,30 @@
 .c-job__error { margin:0 0 var(--space-2); font:400 15px/22px var(--font-sans); color:var(--ink); overflow-wrap:anywhere; }
 .c-pre { margin:0; padding:var(--space-3); overflow-x:auto; background:var(--surface-sunken); border-radius:var(--radius-md);
   font:400 12px/16px var(--font-mono); color:var(--ink); }
+
+/* ---------- Admin catalog (spec 015): a panel per catalog type, holding its facts and its operations ---------- */
+.c-panel { display:flex; flex-direction:column; gap:var(--space-4); margin-top:var(--space-6); padding:var(--space-4);
+  background:var(--surface-raised); border:1px solid var(--line); border-radius:var(--radius-md); }
+.c-panel .c-empty { margin:0; }
+.c-operation { display:flex; flex-direction:column; gap:var(--space-2); padding-top:var(--space-4); border-top:1px solid var(--line); }
+.c-operation__head { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:var(--space-2); }
+.c-operation__title { margin:0; font:600 16px/24px var(--font-sans); color:var(--ink); }
+.c-operation__summary { margin:0; font:400 15px/22px var(--font-sans); color:var(--ink); overflow-wrap:anywhere; }
+.c-operation__summary a { color:var(--brand); font-weight:600; text-decoration:none; }
+.c-operation__summary a:hover { text-decoration:underline; }
+.c-operation__summary a:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
+.c-operation__start { display:flex; }
+.c-runs li { flex-wrap:wrap; }
+
+/* ---------- Stage list (spec 015): the steps of an operation in order, each with its state in a word ---------- */
+.c-stages { display:flex; flex-direction:column; gap:var(--space-2); margin:0; padding:0; list-style:none; }
+.c-stages__stage { display:grid; grid-template-columns:minmax(0, 1fr) auto; gap:var(--space-1) var(--space-3);
+  font:400 14px/20px var(--font-sans); color:var(--ink-muted); }
+.c-stages__stage[aria-current] { color:var(--ink); font-weight:600; }
+.c-stages__state { font:400 13px/18px var(--font-mono); }
+.c-stages__stage .c-meter, .c-stages__note { grid-column:1 / -1; }
+.c-stages__note { font:400 13px/18px var(--font-mono); color:var(--ink-muted); }
+
+/* ---------- Progress meter (spec 015): a bar with its percentage and, where there are any, the amounts in words ---------- */
+.c-meter { display:flex; flex-wrap:wrap; align-items:center; gap:var(--space-2); font:400 13px/18px var(--font-mono); color:var(--ink-muted); }
+.c-meter__bar { flex:1 1 160px; min-width:0; height:var(--space-2); accent-color:var(--brand); }
```

- [ ] Create `docs/design-system/components/AdminCatalog.md`:

````markdown
# AdminCatalog

The admin's catalog page (spec 015): a panel per catalog type with its facts, what an admin can start for it, and how that is going.

**Markup** — a `c-pagehead` with a link to Jobs (repeated as a `c-admin__add` button for phones), then one `section.c-panel` per catalog type. Inside a panel: the type's title, an `EmptyState` while it has no cards, a `Details` list, one `section.c-operation` per operation, and "Recent refreshes" as a `c-list c-runs`.

```html
<section class="c-panel" id="catalog_mtg" aria-labelledby="catalog_mtg_title">
  <h2 class="c-section__title" id="catalog_mtg_title">Magic: The Gathering</h2>
  <dl class="c-details">
    <div><dt>Cards</dt><dd class="is-data">108,412</dd></div>
    <div><dt>Last applied refresh</dt><dd><time datetime="…">5 Oct 2026 03:20 UTC</time> <span class="c-tag">default-cards-20261005</span></dd></div>
    <div><dt>Next scheduled refresh</dt><dd>12 Oct 2026 03:15 UTC</dd></div>
  </dl>

  <section class="c-operation" id="mtg_refresh">
    <div class="c-operation__head">
      <h3 class="c-operation__title">Refresh</h3>
      <form class="c-operation__start" method="post" action="/admin/catalog/operation_starts">…<button class="c-btn c-btn--secondary" disabled>Refresh now</button></form>
    </div>
    <p class="c-operation__summary">Running.</p>
    <ol class="c-stages">…</ol>
    <dl class="c-details">…</dl>
  </section>

  <section class="c-operation">
    <h3 class="c-operation__title">Recent refreshes</h3>
    <ul class="c-list c-runs">
      <li><span>5 Oct 2026 03:15 UTC</span><span class="c-list__meta">scheduled · applied</span><span class="c-list__end">108,412 seen · 412 changed</span></li>
    </ul>
  </section>
</section>
```

- A panel is `surface-raised` with a `line` border and `radius-md`; its parts are `space-4` apart and each operation starts with a `line` rule.
- An operation's summary is one sentence that begins with its state in a word ("Queued.", "Running.", "Applied.", "Failed while syncing cards: …"), so the state never depends on colour. A failed run whose job is in the failed list adds a brand link, "See its failed job".
- Each operation has at most one button, named for what it starts ("Refresh now", "Build art index"). It is `c-btn--secondary`, and disabled while the operation is queued or running or can't run yet; the summary says why. "Refresh now" is `c-btn--primary` only while the catalog has no cards, when it is the page's one next step. An operation that is switched off shows no button, and its summary says how to switch it on.
- While the catalog has no cards and nothing is in flight, the panel opens with an `EmptyState` that says what the first refresh does and which languages are set.
- Times are absolute UTC (`9 Oct 2026 03:15 UTC`, in a `<time>`); a last-progress or heartbeat time adds the relative form in brackets, "(2 minutes ago)".
- While anything is queued or running, `<main>` carries `data-controller="poll"` and the page keeps itself current, as `AdminJobs` describes; it stops when the work ends.
- A new catalog type gets its panel from its source; the page's markup never names a type.
````

- [ ] Create `docs/design-system/components/StageList.md`:

````markdown
# StageList

The steps of a long operation in order, each with its state in a word, and how far the current one is (spec 015).

**Markup** — an `ol.c-stages` with one `li.c-stages__stage` per step: its label, its state, and for the current step a `ProgressMeter` and a note. The current step carries `aria-current="step"`.

```html
<ol class="c-stages">
  <li class="c-stages__stage"><span class="c-stages__label">Download</span><span class="c-stages__state">Done</span></li>
  <li class="c-stages__stage" aria-current="step">
    <span class="c-stages__label">Sync cards</span><span class="c-stages__state">In progress</span>
    <div class="c-meter">…</div>
    <span class="c-stages__note">66,140 seen · 18 inserted · 312 updated</span>
  </li>
  <li class="c-stages__stage"><span class="c-stages__label">Retire missing cards</span><span class="c-stages__state">Waiting</span></li>
</ol>
```

- The state is always a word: "Done", "In progress", "Waiting", or "Stopped here" on the step where a run failed or was interrupted. Colour and weight only repeat it: the current step is `ink` and semibold, the others `ink-muted`.
- The label and the state share a row; the meter and the note take the full width under them.
- A step with nothing to measure is current in words alone, with no meter.
- Counts in the note are exact, in mono, separated by " · ".
````

- [ ] Create `docs/design-system/components/ProgressMeter.md`:

````markdown
# ProgressMeter

How far through something is: a bar with its percentage, and the amounts in words where there are any (spec 015).

**Markup** — a `div.c-meter` holding a native `<progress>` with an `aria-label` naming what it measures, the percentage as text, and optionally the amounts.

```html
<div class="c-meter">
  <progress class="c-meter__bar" max="100" value="50" aria-label="Download"></progress>
  <span class="c-meter__value">50%</span>
  <span class="c-meter__text">39.3 MB of 78.6 MB</span>
</div>
```

- The bar is the browser's own `<progress>`, tinted with `accent-color: var(--brand)`, so assistive technology reads its value and label without scripting.
- The percentage is always written next to the bar; the bar is never the only signal.
- Without a total there is no bar and no percentage, only the amount ("1 MB").
- Numbers are exact and in mono: "7,976 of 31,904 artworks fingerprinted".
- The parts wrap, so on a phone the words drop under the bar.
````

- [ ] Change `docs/design-system/components/AdminJobs.md` (apply this diff exactly):

````diff
--- a/docs/design-system/components/AdminJobs.md
+++ b/docs/design-system/components/AdminJobs.md
@@ -2,7 +2,7 @@
 
 The admin's jobs pages (spec 015): the background jobs by state, one job in full, and the confirmation before a failed job is discarded.
 
-**Markup, the list** — a `c-pagehead`, a GET form of `Chip` filter chips with each state's count, then a `c-table c-jobs` inside `.c-collection`, a `Pager`, or an `EmptyState`.
+**Markup, the list** — a `c-pagehead` with a link to Catalog (repeated as a `c-admin__add` button for phones), a GET form of `Chip` filter chips with each state's count, then a `c-table c-jobs` inside `.c-collection`, a `Pager`, or an `EmptyState`.
 
 ```html
 <form class="c-jobs__filters" action="/admin/jobs" method="get">
````

- [ ] Change `docs/design-system/README.md` (apply this diff exactly):

```diff
--- a/docs/design-system/README.md
+++ b/docs/design-system/README.md
@@ -94,7 +94,7 @@ App additions (spec 006, in `collector/additions.css`): `SortHeader`, `StatusAct
 
 App additions (spec 007, in `collector/additions.css`): `Scanner`. Upstream it into the published design system before the next export replaces this folder.
 
-App additions (spec 015, in `collector/additions.css`): `AdminJobs`. Upstream it into the published design system before the next export replaces this folder.
+App additions (spec 015, in `collector/additions.css`): `AdminJobs`, `AdminCatalog`, `StageList`, `ProgressMeter`. Upstream these into the published design system before the next export replaces this folder.
 
 ## Logo
 
```

- [ ] Run: `bin/rspec spec/requests spec/system/admin_catalog_spec.rb spec/system/admin_jobs_spec.rb spec/system/narrow_admin_pages_spec.rb spec/design_system_files_spec.rb` — expect: PASS.
- [ ] Look at the pages (needs the maintainer's go-ahead for the development server; if it isn't given, leave this step open and say so in the hand-off): render `/admin/catalog`, `/admin/jobs` and a failed job's page at 1280px and 390px, light and dark (`data-theme` on `<html>`), and check the focus ring on every button, chip and link (the design system skill's "Checking your work"). Fix what is off by changing only `c-*` classes and tokens.
- [ ] Run: `bin/brakeman -q --no-pager` — expect: no warnings.
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `feat(admin): catalog page to start and watch refreshes and art index builds (015)`

---

## Phase 8: The not-loaded notice and the links

**Implements:** FR-6, FR-7 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.5, AC-5.4, AC-7.3
**Files:** `app/views/catalog/_not_loaded.html.erb`, `app/controllers/catalog/entries_controller.rb`, `app/controllers/scanners_controller.rb`, `app/controllers/mores_controller.rb`, `app/views/catalog/entries/index.html.erb`, `app/views/scanners/show.html.erb`, `app/views/mores/show.html.erb`, `app/views/layouts/_appbar.html.erb`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/StatusMessage.md`, `docs/design-system/components/MorePage.md`, `.rubocop.yml`, `spec/requests/catalog_not_loaded_spec.rb`, `spec/requests/admin/navigation_spec.rb`, `spec/system/catalog_not_loaded_spec.rb`, `spec/admin_catalog_core_spec.rb`
**Interfaces:** Consumes: `Catalog.unloaded_titles` (Phase 4); `admin_catalog_path`, `admin_jobs_path` (Phases 6, 7); the `:other_catalog` tag. Produces: the partial `catalog/not_loaded` (local `titles:`), with the element id `catalog_not_loaded`; `@unloaded_catalogs` in the three controllers.

Search, the scanner and (for admins) the More page say when a catalog has no applied refresh: admins get the link, members are told who to ask. Admins find the two pages beside user administration. A file-content spec keeps the core's admin catalog code free of any collectible's name.

- [ ] Create `spec/requests/catalog_not_loaded_spec.rb`:

```ruby
require "rails_helper"

# Spec 015 Story 1 and FR-6: while a catalog has no applied refresh, the pages where people look for cards say so.
RSpec.describe "The not-loaded notice", type: :request do
  def notice = Nokogiri::HTML5(response.body).at_css("main #catalog_not_loaded.c-status__message--alert")

  def notice_text = notice&.text&.squish

  context "when the catalog isn't loaded" do
    before { create(:catalog_refresh_run, status: "failed") }

    it "tells an admin on search, the scanner and More, with the way to load it (AC-1.1)", :aggregate_failures do
      sign_in_as(create(:admin))

      [ catalog_entries_path, scanner_path, more_path ].each do |path|
        get path
        expect(notice_text).to eq("The card catalog hasn't been loaded yet. Go to the catalog page to load it."), path
        expect(notice.at_css("a")["href"]).to eq(admin_catalog_path), path
      end
    end

    it "tells a member on search and the scanner to ask an admin, with no link (AC-1.2)", :aggregate_failures do
      sign_in_as(create(:user))

      [ catalog_entries_path, scanner_path ].each do |path|
        get path
        expect(notice_text).to eq("The card catalog hasn't been loaded yet. Ask an admin to load it."), path
        expect(notice.at_css("a")).to be_nil, path
      end
      get more_path
      expect(notice).to be_nil
    end
  end

  it "says nothing once a refresh has applied (AC-1.3)", :aggregate_failures do
    create(:catalog_refresh_run, status: "applied")
    sign_in_as(create(:admin))

    [ catalog_entries_path, scanner_path, more_path ].each do |path|
      get path
      expect(notice).to be_nil, path
    end
  end

  context "with more than one catalog type", :other_catalog do
    before { sign_in_as(create(:admin)) }

    it "names the one type that isn't loaded (FR-6)" do
      create(:catalog_refresh_run, status: "applied")

      get catalog_entries_path

      expect(notice_text).to eq("The Pocket Monsters catalog hasn't been loaded yet. Go to the catalog page to load it.")
    end

    it "names every type that isn't loaded (FR-6)" do
      get catalog_entries_path

      expect(notice_text).to eq("The Magic: The Gathering and Pocket Monsters catalogs haven't been loaded yet. " \
        "Go to the catalog page to load them.")
    end
  end

  it "queues no refresh when the first admin signs up (AC-1.5, FR-6)", :aggregate_failures do
    expect {
      post registration_path, params: { user: { name: "Ann", email_address: "ann@example.test", password: "correct horse battery",
                                                password_confirmation: "correct horse battery" } }
    }.not_to have_enqueued_job

    expect(User.sole).to be_admin
  end
end
```

- [ ] Create `spec/requests/admin/navigation_spec.rb`:

```ruby
require "rails_helper"

# Spec 015 AC-7.3: admins find the catalog and jobs pages where they find user administration.
RSpec.describe "Admin navigation", type: :request do
  def links(selector) = Nokogiri::HTML5(response.body).css("#{selector} a").map { |link| [ link.text.squish, link["href"] ] }

  it "links Catalog and Jobs for an admin, on the More page and in the avatar menu", :aggregate_failures do
    sign_in_as(create(:admin))

    get more_path

    expected = [ [ "Users and sign-up", admin_users_path ], [ "Catalog", admin_catalog_path ], [ "Jobs", admin_jobs_path ] ]
    expect(links(".c-more")).to eq(expected)
    expect(links(".c-appbar .c-menu__list")).to eq(expected)
  end

  it "shows a member neither link", :aggregate_failures do
    sign_in_as(create(:user))

    get more_path

    expect(links(".c-more")).to be_empty
    expect(links(".c-appbar .c-menu__list")).to be_empty
  end
end
```

- [ ] Create `spec/system/catalog_not_loaded_spec.rb`:

```ruby
require "rails_helper"

# Spec 015 AC-1.1 in a browser: the notice takes an admin from where the cards are missing to where they are loaded.
RSpec.describe "The not-loaded notice", type: :system do
  it "leads an admin from search to the catalog page, and from More to the jobs page", :aggregate_failures do
    system_sign_in_as(create(:admin))
    visit catalog_entries_path

    click_link "Go to the catalog page"
    expect(page).to have_css("h1", text: "Catalog")
    expect(page).to have_button("Refresh now")

    visit more_path
    click_link "Jobs"
    expect(page).to have_css("h1", text: "Jobs")
  end
end
```

- [ ] Create `spec/admin_catalog_core_spec.rb`:

```ruby
require "rails_helper"

# Spec 015 AC-5.4: the core's admin catalog code names no collectible type, source or operation. A type reaches the
# page only through its source's optional hooks (app/models/catalog/sources.rb).
RSpec.describe "The core's admin catalog code" do
  let(:files) do
    Rails.root.glob("app/controllers/admin/catalogs{_controller.rb,/**/*.rb}") + Rails.root.glob("app/views/admin/catalogs/**/*.erb") +
      Rails.root.glob("app/models/catalog/{operation,operation/*,refresh_operation,health,refresh/progress}.rb") +
      [ Rails.root.join("app/views/catalog/_not_loaded.html.erb"), Rails.root.join("app/helpers/admin_helper.rb"),
        Rails.root.join("app/javascript/controllers/poll_controller.js") ]
  end

  it "covers the controllers, views, models, helper and script of the page" do
    expect(files.size).to eq(14)
  end

  it "never says MTG, Scryfall or art" do
    offenders = files.select { |file| file.read.match?(/\b(mtg|scryfall|art)\b/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
```

- [ ] Change `.rubocop.yml` (apply this diff exactly):

```diff
--- a/.rubocop.yml
+++ b/.rubocop.yml
@@ -38,9 +38,11 @@ RSpec/Output:
 # class, so a string describe is intentional there, and the project-config spec
 # checks repository files, not a class. The hook spec exercises a git hook
 # script, and the collector rake spec a rake task, not a class. The image
-# publishing spec checks the publishing files.
+# publishing spec checks the publishing files, and the admin catalog core spec
+# the files of a page.
 RSpec/DescribeClass:
   Exclude:
+    - "spec/admin_catalog_core_spec.rb"
     - "spec/design_system_files_spec.rb"
     - "spec/githooks/post_checkout_spec.rb"
     - "spec/image_publishing_spec.rb"
```

- [ ] Run: `bin/rspec spec/requests/catalog_not_loaded_spec.rb spec/requests/admin/navigation_spec.rb spec/system/catalog_not_loaded_spec.rb spec/admin_catalog_core_spec.rb` — expect: FAIL (no notice with the new wording, no links, and the core spec can't read `app/views/catalog/_not_loaded.html.erb`). The sign-up example passes already: it pins AC-1.5.
- [ ] Create `app/views/catalog/_not_loaded.html.erb`:

```erb
<%# locals: (titles:) %>
<%# Spec 015 FR-6: while a catalog has no applied refresh, say so where people look for cards. Admins get the way to
    load it; members are told who can. An instance with one catalog type calls it "the card catalog"; with more than
    one, each unloaded type is named. %>
<% if titles.any? %>
  <p id="catalog_not_loaded" class="c-status__message c-status__message--alert">
    <% if Catalog.sources.one? %>The card catalog hasn't been loaded yet.
    <% elsif titles.one? %>The <%= titles.first %> catalog hasn't been loaded yet.
    <% else %>The <%= titles.to_sentence %> catalogs haven't been loaded yet.<% end %>
    <% if Current.user.admin? %>
      <%= link_to "Go to the catalog page", admin_catalog_path %> to load <%= titles.one? ? "it" : "them" %>.
    <% else %>
      Ask an admin to load <%= titles.one? ? "it" : "them" %>.
    <% end %>
  </p>
<% end %>
```

- [ ] Change `app/controllers/catalog/entries_controller.rb` (apply this diff exactly):

```diff
--- a/app/controllers/catalog/entries_controller.rb
+++ b/app/controllers/catalog/entries_controller.rb
@@ -5,6 +5,7 @@ class Catalog::EntriesController < ApplicationController
     @owned = Lot.owned_quantities(Current.account, @groups.flat_map(&:entries).map(&:id))
     @sets = Catalog::Set.with_searchable_entries.newest_first.to_a
     @last_refresh = Catalog::RefreshRun.last_applied
+    @unloaded_catalogs = Catalog.unloaded_titles
   end
 
   def show
```

- [ ] Change `app/controllers/scanners_controller.rb` (apply this diff exactly):

```diff
--- a/app/controllers/scanners_controller.rb
+++ b/app/controllers/scanners_controller.rb
@@ -7,5 +7,6 @@ class ScannersController < ApplicationController
   def show
     @sitting = sitting_locals
     @summary = flash[:sitting_summary]
+    @unloaded_catalogs = Catalog.unloaded_titles
   end
 end
```

- [ ] Change `app/controllers/mores_controller.rb` (apply this diff exactly):

```diff
--- a/app/controllers/mores_controller.rb
+++ b/app/controllers/mores_controller.rb
@@ -1,4 +1,6 @@
 class MoresController < ApplicationController
   def show
+    # Only admins can act on an unloaded catalog from here (spec 015 AC-1.1); members see the notice where they search.
+    @unloaded_catalogs = Current.user.admin? ? Catalog.unloaded_titles : []
   end
 end
```

- [ ] Change `app/views/catalog/entries/index.html.erb` (apply this diff exactly):

```diff
--- a/app/views/catalog/entries/index.html.erb
+++ b/app/views/catalog/entries/index.html.erb
@@ -17,9 +17,7 @@
     <% end %>
 
     <div class="c-results__meta"><% if @search.active? %><span class="c-filterbar__count"><%= pluralize(@search.pagination.total_count, "card") %></span><% end %><% if @last_refresh %><span class="c-results__freshness">Catalog updated <%= l(@last_refresh.finished_at.to_date, format: :long) %></span><% end %></div>
-    <% if @last_refresh.nil? %>
-      <p class="c-status__message c-status__message--alert">The card catalog hasn't been loaded yet.</p>
-    <% end %>
+    <%= render "catalog/not_loaded", titles: @unloaded_catalogs %>
     <% if !@search.active? %>
       <p class="c-empty">Type part of a card name to search.</p>
     <% elsif @groups.empty? %>
```

- [ ] Change `app/views/scanners/show.html.erb` (apply this diff exactly):

```diff
--- a/app/views/scanners/show.html.erb
+++ b/app/views/scanners/show.html.erb
@@ -3,6 +3,7 @@
 <%= render "layouts/appbar", section: :scanner %>
 <main class="c-main c-page">
   <div class="c-pagehead"><div><h1 class="c-pagehead__title">Scan a card</h1></div></div>
+  <%= render "catalog/not_loaded", titles: @unloaded_catalogs %>
   <%= render "scanners/scanner", **@sitting, summary: @summary %>
 </main>
 <%= render "layouts/tabbar", section: :scanner %>
```

- [ ] Change `app/views/mores/show.html.erb` (apply this diff exactly):

```diff
--- a/app/views/mores/show.html.erb
+++ b/app/views/mores/show.html.erb
@@ -6,9 +6,14 @@
       <h1 class="c-pagehead__title">More</h1>
     </div>
   </div>
+  <%= render "catalog/not_loaded", titles: @unloaded_catalogs %>
   <ul class="c-list c-more">
     <li><span>Signed in as <strong><%= Current.user.name %></strong></span><span class="c-list__meta"><%= Current.user.email_address %></span></li>
-    <% if Current.user.admin? %><li><%= link_to "Users and sign-up", admin_users_path %></li><% end %>
+    <% if Current.user.admin? %>
+      <li><%= link_to "Users and sign-up", admin_users_path %></li>
+      <li><%= link_to "Catalog", admin_catalog_path %></li>
+      <li><%= link_to "Jobs", admin_jobs_path %></li>
+    <% end %>
     <li><%= button_to "Sign out", session_path, method: :delete, class: "c-btn c-btn--secondary" %></li>
   </ul>
 </main>
```

- [ ] Change `app/views/layouts/_appbar.html.erb` (apply this diff exactly):

```diff
--- a/app/views/layouts/_appbar.html.erb
+++ b/app/views/layouts/_appbar.html.erb
@@ -20,7 +20,7 @@
       <details class="c-menu" data-controller="menu">
         <summary class="c-avatar" aria-label="Account: <%= Current.user.name %>"><%= Current.user.initial %></summary>
         <div class="c-menu__list">
-          <% if Current.user.admin? %><%= link_to "Users and sign-up", admin_users_path, class: "c-menu__item" %><div class="c-menu__sep"></div><% end %>
+          <% if Current.user.admin? %><%= link_to "Users and sign-up", admin_users_path, class: "c-menu__item" %><%= link_to "Catalog", admin_catalog_path, class: "c-menu__item" %><%= link_to "Jobs", admin_jobs_path, class: "c-menu__item" %><div class="c-menu__sep"></div><% end %>
           <%= button_to "Sign out", session_path, method: :delete, class: "c-menu__item", form: { class: "c-menu__form" } %>
         </div>
       </details>
```

- [ ] Change `app/assets/stylesheets/collector/additions.css` (apply this diff exactly):

```diff
--- a/app/assets/stylesheets/collector/additions.css
+++ b/app/assets/stylesheets/collector/additions.css
@@ -206,3 +206,8 @@
 /* ---------- Progress meter (spec 015): a bar with its percentage and, where there are any, the amounts in words ---------- */
 .c-meter { display:flex; flex-wrap:wrap; align-items:center; gap:var(--space-2); font:400 13px/18px var(--font-mono); color:var(--ink-muted); }
 .c-meter__bar { flex:1 1 160px; min-width:0; height:var(--space-2); accent-color:var(--brand); }
+
+/* ---------- Links inside a status message use the brand link colour (spec 015: the not-loaded notice) ---------- */
+.c-status__message a { color:var(--brand); font-weight:600; text-decoration:none; }
+.c-status__message a:hover { text-decoration:underline; }
+.c-status__message a:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
```

- [ ] Change `docs/design-system/components/StatusMessage.md` (apply this diff exactly):

````diff
--- a/docs/design-system/components/StatusMessage.md
+++ b/docs/design-system/components/StatusMessage.md
@@ -16,11 +16,13 @@ A one-line message under the header that confirms what just happened ("Added 1 
 
 ```html
 <p class="c-status__message c-status__message--alert">This printing is no longer present in the upstream source.</p>
-<p class="c-status__message c-status__message--alert">The card catalog hasn't been loaded yet.</p>
+<p class="c-status__message c-status__message--alert">The card catalog hasn't been loaded yet. Ask an admin to load it.</p>
+<p class="c-status__message c-status__message--alert">The card catalog hasn't been loaded yet. <a href="/admin/catalog">Go to the catalog page</a> to load it.</p>
 ```
 
 - There is one live region per page (`#status`), always present so screen readers register it before it changes; `c-status:empty` hides it when there is no message.
 - Messages are one plain sentence that says exactly what happened, with exact numbers: "Removed 3 × Opt (XLN · 65) from your collection.", "Saved.", never "Success!".
 - A redirect carries the message in the flash (`notice` or `alert`); an answer that leaves the page as it was updates `#status` with a Turbo Stream (`turbo_stream.update("status", …)`).
+- A link inside a message is a brand link: `brand` colour, semibold, underlined on hover, with the `focus` ring. The catalog notice (spec 015) gives admins the link and tells everyone else who to ask.
 - Use the inline notice only for a state the page is in; never put action results outside the live region, or they won't be announced.
 - Padding follows the page gutter: `space-8` on wide screens, `space-4` below 640px.
````

- [ ] Change `docs/design-system/components/MorePage.md` (apply this diff exactly):

````diff
--- a/docs/design-system/components/MorePage.md
+++ b/docs/design-system/components/MorePage.md
@@ -2,7 +2,7 @@
 
 The page behind the tab bar's "More" tab: who is signed in, account links, and sign out.
 
-**Markup** — a heading and a `c-list c-more`, one row per entry; the consumer adds the admin link only for admins.
+**Markup** — a heading and a `c-list c-more`, one row per entry; the consumer adds the admin links (users, catalog, jobs) only for admins.
 
 ```html
 <main class="c-main">
@@ -10,6 +10,8 @@ The page behind the tab bar's "More" tab: who is signed in, account links, and s
   <ul class="c-list c-more">
     <li><span>Signed in as <strong>Sam</strong></span><span class="c-list__meta">sam@example.com</span></li>
     <li><a href="/admin/users">Users and sign-up</a></li>
+    <li><a href="/admin/catalog">Catalog</a></li>
+    <li><a href="/admin/jobs">Jobs</a></li>
     <li><form class="button_to" method="post" action="/session"><input type="hidden" name="_method" value="delete"><button class="c-btn c-btn--secondary" type="submit">Sign out</button></form></li>
   </ul>
 </main>
````

- [ ] Run: `bin/rspec spec/requests spec/system/catalog_not_loaded_spec.rb spec/admin_catalog_core_spec.rb spec/system/scanner_spec.rb spec/system/catalog_search_spec.rb` — expect: PASS.
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `feat(catalog): say when the catalog isn't loaded, and link the admin pages (015)`

---

## Phase 9: Documentation, benchmarks and integration verification

**Implements:** All FRs; NFR Performance (manual benchmarks) | **Satisfies:** All ACs
**Files:** `README.md`, `CLAUDE.md`, `spec/readme_spec.rb`, `docs/specs/015-admin-catalog-and-jobs/research.md`
**Interfaces:** Consumes: everything. Produces: the documented feature and the recorded benchmarks.

Self-hosters read the README, agents read CLAUDE.md, and the two manual benchmarks are recorded once.

- [ ] Change `spec/readme_spec.rb` (apply this diff exactly):

```diff
--- a/spec/readme_spec.rb
+++ b/spec/readme_spec.rb
@@ -36,6 +36,12 @@ RSpec.describe "README" do
     expect(scanner).to include("HTTPS", "only the photo picker works", "Docker Compose", "Kamal", "ssl: true", "registry.npmjs.org")
   end
 
+  it "documents the admin catalog and jobs pages (spec 015)", :aggregate_failures do
+    catalog = readme[/^## Card catalog\n.*?(?=^## )/m].to_s
+    expect(catalog).to include("Refresh now", "/admin/catalog", "/admin/jobs", "interrupted", "retried or", "Build art index")
+    expect(catalog.index("Refresh now")).to be < catalog.index('bin/rails "catalog:refresh[mtg]"')
+  end
+
   it "documents opt-in art matching in the README, Compose and Kamal (spec 011 AC-1.3)", :aggregate_failures do
     art = readme[/^- \*\*Art matching \(optional\):\*\*.*?(?=^- \*\*|^## )/m].to_s
     expect(readme).to include("| `COLLECTOR_MTG_ART_MATCHING`")
```

- [ ] Run: `bin/rspec spec/readme_spec.rb` — expect: FAIL (the README doesn't mention the pages).
- [ ] Change `README.md` (apply this diff exactly):

````diff
--- a/README.md
+++ b/README.md
@@ -250,8 +250,13 @@ Card data comes from [Scryfall](https://scryfall.com)'s bulk data files, which t
 downloads in a background job and caches in its own database. Pages are rendered only from
 that local copy; the app never calls Scryfall while rendering a page.
 
-**The catalog is empty until the first refresh.** After the first deployment, queue a manual
-refresh:
+**The catalog is empty until the first refresh.** After the first deployment, sign in as an
+admin and open **Catalog** (in the account menu, or under More on a phone). Press
+**Refresh now** and the page shows the download and the sync as they go, without reloading.
+Until then, search and the scanner say that the catalog hasn't been loaded. Nothing downloads
+until you start it, so set the languages below first if you want more than English.
+
+You can also queue the refresh from a shell:
 
 ```sh
 bin/rails "catalog:refresh[mtg]"                          # locally
@@ -267,6 +272,14 @@ any error message:
 bin/rails "catalog:status[mtg]"   # Kamal: bin/kamal catalog-status
 ```
 
+- **Catalog page:** `/admin/catalog` shows each catalog's cards, its last applied refresh, when
+  the next one is scheduled, the running refresh's stage and progress, and its recent runs. A
+  refresh that stops making progress for 15 minutes is shown as interrupted (after a restart,
+  for example); pressing **Refresh now** then starts it again.
+- **Jobs page:** `/admin/jobs` lists the app's background jobs that failed, are running, are
+  queued or are scheduled. A failed job shows its error and backtrace, and can be retried or
+  discarded there. Both pages are for admins only.
+
 - **Schedule:** in production the catalog refreshes weekly, on Mondays at 03:15 server time
   (`config/recurring.yml`). A scheduled run is skipped when the same Scryfall file and
   language set were already applied; a manual run always applies. Only one refresh per
@@ -280,7 +293,8 @@ bin/rails "catalog:status[mtg]"   # Kamal: bin/kamal catalog-status
   recognises a card by its artwork on live captures. It's off by default because the first
   build costs about 708 MB of downloads (one small image per artwork from Scryfall),
   about 2.6 hours of throttled fetching and then fingerprinting, and leaves an index of
-  about 7.3 MB. The build runs in the background after a catalog refresh; to start it now, run
+  about 7.3 MB. The build runs in the background after a catalog refresh; to start it now, press
+  **Build art index** on the Catalog page, which also shows its progress, or run
   `bin/rails "catalog:refresh[mtg]"` (Kamal: `bin/kamal catalog-refresh`), and follow it with
   `bin/rails "catalog:status[mtg]"`. Later refreshes fetch only new artworks. Until the first
   build finishes, and whenever art matching is off, the scanner works on text alone. Images
````

- [ ] Change `CLAUDE.md` (apply this diff exactly):

```diff
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -4,7 +4,7 @@ This file provides guidance to Claude Code (claude.ai/code) when working with co
 
 ## Project Status
 
-Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards. The Rails app skeleton exists (stack, RSpec, `bin/ci`, Compose and Kamal deployment). Feature 002 added a collectible-agnostic catalog core (`app/models/catalog/`) with an MTG extension (`app/models/mtg/`), Scryfall bulk-data ingestion via a background refresh, and a public card search proof-of-concept at `/catalog/entries`. Accounts (row-level tenancy through `Current.account`) and collections of lots (spec 004, list view spec 006) exist, and the card scanner (specs 005, 007–009) adds scanned cards to the collection through its confirm flow. License: AGPL-3.0.
+Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with Magic: The Gathering cards. The Rails app skeleton exists (stack, RSpec, `bin/ci`, Compose and Kamal deployment). Feature 002 added a collectible-agnostic catalog core (`app/models/catalog/`) with an MTG extension (`app/models/mtg/`), Scryfall bulk-data ingestion via a background refresh, and a public card search proof-of-concept at `/catalog/entries`. Accounts (row-level tenancy through `Current.account`) and collections of lots (spec 004, list view spec 006) exist, and the card scanner (specs 005, 007–009) adds scanned cards to the collection through its confirm flow. Admins start and watch catalog refreshes and art index builds at `/admin/catalog`, and see, retry and discard background jobs at `/admin/jobs` (spec 015). License: AGPL-3.0.
 
 Mission and principles: `.claude/memory/foundation.md`. Detailed coding rules: `.claude/rules/`. Feature specs: `docs/specs/`.
 
@@ -27,11 +27,12 @@ Ruby 4.0.7, Rails 8.1.4, SQLite in every environment (including production), Hot
 
 ## Non-obvious Facts
 
-- **Dev mirrors prod.** Development uses separate SQLite DBs (`storage/development{,_cache,_queue,_cable}.sqlite3`) and runs Solid Queue inside Puma (`config/puma.rb` plugin), so the server already processes jobs. Never also run `bin/jobs` (two supervisors on one SQLite queue DB). The test env uses Rails defaults (primary DB only, `:test` job adapter, null cache).
+- **Dev mirrors prod.** Development uses separate SQLite DBs (`storage/development{,_cache,_queue,_cable}.sqlite3`) and runs Solid Queue inside Puma (`config/puma.rb` plugin), so the server already processes jobs. Never also run `bin/jobs` (two supervisors on one SQLite queue DB). The test env uses Rails defaults (primary DB only, `:test` job adapter, null cache); Solid Queue's tables are loaded into that one database for the admin pages' specs.
 - **Worktrees:** `bin/setup` sets `core.hooksPath=.githooks` (unless a custom hooks path exists), so `git worktree add`, `claude --worktree` and Orca (`orca.yaml`) worktrees set themselves up via `.githooks/post-checkout` (new linked worktrees only; failures keep the worktree). Each worktree has its own DBs; dev port is 3000 in the main checkout, 3001–3999 per worktree (`lib/collector/dev_port.rb`), `PORT` overrides. Copy list = `.worktreeinclude` (copied only if missing, mode 0600; logic in `lib/collector/worktree_setup.rb`). A missing `config/master.key` only warns; a wrong one breaks boot.
 - **Specs:** tag spec types explicitly (`type: :request`, `type: :system`; no inference); multi-expectation examples use `:aggregate_failures`. System specs run in headless Firefox. WebMock + VCR block all real HTTP (cassettes in `spec/cassettes`).
 - **Deploy:** Compose (`compose.yaml`, `image:` defaults to the published `ghcr.io/plainprogrammer/collector:latest`, `COLLECTOR_IMAGE` overrides) and Kamal (`config/deploy.yml`, registry `ghcr.io`, placeholder server; deploy a release with `bin/kamal deploy --skip-push --version X.Y.Z`) both mount the `collector_storage` volume at `/rails/storage` and set `SOLID_QUEUE_IN_PUMA`. Both paths are documented in `README.md`; keep it in sync. `.dockerignore` keeps `docs/`, `spec/`, `spikes/`, `script/` and agent files out of the (public) image.
 - **Catalog data is global** (no `account_id`) and changes only through `Catalog::Refresh` (weekly `config/recurring.yml` schedule + the manual rake task, via `Catalog::RefreshJob`) and, for the MTG art index (spec 011, opt-in `COLLECTOR_MTG_ART_MATCHING`), `MTG::Art::BuildJob`, which the refresh queues and which writes `mtg_artworks`, `mtg_art_builds`, the image cache and the index under `storage/catalog/mtg/art/`. Downloads are kept in `storage/catalog/<type>/`. Pages never call Scryfall during render.
+- **Admin catalog and jobs (spec 015, ADRs 0014 and 0015):** `/admin/catalog` renders `Catalog::Health` (one per registered type) and its `Catalog::Operation`s: the core's `Catalog::RefreshOperation`, plus whatever a source's optional `.operations` hook adds (`MTG::Art::Operation`); the core code never names a collectible (`spec/admin_catalog_core_spec.rb`). A refresh run records its stage, progress, heartbeat and job id (`Catalog::Refresh::Progress`); 15 minutes without progress is a stall (`Catalog::RefreshRun::STALL_AFTER`), separate from the job's 6-hour queue lock (`Catalog::RefreshJob::LOCK_FOR`). "In flight" and the jobs pages (`BackgroundJobs::List`, `BackgroundJobs::Entry`) read Solid Queue's own tables. Pages poll with the `poll` Stimulus controller only while work is in flight. In specs, Solid Queue's tables are loaded into the test database (`spec/support/solid_queue.rb`); tag an example `:solid_queue` to queue through Solid Queue (no worker runs) and move jobs with `queue_job`, `claim_job`, `fail_job`, `finish_job`.
 - **Card scanner (specs 007, 009):** `/scanner`, linked from the navigation ("Scan") and the collection page. A scan is confirmed and added as a lot; the sitting's adds live in `scanner_sittings`/`scanner_sitting_entries` (one entry per reading key) until Done. Picked photos go through the hand-written detector (`app/javascript/scanner/detector.js`, ADR 0005); `script/scanner/detector_parity.rb` checks it against the spike's. Spec 009's findings tasks: `scanner:ranking`, `scanner:strong_sweep`, `scanner:foil_markers`, `scanner:detected_score`, `scanner:replay_score`, `scanner:overlap`, `scanner:sitting_findings` (results in `docs/specs/009-card-scanner-confirm-flow/research.md`). Its OCR engine is fetched and checksum-verified into the ignored `vendor/ocr/v7.0.0/` by `bin/fetch-ocr-engine` (run by `bin/setup` and the Dockerfile) and served by `OcrAssetsController`; scanner specs fail until it's installed. Art matching (spec 011, ADRs 0006, 0007 and 0012) needs ImageMagick (`magick` or `convert`) for the build and its specs; the page searches `/scanner/art/<index>` on the device. Only scanner pages send a Content-Security-Policy (`ScannerPage` concern); nonces exist only on those requests. Measurement mode (`/scanner/measurement`) is development-only (`config.x.scanner_measurement`; `COLLECTOR_SCANNER_MANIFEST`, `COLLECTOR_SCANNER_RUN_DIR`) and writes outside the repo. The art spike (spec 010) lives in `spikes/card_scanner/phase3/` (phone timing and replay server; spec 008's art tools take `CARD_SCANNER_WORK_DIR`, `CARD_SCANNER_TRUTH_CORPORA` and `CARD_SCANNER_BULK_FILE`), and measurement mode keeps live frames with `COLLECTOR_SCANNER_KEEP_FRAMES=1`. Phones need HTTPS: `bin/dev-certificate` makes a self-signed certificate outside the repo and prints the `bin/dev -b "ssl://…"` bind (alternative: a tunnel with `RAILS_DEVELOPMENT_HOSTS` + `COLLECTOR_HTTPS=true`).
 - **Off-limits for reads (permission-denied):** `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`. Don't try to read them.
 
```

- [ ] Run: `bin/rspec spec/readme_spec.rb spec/project_config_spec.rb spec/design_system_files_spec.rb` — expect: PASS.
- [ ] Run: `bin/rubocop` — expect: no offenses.
- [ ] Commit (stage with `git add`, then commit in a separate command): `docs(015): document the admin catalog and jobs pages`
- [ ] Run: `bin/ci` — expect: every step green (setup, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec: 0 failures; the one pending example is the art agreement spec, which needs its corpus).
- [ ] Manual benchmark 1, page render (NFR Performance). Needs the development server and a loaded MTG catalog; ask the maintainer before starting the server. Fill the development queue with stand-in jobs that can't run (a class that doesn't exist, due in a year), then remove them. The hashes are passed as hashes: Solid Queue serializes those columns itself.

```sh
bin/rails runner '
  now = Time.current
  rows = ->(count, **extra) { Array.new(count) { { queue_name: "bench", class_name: "Bench::NoopJob", arguments: { "arguments" => [], "executions" => 0 }, priority: 0, active_job_id: SecureRandom.uuid, scheduled_at: 1.year.from_now, created_at: now, updated_at: now, **extra } } }
  SolidQueue::Job.insert_all(rows.call(1_000, finished_at: now))
  failed = SolidQueue::Job.insert_all(rows.call(100), returning: %w[id]).map { |row| row["id"] }
  SolidQueue::FailedExecution.insert_all(failed.map { |id| { job_id: id, error: { exception_class: "RuntimeError", message: "bench", backtrace: [] }, created_at: now } })
  due = SolidQueue::Job.insert_all(rows.call(100), returning: %w[id]).map { |row| row["id"] }
  SolidQueue::ScheduledExecution.insert_all(due.map { |id| { job_id: id, queue_name: "bench", priority: 0, scheduled_at: 1.year.from_now, created_at: now } })
  puts SolidQueue::Job.where(queue_name: "bench").count'
```

  Expect `1200`. Sign in as an admin, load `/admin/catalog` and `/admin/jobs` five times each, and read each request's `Completed 200 OK in …ms` line in `log/development.log`. Record the five times per page; the target is under 300 ms. Then remove the stand-ins: `bin/rails runner 'ids = SolidQueue::Job.where(queue_name: "bench").ids; SolidQueue::FailedExecution.where(job_id: ids).delete_all; SolidQueue::ScheduledExecution.where(job_id: ids).delete_all; puts SolidQueue::Job.where(id: ids).delete_all'` — expect `1200`.
- [ ] Manual benchmark 2, progress overhead (NFR Performance). Needs the maintainer's go-ahead: it calls Scryfall's `/bulk-data` and downloads the bulk file if a newer one is out. With the development server stopped (so no second refresh can start) and `COLLECTOR_MTG_ART_MATCHING` unset (or each applied run queues an art build that runs when the server next starts), time a refresh that changes nothing with and without progress writes:

```sh
bin/rails runner '
  time = ->(label) { started = Process.clock_gettime(Process::CLOCK_MONOTONIC); run = Catalog::Refresh.new("mtg", trigger: "manual").call; puts "#{label}: #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(2)} s, #{run.status}, seen #{run.seen_count}" }
  time.call("warm-up (downloads if needed)")
  time.call("with progress")
  Catalog::Refresh::Progress.prepend(Module.new { def write = (@records = 0; @written_at = @clock.call) })
  time.call("without progress writes")'
```

  Expect three applied runs. The target: "with progress" is no more than 5% slower than "without progress writes".
- [ ] Write `docs/specs/015-admin-catalog-and-jobs/research.md` with both benchmarks: the date, the machine, the catalog's size, the five times per page, the two refresh times and their ratio, and whether each target was met. A missed target is recorded as missed and raised with the maintainer; it doesn't fail the build. Add one note for a later spec: a run whose job crashed less than 15 minutes ago still reads "Running." with no pointer to the failed job until the stall threshold passes, which is what the spec asks.
- [ ] Watch a real refresh (needs the maintainer's go-ahead for the development server). Start `bin/dev` as a background task, sign in as an admin, open `/admin/catalog`, press "Refresh now", and check against the spec: the button disables at once; the stages advance by themselves; the download and sync show a rising percentage; the counts rise; the run ends as applied with its counts; the page stops asking (no further requests in the server log). With `COLLECTOR_MTG_ART_MATCHING=true`, check the art index section starts building after the refresh.
- [ ] Restart mid-refresh: press "Refresh now", stop the server while the sync runs, start it again. Expect the job to run again by itself, the earlier run to be listed as failed with "interrupted" in Recent refreshes, and the new run to proceed (AC-3.3). Stop the server task when done.
- [ ] Open `/admin/jobs`: the filters show counts, a finished refresh isn't listed, and the page for any job renders.
- [ ] Commit: `docs(015): record the admin pages' benchmarks`
- [ ] Delete the planning prototypes: `git branch -D 015-plan-phases`.

---

## Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run the full suite: `bin/ci` — expect every step green.
- [ ] Walk the spec's acceptance criteria against the specs named in each phase header; every AC has at least one example citing it (`grep -rn "AC-" spec/ | grep -c "015\|AC-[1-7]\."` is a quick sanity check, not the proof).
- [ ] Run `sdd-superpowers:sdd-review` (Mode B) before `finishing-a-development-branch`.

## Quickstart Validation

1. `bin/setup --skip-server && bin/rspec spec/requests/admin spec/system/admin_catalog_spec.rb spec/system/admin_jobs_spec.rb` — green.
2. `bin/dev`, sign in as an admin, open the account menu: "Catalog" and "Jobs" are there.
3. On a fresh database, Search says "The card catalog hasn't been loaded yet. Go to the catalog page to load it."
4. `/admin/catalog` → "Refresh now" → stages and percentages move by themselves → "Applied." → Search finds cards.
5. `/admin/jobs` → "Failed", "Running", "Queued", "Scheduled" with counts; a failed job offers "Retry" and "Discard…".
6. `bin/rails "catalog:status[mtg]"` lists the same runs with the same words.
