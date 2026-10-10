# Implementation Plan: Active Storage Variants with vips

**Spec:** docs/specs/014-active-storage-vips/spec.md (v1.1.0, Approved, reviewed twice: Fable Mode A, READY TO PLAN)
**Decisions:** [ADR 0013](../../adr/0013-active-storage-variants-with-vips.md) (libvips through `ruby-vips`, not auto-required), Accepted.
**Issue:** [#18](https://github.com/plainprogrammer/Collector/issues/18)
**Created:** 2026-10-09
**Approved:** 2026-10-09 (maintainer, after the review revision).
**Revised:** 2026-10-09, after a read-only plan review (Fable, READY TO EXECUTE; every block applied cleanly, red/green and RuboCop as stated). Applied:
- Phase 1's red-state wording for AC-2.2, which fails with a `LoadError`
- `|| fail` on the smoke check's runner call, so a non-zero exit fails loudly
- Phase 3's failure count, if Phase 4's example is added early
- memory housekeeping moved to after the merge, as the spec says
- the check's comment narrowed to a direct `bin/setup`

## Global Constraints

- `gem "ruby-vips", "~> 2.3", require: false`; keep `image_processing` (`~> 2.2`) and the `load_defaults` variant processor (`:vips`); never set `config.active_storage.variant_processor` (FR-1).
- The `Dockerfile`'s packages don't change; no `mini_magick`; the art decoder stays ImageMagick (FR-1, FR-2, Non-Goals).
- "libvips is available" means `ruby-vips` loads in the app's bundle, probed with `bundle exec ruby -e 'require "ruby-vips"'`, never a `vips` command (Terms, AC-3.4).
- A missing libvips never fails `bin/setup`, and the variant spec is never skipped or tagged out (FR-3).
- The Debian/Ubuntu package name is the same in the setup hint, the README and `ci.yml`: `libvips` (see Facts).
- Specs: explicit `:aggregate_failures` on multi-expectation examples; RuboCop clean under the project config.

## Context

**Facts established during planning (2026-10-09):**

- **The plan's code was run before it was written down.** Every code block below was drafted in the session scratchpad and run from the worktree with `bin/rspec` and `bin/rubocop` (the real `rails_helper` and config). The new Gemfile line was locked in a scratch copy of the `Gemfile` (`BUNDLE_GEMFILE=<scratch>/Gemfile`), so the worktree stayed untouched.
  - With the scratch bundle: the variant spec ran 3/3 and the libvips check spec 4/5. The fifth is the `bin/setup` shape example, which needs the edited `bin/setup` at `Rails.root`.
  - With the current bundle: 5 of those 8 fail, which is the red state Phases 1 and 2 start from.
  - The new examples in `spec/image_publishing_spec.rb` and `spec/readme_spec.rb` fail against today's files and pass against scratch copies of the edited `ci.yml`, `README.md`, `bin/image-smoke` and `bin/setup`.
  - RuboCop finds no offenses. The only report was `RSpec/DescribeClass` on the scratch copy of `image_publishing_spec.rb`, which the real path is excluded from.
  - `bash -n bin/image-smoke` and `ruby -c bin/setup` are clean.
- **`bundle lock` with `ruby-vips`** adds `ruby-vips (2.3.0)` (depending on `ffi (~> 1.12)` and `logger`) and `ffi 1.17.4` for `aarch64-linux-gnu`, `aarch64-linux-musl`, `arm-linux-gnu`, `arm-linux-musl`, `x86_64-linux-gnu` and `x86_64-linux-musl`, with checksums. `bundler-audit` on that lockfile: no vulnerabilities.
- **The setup check from a plain (non-Bundler) Ruby, as `bin/setup` runs it:** with the current bundle it returns the hint, because `ruby-vips` isn't bundled yet. With the scratch bundle it returns `nil`. libvips 8.18.3 is installed on this machine (`vips-8.18.3-2.fc44`; `vips-tools` isn't, so there's no `vips` command).
- **Ubuntu 24.04's package names** (`podman run ubuntu:24.04`, `apt-get install -s`): `libvips`, `libvips42` and `libvips42t64` all install `libvips42t64 8.15.1`. `libvips` is the name the `Dockerfile` already uses on Debian. So `ci.yml`, the hint and the README use `libvips`, which is portable across both.
- **Transformer API (activestorage 8.1.4):** `ActiveStorage.variant_transformer.new(transformations).transform(file, format:) { |output| … }` needs no blob or tables, and deletes its output `Tempfile` when the block returns, so the spec measures the image inside the block. `PngHelpers#png_bytes` (`spec/support/png_helpers.rb`) generates the 40×20 fixture, so no image file is committed.
- **Bundler 4.0.20:** `Bundler.definition.dependencies` gives `autorequire == []` for a `require: false` entry and `nil` for a default one.
- **RuboCop shaped the spec names.** `RSpec/DescribeClass` needs a constant, hence `RSpec.describe ActiveStorage, ".variant_transformer"`. `RSpec/SpecFilePathFormat` then needs the path to end `active_storage*variant_transformer*_spec.rb`, hence `spec/config/active_storage_variant_transformer_spec.rb`.
- **`bin/ci` runs `bin/setup --skip-server` first** (`config/ci.rb`), so in CI the libvips check runs after the apt step installs libvips.
- **The smoke check was simulated by the plan reviewer** with a fake runner under the same `set -euo pipefail`: healthy output passes, also with a leading log line; `0.1.0`-shaped output (the warning, then an empty line) fails with `FAIL: vips: variants can't use libvips:`; a runner exiting 7 fails with `FAIL: vips: bin/rails runner exited 7:`.
- **Not run during planning:**
  - Building an image with the new bundle, and running the new `bin/image-smoke` against `0.1.0`. The command preparing a scratch build context was declined, so both are evidence in Phase 4.
  - The `ci.yml` run, which happens on the draft PR (Phase 5).
- **Branch:** `014-active-storage-vips`, with the PRD, ADR, spec and memory commits (doc-first done).

**Plan decisions (not spelled out in the spec):**

- **No committed fixture:** the image is generated with `png_bytes` (FR-3 allows either).
- **Where the specs live:**
  - `spec/config/active_storage_variant_transformer_spec.rb` holds AC-2.1, AC-2.2 and AC-3.3, all about the app's Active Storage configuration.
  - `spec/lib/collector/libvips_check_spec.rb` holds AC-3.1, AC-3.2, AC-3.4 and AC-3.5's shape example.
  - The `ci.yml` and `bin/image-smoke` shape examples go into `spec/image_publishing_spec.rb`, and AC-4.1 into `spec/readme_spec.rb`.
- **The check's interface:** `Collector::LibvipsCheck.new(probe: callable).hint` returns the hint string, or `nil` when libvips is available. A probe returning false/nil or raising any `StandardError` counts as unavailable.
- **The smoke check is one `bin/rails runner` call.** It fails when the runner exits non-zero, when the combined output matches `requires the (ruby-vips gem|libvips library)`, or when no line is exactly `ActiveStorage::Transformers::Vips`. It prints the output on failure.

### Pre-implementation gates

- **Simplicity:**
  - One new class (`Collector::LibvipsCheck`), one new gem (with `ffi`, per ADR 0013).
  - Edits to `bin/setup`, `bin/image-smoke`, `ci.yml` and the README.
  - Nothing beyond the spec.
- **Anti-abstraction:** Active Storage's transformer is used directly; the check class exists only because the maintainer chose a testable unit (spec 1.1.0).
- **Integration-first:** each phase starts with its failing spec; the image behaviour is checked by `bin/image-smoke` itself, against a built image.

---

## Goal

Rails in the production image loads Active Storage's vips transformer without a warning, variants work in development and CI, `bin/setup` reports a missing libvips, and the smoke test and suite guard all of it.

---

## Phase 1: Bundle `ruby-vips` and prove variants work

**Implements:** FR-1, FR-3 (variant and bundle specs) | **Satisfies:** AC-2.1, AC-2.2, AC-2.4, AC-3.3
**Files:** `spec/config/active_storage_variant_transformer_spec.rb` (new), `Gemfile`, `Gemfile.lock`
**Interfaces:** Consumes: `PngHelpers#png_bytes(width, height) { |x, y| [r, g, b] }` (existing). Produces: `ruby-vips` in the bundle, not auto-required; `ActiveStorage.variant_transformer == ActiveStorage::Transformers::Vips` in every environment with libvips.

Locks the gem in and proves a real resize through Active Storage's own transformer, with no blobs or tables.

- [ ] Write the failing spec `spec/config/active_storage_variant_transformer_spec.rb`:

```ruby
require "rails_helper"

# Active Storage variants use libvips through ruby-vips (spec 014, ADR 0013). No blobs or tables are involved.
RSpec.describe ActiveStorage, ".variant_transformer" do
  it "is the vips transformer (AC-2.2)" do
    expect(described_class.variant_transformer).to eq(ActiveStorage::Transformers::Vips)
  end

  it "resizes an image with libvips (AC-2.1)" do
    source = Tempfile.create([ "variant", ".png" ], binmode: true)
    source.write(png_bytes(40, 20) { [ 200, 100, 50 ] })
    source.rewind
    size = nil
    # The transformer deletes its output when the block returns, so measure it inside.
    described_class.variant_transformer.new(resize_to_limit: [ 10, 10 ]).transform(source, format: "png") do |output|
      image = Vips::Image.new_from_file(output.path)
      size = [ image.width, image.height ]
    end
    expect(size).to eq([ 10, 5 ])
  ensure
    source&.close
    File.unlink(source.path) if source
  end

  it "comes from a ruby-vips that Bundler.require doesn't load, so the app boots without libvips (AC-3.3)" do
    dependency = Bundler.definition.dependencies.find { |candidate| candidate.name == "ruby-vips" }
    expect(dependency&.autorequire).to eq([])
  end
end
```

- [ ] Run: `bin/rspec spec/config/active_storage_variant_transformer_spec.rb`. Expect `3 examples, 3 failures`. AC-2.2 raises a `LoadError` naming the ruby-vips gem (from autoloading the expected constant `ActiveStorage::Transformers::Vips`), the resize raises `NoMethodError` on `nil`, and the dependency is `nil` instead of `[]`.
- [ ] Add the gem to the `Gemfile`, directly after the `image_processing` line:

```ruby
# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.2"
# Loaded by Active Storage when it sets up vips variants, so the app boots without libvips (ADR 0013)
gem "ruby-vips", "~> 2.3", require: false
```

- [ ] Run: `bundle install`. Expect `Gemfile.lock` to gain exactly the entries listed under Facts: `ruby-vips (2.3.0)`, six `ffi (1.17.4-…)` platform entries, `ruby-vips (~> 2.3)` under DEPENDENCIES, and their checksums. Check with `git diff --stat Gemfile.lock` and `git diff Gemfile.lock | grep '^[+-] ' | grep -v -E 'ffi|ruby-vips'`, which should print nothing.
- [ ] Run: `bin/rspec spec/config/active_storage_variant_transformer_spec.rb`. Expect `3 examples, 0 failures`.
- [ ] Run: `bin/bundler-audit`. Expect `No vulnerabilities found`.
- [ ] Commit (stage first, then commit separately; the pre-commit hook reads the command):
  - `git add Gemfile Gemfile.lock spec/config/active_storage_variant_transformer_spec.rb`
  - `feat(storage): process Active Storage variants with ruby-vips (014)`, with a body naming AC-2.1, AC-2.2, AC-3.3 and ADR 0013.

---

## Phase 2: `bin/setup` reports a missing libvips

**Implements:** FR-3 (libvips check) | **Satisfies:** AC-3.1, AC-3.2, AC-3.4, AC-3.5
**Files:** `spec/lib/collector/libvips_check_spec.rb` (new), `lib/collector/libvips_check.rb` (new), `bin/setup`
**Interfaces:** Consumes: `ruby-vips` in the bundle (Phase 1). Its default-probe example passes only once the gem is bundled. Produces: `Collector::LibvipsCheck.new(probe: -> { … }).hint`, which is `String` or `nil`; `Collector::LibvipsCheck::PROBE` and `::HINT`.

A stdlib-only class, `require_relative`d by `bin/setup` like `WorktreeSetup`, and autoloaded in the app (`config.autoload_lib`).

- [ ] Write the failing spec `spec/lib/collector/libvips_check_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Collector::LibvipsCheck do
  describe "#hint" do
    it "is nil when the probe succeeds (AC-3.1)" do
      expect(described_class.new(probe: -> { true }).hint).to be_nil
    end

    it "names libvips and both packages when the probe fails, exits non-zero or can't run (AC-3.2)", :aggregate_failures do
      [ -> { false }, -> { nil }, -> { raise Errno::ENOENT, "bundle" } ].each do |probe|
        expect(described_class.new(probe: probe).hint).to include("libvips", "sudo dnf install vips", "sudo apt install libvips")
      end
    end

    it "finds libvips with the default probe where it's installed, as in development and CI (AC-3.4)" do
      expect(described_class.new.hint).to be_nil
    end
  end

  it "probes by loading ruby-vips in the bundle, not with a vips command (AC-3.4)" do
    expect(described_class::PROBE).to eq([ "bundle", "exec", "ruby", "-e", 'require "ruby-vips"' ])
  end

  it "is what bin/setup runs, beside the ImageMagick check (AC-3.5)", :aggregate_failures do
    setup = Rails.root.join("bin/setup").read
    expect(setup).to include('require_relative "../lib/collector/libvips_check"', "Collector::LibvipsCheck.new.hint")
    expect(setup.index("Checking libvips")).to be > setup.index("Checking ImageMagick")
  end
end
```

- [ ] Run: `bin/rspec spec/lib/collector/libvips_check_spec.rb`. Expect `An error occurred while loading` with `NameError: uninitialized constant Collector::LibvipsCheck`.
- [ ] Create `lib/collector/libvips_check.rb`:

```ruby
module Collector
  # bin/setup's libvips check (spec 014, ADR 0013). libvips is available when ruby-vips loads in the app's bundle.
  # A direct bin/setup doesn't run under Bundler, so the default probe asks a bundled Ruby rather than requiring the
  # gem in this process, which could find a copy installed outside the bundle. Stdlib only.
  class LibvipsCheck
    PROBE = [ "bundle", "exec", "ruby", "-e", 'require "ruby-vips"' ].freeze
    HINT = "libvips isn't available, so Active Storage can't make image variants (ADR 0013). Install it " \
           "(e.g. `sudo dnf install vips` or `sudo apt install libvips`), then run bin/setup again.".freeze

    def initialize(probe: -> { system(*PROBE, out: File::NULL, err: File::NULL) })
      @probe = probe
    end

    # The hint to print, or nil when libvips is available.
    def hint
      HINT unless available?
    end

    private

    def available?
      @probe.call ? true : false
    rescue StandardError
      false
    end
  end
end
```

- [ ] Edit `bin/setup`. Add the `require_relative` after the `dev_port` one:

```ruby
require_relative "../lib/collector/dev_port"
require_relative "../lib/collector/libvips_check"
require_relative "../lib/collector/worktree_setup"
```

  Then add the check directly after the ImageMagick check's `end`:

```ruby
    puts "\n== Checking ImageMagick (art matching, ADR 0012) =="
    unless %w[magick convert].any? { |name| system(name, "-version", out: File::NULL, err: File::NULL) }
      puts "ImageMagick isn't installed. Install it (e.g. `sudo dnf install ImageMagick` or `sudo apt install imagemagick`): " \
           "the art matching specs and the art build need it."
    end

    puts "\n== Checking libvips (Active Storage variants, ADR 0013) =="
    libvips_hint = Collector::LibvipsCheck.new.hint
    puts libvips_hint if libvips_hint
```

- [ ] Run: `bin/rspec spec/lib/collector/libvips_check_spec.rb`. Expect `5 examples, 0 failures`.
- [ ] Run: `bin/rails zeitwerk:check`. Expect `All is good!`.
- [ ] Run: `bin/setup --skip-server`. Expect `== Checking libvips (Active Storage variants, ADR 0013) ==` followed directly by the next `==` heading, with no hint between them (AC-3.5's evidence). Keep the output for `verification.md`.
- [ ] Commit:
  - `git add lib/collector/libvips_check.rb spec/lib/collector/libvips_check_spec.rb bin/setup`
  - `feat(setup): report a missing libvips in bin/setup (014)`

---

## Phase 3: CI installs libvips; the README lists the system libraries

**Implements:** FR-3 (CI), FR-4 | **Satisfies:** AC-2.3 (file shape; the run is Phase 5), AC-4.1
**Files:** `spec/image_publishing_spec.rb`, `spec/readme_spec.rb`, `.github/workflows/ci.yml`, `README.md`
**Interfaces:** Consumes: nothing from earlier phases. Produces: the `ci` job installs `libvips` and `imagemagick` before `bin/ci`.

- [ ] Add to `spec/image_publishing_spec.rb`, inside `describe ".github/workflows/ci.yml"` and directly before the example `"grants packages: write only to the image and publish jobs (NFR Security)"`:

```ruby
    it "installs libvips and ImageMagick before bin/ci (spec 014 AC-2.3, FR-3)", :aggregate_failures do
      ci_steps = workflow.dig("jobs", "ci", "steps")
      install = ci_steps.index { |candidate| candidate["run"].to_s.include?("apt-get install") }
      expect(install).not_to be_nil
      expect(ci_steps[install]["run"].split).to include("libvips", "imagemagick")
      expect(install).to be < ci_steps.index { |candidate| candidate["run"] == "bin/ci" }
    end
```

- [ ] Add to `spec/readme_spec.rb`, directly before the example `"warns about the first-run admin before the deployment steps"`:

```ruby
  it "lists libvips and ImageMagick with their packages (spec 014 AC-4.1)", :aggregate_failures do
    requirements = readme[/^## Requirements\n.*?(?=^## )/m].to_s
    expect(requirements).to include("libvips", "sudo dnf install vips", "sudo apt install libvips")
    expect(requirements).to include("ImageMagick", "sudo dnf install ImageMagick", "sudo apt install imagemagick")
  end
```

- [ ] Run: `bin/rspec spec/image_publishing_spec.rb spec/readme_spec.rb`. Expect exactly these two failures, with the other examples passing (three, if Phase 4's example was added early): `installs libvips and ImageMagick before bin/ci` and `lists libvips and ImageMagick with their packages`.
- [ ] Edit `.github/workflows/ci.yml`. Replace the install step in the `ci` job:

```yaml
      - name: Install libvips (Active Storage variants, ADR 0013) and ImageMagick (art matching's decoder, ADR 0012)
        run: sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends libvips imagemagick
```

- [ ] Edit `README.md`. Replace the `## Requirements` list with:

```markdown
- Ruby 4.0.7 (see `.ruby-version`)
- SQLite is provided by the `sqlite3` gem; no separate database server is needed
- Firefox, for the system specs (run headless)
- libvips, for Active Storage image variants (ADR 0013): `sudo dnf install vips` on Fedora,
  `sudo apt install libvips` on Debian or Ubuntu. `bin/setup` says so when it's missing
- ImageMagick, for the card scanner's art index build (ADR 0012): `sudo dnf install ImageMagick`
  on Fedora, `sudo apt install imagemagick` on Debian or Ubuntu
```

- [ ] Run: `bin/rspec spec/image_publishing_spec.rb spec/readme_spec.rb`. Expect 0 failures.
- [ ] Commit:
  - `git add .github/workflows/ci.yml README.md spec/image_publishing_spec.rb spec/readme_spec.rb`
  - `ci: install libvips for the test job and list system libraries in the README (014)`

---

## Phase 4: The smoke test checks vips in the image

**Implements:** FR-2 | **Satisfies:** AC-1.1, AC-1.2, AC-1.3 (file shape; the run is Phase 5), AC-1.4
**Files:** `spec/image_publishing_spec.rb`, `bin/image-smoke`
**Interfaces:** Consumes: Phase 1's bundle, which goes into the image (Dockerfile `bundle install`). Produces: `bin/image-smoke` fails with `FAIL: vips: …` when the image logs a vips warning or lacks the vips transformer.

- [ ] Add to `spec/image_publishing_spec.rb`, as a new `describe` directly before `describe "compose.yaml" do`:

```ruby
  describe "bin/image-smoke" do
    it "checks that Active Storage variants use libvips without a warning (spec 014 AC-1.3, FR-2)" do
      expect(Rails.root.join("bin/image-smoke").read).to include(
        "bin/rails runner 'puts ActiveStorage.variant_transformer'", "requires the (ruby-vips gem|libvips library)",
        "ActiveStorage::Transformers::Vips")
    end
  end
```

- [ ] Run: `bin/rspec spec/image_publishing_spec.rb`. Expect 1 failure: `bin/image-smoke checks that Active Storage variants use libvips without a warning`.
- [ ] Edit `bin/image-smoke`. Add the check directly after the `collector:user` check (the end of `== operational tasks`):

```bash
echo "== Active Storage variants use libvips (spec 014)"
vips="$("$cli" exec "$name" bin/rails runner 'puts ActiveStorage.variant_transformer' 2>&1)" || fail "vips: bin/rails runner exited $?:"$'\n'"$vips"
if grep -qE "requires the (ruby-vips gem|libvips library)" <<<"$vips" || ! grep -qx "ActiveStorage::Transformers::Vips" <<<"$vips"; then
  fail "vips: variants can't use libvips:"$'\n'"$vips"
fi
```

- [ ] Run: `bin/rspec spec/image_publishing_spec.rb`. Expect 0 failures.
- [ ] Run: `bash -n bin/image-smoke`. Expect no output.
- [ ] Build and smoke the image locally for amd64 (AC-1.1, AC-1.2). Expect the last line `OK: collector:vips passed the smoke test`, with `== Active Storage variants use libvips (spec 014)` among the headings.
  - `podman build -t collector:vips .`
  - `bin/image-smoke collector:vips`
- [ ] Run the new smoke test against the published release from before this feature (AC-1.4). Expect it to pass every check up to `== Active Storage variants use libvips (spec 014)`, then end with `FAIL: vips: variants can't use libvips:`, followed by the runner output containing `requires the ruby-vips gem`, and exit status 1.
  - `podman pull ghcr.io/plainprogrammer/collector:0.1.0`
  - `bin/image-smoke ghcr.io/plainprogrammer/collector:0.1.0`
- [ ] Keep both outputs for `verification.md`.
- [ ] Commit:
  - `git add bin/image-smoke spec/image_publishing_spec.rb`
  - `test(image): smoke-check that the image's variants use libvips (014)`

---

## Phase 5: Integration verification

**Implements:** All FRs | **Satisfies:** all ACs; evidence for AC-1.1–AC-1.4, AC-2.3, AC-2.4 and AC-3.5
**Files:** `docs/specs/014-active-storage-vips/verification.md` (new); after the merge, `.claude/memory/spec-012-followups.md`, `.claude/memory/dev-machine-image-tools.md`, `.claude/memory/MEMORY.md`

- [ ] Run: `bin/ci`. Expect every step to pass, with the RSpec step at 0 failures (AC-2.4).
- [ ] Write `docs/specs/014-active-storage-vips/verification.md` with one row per AC. Each row gives its evidence: the spec example, the file-shape example, or the command output from Phases 2 and 4 and this phase.
- [ ] Commit:
  - `git add docs/specs/014-active-storage-vips/verification.md`
  - `docs(014): record the verification evidence`
- [ ] Push the branch and open a **draft** PR (CI runs only on PRs and `main`). Its body says `Closes #18`, and ends with the attribution line. Expect:
  - the `ci` job's install step to install `libvips42t64` and `bin/ci` to pass (AC-2.3)
  - both `Image (linux/amd64)` and `Image (linux/arm64)` jobs to pass `Smoke test`, with the vips heading in the log (AC-1.3)
- [ ] Add the run's URL to `verification.md`, then commit:
  - `git add docs/specs/014-active-storage-vips/verification.md`
  - `docs(014): link the CI run evidence`
- [ ] **After the PR merges** (the spec's Delivery note), memory housekeeping:
  - remove the ruby-vips item from `.claude/memory/spec-012-followups.md`, noting it's done by spec 014, and drop "ruby-vips" from that memory's description in `MEMORY.md`. The index entry stays.
  - correct `.claude/memory/dev-machine-image-tools.md`: libvips 8.18.3 is installed, and `ruby-vips` and `ffi` are in the bundle with `image_processing` 2.2.0
  - commit: `git add .claude/memory/spec-012-followups.md .claude/memory/dev-machine-image-tools.md .claude/memory/MEMORY.md`, then `chore(memory): record spec 014's vips follow-up as done`

---

## Quickstart Validation

```sh
bundle install
bin/rspec spec/config/active_storage_variant_transformer_spec.rb spec/lib/collector/libvips_check_spec.rb
bin/setup --skip-server | grep -A1 "Checking libvips"        # the next line is a "==" heading, not a hint
podman build -t collector:vips . && bin/image-smoke collector:vips   # ends "OK: collector:vips passed the smoke test"
bin/ci
```
