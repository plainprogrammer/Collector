# Implementation Plan: Clean Up Untagged GHCR Package Versions

**Spec:** docs/specs/013-ghcr-untagged-cleanup/spec.md (v1.1.1, Approved, reviewed twice; Phase 0 patches it to v1.1.2)
**Decisions:** [ADR 0011](../../adr/0011-own-ghcr-cleanup-script.md) (own stdlib-only script, not a third-party action), Accepted.
**Issue:** [#17](https://github.com/plainprogrammer/Collector/issues/17)
**Created:** 2026-10-08
**Revised:** 2026-10-08, after a read-only plan review (Fable, READY TO EXECUTE: phases ran 19/13/45/21 as claimed, live dry run matched). Applied: a failed DELETE request (not only a refusal) now stops deleting and still runs the post-delete check, with a run example; `$stdout.sync` so deletions precede a failure in the Actions log; `Manifest.parse` rejects a child without a `sha256:` digest; `Net::ProtocolError`/`Net::HTTPBadResponse` are wrapped as failures; the Phase 3 FAIL wording; a 4-backtick fence around the releasing section; `.dockerignore` lines at column 0; the executable-bit check; a WebMock note on the subprocess examples.
**Approved:** 2026-10-08 (maintainer, after the review revision).

## Context

Every publish leaves untagged per-architecture images behind its tagged manifest list, and a release re-run
orphans a whole list. This plan adds `Collector::GhcrCleanup` (selection rule, API client, run), the
`bin/ghcr-cleanup` command, a weekly workflow, the image exclusions and the `docs/releasing.md` section.

**Facts established during planning (2026-10-08):**

- **The plan's code was run before it was written down.** Every code block below was drafted in the session
  scratchpad and run with `bin/rspec` from the worktree (the real `rails_helper`, WebMock, the project's RuboCop
  config): 45 of 47 examples pass in scratch, the other 2 being the `bin/ghcr-cleanup` examples, which need the
  script at `Rails.root`; the script was checked by hand (no token → exit 1 naming `GH_TOKEN`; `--force` → exit 1
  with the usage line). The file-shape examples pass against scratch copies of the workflow, `.dockerignore` and
  `docs/releasing.md`. RuboCop: no offenses.
- **A live dry run of the drafted command** (`GH_TOKEN="$(gh auth token)"`, read-only) printed exactly the
  spec's numbers: `18 versions: 5 tagged, 10 referenced, 3 too young, 0 selected`, the three being
  `f03eb8274a90…` (unit age 0d 3h) and its children `90ceeb5c0550…` and `0f9c9927048e…`. So the API shape,
  pagination, the anonymous pull token, the `Accept` header and the media-type parsing work against the real
  systems.
- **GitHub Packages accepts only classic personal access tokens** ("GitHub Packages only supports authentication
  using a personal access token (classic)"; deleting needs `read:packages` and `delete:packages`), from
  docs.github.com "About permissions for GitHub Packages", fetched 2026-10-08. The spec's Open Question names a
  fine-grained token as the fallback, which would not work; Phase 0 patches it.
- **Code layout:** `lib/` is autoloaded (`config.autoload_lib(ignore: %w[assets tasks])`), so
  `lib/collector/ghcr_cleanup.rb` defines `Collector::GhcrCleanup` with its nested `Version`, `Manifest`, `Unit`,
  `Plan`, `Client` and `Run`, and loads without side effects; `bin/ghcr-cleanup` `require_relative`s it like
  `bin/dev-certificate`. Specs follow `RSpec/SpecFilePathFormat`: `spec/lib/collector/ghcr_cleanup_spec.rb`,
  `spec/lib/collector/ghcr_cleanup/client_spec.rb`, `spec/lib/collector/ghcr_cleanup/run_spec.rb`.
- **RuboCop limits that shaped the specs:** `RSpec/ExampleLength` 15, `RSpec/MultipleMemoizedHelpers` 5,
  `RSpec/NestedGroups` 3, `RSpec/LeakyConstantDeclaration` on (the run spec's in-memory registry is a
  `Class.new` in a `let`, like no constant), `:aggregate_failures` on multi-expectation examples.
- **`spec/support/http_stubbing.rb`** already disables real HTTP (`WebMock.disable_net_connect!(allow_localhost:
  true)`); WebMock intercepts `Net::HTTP` GET, HEAD and DELETE, and `.to_timeout` raises `Net::OpenTimeout`.
- **The post-delete check cannot be exercised live before 2026-10-15T14:42:46Z**, when the only orphan unit
  passes the grace period; until then a deleting run selects nothing and so neither deletes nor checks. The live
  delete (and the Open Question about `GITHUB_TOKEN`) is therefore a maintainer step after that time (Phase 5).
- **`workflow_dispatch` only appears in the Actions tab once the workflow is on `main`**, so the manual workflow
  runs happen after the merge.
- **Branch:** `013-ghcr-untagged-cleanup` exists with the PRD, ADR and spec commits (doc-first done).

**Plan decisions (not spelled out in the spec):**

- **One file, three parts.** The selection rule is module functions (pure, no I/O); `Client` does every HTTP
  request; `Run` orchestrates and prints. Specs test the rule with plain values, the client with WebMock, and the
  run with an in-memory registry plus one end-to-end example through the real client.
- **Union-find for orphan units.** Candidates are joined through each candidate list's children that are
  themselves candidates, so units sharing a member merge and children missing from the version list or
  referenced by a tag never join (Terms).
- **Output wording** (AC-4.1, AC-4.3): `select <digest> created <time> tags (none): <kind>, unit age Nd Nh`,
  `too young …` with the same fields, `deleted <digest>` / `already deleted <digest>`, and the summary
  `N versions: T tagged, R referenced, Y too young, S selected`.
- **"Deleted at least one version" (AC-2.4) counts 404s** (already gone) as well as 204s: either way a version
  went away, so the tags are checked.
- **A failure exits 1 via `abort`**, printing `ghcr-cleanup: <message>` to stderr; messages name requests by URL
  and versions by tag and digest, never the token.
- **The workflow installs Ruby with `ruby/setup-ruby@v1` (already in `ci.yml`) without `bundler-cache`**: the
  command is stdlib-only, so no gems are installed.

## Global Constraints

- Delete only untagged versions that no tagged manifest list references, as whole orphan units, once a unit's
  newest member is more than 7 × 86,400 seconds old; never a tagged version or a referenced digest.
- Fail closed: an unreadable version list, pull token or manifest, a tagged version that is not a manifest list
  of exactly `linux/amd64` and `linux/arm64`, or a candidate of unknown media type deletes nothing; a refused
  delete (any status but 404) stops deleting; the run exits non-zero naming the cause.
- A dry run unless `--delete`; the token comes from `GH_TOKEN`, else `GITHUB_TOKEN`, and is never printed.
- Endpoints: `https://api.github.com/users/plainprogrammer/packages/container/collector/versions?per_page=100&page=N`
  (no `Link` following), `DELETE …/versions/{id}`, `https://ghcr.io/token?scope=repository:plainprogrammer/collector:pull`,
  `https://ghcr.io/v2/plainprogrammer/collector/manifests/<digest>` with all four media types in `Accept`.
- Timeouts: 10 seconds to open, 30 seconds to read, on every request.
- Workflow: Sundays 06:00 UTC deleting; `workflow_dispatch` with `dry_run` defaulting to `true`; jobs `dry-run`
  (`packages: read`) and `delete` (`packages: write`); `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}`; only `actions/*`
  and `ruby/setup-ruby`; `ci.yml` unchanged.
- Stdlib only, no new gems. `bin/ghcr-cleanup` and `lib/collector/ghcr_cleanup.rb` stay out of the image.
- Commits follow `docs/git-convention.md` (`<type>(<scope>): <message>`), one per step, with the attribution
  trailers; the pre-commit hook runs RuboCop on staged Ruby files and Brakeman, the pre-push hook runs `bin/ci`.

---

## Goal

`bin/ghcr-cleanup` and a weekly workflow delete orphaned untagged versions of `ghcr.io/plainprogrammer/collector`
after 7 days without ever breaking a tag, and `docs/releasing.md` says how to run and pause it.

---

## Phase 0: Spec patch (classic token)

**Implements:** Open Questions | **Satisfies:** none (documentation)
**Files:** `docs/specs/013-ghcr-untagged-cleanup/spec.md`
**Interfaces:** Consumes: nothing. Produces: spec v1.1.2, whose Open Question names a classic token.

Correct the fallback credential before any code depends on it (a PATCH under `sdd-spec-update`: wording, no
behaviour change; the maintainer's approval of this plan covers it).

- [ ] In `spec.md`, set `**Version:** 1.1.2`, add this changelog row after 1.1.1:

  ```markdown
  | 1.1.2 | 2026-10-08 | Planning fix: GitHub Packages accepts only classic personal access tokens, so the fallback credential is a classic token with `read:packages` and `delete:packages`, not a fine-grained one (Open Questions) |
  ```

  and in Open Questions replace `a fine-grained token with \`packages\` read and write in a repository secret`
  with `a personal access token (classic) with \`read:packages\` and \`delete:packages\` in a repository secret
  (GitHub Packages does not accept fine-grained tokens)`.
- [ ] Run: `grep -n "fine-grained" docs/specs/013-ghcr-untagged-cleanup/spec.md` — expect: only the changelog
  row and the parenthesis.
- [ ] Commit: `docs(013): fallback token is a classic PAT (spec v1.1.2)`

---

## Phase 1: Selection rule

**Implements:** FR-1 (units, grace, referenced), FR-2 (tagged and candidate checks), FR-3 (token variable) | **Satisfies:** AC-1.1, AC-1.2, AC-1.3, AC-1.4, AC-2.1, AC-2.2, AC-2.3, AC-3.4, AC-3.5 (unknown type), AC-3.7 (rule), AC-3.8, AC-4.1 (counts)
**Files:** `lib/collector/ghcr_cleanup.rb`, `spec/lib/collector/ghcr_cleanup_spec.rb`
**Interfaces:** Consumes: nothing. Produces: `Collector::GhcrCleanup::{LIST_TYPES, IMAGE_TYPES, PLATFORMS, GRACE}`,
`Failure < StandardError`, `Refused < Failure`, `Version(id:, digest:, created_at:, tags:)` with `#tagged?` and
`#label`, `Manifest(media_type:, children:, platforms:)` with `.parse(content_type, body)`, `#list?`, `#known?`,
`Unit(lists:, images:)` with `#members`, `#age(now)`, `#past_grace?(now)`, `Plan(selected:, young:, counts:)`,
and module functions `token_from(env)`, `referenced(tagged)` (`{ Version => Manifest }` → `Set` of digests),
`check_tagged!(version, manifest)`, `plan(versions:, referenced:, manifests:, now:)`, `duration(seconds)`.

The pure rule: which versions form orphan units, which units are past the grace period, and which inputs
fail closed. No I/O.

- [ ] Write the spec `spec/lib/collector/ghcr_cleanup_spec.rb`:

  ```ruby
require "rails_helper"

RSpec.describe Collector::GhcrCleanup do
  let(:now) { Time.utc(2026, 10, 20, 12) }

  def version(name, age_days, tags: [])
    described_class::Version.new(id: name.sum, digest: "sha256:#{name}", created_at: now - (age_days * 86_400), tags:)
  end

  def list(*children, platforms: described_class::PLATFORMS)
    described_class::Manifest.new(media_type: described_class::LIST_TYPES.first,
                                  children: children.map { |child| "sha256:#{child}" }, platforms:)
  end

  def image = described_class::Manifest.new(media_type: described_class::IMAGE_TYPES.first, children: [], platforms: [])

  # manifests: { "name" => Manifest } for every tagged version and every candidate.
  def plan_for(versions, manifests)
    by_digest = manifests.transform_keys { |name| "sha256:#{name}" }
    referenced = described_class.referenced(versions.select(&:tagged?).to_h { |v| [ v, by_digest.fetch(v.digest) ] })
    described_class.plan(versions:, referenced:, manifests: by_digest, now:)
  end

  def names(units) = units.flat_map(&:members).map { |v| v.digest.delete_prefix("sha256:") }

  describe ".plan" do
    it "selects an unreferenced image past the grace period (AC-1.1)" do
      expect(names(plan_for([ version("orphan", 8) ], "orphan" => image).selected)).to eq([ "orphan" ])
    end

    it "selects an orphan list with its children, list first (AC-1.2, FR-1)" do
      plan = plan_for([ version("old", 8), version("a", 8.01), version("b", 8.01) ], "old" => list("a", "b"), "a" => image, "b" => image)
      expect(names(plan.selected)).to eq(%w[old a b])
    end

    it "keeps a unit whose list is inside the grace period although its children are not (AC-1.3)", :aggregate_failures do
      plan = plan_for([ version("new", 6), version("a", 8), version("b", 8) ], "new" => list("a", "b"), "a" => image, "b" => image)
      expect(plan.selected).to be_empty
      expect(names(plan.young)).to eq(%w[new a b])
    end

    it "keeps a young unreferenced image (AC-1.4)" do
      expect(names(plan_for([ version("fresh", 6) ], "fresh" => image).young)).to eq([ "fresh" ])
    end

    it "selects only strictly past 7 × 86,400 seconds (Terms)", :aggregate_failures do
      plan = plan_for([ version("exact", 7), version("over", 7 + (1.0 / 86_400)) ], "exact" => image, "over" => image)
      expect(names(plan.selected)).to eq([ "over" ])
      expect(names(plan.young)).to eq([ "exact" ])
    end

    it "keeps tagged versions of any age, with several tags (AC-2.1)", :aggregate_failures do
      plan = plan_for([ version("rel", 400, tags: %w[latest 0.1 0.1.0]), version("a", 400), version("b", 400) ],
                      "rel" => list("a", "b"))
      expect(plan.selected).to be_empty
      expect(plan.counts).to eq(tagged: 1, referenced: 2, young: 0, selected: 0)
    end

    it "keeps old children of a tagged list (AC-2.2)" do
      plan = plan_for([ version("edge", 1, tags: %w[edge]), version("a", 30), version("b", 30) ], "edge" => list("a", "b"))
      expect(plan.counts).to include(referenced: 2, selected: 0)
    end

    it "deletes an old list but keeps a child it shares with a tagged list (AC-2.3)" do
      versions = [ version("rel", 1, tags: %w[latest]), version("new2", 1), version("shared", 9), version("old", 9), version("old2", 9) ]
      plan = plan_for(versions, "rel" => list("shared", "new2"), "old" => list("shared", "old2"), "old2" => image)
      expect(names(plan.selected)).to eq(%w[old old2])
    end

    it "merges untagged lists that share a child and judges them by the newest member (Terms)", :aggregate_failures do
      versions = [ version("young", 2), version("old", 10), version("shared", 10), version("y2", 2), version("o2", 10) ]
      manifests = { "young" => list("shared", "y2"), "old" => list("shared", "o2"), "shared" => image, "y2" => image, "o2" => image }
      plan = plan_for(versions, manifests)
      expect(plan.selected).to be_empty
      expect(names(plan.young)).to contain_exactly("young", "old", "shared", "y2", "o2")
    end

    it "ignores a child that is no longer in the version list (Terms)" do
      expect(names(plan_for([ version("old", 10), version("a", 10) ], "old" => list("a", "gone"), "a" => image).selected)).to eq(%w[old a])
    end

    it "counts four disjoint buckets that sum to the version total (AC-4.1)", :aggregate_failures do
      versions = [ version("edge", 1, tags: %w[edge]), version("a", 9), version("b", 9), version("fresh", 1), version("orphan", 9) ]
      plan = plan_for(versions, "edge" => list("a", "b"), "fresh" => image, "orphan" => image)
      expect(plan.counts).to eq(tagged: 1, referenced: 2, young: 1, selected: 1)
      expect(plan.counts.values.sum).to eq(versions.size)
    end

    it "fails closed on a candidate with an unknown media type (AC-3.5)" do
      odd = described_class::Manifest.new(media_type: "application/vnd.example+json", children: [], platforms: [])
      expect { plan_for([ version("odd", 9) ], "odd" => odd) }.to raise_error(described_class::Failure, %r{sha256:odd is "application/vnd.example\+json"})
    end
  end

  describe ".referenced" do
    it "fails closed on a tag pointing at a single image (AC-3.4)" do
      expect { plan_for([ version("kamal", 1, tags: %w[latest]) ], "kamal" => image) }
        .to raise_error(described_class::Failure, /tag latest \(sha256:kamal\) is "application\/vnd.oci.image.manifest.v1\+json", not a manifest list/)
    end

    it "fails closed on a tagged list without exactly amd64 and arm64 (AC-3.8)" do
      expect { plan_for([ version("one", 1, tags: %w[edge]) ], "one" => list("a", platforms: %w[linux/amd64])) }
        .to raise_error(described_class::Failure, /tag edge \(sha256:one\) has platforms linux\/amd64; expected/)
    end
  end

  describe "Manifest.parse" do
    let(:index) do
      { "mediaType" => described_class::LIST_TYPES.first,
        "manifests" => [ { "digest" => "sha256:a", "platform" => { "os" => "linux", "architecture" => "amd64" } },
                         { "digest" => "sha256:b", "platform" => { "os" => "linux", "architecture" => "arm64" } } ] }.to_json
    end

    it "reads the type from Content-Type and the children with their platforms", :aggregate_failures do
      manifest = described_class::Manifest.parse("#{described_class::LIST_TYPES.first}; charset=utf-8", index)
      expect(manifest.children).to eq(%w[sha256:a sha256:b])
      expect(manifest.platforms).to eq(%w[linux/amd64 linux/arm64])
    end

    it "falls back to the body's mediaType without a Content-Type (FR-1)" do
      expect(described_class::Manifest.parse(nil, index)).to be_list
    end

    it "fails on a child without a digest" do
      body = { "manifests" => [ { "platform" => { "os" => "linux", "architecture" => "amd64" } } ] }.to_json
      expect { described_class::Manifest.parse(described_class::LIST_TYPES.first, body) }
        .to raise_error(described_class::Failure, /child without a digest/)
    end

    it "fails on a body that is not JSON" do
      expect { described_class::Manifest.parse("text/html", "<html>") }.to raise_error(described_class::Failure, /not JSON/)
    end
  end

  describe ".token_from" do
    it "prefers GH_TOKEN and falls back to GITHUB_TOKEN (FR-3)", :aggregate_failures do
      expect(described_class.token_from("GH_TOKEN" => "a", "GITHUB_TOKEN" => "b")).to eq("a")
      expect(described_class.token_from("GH_TOKEN" => "", "GITHUB_TOKEN" => "b")).to eq("b")
    end

    it "fails naming GH_TOKEN when neither is set (AC-3.7)" do
      expect { described_class.token_from({}) }.to raise_error(described_class::Failure, /GH_TOKEN/)
    end
  end
end
  ```

- [ ] Run: `bin/rspec spec/lib/collector/ghcr_cleanup_spec.rb` — expect: FAIL (`uninitialized constant
  Collector::GhcrCleanup`).
- [ ] Write `lib/collector/ghcr_cleanup.rb`:

  ```ruby
require "json"
require "net/http"
require "openssl"
require "time"

module Collector
  # Deletes untagged versions of ghcr.io/plainprogrammer/collector that no tagged manifest list references, once
  # their orphan unit is past a 7-day grace period (spec 013, ADR 0011). Fails closed: anything it can't read or
  # understand stops the run before a delete. Stdlib only: loaded by bin/ghcr-cleanup without the app.
  module GhcrCleanup
    LIST_TYPES = %w[application/vnd.oci.image.index.v1+json
                    application/vnd.docker.distribution.manifest.list.v2+json].freeze
    IMAGE_TYPES = %w[application/vnd.oci.image.manifest.v1+json
                     application/vnd.docker.distribution.manifest.v2+json].freeze
    PLATFORMS = %w[linux/amd64 linux/arm64].freeze
    GRACE = 7 * 86_400

    class Failure < StandardError; end
    class Refused < Failure; end

    Version = Data.define(:id, :digest, :created_at, :tags) do
      def tagged? = tags.any?
      def label = tagged? ? "tag #{tags.join(", ")} (#{digest})" : digest
    end

    Manifest = Data.define(:media_type, :children, :platforms) do
      # The media type comes from Content-Type, falling back to the body's mediaType (FR-1).
      def self.parse(content_type, body)
        json = JSON.parse(body)
        raise Failure, "manifest is not a JSON object" unless json.is_a?(Hash)

        type = content_type.to_s.split(";").first.to_s.strip
        type = json["mediaType"].to_s if type.empty?
        entries = LIST_TYPES.include?(type) ? Array(json["manifests"]).grep(Hash) : []
        unless entries.all? { |entry| entry["digest"].is_a?(String) && entry["digest"].start_with?("sha256:") }
          raise Failure, "manifest names a child without a digest"
        end
        new(media_type: type, children: entries.map { |entry| entry["digest"] },
            platforms: entries.map { |entry| "#{entry.dig("platform", "os")}/#{entry.dig("platform", "architecture")}" })
      rescue JSON::ParserError
        raise Failure, "manifest is not JSON"
      end

      def list? = LIST_TYPES.include?(media_type)
      def known? = list? || IMAGE_TYPES.include?(media_type)
    end

    # An orphan unit; its manifest lists come first so an interrupted run leaves only standalone images (FR-1).
    Unit = Data.define(:lists, :images) do
      def members = lists + images
      def age(now) = now - members.map(&:created_at).max
      def past_grace?(now) = age(now) > GRACE
    end

    Plan = Data.define(:selected, :young, :counts)

    module_function

    def token_from(env)
      token = [ env["GH_TOKEN"], env["GITHUB_TOKEN"] ].find { |value| value && !value.empty? }
      token or raise Failure, "set GH_TOKEN (or GITHUB_TOKEN) to a token that can read the package"
    end

    # Checks every tagged version is a two-platform manifest list and returns the digests they reference.
    def referenced(tagged)
      tagged.each_with_object(Set.new) do |(version, manifest), digests|
        check_tagged!(version, manifest)
        digests.merge(manifest.children)
      end
    end

    def check_tagged!(version, manifest)
      raise Failure, "#{version.label} is #{manifest.media_type.inspect}, not a manifest list" unless manifest.list?
      return if manifest.platforms.sort == PLATFORMS

      raise Failure, "#{version.label} has platforms #{manifest.platforms.join(", ")}; expected #{PLATFORMS.join(" and ")}"
    end

    # Groups the candidates (untagged, unreferenced) into orphan units, merging units that share a member, and
    # splits them by the grace period. manifests holds every candidate's manifest by digest.
    def plan(versions:, referenced:, manifests:, now:)
      candidates = versions.reject { |version| version.tagged? || referenced.include?(version.digest) }
      root = candidates.to_h { |version| [ version.digest, version.digest ] }
      find = ->(digest) { root[digest] == digest ? digest : (root[digest] = find.(root[digest])) }
      candidates.each do |version|
        manifest = manifests.fetch(version.digest)
        raise Failure, "#{version.digest} is #{manifest.media_type.inspect}, which the cleanup does not know" unless manifest.known?

        manifest.children.each { |child| root[find.(child)] = find.(version.digest) if root.key?(child) }
      end
      units = candidates.group_by { |version| find.(version.digest) }.values.map do |members|
        lists, images = members.partition { |version| manifests.fetch(version.digest).list? }
        Unit.new(lists:, images:)
      end
      selected, young = units.partition { |unit| unit.past_grace?(now) }
      tagged = versions.count(&:tagged?)
      Plan.new(selected:, young:, counts: { tagged:, referenced: versions.size - tagged - candidates.size,
                                            young: young.sum { |unit| unit.members.size },
                                            selected: selected.sum { |unit| unit.members.size } })
    end

    def duration(seconds)
      days, rest = seconds.to_i.divmod(86_400)
      "#{days}d #{rest / 3600}h"
    end
  end
end
  ```

- [ ] Run: `bin/rspec spec/lib/collector/ghcr_cleanup_spec.rb` — expect: `20 examples, 0 failures`.
- [ ] Run: `bin/rails zeitwerk:check` — expect: `All is good!`; `bin/rubocop lib/collector/ghcr_cleanup.rb
  spec/lib/collector/ghcr_cleanup_spec.rb` — expect: no offenses.
- [ ] Commit: `feat(ghcr-cleanup): add the orphan-unit selection rule`

---

## Phase 2: API client

**Implements:** FR-1 (manifest reads), FR-2 (timeouts, refusals, 404 on delete), FR-3 (endpoints, pagination), NFR Security (no token in messages) | **Satisfies:** AC-3.1, AC-3.2, AC-3.3 (request), AC-3.6 (status), AC-3.9 (status)
**Files:** `lib/collector/ghcr_cleanup.rb`, `spec/lib/collector/ghcr_cleanup/client_spec.rb`
**Interfaces:** Consumes: Phase 1's `Version`, `Manifest.parse`, `Failure`, `Refused`, `LIST_TYPES`,
`IMAGE_TYPES`. Produces: `Collector::GhcrCleanup::Client.new(token:)` with `#versions` → `[Version]`,
`#manifest(digest)` → `Manifest`, `#fetchable?(digest)` → `true`/`false`, `#delete(version)` → `:deleted` or
`:gone` (raises `Refused`); constants `API`, `REGISTRY`, `PULL_TOKEN`, `PER_PAGE`, `ACCEPT`, `USER_AGENT`.

Every HTTP request in one class, so the rule and the run never touch the network directly.

- [ ] Write the spec `spec/lib/collector/ghcr_cleanup/client_spec.rb`:

  ```ruby
require "rails_helper"

RSpec.describe Collector::GhcrCleanup::Client do
  subject(:client) { described_class.new(token: "gh-secret") }

  let(:failure) { Collector::GhcrCleanup::Failure }

  def entry(id, tags: [])
    { "id" => id, "name" => "sha256:#{id}", "created_at" => "2026-10-08T14:42:46Z",
      "metadata" => { "package_type" => "container", "container" => { "tags" => tags } } }
  end

  def stub_page(page, body, status: 200)
    stub_request(:get, "#{described_class::API}?per_page=100&page=#{page}")
      .with(headers: { "Authorization" => "Bearer gh-secret", "Accept" => "application/vnd.github+json" })
      .to_return(status:, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_pull_token = stub_request(:get, described_class::PULL_TOKEN).to_return(body: { token: "pull" }.to_json)

  def stub_manifest(digest, status: 200, body: "{}", type: Collector::GhcrCleanup::IMAGE_TYPES.first, method: :get)
    stub_request(method, "#{described_class::REGISTRY}#{digest}")
      .with(headers: { "Authorization" => "Bearer pull", "Accept" => described_class::ACCEPT })
      .to_return(status:, body:, headers: { "Content-Type" => type })
  end

  describe "#versions" do
    it "reads every page by number until a short page (AC-3.2, FR-3)", :aggregate_failures do
      stub_page(1, (1..100).map { |id| entry(id) })
      stub_page(2, [ entry(101, tags: %w[latest 0.1]) ])
      versions = client.versions
      expect(versions.size).to eq(101)
      expect(versions.last).to have_attributes(id: 101, digest: "sha256:101", tags: %w[latest 0.1],
                                               created_at: Time.utc(2026, 10, 8, 14, 42, 46))
    end

    it "stops at an empty page after a full one" do
      stub_page(1, (1..100).map { |id| entry(id) })
      stub_page(2, [])
      expect(client.versions.size).to eq(100)
    end

    it "fails naming the request, not the token, when the API refuses (AC-3.1)", :aggregate_failures do
      stub_page(1, { message: "Bad credentials" }, status: 401)
      expect { client.versions }.to raise_error(failure, /page=1 answered 401/) { |error| expect(error.message).not_to include("gh-secret") }
    end

    it "fails on a response that is not a version list (AC-3.1)", :aggregate_failures do
      stub_page(1, { "message" => "moved" })
      expect { client.versions }.to raise_error(failure, /did not return a version list/)
      stub_page(1, [ entry(1).merge("metadata" => {}) ])
      expect { client.versions }.to raise_error(failure, /did not return a version list/)
      stub_page(1, [ entry(1).merge("created_at" => "yesterday") ])
      expect { client.versions }.to raise_error(failure, /did not return a version list/)
    end

    it "fails on a timeout, naming the request" do
      stub_request(:get, /api.github.com/).to_timeout
      expect { client.versions }.to raise_error(failure, /GET .*page=1 failed/)
    end

    it "sets explicit timeouts on every request (FR-2)" do
      allow(Net::HTTP).to receive(:start).and_call_original
      stub_page(1, [])
      client.versions
      expect(Net::HTTP).to have_received(:start).with("api.github.com", 443, hash_including(open_timeout: 10, read_timeout: 30))
    end
  end

  describe "#manifest" do
    let(:index) do
      { "manifests" => [ { "digest" => "sha256:a", "platform" => { "os" => "linux", "architecture" => "amd64" } } ] }.to_json
    end

    it "reads by digest with an anonymous pull token, fetched once per run (FR-1)", :aggregate_failures do
      token = stub_pull_token
      stub_manifest("sha256:list", body: index, type: Collector::GhcrCleanup::LIST_TYPES.first)
      stub_manifest("sha256:img")
      expect(client.manifest("sha256:list")).to have_attributes(children: [ "sha256:a" ], platforms: [ "linux/amd64" ])
      expect(client.manifest("sha256:img")).not_to be_list
      expect(token).to have_been_requested.once
    end

    it "fails naming the request when the registry answers otherwise (AC-3.3)" do
      stub_pull_token
      stub_manifest("sha256:gone", status: 404)
      expect { client.manifest("sha256:gone") }.to raise_error(failure, %r{GET https://ghcr.io/.*sha256:gone answered 404})
    end

    it "fails when no pull token is issued" do
      stub_request(:get, described_class::PULL_TOKEN).to_return(status: 500)
      expect { client.manifest("sha256:a") }.to raise_error(failure, /token\?scope=.* answered 500/)
    end
  end

  describe "#fetchable?" do
    before { stub_pull_token }

    it "answers from a HEAD with the same Accept (AC-2.4)", :aggregate_failures do
      stub_manifest("sha256:here", method: :head)
      stub_manifest("sha256:gone", method: :head, status: 404)
      expect(client.fetchable?("sha256:here")).to be(true)
      expect(client.fetchable?("sha256:gone")).to be(false)
    end

    it "fails on any other answer" do
      stub_manifest("sha256:odd", method: :head, status: 502)
      expect { client.fetchable?("sha256:odd") }.to raise_error(failure, /HEAD .* answered 502/)
    end
  end

  describe "#delete" do
    let(:version) { Collector::GhcrCleanup::Version.new(id: 42, digest: "sha256:x", created_at: Time.now, tags: []) }

    def stub_delete(status) = stub_request(:delete, "#{described_class::API}/42").to_return(status:)

    it "deletes by id, and treats a 404 as already deleted (AC-3.9)", :aggregate_failures do
      stub_delete(204)
      expect(client.delete(version)).to eq(:deleted)
      stub_delete(404)
      expect(client.delete(version)).to eq(:gone)
    end

    it "raises Refused naming the version and status on any other answer (AC-3.6)" do
      stub_delete(403)
      expect { client.delete(version) }.to raise_error(Collector::GhcrCleanup::Refused, %r{versions/42 \(sha256:x\) answered 403})
    end
  end
end
  ```

- [ ] Run: `bin/rspec spec/lib/collector/ghcr_cleanup/client_spec.rb` — expect: FAIL (`uninitialized constant
  Collector::GhcrCleanup::Client`).
- [ ] In `lib/collector/ghcr_cleanup.rb`, insert the class after `def duration(seconds) … end` and before the
  module's closing `end`:

  ```ruby
    # The packages API and the registry. Error messages name the request, never the token.
    class Client
      API = "https://api.github.com/users/plainprogrammer/packages/container/collector/versions".freeze
      REGISTRY = "https://ghcr.io/v2/plainprogrammer/collector/manifests/".freeze
      PULL_TOKEN = "https://ghcr.io/token?scope=repository:plainprogrammer/collector:pull".freeze
      PER_PAGE = 100
      ACCEPT = (LIST_TYPES + IMAGE_TYPES).join(", ").freeze
      USER_AGENT = "collector-ghcr-cleanup (+https://github.com/plainprogrammer/Collector)".freeze

      def initialize(token:)
        @token = token
      end

      # Every page, by number on the /users/ path; the Link header points at a /user/{id}/ path (FR-3).
      def versions
        (1..).each_with_object([]) do |page, all|
          url = "#{API}?per_page=#{PER_PAGE}&page=#{page}"
          batch = parse_versions(url, json(request(Net::HTTP::Get, url, github_headers), url))
          all.concat(batch)
          break all if batch.size < PER_PAGE
        end
      end

      def manifest(digest)
        url = REGISTRY + digest
        response = request(Net::HTTP::Get, url, registry_headers)
        raise Failure, "GET #{url} answered #{response.code}" unless response.code == "200"

        Manifest.parse(response["content-type"], response.body)
      end

      def fetchable?(digest)
        url = REGISTRY + digest
        code = request(Net::HTTP::Head, url, registry_headers).code
        return code == "200" if %w[200 404].include?(code)

        raise Failure, "HEAD #{url} answered #{code}"
      end

      # :deleted, or :gone when GitHub answers 404 (already deleted, AC-3.9); raises Refused otherwise.
      def delete(version)
        url = "#{API}/#{version.id}"
        code = request(Net::HTTP::Delete, url, github_headers).code
        return :deleted if code == "204"
        return :gone if code == "404"

        raise Refused, "DELETE #{url} (#{version.digest}) answered #{code}"
      end

      private

      def request(verb, url, headers)
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
          http.request(verb.new(uri, headers))
        end
      rescue IOError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError,
             Net::HTTPBadResponse => e
        raise Failure, "#{verb::METHOD} #{url} failed: #{e.class}"
      end

      def json(response, url)
        raise Failure, "GET #{url} answered #{response.code}" unless response.code == "200"

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Failure, "GET #{url} did not return JSON"
      end

      def parse_versions(url, entries)
        raise Failure, "GET #{url} did not return a version list" unless entries.is_a?(Array)

        entries.map do |entry|
          tags = entry.dig("metadata", "container", "tags") if entry.is_a?(Hash)
          unless tags.is_a?(Array) && entry["id"].is_a?(Integer) && entry["name"].to_s.start_with?("sha256:")
            raise Failure, "GET #{url} did not return a version list"
          end

          Version.new(id: entry["id"], digest: entry["name"], created_at: Time.iso8601(entry["created_at"].to_s), tags:)
        rescue ArgumentError, TypeError
          raise Failure, "GET #{url} did not return a version list"
        end
      end

      def pull_token
        @pull_token ||= begin
          body = json(request(Net::HTTP::Get, PULL_TOKEN, { "User-Agent" => USER_AGENT }), PULL_TOKEN)
          raise Failure, "GET #{PULL_TOKEN} returned no token" unless body.is_a?(Hash) && body["token"].is_a?(String)

          body["token"]
        end
      end

      def github_headers
        { "Authorization" => "Bearer #{@token}", "Accept" => "application/vnd.github+json",
          "X-GitHub-Api-Version" => "2022-11-28", "User-Agent" => USER_AGENT }
      end

      def registry_headers
        { "Authorization" => "Bearer #{pull_token}", "Accept" => ACCEPT, "User-Agent" => USER_AGENT }
      end
    end
  ```

- [ ] Run: `bin/rspec spec/lib/collector/ghcr_cleanup/client_spec.rb` — expect: `13 examples, 0 failures`.
- [ ] Run: `bin/rubocop lib/collector/ghcr_cleanup.rb spec/lib/collector/ghcr_cleanup/client_spec.rb` — expect:
  no offenses.
- [ ] Commit: `feat(ghcr-cleanup): add the packages API and registry client`

---

## Phase 3: Run and command

**Implements:** FR-2 (fail closed, stop at refusal), FR-3 (run modes, output), AC-2.4's check | **Satisfies:** AC-1.2, AC-1.6, AC-2.4, AC-3.3 (naming), AC-3.5 (naming), AC-3.6, AC-3.7, AC-3.9, AC-4.1
**Files:** `lib/collector/ghcr_cleanup.rb`, `bin/ghcr-cleanup`, `spec/lib/collector/ghcr_cleanup/run_spec.rb`, `spec/lib/collector/ghcr_cleanup_spec.rb`
**Interfaces:** Consumes: Phase 1's rule and Phase 2's `Client` (any object with `#versions`, `#manifest`,
`#fetchable?`, `#delete`). Produces: `Collector::GhcrCleanup::Run.new(client:, out:, now: Time.now, delete:
false)` with `#call` → `Plan` (raises `Failure`); the executable `bin/ghcr-cleanup [--delete]`.

Reads everything before deciding, reports, deletes unit by unit (lists first), then checks every tag's
children.

- [ ] Write the spec `spec/lib/collector/ghcr_cleanup/run_spec.rb`:

  ```ruby
require "rails_helper"

RSpec.describe Collector::GhcrCleanup::Run do
  let(:now) { Time.utc(2026, 10, 20, 12) }
  let(:out) { StringIO.new }
  let(:cleanup) { Collector::GhcrCleanup }

  # In-memory packages API and registry; the Client itself is specced against WebMock in client_spec.rb.
  let(:registry) do
    Class.new do
      attr_reader :versions, :manifests, :deleted, :missing, :refuse, :gone, :broken

      def initialize(versions, manifests)
        @versions, @manifests, @deleted, @missing, @refuse, @gone, @broken = versions, manifests, [], [], {}, [], []
      end

      def manifest(digest)
        manifests.fetch(digest) { raise Collector::GhcrCleanup::Failure, "GET #{digest} answered 404" }
      end

      def fetchable?(digest) = !missing.include?(digest)

      def delete(version)
        status = refuse[version.digest]
        raise Collector::GhcrCleanup::Refused, "DELETE #{version.digest} answered #{status}" if status
        raise Collector::GhcrCleanup::Failure, "DELETE #{version.digest} failed: Net::ReadTimeout" if broken.include?(version.digest)

        deleted << version.digest
        versions.delete(version)
        gone.include?(version.digest) ? :gone : :deleted
      end
    end
  end

  def version(name, age_days, tags: [])
    cleanup::Version.new(id: name.sum, digest: "sha256:#{name}", created_at: now - (age_days * 86_400), tags:)
  end

  def list(*children)
    cleanup::Manifest.new(media_type: cleanup::LIST_TYPES.first, children: children.map { |c| "sha256:#{c}" },
                          platforms: cleanup::PLATFORMS)
  end

  def image = cleanup::Manifest.new(media_type: cleanup::IMAGE_TYPES.first, children: [], platforms: [])

  # The live shape: edge with two children, and an orphan list from a re-run with its two children.
  def package
    versions = [ version("edge", 1, tags: %w[edge sha-a89f870]), version("e1", 1), version("e2", 1),
                 version("orphan", 9), version("o1", 9), version("o2", 9) ]
    registry.new(versions, { "edge" => list("e1", "e2"), "orphan" => list("o1", "o2"), "o1" => image, "o2" => image }
                             .transform_keys { |name| "sha256:#{name}" })
  end

  def run(client, delete: false) = described_class.new(client:, out:, now:, delete:).call

  it "dry-runs by default: deletes nothing and reports each selection and the counts (AC-4.1, FR-3)", :aggregate_failures do
    client = package
    run(client)
    expect(client.deleted).to be_empty
    expect(out.string).to include("Dry run: nothing is deleted")
    expect(out.string).to include("select sha256:orphan created 2026-10-11T12:00:00Z tags (none): orphan manifest list, unit age 9d 0h")
    expect(out.string).to include("select sha256:o1 created 2026-10-11T12:00:00Z tags (none): unreferenced image")
    expect(out.string).to include("6 versions: 1 tagged, 2 referenced, 0 too young, 3 selected")
  end

  it "reports young units with their ages (AC-4.3)" do
    client = registry.new([ version("fresh", 2.5) ], { "sha256:fresh" => image })
    run(client)
    expect(out.string).to include("too young sha256:fresh created 2026-10-18T00:00:00Z tags (none): unreferenced image, unit age 2d 12h")
  end

  it "deletes the orphan unit, list first, and nothing a tag needs (AC-1.2, AC-2.2, FR-1)", :aggregate_failures do
    client = package
    run(client, delete: true)
    expect(client.deleted).to eq(%w[sha256:orphan sha256:o1 sha256:o2])
    expect(out.string).to include("deleted sha256:orphan")
  end

  it "deletes nothing on a second run (AC-1.6)" do
    client = package
    run(client, delete: true)
    expect { run(client, delete: true) }.not_to(change { client.deleted.size })
  end

  it "fails naming the tag and digest when a tag's child is missing after deleting (AC-2.4)", :aggregate_failures do
    client = package
    client.missing << "sha256:e2"
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure, /tag edge, sha-a89f870 \(sha256:edge\): child sha256:e2 is missing/)
    expect(client.deleted).to eq(%w[sha256:orphan sha256:o1 sha256:o2])
  end

  it "skips the post-delete check when nothing was deleted" do
    client = registry.new([ version("edge", 1, tags: %w[edge]) ], { "sha256:edge" => list("e1", "e2") })
    client.missing << "sha256:e1"
    expect { run(client, delete: true) }.not_to raise_error
  end

  it "deletes nothing when a tagged manifest can't be read, naming the tag (AC-3.3)", :aggregate_failures do
    client = package
    client.manifests.delete("sha256:edge")
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure, /\Atag edge, sha-a89f870 \(sha256:edge\): GET .* answered 404/)
    expect(client.deleted).to be_empty
  end

  it "deletes nothing when a candidate can't be read, naming the digest (AC-3.5)", :aggregate_failures do
    client = package
    client.manifests.delete("sha256:o2")
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure, /\Asha256:o2: GET .* answered 404/)
    expect(client.deleted).to be_empty
  end

  it "stops at a refused delete, still checks the tags, and fails naming it (AC-3.6)", :aggregate_failures do
    client = package
    client.refuse["sha256:o1"] = 403
    client.missing << "sha256:e1"
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure) do |error|
      expect(error.message).to include("DELETE sha256:o1 answered 403", "child sha256:e1 is missing")
    end
    expect(client.deleted).to eq([ "sha256:orphan" ])
  end

  it "stops at a failed delete request and still checks the tags (AC-3.6)", :aggregate_failures do
    client = package
    client.broken << "sha256:o1"
    client.missing << "sha256:e1"
    expect { run(client, delete: true) }.to raise_error(cleanup::Failure) do |error|
      expect(error.message).to include("DELETE sha256:o1 failed: Net::ReadTimeout", "child sha256:e1 is missing")
    end
    expect(client.deleted).to eq([ "sha256:orphan" ])
  end

  it "reports a 404 on delete as already deleted and carries on (AC-3.9)", :aggregate_failures do
    client = package
    client.gone << "sha256:o1"
    run(client, delete: true)
    expect(out.string).to include("already deleted sha256:o1", "deleted sha256:o2")
    expect(client.deleted).to eq(%w[sha256:orphan sha256:o1 sha256:o2])
  end

  context "with the real client against stubbed GitHub and GHCR" do
    let(:client) { cleanup::Client.new(token: "gh-secret") }

    def entry(id, name, created, tags = [])
      { "id" => id, "name" => name, "created_at" => created, "metadata" => { "container" => { "tags" => tags } } }
    end

    def stub_manifest(digest, body, method: :get)
      stub_request(method, "#{cleanup::Client::REGISTRY}#{digest}")
        .to_return(body: body.to_json, headers: { "Content-Type" => body["mediaType"] || cleanup::IMAGE_TYPES.first })
    end

    def index(*children)
      { "mediaType" => cleanup::LIST_TYPES.first, "manifests" => children.zip(%w[amd64 arm64]).map do |digest, arch|
        { "digest" => digest, "platform" => { "os" => "linux", "architecture" => arch } }
      end }
    end

    it "deletes the orphan unit and checks the tag's children (AC-1.2, AC-2.4)", :aggregate_failures do
      stub_request(:get, "#{cleanup::Client::API}?per_page=100&page=1").to_return(body: [
        entry(1, "sha256:edge", "2026-10-19T00:00:00Z", %w[edge]), entry(2, "sha256:e1", "2026-10-19T00:00:00Z"),
        entry(3, "sha256:e2", "2026-10-19T00:00:00Z"), entry(4, "sha256:orphan", "2026-10-08T14:42:46Z"),
        entry(5, "sha256:o1", "2026-10-08T14:42:03Z") ].to_json)
      stub_request(:get, cleanup::Client::PULL_TOKEN).to_return(body: { token: "pull" }.to_json)
      [ [ "sha256:edge", index("sha256:e1", "sha256:e2") ], [ "sha256:orphan", index("sha256:o1", "sha256:o2") ],
        [ "sha256:o1", {} ] ].each { |digest, body| stub_manifest(digest, body) }
      %w[sha256:e1 sha256:e2].each { |digest| stub_manifest(digest, {}, method: :head) }
      deletes = [ 4, 5 ].map { |id| stub_request(:delete, "#{cleanup::Client::API}/#{id}").to_return(status: 204) }
      run(client, delete: true)
      expect(deletes).to all(have_been_requested.once)
      expect(out.string).to include("deleted sha256:orphan", "deleted sha256:o1")
    end
  end
end
  ```

- [ ] Add the command examples to `spec/lib/collector/ghcr_cleanup_spec.rb`, before its final `end`:

  ```ruby
  # The subprocess is not under WebMock: every example here must exit before any request.
  describe "bin/ghcr-cleanup" do
    let(:command) { Rails.root.join("bin/ghcr-cleanup").to_s }

    it "exits before any request without a token, naming GH_TOKEN (AC-3.7)", :aggregate_failures do
      _out, err, status = Open3.capture3({ "GH_TOKEN" => nil, "GITHUB_TOKEN" => nil }, command)
      expect(status).not_to be_success
      expect(err).to include("GH_TOKEN")
    end

    it "rejects unknown arguments", :aggregate_failures do
      _out, err, status = Open3.capture3({ "GH_TOKEN" => "unused" }, command, "--force")
      expect(status).not_to be_success
      expect(err).to include("usage: bin/ghcr-cleanup [--delete]")
    end
  end
  ```

  and add `require "open3"` below `require "rails_helper"` at the top of that file.
- [ ] Run: `bin/rspec spec/lib/collector/ghcr_cleanup/run_spec.rb spec/lib/collector/ghcr_cleanup_spec.rb` —
  expect: FAIL (`uninitialized constant Collector::GhcrCleanup::Run`, raised while loading `run_spec.rb`, so RSpec
  reports `0 examples, 1 error occurred outside of examples`).
- [ ] In `lib/collector/ghcr_cleanup.rb`, insert the class after `Client` and before the module's closing `end`:

  ```ruby
    # One run: read everything, plan, report, and (with delete: true) delete and check every tag afterwards.
    class Run
      def initialize(client:, out:, now: Time.now, delete: false)
        @client, @out, @now, @delete = client, out, now, delete
      end

      # Returns the plan; raises Failure when the run must fail (nothing deleted, or nothing after the failure).
      def call
        versions = @client.versions
        tagged = versions.select(&:tagged?)
        referenced = GhcrCleanup.referenced(tagged.to_h { |version| [ version, read(version) ] })
        candidates = versions.reject { |version| version.tagged? || referenced.include?(version.digest) }
        manifests = candidates.to_h { |version| [ version.digest, read(version) ] }
        plan = GhcrCleanup.plan(versions:, referenced:, manifests:, now: @now)
        report(plan)
        delete(plan, tagged) if @delete
        plan
      end

      private

      def read(version)
        @client.manifest(version.digest)
      rescue Failure => e
        raise Failure, "#{version.label}: #{e.message}"
      end

      def report(plan)
        @out.puts(@delete ? "Deleting orphans past the 7-day grace period." : "Dry run: nothing is deleted (pass --delete to delete).")
        plan.selected.each { |unit| describe(unit, "select") }
        plan.young.each { |unit| describe(unit, "too young") }
        counts = plan.counts
        @out.puts("#{counts.values.sum} versions: #{counts[:tagged]} tagged, #{counts[:referenced]} referenced, " \
                  "#{counts[:young]} too young, #{counts[:selected]} selected")
      end

      def describe(unit, verdict)
        age = GhcrCleanup.duration(unit.age(@now))
        unit.members.each do |version|
          kind = unit.lists.include?(version) ? "orphan manifest list" : "unreferenced image"
          @out.puts("#{verdict} #{version.digest} created #{version.created_at.utc.iso8601} tags (none): #{kind}, unit age #{age}")
        end
      end

      def delete(plan, tagged)
        removed, refusal = delete_all(plan.selected.flat_map(&:members))
        problems = removed.positive? ? check(tagged) : []
        raise Failure, [ refusal, *problems ].compact.join("\n") if refusal || problems.any?
      end

      # Returns [versions removed, failure message or nil]; stops at the first refusal or failed request (AC-3.6),
      # so the post-delete check still runs when something was removed before it.
      def delete_all(members)
        removed = 0
        members.each do |version|
          result = @client.delete(version)
          removed += 1
          @out.puts("#{result == :gone ? "already deleted" : "deleted"} #{version.digest}")
        end
        [ removed, nil ]
      rescue Failure => e
        [ removed, e.message ]
      end

      # AC-2.4: deleting a child leaves its tagged list intact, so check every child is still in the registry.
      def check(tagged)
        tagged.flat_map do |version|
          manifest = read(version)
          GhcrCleanup.check_tagged!(version, manifest)
          manifest.children.reject { |child| @client.fetchable?(child) }.map { |child| "#{version.label}: child #{child} is missing" }
        rescue Failure => e
          [ e.message ]
        end
      end
    end
  ```

- [ ] Write `bin/ghcr-cleanup` and make it executable (`chmod +x bin/ghcr-cleanup`):

  ```ruby
#!/usr/bin/env ruby
# Deletes untagged ghcr.io/plainprogrammer/collector versions that no tag needs, once their orphan unit is more
# than 7 days old (spec 013, docs/releasing.md). A dry run unless --delete. Reads the token from GH_TOKEN, else
# GITHUB_TOKEN:
#
#   GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup   # dry run
#   bin/ghcr-cleanup --delete                       # what the weekly workflow runs
require_relative "../lib/collector/ghcr_cleanup"

$stdout.sync = true # keep the deletions before a failure message in the Actions log
cleanup = Collector::GhcrCleanup
abort "usage: bin/ghcr-cleanup [--delete]" unless (ARGV - [ "--delete" ]).empty?

begin
  client = cleanup::Client.new(token: cleanup.token_from(ENV))
  cleanup::Run.new(client:, out: $stdout, delete: ARGV.include?("--delete")).call
rescue cleanup::Failure => e
  abort "ghcr-cleanup: #{e.message}"
end
  ```

- [ ] Run: `bin/rspec spec/lib/collector` — expect: all pass (`47 examples` across the three files, plus the
  existing `spec/lib/collector` examples).
- [ ] Run: `bin/rubocop bin/ghcr-cleanup lib/collector/ghcr_cleanup.rb spec/lib/collector` — expect: no offenses.
- [ ] Run: `git add bin/ghcr-cleanup && git ls-files -s bin/ghcr-cleanup` — expect: mode `100755`.
- [ ] Run (read-only, live): `GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup` — expect: exit 0, `Dry run: nothing is
  deleted`, and before 2026-10-15T14:42:46Z `18 versions: 5 tagged, 10 referenced, 3 too young, 0 selected` (or
  the counts of the package as it is then, summing to its version total).
- [ ] Commit: `feat(ghcr-cleanup): add the run and bin/ghcr-cleanup`

---

## Phase 4: Workflow, image and docs

**Implements:** FR-4, FR-5 | **Satisfies:** AC-1.5, AC-4.2, AC-5.1, AC-5.2 (file side)
**Files:** `.github/workflows/ghcr-cleanup.yml`, `.dockerignore`, `bin/image-smoke`, `docs/releasing.md`, `spec/image_publishing_spec.rb`
**Interfaces:** Consumes: Phase 3's `bin/ghcr-cleanup [--delete]`. Produces: the `GHCR cleanup` workflow with jobs
`dry-run` and `delete`; the releasing section `## Cleaning up untagged versions`.

The schedule, the permissions split, the image exclusions and the maintainer's documentation, checked as file
shapes like the rest of `spec/image_publishing_spec.rb`.

- [ ] In `spec/image_publishing_spec.rb`, add to `describe ".dockerignore"` (after the "still keeps secrets"
  example):

  ```ruby
    it "keeps the GHCR cleanup command out of the image and the smoke test checks it (AC-5.2, FR-5)", :aggregate_failures do
      expect(rules).to include("/bin/ghcr-cleanup", "/lib/collector/ghcr_cleanup.rb")
      expect(Rails.root.join("bin/image-smoke").read).to include("bin/ghcr-cleanup lib/collector/ghcr_cleanup.rb")
    end
  ```

  then add after the `describe ".github/workflows/ci.yml"` block:

  ```ruby
  describe ".github/workflows/ghcr-cleanup.yml" do
    let(:workflow) { YAML.load_file(Rails.root.join(".github/workflows/ghcr-cleanup.yml")) }
    let(:triggers) { workflow[true] || workflow["on"] } # Psych reads the YAML key `on` as true

    def job(name) = workflow.dig("jobs", name)
    def command(name) = job(name)["steps"].find { |candidate| candidate["run"]&.start_with?("bin/ghcr-cleanup") }

    it "runs weekly and by hand, never on pushes or pull requests (AC-1.5, FR-4)", :aggregate_failures do
      expect(triggers.keys).to contain_exactly("schedule", "workflow_dispatch")
      expect(triggers["schedule"]).to eq([ { "cron" => "0 6 * * 0" } ])
      expect(triggers.dig("workflow_dispatch", "inputs", "dry_run")).to include("type" => "boolean", "default" => true)
    end

    it "dry-runs by hand by default, without packages: write (AC-4.2, FR-4)", :aggregate_failures do
      expect(job("dry-run")["if"]).to eq("github.event_name == 'workflow_dispatch' && inputs.dry_run")
      expect(job("dry-run")["permissions"]).to eq("contents" => "read", "packages" => "read")
      expect(command("dry-run")["run"]).to eq("bin/ghcr-cleanup")
    end

    it "deletes on the schedule or an unticked dry_run, the only job with packages: write (AC-1.5, FR-4)", :aggregate_failures do
      expect(job("delete")["if"])
        .to eq("github.event_name == 'schedule' || (github.event_name == 'workflow_dispatch' && !inputs.dry_run)")
      expect(job("delete")["permissions"]).to eq("contents" => "read", "packages" => "write")
      expect(command("delete")["run"]).to eq("bin/ghcr-cleanup --delete")
      expect(workflow["permissions"]).to eq("contents" => "read")
    end

    it "passes the workflow token as GH_TOKEN and uses only GitHub's or ci.yml's actions (FR-4, NFR Security)", :aggregate_failures do
      expect(%w[dry-run delete].map { |name| command(name).dig("env", "GH_TOKEN") }).to all(eq("${{ secrets.GITHUB_TOKEN }}"))
      uses = workflow["jobs"].values.flat_map { |each_job| each_job["steps"].filter_map { |candidate| candidate["uses"] } }
      expect(uses).to all(start_with("actions/").or(start_with("ruby/setup-ruby@")))
    end
  end
  ```

  and add to `describe "docs/releasing.md"` (after the go-public example):

  ```ruby
    it "documents the cleanup: rule, grace period, schedule, manual and local runs, failures, token (AC-5.1)", :aggregate_failures do
      expect(doc).to include("## Cleaning up untagged versions", "more than\n  7 days old", "**Never deleted:**")
      expect(doc).to include("Sundays at 06:00 UTC", "The `dry_run` box is ticked by default")
      expect(doc).to include('GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup', "**A failed run failed closed:**")
      expect(doc).to include("Investigate the cause before re-running", "personal access token (classic")
    end
  ```

- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: FAIL (6 new examples: the `.dockerignore` rules,
  the missing workflow file, the missing section).
- [ ] Write `.github/workflows/ghcr-cleanup.yml`:

  ```yaml
name: GHCR cleanup

# Deletes untagged ghcr.io/plainprogrammer/collector versions that no tag needs, once their orphan unit is more
# than 7 days old (spec 013, ADR 0011, docs/releasing.md). The weekly run deletes; a run started by hand is a dry
# run unless dry_run is unticked. bin/ghcr-cleanup checks every tag after deleting.
on:
  schedule:
    - cron: "0 6 * * 0" # Sundays 06:00 UTC
  workflow_dispatch:
    inputs:
      dry_run:
        description: Report what would be deleted and delete nothing
        type: boolean
        default: true

permissions:
  contents: read

jobs:
  dry-run:
    if: github.event_name == 'workflow_dispatch' && inputs.dry_run
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v7

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1

      - name: Dry run
        run: bin/ghcr-cleanup
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  delete:
    if: github.event_name == 'schedule' || (github.event_name == 'workflow_dispatch' && !inputs.dry_run)
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v7

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1

      - name: Delete orphans
        run: bin/ghcr-cleanup --delete
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  ```

- [ ] Append to `.dockerignore`, at column 0 (a blank line, then):

```
# The GHCR cleanup command runs only in its workflow and locally (spec 013).
/bin/ghcr-cleanup
/lib/collector/ghcr_cleanup.rb
```

- [ ] In `bin/image-smoke`, extend the absent-path loop's list: replace
  `for path in docs spikes spec script .claude CLAUDE.md .githooks orca.yaml .worktreeinclude config/master.key .kamal; do`
  with
  `for path in docs spikes spec script .claude CLAUDE.md .githooks orca.yaml .worktreeinclude config/master.key .kamal bin/ghcr-cleanup lib/collector/ghcr_cleanup.rb; do`.
- [ ] Append to `docs/releasing.md` (after the go-public section's last line, "Then cut `v0.1.0` as above so that
  `latest` exists for the README's instructions."):

  ````markdown
## Cleaning up untagged versions

Every publish leaves untagged versions in the package: the two per-architecture images behind each tagged
manifest list and, after a re-run, the previous manifest list with its images. The **GHCR cleanup** workflow
(`.github/workflows/ghcr-cleanup.yml`, spec 013) runs `bin/ghcr-cleanup` to remove the ones nothing needs.

- **Deleted:** untagged versions that no tagged manifest list references, once their orphan unit is more than
  7 days old. A unit is an untagged manifest list with its unreferenced images, or a lone untagged image; it is
  deleted together, manifest lists first.
- **Never deleted:** a tagged version (`latest`, `X.Y.Z`, `X.Y`, `edge`, `sha-*`), or an image that a tagged
  manifest list references, whatever its age.
- **Schedule:** Sundays at 06:00 UTC, deleting. After deleting, the run checks that every tag still lists
  `linux/amd64` and `linux/arm64` and that each of their images is still in the registry.

**Running it by hand:** Actions → **GHCR cleanup** → **Run workflow**. The `dry_run` box is ticked by default:
the run lists what it would delete and deletes nothing. Untick it to delete.

**Local dry run** (with `gh` logged in):

```sh
GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup
```

It prints each version it would delete (`select`) or keeps for now (`too young`) with its unit's age, then
the counts of tagged, referenced, too young and selected versions. Leave `--delete` to the workflow.

**A failed run failed closed:** it deleted nothing, or nothing after the failure, and its log names the tag,
digest or request that stopped it: a tag that is not a two-architecture manifest list, a manifest it could
not read, a refused delete, or a tag whose image went missing. Investigate the cause before re-running, and
never delete versions by hand to get past it.

**Token:** the workflow uses its own `GITHUB_TOKEN`, which may delete versions of a package that the
repository's workflow published (GitHub documents this as a public preview). If a delete is refused with
`answered 401` or `answered 403`, create a personal access token (classic; GitHub Packages does not accept
fine-grained tokens) with `read:packages` and `delete:packages`, store it as the repository secret
`GHCR_CLEANUP_TOKEN`, and change both `GH_TOKEN:` lines in the workflow to
`${{ secrets.GHCR_CLEANUP_TOKEN }}`. Rotate it before it expires by replacing the secret.
  ````

- [ ] Run: `bin/rspec spec/image_publishing_spec.rb` — expect: all pass (`21 examples, 0 failures`).
- [ ] Run: `bin/rubocop spec/image_publishing_spec.rb` — expect: no offenses.
- [ ] Commit: `ci(ghcr-cleanup): add the weekly cleanup workflow, image exclusions and docs`

---

## Phase 5: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs; evidence for AC-2.5, AC-4.3, AC-5.2 (image) and the Open Question
**Files:** `docs/specs/013-ghcr-untagged-cleanup/verification.md`
**Interfaces:** Consumes: everything above. Produces: `verification.md` with the evidence per AC.

The local gate, the pull request's image builds, then the maintainer's live steps after the merge.

- [ ] Run: `bin/ci` — expect: every step green (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec).
- [ ] Write `verification.md` with an AC table (AC, evidence, status) and record: the `bin/ci` result; the Phase 3
  live dry-run output (AC-4.3 so far, AC-4.1); the spec files and example names per AC.
- [ ] Commit: `docs(013): record verification evidence`
- [ ] Push the branch and open the pull request (body ends with the attribution line). Expect: the `ci` job and
  both `Image` jobs green; the `Smoke test` step on amd64 and arm64 passes with the extended absent-path list
  (AC-5.2). Record the run URL in `verification.md`.
- [ ] Run `sdd-superpowers:sdd-review` (Mode B) before merging.
- [ ] **Maintainer, after the merge:** Actions → **GHCR cleanup** → **Run workflow** with `dry_run` ticked.
  Expect: only the `dry-run` job runs, green, and its log matches the local dry run (AC-4.2; confirms the
  workflow token can list the package through the `/users/` endpoint).
- [ ] **Maintainer, after 2026-10-15T14:42:46Z:** a local dry run lists the three `f03eb827…` unit members as
  `select` (AC-4.3). Then Actions → **GHCR cleanup** → **Run workflow** with `dry_run` unticked (or wait for the
  Sunday 2026-10-18 06:00 UTC run). Expect: only the `delete` job runs, it prints `deleted` for the three, and it
  ends green after its post-delete check (AC-1.2, AC-2.4). A refused delete (`answered 403`) answers the Open
  Question the other way: follow the token fallback in `docs/releasing.md`.
- [ ] **Maintainer, after that run (AC-2.5):**

  ```sh
  podman logout ghcr.io
  for tag in latest 0.1.0 edge; do
    for arch in amd64 arm64; do podman pull --arch "$arch" "ghcr.io/plainprogrammer/collector:$tag"; done
  done
  ```

  Expect: six successful pulls. A second dry run prints `0 selected` (AC-1.6).
- [ ] Record the workflow run URLs, the pull output and the Open Question's answer in `verification.md`;
  commit `docs(013): record live cleanup evidence`; close issue #17.

---

## Quickstart Validation

```sh
bin/rspec spec/lib/collector/ghcr_cleanup_spec.rb spec/lib/collector/ghcr_cleanup spec/image_publishing_spec.rb
GH_TOKEN="$(gh auth token)" bin/ghcr-cleanup          # dry run against the live package; deletes nothing
env -u GH_TOKEN -u GITHUB_TOKEN bin/ghcr-cleanup; echo $?   # 1, names GH_TOKEN
```

Then, on GitHub: Actions → **GHCR cleanup** → **Run workflow** (dry run by default).
