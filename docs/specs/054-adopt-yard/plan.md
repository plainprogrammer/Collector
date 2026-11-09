# Implementation Plan: Browsable API Documentation for the Ruby Code, with the Area Docs and ADRs Linked In (YARD)

**Spec:** docs/specs/054-adopt-yard/spec.md (v1.2.1, approved 2026-11-09 under the maintainer's rulings OD1–OD3)
**Decisions:** [ADR 0027](../../adr/0027-yard-for-api-documentation.md) (Proposed, accepted with this plan's approval)
**Created:** 2026-11-09

## Global Constraints

Copied from the spec; every phase includes them.

- The image is public: `doc/`, `.yardoc/`, `.yardopts`, `bin/yard` and `script/yard/` are never in it. `yard` is in the `:development` group only, `require: false`; the `Dockerfile` is not edited (Story 3, FR-4).
- `Gemfile` is edited by hand and `bundle install` run; never `bundle add`.
- The area docs, the ADRs and every other shipped document keep their relative links and are never rewritten on disk (FR-3, AC-1.7). No shipped spec is edited, spec 027 included (AC-4.7).
- The app never loads the extension and never requires `yard` (AC-3.7): the extension is `script/yard/links.rb`, outside `app/` and `lib/`.
- Comments: only the three that warn and the one worked-example `@see` change (Non-Goals). Existing "spec NNN AC-x" comments stay.
- Test files: `type:` tags explicit, `:aggregate_failures` on multi-expectation examples, no `any_instance_of`, no sleeps (`.claude/rules/testing.md`). Prose documents are checked by reading, recorded in `verification.md`, never from RSpec.
- Commits: one Conventional Commit per task, ending with the `Co-Authored-By:` line of the model that made it. Stage and commit in separate Bash calls. Hooks run RuboCop and Brakeman before a commit; a Ruby edit runs `bin/rubocop -a` on the file.
- `bin/yard doc` is the one command; the options live in `.yardopts` (FR-1).

---

## Goal

`bin/yard doc` builds a browsable site of the classes in `app/` and `lib/` with the area docs and numbered ADRs as pages (the area map as the front page), with working links between pages, no warnings on the current code, and a `bin/ci checks` step that fails on a warning; nothing generated is committed, and nothing that builds it is in the image.

---

## Phase 1: The command, the ignore rules and a clean build

**Implements:** FR-1, FR-4 | **Satisfies:** AC-1.1, AC-1.2, AC-1.4, AC-1.8, AC-2.1, AC-2.4, AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.5, AC-3.6 (in CI)
**Files:** `Gemfile`, `Gemfile.lock`, `bin/yard`, `.yardopts`, `.gitignore`, `.dockerignore`, `bin/image-smoke`, `app/models/scanner/measurement_run.rb`, `lib/collector/ghcr_cleanup.rb` (and the other file YARD names), `spec/image_publishing_spec.rb`, `spec/project_config_spec.rb`
**Interfaces:** Consumes: nothing. Produces: `bin/yard` (a binstub that runs `yard` under Bundler), `.yardopts` (the one definition of the site), the ignore rules of Story 3.

- [ ] **Task 1.1: write the failing configuration examples.**

In `spec/image_publishing_spec.rb`, inside `describe ".dockerignore"`, after the example "keeps the CI tooling out of the image, and the image smoke test checks it", add:

```ruby
    it "keeps YARD's output, cache, options, binstub and extension out of the image, and the image smoke test checks them (spec 054 Story 3)", :aggregate_failures do
      builders = %w[doc .yardoc .yardopts bin/yard]
      absent = Rails.root.join("bin/image-smoke").read[/for path in (.+); do/, 1].split

      expect(rules).to include(*builders.map { "/#{it}" })
      expect(absent).to include(*builders)
      # The extension lives in script/, which the rules and the smoke list already hold out (AC-3.2, AC-3.3).
      expect(Rails.root.join("script/yard/links.rb").to_s).to start_with(Rails.root.join("script").to_s)
      expect(rules).to include("/script")
      expect(absent).to include("script")
    end
```

In `spec/project_config_spec.rb`, before the file's last `end`, add:

```ruby

  describe "YARD (spec 054)" do
    it "ignores the generated site and its cache (AC-3.1)", :aggregate_failures do
      expect(git_ignored?("doc/index.html")).to be(true)
      expect(git_ignored?(".yardoc/checksums")).to be(true)
    end

    it "is a development-only gem that nothing requires, which the image's bundle leaves out (AC-3.4, AC-3.5)", :aggregate_failures do
      yard = Bundler.definition.dependencies.find { it.name == "yard" }

      expect(yard.groups).to eq([ :development ])
      expect(yard.autorequire).to eq([])
      expect(Rails.root.join("Dockerfile").read).to include('BUNDLE_WITHOUT="development"')
    end
  end
```

Run: `bin/rspec spec/image_publishing_spec.rb spec/project_config_spec.rb`
Expected: the three new examples fail (no `/doc` rule, `doc/index.html` not ignored, no `yard` dependency: `undefined method 'groups' for nil`).

- [ ] **Task 1.2: add the gem, the binstub, the options and the ignore rules.**

`Gemfile`: replace

```ruby
group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end
```

with

```ruby
group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # API documentation from the code's comments, with the area docs and ADRs as pages (spec 054, ADR 0027). Development
  # only: the image's bundle leaves this group out.
  gem "yard", require: false
end
```

Run `bundle install` (never `bundle add`); `Gemfile.lock` gains `yard`. Run `bin/bundler-audit`; expected: no vulnerabilities.

Create `bin/yard` (then `chmod +x bin/yard`):

```ruby
#!/usr/bin/env ruby
# Generates the API documentation: bin/yard doc (spec 054, ADR 0027). Options are in .yardopts.
require "rubygems"
require "bundler/setup"

load Gem.bin_path("yard", "yard")
```

Create `.yardopts` (one option per line; YARD expands the globs itself):

```
--markup markdown
--output-dir doc
--readme docs/architecture/README.md
--title Collector
--fail-on-warning
app/**/*.rb
lib/**/*.rb
--files docs/architecture/*.md,docs/adr/0*.md
```

`.gitignore`: after the `# Ignore test coverage reports.` block (`/coverage/`), add:

```
# The generated API documentation and its cache (spec 054, bin/yard doc).
/doc/
/.yardoc/
```

`.dockerignore`: after the `/lib/collector/push_scope.rb` line at the end, add:

```

# The API documentation: the generated site, its cache, its options and its binstub run only on a checkout and in CI
# (spec 054). The extension that fixes the site's links is in /script, which is already left out. `yard` itself is in the
# development group, which the image's bundle leaves out.
/doc
/.yardoc
/.yardopts
/bin/yard
```

`bin/image-smoke`: in the `for path in …; do` line of the "development-only paths and secrets must be absent" block, append `doc .yardoc .yardopts bin/yard` after `lib/collector/push_scope.rb`, so it reads `… lib/collector/ci_shard.rb lib/collector/push_scope.rb doc .yardoc .yardopts bin/yard; do`.

Run: `bin/rspec spec/image_publishing_spec.rb spec/project_config_spec.rb`
Expected: all pass.

- [ ] **Task 1.3: fix the comments that warn.**

Run `bin/yard doc --no-cache 2>&1 | grep -A1 warn`. Expected: the warnings the spike found (`app/models/scanner/measurement_run.rb:4`, `lib/collector/ghcr_cleanup.rb:107` and `:120`), and the run exits non-zero (`--fail-on-warning`). Fix each at the file and line YARD names, keeping each comment's meaning:

- `app/models/scanner/measurement_run.rb` lines 4–5 (the layout lines): put the layout in backticks so Markdown renders it as code and `{name,collector}`, `<dir>` and `foil[,era]` are not read as a link, a tag or a reference link. Replace

```ruby
# A measured run of the card scanner (spec 007 Story 5): the manifest of known cards (spec 005's format,
# file,set,number,foil[,era]) and what each live capture read, stored in a directory outside the
# repository. The first capture of a row is the measured one; later ones are retakes (AC-5.4).
# Layout: <dir>/<file>/capture-NNN.json, capture-NNN-{name,collector}.png (and capture-NNN-frame.png, spec 010), skipped.json;
# <dir>/replays/<label>.json.
```

with

```ruby
# A measured run of the card scanner (spec 007 Story 5): the manifest of known cards (spec 005's format,
# `file,set,number,foil[,era]`) and what each live capture read, stored in a directory outside the
# repository. The first capture of a row is the measured one; later ones are retakes (AC-5.4).
# Layout: `<dir>/<file>/capture-NNN.json`, `capture-NNN-name.png` and `capture-NNN-collector.png` (and
# `capture-NNN-frame.png`, spec 010), `skipped.json`; `<dir>/replays/<label>.json`.
```

- `lib/collector/ghcr_cleanup.rb`: line 120 reads `# Every page, by number on the /users/ path; the Link header points at a /user/{id}/ path (FR-3).`; put the paths in backticks (`` `/users/` `` and `` `/user/{id}/` ``). Run `bin/yard doc --no-cache 2>&1 | grep -A1 warn` again: the warning at `:107` names the object whose comment is at that line; open the file at that line and fix the `{…}` YARD reads as a link the same way (backticks, or the braces dropped).

Run: `bin/yard doc --no-cache; echo "exit=$?"`
Expected: no `[warn]` line, `exit=0`, `doc/index.html` exists (AC-1.1, AC-2.1). Run it a second time without `--no-cache`: the same (AC-1.8). Run `git status --short`: only the intended files; `doc/` and `.yardoc/` don't show (AC-1.1, AC-2.4, AC-3.1).

Check AC-1.2 and AC-1.4 by reading `doc/index.html` (the area map) and `doc/class_list.html`, and compare the object counts of `bin/yard stats` (it prints Files, Modules, Classes) with the class list; record them for `verification.md`.

- [ ] **Task 1.4: commit.** `bin/rubocop` (Ruby files) must pass. Stage `Gemfile Gemfile.lock bin/yard .yardopts .gitignore .dockerignore bin/image-smoke app/models/scanner/measurement_run.rb lib/collector/ghcr_cleanup.rb spec/image_publishing_spec.rb spec/project_config_spec.rb` (and any other file the third task changed), then commit `feat(docs): generate the Ruby API documentation with YARD (#103)`.

---

## Phase 2: The CI step

**Implements:** FR-2 | **Satisfies:** AC-2.2, AC-2.3, AC-2.5, AC-2.6, AC-2.8
**Files:** `config/ci.rb`, `spec/config/ci_definition_spec.rb`
**Interfaces:** Consumes: `bin/yard doc` of Phase 1 (`--fail-on-warning` is in `.yardopts`). Produces: the step "Docs: YARD builds without warnings".

- [ ] **Task 2.1: write the failing example.** In `spec/config/ci_definition_spec.rb`, after the example "prints the 10 slowest examples…", add:

```ruby

  it "runs YARD in bin/ci checks, after the style step and not with the RSpec group, and never reads its cache (spec 054 AC-2.3, AC-2.8)", :aggregate_failures do
    lines = Rails.root.join("config/ci.rb").readlines(chomp: true).map(&:strip)
    yard = lines.index('step "Docs: YARD builds without warnings", "bin/yard doc --no-cache"')

    expect(yard).not_to be_nil
    expect(yard).to be > lines.index('step "Style: Ruby", "bin/rubocop"')
    expect(yard).to be > lines.index("unless selection.group == :rspec")
    expect(yard).to be < lines.index { it.start_with?('step "Tests: RSpec"') }
  end
```

Run: `bin/rspec spec/config/ci_definition_spec.rb`. Expected: the new example fails (`expected: not nil, got: nil`).

- [ ] **Task 2.2: add the step.** In `config/ci.rb`, in the `unless selection.group == :rspec` block, after the Ruby style step line, add:

```ruby
    step "Docs: YARD builds without warnings", "bin/yard doc --no-cache"
```

so the block reads `… step "Style: Ruby", "bin/rubocop"`, then this line, then the Brakeman step.

Run: `bin/rspec spec/config/ci_definition_spec.rb`. Expected: pass.

- [ ] **Task 2.3: prove the step fails on a bad comment, and not otherwise (AC-2.2, AC-2.6, AC-2.8).**

1. Run `bin/yard doc` once (writes `.yardoc/`), `echo "exit=$?"`; expected `exit=0`.
2. Add a deliberately bad tag to a comment: in `app/models/lot.rb`, directly above the line `class Lot < ApplicationRecord` (check the first line of the class with `grep -n "^class Lot" app/models/lot.rb`), insert two lines `# See {nothing_here}.` and `# @param`.
3. Run `bin/yard doc --no-cache; echo "exit=$?"`. Expected: `[warn]` lines naming `app/models/lot.rb` with its line, and `exit=1`.
4. Run `bin/ci checks`. Expected: the step "Docs: YARD builds without warnings" fails with those lines in its output, and `bin/ci` exits non-zero (AC-2.2, AC-2.6); the `.yardoc/` of step 1 is still there, so the failure also shows AC-2.8: the step's `--no-cache` makes YARD parse the file again instead of reusing the clean parse in `.yardoc/`.
5. Revert with `git checkout app/models/lot.rb`; run `bin/ci checks`; expected: it passes, with the step's time in its output (record it for AC-2.5; it must be at most 30 s).

Record each output in `verification.md`. `git status --short` must show no change to `app/models/lot.rb`.

- [ ] **Task 2.4: commit.** Stage `config/ci.rb spec/config/ci_definition_spec.rb`; commit `ci: fail bin/ci checks on a YARD warning (#103)`.

---

## Phase 3: The links of the included pages

**Implements:** FR-3 | **Satisfies:** AC-1.3, AC-1.5, AC-1.6, AC-1.7, AC-2.7, AC-3.7
**Files:** `script/yard/links.rb`, `.yardopts`, `spec/script/yard/links_spec.rb`, `spec/script/yard/site_spec.rb`, `spec/fixtures/yard_site/` (new)
**Interfaces:** Consumes: `.yardopts` of Phase 1; YARD's `YARD::CodeObjects::ExtraFileObject#initialize(filename, contents = nil)`, `#contents`, `#filename`, `#name`; `YARD::Logger.instance.warn`. Produces: `YardLinks::Rewriter.new(root:, pages:, warn:)` and `#rewrite(text, from:)` (String), `YardLinks.slug(text)` and `YardLinks.yard_id(text)` (String), the hook that loads them into YARD.

The behaviour of a page's link (spec 054 decision 6): a relative link to another page of the site becomes `file.<name>.html` plus its fragment mapped to YARD's heading id; any other relative link becomes `https://github.com/plainprogrammer/Collector/blob/main/<path>` (`tree` for a directory); an absolute URL or an in-page anchor is unchanged; a link to a missing file, or to a heading the page doesn't have, is a warning. Fenced code isn't touched.

- [ ] **Task 3.1: write the failing unit examples.** Create `spec/script/yard/links_spec.rb`:

```ruby
require "rails_helper"
require "tmpdir"
require Rails.root.join("script/yard/links").to_s

# The extension that makes the links of YARD's Markdown pages work (spec 054 FR-3, decision 6). The pure rewriting is
# here; spec/script/yard/site_spec.rb runs it inside a real YARD run.
RSpec.describe YardLinks::Rewriter, type: :model do
  let(:root) { Pathname(Dir.mktmpdir) }
  let(:pages) { { "docs/architecture/a.md" => "a", "docs/adr/0001-x.md" => "0001-x" } }
  let(:warnings) { [] }
  let(:rewriter) { described_class.new(root:, pages:, warn: ->(message) { warnings << message }) }

  before do
    { "docs/architecture/a.md" => "# A\n\n## Option A: The `VACUUM INTO` step\n\n```\n# Not a heading\n```\n",
      "docs/adr/0001-x.md" => "# 0001\n\n## Consequences\n",
      "docs/releasing.md" => "# Releasing\n\n## What each trigger publishes\n",
      "docs/design-system/README.md" => "# DS\n" }.each do |path, body|
      root.join(path).dirname.mkpath
      root.join(path).write(body)
    end
  end

  after { FileUtils.remove_entry(root) }

  def rewrite(target, from: "docs/architecture/a.md") = rewriter.rewrite("See [x](#{target}).", from:)

  it "maps a link to another page of the site to its page, with a fragment mapped to YARD's heading id (AC-1.5)", :aggregate_failures do
    expect(rewrite("../adr/0001-x.md")).to eq("See [x](file.0001-x.html).")
    expect(rewrite("../adr/0001-x.md#consequences")).to eq("See [x](file.0001-x.html#Consequences).")
    expect(rewrite("../architecture/a.md#option-a-the-vacuum-into-step", from: "docs/adr/0001-x.md")).to eq("See [x](file.a.html#Option_A__The__VACUUM_INTO__step).")
  end

  it "sends a link to anything else to GitHub's main branch, keeping its fragment (AC-1.6)", :aggregate_failures do
    expect(rewrite("../releasing.md#what-each-trigger-publishes"))
      .to eq("See [x](https://github.com/plainprogrammer/Collector/blob/main/docs/releasing.md#what-each-trigger-publishes).")
    expect(rewrite("../design-system/")).to eq("See [x](https://github.com/plainprogrammer/Collector/tree/main/docs/design-system).")
  end

  it "leaves absolute URLs and in-page anchors alone", :aggregate_failures do
    expect(rewrite("https://example.com/a.md")).to eq("See [x](https://example.com/a.md).")
    expect(rewrite("#glossary")).to eq("See [x](#glossary).")
    expect(warnings).to be_empty
  end

  it "warns about a link to a file that doesn't exist and leaves it as written (AC-2.7)", :aggregate_failures do
    expect(rewrite("missing.md")).to eq("See [x](missing.md).")
    expect(rewrite("../../../outside.md")).to eq("See [x](../../../outside.md).")
    expect(warnings.size).to eq(2)
    expect(warnings.first).to include("docs/architecture/a.md", "missing.md", "doesn't exist")
  end

  it "warns about a fragment that names no heading, once however often the page is rendered" do
    2.times { rewrite("../adr/0001-x.md#nope") }

    expect(warnings.size).to eq(1)
    expect(warnings.first).to include("0001-x.md#nope", "heading")
  end

  it "doesn't touch a link inside a fenced code block" do
    text = "```\n[x](missing.md)\n```\n"

    expect(rewriter.rewrite(text, from: "docs/architecture/a.md")).to eq(text)
    expect(warnings).to be_empty
  end

  it "does not count a '#' line in a fenced block as a heading" do
    rewrite("a.md#not-a-heading")

    expect(warnings.size).to eq(1)
  end

  describe ".slug and .yard_id" do
    it "give GitHub's anchor and YARD's id of a heading", :aggregate_failures do
      expect(YardLinks.slug("Option A: The `VACUUM INTO` step")).to eq("option-a-the-vacuum-into-step")
      expect(YardLinks.yard_id("Option A: The `VACUUM INTO` step")).to eq("Option_A__The__VACUUM_INTO__step")
      expect(YardLinks.yard_id("A workflow run (`ci.yml`)")).to eq("A_workflow_run___ci_yml__")
    end
  end
end
```

Run: `bin/rspec spec/script/yard/links_spec.rb`. Expected: fails to load (`cannot load such file -- …/script/yard/links`).

- [ ] **Task 3.2: write the rewriter.** Create `script/yard/links.rb`:

```ruby
# Makes the links of the Markdown pages in YARD's site work (spec 054 FR-3, decision 6, ADR 0027). The area docs and ADRs
# keep plain relative links for GitHub; at generation this rewrites them in the text a page is rendered from, never on
# disk: a link to another page of the site becomes that page, any other relative link becomes the file on GitHub's main
# branch, and a link to a file or heading that doesn't exist is a warning (so `bin/yard doc` fails). Loaded by
# .yardopts (`--load`); the app never loads it (it is outside app/ and lib/). Standard library only, apart from the hook
# at the end, which needs YARD.
require "pathname"

module YardLinks
  GITHUB = "https://github.com/plainprogrammer/Collector".freeze
  TARGET = /(?<=\]\()([^)\s]+)(?=\))/ # the target of an inline Markdown link: ](target)
  HEADING = /\A[#]{1,6}\s+(.+?)\s*\z/

  # GitHub's anchor for a heading: lower case, punctuation dropped, spaces as hyphens.
  def self.slug(text) = text.downcase.gsub(/[^\p{Alnum}\s_-]/, "").gsub(/\s/, "-")

  # YARD's id for a heading: every character that isn't a letter or digit becomes an underscore, so
  # "A workflow run (`ci.yml`)" is "A_workflow_run___ci_yml__".
  def self.yard_id(text) = text.gsub(/[^A-Za-z0-9]/, "_")

  class Rewriter
    # root: the repository's directory; pages: { "docs/architecture/a.md" => "a" }, each page's path and the name YARD
    # gives its file (a live hash: YARD adds to it as it reads the file list); warn: called with a message.
    def initialize(root:, pages:, warn:)
      @root = Pathname(root).expand_path
      @pages = pages
      @warn = warn
      @warned = {}
      @headings = {}
    end

    # text: a page's Markdown; from: that page's path in the repository.
    def rewrite(text, from:)
      fenced = false
      text.each_line.map do |line|
        fenced = !fenced if line.lstrip.start_with?("```")
        fenced ? line : line.gsub(TARGET) { rewrite_target(Regexp.last_match(1), from) }
      end.join
    end

    private

    def rewrite_target(target, from)
      return target if target.start_with?("#") || target.match?(/\A[a-z][a-z0-9+.-]*:/i)

      path, fragment = target.split("#", 2)
      resolved = (Pathname(from).dirname + path).cleanpath.to_s
      if resolved.start_with?("..") || !@root.join(resolved).exist?
        warn_once(from, target, "the link #{target} points at #{resolved}, which doesn't exist")
        return target
      end

      if (name = @pages[resolved])
        "file.#{name}.html#{page_anchor(resolved, fragment, from, target)}"
      else
        kind = @root.join(resolved).directory? ? "tree" : "blob"
        "#{GITHUB}/#{kind}/main/#{resolved}#{"##{fragment}" if fragment}"
      end
    end

    def page_anchor(page, fragment, from, target)
      return "" unless fragment

      id = headings(page)[fragment]
      return "##{id}" if id

      warn_once(from, target, "the link #{target} names a heading that #{page} doesn't have")
      "##{fragment}"
    end

    # GitHub's anchor => YARD's id, for each heading of a page outside fenced code (the first of equal anchors wins).
    def headings(page)
      @headings[page] ||= begin
        fenced = false
        @root.join(page).each_line.with_object({}) do |line, found|
          fenced = !fenced if line.lstrip.start_with?("```")
          next if fenced || !(match = line.match(HEADING))

          found[YardLinks.slug(match[1])] ||= YardLinks.yard_id(match[1])
        end
      end
    end

    # A page is read more than once (its contents are asked for again), a warning is said once.
    def warn_once(from, target, message)
      @warned[[ from, target ]] ||= @warn.call("#{from}: #{message}") || true
    end
  end
end
```

Run: `bin/rspec spec/script/yard/links_spec.rb`. Expected: pass. Run `bin/rubocop script/yard/links.rb spec/script/yard/links_spec.rb` and fix style offenses (the hook autocorrects on edit).

- [ ] **Task 3.3: write the failing site example, over a real YARD run.** Create the fixture `spec/fixtures/yard_site/` with `lib/thing.rb`:

```ruby
# A thing, which the area doc explains.
#
# @see file:alpha.md
class Thing; end
```

`docs/alpha.md`:

```markdown
# Alpha

## Option A: The `VACUUM INTO` step

See [beta](beta.md#what-it-keeps), [the releasing notes](outside.md#what-each-trigger-publishes) and
[the web](https://example.com/page).
```

`docs/beta.md`:

```markdown
# Beta

## What it keeps

Back to [alpha](alpha.md#option-a-the-vacuum-into-step).
```

`docs/outside.md`:

```markdown
# Outside

## What each trigger publishes
```

(`outside.md` is on disk but not a page of the fixture's site.) Create `spec/script/yard/site_spec.rb`:

```ruby
require "rails_helper"
require "open3"
require "tmpdir"

# A real `yard doc` over a small fixture with the extension loaded (spec 054 FR-3: AC-1.5, AC-1.6, AC-1.7, AC-2.7, AC-1.9).
# Slower than the unit examples (about 3 s), so it holds the end-to-end checks: that the hook is reached, that a mapped
# fragment is an id the target page has, and that a dead link fails the run.
RSpec.describe "The extension in a YARD run", type: :model do
  let(:fixture) { Rails.root.join("spec/fixtures/yard_site") }
  let(:extension) { Rails.root.join("script/yard/links.rb").to_s }

  def yard(*args, out:)
    Open3.capture3(Rails.root.join("bin/yard").to_s, "doc", "--no-save", "--fail-on-warning", "--markup", "markdown",
                   "--output-dir", out, "--load", extension, "--files", "docs/*.md", "lib/**/*.rb", *args, chdir: fixture.to_s)
  end

  def page(out, name) = File.read(File.join(out, "file.#{name}.html"))

  it "links the pages to each other, at ids the target has, and the rest to GitHub", :aggregate_failures do
    Dir.mktmpdir do |out|
      _stdout, stderr, status = yard(out:)

      expect(status).to be_success, stderr
      alpha = page(out, "alpha")
      beta = page(out, "beta")
      expect(alpha).to include('href="file.beta.html#What_it_keeps"')
      expect(beta).to include('id="What_it_keeps"')
      expect(beta).to include('href="file.alpha.html#Option_A__The__VACUUM_INTO__step"')
      expect(alpha).to include('id="Option_A__The__VACUUM_INTO__step"')
      expect(alpha).to include('href="https://github.com/plainprogrammer/Collector/blob/main/docs/outside.md#what-each-trigger-publishes"')
      expect(alpha).to include('href="https://example.com/page"')
    end
  end

  it "renders a class comment's @see file: as a link to the page, with no warning (AC-1.9)", :aggregate_failures do
    Dir.mktmpdir do |out|
      _stdout, stderr, status = yard(out:)

      expect(status).to be_success, stderr
      expect(File.read(File.join(out, "Thing.html"))).to include('href="file.alpha.html"')
    end
  end

  it "leaves the documents on disk as they were (AC-1.7)" do
    Dir.mktmpdir do |out|
      before = Dir[fixture.join("docs/*.md")].to_h { [it, File.read(it)] }
      yard(out:)

      expect(Dir[fixture.join("docs/*.md")].to_h { [it, File.read(it)] }).to eq(before)
    end
  end

  it "fails the run, naming the page and the link, when a link points at a missing file (AC-2.7)", :aggregate_failures do
    Dir.mktmpdir do |dir|
      docs = Pathname(dir).join("docs")
      docs.mkpath
      docs.join("bad.md").write("# Bad\n\nSee [nothing](missing.md).\n")
      stdout, stderr, status = Open3.capture3(Rails.root.join("bin/yard").to_s, "doc", "--no-save", "--fail-on-warning",
                                              "--markup", "markdown", "--output-dir", Pathname(dir).join("out").to_s,
                                              "--load", extension, "--files", "docs/*.md", chdir: dir)

      expect(status).not_to be_success
      expect(stdout + stderr).to include("docs/bad.md", "missing.md", "doesn't exist")
    end
  end
end
```

The fixture is run from its own directory, so `outside.md` is at `docs/outside.md` of that run's root, and that is the path in the GitHub URL.

Run: `bin/rspec spec/script/yard/site_spec.rb`. Expected: fails (YARD doesn't load the extension's hook yet: `href="beta.md#what-it-keeps"` is not rewritten, and `bin/yard` exits 0 for the missing-file case).

- [ ] **Task 3.4: add the hook.** Append to `script/yard/links.rb` (after the closing `end` of `module YardLinks`):

```ruby

# The hook: only when YARD loads this file (`--load`); the unit specs load the file without YARD.
if defined?(YARD::CodeObjects::ExtraFileObject)
  module YardLinks
    class << self
      # The pages of the site: path in the repository => the name YARD gives its file. YARD builds a file object for
      # each page before it renders any, so the map is complete by the time contents are asked for.
      def pages = (@pages ||= {})

      def rewriter
        @rewriter ||= Rewriter.new(root: Dir.pwd, pages:, warn: ->(message) { YARD::Logger.instance.warn(message) })
      end
    end

    module ExtraFileHook
      def initialize(filename, contents = nil)
        super
        YardLinks.pages[repository_path] = name
      end

      def contents
        text = super
        text && YardLinks.rewriter.rewrite(text, from: repository_path)
      end

      private

      def repository_path = Pathname(filename).expand_path.relative_path_from(Pathname(Dir.pwd)).to_s
    end
  end

  YARD::CodeObjects::ExtraFileObject.prepend(YardLinks::ExtraFileHook)
end
```

Then run `bin/rspec spec/script/yard`. Expected: pass. If the page map is incomplete when `contents` is first asked for (a link to a page of the site goes to GitHub instead), the file object for that page was created after the first render; in that case build the map from `YARD::CLI::Yardoc` instead (stop and ask the coordinator; do not guess).

- [ ] **Task 3.5: load it in the real run and check the real docs.** Add to `.yardopts`, after `--fail-on-warning`:

```
--load script/yard/links.rb
```

Run: `bin/yard doc --no-cache; echo "exit=$?"`. Expected: no `[warn]` line, `exit=0` (AC-1.1, AC-1.3, AC-2.7: none of the 389 relative links of the area docs and ADRs is dead on disk, the spike checked). Then check, and record in `verification.md`:

1. `ls doc | grep -c '^file\.'` is 33 (7 area docs, including `README`, and 26 ADRs; `file.0027-…` makes it 34 once ADR 0027 is on disk: count what exists with `ls docs/adr/0*.md docs/architecture/*.md | wc -l`) and there is no `file.README.html` for the ADR index (AC-1.3): `grep -L` shows `doc/file.README.html` is the area map, `docs/adr/README.md` has no page.
2. A link from an area doc to an ADR: `grep -o 'href="file.0024[^"]*"' doc/file.release-and-deploy.html | head -1` prints `href="file.0024-backup-with-vacuum-into.html"` (AC-1.5); a link to a spec: `grep -o 'href="https://github.com/plainprogrammer/Collector/blob/main/docs/specs[^"]*"' doc/file.catalog-operations.html | head -1` prints one (AC-1.6).
3. No relative link of a rendered page is left: `grep -o 'href="[^h#"][^"]*\.md[^"]*"' doc/file.*.html | head` prints nothing.
4. `git status --short` shows no change to any document under `docs/` (AC-1.7).
5. App boot: `bin/rails zeitwerk:check` passes, and `CI=true bin/rspec spec/models/lot_spec.rb` (an eager-loaded run) passes without loading YARD (AC-3.7): `CI=true bin/rails runner 'abort "yard loaded" if defined?(YARD)'` exits 0.

- [ ] **Task 3.6: commit.** `bin/rubocop` must pass. Stage `script/yard/links.rb .yardopts spec/script/yard spec/fixtures/yard_site`; commit `feat(docs): make the links of the YARD pages work (#103)`.

---

## Phase 4: The worked example and the documents

**Implements:** FR-1 (the example), Story 4 | **Satisfies:** AC-1.9, AC-4.1–AC-4.7
**Files:** `lib/collector/backup.rb`, `CLAUDE.md`, `.claude/rules/conventions.md`, `docs/adr/0027-yard-for-api-documentation.md`, `docs/adr/README.md`, `docs/architecture/README.md`, `docs/architecture/release-and-deploy.md`, `docs/specs/README.md`, `docs/roadmap.md`, `docs/specs/054-adopt-yard/verification.md`
**Interfaces:** Consumes: Phases 1–3. Produces: nothing in code beyond one comment.

Documents are verified by reading, recorded in `verification.md` (`.claude/rules/testing.md`); no test.

- [ ] **Task 4.1: the worked-example `@see`.** In `lib/collector/backup.rb`, find the comment above `module Collector` … `module Backup` (`grep -n "module Backup" lib/collector/backup.rb`) and add as the last line of that comment, after a `#` blank line if the comment is more than one line:

```ruby
# @see file:release-and-deploy.md
```

Run `bin/yard doc --no-cache; echo "exit=$?"` (expected: no warning, `exit=0`) and `grep -o 'href="file.release-and-deploy.html"' doc/Collector/Backup.html` (expected: one match; AC-1.9). If `Collector::Backup` has no class comment, give it a one-line one first: `# Backs up the primary database online and restores it onto a fresh volume (spec 030, ADR 0024).`

- [ ] **Task 4.2: CLAUDE.md (AC-4.1).** In the Commands list, after the line beginning `- Lint (autocorrect):`, add:

```
- API docs: `bin/yard doc` (spec 054, ADR 0027) writes the browsable site to `doc/` (ignored by Git, left out of the image): the classes of `app` and `lib` from their comments, with the area docs and ADRs as pages and the area map as the front page. A YARD warning, such as an unresolved `{…}` in a comment, fails it, and fails the `bin/ci checks` step "Docs: YARD builds without warnings".
```

In the `- Local CI` line, change `setup, migration guard, RuboCop, Brakeman, bundler-audit, importmap audit, RSpec, serially` to `setup, migration guard, RuboCop, YARD, Brakeman, bundler-audit, importmap audit, RSpec, serially`. In `- Security:` nothing changes. Don't extend the Project Status paragraph.

- [ ] **Task 4.3: the comment convention (AC-4.4).** In `.claude/rules/conventions.md`, add at the end of the ✓ list (before the first ✗):

```
- ✓ Point a comment at an area doc or an ADR with a YARD tag, `@see file:<file name>.md` (for example `@see file:release-and-deploy.md`), not wrapped in braces; a spec stays a plain mention ("spec 015 AC-2.16"), as in the existing comments. Comments are Markdown (`bin/yard doc`, spec 054).
- ✓ Keep `{…}` out of comments unless it is YARD's link syntax: put paths and formats that contain braces in backticks. An unresolved `{…}` or a malformed tag fails `bin/ci checks` (step "Docs: YARD builds without warnings").
```

- [ ] **Task 4.4: ADR 0027 and its index (AC-4.2).** In `docs/adr/0027-yard-for-api-documentation.md`, change the Status line to begin `Accepted (2026-11-09). …` keeping the rest of the paragraph (replace `Proposed (2026-11-09); Accepted when the coordinator approves the plan of [spec 054](../specs/054-adopt-yard/spec.md).` with `Accepted (2026-11-09), with the approval of the plan of [spec 054](../specs/054-adopt-yard/spec.md).`) — only after the coordinator has approved the plan (Gate B). In `docs/adr/README.md`: add under the "### Images and publishing" heading's neighbours a new heading and line, after the "### Admin" section and before "### Data safety":

```
### Documentation

- [0027](0027-yard-for-api-documentation.md): Generate the Ruby API documentation with YARD, from the code's comments and the area docs
```

Replace the "### Expected" paragraph's first sentence `Named by the [roadmap](../roadmap.md) and written with their specs: adopting YARD (spec 027 slice B), which takes the next free number (lots in locations, roadmap item 10, took 0025; form errors, spec 044, took 0026). The upload-retention ADR expected by spec 028 is 0022 above.` with `Named by the [roadmap](../roadmap.md) and written with their specs: none now. The upload-retention ADR expected by spec 028 is 0022 above, and the YARD ADR (spec 027 slice B) is 0027 above (it was expected as 0023, then as the next free number: 0023 went to locations, 0025 to lots in locations, 0026 to form errors).` (Keep any text of the paragraph after these sentences.)

- [ ] **Task 4.5: the area docs (AC-4.3, AC-4.5).** In `docs/architecture/release-and-deploy.md`:

1. The bullet "**The image carries only what it runs.**": after the `bin/upgrade-smoke`-related list, add `, the API documentation (`doc/`, `.yardoc/`, `.yardopts`, `bin/yard`; the site's link extension is under `script/`, which is already left out, and the gem is in the development group, which the image's bundle leaves out)` and the source `spec 054 Story 3; ADR 0027` inside its closing parenthesis list of sources.
2. The bullet "**`bin/image-smoke` fails an image**…": add `doc`, `.yardoc`, `.yardopts` and `bin/yard` to the development-only paths it lists, with `spec 054 AC-3.3` in its sources.
3. The bullet "**The suite checks no prose document**…": after "`.dockerignore`" in its list of checked configuration files, add `, the Gemfile's group for `yard`, `.gitignore`'s rules for the generated site, the `bin/ci` step for YARD` and `spec 054 Story 3, AC-2.3` in its sources.
4. Sources: add `[spec 054](../specs/054-adopt-yard/spec.md) (the image's ignore rules for the API documentation) and [ADR 0027](../adr/0027-yard-for-api-documentation.md)` and issue `#103`.
5. Distillation log: one row `2026-11-09 | spec 054: the image's rules for the API documentation | <the pull request, when it exists>`.

In `docs/architecture/README.md`, after the paragraph "Lasting decisions are in [ADRs](../adr/README.md)…", add:

```
The area docs and the numbered ADRs are also pages of the generated API documentation: `bin/yard doc` writes it to `doc/` (spec 054, [ADR 0027](../adr/0027-yard-for-api-documentation.md)), turning the relative links below into links between pages. The files keep plain relative links.
```

- [ ] **Task 4.6: the indexes (AC-4.6).** In `docs/specs/README.md`: add a row for 054 after the row for 053, in the table's format (columns Spec | Status | Areas | Plan | Supersedes | Superseded by):

```
| [054 Browsable API Documentation for the Ruby Code, with the Area Docs and ADRs Linked In (YARD)](054-adopt-yard/spec.md) | Approved | Release and deploy (the image's ignore rules; [release and deploy](../architecture/release-and-deploy.md)); CLAUDE.md (R5): commands | present | 027 Out of Scope "Slice B: adopt YARD" (the starting shape, decided here) and the expected ADR number 0023 in D9, FR-8 and AC-6.2 (0027) | |
```

and in spec 027's row, put in its empty "Superseded by" cell: `Out of Scope "Slice B: adopt YARD" (the starting shape) and D9's, FR-8's and AC-6.2's expected ADR number 0023: 054 (ADR 0027)`. In `docs/roadmap.md`, replace the #103 line's text after the link with: `adopt YARD for the Ruby code's documentation, with the area docs linked in (spec 027 slice B). **In progress:** [spec 054](specs/054-adopt-yard/spec.md), [ADR 0027](adr/0027-yard-for-api-documentation.md).`

- [ ] **Task 4.7: verification.md.** Create `docs/specs/054-adopt-yard/verification.md` with a `## Criteria` table (one row per AC of the spec: the evidence: the command and its recorded output, or the document and the line read; Phases 1–3's recorded outputs go here), and leave the `## Implementation review` heading for the implementation review.

- [ ] **Task 4.8: commits.** One commit per document group: `docs: the YARD worked example, CLAUDE.md and the comment convention (#103)`, `docs(adr): accept ADR 0027, YARD for API documentation`, `docs: area docs, indexes and verification for spec 054`.

---

## Integration Verification

Run after Phase 4:

- `bin/yard doc --no-cache; echo "exit=$?"` → no `[warn]`, `exit=0`; open `doc/index.html` (the area map) in a browser and follow a link from an area doc to an ADR and to a spec (GitHub).
- `bin/rspec spec/script/yard spec/image_publishing_spec.rb spec/project_config_spec.rb spec/config/ci_definition_spec.rb` → all pass.
- `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit` pass; `bin/rails zeitwerk:check` passes.
- `bin/ci` (full; a slot is needed) passes; its YARD step's time is at most 30 s.
- CI's image job runs `bin/image-smoke` on both architectures and passes (AC-3.6).

## Quickstart Validation

1. `bundle install`
2. `bin/yard doc` → `doc/index.html` is the area map; a class page such as `doc/Collector/Backup.html` links to the release and deploy area doc.
3. Add `# {nothing_here}` to a comment in `app/`; `bin/ci checks` fails at "Docs: YARD builds without warnings", naming the file and line; remove it, and it passes.
4. `git status` shows nothing from `doc/` or `.yardoc/`.
