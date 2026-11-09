# Implementation Plan: An Art Index Built With Other Settings or For an Older Catalog Isn't Plain "Ready"

**Spec:** docs/specs/053-art-index-drift/spec.md (v1.0.1, approved 2026-11-09)
**Decisions:** none new (no ADR: the comparison reuses the build row's two recorded columns; spec 039's decisions 1 and 6 stand)
**Created:** 2026-11-09

## Global Constraints

Copied from the spec; every phase includes them.

- No migration, no new column, no stored data; the export format and the backup are untouched (NFR Data).
- `Catalog::Operation`, the admin controllers and views, `AdminHelper`, the scanner and its JavaScript, `MTG::Art::Build`, the CSS and the design-system components change not at all (FR-4); `spec/admin_catalog_core_spec.rb` keeps checking the core files.
- A blank `settings_digest`, a blank `catalog_version`, or a latest applied refresh with a blank `source_version` isn't judged (decision 1).
- Both comparisons are made only for a finished latest build whose file is on disk (spec 039's missing state first), and only once nothing is in flight (decision 1, AC-1.8).
- The panel's summary names the state first, one sentence, then what you can do; sentence case, "you", no emoji, numbers exact; "Warning" is the word that carries a warning fact's status (NFR UI; `docs/design-system/components/AdminCatalog.md`). No new component, class or token.
- Exact wording: summary "Out of date. Built with other settings, so the scanner can't use it. Build the art index again."; warning fact "Built from catalog <built>; the latest refresh is <latest>. Cards added since may be missing from it. Build the art index again."
- Cost: one more query per panel render and per `catalog:status` run (the latest applied refresh's version), only in the finished branch; no network, no file read.
- Test files: `type:` tags explicit, `:aggregate_failures` on multi-expectation examples, no `any_instance_of`, no sleeps (`.claude/rules/testing.md`).
- Commits: one Conventional Commit per task, ending with the `Co-Authored-By:` line of the model that made it. Stage and commit in separate Bash calls.

---

## Goal

The Art index panel and the `catalog:status` art line say "Out of date" for a finished build made with other settings (which the scanner refuses) and add a "Warning" for one made for an older catalog (which the scanner still uses), and say plain "Ready." again once a build at the current settings and catalog finishes.

---

## Phase 1: The two comparisons

**Implements:** FR-1 | **Satisfies:** decision 1 (the tests), AC-1.7 (the blanks, at the model level)
**Files:** `app/models/mtg/art_build.rb`, `app/models/mtg/art.rb`, `spec/models/mtg/art_build_spec.rb`, `spec/models/mtg/art_spec.rb`
**Interfaces:** Consumes: nothing new (`MTG::Art::Settings.digest`, `Catalog::RefreshRun.last_applied`, `MTG::Art::Build::COLLECTIBLE_TYPE`). Produces: `MTG::ArtBuild#settings_drift?` (Boolean), `MTG::ArtBuild#catalog_drift?(latest_version)` (Boolean), `MTG::Art.latest_catalog_version` (String or nil).

The build row already holds what the comparison needs; this phase gives the panel and the line one statement of each test, as `#left_behind?` is one statement of its rule.

- [ ] **Task 1.1: write the failing model examples.** In `spec/models/mtg/art_build_spec.rb`, add before the last `end` (after the `#index_file_present?` describe, line 252):

```ruby

  describe "#settings_drift? and #catalog_drift? (spec 053 decision 1)" do
    it "judges the build's settings digest against the current one, and a blank digest not at all", :aggregate_failures do
      expect(build(:mtg_art_build)).not_to be_settings_drift
      expect(build(:mtg_art_build, settings_digest: "0123456789abcdef")).to be_settings_drift
      expect(build(:mtg_art_build, settings_digest: nil)).not_to be_settings_drift
      expect(build(:mtg_art_build, settings_digest: "")).not_to be_settings_drift
    end

    it "judges the build's catalog version against the latest one given, a blank on either side not at all", :aggregate_failures do
      run = build(:mtg_art_build, catalog_version: "default-cards-1")

      expect(run.catalog_drift?("default-cards-1")).to be(false)
      expect(run.catalog_drift?("default-cards-2")).to be(true)
      expect(run.catalog_drift?(nil)).to be(false)
      expect(run.catalog_drift?("")).to be(false)
      expect(build(:mtg_art_build, catalog_version: nil).catalog_drift?("default-cards-2")).to be(false)
    end
  end
```

In `spec/models/mtg/art_spec.rb`, add before the `describe ".page_config` block (line 144):

```ruby
  describe ".latest_catalog_version (spec 053 decision 1)" do
    it "is the latest applied mtg refresh's source version, and nil when none is applied or that refresh has none", :aggregate_failures do
      expect(described_class.latest_catalog_version).to be_nil

      create(:catalog_refresh_run, source_version: "default-cards-1", finished_at: 2.hours.ago)
      create(:catalog_refresh_run, source_version: "default-cards-2", finished_at: 1.hour.ago)
      create(:catalog_refresh_run, source_version: "default-cards-3", status: "failed", finished_at: 10.minutes.ago)
      expect(described_class.latest_catalog_version).to eq("default-cards-2")

      create(:catalog_refresh_run, source_version: nil, finished_at: 5.minutes.ago)
      expect(described_class.latest_catalog_version).to be_nil
    end
  end

```

- [ ] **Task 1.2: run them, confirm red.** `bin/rspec spec/models/mtg/art_build_spec.rb spec/models/mtg/art_spec.rb` — expect 3 failures (`undefined method 'settings_drift?'`/`'catalog_drift?'`/`'latest_catalog_version'`).
- [ ] **Task 1.3: implement.** In `app/models/mtg/art_build.rb`, after `index_file_present?` (before `def counts`):

```ruby
  # Whether the build used other fingerprint settings than the instance runs now (spec 053 decision 1). The scanner
  # refuses an index of another digest, so this is its own state. A build row with no digest isn't judged.
  def settings_drift? = settings_digest.present? && settings_digest != MTG::Art::Settings.digest

  # Whether the build is for another catalog version than the latest applied refresh's, which the caller reads once
  # (MTG::Art.latest_catalog_version). The scanner keeps using such an index, so this is a warning. A blank on either
  # side isn't judged.
  def catalog_drift?(latest_version) = catalog_version.present? && latest_version.present? && catalog_version != latest_version
```

In `app/models/mtg/art.rb`, after `page_config`'s `end`:

```ruby

  # The source version of the latest applied catalog refresh, the version a build records (MTG::Art::Build#call) and the
  # one a build's catalog drift is judged against (spec 053 decision 1). Nil with none applied, or when that refresh
  # recorded no version.
  def self.latest_catalog_version = Catalog::RefreshRun.for_type(MTG::Art::Build::COLLECTIBLE_TYPE).last_applied&.source_version
```

- [ ] **Task 1.4: run them, confirm green.** `bin/rspec spec/models/mtg/art_build_spec.rb spec/models/mtg/art_spec.rb` — expect 0 failures.
- [ ] **Task 1.5: commit.** Stage the four files; commit `feat(art): settings and catalog drift readers on the build (#176)`.

---

## Phase 2: The panel

**Implements:** FR-2 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-1.5, AC-1.6, AC-1.7, AC-1.8, AC-1.9, AC-1.10, AC-3.1
**Files:** `app/models/mtg/art/operation.rb`, `spec/models/mtg/art/operation_spec.rb`, `spec/requests/admin/catalogs_spec.rb`
**Interfaces:** Consumes: `MTG::ArtBuild#settings_drift?`, `#catalog_drift?(latest)`, `MTG::Art.latest_catalog_version` (Phase 1). Produces: `MTG::Art::Operation#state` returning `:out_of_date`; `MTG::Art::Operation::OUT_OF_DATE`; the "Warning" fact under `:ready`.

The state goes between `:index_missing` and `:ready` inside the finished branch; the warning fact is the last fact of `:ready` only. Copy was checked against the design system's voice rules and `AdminCatalog.md` (state word first; a fact's long value wraps), so no view, class or token changes.

- [ ] **Task 2.1: write the failing model examples.** In `spec/models/mtg/art/operation_spec.rb`:

(a) In the `"with art matching off"` context, right after its `"looks at no file, whatever the latest build names (spec 039 AC-1.7)"` example, add:

```ruby

    it "makes no drift comparison (spec 053 AC-1.9)", :aggregate_failures do
      loaded
      build(index_file: "art-index-default-cards-1-0123456789abcdef-9.bin.gz", settings_digest: "0123456789abcdef")
      allow(MTG::Art).to receive(:latest_catalog_version)

      expect(operation.state).to eq(:off)
      expect(operation.facts).to eq([])
      expect(MTG::Art).not_to have_received(:latest_catalog_version)
    end
```

(b) Immediately before the final two `end`s of the file (after the `"with a finished build whose index file is gone (spec 039)"` context's closing `end`), add:

```ruby

    context "with a finished build that drifted (spec 053)" do
      let(:other) { "0123456789abcdef" }
      let(:gone) { "art-index-default-cards-1-0123456789abcdef-9.bin.gz" }

      def facts = operation.facts.to_h { |fact| [ fact.label, fact.value ] }

      it "says it is out of date when built with other settings, with its facts and a button (AC-1.1, AC-1.2, AC-1.3)", :aggregate_failures do
        loaded
        name = art_index_name
        build(index_file: name, settings_digest: other, indexed_count: 9, without_image_count: 1, failed_count: 2)

        expect(operation).to have_attributes(state: :out_of_date, startable?: true, meter: nil, failed_job?: false, record_running?: false,
          summary: "Out of date. Built with other settings, so the scanner can't use it. Build the art index again.")
        expect(operation.facts.map(&:label)).to eq([ "Finished", "Index file", "Built with settings", "Current settings", "Artworks indexed",
          "Without an image", "Failed images" ])
        expect(facts).to include("Index file" => name, "Built with settings" => other, "Current settings" => MTG::Art::Settings.digest,
          "Artworks indexed" => 9, "Without an image" => 1, "Failed images" => 2)
      end

      it "is plain ready at the current settings and the latest catalog (AC-1.4)", :aggregate_failures do
        create(:catalog_refresh_run, source_version: "default-cards-1")
        build(index_file: art_index_name)

        expect(operation).to have_attributes(state: :ready, summary: "Ready.")
        expect(operation.facts.map(&:label)).to eq([ "Finished", "Artworks indexed", "Without an image", "Failed images" ])
      end

      it "stays ready with a warning fact last when built for an older catalog (AC-1.5)", :aggregate_failures do
        create(:catalog_refresh_run, source_version: "default-cards-2")
        build(index_file: art_index_name)

        expect(operation).to have_attributes(state: :ready, summary: "Ready.", startable?: true, meter: nil)
        expect(operation.facts.map(&:label)).to eq([ "Finished", "Artworks indexed", "Without an image", "Failed images", "Warning" ])
        expect(operation.facts.last.value).to eq("Built from catalog default-cards-1; the latest refresh is default-cards-2. " \
                                                 "Cards added since may be missing from it. Build the art index again.")
      end

      it "says out of date alone when both drifted (AC-1.6)", :aggregate_failures do
        create(:catalog_refresh_run, source_version: "default-cards-2")
        build(index_file: art_index_name, settings_digest: other)

        expect(operation.state).to eq(:out_of_date)
        expect(operation.facts.map(&:label)).not_to include("Warning")
      end

      it "reads a missing file as missing, whatever the settings (AC-1.6)" do
        loaded
        build(index_file: gone, settings_digest: other)

        expect(operation.state).to eq(:index_missing)
      end

      it "judges no settings for a build with no digest (AC-1.7)", :aggregate_failures do
        create(:catalog_refresh_run, source_version: "default-cards-1")
        build(index_file: art_index_name, settings_digest: nil)

        expect(operation.state).to eq(:ready)
        expect(operation.facts.map(&:label)).not_to include("Warning")
      end

      it "judges no catalog for a build with no catalog version (AC-1.7)", :aggregate_failures do
        create(:catalog_refresh_run, source_version: "default-cards-2")
        build(index_file: art_index_name, catalog_version: nil)

        expect(operation.state).to eq(:ready)
        expect(operation.facts.map(&:label)).not_to include("Warning")
      end

      it "judges no catalog when the latest applied refresh has no version (AC-1.7)", :aggregate_failures do
        loaded
        build(index_file: art_index_name)

        expect(operation.state).to eq(:ready)
        expect(operation.facts.map(&:label)).not_to include("Warning")
      end

      it "is queued while a build job waits (AC-1.8)" do
        loaded
        build(index_file: art_index_name, settings_digest: other)
        queue_job(MTG::Art::BuildJob)

        expect(operation.state).to eq(:queued)
      end

      it "is building while a later build runs (AC-1.8)" do
        loaded
        build(index_file: art_index_name, settings_digest: other, started_at: 2.hours.ago)
        build(status: "running", finished_at: nil, heartbeat_at: 20.seconds.ago)

        expect(operation.state).to eq(:building)
      end

      it "is failed, worded as before, when the latest build failed (AC-1.8)", :aggregate_failures do
        loaded
        build(index_file: art_index_name, settings_digest: other, started_at: 2.hours.ago)
        build(status: "failed", message: "Errno::ENOSPC: No space left on device")

        expect(operation).to have_attributes(state: :failed, summary: "Failed. An unexpected error stopped it.")
      end
    end
```

(c) In `spec/requests/admin/catalogs_spec.rb`, directly after the example `"says a finished build's index file is missing, with its facts and an enabled button, and doesn't poll (spec 039 AC-1.8)"` (it ends at the `end` before `"queues one build when Build art index is pressed with the index file missing"`), add:

```ruby

      it "says a finished build is out of date, with its facts and an enabled button, and doesn't poll (spec 053 AC-1.10)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run)
        name = art_index_name
        create(:mtg_art_build, index_file: name, settings_digest: "0123456789abcdef", indexed_count: 31_904, without_image_count: 12,
          failed_count: 3, finished_at: Time.utc(2026, 10, 9, 5, 0))

        get admin_catalog_path

        expect(text(section("art_index"))).to eq("Art index Build art index Out of date. Built with other settings, so the scanner " \
          "can't use it. Build the art index again. Finished 9 Oct 2026 05:00 UTC Index file #{name} Built with settings " \
          "0123456789abcdef Current settings #{MTG::Art::Settings.digest} Artworks indexed 31,904 Without an image 12 Failed images 3")
        expect(section("art_index").at_css("button")["disabled"]).to be_nil
        expect(page.at_css("[data-controller~='poll']")).to be_nil
      end

      it "shows a warning under Ready. for a build made for an older catalog, with an enabled button, and doesn't poll (spec 053 AC-1.10)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run, source_version: "default-cards-2")
        create(:mtg_art_build, index_file: art_index_name, indexed_count: 31_904, without_image_count: 12, failed_count: 3,
          finished_at: Time.utc(2026, 10, 9, 5, 0))

        get admin_catalog_path

        expect(text(section("art_index"))).to eq("Art index Build art index Ready. Finished 9 Oct 2026 05:00 UTC Artworks indexed 31,904 " \
          "Without an image 12 Failed images 3 Warning Built from catalog default-cards-1; the latest refresh is default-cards-2. " \
          "Cards added since may be missing from it. Build the art index again.")
        expect(section("art_index").at_css("button")["disabled"]).to be_nil
        expect(page.at_css("[data-controller~='poll']")).to be_nil
      end

      it "queues one build when Build art index is pressed with the index out of date (spec 053 AC-3.1)", :aggregate_failures, :art_matching do
        create(:catalog_refresh_run)
        create(:mtg_art_build, index_file: art_index_name, settings_digest: "0123456789abcdef")
        get admin_catalog_path
        expect(section("art_index").at_css("button")["disabled"]).to be_nil

        start("art_index")
        expect(flash[:notice]).to eq("Art index build queued.")
        expect(SolidQueue::Job.where(class_name: "MTG::Art::BuildJob").count).to eq(1)
      end
```

- [ ] **Task 2.2: run them, confirm red.** `bin/rspec spec/models/mtg/art/operation_spec.rb spec/requests/admin/catalogs_spec.rb` — expect failures in AC-1.1/1.2 (`:ready` for `:out_of_date`), AC-1.5 (no "Warning" fact), AC-1.6 "says out of date alone", and the two new request examples (and the AC-3.1 example, which reads "Ready." with an enabled button, so it passes: a guard); AC-1.4, the blank ones and the in-flight ones pass already as guards. The AC-1.9 example passes only once `MTG::Art.latest_catalog_version` exists (Phase 1), so it passes here.
- [ ] **Task 2.3: implement.** In `app/models/mtg/art/operation.rb`:

(a) Add the constant after `INDEX_MISSING`:

```ruby
  OUT_OF_DATE = "Out of date. Built with other settings, so the scanner can't use it. Build the art index again.".freeze
```

(b) Replace the `state` method's comment and body (from the comment line `# :off, :queued, …` through the method's `end`) with:

```ruby
  # :off, :queued, :building, :stalled, :interrupted, :never, :ready, :index_missing, :out_of_date or :failed. A build
  # still marked running that nothing is working on any more is interrupted: its heartbeat stopped 10 minutes ago, or
  # 2 minutes ago and the queue has failed its job or no longer holds it (issue #73). One whose heartbeat stopped
  # 10 minutes ago while a worker still holds its job is stalled instead (issue #79). A finished build is judged by
  # its file first: not on the volume is :index_missing (spec 039); then by its settings: another digest than the
  # instance runs now is :out_of_date, since the scanner refuses such an index (spec 053). It is judged only once
  # nothing is in flight or running, so the states above it win.
  def state
    @state ||=
      if !MTG::Art.enabled? then :off
      elsif build&.running? then running_state
      elsif queue.any? then :queued
      elsif build.nil? then :never
      elsif build.finished? then finished_state
      else :failed
      end
  end
```

(c) In `summary`, after `when :index_missing then INDEX_MISSING` add `when :out_of_date then OUT_OF_DATE`.

(d) In `facts`, change `when :ready, :index_missing then finished_facts` to `when :ready, :index_missing, :out_of_date then finished_facts`.

(e) In the private section, before `failed_summary`, replace `finished_facts` with these three methods (keeping `failed_summary` after them):

```ruby
    # The file's own state first, then the settings it was built with (spec 053 decision 2).
    def finished_state
      if !build.index_file_present? then :index_missing
      elsif build.settings_drift? then :out_of_date
      else :ready
      end
    end

    # What a finished build records, plus the file's name where the file is the point (spec 039 decision 2), the two
    # settings digests where they differ (spec 053 decision 2), and a warning when a ready build is for an older
    # catalog (spec 053 decision 3).
    def finished_facts
      drifted = state == :out_of_date
      [ fact("Finished", build.finished_at),
        (fact("Index file", build.index_file.presence || "none recorded") if state == :index_missing || drifted),
        (fact("Built with settings", build.settings_digest) if drifted),
        (fact("Current settings", MTG::Art::Settings.digest) if drifted),
        fact("Artworks indexed", build.indexed_count), fact("Without an image", build.without_image_count),
        fact("Failed images", build.failed_count),
        (fact("Warning", catalog_warning) if state == :ready && build.catalog_drift?(latest_catalog_version)) ].compact
    end

    def catalog_warning
      "Built from catalog #{build.catalog_version}; the latest refresh is #{latest_catalog_version}. " \
        "Cards added since may be missing from it. Build the art index again."
    end

    # Read once per render, and only for a ready build (spec 053 NFR Cost).
    def latest_catalog_version
      return @latest_catalog_version if defined?(@latest_catalog_version)

      @latest_catalog_version = MTG::Art.latest_catalog_version
    end
```

- [ ] **Task 2.4: run, confirm green.** `bin/rspec spec/models/mtg/art/operation_spec.rb spec/requests/admin/catalogs_spec.rb spec/admin_catalog_core_spec.rb spec/models/mtg/art_spec.rb spec/tasks/catalog_rake_spec.rb` — expect 0 failures (the existing "Ready." examples stay green: their applied refresh has no `source_version`, AC-1.7).
- [ ] **Task 2.5: commit.** Stage the three files; commit `feat(admin): the art index panel says out of date and warns of an older catalog (#176)`.

---

## Phase 3: The status line

**Implements:** FR-3 | **Satisfies:** AC-2.1, AC-2.2, AC-2.3
**Files:** `app/models/mtg/art.rb`, `spec/models/mtg/art_spec.rb`
**Interfaces:** Consumes: `MTG::ArtBuild#settings_drift?`, `#catalog_drift?(latest)`, `MTG::Art.latest_catalog_version` (Phase 1). Produces: `MTG::Art.status_line` lines "Art matching: out of date (…)" and the ready line with a trailing warning.

- [ ] **Task 3.1: write the failing examples.** In `spec/models/mtg/art_spec.rb`, directly after the example `"says no file name was recorded for a finished build without one (spec 039 AC-2.1)"` (inside `describe ".status_line"`), add:

```ruby

    it "says the index is out of date when built with other settings, and what to press (spec 053 AC-2.1)", :aggregate_failures, :art_matching do
      name = art_index_name
      create(:mtg_art_build, indexed_count: 9, without_image_count: 1, failed_count: 2, index_file: name, settings_digest: "0123456789abcdef")
      line = described_class.status_line

      expect(line).to eq("Art matching: out of date (built with settings 0123456789abcdef, current #{MTG::Art::Settings.digest}); " \
        "the scanner reads text only. Press Build art index on the admin catalog page to build it again. " \
        "9 artworks indexed, 1 without an image, 2 failed images; index #{name}")
      expect(line).not_to include("ready")
    end

    it "adds a warning to the ready line when built for an older catalog (spec 053 AC-2.2)", :aggregate_failures, :art_matching do
      create(:catalog_refresh_run, source_version: "default-cards-2")
      name = art_index_name
      create(:mtg_art_build, indexed_count: 9, without_image_count: 1, failed_count: 2, index_file: name)

      expect(described_class.status_line).to eq("Art matching: ready; 9 artworks indexed, 1 without an image, 2 failed images; " \
        "index #{name}. Warning: built from catalog default-cards-1, the latest refresh is default-cards-2; press Build art index " \
        "on the admin catalog page to build it again.")
    end

    it "judges nothing of a blank, and reads a missing file first (spec 053 AC-2.3)", :aggregate_failures, :art_matching do
      create(:catalog_refresh_run, source_version: "default-cards-2")
      name = art_index_name
      create(:mtg_art_build, index_file: name, catalog_version: nil, settings_digest: nil, indexed_count: 9, without_image_count: 1, failed_count: 2)
      expect(described_class.status_line).to eq("Art matching: ready; 9 artworks indexed, 1 without an image, 2 failed images; index #{name}")

      MTG::ArtBuild.delete_all
      create(:mtg_art_build, index_file: "art-index-v1-0123456789abcdef-9.bin.gz", settings_digest: "0123456789abcdef")
      expect(described_class.status_line).to start_with("Art matching: index file missing")
    end
```

- [ ] **Task 3.2: run, confirm red.** `bin/rspec spec/models/mtg/art_spec.rb` — expect 2 failures (the out of date and the warning examples read the plain ready line); the third passes (guard).
- [ ] **Task 3.3: implement.** In `app/models/mtg/art.rb`: update the `status_line` comment's last sentence to `A finished build whose index file isn't on the volume reads as missing, and says to press the admin page's button (spec 039 decision 3); one made with other settings reads as out of date, which the scanner refuses, and one made for an older catalog reads as ready with a warning (spec 053 decision 4).` Then replace the two lines

```ruby
    elsif run.finished?
      "Art matching: ready; #{run.indexed_count} artworks indexed, #{run.without_image_count} without an image, " \
        "#{run.failed_count} failed images; index #{run.index_file}"
```

with:

```ruby
    elsif run.finished? && run.settings_drift?
      "Art matching: out of date (built with settings #{run.settings_digest}, current #{MTG::Art::Settings.digest}); the scanner " \
        "reads text only. Press Build art index on the admin catalog page to build it again. #{run.indexed_count} artworks indexed, " \
        "#{run.without_image_count} without an image, #{run.failed_count} failed images; index #{run.index_file}"
    elsif run.finished?
      ready_line(run)
```

and add, after `status_line`'s `end` and before the module's closing `end`:

```ruby

  # The ready line, with the older-catalog warning after it (spec 053 decision 4).
  def self.ready_line(run)
    line = "Art matching: ready; #{run.indexed_count} artworks indexed, #{run.without_image_count} without an image, " \
           "#{run.failed_count} failed images; index #{run.index_file}"
    latest = latest_catalog_version
    return line unless run.catalog_drift?(latest)

    "#{line}. Warning: built from catalog #{run.catalog_version}, the latest refresh is #{latest}; press Build art index on the " \
      "admin catalog page to build it again."
  end
  private_class_method :ready_line
```

- [ ] **Task 3.4: run, confirm green.** `bin/rspec spec/models/mtg/art_spec.rb spec/tasks/catalog_rake_spec.rb spec/models/mtg/scryfall/source_spec.rb` — expect 0 failures.
- [ ] **Task 3.5: commit.** Stage `app/models/mtg/art.rb` and `spec/models/mtg/art_spec.rb`; commit `feat(art): catalog:status says out of date and warns of an older catalog (#176)`.

---

## Phase 4: Building again, and the scanner's behaviour pinned

**Implements:** Story 3, Story 4 (and so the Problem Statement's two rows) | **Satisfies:** AC-3.2, AC-3.3, AC-4.1, AC-4.2
**Files:** `spec/models/mtg/art/build_spec.rb`, `spec/requests/scanner/art_indexes_spec.rb`
**Interfaces:** Consumes: Phases 1–3 (the states and lines). Produces: nothing in code (examples only; the build and the scanner are unchanged).

AC-3.2 and AC-3.3 go red against the pre-Phase-2 code (they assert `:out_of_date` and the warning before building), so they prove the end-to-end path on top of this plan's code. AC-4.1 and AC-4.2 pin what the code already does (Problem Statement); they are characterization examples, green from the start, and are written to fail if the scanner's behaviour ever changes.

- [ ] **Task 4.1: write the build examples.** In `spec/models/mtg/art/build_spec.rb`, directly after the example `"writes a missing index file again without an image request, and reads ready again (spec 039 AC-3.2)"`, before the file's last `end`, add:

```ruby

  it "builds an out of date index again from the cached images without an image request, and reads ready again (spec 053 AC-3.2)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    serve("#{art_a}-2005-1")
    allow(MTG::Art::Settings).to receive(:digest).and_return("0123456789abcdef") # the settings this build used
    old_name = run_build.index_file
    allow(MTG::Art::Settings).to receive(:digest).and_call_original
    expect(MTG::Art::Operation.new("mtg").state).to eq(:out_of_date)
    expect(MTG::Art.status_line).to start_with("Art matching: out of date (built with settings 0123456789abcdef")

    WebMock.reset! # no stub is left: a request would raise, and would be counted
    built = run_build(job_id: "job-2")

    expect(built).to have_attributes(status: "finished", fetched_count: 0, fingerprinted_count: 1, settings_digest: MTG::Art::Settings.digest)
    expect(built.index_file).not_to eq(old_name)
    expect(a_request(:any, /.*/)).not_to have_been_made
    expect(MTG::Art::Index.dir.join(built.index_file)).to be_file
    expect(MTG::Art::Operation.new("mtg").state).to eq(:ready)
    expect(MTG::Art.status_line).to start_with("Art matching: ready")
  end

  it "builds again for a newer catalog, and the warning goes (spec 053 AC-3.3)", :aggregate_failures do
    printing(art_a, released_on: Date.new(2005, 1, 1))
    serve("#{art_a}-2005-1")
    run_build
    create(:catalog_refresh_run, collectible_type: "mtg", source_version: "default-cards-2", finished_at: 1.minute.ago)
    warned = MTG::Art::Operation.new("mtg")
    expect(warned.state).to eq(:ready)
    expect(warned.facts.map(&:label)).to include("Warning")
    expect(MTG::Art.status_line).to include("Warning: built from catalog default-cards-1, the latest refresh is default-cards-2")

    WebMock.reset!
    expect(run_build(job_id: "job-2")).to have_attributes(status: "finished", fetched_count: 0, catalog_version: "default-cards-2")

    expect(a_request(:any, /.*/)).not_to have_been_made
    fresh = MTG::Art::Operation.new("mtg")
    expect(fresh.state).to eq(:ready)
    expect(fresh.facts.map(&:label)).not_to include("Warning")
    expect(MTG::Art.status_line).not_to include("Warning")
  end
```

- [ ] **Task 4.2: write the pinning examples.** In `spec/requests/scanner/art_indexes_spec.rb`, before the file's last `end`, add:

```ruby

  describe "an index that drifted (spec 053 Problem Statement)" do
    def served_digest = Zlib.gunzip(response.body.b).byteslice(8, 16)

    it "is offered to the page and served although its header digest isn't the page's, which the browser refuses (AC-4.1)", :aggregate_failures do
      path = write("v1")
      bytes = Zlib.gunzip(path.binread)
      bytes[8, 16] = "0123456789abcdef"
      path.binwrite(ActiveSupport::Gzip.compress(bytes))
      config = MTG::Art.page_config

      get scanner_art_index_path(config.fetch(:name))

      expect(config).to include(name: path.basename.to_s)
      expect(response).to have_http_status(:ok)
      expect(served_digest).to eq("0123456789abcdef")
      expect(served_digest).not_to eq(config.dig(:settings, "digest"))
    end

    it "is offered and served for an older catalog, its header digest the page's, which the browser uses (AC-4.2)", :aggregate_failures do
      path = write("default-cards-1")
      create(:catalog_refresh_run, source_version: "default-cards-2")
      config = MTG::Art.page_config

      get scanner_art_index_path(config.fetch(:name))

      expect(config).to include(name: path.basename.to_s)
      expect(response).to have_http_status(:ok)
      expect(served_digest).to eq(config.dig(:settings, "digest"))
    end
  end
```

- [ ] **Task 4.3: run and check.** `bin/rspec spec/models/mtg/art/build_spec.rb spec/requests/scanner/art_indexes_spec.rb` — expect 0 failures. (Red evidence for AC-3.2 and AC-3.3 is the Phase 2 red run: before that code, `MTG::Art::Operation` reads `:ready` with no "Warning" fact where these examples expect `:out_of_date` and a warning. AC-4.1 and AC-4.2 are characterization examples, green from the start.)
- [ ] **Task 4.4: commit.** Stage both spec files; commit `test(art): building again clears the drift, and the scanner's two behaviours are pinned (#176)`.

---

## Phase 5: Integration verification and the documents

**Implements:** all FRs | **Satisfies:** AC-5.1, AC-5.2, AC-5.3, and every other AC by the run
**Files:** `docs/architecture/catalog-operations.md`, `docs/architecture/scanner.md`, `docs/specs/README.md`, `docs/specs/053-art-index-drift/verification.md`
**Interfaces:** Consumes: Phases 1–4. Produces: the area docs' current rules and the verification record.

- [ ] **Task 5.1: run the checks.** `bin/rubocop` and `bin/rspec spec/models/mtg spec/requests/admin spec/requests/scanner spec/tasks spec/admin_catalog_core_spec.rb` — expect 0 offenses, 0 failures. Then, with the coordinator's "ci slot", the full `bin/ci`; release the slot with the SHA and result.
- [ ] **Task 5.2: write `verification.md`** (`docs/specs/053-art-index-drift/verification.md`, modelled on spec 039's): a Red-then-green table per phase (commit SHAs and the failing example names from Tasks 1.2, 2.2, 3.2), the AC → evidence table (each AC to its example or document), the `bin/ci` run, and later the `## Implementation review` section with its verdict first.
- [ ] **Task 5.3: area docs (done by `distill-feature`, before the pull request is ready; the maintainer's ruling: "The catalog operations area doc is updated at distillation").** Read each document and make exactly the AC-5.1 and AC-5.2 edits, each new statement carrying its source inline (spec 053 criterion, decision or #176):
  - `docs/architecture/catalog-operations.md`: the art index panel table's "Finished, its index file on the volume" row gains the "Warning" fact for an older catalog and "at the current settings"; a new row "Finished, its index file on the volume, built with other settings" with the summary, the facts (finish time, file name, built-with and current settings, counts), button enabled unless a job is in flight, no meter, no Failed-list link, no polling, and "judged only once nothing is queued or running"; the status-line paragraph words both lines; the Glossary's "Ready (art index)" entry says what ready is judged by now; the accepted limit about older settings or catalog is reworded to the damaged file only, and a new open point: a release that changes the settings queues no rebuild, only a refresh does (maintainer's ruling, 2026-11-09); Sources gets #176 and spec 053.
  - `docs/architecture/scanner.md`: the digest paragraph and the art-status table's mismatch row say the admin page shows the refused index as out of date and an older catalog's index as a warning; the open-issues line for #176 is removed; Sources gets #176 and spec 053.
  - `docs/specs/README.md`: the 053 row's status word moves as the spec progresses (Approved → Shipped → Frozen by the area docs), and its Plan column becomes "retirement owed" at distillation; the three Superseded-by entries stay.
- [ ] **Task 5.4: commit.** `docs(art): the area docs and the verification record for spec 053 (#176)`.

---

## Quickstart Validation

1. `bin/rails "catalog:status[mtg]"` in a development instance with `COLLECTOR_MTG_ART_MATCHING=true` and a finished build: the art line reads "ready; …".
2. With a finished build row at another digest (in a console-free way: a request or model example, or by editing `config/art_fingerprint.json` in a scratch checkout and rebooting): `/admin/catalog` shows "Out of date. Built with other settings, so the scanner can't use it. Build the art index again." with an enabled **Build art index**, and `catalog:status[mtg]` reads "Art matching: out of date (…)". The scanner page at `/scanner` says "Artwork matching isn't available. The scanner is reading text only."
3. After a refresh applies a newer version with no rebuild: `/admin/catalog` shows "Ready." and a final "Warning" fact; the scanner page says "Artwork matching is on".
4. Press **Build art index**: both read plain "Ready." when it finishes.

(The examples of Phases 2–4 prove each of these without a browser; the scanner page's two messages are `spec/system/scanner_art_spec.rb`'s.)
