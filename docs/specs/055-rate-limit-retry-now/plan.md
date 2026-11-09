# Implementation Plan: Retry Now for a Job Waiting to Retry

**Spec:** docs/specs/055-rate-limit-retry-now/spec.md (v1.0.0, approved 2026-11-09; open question 1 ruled by the maintainer for the wide offer)
**Decisions:** none new (no ADR: the move uses Solid Queue's own operations, which ADR 0014 already chose to read and act on; no table, route family or dependency is new)
**Created:** 2026-11-09

## Global Constraints

Copied from the spec; every phase includes them.

- No migration, no new column, no stored data; the export format and the backup are untouched (NFR Reliability).
- The request moves one scheduled queue entry of the operation's own latest failed run's job. It runs nothing, calls no source, writes no run record, queues no job (decision 2, AC-2.8, FR-1).
- The request names only a catalog type and an operation key, each looked up among what is registered; a job id or any other parameter has no effect (decision 4, AC-4.4).
- The move is atomic with one winner: the scheduled entry is removed first, and the move goes on only when exactly that removal happened (decision 3, FR-2).
- The offer is decided in one place (`Catalog::Operation#retry_job_id`, with the `retryable?` hook), and re-read at press time (FR-1, decision 1, open question 1's ruling).
- The refresh's "Queued to retry" means the failed run's own job, as the art build's already does (decision 1, AC-1.6, AC-1.7; supersedes spec 015 AC-3.7 in part).
- Wording, exact: button "Retry now" (`c-btn--secondary`); notices "Retrying now." and "Nothing is waiting to retry."; both on a `303` to `/admin/catalog` (decision 5).
- Admin only: 404 for a member, sign-in for a visitor (spec 015 FR-7); the core names no collectible: `spec/admin_catalog_core_spec.rb` keeps passing, its file count raised by the one new controller (AC-6.4).
- No new component, class or token (spec FR-4): the two buttons share the existing `c-operation__start` class, whose rule gains a `gap` (Task 3.4), documented in `AdminCatalog.md` (Task 5.3).
- Test files: `type:` tags explicit, `:aggregate_failures` on multi-expectation examples, no `any_instance_of`, no `sleep`; Solid Queue examples are tagged `:solid_queue` and move jobs with `queue_job`, `claim_job`, `fail_job`, `finish_job` (`.claude/rules/testing.md`, CLAUDE.md).
- Commits: one Conventional Commit per task, ending with the `Co-Authored-By:` line the coordinator's brief gives. Stage and commit in separate Bash calls. Targeted `bin/rspec <file>` runs need no CI slot; the one full `bin/ci`, run by the pre-push hook, needs one (Task 5.9).

---

## Goal

While a rate-limited refresh or art index build waits for its scheduled retry, `/admin/catalog` shows "Retry now" on its panel, and pressing it runs that same job at once, once, however many presses or dispatches reach it.

---

## Phase 1: The queue-side move

**Implements:** FR-2 | **Satisfies:** AC-2.7, AC-3.1 (queue level), AC-3.2, AC-3.3 (queue level), AC-3.4, AC-3.6, AC-3.7, decision 3
**Files:** `app/models/catalog/operation/queue.rb`, `spec/models/catalog/operation/queue_spec.rb`
**Interfaces:** Consumes: `SolidQueue::Job`, `SolidQueue::ScheduledExecution`, `SolidQueue::Record`, `SolidQueue::Job#dispatch` (Solid Queue 1.7.0). Produces: `Catalog::Operation::Queue#run_now(active_job_id)` → `true` when this call moved the job's scheduled entry, `false` (changing nothing) otherwise.

Solid Queue gives no "run this scheduled job now". Its own dispatcher deletes a scheduled entry after dispatching, and `Job#dispatch` does not check the entry exists, so a second dispatch of a limited job that is already ready or claimed would add a blocked entry that later runs it again. The move therefore deletes the entry first, inside one transaction on the queue's database, and dispatches only when that delete removed exactly one row.

- [ ] **Task 1.1: write the failing examples.** In `spec/models/catalog/operation/queue_spec.rb`, add before the file's last `end`:

```ruby

  describe "#run_now (spec 055 FR-2)" do
    def waiting(wait: 10.minutes) = queue_job(Catalog::RefreshJob, "mtg", "manual", wait:)

    it "makes a scheduled job ready, adding no job and leaving its Active Job id and arguments as they were", :aggregate_failures do
      job = waiting
      before = job.slice(:id, :active_job_id, :arguments)

      expect { expect(queue.run_now(job.active_job_id)).to be(true) }.not_to change(SolidQueue::Job, :count)

      expect(job.reload.slice(:id, :active_job_id, :arguments)).to eq(before)
      expect(job).to be_ready
      expect(job.scheduled_execution).to be_nil
      expect(job.blocked_execution).to be_nil
    end

    it "moves a retry that is due but not yet dispatched, and the dispatcher then finds nothing (AC-3.2, AC-3.4)", :aggregate_failures do
      job = waiting
      job.scheduled_execution.update_columns(scheduled_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations -- the wait is over, the dispatcher hasn't run

      expect(queue.run_now(job.active_job_id)).to be(true)
      expect(SolidQueue::ScheduledExecution.dispatch_next_batch(10)).to eq(0)
      expect(SolidQueue::ReadyExecution.where(job_id: job.id).count).to eq(1)
      expect(SolidQueue::BlockedExecution.where(job_id: job.id)).to be_none
    end

    it "does nothing when the dispatcher got there first (AC-3.4)", :aggregate_failures do
      job = waiting
      job.scheduled_execution.update_columns(scheduled_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations -- the wait is over
      expect(SolidQueue::ScheduledExecution.dispatch_next_batch(10)).to eq(1)

      expect(queue.run_now(job.active_job_id)).to be(false)
      expect(SolidQueue::ReadyExecution.where(job_id: job.id).count).to eq(1)
      expect(SolidQueue::BlockedExecution.where(job_id: job.id)).to be_none
    end

    it "moves it once: a second call changes nothing (AC-3.1)", :aggregate_failures do
      job = waiting

      expect(queue.run_now(job.active_job_id)).to be(true)
      expect(queue.run_now(job.active_job_id)).to be(false)
      expect(SolidQueue::ReadyExecution.where(job_id: job.id).count).to eq(1)
      expect(SolidQueue::BlockedExecution.where(job_id: job.id)).to be_none
    end

    it "does nothing for a job that isn't waiting for a later time (AC-3.3)", :aggregate_failures do
      job = queue_job(Catalog::RefreshJob, "mtg", "manual")
      expect(queue.run_now(job.active_job_id)).to be(false) # ready
      claim_job(job)
      expect(queue.run_now(job.active_job_id)).to be(false) # claimed
      finish_job(job)
      expect(queue.run_now(job.active_job_id)).to be(false) # finished
      failed = fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
      expect(queue.run_now(failed.active_job_id)).to be(false) # failed
      expect(queue.run_now("no-such-job")).to be(false)
      expect(SolidQueue::BlockedExecution.count).to eq(0)
    end

    it "moves no job of another type or another class, whatever its Active Job id", :aggregate_failures do
      other_type = queue_job(Catalog::RefreshJob, "other", "manual", wait: 10.minutes)
      other_class = queue_job(MTG::Art::BuildJob, wait: 10.minutes)

      expect(queue.run_now(other_type.active_job_id)).to be(false)
      expect(queue.run_now(other_class.active_job_id)).to be(false)
      expect(other_type.reload).to be_scheduled
      expect(other_class.reload).to be_scheduled
    end

    it "blocks a refresh behind another refresh of the type that holds its lock, and runs it when that one ends (AC-2.7)", :aggregate_failures do
      holder = queue_job(Catalog::RefreshJob, "mtg", "scheduled") # takes the type's concurrency lock
      job = waiting

      expect(queue.run_now(job.active_job_id)).to be(true)
      expect(job.reload).to be_blocked
      expect(job.ready_execution).to be_nil

      finish_job(holder)
      expect(job.reload).to be_ready
    end

    it "moves the scheduled row of a refresh retry whose old attempt is still claimed, to a blocked entry (AC-3.6)", :aggregate_failures do
      old = claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual"))
      retry_row = waiting
      retry_row.update_columns(active_job_id: old.active_job_id) # rubocop:disable Rails/SkipsModelValidations -- Active Job's retry keeps the id

      expect(queue.run_now(old.active_job_id)).to be(true)
      expect(retry_row.reload).to be_blocked
      expect(old.reload).to be_claimed

      finish_job(old)
      expect(retry_row.reload).to be_ready
    end

    it "moves the scheduled row of an art build retry whose old attempt is still claimed, to a ready entry (AC-3.7)", :aggregate_failures do
      builds = described_class.new(MTG::Art::BuildJob)
      old = claim_job(queue_job(MTG::Art::BuildJob))
      retry_row = queue_job(MTG::Art::BuildJob, wait: 10.minutes)
      retry_row.update_columns(active_job_id: old.active_job_id) # rubocop:disable Rails/SkipsModelValidations -- Active Job's retry keeps the id

      expect(builds.run_now(old.active_job_id)).to be(true)
      expect(retry_row.reload).to be_ready
      expect(old.reload).to be_claimed
      expect(SolidQueue::BlockedExecution.count).to eq(0)
    end

    it "puts the entry back when the dispatch fails, so nothing is lost", :aggregate_failures do
      job = waiting
      allow(SolidQueue::Semaphore).to receive(:wait).and_raise(ActiveRecord::StatementTimeout)

      expect { queue.run_now(job.active_job_id) }.to raise_error(ActiveRecord::StatementTimeout)
      expect(job.reload).to be_scheduled
    end
  end
```

- [ ] **Task 1.2: run it, expect FAIL.** `bin/rspec spec/models/catalog/operation/queue_spec.rb -e "#run_now"` — expect: every example in the new describe fails with `NoMethodError: undefined method 'run_now'`.
- [ ] **Task 1.3: implement.** In `app/models/catalog/operation/queue.rb`, add after `waiting_to_retry?` and before `private`:

```ruby

  # Makes the scheduled job with this Active Job id run now (spec 055): its scheduled entry is removed and the job is
  # dispatched as the queue's own dispatcher would when its time came, so a job with a concurrency limit still takes it,
  # or waits for it. True when this call moved it; false, changing nothing, when no job of this queue with this id has a
  # scheduled entry any more: a worker or the dispatcher got there first, it finished, or it never was. The entry is
  # removed first and the dispatch happens only when exactly one row went, because the queue's dispatch doesn't check the
  # entry exists: dispatching a limited job that is already ready or claimed would add a blocked entry that runs it again.
  # A retry is a new row with the same Active Job id, so the row to move is the unfinished one holding the entry. The
  # transaction is on the queue's own database, and requires_new puts the entry back when the dispatch fails, even when
  # it is called inside another transaction.
  def run_now(active_job_id)
    SolidQueue::Record.transaction(requires_new: true) do
      scheduled = scheduled_entry_of(active_job_id)
      next false unless scheduled && SolidQueue::ScheduledExecution.where(id: scheduled.id).delete_all == 1

      scheduled.job.dispatch
      true
    end
  end
```

and, in the private section, after `first_argument_of`:

```ruby

    # The scheduled entry of the unfinished job of this class (and type) with this Active Job id, read now, not from the
    # memoized reading of #jobs.
    def scheduled_entry_of(active_job_id)
      SolidQueue::Job.where(class_name: @job_class.name, active_job_id:, finished_at: nil).includes(:scheduled_execution)
        .find { |job| job.scheduled_execution && (@first_argument.nil? || first_argument_of(job) == @first_argument) }
        &.scheduled_execution
    end
```

- [ ] **Task 1.4: run it, expect PASS.** `bin/rspec spec/models/catalog/operation/queue_spec.rb` — expect: all examples pass (the file's earlier ones too).
- [ ] **Task 1.5: commit.** `feat(admin): move a scheduled job to run now, once (spec 055 FR-2, #77)`.

> **Complexity note** (Simplicity Gate: one method more on an existing class). The transaction's `requires_new` exists only so the rollback example can show the entry coming back inside the test's own transaction; at the top level it changes nothing. In the test environment the queue shares the primary database, so no example can show that the transaction is opened on the queue's own connection (`SolidQueue::Record`, not `ActiveRecord::Base`); that is checked by reading and recorded in `verification.md` (Task 5.5). Two simultaneous requests are not run on threads: the delete-first row count is what serialises them under SQLite's IMMEDIATE transactions, and the dispatcher-first, press-first, stale and repeated orders above are the examples of it.

---

## Phase 2: The operation offers and performs it, and the refresh's state is tied to its own job

**Implements:** FR-1, FR-5 (the one change) | **Satisfies:** AC-1.1 (model level), AC-1.2 (model level), AC-1.3, AC-1.3a, AC-1.4, AC-1.5, AC-1.6, AC-1.7, AC-2.1 and AC-2.2 (model level), AC-2.6, AC-3.5, AC-2.8 (no run written)
**Files:** `app/models/catalog/operation.rb`, `app/models/catalog/refresh_operation.rb`, `app/models/mtg/art/operation.rb`, `spec/models/catalog/refresh_operation_spec.rb`, `spec/models/mtg/art/operation_spec.rb`, `spec/requests/admin/catalogs_spec.rb`
**Interfaces:** Consumes: `Catalog::Operation::Queue#run_now`, `#retry_at(active_job_id)` (Phase 1 and existing). Produces: `Catalog::Operation#retry_candidate` (the operation's latest run or build record, or nil; default nil), `#retryable?(record)` (hook, default true), `#retry_job_id` (the Active Job id of the failed candidate's own job when it waits for a later time, else nil), `#retry_now?` (Boolean), `#retry_now` (Boolean: true when this call moved the job).

Today the refresh asks the queue for any scheduled job (`queue.retry_at`) while the build asks for its own (`queue.retry_at(build.job_id)`). One statement serves both: the candidate is the failed latest run or build, and its own job must be scheduled. `retryable?` is the one hook the offer rule turns on: if the maintainer's ruling ever narrows to rate-limit retries, `retryable?` is the only thing to change (and AC-1.5 with it).

- [ ] **Task 2.1: write the failing refresh examples.** In `spec/models/catalog/refresh_operation_spec.rb`:

  (a) The two existing examples under `context` "…" that read "shows a failed run whose job waits to retry as queued…" (line ~351) and "still shows the failed run, queued to retry, after another refresh was skipped for it" (line ~365) create the run before the job and without a job id. The refresh now ties the state to the run's own job, so each creates the job first and gives the run its id. Replace

```ruby
        run(status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503")
        queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)
```
with
```ruby
        job = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)
        run(status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503", job_id: job.active_job_id)
```
  and, in the second example, replace
```ruby
        run(status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503", started_at: 2.minutes.ago)
        queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)
```
with
```ruby
        job = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)
        run(status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503", started_at: 2.minutes.ago, job_id: job.active_job_id)
```

  (b) Add, before the file's last `end` (inside the outermost `RSpec.describe`, after the last `context`'s closing `end`, before the file's final `end`):

```ruby

  # Spec 055: "Retry now" runs the failed run's own job when it waits to retry.
  context "when the failed run's own job waits to retry (spec 055)" do
    def waiting_job(wait: 10.minutes) = queue_job(Catalog::RefreshJob, "mtg", "manual", wait:)

    def failed_run(job_id) = run(status: "failed", stage: "download", job_id:, message: "Catalog::Sources::RateLimitedError: asked for 600 seconds")

    it "offers it, and runs that job at once without queueing another or writing a run (AC-1.1, AC-2.1, AC-2.8)", :aggregate_failures do
      job = waiting_job
      failed_run(job.active_job_id)

      expect(operation).to be_retry_now
      expect { expect(operation.retry_now).to be(true) }.not_to change { [ SolidQueue::Job.count, Catalog::RefreshRun.count ] }
      expect(job.reload).to be_ready
    end

    it "offers it for any retry of that job, not only a rate limit's (decision 1, ruled 2026-11-09)" do
      job = waiting_job
      run(status: "failed", stage: "download", job_id: job.active_job_id, message: "Catalog::Sources::TransientError: 503")

      expect(operation).to be_retry_now
    end

    {
      "a job queued fresh and ready" => -> { queue_job(Catalog::RefreshJob, "mtg", "manual") },
      "a job scheduled by hand with no failed run of its own" => -> { waiting_job },
      "a failed run whose job is in the Failed list" => -> { failed_run(fail_job(queue_job(Catalog::RefreshJob, "mtg", "manual")).active_job_id) },
      "a failed run whose job id is no longer in the queue" => -> { waiting_job.tap { failed_run("gone") } },
      "a failed run with no job id" => -> { waiting_job.tap { failed_run(nil) } },
      "a run in progress" => -> { running(job_id: claim_job(queue_job(Catalog::RefreshJob, "mtg", "manual")).active_job_id) },
      "an applied run" => -> { run(status: "applied") },
      "a skipped run" => -> { run(status: "skipped", message: "already running") },
      "no run at all" => -> { nil }
    }.each do |name, setup|
      it "doesn't offer it for #{name} (AC-1.3)", :aggregate_failures do
        instance_exec(&setup)

        expect(operation).not_to be_retry_now
        expect(operation.retry_now).to be(false)
      end
    end

    it "shows a failed run beside only a hand-scheduled job as plain queued, with that job's time and none of the run's stages (AC-1.6)", :aggregate_failures do
      freeze_time do
        failed_run("another-job")
        waiting_job(wait: 4.minutes)

        expect(operation).to have_attributes(state: :queued, summary: "Queued.", stages: [])
        expect(operation.facts.map { |fact| [ fact.label, fact.value ] }).to eq([ [ "Retrying at", 4.minutes.from_now ] ])
        expect(operation).not_to be_retry_now
      end
    end

    it "shows the run's own job's time and moves only that job when another is scheduled sooner (AC-1.4, AC-1.7, AC-2.6)", :aggregate_failures do
      freeze_time do
        hand = waiting_job(wait: 1.minute)
        own = waiting_job(wait: 5.minutes)
        failed_run(own.active_job_id)

        expect(operation.summary).to start_with("Queued to retry.")
        expect(operation.facts.first).to have_attributes(label: "Retrying at", value: 5.minutes.from_now)
        expect(operation.retry_now).to be(true)
        expect(own.reload).to be_ready
        expect(hand.reload).to be_scheduled
      end
    end

    it "does nothing, and says so, when the job was moved after the operation read the queue (AC-3.5)", :aggregate_failures do
      job = waiting_job
      failed_run(job.active_job_id)
      expect(operation).to be_retry_now # the page was rendered with the button

      SolidQueue::ScheduledExecution.where(job_id: job.id).delete_all # another admin, or the dispatcher, was first
      job.reload.dispatch_bypassing_concurrency_limits

      expect(operation.retry_now).to be(false)
      expect(SolidQueue::ReadyExecution.where(job_id: job.id).count).to eq(1)
      expect(SolidQueue::BlockedExecution.where(job_id: job.id)).to be_none
    end

    it "does nothing for an operation whose latest run has no job to move" do
      expect(Catalog::Operation.new("mtg")).not_to be_retry_now
    end
  end
```

  Note the last example constructs the abstract base: `Catalog::Operation#key` isn't defined on it, which `retry_now?` never calls, so it needs no subclass; if rubocop or the spec shows otherwise, use a `Class.new(Catalog::Operation)` in its place.

- [ ] **Task 2.2: write the failing art examples.** In `spec/models/mtg/art/operation_spec.rb`, inside the existing `context "when a rate-limited build's job waits to run again"` (it runs the real job, so its retry row is the scheduled one), add after the example "still says it is queued to retry after another build was skipped for it":

```ruby

      it "offers Retry now, and runs the waiting job at once without queueing another (spec 055 AC-1.2, AC-2.2)", :aggregate_failures do
        expect(operation).to be_retry_now
        expect { expect(operation.retry_now).to be(true) }.not_to change(SolidQueue::Job, :count)
        expect(SolidQueue::Job.sole).to be_ready
        expect(described_class.new("mtg")).to have_attributes(state: :queued, summary: "Queued.", retry_now?: false) # a fresh read: `operation` memoized its queue
      end

      it "offers it for the busy-database retry too (spec 055 AC-1.5)", :aggregate_failures do
        MTG::ArtBuild.sole.update!(message: "SQLite3::BusyException: database is locked")

        expect(operation).to be_retry_now
      end
```

  and, after that `context`'s closing `end` (still inside `context "with art matching on"`), add:

```ruby

    {
      "a build job queued fresh" => -> { queue_job(MTG::Art::BuildJob) },
      "a build job scheduled by hand with no failed build of its own" => -> { queue_job(MTG::Art::BuildJob, wait: 5.minutes) },
      "a failed build whose job is in the Failed list" => -> { build(status: "failed", job_id: fail_job(queue_job(MTG::Art::BuildJob)).active_job_id) },
      "a failed build whose job id is no longer in the queue" => -> { build(status: "failed", job_id: "gone") },
      "a failed build with no job id" => -> { build(status: "failed", job_id: nil) },
      "a build in progress" => -> { build(status: "running", finished_at: nil, heartbeat_at: Time.current, job_id: claim_job(queue_job(MTG::Art::BuildJob)).active_job_id) },
      "a finished build" => -> { build(status: "finished") },
      "a skipped build" => -> { build(status: "skipped", message: "already running") },
      "no build at all" => -> { nil }
    }.each do |name, setup|
      it "doesn't offer Retry now for #{name} (spec 055 AC-1.3a)", :aggregate_failures do
        loaded
        instance_exec(&setup)

        expect(operation).not_to be_retry_now
        expect(operation.retry_now).to be(false)
      end
    end
```

  and, in `context "with art matching off"`, add:

```ruby

    it "offers no Retry now, whatever waits (spec 055 AC-1.3a)" do
      loaded
      build(status: "failed", job_id: queue_job(MTG::Art::BuildJob, wait: 5.minutes).active_job_id)

      expect(operation).not_to be_retry_now
    end
```

- [ ] **Task 2.3: fix the request examples that the tightening changes (they stay red until Task 2.5).** In `spec/requests/admin/catalogs_spec.rb`, the example "shows a failed run whose job waits to retry as queued, without the failed link (AC-3.7)" (line ~312) creates the run before its job. Replace

```ruby
        create(:catalog_refresh_run, status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503")
        travel_to(Time.utc(2026, 10, 9, 3, 15)) do
          queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)
          get admin_catalog_path
        end
```
with
```ruby
        travel_to(Time.utc(2026, 10, 9, 3, 15)) do
          job = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 3.minutes)
          create(:catalog_refresh_run, status: "failed", stage: "download", message: "Catalog::Sources::TransientError: 503", job_id: job.active_job_id)
          get admin_catalog_path
        end
```
  This edit keeps the example green before and after the implementation (a run with its own job id is "queued to retry" today too). The art example at line ~476 ("shows a failed build whose job waits to retry as queued, with the reason and the time (AC-4.12)") compares the whole section's text, button text included; once the button exists (Task 3.4) its expected string gains "Retry now" after "Build art index". Edit it in Task 3.4, not here.

- [ ] **Task 2.4: run them, expect FAIL.** `bin/rspec spec/models/catalog/refresh_operation_spec.rb spec/models/mtg/art/operation_spec.rb` — expect: the new examples fail with `NoMethodError` for `retry_now?`/`retry_now`; the two edited existing refresh examples still pass (a run with its own job id is "queued to retry" today as well).
- [ ] **Task 2.5: implement.** 

  In `app/models/catalog/operation.rb`: extend the header comment's "may provide" line to
```ruby
# and may provide queue_argument, stages, meter, facts, unavailable_reason and retry_candidate.
```
  and add, after `def startable? = unavailable_reason.nil? && !in_flight?`:

```ruby

  # The run or build record of its latest attempt, which a retry belongs to: it answers #failed?, #job_id and #message.
  # Nil for an operation that has none; such an operation never offers Retry now (spec 055 FR-1).
  def retry_candidate = nil

  # Whether a failed attempt's waiting retry may be run now. The one place the offer is narrowed: spec 055 decision 1
  # offers it for any retry of the failed attempt's own job (ruled by the maintainer, 2026-11-09).
  def retryable?(_record) = true

  # The Active Job id of the latest failed attempt's own job when the queue holds it for a later time: what Retry now
  # would run, and what the page shows "Retrying at" for. Nil otherwise: not a failed attempt, no job id, its job in the
  # Failed list or gone, only some other job waiting, or the operation unavailable (a setting that is off: spec 055
  # decision 1, Error Scenarios).
  def retry_job_id
    record = retry_candidate
    return unless record&.failed? && record.job_id.present? && retryable?(record) && unavailable_reason.nil?

    record.job_id if queue.retry_at(record.job_id)
  end

  def retry_now? = retry_job_id.present?

  # Runs the waiting job now, through the queue's own dispatch (spec 055 decision 2). True when this call moved it;
  # false, changing nothing, when nothing waits for it any more. The offer is read again here, not trusted from the
  # page, and the move itself decides atomically (Catalog::Operation::Queue#run_now).
  def retry_now = retry_job_id.present? && queue.run_now(retry_job_id)
```

  In `app/models/catalog/refresh_operation.rb`: add after `def record_running? = %i[building stalled]`… i.e. after `def record_running? = %i[running stalled].include?(state)`:

```ruby

  def retry_candidate = run
```
  change `facts`' first line from
```ruby
    retry_fact = [ (fact("Retrying at", queue.retry_at) if state == :queued && queue.retry_at) ].compact
```
  to
```ruby
    retry_fact = [ (fact("Retrying at", queue.retry_at(retrying? ? run.job_id : nil)) if state == :queued && queue.retry_at) ].compact
```
  and the private `retrying?` from
```ruby
    # A failed run whose job waits to run again (spec 015 AC-3.7).
    def retrying? = state == :queued && queue.retry_at.present? && run&.failed?
```
  to
```ruby
    # A failed run whose own job waits to run again (spec 015 AC-3.7, as spec 055 decision 1 words it: the run's own job,
    # as an extension's build already is, so a job held by hand beside a failed run is plain "Queued.").
    def retrying? = state == :queued && retry_job_id.present?
```

  In `app/models/mtg/art/operation.rb`: add `def retry_candidate = build` next to `def record_running?` (public section), and replace the private `retrying?` body

```ruby
    def retrying?
      state == :queued && build&.failed? && build.job_id.present? && queue.retry_at(build.job_id).present?
    end
```
  with
```ruby
    def retrying? = state == :queued && retry_job_id.present?
```
  (the comment above it stays).

- [ ] **Task 2.6: run them, expect PASS.** `bin/rspec spec/models/catalog/refresh_operation_spec.rb spec/models/mtg/art/operation_spec.rb spec/models/catalog/operation spec/requests/admin/catalogs_spec.rb spec/models/catalog/health_spec.rb spec/admin_catalog_core_spec.rb` — expect: all pass, including AC-1.6's and AC-1.7's new refresh examples and the three edited existing ones. If the `Catalog::Operation.new("mtg")` example raises, apply the note under Task 2.1.
- [ ] **Task 2.7: commit.** `feat(admin): offer and perform Retry now on an operation, tie the refresh's retry state to its own job (spec 055 FR-1, #77)`.

> **Complexity note.** None: one hook (`retryable?`) and four small methods on the base class, no new class. The refresh's tightening is a behaviour change to an existing panel, recorded in the spec's Supersedes (spec 015 AC-3.7) and in Task 5.4's area doc edits.

---

## Phase 3: The route, the controller and the button

**Implements:** FR-3, FR-4 | **Satisfies:** AC-1.1, AC-1.2 (page level), AC-2.1, AC-2.2, AC-2.3, AC-2.8 (page level), AC-3.1, AC-3.3 (page level), AC-4.1–AC-4.5, AC-5.3
**Files:** `config/routes.rb`, `app/controllers/admin/catalogs/operation_retries_controller.rb`, `app/views/admin/catalogs/_operation.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/requests/admin/catalogs/operation_retries_spec.rb`, `spec/requests/admin/catalogs_spec.rb`, `spec/admin_catalog_core_spec.rb`
**Interfaces:** Consumes: `Catalog::Health.find(type).operation(key)`, `Catalog::Operation#retry_now?`, `#retry_now` (Phase 2). Produces: `POST /admin/catalog/operation_retries` (`admin_catalog_operation_retries_path`, params `collectible_type`, `operation`) answering `303` to `admin_catalog_path` with flash notice "Retrying now." or "Nothing is waiting to retry."; the "Retry now" button in the operation head.

- [ ] **Task 3.1: write the failing request examples.** Create `spec/requests/admin/catalogs/operation_retries_spec.rb`:

```ruby
require "rails_helper"

# Spec 055 Stories 1-4 over HTTP: "Retry now" on /admin/catalog runs the job that waits to retry, once, for an admin only.
# No worker runs in tests: a job's records show where it stands.
RSpec.describe "Retrying a waiting refresh or art build now", :solid_queue, type: :request do
  let(:admin) { create(:admin) }

  def page = Nokogiri::HTML5(response.body)

  def section(key) = page.at_css("#mtg_#{key}")

  def retry_now(operation, collectible_type: "mtg", **extra) = post admin_catalog_operation_retries_path, params: { collectible_type:, operation:, **extra }

  # A refresh whose attempt a rate limit ended: its run failed and its own job waits.
  def waiting_refresh(wait: 10.minutes)
    queue_job(Catalog::RefreshJob, "mtg", "manual", wait:).tap do |job|
      create(:catalog_refresh_run, status: "failed", stage: "download", job_id: job.active_job_id,
        message: "Catalog::Sources::RateLimitedError: asked for 600 seconds")
    end
  end

  def waiting_build(wait: 10.minutes)
    create(:catalog_refresh_run)
    queue_job(MTG::Art::BuildJob, wait:).tap do |job|
      create(:mtg_art_build, status: "failed", job_id: job.active_job_id, finished_at: Time.current,
        message: "Catalog::Sources::RateLimitedError: asked for 600 seconds")
    end
  end

  context "when signed in as an admin" do
    before { sign_in_as(admin) }

    it "shows an enabled Retry now beside the disabled start button of a waiting refresh (AC-1.1)", :aggregate_failures do
      waiting_refresh

      get admin_catalog_path

      form = section("refresh").at_css("form[action='#{admin_catalog_operation_retries_path}']")
      expect(form.at_css("button").text).to eq("Retry now")
      expect(form.at_css("button")["disabled"]).to be_nil
      expect(form.at_css("button")["class"]).to eq("c-btn c-btn--secondary")
      expect(form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] })
        .to include("collectible_type" => "mtg", "operation" => "refresh")
      expect(section("refresh").at_css("form[action='#{admin_catalog_operation_starts_path}'] button")["disabled"]).to be_present
    end

    it "shows it on a waiting art index build too (AC-1.2)", :art_matching, :aggregate_failures do
      waiting_build

      get admin_catalog_path

      expect(section("art_index").at_css("form[action='#{admin_catalog_operation_retries_path}'] button").text).to eq("Retry now")
      expect(section("art_index").at_css("form[action='#{admin_catalog_operation_starts_path}'] button")["disabled"]).to be_present
    end

    it "shows none when nothing waits to retry (AC-1.3)" do
      create(:catalog_refresh_run)

      get admin_catalog_path

      expect(page.css("form[action='#{admin_catalog_operation_retries_path}']")).to be_empty
    end

    it "runs the waiting refresh job at once, without queueing another or writing a run (AC-2.1, AC-2.8)", :aggregate_failures do
      job = waiting_refresh

      expect { retry_now("refresh") }.not_to change { [ SolidQueue::Job.count, Catalog::RefreshRun.count ] }

      expect(response).to redirect_to(admin_catalog_path)
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Retrying now.")
      expect(job.reload).to be_ready
      expect(job.scheduled_execution).to be_nil
    end

    it "runs the waiting art build job at once (AC-2.2)", :art_matching, :aggregate_failures do
      job = waiting_build

      expect { retry_now("art_index") }.not_to change(SolidQueue::Job, :count)

      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Retrying now.")
      expect(job.reload).to be_ready
    end

    it "then reads Queued., with no Retry now, the start button disabled, and the page polling (AC-2.3, AC-5.3)", :aggregate_failures do
      waiting_refresh
      retry_now("refresh")

      follow_redirect!

      expect(section("refresh").at_css(".c-operation__summary").text.squish).to eq("Queued.")
      expect(section("refresh").at_css("form[action='#{admin_catalog_operation_retries_path}']")).to be_nil
      expect(section("refresh").at_css("button")["disabled"]).to be_present
      expect(section("refresh").at_css(".c-details")).to be_nil
      expect(page.at_css("main")["data-controller"]).to eq("poll")
    end

    it "says nothing is waiting, and changes nothing, on a second press (AC-3.1)", :aggregate_failures do
      job = waiting_refresh
      retry_now("refresh")

      expect { retry_now("refresh") }.not_to change { [ SolidQueue::Job.count, SolidQueue::ReadyExecution.count, SolidQueue::BlockedExecution.count ] }

      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Nothing is waiting to retry.")
      expect(job.reload.ready_execution).to be_present
    end

    it "says nothing is waiting when the job has been claimed since the page was shown (AC-3.3)", :aggregate_failures do
      job = waiting_refresh
      claim_job(job)

      retry_now("refresh")

      expect(flash[:notice]).to eq("Nothing is waiting to retry.")
      expect(job.reload).to be_claimed
    end

    it "offers no button and moves nothing for an art build while art matching is off (spec 055 Error Scenarios)", :aggregate_failures do
      job = waiting_build # the example runs with art matching off: no :art_matching tag

      get admin_catalog_path
      expect(page.css("form[action='#{admin_catalog_operation_retries_path}']")).to be_empty

      retry_now("art_index")
      expect(flash[:notice]).to eq("Nothing is waiting to retry.")
      expect(job.reload).to be_scheduled
    end

    it "says nothing is waiting when no run is waiting at all" do
      retry_now("refresh")

      expect(flash[:notice]).to eq("Nothing is waiting to retry.")
    end

    it "moves only the operation's own run's job, whatever else the request carries (AC-4.4)", :aggregate_failures do
      other = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 1.minute)
      own = waiting_refresh

      retry_now("refresh", job_id: other.id, id: other.active_job_id)

      expect(own.reload).to be_ready
      expect(other.reload).to be_scheduled
    end

    it "answers 404 for an unknown type or operation, changing nothing (AC-4.3)", :aggregate_failures do
      job = waiting_refresh

      retry_now("refresh", collectible_type: "pokemon")
      expect(response).to have_http_status(:not_found)
      retry_now("art_index_rebuild")
      expect(response).to have_http_status(:not_found)
      retry_now("constantize")
      expect(response).to have_http_status(:not_found)
      expect(job.reload).to be_scheduled
    end
  end

  it "is invisible to a member: 404, and the waiting job is unchanged (AC-4.1)", :aggregate_failures do
    job = waiting_refresh
    sign_in_as(create(:user))

    retry_now("refresh")

    expect(response).to have_http_status(:not_found)
    expect(job.reload).to be_scheduled
  end

  it "sends a visitor who isn't signed in to sign in, changing nothing (AC-4.2)", :aggregate_failures do
    job = waiting_refresh
    admin

    retry_now("refresh")

    expect(response).to redirect_to(new_session_path)
    expect(job.reload).to be_scheduled
  end
end
```

- [ ] **Task 3.2: run it, expect FAIL.** `bin/rspec spec/requests/admin/catalogs/operation_retries_spec.rb` — expect: every example fails with a `NameError` for `admin_catalog_operation_retries_path` (the route doesn't exist).
- [ ] **Task 3.3: route and controller.** In `config/routes.rb`, change

```ruby
    resource :catalog, only: :show do
      resources :operation_starts, only: :create, module: :catalogs
    end
```
to
```ruby
    resource :catalog, only: :show do
      resources :operation_starts, only: :create, module: :catalogs
      resources :operation_retries, only: :create, module: :catalogs
    end
```
  Create `app/controllers/admin/catalogs/operation_retries_controller.rb`:

```ruby
# Runs the job of one of a catalog type's operations that waits to retry, at once (spec 055). The type and the operation
# are looked up among what is registered, so an unknown one is a 404 and nothing from the request is ever called by name;
# the job comes from the operation's own latest failed run, never from the request (decision 4). Nothing is queued or run
# in the request: the waiting job's scheduled entry becomes ready, and a worker runs it.
class Admin::Catalogs::OperationRetriesController < ApplicationController
  include AdminOnly

  def create
    operation = Catalog::Health.find(params[:collectible_type]).operation(params[:operation])
    raise ActiveRecord::RecordNotFound unless operation

    notice = operation.retry_now ? "Retrying now." : "Nothing is waiting to retry."
    redirect_to admin_catalog_path, notice:, status: :see_other
  end
end
```

- [ ] **Task 3.4: the button.** Invoke the `collector-design-system` skill and read `docs/design-system/README.md` and `docs/design-system/components/AdminCatalog.md` and `Button.md` first (CLAUDE.md, UI section). The head is `display:flex; flex-wrap:wrap; justify-content:space-between`, so a third direct child (a second form) would sit mid-row. Both buttons therefore go into one wrapper that carries the existing `c-operation__start` class (no new class), and the rule gains a gap.

  In `app/views/admin/catalogs/_operation.html.erb`, replace the whole `<% if operation.start_label %> … <% end %>` block inside `.c-operation__head` with:

```erb
    <% if operation.start_label || operation.retry_now? %>
      <div class="c-operation__start">
        <% if operation.start_label %>
          <%# The refresh is the page's primary action while the catalog isn't loaded (AC-1.4). %>
          <%= button_to operation.start_label, admin_catalog_operation_starts_path,
                params: { collectible_type: catalog.collectible_type, operation: operation.key }, disabled: !operation.startable?,
                class: class_names("c-btn", !catalog.loaded? && operation == catalog.refresh ? "c-btn--primary" : "c-btn--secondary") %>
        <% end %>
        <% if operation.retry_now? %>
          <%# While its failed run's own job waits to retry, the job can be run now (spec 055). %>
          <%= button_to "Retry now", admin_catalog_operation_retries_path,
                params: { collectible_type: catalog.collectible_type, operation: operation.key }, class: "c-btn c-btn--secondary" %>
        <% end %>
      </div>
    <% end %>
```
  In `app/assets/stylesheets/collector/additions.css`, change the line `.c-operation__start { display:flex; }` to:

```css
.c-operation__start { display:flex; flex-wrap:wrap; gap:var(--space-2); } /* the start button, and Retry now beside it while a retry waits (spec 055) */
.c-operation__start form { display:flex; } /* as the start form itself was before the wrapper: a button in a block form would sit on a line box's baseline */
```
  In `spec/requests/admin/catalogs_spec.rb`, the art example "shows a failed build whose job waits to retry as queued, with the reason and the time (AC-4.12)" compares the section's whole text, button text included: change the start of its expected string from `"Art index Build art index Queued to retry. The last build failed. "` to `"Art index Build art index Retry now Queued to retry. The last build failed. "`. Every other example reads `at_css("button")`, which is still the start button (it comes first), or `.c-operation__summary`, so none else needs an edit; this task's run proves it. The wrapper's form keeps the `display:flex` the start form had, so a panel with one button looks as it did (Task 5.2 compares one with `main`'s look). The only users of the class are this view, `additions.css` and `AdminCatalog.md` (checked with `grep -rln "c-operation__start" app docs spec`).
- [ ] **Task 3.5: the core guard.** In `spec/admin_catalog_core_spec.rb`, the example "covers the controllers, views, models, helper and script of the page" counts the files the glob finds (`app/controllers/admin/catalogs{_controller.rb,/**/*.rb}` now also finds the new controller). Change `expect(files.size).to eq(15)` to `expect(files.size).to eq(16)`.
- [ ] **Task 3.6: run, expect PASS.** `bin/rspec spec/requests/admin/catalogs/operation_retries_spec.rb spec/requests/admin/catalogs_spec.rb spec/admin_catalog_core_spec.rb spec/requests/admin/jobs_spec.rb` — expect: all pass. (AC-4.5, forgery protection, is the framework default; it is verified by reading `ApplicationController` in Task 5.5.)
- [ ] **Task 3.7: commit.** `feat(admin): Retry now on /admin/catalog for a job waiting to retry (spec 055 FR-3, FR-4, #77)`.

---

## Phase 4: The lifecycle is kept, and the button in a browser

**Implements:** FR-1 (lifecycle), FR-5 | **Satisfies:** AC-2.4, AC-2.5, AC-5.1, AC-5.2
**Files:** `spec/jobs/catalog/refresh_job_spec.rb`, `spec/jobs/mtg/art/build_job_spec.rb`, `spec/system/admin_catalog_spec.rb`, `spec/system/narrow_admin_pages_spec.rb`
**Interfaces:** Consumes: Phases 1–3. Produces: nothing new (these examples pin behaviour the earlier phases make true; no production code changes here).

These examples pass as soon as they are written, because they test behaviour the move already keeps (the row, its Active Job id and its retry record are never touched): they pin it. They would fail if a later change made the move queue a new job or reset the retry record, which is what they are for. TDD's "no code without a failing test" has no production code to bind here.

- [ ] **Task 4.1: the job keeps its retry count and its run lifecycle.** The worker runs a claimed row with `ActiveJob::Base.execute(row.arguments)` (`spec/jobs/mtg/art/build_job_spec.rb` already does the same with the test adapter's queued jobs), so the examples run the moved row that way, with the Solid Queue adapter.

  In `spec/jobs/catalog/refresh_job_spec.rb`, add before the file's last `end`:

```ruby

  # Spec 055 AC-2.4, AC-2.5: Retry now moves the waiting row; the job that runs is that row, with its retry record.
  context "when Retry now has moved its waiting retry (spec 055)", :solid_queue do
    def scheduled_row(active_job_id) = SolidQueue::Job.where(active_job_id:, finished_at: nil).find(&:scheduled?)

    it "carries on counting from the job's retry record, and opens a run under the same job id as any retry does", :aggregate_failures do
      stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(status: 429, headers: { "Retry-After" => "600" })
      described_class.perform_now("mtg", "manual")
      waiting = scheduled_row(Catalog::RefreshRun.sole.job_id)
      counted = Catalog::RateLimitRetry::COUNTED_AS
      expect(waiting.arguments["exception_executions"]).to eq(counted => 1)

      expect(Catalog::RefreshOperation.new("mtg").retry_now).to be(true)
      expect(waiting.reload).to be_ready
      expect(waiting.arguments["exception_executions"]).to eq(counted => 1) # the press left the retry record alone

      ActiveJob::Base.execute(waiting.arguments) # a worker runs the row; the source still turns it away, with no progress
      expect(scheduled_row(waiting.active_job_id).arguments["exception_executions"]).to eq(counted => 2) # 2, not 1 again
      expect(Catalog::RefreshRun.where(job_id: waiting.active_job_id).pluck(:status)).to eq(%w[failed failed])
    end
  end
```

  In `spec/jobs/mtg/art/build_job_spec.rb`, add before the file's last `end` (the build's own start guard under the same job id is already pinned by `spec/models/mtg/art/operation_spec.rb`, "opens a new run when the retry starts, leaving the failed one as it ended"):

```ruby

  context "when Retry now has moved its waiting retry (spec 055 AC-2.4)", :solid_queue do
    it "carries on counting from the job's retry record", :aggregate_failures do
      allow(MTG::Art::Build).to receive(:new).and_raise(Catalog::Sources::RateLimitedError.new("rate limited", retry_after: 600))
      described_class.perform_now
      waiting = SolidQueue::Job.sole
      counted = Catalog::RateLimitRetry::COUNTED_AS
      expect(waiting.arguments["exception_executions"]).to eq(counted => 1)

      expect(Catalog::Operation::Queue.new(described_class).run_now(waiting.active_job_id)).to be(true)
      expect(waiting.reload).to be_ready
      expect(waiting.arguments["exception_executions"]).to eq(counted => 1)

      ActiveJob::Base.execute(waiting.arguments)
      retry_row = SolidQueue::Job.where(active_job_id: waiting.active_job_id).find(&:scheduled?)
      expect(retry_row.arguments["exception_executions"]).to eq(counted => 2)
    end
  end
```
  Run: `bin/rspec spec/jobs/catalog/refresh_job_spec.rb spec/jobs/mtg/art/build_job_spec.rb` — expect: pass. If an example is red, do not bend it to fit: invoke `sdd-superpowers:systematic-debugging` and read `SolidQueue::ClaimedExecution#execute` in the gem (it calls `ActiveJob::Base.execute(job.arguments)`, which these examples copy) to find which side is wrong.
- [ ] **Task 4.2: the system example.** In `spec/system/admin_catalog_spec.rb`, add before the file's last `end`:

```ruby

  it "runs a refresh that waits to retry at once, and the button goes (spec 055 AC-5.1)", :aggregate_failures do
    job = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 20.minutes)
    create(:catalog_refresh_run, status: "failed", stage: "download", job_id: job.active_job_id,
      message: "Catalog::Sources::RateLimitedError: asked for 1200 seconds")
    system_sign_in_as(admin)
    visit admin_catalog_path
    expect(page).to have_css("#mtg_refresh .c-operation__summary", text: "Queued to retry.")
    expect(page).to have_button("Refresh now", disabled: true)

    click_button "Retry now"

    expect(page).to have_css("#status", text: "Retrying now.")
    expect(page).to have_css("#mtg_refresh .c-operation__summary", exact_text: "Queued.")
    expect(page).to have_no_button("Retry now")
    expect(page).to have_button("Refresh now", disabled: true)
    expect(job.reload).to be_ready
  end
```
  Run `bin/rspec spec/system/admin_catalog_spec.rb` — expect: pass (headless Firefox).
- [ ] **Task 4.3: the phone width.** In `spec/system/narrow_admin_pages_spec.rb`, add before the file's last `end`:

```ruby

  it "keeps Retry now beside the start button, reachable and fitting, at 360px and 375px (spec 055 AC-5.2)", :aggregate_failures do
    job = queue_job(Catalog::RefreshJob, "mtg", "manual", wait: 20.minutes)
    create(:catalog_refresh_run, status: "failed", stage: "download", job_id: job.active_job_id, message: long_error)
    system_sign_in_as(create(:admin))

    [ 360, 375 ].each do |width|
      expect(open_in_narrow_frame(admin_catalog_path, width:, ready: "main")).to eq([ width, true ]), "scrolls sideways at #{width}px"
      within_narrow_frame do
        expect(page).to have_button("Retry now")
        expect(page).to have_button("Refresh now", disabled: true)
      end
    end
  end
```
  Run `bin/rspec spec/system/narrow_admin_pages_spec.rb` — expect: pass.
- [ ] **Task 4.4: commit.** `test(admin): pin Retry now's lifecycle and its button in a browser (spec 055 AC-2.4, AC-2.5, AC-5.1, AC-5.2, #77)`.

---

## Phase 5: The look, the documents, the review and CI

**Implements:** All FRs | **Satisfies:** AC-5.2 (the screenshots), AC-6.1–AC-6.4, AC-4.5 (by reading), all ACs at the end
**Files:** `docs/architecture/catalog-operations.md`, `docs/design-system/components/AdminCatalog.md`, `docs/roadmap.md`, `docs/architecture/catalog-core.md`, `CLAUDE.md`, `docs/specs/README.md`, `docs/specs/055-rate-limit-retry-now/verification.md`, and the screenshot files under `docs/specs/055-rate-limit-retry-now/screenshots/`
**Interfaces:** Consumes: Phases 1–4. Produces: the area doc's current rules, the verification record, the PR's screenshots.

- [ ] **Task 5.1: the screenshots.** Following the "Screenshots from a throwaway system spec" paragraph of `.claude/memory/pr-screenshots-workflow.md` and `.claude/memory/headless-firefox-narrow-frame.md` (no dev server, no seed script, nothing that runs a real job): write an uncommitted `spec/system/zz_055_screenshots_spec.rb` (`:solid_queue`, `:art_matching`, `type: :system`) that builds, with factories and `queue_job(..., wait: 20.minutes)`, an applied refresh run, a failed refresh run whose own job waits, and a failed art build whose own job waits (the data of Task 4.2), signs in an admin, and saves with `page.save_screenshot(File.join(ENV.fetch("SHOTS_DIR"), name))`: `/admin/catalog` in the waiting state at 1280px, and at 390px through `open_in_narrow_frame` and `find("#narrow").native.save_screenshot`, each in light and dark (set `data-theme` in the page and inside the frame, pause 0.6s after each switch), one with the focus on "Retry now" (`find_button("Retry now").send_keys(:tab)` from the start button, or `execute_script("document.querySelector('form[action$=operation_retries] button').focus()")`), and one of the page after pressing "Retry now" (summary "Queued.", no button). The "before" shots are the same states with `document.head.append` of a `<style>.c-operation__start form[action$="operation_retries"]{display:none}</style>` (the memory file's "before" method; note in `verification.md` that "before" is the page without the button, since nothing of the old code can be loaded). Run with `SHOTS_DIR=<scratchpad> bin/rspec spec/system/zz_055_screenshots_spec.rb`; look at one shot of each theme and width before trusting the rest; compress with `magick … -resize 1000x -quality 82`; copy the chosen files to `docs/specs/055-rate-limit-retry-now/screenshots/`; delete the spec before committing. Say "factory data, placeholder printings" in the PR body.
- [ ] **Task 5.2: look at the shots.** The buttons share one wrapper that wraps as a unit; confirm at 1280px and 390px that "Retry now" sits beside "Refresh now" (or under it on the narrow frame), that the title is not squeezed, and that the focus ring is visible on "Retry now" (the focused shot of Task 5.1). Also compare a panel with one button (the art index when nothing waits, or the refresh with no retry) with how `main` renders it (the old markup is in this plan's Task 3.4): same height and alignment. A defect found here is fixed in the view or the one rule of Task 3.4 and re-run with `bin/rspec spec/requests/admin spec/system/admin_catalog_spec.rb spec/system/narrow_admin_pages_spec.rb`, committed as `fix(admin): …`.
- [ ] **Task 5.3: the design system document.** In `docs/design-system/components/AdminCatalog.md`: (1) the markup sample's start form becomes `<div class="c-operation__start"><form method="post" action="/admin/catalog/operation_starts">…<button class="c-btn c-btn--secondary" disabled>Refresh now</button></form></div>`; (2) replace the bullet that begins "Each operation has at most one button, named for what it starts" with:

```markdown
- Each operation has one start button, named for what it starts ("Refresh now", "Build art index"). It is `c-btn--secondary`, and disabled while the operation is queued or running or can't run yet; the summary says why. "Refresh now" is `c-btn--primary` only while the catalog has no cards, when it is the page's one next step. While a failed run's own job waits to retry ("Queued to retry."), the operation also shows "Retry now", `c-btn--secondary` and enabled, beside the start button in the same `c-operation__start` wrapper (a flex row that wraps, `space-2` apart, its forms flex too), which runs that waiting job at once (spec 055); the start button stays disabled. An operation that is switched off shows no button, and its summary says how to switch it on.
```
  Then check with `grep -ln "Queued to retry\|c-operation__start" docs/design-system/previews/*.html`; if a preview shows either, change it to the same markup.
- [ ] **Task 5.4: the other documents (AC-6.1–AC-6.3).** The implementer writes every edit here, including the area doc's; `distill-feature` at session end (Task 5.8) finds them done, checks them, adds the distillation-log row ("spec 055's pull request", as spec 043's row does, since the pull request doesn't exist yet) and moves the index's status words. Read each document and make exactly these edits, each new statement with its source inline (spec 055 criterion or decision, or #77):
  - `docs/architecture/catalog-operations.md`: (1) in "A rate-limited job", step 3, add after the panel sentence: "An admin can run the waiting job at once with **Retry now**: it moves the failed run's own job's scheduled entry to ready (`Catalog::Operation::Queue#run_now`), queues no job and changes neither the job's Active Job id nor its retry record, so the count carries on as for any retry; the move is atomic with one winner (the entry is removed first and the dispatch happens only when that removal happened), so a second press, a press as the wait ends or the queue's own dispatch changes nothing and the press says 'Nothing is waiting to retry.'; it is offered for any retry of that job, not only a rate limit's (spec 055 decisions 1–5, FR-2; maintainer ruling 2026-11-09; #77)." (2) In the refresh panel table, the row "Failed, a refresh job scheduled to run again" now reads "…the failed run's own job scheduled to run again…; 'Refresh now' disabled, 'Retry now' enabled (spec 055 decision 1; spec 015 AC-3.7 in part)" and a new row follows it: "Failed run, only another refresh job scheduled (held by hand) | 'Queued.' with that job's 'Retrying at', none of the failed run's stages or facts, no 'Retry now' (spec 055 AC-1.6)". (3) In the art table, the row "Failed build whose own job is scheduled to run again" gains "'Retry now' enabled (spec 055 AC-1.2)". (4) In Invariants, after the line "The jobs pages read Solid Queue's own tables…": "**The catalog page moves one scheduled job, through the queue's own operations.** 'Retry now' names only a type and an operation key, takes the job from the operation's own latest failed run, runs nothing in the request and writes no run record; it is admin only like the rest of the page (spec 055 decision 4, FR-1; ADR 0014)." (5) Glossary "Waiting retry": append "Retry now runs the failed run's own waiting job (spec 055)." (6) "Accepted limits and open issues": reword the #77 line to "[#77](https://github.com/plainprogrammer/Collector/issues/77): an admin can run a waiting retry now (spec 055) but still can't discard one from `/admin/jobs`, which discards only failed jobs (ruling 2026-11-09, out of scope)." (7) Scope's "Covers" admin-pages bullet: add `Admin::Catalogs::OperationRetriesController`. (8) Sources: add the line "- [Spec 055](../specs/055-rate-limit-retry-now/spec.md): all." and, in the Issues line, move #77 out of "open:" into the resolved list.
  - `CLAUDE.md`: in the "Admin catalog and jobs (specs 015, 024; ADRs 0014, 0015)" bullet, change the heading to "(specs 015, 024, 055; ADRs 0014, 0015)" and add "'Retry now' runs a waiting retry now" after "rate-limit retries"; keep the bullet's pointer-only shape (`.claude/rules/documentation.md`).
  - `docs/roadmap.md` line 82 (the #77 line): reword to "#77: an admin can run a waiting rate-limit retry now (spec 055); discarding one from `/admin/jobs` is out of scope".
  - `docs/architecture/catalog-core.md`: lines 205 and 217 list #77 as an open issue of the catalog operations area; reword line 205 to say #77 is catalog operations' and addressed by spec 055, and drop it from line 217's open list if it appears there as open.
  - `docs/specs/README.md`: the 055 row's Plan column "present" becomes "retirement owed" at distillation (Task 5.8); its status stays "Approved" until merge; the 015, 024 and 043 rows already carry "055".
- [ ] **Task 5.5: the verification record.** Create `docs/specs/055-rate-limit-retry-now/verification.md` with one line per AC (the spec file and example that proves it, or "by reading" with what was read), including: AC-4.5 (read `ApplicationController`: forgery protection is on by default and `button_to` posts the token); FR-2's transaction (read `Catalog::Operation::Queue#run_now`: `SolidQueue::Record.transaction`, the queue's connection; the test environment shares the primary database, so no example can tell); AC-2.4's "made progress, so the count starts again" half (the move leaves the retry record alone, and spec 043's example "starts the count again after an attempt that wrote rows" in `spec/jobs/catalog/refresh_job_spec.rb` proves the count's rule); AC-2.5's art half (the existing example "opens a new run when the retry starts" in `spec/models/mtg/art/operation_spec.rb`, which calls `MTG::ArtBuild.start!` under the job's id, plus Task 4.1's count example; a moved art job is not run end to end); AC-6.1–AC-6.3 (by reading); the screenshots' file names and that "before" is the page without the button; the Phase 1 complexity note; the accepted edge that `retrying?` goes through `unavailable_reason`, so a failed build whose job waits with no applied refresh (barely reachable) reads "Queued." and no button instead of "Queued to retry."; the example counts from `bin/rspec --dry-run` over each new or changed file.
- [ ] **Task 5.6: commit.** `docs(specs): spec 055's area docs, design system rule, screenshots and verification record (#77)` (screenshots in a commit of their own first if the hook's size limit requires it), so the reviewer's diff holds everything.
- [ ] **Task 5.7: the implementation review.** Dispatch the read-only `opus` `sdd-review` Mode B reviewer over the whole branch diff against `origin/main`; record it in `verification.md` under `## Implementation review` with the verdict on its first line and commit that (`docs(specs): implementation review of spec 055 (#77)`); fix what it finds blocking or major, test first, one commit each.
- [ ] **Task 5.8: session wrap and distillation.** Run `sdd-superpowers:session-wrap`, then `distill-feature`, show the coordinator the digest and wait for approval, commit its output.
- [ ] **Task 5.9: push and pull request.** Ask the coordinator for a CI slot covering the push (the pre-push hook runs `bin/ci` once; its pass is the evidence, cite the pushed SHA); `git push -u origin 055-rate-limit-retry-now`; `gh pr create --draft` with the summary, test counts, "factory data, placeholder printings", the before/after screenshots embedded as `https://github.com/plainprogrammer/Collector/blob/<sha>/<path>?raw=true`, `Closes #77`, and the footer `🤖 Generated with [Claude Code](https://claude.com/claude-code)`; wait for CI green; `gh pr ready <N>` and `gh pr edit <N> --add-assignee @me`; send "slot released" with the SHA and result; then `worker_done`.

---

## Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run `bin/rspec spec/models/catalog spec/models/mtg/art spec/requests/admin spec/jobs spec/system/admin_catalog_spec.rb spec/system/narrow_admin_pages_spec.rb spec/admin_catalog_core_spec.rb` — expect: all pass.
- [ ] The pre-push `bin/ci` and GitHub's CI (Task 5.9) — expect: green.
- [ ] Walk the spec's ACs against `verification.md`.

## Quickstart Validation

The throwaway spec of Task 5.1 is the walkthrough: with a failed refresh run whose own `Catalog::RefreshJob` is scheduled 20 minutes ahead, `/admin/catalog` reads "Queued to retry." with "Retrying at" and shows "Retry now" beside the disabled "Refresh now"; pressing it shows "Retrying now.", the section reads "Queued." and the button is gone; `SolidQueue::Job` still has the one row, now ready (Task 4.2's assertions).
