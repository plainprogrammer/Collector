# Implementation Plan: Rate-Limit Retries Count Only Without Progress

**Spec:** [spec.md](spec.md) (v1.0.0; approved 2026-11-06 by the coordinator under the maintainer's delegation, decision 1 ruled A by the maintainer)
**Decisions:** no ADR. Decision 1 is the maintainer's ruling; the rest are the spec's. ADR 0018 (collectible-agnostic core) governs where the code goes.
**Created:** 2026-11-06
**Issue:** [#86](https://github.com/plainprogrammer/Collector/issues/86)

**How this plan was made.** Read-only: every block was traced by hand against the files it edits (`app/jobs/catalog/rate_limit_retry.rb`, `app/jobs/catalog/refresh_job.rb`, `app/jobs/mtg/art/build_job.rb`, `app/models/catalog/refresh.rb`, `app/models/mtg/art/build.rb`, the client and source) and the specs it extends (`spec/jobs/catalog/refresh_job_spec.rb`, `spec/jobs/mtg/art/build_job_spec.rb`, `spec/models/catalog/refresh_spec.rb`, `spec/models/mtg/art/build_spec.rb`, `spec/footer_core_spec.rb`, `spec/support/fake_catalog_source.rb`, `scryfall_helpers.rb`, `solid_queue.rb`). Nothing was run. Blocks are strong drafts, not pre-run: execution goes red first, then green, and records any deviation in the commit body. What only a run can confirm is at the end.

## Design

**The shape.** The core concern asks the job a question and the jobs answer it from the operation object of their own attempt.

```ruby
# Catalog::RateLimitRetry (core; names nothing)
counted = rate_limit_progress? ? 0 : exception_executions[COUNTED_AS].to_i
raise error if counted >= MAX_RETRIES
exception_executions[COUNTED_AS] = counted + 1
```

- `rate_limit_progress?` is a private method with a default of `false` in the concern (FR-3, AC-1.6). A job class overrides it (a method of the class wins over the included module's). The question is asked only after the `LONGEST_WAIT` test, so a wait over an hour fails at once, progress or not (FR-1, AC-1.4).
- The count stays in `exception_executions` under the unchanged `COUNTED_AS` key (FR-4): a job queued before the upgrade keeps its count, and "progress" only ever writes 1 where the old rule wrote `count + 1`.
- Each job keeps its operation in an instance variable that `perform` sets to `nil` first, then assigns (decision 4, note 2): the job specs run `perform_now` repeatedly on one instance, and an assignment that raises (the constructor failing) would otherwise leave the previous attempt's answer behind. A job instance that is serialized for a retry carries no instance variables, so a worker's retry starts clean too.
- Each operation exposes `made_progress?`, the one word for both: `Catalog::Refresh#made_progress?` (core: a catalog row written) and `MTG::Art::Build#made_progress?` (MTG: an image fetched and kept, or a batch of fingerprints stored).

**Why this over the alternatives.**
- *A progress token stored in the job's retry record or in the database* (a column, a cache key): needs a second place to keep state, a migration or a key in the job's arguments, and has the stale-answer hazard of note 2. Rejected: the operation object already holds the facts and dies with the attempt.
- *The run record as the source of the answer* (compare `fetched_count` to a prior count): the refresh's counts tally entries only and the build's `fetched` counts an image later removed as undecodable (AC-2.6). Rejected: the run's counts are the wrong facts.
- *Rescue the error inside the operation and re-raise with a flag* (`RateLimitedError#progress`): changes the source contract's error class, which Scryfall's client and every source would then have to know. Rejected: FR-6 leaves the contract unchanged.
- *A module-level callable registry*: more machinery than one private method (Simplicity Gate: one concern, two jobs, two operations; no new class).

**What counts, in code.**
- Refresh: a flag set when a write has committed: after `write_sets` in `sync_sets` (when anything was written), after the `flush` transaction commits (any set, identity or entry), and after `retire_unseen` retires at least one entry. `seen`, `tally` and the download never touch it.
- Build: a `Set` of illustration ids fetched this attempt (added after the image is renamed into the cache, removed again when that image is deleted as undecodable) and a boolean set when `store` upserts at least one row. `@counts[:fetched]` is not reused because it counts an image later removed.

## Global Constraints

- `Catalog::RateLimitRetry`, `Catalog::RefreshJob` and `Catalog::Refresh` name no collectible; the MTG answer lives in `MTG::Art::Build` and `MTG::Art::BuildJob` (FR-7, AC-4.1).
- No migration, gem, setting, view, controller or source-contract change (`Catalog::Sources` is untouched, FR-6). `MAX_RETRIES`, `SHORTEST_WAIT`, `LONGEST_WAIT` and the client's back-off keep their values.
- Specs: `type:` tag explicit, `:aggregate_failures` on every multi-expectation example, examples at most 15 lines (`RSpec/ExampleLength`, `.rubocop.yml`). Examples that touch the art directory are tagged `:art_matching`; ones that need a real art build need ImageMagick, as the files they extend already do. No real HTTP (WebMock).
- Each task ends with one Conventional Commit; `git add` and `git commit` as separate commands; end each message with the attribution trailer the session gives. The commit hook runs RuboCop on staged Ruby files and Brakeman. Don't push: the pre-push hook runs the full `bin/ci`, and the maintainer commits and pushes. Run only the targeted spec files named in each task; the full suite and `bin/ci` are the supervisor's.
- `Gemfile.lock` has an unrelated local modification: don't stage it.
- Prose documents aren't checked from RSpec (`.claude/rules/testing.md`): AC-5.x are verified by reading and recorded in `verification.md` (Task 9).

## Spec coverage map

| Criterion | Task |
|---|---|
| AC-1.1 to AC-1.6, FR-1, FR-2, FR-3, FR-4, FR-8 | 1 (core hook) |
| AC-4.1, FR-7 | 2 |
| AC-3.3 (model), FR-6 | 3 |
| AC-3.1, AC-3.2, AC-3.3 and AC-3.4 (job) | 4 |
| AC-2.1, AC-2.2, AC-2.3, AC-2.4 (model), AC-2.6, FR-5 | 5 |
| AC-2.4 (job), AC-2.5 | 6 |
| AC-5.2 | 7 |
| AC-5.1 | 8 |
| AC-5.3 and the verification record | 9 |

---

## Task 1: The core asks the job whether its attempt made progress (FR-1 to FR-4, FR-8; AC-1.1 to AC-1.6)

**Files:** `spec/jobs/catalog/rate_limit_retry_spec.rb` (new), `app/jobs/catalog/rate_limit_retry.rb`.

**Red.** New file. Two probe jobs, defined with `stub_const` so Active Job can serialize them (it needs a class name); the first answers from its second argument, the second says nothing.

```ruby
require "rails_helper"

# Spec 043: the rule's own examples, with probe jobs that are rate limited every time they run. The jobs' own answers are
# in spec/jobs/catalog/refresh_job_spec.rb and spec/jobs/mtg/art/build_job_spec.rb.
RSpec.describe Catalog::RateLimitRetry, type: :job do
  let(:counted_as) { Catalog::RateLimitRetry::COUNTED_AS }

  # First argument: the wait the source asks for. Second: whether the attempt made progress, which the job answers.
  let(:probe_class) do
    stub_const("RateLimitedProbeJob", Class.new(ApplicationJob) do
      include Catalog::RateLimitRetry

      def perform(asked, progressed)
        @progressed = progressed
        raise Catalog::Sources::RateLimitedError.new("rate limited", retry_after: asked)
      end

      private
        def rate_limit_progress? = @progressed
    end)
  end

  # Includes the rule and says nothing about progress.
  let(:silent_class) do
    stub_const("SilentProbeJob", Class.new(ApplicationJob) do
      include Catalog::RateLimitRetry

      def perform = raise(Catalog::Sources::RateLimitedError.new("rate limited", retry_after: 60))
    end)
  end

  before { freeze_time }

  def probe(count, progressed, asked: 60)
    probe_class.new(asked, progressed).tap { |job| job.exception_executions[counted_as] = count unless count.nil? }
  end

  def count_of(job) = job.exception_executions[counted_as]

  context "when the attempt made progress" do
    it "retries after the wait and starts the count again at 1, from 3 (AC-1.1)", :aggregate_failures do
      job = probe(3, true)

      expect { job.perform_now }.to have_enqueued_job(probe_class).at(60.seconds.from_now)
      expect(count_of(job)).to eq(1)
    end

    it "retries every time, however many times it is rate limited (AC-1.5)", :aggregate_failures do
      job = probe(nil, true)

      expect { 8.times { job.perform_now } }.to have_enqueued_job(probe_class).exactly(8).times
      expect(count_of(job)).to eq(1)
    end

    [ nil, 5, 44 ].each do |asked|
      it "still waits 45 seconds at least, when the source asked for #{asked.inspect} (FR-8)" do
        job = probe(0, true, asked:)

        expect { job.perform_now }.to have_enqueued_job(probe_class).at(45.seconds.from_now)
      end
    end
  end

  context "when the attempt made no progress" do
    [ 0, 1, 2 ].each do |before|
      it "retries after the wait with the count one more, from #{before} (AC-1.3)", :aggregate_failures do
        job = probe(before, false)

        expect { job.perform_now }.to have_enqueued_job(probe_class).at(60.seconds.from_now)
        expect(count_of(job)).to eq(before + 1)
      end
    end

    it "fails with the rate-limit error from 3, as before (AC-1.2)" do
      expect { expect { probe(3, false).perform_now }.to raise_error(Catalog::Sources::RateLimitedError) }
        .not_to have_enqueued_job(probe_class)
    end
  end

  [ true, false ].each do |progressed|
    it "fails at once when asked to wait more than an hour, with progress #{progressed} (AC-1.4)" do
      job = probe(0, progressed, asked: 3601)

      expect { expect { job.perform_now }.to raise_error(Catalog::Sources::RateLimitedError) }
        .not_to have_enqueued_job(probe_class)
    end
  end

  it "treats a job that says nothing about progress as having made none: it fails the fourth time (AC-1.6, FR-3)", :aggregate_failures do
    job = silent_class.new

    expect { 3.times { job.perform_now } }.to have_enqueued_job(silent_class).exactly(3).times
    expect { expect { job.perform_now }.to raise_error(Catalog::Sources::RateLimitedError) }
      .not_to have_enqueued_job(silent_class)
  end
end
```

Run: `bin/rspec spec/jobs/catalog/rate_limit_retry_spec.rb`. Expected: the two progress examples fail ("AC-1.1": the job raises `Catalog::Sources::RateLimitedError` instead of being enqueued, since the count of 3 is at the limit; "AC-1.5": the same on the fourth run, the first three are retried); the wait examples with progress pass today, as do the no-progress, over-an-hour and silent ones (they pin today's behaviour, FR-1/FR-8, so they stay green and guard the change).

**Green.** `app/jobs/catalog/rate_limit_retry.rb`, replacing the private method (the file's header comments are rewritten in Task 7):

```ruby
  private
    def retry_when_asked(error)
      wait = [ error.retry_after.to_i.seconds, SHORTEST_WAIT ].max
      raise error if wait > LONGEST_WAIT

      counted = rate_limit_progress? ? 0 : exception_executions[COUNTED_AS].to_i
      raise error if counted >= MAX_RETRIES

      exception_executions[COUNTED_AS] = counted + 1
      retry_job(wait:, error:)
    end

    # Asked of the job when a rate limit ended its attempt: did that attempt do durable new work (spec 043)? A job that
    # includes this rule overrides it from its own operation; one that doesn't answers no, so every rate limit counts.
    def rate_limit_progress? = false
```

Run `bin/rspec spec/jobs/catalog/rate_limit_retry_spec.rb spec/jobs/catalog/refresh_job_spec.rb spec/jobs/mtg/art/build_job_spec.rb`. Expected: all green (the two existing job files still stub the operation's constructor to raise, so their jobs answer "no progress" and behave as before).

**Commit:** `feat(catalog): a rate-limited job asks whether its attempt made progress`.

---

## Task 2: The rule's source names nothing (AC-4.1, FR-7)

**Files:** `spec/rate_limit_retry_core_spec.rb` (new). No production change: it is a guard in the manner of `spec/footer_core_spec.rb`, so it is green when written; it fails if a later edit (including Task 7's comments) names a collectible, host, MTG constant or catalog table. Execution runs it once now and once after Task 7.

```ruby
require "rails_helper"

# Spec 043 AC-4.1, FR-7 (ADR 0018): the retry rule is core code. It asks the job whether its attempt made progress and
# names no collectible type, source, host, MTG constant or catalog table; each operation answers for itself.
RSpec.describe "The core's rate-limit retry rule" do
  let(:file) { Rails.root.join("app/jobs/catalog/rate_limit_retry.rb") }

  it "is the file the rule lives in" do
    expect(file).to exist
  end

  it "names no collectible, source, host, MTG constant or catalog table", :aggregate_failures do
    source = file.read

    expect(source).not_to match(/mtg|magic|wizards|scryfall|\.scryfall\.|cards\.|data\./i)
    expect(source).not_to match(/MTG::|Art::|ArtBuild|BuildJob|RefreshJob|Catalog::Refresh\b/)
    expect(source).not_to match(/catalog_(entries|identities|sets|refresh_runs)|mtg_/)
  end
end
```

Run: `bin/rspec spec/rate_limit_retry_core_spec.rb`. Expected: green at once (the Task 1 file names none of these; `Catalog::Sources::RateLimitedError` and `Catalog::Operation::Queue` are not matched). A note in the commit body says it is a guard, not a red-first example.

**Commit:** `test(catalog): the rate-limit retry rule names no collectible`.

---

## Task 3: A refresh says whether its attempt wrote a catalog row (FR-6; AC-3.3, decision 3)

**Files:** `spec/support/fake_catalog_source.rb`, `spec/models/catalog/refresh_spec.rb`, `app/models/catalog/refresh.rb`.

**Support.** Add after `ReportingCatalogSource` in `spec/support/fake_catalog_source.rb`:

```ruby
# A source that hands over all its records and is then turned away (spec 043 decision 3, AC-3.3): the stand-in for a
# source that can be rate limited after it has written something. Scryfall's refresh never is (area doc).
class RateLimitedCatalogSource < FakeCatalogSource
  def each_entry(path, languages:, &)
    super
    raise Catalog::Sources::RateLimitedError.new("rate limited", retry_after: 60)
  end
end
```

**Red.** In `spec/models/catalog/refresh_spec.rb`, a new `describe` at the end of the file's `RSpec.describe` (it uses the file's `let(:source)`, `refresh`, and the record helpers). The `RateLimitedCatalogSource` examples use `sets: []` so the only set is the one written with the first batch, and the batch size is stubbed where a batch must be written before the error (`Catalog::Refresh::BATCH_SIZE` is read at call time, so `stub_const` applies).

```ruby
  describe "#made_progress? (spec 043 decision 3)" do
    def attempt(from = source) = described_class.new("fake", trigger: "manual", source: from).tap(&:call)

    def turned_away(from)
      described_class.new("fake", trigger: "manual", source: from).tap do |run|
        expect { run.call }.to raise_error(Catalog::Sources::RateLimitedError)
      end
    end

    it "is false before it has run" do
      expect(described_class.new("fake", trigger: "manual", source:).made_progress?).to be(false)
    end

    it "is true when it inserted rows" do
      expect(attempt.made_progress?).to be(true)
    end

    it "is false when the same data is applied again, though it saw every record and downloaded the file", :aggregate_failures do
      attempt
      again = attempt

      expect(again.made_progress?).to be(false)
      expect(Catalog::RefreshRun.recent.first).to have_attributes(seen_count: 2, inserted_count: 0)
      expect(source.downloads).to eq(%w[v1 v1])
    end

    it "is true when an entry was updated" do
      attempt
      source.entries = [ entry_record("a"), entry_record("b", number: "2") ]

      expect(attempt.made_progress?).to be(true)
    end

    it "is true when an entry was only retired" do
      attempt
      source.entries = [ entry_record("a") ]

      expect(attempt.made_progress?).to be(true)
    end

    it "is true when an entry was only restored" do
      attempt
      source.entries = [ entry_record("a") ]
      attempt
      source.entries = [ entry_record("a"), entry_record("b") ]

      expect(attempt.made_progress?).to be(true)
    end

    it "is true when only a set was written, though no entry changed (tally covers entries only)" do
      attempt
      source.sets = [ set_record("lea"), set_record("m10") ]

      expect(attempt.made_progress?).to be(true)
    end

    it "is true when only an identity changed" do
      attempt
      source.entries = [ entry_record("a", identity: identity_record(extension: { errata: true })), entry_record("b") ]

      expect(attempt.made_progress?).to be(true)
    end

    it "is false when the source is turned away on its sets, after a fresh download", :aggregate_failures do
      allow(source).to receive(:each_set).and_raise(Catalog::Sources::RateLimitedError.new("rate limited", retry_after: 60))
      run = turned_away(source)

      expect(source.downloads).to eq([ "v1" ])
      expect(run.made_progress?).to be(false)
    end

    it "is true when the source is turned away after a batch was written (AC-3.3)", :aggregate_failures do
      stub_const("Catalog::Refresh::BATCH_SIZE", 1)
      run = turned_away(RateLimitedCatalogSource.new(entries: [ entry_record("a") ]))

      expect(run.made_progress?).to be(true)
      expect(Catalog::Entry.pluck(:external_key)).to eq([ "a" ])
    end

    it "is false when the source is turned away before the batch is written, though it saw records", :aggregate_failures do
      run = turned_away(RateLimitedCatalogSource.new(entries: [ entry_record("a"), entry_record("b") ]))

      expect(run.made_progress?).to be(false)
      expect(Catalog::Entry.count).to eq(0)
    end
  end
```

Run: `bin/rspec spec/models/catalog/refresh_spec.rb -e "made_progress"`. Expected: every example fails with `NoMethodError: undefined method 'made_progress?' for an instance of Catalog::Refresh`. (The "seen_count: 2" expectation in the third example needs the failing run's counts, which a first green run confirms.)

**Green.** `app/models/catalog/refresh.rb`:

- In `initialize`, after `@counts = Hash.new(0)`: `@wrote_rows = false`.
- After `call` (public section), before `private`:

  ```ruby
  # Whether this attempt wrote a catalog row: a set, an identity or an entry inserted, updated or restored, or an entry
  # retired (spec 043 decision 3). Records seen and the download are not progress: a retried refresh reads the same file
  # again. Catalog::RateLimitRetry asks it, through the job, of the attempt a rate limit ended.
  def made_progress? = @wrote_rows
  ```

- `sync_sets`: after `write_sets(changed)` add `@wrote_rows = true if changed.any?`.
- `flush`: after the `Catalog::Entry.transaction do … end` block and before `@pending_entries.each { |record| tally(record) }` add `@wrote_rows = true # the transaction has committed`.
- `retire_unseen`: after the `ids.each_slice(BATCH_SIZE) do … end` block, before `@counts[:retired] = ids.size`, add `@wrote_rows = true if ids.any?`.

Run `bin/rspec spec/models/catalog/refresh_spec.rb spec/models/catalog/refresh_scryfall_spec.rb spec/models/catalog/refresh_operation_spec.rb`. Expected: all green.

**Commit:** `feat(catalog): a refresh says whether its attempt wrote a catalog row`.

---

## Task 4: The refresh job answers from its attempt (FR-6, FR-2; AC-3.1, AC-3.2, AC-3.3, AC-3.4)

**Files:** `spec/jobs/catalog/refresh_job_spec.rb`, `app/jobs/catalog/refresh_job.rb`.

**Red.** In `spec/jobs/catalog/refresh_job_spec.rb`, inside the existing `context "when the source rate limits the refresh (issue #74)"` (it already has `before { freeze_time }` and `rate_limited`), add two helpers beside `rate_limited` and a nested `describe`:

```ruby
    def with_count(job, count) = job.tap { |queued| queued.exception_executions[Catalog::RateLimitRetry::COUNTED_AS] = count }

    def count_of(job) = job.exception_executions[Catalog::RateLimitRetry::COUNTED_AS]

    # Spec 043: only a refresh that wrote catalog rows before the rate limit starts the count again.
    describe "and its count is kept only without progress (spec 043)" do
      it "counts a rate limit on /bulk-data as no progress (AC-3.1)", :aggregate_failures do
        stub_request(:get, "https://api.scryfall.com/bulk-data").to_return(status: 429)
        job = with_count(described_class.new("mtg"), 2)

        expect { job.perform_now }.to have_enqueued_job(described_class).at(45.seconds.from_now)
        expect(count_of(job)).to eq(3)
      end

      it "counts a rate limit on /sets after a fresh download as no progress (AC-3.2)", :aggregate_failures do
        file = stub_scryfall(cards: [ scryfall_card ])
        stub_request(:get, "https://api.scryfall.com/sets").to_return(status: 429)
        job = with_count(described_class.new("mtg"), 2)

        expect { job.perform_now }.to have_enqueued_job(described_class)
        expect(file).to have_been_requested
        expect(count_of(job)).to eq(3)
      ensure
        FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir)
      end

      it "starts the count again after an attempt that wrote rows, then fails on the third rate limit with none (AC-3.3, AC-3.4)",
        :aggregate_failures do
        stub_const("Catalog::Refresh::BATCH_SIZE", 1)
        allow(Catalog).to receive(:source_for).with("fake").and_return(RateLimitedCatalogSource.new(entries: [ entry_record("a") ]))
        job = with_count(described_class.new("fake"), 3)

        expect { job.perform_now }.to have_enqueued_job(described_class) # wrote "a", then was turned away
        expect(count_of(job)).to eq(1)
        expect(2.times.map { job.perform_now && count_of(job) }).to eq([ 2, 3 ]) # nothing new to write
        expect { job.perform_now }.to raise_error(Catalog::Sources::RateLimitedError)
      end
    end
```

Run: `bin/rspec spec/jobs/catalog/refresh_job_spec.rb -e "kept only without progress"`. Expected: the first two examples pass already (a refresh never answers progress yet, so the count goes 2 to 3, as it must); the third fails at `expect(count_of(job)).to eq(1)` (it fails with `RateLimitedError` raised from the first `perform_now`, since the count 3 is at the limit). So AC-3.1 and AC-3.2 are guards; AC-3.3/3.4 are the red example. (If `job.perform_now && …` reads badly under RuboCop, split it into a `counts = []` block.)

**Green.** `app/jobs/catalog/refresh_job.rb`, replacing `perform` and adding the private answer:

```ruby
  def perform(collectible_type, trigger = "manual")
    @refresh = nil # the answer below is about this attempt alone: a job instance can run perform more than once (spec 043)
    @refresh = Catalog::Refresh.new(collectible_type, trigger:, job_id:)
    @refresh.call
  end

  private
    # Whether the attempt a rate limit just ended wrote a catalog row (Catalog::RateLimitRetry; spec 043 decision 3).
    # Nil when the refresh couldn't even be built.
    def rate_limit_progress? = @refresh&.made_progress? || false
```

Existing examples that stub `Catalog::Refresh.new` with `instance_double(Catalog::Refresh, call: nil)` still pass: the job asks only after a rate limit, and those examples raise from `new`, leaving `@refresh` nil.

Run `bin/rspec spec/jobs/catalog/refresh_job_spec.rb spec/jobs/catalog/rate_limit_retry_spec.rb`. Expected: all green.

**Commit:** `feat(catalog): the refresh job counts a rate limit only without progress`.

---

## Task 5: An art build says whether its attempt made progress (FR-5; AC-2.1, AC-2.2, AC-2.3, AC-2.4, AC-2.6)

**Files:** `spec/models/mtg/art/build_spec.rb`, `app/models/mtg/art/build.rb`.

**Red.** In `spec/models/mtg/art/build_spec.rb`, inside the existing `context "when the image host rate limits the build (issue #74)"` (its `before` creates `art_a` (2005) and `art_b` (2006) printings; `first` and `second` are their image URLs), add after its last example:

```ruby
    # Spec 043: an image fetched and kept, or a batch of fingerprints stored, is progress; nothing else is.
    describe "#made_progress?" do
      let(:build) { described_class.new(job_id: "job-1", client:) }

      def turned_away = expect { build.call }.to raise_error(Catalog::Sources::RateLimitedError)

      it "is true for an image fetched and kept before the rate limit (AC-2.1)" do
        stub_request(:get, first).to_return(body: noisy_png)
        stub_request(:get, second).to_return(status: 429)
        turned_away

        expect(build.made_progress?).to be(true)
      end

      it "is false when the first image request is rate limited (AC-2.2)" do
        stub_request(:get, first).to_return(status: 429)
        turned_away

        expect(build.made_progress?).to be(false)
      end

      it "is true for a batch of fingerprints stored for an image already cached, with none fetched (AC-2.3)", :aggregate_failures do
        stub_const("MTG::Art::Build::BATCH", 1)
        MTG::Art.cache_dir.mkpath
        MTG::Art.cache_dir.join("#{art_a}.jpg").binwrite(noisy_png)
        stub_request(:get, second).to_return(status: 429)
        turned_away

        expect(build.made_progress?).to be(true)
        expect(MTG::ArtBuild.sole).to have_attributes(fetched_count: 0, fingerprinted_count: 1)
      end

      it "is false when the only image fetched couldn't be decoded and was removed, and no batch was stored (AC-2.6)", :aggregate_failures do
        stub_request(:get, first).to_return(body: "not an image")
        stub_request(:get, second).to_return(status: 429)
        turned_away

        expect(build.made_progress?).to be(false)
        expect(MTG::ArtBuild.sole).to have_attributes(fetched_count: 1, failed_count: 1)
      end

      it "is false for a build skipped at start, which asks the host for nothing (AC-2.4)", :aggregate_failures do
        create(:mtg_art_build, status: "running", finished_at: nil, started_at: 1.minute.ago, heartbeat_at: 10.seconds.ago)
        image = stub_request(:get, first).to_return(body: noisy_png)

        expect(build.call).to have_attributes(status: "skipped", message: "already running")
        expect(build.made_progress?).to be(false)
        expect(image).not_to have_been_requested
      end

      it "is false before it has run" do
        expect(build.made_progress?).to be(false)
      end
    end
```

Run: `bin/rspec spec/models/mtg/art/build_spec.rb -e "made_progress"`. Expected: all six fail with `NoMethodError: undefined method 'made_progress?' for an instance of MTG::Art::Build`. The memoized helpers of the enclosing group (`naps`, `client`, `art_a`, `art_b`) plus `build` make five, the `RSpec/MultipleMemoizedHelpers` limit.

**Green.** `app/models/mtg/art/build.rb`:

- In `initialize`, after `@failures = []`:

  ```ruby
    @fetched_ids = ::Set.new # artworks whose image this attempt fetched and still holds (spec 043)
    @stored = false # a batch of fingerprints was stored
  ```

- Public method after `call`, before `private`:

  ```ruby
  # Whether this attempt did durable new work (spec 043 decision 3): an image fetched into the cache and kept there, or a
  # batch of fingerprints stored. Not progress: an image found already cached, the counts recorded at the start, an
  # image that failed, or one fetched but undecodable and so removed (the images of an unstored batch stay cached, and
  # count). Catalog::RateLimitRetry asks it, through the job, of the attempt a rate limit ended.
  def made_progress? = @stored || @fetched_ids.any?
  ```

- `fetch`: after `partial.rename(path)` and before `@counts[:fetched] += 1`, add `@fetched_ids << artwork.id`.
- `fingerprint`'s `rescue MTG::Art::Decoder::Error => error` branch: after `path&.delete # …` add `@fetched_ids.delete(artwork.id) # removed from the cache, so no longer kept`.
- `store`: after `MTG::Artwork.upsert_all(rows, unique_by: :illustration_id)` add `@stored = true`.

Run `bin/rspec spec/models/mtg/art/build_spec.rb`. Expected: all green (including the unrelated examples, since the change adds only bookkeeping).

**Commit:** `feat(art): an art build says whether its attempt fetched or stored anything`.

---

## Task 6: The build job answers from its attempt (FR-5; AC-2.4, AC-2.5)

**Files:** `spec/jobs/mtg/art/build_job_spec.rb`, `app/jobs/mtg/art/build_job.rb`.

**Red.** In `spec/jobs/mtg/art/build_job_spec.rb`, inside the rate-limit context: generalise the existing `two_artworks` helper to take the artwork names (default `%w[a b]`), renaming it `artworks`, and update its single call in the "stops at one 429 with no Retry-After…" example (`images = artworks`):

```ruby
    # Artworks in an applied catalog, oldest first, and a client that doesn't really sleep. Returns the image URLs.
    def artworks(names = %w[a b])
      create(:catalog_refresh_run, collectible_type: "mtg", source_version: "default-cards-1")
      allow(MTG::Scryfall::Client).to receive(:new).and_return(MTG::Scryfall::Client.new(sleeper: ->(_) { }, clock: -> { 0.0 }))
      names.map.with_index(1) do |name, year|
        url = "https://cards.scryfall.io/small/front/a/b/#{name}.jpg"
        create(:mtg_printing, illustration_id: "#{name * 8}-0000-4000-8000-000000000001", faces: [ { "image_uris" => { "small" => url } } ],
          entry: create(:catalog_entry, released_on: Date.new(2000 + year, 1, 1), set: create(:catalog_set)))
        url
      end
    end
```

Then add two examples after the "stops at one 429…" example:

```ruby
    # The issue's scenario (#86): every attempt but the last fetched images before it was turned away. Attempt 1 fetches a
    # and meets a 429 on b; 2 fetches b and meets one on c; 3 fetches c and meets one on d; 4 has nothing new to fetch.
    it "retries a fourth rate limit when the first three attempts fetched images and the fourth fetched none (AC-2.5)",
      :aggregate_failures, :art_matching do
      a, b, c, d = artworks(%w[a b c d])
      stub_request(:get, a).to_return(body: noisy_png)
      stub_request(:get, b).to_return({ status: 429 }, { body: noisy_png })
      stub_request(:get, c).to_return({ status: 429 }, { body: noisy_png })
      stub_request(:get, d).to_return(status: 429)
      queued = -> { ActiveJob::Base.queue_adapter.enqueued_jobs }
      counted = -> { queued.call.last.dig("exception_executions", Catalog::RateLimitRetry::COUNTED_AS) }

      described_class.perform_now
      counts = [ counted.call ]
      3.times { ActiveJob::Base.execute(queued.call.last).then { counts << counted.call } }

      expect(counts).to eq([ 1, 1, 1, 2 ])
      expect(MTG::ArtBuild.recent.pluck(:status)).to all(eq("failed"))
    end

    it "leaves its count alone when the build is skipped at start (AC-2.4)", :aggregate_failures, :art_matching do
      artworks
      create(:mtg_art_build, status: "running", finished_at: nil, started_at: 1.minute.ago, heartbeat_at: 10.seconds.ago)
      job = described_class.new
      job.exception_executions[Catalog::RateLimitRetry::COUNTED_AS] = 2

      expect { job.perform_now }.not_to have_enqueued_job(described_class)
      expect(job.exception_executions[Catalog::RateLimitRetry::COUNTED_AS]).to eq(2)
      expect(MTG::ArtBuild.recent.first).to have_attributes(status: "skipped", message: "already running")
    end
```

Run: `bin/rspec spec/jobs/mtg/art/build_job_spec.rb -e "AC-2.5" -e "AC-2.4"`. Expected: AC-2.5 fails: the third `ActiveJob::Base.execute` raises `Catalog::Sources::RateLimitedError` (the counts reach 3 and the next rate limit fails; today's rule), instead of reaching `[1, 1, 1, 2]`. AC-2.4 passes today (a skipped build never raises); it is a guard.

**Green.** `app/jobs/mtg/art/build_job.rb`, replacing `def perform = MTG::Art::Build.new(job_id:).call`:

```ruby
  def perform
    @build = nil # the answer below is about this attempt alone: a job instance can run perform more than once (spec 043)
    @build = MTG::Art::Build.new(job_id:)
    @build.call
  end

  private
    # Whether the attempt a rate limit just ended fetched and kept an image, or stored a batch of fingerprints
    # (Catalog::RateLimitRetry; spec 043 decision 3). False when the build couldn't even be built.
    def rate_limit_progress? = @build&.made_progress? || false
```

Run `bin/rspec spec/jobs/mtg/art/build_job_spec.rb spec/models/mtg/art/build_spec.rb spec/jobs/catalog/rate_limit_retry_spec.rb`. Expected: all green. The existing "runs a build under its own job id" example still passes (`and_call_original` on `new`).

**Commit:** `feat(art): the build job counts a rate limit only without progress`.

---

## Task 7: The comments say the new count (AC-5.2)

**Files:** `app/jobs/catalog/rate_limit_retry.rb`, `app/jobs/mtg/art/build_job.rb`. Comments only; no example.

`app/jobs/catalog/rate_limit_retry.rb`:
- Replace the last bullet of the header (`# - So does a job turned away again after MAX_RETRIES such retries.`) with:

  ```ruby
  # - The job is retried while its rate limits come with progress between them, and MAX_RETRIES times in a row without it
  #   (spec 043, issue #86). When a rate limit ends an attempt that made progress (the job's answer to
  #   #rate_limit_progress?: durable new work, as its own operation judges it), the count starts again at 1; otherwise it
  #   goes up by one, and the job fails when that would pass MAX_RETRIES, that is on the fourth rate limit in a row with no
  #   progress between them. A job that says nothing about progress has made none: every rate limit counts. The question
  #   is about the attempt the rate limit ended, alone.
  ```

- Replace the `COUNTED_AS` comment with `# Where the job keeps its count of rate limits in a row without progress; Active Job serializes exception_executions with the job (a job queued before spec 043 keeps its count).`
- Keep the sentences about the wait and the `retry_on` order. The text names no collectible, host or table (Task 2's guard).

`app/jobs/mtg/art/build_job.rb`: replace the final sentence of the header (`Asked to wait more than an hour, or turned away a fourth time, the job fails, and the build is started again from the admin pages or by the next refresh.`) with:

```ruby
# Asked to wait more than an hour, or turned away a fourth time in a row with no progress between (an image fetched and
# kept, or a batch of fingerprints stored, counts as progress: spec 043, issue #86), the job fails, and the build is
# started again from the admin pages or by the next refresh.
```

Run `bin/rspec spec/rate_limit_retry_core_spec.rb spec/jobs/catalog/rate_limit_retry_spec.rb` (the guard re-run; RuboCop's hook covers the Ruby files).

**Commit:** `docs(catalog): the retry rule's comments count rate limits without progress`.

---

## Task 8: The area doc (AC-5.1)

**Files:** `docs/architecture/catalog-operations.md`. Verified by reading (recorded in Task 9). Each new statement carries its source inline (`.claude/rules/documentation.md`).

1. **"A rate-limited job", step 2.** Replace its first two sentences from "A wait over `LONGEST_WAIT`, or a rate limit after `MAX_RETRIES` such retries of the job, fails the job instead; it then shows under Failed, and the next refresh or an admin starts another." with:

   > A wait over `LONGEST_WAIT` fails the job at once, progress or not. Otherwise the job is asked whether the attempt the rate limit ended made progress (`rate_limit_progress?`; a job that doesn't answer has made none). With progress the count of rate limits, kept in the job's retry record (`exception_executions`, under `COUNTED_AS`, as before), starts again at 1 and the job is retried; without it the count goes up by one and the job fails when that would pass `MAX_RETRIES`, that is on the fourth rate limit in a row with no progress between them. A failed job shows under Failed, and the next refresh or an admin starts another; an admin's retry starts the count again, as Solid Queue clears the record. The question is about the attempt the rate limit ended, alone (spec 043 decisions 1 and 2, FR-1 to FR-4; #86).
   >
   > Progress is durable new work, as the operation judges it (spec 043 decision 3). For a refresh (`Catalog::Refresh#made_progress?`): a catalog row written, meaning a set, an identity or an entry inserted, updated or restored, or an entry retired; not the records seen, which the page shows, and not the download, fresh or reused. For an art build (`MTG::Art::Build#made_progress?`): an image fetched into the cache and kept, or a batch of `BATCH` fingerprints stored; not images found already cached, not the counts recorded at the start, not an image that failed or was removed as undecodable. With Scryfall a refresh is only ever rate limited on `/bulk-data` or `/sets`, before any row is written, so its count behaves as it did; the rule is still tested with a source that is turned away after writing (spec 043 decision 3).

   The closing sentence of the step (the rule is tried before `retry_on`; `Catalog::RefreshJob` and `MTG::Art::BuildJob` include it) stays.

2. **"What the source does for a refresh".** Add a bullet: *A refresh asks the API host twice per run, `/bulk-data` before the download and `/sets` after it, at least `MIN_INTERVAL` apart; the bulk file comes from `data.scryfall.io`. Scryfall's documentation says the rate limits are those of `api.scryfall.com` and that "the direct file origins located at `*.scryfall.io` do not have rate limits" (https://scryfall.com/docs/api/rate-limits, read 2026-11-06), so the image origin never is by its documentation; the client still treats a 429 from any of them as a rate limit (spec 043 Problem Statement, "Does the image host ever rate limit?").*

3. **Named constants.**
   - `MAX_RETRIES` row, Purpose: "Rate limits in a row with no progress between them that a job is retried through before it fails, so a job that keeps being turned away stops while one that gets work done between rate limits doesn't". Source: "spec 002 FR-4; #74; spec 043 FR-2 (#86)".
   - `IMAGE_HOSTS` row, Purpose: "The only host an image is fetched from; Scryfall's documentation gives the `*.scryfall.io` file origins no rate limits (spec 043)". Source: "spec 011 AC-3.4; spec 024 Non-Goals; spec 043".

4. **Art index build, "Ends:" bullet** (the line that says the job runs again "through `Catalog::RateLimitRetry`"): append "; the job is retried without limit while each rate limit comes with progress, and fails on the fourth in a row without (spec 043)".

5. **Decisions not in an ADR.** Add: "**Progress is judged on the attempt the rate limit ended, alone.** In the order rate limit, a busy-database retry that did work, rate limit with no new work, the second rate limit counts 2, not 1: the job fails sooner than a perfect rule would, never later than before; the count stays in one place, the job's retry record (spec 043 decision 2)." Add under **Accepted limits and open issues** the same fact is not repeated; instead delete the line "[#86] … though it did work between them." (the issue is closed by this feature).

6. **Sources.** Add `- [Spec 043](../specs/043-rate-limit-retry-progress/spec.md): decisions 1 to 4, FR-1 to FR-8, Story 4.` after the spec 039 line; in the Issues line, move `#86` from the "open:" list (`open: #41, #77, #86, #111`) to the closed ones, giving `…, #84, #86, #122; open: #41, #77, #111`.

7. Not edited here: the "Distillation log" table (`distill-feature` adds its row when the feature is finished), `CLAUDE.md` (it points to this doc and restates nothing).

Reading check, recorded in Task 9: grep the doc for `#86` (it appears only in step 2, the `MAX_RETRIES` row, Decisions and Sources), for "fourth" (every use says "in a row with no progress between them"), and for "over the job's life" (none left).

**Commit:** `docs(catalog): the rate-limit retry count and what counts as progress (#86)`.

---

## Task 9: The spec index and the verification record (AC-5.3)

**Files:** `docs/specs/README.md`, `docs/specs/043-rate-limit-retry-progress/verification.md` (new). Two commits.

1. `docs/specs/README.md`: rows 002, 011 and 024 already carry the 043 clauses and row 043's Supersedes cell is written (read all four first and compare with the spec's "Supersedes" section; fix only a missing clause, keeping the other rows' text and other sessions' edits). Row 043's Plan cell changes from "not yet" to "present". Its Status stays "Approved" until the pull request merges (`distill-feature` changes it). **Commit:** `docs(specs): spec 043 plan present`.

2. `verification.md`, in the repository's shape (the run evidence is pasted from the executing session; nothing here is invented ahead of it):

   - A **Red evidence** table: one row per task 1 and 3 to 6 with the command from the task, the first-run failure message as seen, and the green run's summary line. Tasks 2 and 7 record that their examples were guards.
   - An **AC table**, one row per criterion AC-1.1 to AC-5.3: the example that covers it (`spec/jobs/catalog/rate_limit_retry_spec.rb` for AC-1.x; `spec/models/mtg/art/build_spec.rb` and `spec/jobs/mtg/art/build_job_spec.rb` for AC-2.x; `spec/models/catalog/refresh_spec.rb` and `spec/jobs/catalog/refresh_job_spec.rb` for AC-3.x; `spec/rate_limit_retry_core_spec.rb` for AC-4.1) and, for AC-5.1 to AC-5.3, the reading done: step 2 and the `MAX_RETRIES` row, the `IMAGE_HOSTS` row and the refresh bullet, #86 in the open list and in Sources (AC-5.1); the two comments (AC-5.2); the four index rows (AC-5.3).
   - The **final `bin/ci` result** at the last commit, with the date.
   - A "Deviations from the plan" section (empty if none).
   - **No `## Implementation review` heading here**: `sdd-review` Mode B adds it, with its verdict on its first line, and `distill-feature` reads that heading to know the feature is finished (`.claude/rules/documentation.md`).

   **Commit:** `docs(specs): spec 043 verification record`.

---

## Self-review

- **Spec coverage.** FR-1 (Task 1, AC-1.4 examples), FR-2 (Task 1), FR-3 (Task 1, silent probe), FR-4 (Task 1: same key; Tasks 4 and 6 read the count from the serialized queued job), FR-5 (Tasks 5, 6), FR-6 (Tasks 3, 4; `Catalog::Sources` untouched), FR-7 (Task 2), FR-8 (Task 1, the 45-second examples, plus the existing `retry_on`-order examples that stay green). Every AC is mapped in the table above; no gap.
- **Placeholders.** None: every code step shows code; the verification skeleton's evidence cells are filled by the executing session from real runs, which is the point of that file.
- **Names.** `rate_limit_progress?` (private, concern default and two job overrides), `made_progress?` (public on `Catalog::Refresh` and `MTG::Art::Build`), `RateLimitedCatalogSource` (support), `COUNTED_AS` (unchanged), `@refresh` and `@build` (job instance variables) are spelled the same in every task. Methods and helpers called exist: `have_enqueued_job(...).at/.exactly`, `freeze_time`, `stub_const`, `stub_scryfall` (returns the data file's stub), `scryfall_card`, `noisy_png`, `entry_record`, `identity_record`, `set_record`, `create(:mtg_art_build)`, `MTG::Art.cache_dir`, `ActiveJob::Base.queue_adapter.enqueued_jobs`, `ActiveJob::Base.execute`.

## Risks, and what only a run can confirm

- **Anonymous probe jobs.** The core spec relies on `stub_const` giving the `Class.new(ApplicationJob)` a name before it is enqueued (Ruby names a class at its first constant assignment), and on `retry_job` serializing the probe's two arguments. If Active Job complains, define the probes as constants at the top of the file instead.
- **`exception_executions` on a fresh instance.** The examples set it directly on a new job (`job.exception_executions[key] = 3`) as the existing "fails the fourth time" example implies; the first red run confirms it is an initialised hash on `ActiveJob::Base.new` in Rails 8.1.
- **Real-client examples** (AC-3.1, AC-3.2) sleep the client's real 100 ms throttle; the existing "asks Scryfall once…" example does the same. AC-3.2 depends on a later `stub_request` for `/sets` overriding the one `stub_scryfall` made (WebMock uses the last declared match) and on `Rails.configuration.x.catalog_download_dir` being removed afterwards (the `ensure`).
- **AC-3.4's stub of `Catalog.source_for`** with `.with("fake")`: any other argument in the same example would fail the stub. The job and `Catalog::Refresh` call it once, with the type. The attempt also reaches `Catalog::Operation::Queue` reads of the Solid Queue tables (loaded in the suite), as the existing real-refresh job examples do. If `with("fake")` proves brittle, use `and_wrap_original` keyed on the argument.
- **AC-2.5's exact sequence** (counts 1, 1, 1, 2) depends on each WebMock sequence being consumed once per attempt, which holds because a 429 with no `Retry-After` raises at once (#81) and a cached image is not requested again. A run confirms the four attempts really fetch `a`, `b`, `c` and nothing, and that ImageMagick decodes `noisy_png` as in the neighbouring examples.
- **`RSpec/ExampleLength` (15) and `RSpec/MultipleMemoizedHelpers` (5)** on the new examples (the AC-2.5 example is about 13 lines; the Task 5 group has five memoized helpers). RuboCop's hook on save will say; split an example or fold a helper into a method if needed.
- **`@fetched_ids` and the batch.** A fetched image is "kept" once decoded; when a batch's fingerprint upsert is lost to a rate limit later in the batch, the images stay cached and the attempt still counts as progress (decision 3). That is intended, but it means an attempt that fetched one image and was then turned away on every later image counts as progress each time; the bound on that is the finite number of uncached images (spec NFR Reliability), which no example exercises beyond AC-2.5.
- **Existing examples** that stub the operation's constructor to raise (`Catalog::Refresh.new`, `MTG::Art::Build.new`) leave the instance variable nil and so answer "no progress": the whole of `refresh_job_spec.rb` and `build_job_spec.rb` should stay green after Tasks 4 and 6; a run confirms it.
- **Documentation criteria** (AC-5.x) are not machine-checked; Task 9's reading and the supervisor's review are the only check. The area doc's exact wording of the unchanged sentences around the edits was read on 2026-11-06 and should be re-read before editing, since other branches edit the same file.
- **Not runnable here:** nothing in this plan was executed; the full suite, `bin/ci` and any Brakeman or RuboCop finding on the new code are the supervisor's run.
