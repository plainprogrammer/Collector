# Implementation Plan: The Running Version, Its Commit and the Licence, Shown in the App (spec 084, issue #374)

**Spec:** `docs/specs/084-version-and-licence-in-app/spec.md` (Approved v0.3.1) · **Issue:** #374 · **Branch:** `084-version-and-licence-in-app` · **Created:** 2026-11-13
**Status:** Draft, for the Opus plan review and Gate B. Retired by `distill-feature` after the merge (spec 027).

## Context

Spec 084 adds Collector's licence line to the footer of every page, for everyone: "Collector 0.3.0 (a9f6de7) is free software under the AGPL-3.0. Get the source code.". It has two links: "AGPL-3.0" goes to the licence text, and "source code" goes to the source of the running build. The version, the revision and the source address are the *build facts*. The image's build passes them as three build arguments that become environment variables (`COLLECTOR_VERSION`, `COLLECTOR_REVISION`, `COLLECTOR_SOURCE_URL`). The app reads them once at boot through one core reader, `Collector::BuildFacts`, and a development checkout falls back to git. `bin/image-smoke` fails an image that doesn't report them. The footer is now always present (decision 1) and the shell is always footed (decision 11).

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`.
  - Spec types are tagged (`type: :model|:request|:system|:config`).
  - `RSpec/ExampleLength` max 15 lines; `RSpec/MultipleMemoizedHelpers` max 5 (use `def`).
  - Multi-expectation examples use `:aggregate_failures`.
  - Prose documents are verified by reading and recorded in `verification.md`, never from RSpec (`.claude/rules/testing.md`).
- **Core names no collectible.** `spec/footer_core_spec.rb` reads whole files, comments included, for `/mtg|magic|wizards|scryfall|fan content/i`. The new files `lib/collector/build_facts.rb` and `config/initializers/build_facts.rb` join its list (T2.2). Never write those words in them, not even in a comment ("the types' notices", not "the Scryfall line").
- **One commit per task, test first** (red, implement, green, RuboCop).
  - Conventional Commits with `(#374)`. The trailer is the attribution reminder in force at commit time; a Sonnet implementer's commits name Sonnet 5.5.
  - One git operation per shell call; `git add` and `git commit` in separate calls (the pre-commit hook reads the command text).
  - Every `git grep` ends with `':!.kamal/secrets'`. Never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/` or any `*.sqlite3`.
- **Never run `printenv` or `env` as a Bash command**, in a container or out (denied for agents here). `bin/image-smoke` may run `printenv COLLECTOR_VERSION` and `printenv COLLECTOR_REVISION` inside the container, and nothing else; an agent only runs the script.
- **Prompting files.** `Dockerfile` and `.github/workflows/ci.yml` are edited only in T3.2, with the text sent at Gate B and the maintainer answering the prompts. Never touch `config/deploy*.yml` or `.claude/settings.json`.
- **Comments:** every public class, module and method gets a summary (the comment ratchet in `bin/ci checks`), with `@param`/`@return` on reusable code. No `{…}` outside YARD links. Use `@see file:release-and-deploy.md` and `@see file:catalog-core.md`. Private helpers are `private_class_method`.
- **No migration, no export, import or backup change**; the export format stays 4. No gem, no JS. `spec/support/runtime_log.txt` is not refreshed.
- **UI:** the `collector-design-system` skill applies; there is no new pattern, the line is a `c-footer` paragraph.
- **Shared test database:** one test run at a time in this worktree.

## Goal

Every page's footer ends with the licence line, worded from the build facts. A published image reports a version and a 40-character revision. `bin/image-smoke` fails an image that doesn't.

## Pre-implementation gates

- **Simplicity (≤3 components): pass.** (1) `Collector::BuildFacts` with its initializer and spec helper; (2) the footer partial, the layout and the CSS; (3) the image: `Dockerfile`, `ci.yml` and `bin/image-smoke`.
- **Anti-abstraction: pass.** The licence line is `[text, address]` parts, the shape the partial already renders for `Catalog::ContentNotice::Line#parts`, with no new class. No wrapper sits around `ENV`.
- **Integration-first: pass.** The reader and its contract (Phase 1) come before the footer (Phase 2) and the image (Phase 3).

## Files

| File | Change | Responsibility |
|---|---|---|
| `lib/collector/build_facts.rb` | create | read, clean and keep the facts; the licence line's parts |
| `config/initializers/build_facts.rb` | create | read once at boot into `Rails.configuration.x.build_facts` |
| `spec/support/build_facts.rb` | create | `build_facts(...)` helper; restores after the example |
| `app/views/layouts/_footer.html.erb`, `application.html.erb` | edit | always a footer, licence line last; always `c-shell--footed` |
| `app/assets/stylesheets/collector/additions.css` | edit | drop the two unfooted clearance rules; comments |
| `bin/image-smoke` | edit | the build facts check |
| `Dockerfile`, `.github/workflows/ci.yml` | edit (prompting) | build arguments; header comment |
| `compose.yaml` | edit | comment only |
| `spec/models/collector/build_facts_spec.rb`, `spec/requests/licence_line_spec.rb` | create | the proofs |
| `spec/footer_core_spec.rb`, `spec/requests/footer_spec.rb`, `spec/system/footer_spec.rb`, `spec/design_system_files_spec.rb`, `spec/image_publishing_spec.rb` | edit | the guard's files; the third line; the CSS block; the file shapes |
| `docs/design-system/components/Footer.md`, `VisitorHeader.md`, `docs/design-system/README.md` | edit | the always-present footer and its licence line |
| `docs/architecture/catalog-core.md`, `docs/architecture/release-and-deploy.md`, `README.md`, `docs/releasing.md`, `CLAUDE.md` | edit | Story 5 |
| `docs/specs/084-version-and-licence-in-app/verification.md`, `screenshots/` | create | evidence |

## Phase 1: The build facts reader (contracts first)

**Implements:** FR-2; decisions 4, 6, 10 · **Satisfies:** AC-2.5, AC-2.6, AC-2.10 (git half), AC-2.11, AC-2.12 (reader level), AC-2.13 and AC-2.14 (parts)
**Files:** `lib/collector/build_facts.rb`, `config/initializers/build_facts.rb`, `spec/support/build_facts.rb`, `spec/models/collector/build_facts_spec.rb`

- [ ] **T1.1 The reader and the licence line's parts.** Test first: `spec/models/collector/build_facts_spec.rb` (`type: :model`). Every example calls `described_class.read(env:, rails_env:, git:)` with a `git` lambda; none touches `ENV`.

  ```ruby
  require "rails_helper"

  # Spec 084 decisions 2, 4, 6 and 10: what the running build's facts read, from the environment and, in development, git.
  RSpec.describe Collector::BuildFacts, type: :model do
    let(:sha) { "a9f6de7c0ffee1234567890abcdef1234567890a" } # 40 hexadecimal characters

    def read(env = {}, rails_env: "production", git: -> { raise "git asked" }) = described_class.read(env:, rails_env:, git:)

    def text(facts) = facts.licence_parts.map(&:first).join

    def links(facts) = facts.licence_parts.select(&:last)

    describe ".read" do
      it "takes a release's facts as given (AC-2.1)", :aggregate_failures do
        facts = read("COLLECTOR_VERSION" => "0.3.0", "COLLECTOR_REVISION" => sha,
          "COLLECTOR_SOURCE_URL" => "https://github.com/plainprogrammer/Collector/tree/#{sha}")

        expect([ facts.version, facts.revision, facts.short_revision ]).to eq([ "0.3.0", sha, "a9f6de7" ])
        expect(facts.source_url).to eq("https://github.com/plainprogrammer/Collector/tree/#{sha}")
      end

      it "knows nothing, and links upstream, when nothing is given outside development (AC-2.4)" do
        expect([ read.version, read.revision, read.source_url ]).to eq([ nil, nil, "https://github.com/plainprogrammer/Collector" ])
      end

      it "reads development and HEAD from git in development (AC-2.5)" do
        facts = read(rails_env: "development", git: -> { "#{sha}\n" })

        expect([ facts.version, facts.revision, facts.source_url ]).to eq([ "development", sha, "https://github.com/plainprogrammer/Collector" ])
      end

      it "keeps a given fact in development and asks git only for the revision it lacks (decision 4)", :aggregate_failures do
        expect(read({ "COLLECTOR_VERSION" => "0.3.0" }, rails_env: "development", git: -> { sha }).version).to eq("0.3.0")
        expect(read({ "COLLECTOR_REVISION" => sha }, rails_env: "development").revision).to eq(sha) # git would raise "git asked"
      end

      it "gives no revision, and raises nothing, when git is missing, fails or answers no SHA (AC-2.6)", :aggregate_failures do
        [ -> { raise Errno::ENOENT, "git" }, -> { nil }, -> { "fatal: not a git repository\n" }, -> { sha.first(7) } ].each do |git|
          facts = read(rails_env: "development", git:)
          expect([ facts.version, facts.revision ]).to eq([ "development", nil ])
        end
      end

      it "never asks git in test or production (AC-2.10)", :aggregate_failures do
        asked = 0
        git = -> { (asked += 1) && sha }
        %w[test production].each { |rails_env| read(rails_env:, git:) }

        expect(asked).to eq(0)
      end

      it "drops a version that breaks the rule (AC-2.7)", :aggregate_failures do
        [ "", "x" * 65, "0.3 .0", "<b>", "0.3.0;rm" ].each do |version|
          expect(read("COLLECTOR_VERSION" => version).version).to be_nil, version.inspect
        end
        expect(read("COLLECTOR_VERSION" => "0.4.0-rc.1+b_2").version).to eq("0.4.0-rc.1+b_2")
        expect(read("COLLECTOR_VERSION" => "x" * 64).version).to eq("x" * 64)
      end

      it "drops a revision that isn't 40 hexadecimal characters (AC-2.8)", :aggregate_failures do
        [ sha.first(7), sha.first(39), "g#{sha.first(39)}", "#{sha}0" ].each do |revision|
          expect(read("COLLECTOR_REVISION" => revision).revision).to be_nil, revision
        end
      end

      it "links upstream for an address that isn't absolute https with a host (AC-2.9)", :aggregate_failures do
        [ "http://example.test/src", "javascript:alert(1)", "/src", "https://", "https:///x", "not a uri" ].each do |address|
          expect(read("COLLECTOR_SOURCE_URL" => address).source_url).to eq("https://github.com/plainprogrammer/Collector"), address
        end
      end

      it "trims each fact and lowercases the revision (AC-2.11, AC-2.12)", :aggregate_failures do
        facts = read("COLLECTOR_VERSION" => " 0.3.0\n", "COLLECTOR_REVISION" => "#{sha.upcase}\n",
          "COLLECTOR_SOURCE_URL" => " https://example.test/src \n")

        expect([ facts.version, facts.revision, facts.short_revision ]).to eq([ "0.3.0", sha, "a9f6de7" ])
        expect(facts.source_url).to eq("https://example.test/src")
      end
    end

    describe "#licence_parts" do
      it "reads each row of decision 2's table", :aggregate_failures do
        tail = " is free software under the AGPL-3.0. Get the source code."
        expect(text(read("COLLECTOR_VERSION" => "0.3.0", "COLLECTOR_REVISION" => sha))).to eq("Collector 0.3.0 (a9f6de7)#{tail}")
        expect(text(read("COLLECTOR_VERSION" => "0.3.0"))).to eq("Collector 0.3.0#{tail}")
        expect(text(read("COLLECTOR_VERSION" => "bad version", "COLLECTOR_REVISION" => sha))).to eq("Collector (unknown version, a9f6de7)#{tail}")
        expect(text(read)).to eq("Collector (unknown version)#{tail}")
      end

      it "puts its two links on the fixed words, whatever the version says (AC-1.4, AC-2.13)", :aggregate_failures do
        [ "AGPL-3.0", "source-code" ].each do |version|
          facts = read("COLLECTOR_VERSION" => version, "COLLECTOR_REVISION" => sha, "COLLECTOR_SOURCE_URL" => "https://example.test/src")
          expect(links(facts)).to eq([ [ "AGPL-3.0", "https://www.gnu.org/licenses/agpl-3.0.html" ], [ "source code", "https://example.test/src" ] ])
          expect(facts.licence_parts.first).to eq([ "Collector #{version} (a9f6de7) is free software under the ", nil ])
        end
      end
    end
  end
  ```

  (If an example passes 15 lines, split it per case; the multi-case examples are one example per AC with `:aggregate_failures`.)

  Then `lib/collector/build_facts.rb`:

  ```ruby
  module Collector
    # The facts of the running build that every page's footer shows in Collector's licence line (spec 084): its version,
    # the commit it was built from and the address of that commit's source. The image's build sets them as environment
    # variables (`COLLECTOR_VERSION`, `COLLECTOR_REVISION`, `COLLECTOR_SOURCE_URL`); a development checkout falls back to
    # git for the revision. Each fact is trimmed and checked, and one that fails its rule counts as not given, so no value
    # an image or an operator passes can break a page (spec 084 decision 6).
    #
    # `config/initializers/build_facts.rb` reads them once at boot; {.current} returns that reading. Specs replace it with
    # `build_facts(...)` (`spec/support/build_facts.rb`) and never through the process environment (decision 10).
    #
    # @see file:release-and-deploy.md
    # @see file:catalog-core.md
    class BuildFacts
      # Where the source is when the build names no address: the upstream repository (decision 5).
      UPSTREAM_SOURCE = "https://github.com/plainprogrammer/Collector"
      # The licence's text, independent of any forge (decision 2).
      LICENCE_URL = "https://www.gnu.org/licenses/agpl-3.0.html"
      # A release's number, `edge`, `pr-N`, `development`: what a tag or a builder may name, with nothing a page would
      # escape (decision 6).
      VERSION_RULE = /\A[0-9A-Za-z.+_-]{1,64}\z/
      # A full commit SHA. A short one is refused so that two builds can't show the same ambiguous prefix (decision 6).
      REVISION_RULE = /\A\h{40}\z/

      attr_reader :version, :revision, :source_url

      def initialize(version:, revision:, source_url:)
        @version = version
        @revision = revision
        @source_url = source_url
      end

      # The facts this process runs with, read once at boot by `config/initializers/build_facts.rb`.
      #
      # @return [BuildFacts]
      def self.current = Rails.configuration.x.build_facts

      # Reads the facts from an environment. Each fact stands alone: in development, a version not given is
      # `development` and a revision not given is asked of `git`; elsewhere git is never asked (spec 084 decision 4).
      # No query, no request; it runs git at most once, in development.
      #
      # @param env [#[]] the variables, as `ENV` holds them
      # @param rails_env [String, #to_s] the Rails environment's name
      # @param git [#call] answers `HEAD`'s SHA, or nil; it may raise, and is called only in development
      # @return [BuildFacts]
      def self.read(env:, rails_env:, git: method(:git_head))
        version = cleaned(env["COLLECTOR_VERSION"], VERSION_RULE)
        revision = cleaned(env["COLLECTOR_REVISION"], REVISION_RULE)
        if rails_env.to_s == "development"
          version ||= "development"
          revision ||= cleaned(asked(git), REVISION_RULE)
        end
        new(version:, revision: revision&.downcase, source_url: https(env["COLLECTOR_SOURCE_URL"]) || UPSTREAM_SOURCE)
      end

      # The revision's first 7 characters, as the line shows it.
      #
      # @return [String, nil]
      def short_revision = revision&.first(7)

      # The licence line in reading order as `[text, address]` parts, the address nil where the text isn't a link, the
      # shape the footer renders for every line. The links sit on the fixed words "AGPL-3.0" and "source code", never
      # found by searching the text, so a version that contains them moves nothing (spec 084 decision 2, AC-2.13).
      #
      # @return [Array<Array(String, String), Array(String, nil)>]
      def licence_parts
        [ [ "#{name} is free software under the ", nil ], [ "AGPL-3.0", LICENCE_URL ], [ ". Get the ", nil ],
          [ "source code", source_url ], [ ".", nil ] ]
      end

      def self.cleaned(value, rule)
        value = value.to_s.strip
        value if value.match?(rule)
      end

      def self.https(value)
        uri = URI.parse(value.to_s.strip)
        uri.to_s if uri.is_a?(URI::HTTPS) && uri.host.present?
      rescue URI::InvalidURIError
        nil
      end

      def self.asked(git)
        git.call
      rescue StandardError
        nil
      end

      def self.git_head
        head = IO.popen(%w[git rev-parse HEAD], chdir: Rails.root.to_s, err: File::NULL, &:read)
        head if Process.last_status.success?
      end
      private_class_method :cleaned, :https, :asked, :git_head

      private
        # "Collector 0.3.0 (a9f6de7)", "Collector 0.3.0", "Collector (unknown version, a9f6de7)" or
        # "Collector (unknown version)" (spec 084 decision 2's table).
        def name
          return "Collector #{version}#{" (#{short_revision})" if short_revision}" if version

          "Collector (#{[ "unknown version", short_revision ].compact.join(", ")})"
        end
    end
  end
  ```

  `git_head` runs only from `read` in development, at boot (T1.2). `IO.popen` with an array runs no shell. A missing git raises `Errno::ENOENT`, which `asked` turns into nil. Run `bin/rails zeitwerk:check`. Commit: `feat(footer): read the running build's facts (#374)`.

- [ ] **T1.2 Read once at boot, and the spec helper.** Test first: add to `build_facts_spec.rb`:

  ```ruby
  describe ".current" do
    it "is read at boot from nothing in the test environment (AC-2.4, decision 10)" do
      expect([ described_class.current.version, described_class.current.revision ]).to eq([ nil, nil ])
    end

    it "is replaced by the spec helper with raw values, cleaned as the image's would be (decision 10)", :aggregate_failures do
      build_facts(version: " 0.3.0\n", revision: "A" * 40, source_url: "http://insecure.test")

      expect([ described_class.current.version, described_class.current.revision ]).to eq([ "0.3.0", "a" * 40 ])
      expect(described_class.current.source_url).to eq("https://github.com/plainprogrammer/Collector")
    end

    it "is back to the boot reading in the next example (order-independent restore)" do
      expect(described_class.current.version).to be_nil
    end
  end
  ```

  (The third example proves the restore only when it runs after the second. Also prove it directly: an example that calls `build_facts(version: "1.0.0")`, then runs the `after` hook's body by hand (`restore_build_facts`), and expects `nil`.) Then:

  `config/initializers/build_facts.rb`:

  ```ruby
  # Spec 084: the running build's facts (Collector::BuildFacts), read once at boot so that git, which a development
  # checkout asks for its revision, never runs during a request. after_initialize, because the reader is autoloaded from
  # lib/ and can't be referenced while the configuration loads. Tests never read the environment (a developer's exported
  # variable mustn't change a page in the suite); examples set the facts with build_facts(...) (spec/support/build_facts.rb).
  Rails.application.config.after_initialize do
    Rails.configuration.x.build_facts = Collector::BuildFacts.read(env: Rails.env.test? ? {} : ENV, rails_env: Rails.env)
  end
  ```

  `spec/support/build_facts.rb`:

  ```ruby
  # The running build's facts in specs (spec 084 decision 10). An example sets them with build_facts(...): raw values that
  # go through Collector::BuildFacts.read's trimming and checking, as an image's environment would, read as production
  # reads them (git is never asked). The boot reading comes back after the example.
  module BuildFactsHelpers
    # Replaces the running build's facts for the rest of this example.
    #
    # @param version [String, nil] as `COLLECTOR_VERSION` would hold it
    # @param revision [String, nil] as `COLLECTOR_REVISION` would hold it
    # @param source_url [String, nil] as `COLLECTOR_SOURCE_URL` would hold it
    # @return [Collector::BuildFacts] the facts now in force
    def build_facts(version: nil, revision: nil, source_url: nil)
      @build_facts_at_boot = Rails.configuration.x.build_facts unless defined?(@build_facts_at_boot)
      env = { "COLLECTOR_VERSION" => version, "COLLECTOR_REVISION" => revision, "COLLECTOR_SOURCE_URL" => source_url }.compact
      Rails.configuration.x.build_facts = Collector::BuildFacts.read(env:, rails_env: "production")
    end

    # Puts back the facts read at boot, if this example replaced them; the suite calls it after every example.
    #
    # @return [void]
    def restore_build_facts
      Rails.configuration.x.build_facts = @build_facts_at_boot if defined?(@build_facts_at_boot)
    end
  end

  RSpec.configure do |config|
    config.include BuildFactsHelpers
    config.after { restore_build_facts }
  end
  ```

  Commit: `feat(footer): read the build facts once at boot, and set them in specs (#374)`.

## Phase 2: The licence line in the footer

**Implements:** FR-1; decisions 1, 2, 11 · **Satisfies:** AC-1.1 to AC-1.8, AC-2.1 to AC-2.4, AC-2.7 to AC-2.9, AC-2.10 (no query), AC-2.11 to AC-2.14 (page level), AC-4.1 to AC-4.3
**Files:** `app/views/layouts/_footer.html.erb`, `app/views/layouts/application.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/requests/licence_line_spec.rb`, `spec/requests/footer_spec.rb`, `spec/footer_core_spec.rb`, `spec/system/footer_spec.rb`, `spec/design_system_files_spec.rb`

- [ ] **T2.1 Every page ends with the licence line.** Test first.

  **(a)** `spec/requests/licence_line_spec.rb` (`type: :request`):

  ```ruby
  require "rails_helper"

  # Spec 084 Stories 1 and 2: Collector's licence line ends every page's footer, for everyone, worded from the build facts.
  RSpec.describe "The licence line", type: :request do
    let(:sha) { "a9f6de7c0ffee1234567890abcdef1234567890a" }
    let(:tail) { " is free software under the AGPL-3.0. Get the source code." }

    def html = Nokogiri::HTML5(response.body)

    def line = html.at_css("body > footer.c-footer > p:last-child")

    def link_pairs = line.css("a").map { |link| [ link.text, link["href"] ] }

    it "ends the footer of a collector's pages (AC-1.1, AC-1.4)", :aggregate_failures do
      lot = create(:lot, account: sign_in_as(create(:user)).account)
      [ collection_path, catalog_entry_path(lot.entry), scanner_path, more_path ].each do |path|
        get path
        expect(line.text).to eq("Collector (unknown version)#{tail}"), path
        expect(link_pairs).to eq([ [ "AGPL-3.0", "https://www.gnu.org/licenses/agpl-3.0.html" ],
          [ "source code", "https://github.com/plainprogrammer/Collector" ] ]), path
        expect(line.css("a").map { |link| link.attributes.keys }).to all(match_array(%w[rel href])), path
      end
    end
  ```

  Add, each its own example in that file:
  - **Deck page and admin page (AC-1.1).** As an admin with a deck: `deck_path(deck)` and `admin_catalog_path`.
  - **Visitor (AC-1.2).** `new_registration_path` (first run), then, after `create(:user)` and `InstanceSetting.current.update!(sign_up_open: true)`, `new_session_path` and `new_registration_path`.
  - **Open catalog (AC-1.3).** Tagged `:public_catalog`: `catalog_entries_path` and `catalog_entry_path(create(:catalog_entry))` signed out; the last `p` is the line.
  - **Release facts (AC-2.1).** `build_facts(version: "0.3.0", revision: sha, source_url: "https://example.test/tree/#{sha}")`, then `new_session_path` signed out and `collection_path` signed in: the text is `"Collector 0.3.0 (a9f6de7)#{tail}"` and the "source code" link is `"https://example.test/tree/#{sha}"`.
  - **Edge (AC-2.2).** `build_facts(version: "edge", revision: sha)`: the text starts with `"Collector edge (a9f6de7) is free software"`.
  - **No revision (AC-2.3).** `build_facts(version: "0.3.0")`: the text is `"Collector 0.3.0#{tail}"`.
  - **Bad values, one example per AC.** AC-2.7: `version: "0.3 .0"` with no revision gives `"Collector (unknown version)…"`. AC-2.8: `revision: sha.first(7)` gives no parentheses after `0.3.0`. AC-2.9: `source_url: "javascript:alert(1)"` gives the upstream link, and the body doesn't include `javascript:`. AC-2.11: `version: " 0.3.0\n"`. AC-2.12: an upper-case revision shows `a9f6de7`. AC-2.13: `version: "AGPL-3.0"` keeps exactly the two links. AC-2.14: `version: "bad version", revision: sha` gives `"Collector (unknown version, a9f6de7)#{tail}"`.
  - **Once, on 422 and 429 (AC-1.6).** Ten bad sign-ins give 422, the eleventh 429; each page has exactly one `p` whose text ends with `"Get the source code."`. Copy the existing footer spec's sequence.
  - **No query (AC-2.10).** `expect(count_queries { Collector::BuildFacts.current.licence_parts }).to eq(0)`.

  **(b)** Edit `spec/requests/footer_spec.rb`:
  - `expect_the_footer` expects three lines: `[ notice, attribution, licence ]`, with `def licence = "Collector (unknown version) is free software under the AGPL-3.0. Get the source code."`.
  - `links` gains `[ "AGPL-3.0", "https://www.gnu.org/licenses/agpl-3.0.html" ], [ "source code", "https://github.com/plainprogrammer/Collector" ]`.
  - In "with other catalog types", the line lists become `[ notice, attribution, "Zeta …", "Data from Zeta Base.", licence ]`. The paragraph indexes `[2]` and `[3]` stay. The unsafe-link example's `footer.css("a").size` becomes 4.
  - The AC-2.3 example becomes AC-1.5 of spec 084: rename it to "holds only the licence line when no type supplies a notice (spec 084 AC-1.5, supersedes spec 018 AC-2.3)", expect `footers.size == 1`, `lines == [ licence ]` and `body class == "c-shell c-shell--footed"`.
  - "is text and its links" keeps its assertions; `rel` and `href` hold for all four links.
  - Add to the file's header comment that spec 084 adds the last line.

  **(c)** `spec/footer_core_spec.rb`: the `files` list gains `lib/collector/build_facts.rb` and `config/initializers/build_facts.rb`. The first example's description becomes "covers the layout, the footer's partial, the model that collects the notices and the build facts' reader". The header comment names spec 084 AC-1.8.

  Run (a), (b) and (c): red. Then implement:

  `app/views/layouts/_footer.html.erb`:

  ```erb
  <%# The page's footer, on every page (spec 018, spec 084): the content notices of the registered catalog types, one line
      per paragraph, then Collector's own licence line, always last. The types' lines come from each type's source, never
      from this file; the licence line's words and links come from the running build's facts
      (Collector::BuildFacts#licence_parts). %>
  <footer class="c-footer">
    <% lines.each do |line| %>
      <p><% line.parts.each do |text, address| %><%= address ? link_to(text, address, rel: "noopener") : text %><% end %></p>
    <% end %>
    <p><% licence.each do |text, address| %><%= address ? link_to(text, address, rel: "noopener") : text %><% end %></p>
  </footer>
  ```

  `app/views/layouts/application.html.erb`: the `<body>` line becomes

  ```erb
  <%# Every shell is footed: the footer always holds at least the licence line (spec 084 decisions 1 and 11). A page with no tab bar (a visitor's catalog page, sign-in, sign-up) gives up the bar's clearance (spec 023). %>
  <body class="<%= class_names("c-shell", "c-shell--footed", "c-shell--untabbed": !content_for?(:tabbar)) %>">
  ```

  (The old one-line comment above it is replaced.) The render line becomes `<%= render "layouts/footer", lines: notice_lines, licence: Collector::BuildFacts.current.licence_parts %>`.

  Green: (a), (b), (c), `spec/requests/catalog/visitors_spec.rb`, `spec/requests/catalog/entries_show_spec.rb`, `spec/system/visitor_catalog_spec.rb`. Commit: `feat(footer): end every page's footer with the licence line (#374)`.

- [ ] **T2.2 The shell's CSS and the browser checks.** Test first.
  - `spec/design_system_files_spec.rb` "the untabbed shell": `include` only `".c-shell--untabbed > .c-footer { padding-bottom:calc(var(--space-4) + env(safe-area-inset-bottom)); }"`, with `not_to include(".c-shell--untabbed > .c-main")` and a rule count of 1. Name spec 084 decision 11 in the example's description.
  - `spec/system/footer_spec.rb`:
    - "is styled on the scanner page" expects four hrefs: the existing two, then `"https://www.gnu.org/licenses/agpl-3.0.html"` and `"https://github.com/plainprogrammer/Collector"` (spec 084 AC-4.3).
    - Add one example: the licence line at 360px on `collection_path` and `new_session_path` through `measure_at` (as the 390/360 example does). Every line is uncovered, on the gutter, inside `viewport - gutter`, and on the collection page above the tab bar (AC-4.1).
    - Add one example in the light theme: `find("body > footer.c-footer a", text: "source code")` has the brand colour `rgb(19, 89, 90)`, contrast ≥ 4.5, and the 2px focus ring (AC-4.2, light).
    - In the dark example, add that the licence line's link colour is `rgb(95, 183, 178)` (AC-4.2, dark).
  - Run: the design-system example is red.

  Then, in `additions.css`:
  - The "Footer" block's comment, "The layout marks the shell c-shell--footed when it renders a footer, and c-main then gives that clearance up.", becomes "The layout marks every shell c-shell--footed (the footer is always there, spec 084), and c-main gives that clearance up."
  - The "Untabbed shell (spec 023)" block becomes:

  ```css
  /* ---------- Untabbed shell (spec 023) ----------
     Below bp-narrow the footer keeps 80px clear for the fixed tab bar. A page with no tab bar (a visitor's catalog page,
     sign-in, sign-up) is marked c-shell--untabbed and the footer gives that clearance up. Every shell is footed (spec 084
     decision 11), so c-main's foot is the footer block's rule. */
  @media (max-width: 639px) {
    .c-shell--untabbed > .c-footer { padding-bottom:calc(var(--space-4) + env(safe-area-inset-bottom)); }
  }
  ```

  Keep the block's header line unchanged: the design-system spec matches `Untabbed shell (spec 023)` and counts "spec 023" once. Green: `spec/design_system_files_spec.rb`, `spec/system/footer_spec.rb`, `spec/system/visitor_catalog_spec.rb` (spec 023 AC-5.7's measurements). Commit: `refactor(footer): drop the clearance rules of an unfooted shell (#374)`.

## Phase 3: The image reports its facts

**Implements:** FR-3; decisions 3, 4, 7 · **Satisfies:** AC-3.1 to AC-3.6
**Files:** `bin/image-smoke`, `spec/image_publishing_spec.rb`, `Dockerfile`, `.github/workflows/ci.yml`

- [ ] **T3.1 The smoke test's check.** Test first, in `spec/image_publishing_spec.rb`'s `bin/image-smoke` group:

  ```ruby
  it "fails an image that reports no version or no full revision, from captured output (spec 084 decision 7)", :aggregate_failures do
    script = Rails.root.join("bin/image-smoke").read
    expect(script).to include(%(version="$(trim "$("$cli" exec "$name" printenv COLLECTOR_VERSION 2>/dev/null || true)")"),
      %(revision="$(trim "$("$cli" exec "$name" printenv COLLECTOR_REVISION 2>/dev/null || true)")"),
      %(grep -qF "Collector ${version} (${short}) is free software" <<<"$sign_in"))
    expect(script.scan("printenv").size).to eq(2) # the two named variables and nothing else
    expect(script).to include("COLLECTOR_SOURCE_URL") # the failure message names all three build arguments
  end
  ```

  Then, in `bin/image-smoke`: after `fail()`, add

  ```bash
  trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }
  ```

  After the "pages and assets" section (a user exists, so `/session/new` answers 200), add:

  ```bash
  # The image's build passes its facts as build arguments (spec 084 decision 3); an image without them shows "unknown
  # version" and is never published. Only the two named variables are read, captured and then tested (no pipe).
  echo "== the build facts (spec 084)"
  build_args="build it with --build-arg COLLECTOR_VERSION=<version> --build-arg COLLECTOR_REVISION=<40-character SHA> --build-arg COLLECTOR_SOURCE_URL=<https address of the source> (README.md, Building from source)"
  version="$(trim "$("$cli" exec "$name" printenv COLLECTOR_VERSION 2>/dev/null || true)")"
  revision="$(trim "$("$cli" exec "$name" printenv COLLECTOR_REVISION 2>/dev/null || true)")"
  [ -n "$version" ] || fail "the image reports no version: ${build_args}"
  grep -qxE '[0-9A-Fa-f]{40}' <<<"$revision" || fail "the image reports no 40-character revision (got '${revision}'): ${build_args}"
  short="$(tr 'A-F' 'a-f' <<<"${revision:0:7}")"
  sign_in="$(curl -s "http://127.0.0.1:${port}/session/new")" || fail "the sign-in page did not load"
  grep -qF "Collector ${version} (${short}) is free software" <<<"$sign_in" \
    || fail "the sign-in page's licence line doesn't read 'Collector ${version} (${short})'"
  ```

  The header comment gains "and that it reports its version and revision (spec 084)". Run `spec/image_publishing_spec.rb` and `spec/smoke_scripts_spec.rb`: green. `bash -n bin/image-smoke` passes. Commit: `test(image): fail an image that doesn't report its build facts (#374)`.

- [ ] **T3.2 The build arguments (prompting edits; the text sent at Gate B).** Test first, in `spec/image_publishing_spec.rb`:

  ```ruby
  # in describe "Dockerfile"
  it "takes the build facts last in the final stage, after every COPY (spec 084 AC-3.1)", :aggregate_failures do
    final = instructions[instructions.rindex { it.start_with?("FROM ") }..]
    facts = %w[COLLECTOR_VERSION COLLECTOR_REVISION COLLECTOR_SOURCE_URL]

    expect(final).to include(*facts.map { %(ARG #{it}="") })
    expect(final.index(%(ARG COLLECTOR_VERSION=""))).to be > final.rindex { it.start_with?("COPY ") }
    expect(final.join("\n")).to include(*facts.map { %(#{it}="${#{it}}") })
  end

  # in the workflow group
  it "passes the same build facts to both builds, pr-N on a pull request (spec 084 AC-3.2, AC-3.6)", :aggregate_failures do
    expected = <<~ARGS
      COLLECTOR_VERSION=${{ steps.meta.outputs.version || format('pr-{0}', github.event.pull_request.number) }}
      COLLECTOR_REVISION=${{ github.sha }}
      COLLECTOR_SOURCE_URL=${{ github.server_url }}/${{ github.repository }}/tree/${{ github.sha }}
    ARGS
    expect(step("build").dig("with", "build-args")).to eq(expected)
    expect(step("push").dig("with", "build-args")).to eq(expected)
  end
  ```

  Red. Then, after the maintainer has answered the prompts, make exactly these edits.

  **`Dockerfile`**, lines 4–6, from:

  ```dockerfile
  # This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
  # docker build -t collector .
  # docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name collector collector
  ```

  to:

  ```dockerfile
  # This Dockerfile is designed for production, not development. Use with Kamal, or build it by hand as README.md's
  # "Building from source" says, passing the build facts at the end of this file (spec 084), and then run it:
  # docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name collector collector
  ```

  and, between `ENV MAX_REQUEST_BODY="40000000"` and `# Entrypoint prepares the database.`, insert:

  ```dockerfile
  # The build facts the footer's licence line shows (spec 084): the version, the full commit SHA and the https address of
  # that commit's source. CI passes them (docs/releasing.md); a build by hand passes them with --build-arg. Declared last,
  # so a new commit rebuilds only this layer. Without them the footer reads "unknown version" and bin/image-smoke fails.
  ARG COLLECTOR_VERSION=""
  ARG COLLECTOR_REVISION=""
  ARG COLLECTOR_SOURCE_URL=""
  ENV COLLECTOR_VERSION="${COLLECTOR_VERSION}" \
      COLLECTOR_REVISION="${COLLECTOR_REVISION}" \
      COLLECTOR_SOURCE_URL="${COLLECTOR_SOURCE_URL}"

  ```

  **`.github/workflows/ci.yml`**, in the `image` job. In the `Build` step (`id: build`), after `labels: ${{ steps.meta.outputs.labels }}`, insert:

  ```yaml
            # The build facts the footer shows (spec 084): metadata-action gives no version on a pull request, so pr-N.
            build-args: |
              COLLECTOR_VERSION=${{ steps.meta.outputs.version || format('pr-{0}', github.event.pull_request.number) }}
              COLLECTOR_REVISION=${{ github.sha }}
              COLLECTOR_SOURCE_URL=${{ github.server_url }}/${{ github.repository }}/tree/${{ github.sha }}
  ```

  In the `Push by digest` step (`id: push`), after its `labels:` line, insert:

  ```yaml
            # The same build facts as the smoke-tested build, so the cache gives the same image (spec 084).
            build-args: |
              COLLECTOR_VERSION=${{ steps.meta.outputs.version || format('pr-{0}', github.event.pull_request.number) }}
              COLLECTOR_REVISION=${{ github.sha }}
              COLLECTOR_SOURCE_URL=${{ github.server_url }}/${{ github.repository }}/tree/${{ github.sha }}
  ```

  Nothing else changes in either file. Green: `spec/image_publishing_spec.rb`. Commit: `build(image): pass the build facts to the image (#374)`.

- [ ] **T3.3 Prove the image locally** (Docker through colima; no slot needed, it isn't `bin/ci`; run in the background, one build at a time):
  1. `docker build --build-arg COLLECTOR_VERSION=0.0.0-smoke --build-arg COLLECTOR_REVISION=$(git rev-parse HEAD) --build-arg COLLECTOR_SOURCE_URL=https://github.com/plainprogrammer/Collector/tree/$(git rev-parse HEAD) -t collector:084 .` (write it as a script under the scratchpad and run that script).
  2. `bin/image-smoke collector:084` passes (AC-3.3).
  3. `bin/image-smoke collector:084 -e COLLECTOR_REVISION=` fails with the build-arguments message (AC-3.4, no revision).
  4. `bin/image-smoke collector:084 -e COLLECTOR_REVISION=$(git rev-parse --short HEAD)` fails (AC-3.4, short SHA).
  5. `bin/image-smoke collector:084 -e COLLECTOR_VERSION=` fails (no version).

  The run flags reach `docker run` (the script's `[run flags]`), which overrides the image's `ENV`. Record each command, its exit status and its last lines in `verification.md`. No commit beyond `verification.md`'s, which is written in T5.2.

## Phase 4: The documents

**Implements:** Story 5; decisions 1, 9, 11 · **Satisfies:** AC-4.4, AC-5.1 to AC-5.6 (verified by reading, in `verification.md`)

- [ ] **T4.1 The design system.**
  - `Footer.md`: the opening says the footer is the small print at the end of every page: the catalog types' notices, then Collector's licence line. The markup gains the third paragraph, with the version shown as `0.3.0 (a9f6de7)` and both links.
  - Rewrite the stale statements decision 1 names:
    - "The lines come from each catalog type's source …, never from a view" covers the types' lines; the licence line comes from `Collector::BuildFacts#licence_parts`.
    - "When no catalog type supplies a notice there is no element at all" becomes "There is always a footer: with no type's notice it holds the licence line alone, and the shell is always `c-shell--footed`".
    - "A line's wording belongs to its catalog type" applies to the types' lines.
  - Add a rule: the licence line is last, is the core's, and its links are the two fixed words.
  - `VisitorHeader.md`, the bullet on `c-main`'s foot: every shell is footed, so `c-main` keeps `space-4` (the footer block's rule), and the untabbed block holds only the footer's rule.
  - `docs/design-system/README.md`:
    - Line 81 ("A focused page that is one screen high and has no footer shows the content notice's lines in the foot of each of its sheets") gains "and the licence line" (see Gate B's note on #344).
    - Line 129 gains "spec 084 adds the licence line".

  Commit: `docs(design-system): the footer is always there and ends with the licence line (#374)`.
- [ ] **T4.2 Catalog core's area doc.** `docs/architecture/catalog-core.md`:
  - The Scope line "The footer's content notice" gains "and Collector's licence line (spec 084)".
  - The invariant "The footer is one place, supplied by the types" becomes "The footer is one place: the types' notices, then the core's licence line", with spec 084 decisions 1 and 2.
  - In "The footer": "With no line there is no footer element" becomes "The footer is always there; its last line is Collector's licence line …". The wording table goes in, with the links, the build facts' source (pointing to release and deploy) and the always-footed shell.
  - Add spec 084 to Sources.

  Commit: `docs(architecture): the footer's licence line in catalog core (#374)`.
- [ ] **T4.3 Release and deploy, the README, the release procedure, Compose.**
  - `docs/architecture/release-and-deploy.md`:
    - "The image" gains the build facts (decision 3), the per-trigger table (decision 4), the cleaning rule (decision 6), the smoke check (decision 7), the hand-build path (decision 9) and the reader (decision 10).
    - Add a row to Named constants: the three variables, `VERSION_RULE`, `REVISION_RULE` and `UPSTREAM_SOURCE`.
    - Add spec 084 to Sources.
  - `README.md`:
    - In Self-hosting, add one paragraph: "Each page's footer shows the running version and commit".
    - "Building from source" becomes:

      ```sh
      docker build -t collector:local \
        --build-arg COLLECTOR_VERSION=0.3.0-local \
        --build-arg COLLECTOR_REVISION="$(git rev-parse HEAD)" \
        --build-arg COLLECTOR_SOURCE_URL="https://github.com/you/collector/tree/$(git rev-parse HEAD)" .
      ```

      Explain the three arguments, the fork's address, and what an image without them shows.
    - The Kamal own-registry paragraph shows decision 9's `builder: args:` lines.
    - License adds: "Every page's footer says so, with a link to the source of the running build."
  - `docs/releasing.md`:
    - After "Every published image carries OCI labels…", add a paragraph on the build facts, each trigger's version and the PR `pr-N`.
    - In "Cutting a release", step 6 gains "then open the instance and check that its footer reads `Collector X.Y.Z (<first 7 of the tag's commit>)`".
  - `compose.yaml`'s comment on `COLLECTOR_IMAGE`: "e.g. collector:local after `docker build -t collector:local .`" becomes "e.g. collector:local, built as README.md's "Building from source" says, with the build facts".
  - `spec/image_publishing_spec.rb`'s compose examples must stay green: they read keys, not comments.

  Commit: `docs(release): the build facts in the image, the README and the release procedure (#374)`.
- [ ] **T4.4 `CLAUDE.md`.** In Project Status, after the export sentence, add: "Every page's footer ends with Collector's licence line, AGPL-3.0 with a link to the source of the running build, and shows the running version and short SHA, which the image's build passes as `COLLECTOR_VERSION`, `COLLECTOR_REVISION` and `COLLECTOR_SOURCE_URL` and `Collector::BuildFacts` reads once at boot; `bin/image-smoke` fails an image without them (spec 084)." In Non-obvious Facts' "Footer and open catalog" bullet, add "(specs 018, 023, 084)" and "the licence line is the core's last line; specs set the build facts with `build_facts(...)`, never ENV". Commit: `docs: the licence line and build facts in CLAUDE.md (#374)`.

## Phase 5: Verification

- [ ] **T5.1 Screenshots** (`.claude/memory/pr-screenshots-workflow.md`; headless Firefox; `data-theme` set for both themes; phone widths in the narrow frame). Shots: the collection page's footer at 1280px and at 390px (in the frame), and the sign-in page's footer at 390px, light and dark. Seed the build facts with one runner script in its own call. A dev server reads them at boot, so start it with `COLLECTOR_VERSION=0.0.0-shot COLLECTOR_REVISION=<a sha> COLLECTOR_SOURCE_URL=https://github.com/plainprogrammer/Collector/tree/<sha>` in the environment of the background server task, not via `printenv`. Save them to `docs/specs/084-version-and-licence-in-app/screenshots/`. Commit: `docs(specs): screenshots of the licence line (#374)`.
- [ ] **T5.2 `verification.md`.** Record:
  - each AC with its evidence (example, run or reading);
  - T3.3's image runs;
  - the full `bin/ci` result (with a slot);
  - the PR's CI run and its two `Image` jobs' smoke output (AC-3.5, AC-3.6: the build step's `COLLECTOR_VERSION=pr-N`);
  - two mutation proofs: break `REVISION_RULE` to `/\A\h{7,40}\z/` and AC-2.8's example fails; drop the `|| format(...)` and the AC-3.6 config example fails. Restore both.
- [ ] **T5.3 Implementation review** (`sdd-review` Mode B, read-only, Opus), recorded under `## Implementation review` with the verdict first.

## Self-review

- **Spec coverage:**
  - FR-1: T2.1.
  - FR-2: T1.1, T1.2.
  - FR-3: T3.1, T3.2.
  - Story 4: T2.2, T4.1.
  - Story 5: T4.1 to T4.4, and the roadmap (done at Gate A, `a40d0e44`).
  - AC-3.5 and AC-3.6: the PR run (T5.2), with AC-3.6's expression also checked statically (T3.2). The spec's AC-3.6 says there is no automated check of the workflow file; the static example is extra, and `verification.md` notes it.
- **Placeholders:** none.
- **Names:** `Collector::BuildFacts.read(env:, rails_env:, git:)`, `.current`, `#version`, `#revision`, `#short_revision`, `#source_url`, `#licence_parts`; the spec helper `build_facts(version:, revision:, source_url:)` and `restore_build_facts`; the partial's locals are `lines:` and `licence:`.
