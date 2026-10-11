# Implementation Plan: Content Notice Footer

**Spec:** docs/specs/018-content-notice-footer/spec.md (v1.2.1, Approved, reviewed twice)
**Decisions:** [ADR 0018](../../adr/0018-collectible-agnostic-catalog-core.md) (collectible-agnostic catalog core), Accepted. No new ADR: the footer uses the source contract's existing pattern of optional hooks.
**Created:** 2026-10-11
**Revised:** 2026-10-11, after a read-only plan review (Fable, READY TO EXECUTE, nothing blocking; all blocks byte-identical to the phase commits, Phases 0 and 1 run from scratch copies, the rest traced by hand). Its findings, applied to the phase commits and re-run: the phone test frame is 320px tall, not 480px, so the More page scrolls with room to spare; the card page block's comment in `additions.css` no longer says "attribution"; a link phrase or address a source marked `html_safe` is still plain text (`String.new`), with an example; following a footer link from the scanner mid-sitting is listed with what no example covers and is in the quickstart. Considered and not taken: giving the footer the tab bar's clearance only on pages that have a tab bar (pages without one keep the band `c-main` already left there today), and collecting the lines through a helper instead of the layout calling `Catalog::ContentNotice.lines`.

**How this plan was made.** Every code block below was written, run and linted before the plan was. The feature was prototyped in the worktree, then replayed as one commit per phase on a local branch (`018-plan-phases`, commits `db94f89` to `0e7e3ca`, on top of `8e89c3d`). At each phase's commit that phase's specs and RuboCop were green, and each phase's specs were first run against the previous commit to record how they fail. At the last commit the whole suite, RuboCop, Brakeman and `zeitwerk:check` were green (1,178 examples, 0 failures, 1 pending). The blocks are rendered from those commits by script: a new file is shown whole, a changed file as the exact diff. That branch is local only, was never pushed, and is deleted once this plan is executed.

## Global Constraints

- The notice's wording is exact (FR-1): "Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC." and "Card data and images provided by Scryfall."
- The two links are exact: "Fan Content Policy" to `https://company.wizards.com/en/legal/fancontentpolicy`, "Scryfall" to `https://scryfall.com` (AC-1.9, AC-1.10).
- The core's footer code (the layout, `layouts/_footer.html.erb`, `app/models/catalog/content_notice.rb`) never contains "mtg", "magic", "wizards", "scryfall" or "fan content" in any case, in text or in an address (AC-2.5). Comments count.
- Notice text and link phrases are escaped. No `html_safe`, `raw` or `<%==` (Security). An address reaches an `href` only when it is an absolute `https` URI.
- The footer is text and links only: no image, logo, icon, button or form control, no inline style or script (AC-3.5, AC-4.1). The scanner pages' Content-Security-Policy is not changed (AC-4.2).
- The footer is rendered by the layout, once. No view renders it (FR-2). It runs no database query and reads nothing.
- It is never fixed or sticky, and it sits directly after the content (AC-3.3).
- CSS uses only design-system tokens and `c-*` classes. New rules go at the end of `collector/additions.css` in one block of their own; `collector/components.css` and `tokens.css` are not edited (they are replaced wholesale by a re-export). The one literal, `80px`, is the tab bar clearance `components.css` already gives `c-main` below 640px.
- Nothing else on the card page changes; its image rules belong to spec 019. `README.md` is not touched (maintainer's ruling).
- No new gem, no JavaScript, no migration, no setting or environment variable.
- `bin/ci` passes at every commit: each phase commits its specs with its code, never a failing spec.
- Commits are Conventional Commits, one per phase, with the attribution trailer. Stage and commit in separate commands (the pre-commit hook reads the command text).
- Spec types are tagged explicitly; multi-expectation examples use `:aggregate_failures`. Phone widths are tested in a frame (`spec/support/narrow_frame.rb`), since headless Firefox won't open a window under 500px.

---

## Goal

Every page rendered with the application layout ends with one footer carrying the Fan Content Policy notice and the Scryfall attribution, supplied by the Magic catalog's source through a new optional hook, so the core names neither.

**Pre-implementation gates.** Simplicity: three parts (a small core module, one source hook, one partial with its CSS block); nothing is built for a future need. Anti-abstraction: `link_to`, `Data.define` and the layout are used directly; a line has one representation (`Catalog::ContentNotice::Line`) from the source to the view. Integration-first: Phase 0 writes the contract's documentation and its spec before the module. All three pass, so no phase carries a complexity note.

**Facts established during planning (2026-10-11), each checked by running it:**

- Every view puts its app header and tab bar into `content_for` (`layouts/_appbar`, `layouts/_tabbar`) and renders its own `<main>` as the layout's `yield`. A footer rendered between `yield` and `yield :tabbar` is therefore the element straight after `<main>` on every page, and before the tab bar's `<nav>` (asserted in Phase 2).
- A request with a `Turbo-Frame` header is rendered by turbo-rails without the application layout, so it gets no footer with no code of ours; the same address without the header is a page and gets one (AC-1.8, asserted in Phase 2).
- Below 640px `components.css` gives `c-main` `80px + env(safe-area-inset-bottom)` of bottom padding to clear the fixed tab bar. With a footer after it, that padding would sit between the content and the footer, and the footer itself would end under the bar. The footer's block moves the clearance: the footer takes it and `c-main` gives it up, through `.c-shell:has(> .c-footer) > .c-main`. This is the first `:has()` in the stylesheets (Firefox 121, Safari 15.4, Chrome 105 and later). A browser without it shows a taller gap above the footer and nothing worse. Both rules were proved by removing each once: Phase 3's phone examples fail without either. Pages with no tab bar (sign-in, sign-up) keep the same empty band at their end below 640px that `c-main` leaves there today.
- `<body>` has the browser's default 8px margin today (nothing resets it), so the page's real gutter is 8px wider than the token. The system spec measures the footer against `c-main`'s own content edge, not against a number.
- The scanner page's policy sets `frame-src 'none'`, so the phone-width test frame can't be opened from the scanner page itself. The spec opens it from the collection page.
- The scanner page grows while the camera starts. Measuring the scanner and the footer in two separate script calls raced once in a full-suite run; the spec measures both in one call.
- A system example's window keeps the size the previous example's driver gave it. The short-page example sets its own window size.
- Programmatic focus shows the focus ring in Firefox when asked to (`focus({ focusVisible: true })`), which lets the spec assert the ring without synthesising Tab presses.
- `Catalog.sources` keeps registration order (a Hash), and the `mtg` type is registered first, so test-only types registered in an example come after it.
- Run against the code before each phase, the phases' specs fail as the steps below say.

**Overlap with spec 019 (issue #35), which is being built in parallel.** Both branches append a block to the end of `collector/additions.css`, add an "App additions (spec 01x…)" line after spec 015's in `docs/design-system/README.md`, and may add a name to the list in `spec/design_system_files_spec.rb` and a file to `.rubocop.yml`'s `RSpec/DescribeClass` list. Each is an adjacent-line conflict to resolve by keeping both. This plan removes one line inside the card page's block of `additions.css` (`.c-attribution`) and one line of `catalog/entries/show.html.erb`; it touches no image rule.

---

## Phase 0: The contract and its collector

**Implements:** FR-1 (the hook and a line's rules), FR-2 (order, one line once, nothing when there is none, no query) | **Satisfies:** AC-2.1, AC-2.2, AC-2.3, AC-2.4 at the model; Error Scenarios (missing hook, blank lines, bad links, a hook that raises)
**Files:** `app/models/catalog/sources.rb` (contract documentation), `spec/support/fake_catalog_source.rb` (test-only catalog types), `spec/models/catalog/content_notice_spec.rb` (new), `app/models/catalog/content_notice.rb` (new)
**Interfaces:** Consumes: `Catalog.sources` (`{ "type" => "SourceClassName" }`, in registration order). Produces: the optional source hook `.content_notice` returning an Array of `Catalog::ContentNotice::Line`; `Catalog::ContentNotice::Line.new(text:, links: {})` with `#text` (String, trimmed), `#links` (frozen Hash of phrase String to address String) and `#parts` (Array of `[String, String or nil]` in reading order, the second member the `https` address or nil); `Catalog::ContentNotice.lines` (Array of `Line`). Spec helpers for later phases: `register_notice_catalog(type, *lines, &hook)`, `with_catalog_sources(hash) { … }`, `notice_line(text, links = {})`.

The contract comes first: the hook is documented where sources look for it, then specified, then built. A line is plain text plus the phrases of it that link out. `#parts` is the only place the link rules live (FR-1): each phrase exactly once and case-sensitively, no overlap, an absolute `https` address; a line that breaks any of them is one part of plain text.

- [ ] Document the hook in the source contract:

```diff
diff --git a/app/models/catalog/sources.rb b/app/models/catalog/sources.rb
index 2f85352..08473f7 100644
--- a/app/models/catalog/sources.rb
+++ b/app/models/catalog/sources.rb
@@ -18,6 +18,10 @@
 #                                       file read, its size), so the run can show a percentage (spec 015 FR-2)
 #   .title                              optional: what the admin catalog page calls this catalog ("Magic: The Gathering")
 #   .operations(collectible_type)       optional: extra Catalog::Operation objects for the admin catalog page
+#   .content_notice                     optional: the Catalog::ContentNotice::Line objects every page's footer shows for
+#                                       this type, in order: what the content's owner asks to be said, and who provides
+#                                       the data. Plain text, with the phrases that link out and their https addresses.
+#                                       It is the same for every request and reads nothing (spec 018 FR-1)
 module Catalog::Sources
   SetRecord = Data.define(:code, :name, :released_on, :parent_code) do
     def digest = Catalog::Sources.digest(to_h)
```

- [ ] Add the test-only catalog types' helpers to the end of `spec/support/fake_catalog_source.rb`:

```diff
diff --git a/spec/support/fake_catalog_source.rb b/spec/support/fake_catalog_source.rb
index 72fe3fd..2b51923 100644
--- a/spec/support/fake_catalog_source.rb
+++ b/spec/support/fake_catalog_source.rb
@@ -110,3 +110,30 @@ module CatalogRecordHelpers
 end
 
 RSpec.configure { |config| config.include CatalogRecordHelpers }
+
+# Catalog types for the content notice's specs (spec 018). `register_notice_catalog("zeta", line, …)` adds a type,
+# after the app's own, whose source supplies those lines; `with_catalog_sources("other" => "OtherCatalogSource") { … }`
+# swaps the whole registry for a block. Both are undone after the example.
+module NoticeCatalogHelpers
+  def register_notice_catalog(type, *lines, &hook)
+    name = "#{type.camelize}NoticeSource"
+    stub_const(name, Class.new(FakeCatalogSource) { define_singleton_method(:content_notice, &(hook || -> { lines })) })
+    (@notice_catalogs ||= []) << type
+    Catalog.sources[type] = name
+  end
+
+  def with_catalog_sources(sources)
+    registered = Catalog.sources
+    Catalog.sources = sources
+    yield
+  ensure
+    Catalog.sources = registered
+  end
+
+  def notice_line(text, links = {}) = Catalog::ContentNotice::Line.new(text:, links:)
+end
+
+RSpec.configure do |config|
+  config.include NoticeCatalogHelpers
+  config.after { @notice_catalogs&.each { |type| Catalog.sources.delete(type) } }
+end
```

- [ ] Write the spec, `spec/models/catalog/content_notice_spec.rb`. Its `.lines` examples register only test-only types, so they hold whatever the app's own types supply:

```ruby
require "rails_helper"

# Spec 018 FR-1 and FR-2: the lines every page's footer shows, and how one line's links are read.
RSpec.describe Catalog::ContentNotice, type: :model do
  describe ".lines" do
    # Only test-only types are registered here, so these examples hold whatever the app's own types supply.
    around { |example| with_catalog_sources({}) { example.run } }

    let(:owner) { notice_line("Zeta is shown with its owner's leave.") }
    let(:credit) { notice_line("Data from Zeta Base.", "Zeta Base" => "https://zeta.test") }

    it "gives types in registration order, each type's lines in the order its source supplies them (AC-2.1)" do
      register_notice_catalog("zeta", owner, credit)
      register_notice_catalog("eta", notice_line("Data from Eta."))

      expect(described_class.lines.map(&:text)).to eq([ "Zeta is shown with its owner's leave.", "Data from Zeta Base.", "Data from Eta." ])
    end

    it "takes nothing from a source without the hook (AC-2.2)" do
      Catalog.sources["other"] = "OtherCatalogSource"
      register_notice_catalog("zeta", owner)

      expect(described_class.lines).to eq([ owner ])
    end

    it "takes nothing from a hook that gives nil or no lines" do
      register_notice_catalog("eta") { nil }
      register_notice_catalog("theta")
      register_notice_catalog("zeta", owner)

      expect(described_class.lines).to eq([ owner ])
    end

    it "is empty when no type supplies a notice, or none is registered (AC-2.3)", :aggregate_failures do
      expect(described_class.lines).to eq([])

      Catalog.sources["other"] = "OtherCatalogSource"
      expect(described_class.lines).to eq([])
    end

    it "shows a line two types supply once, where the first type puts it (AC-2.4)" do
      register_notice_catalog("zeta", owner, credit)
      register_notice_catalog("eta", notice_line("Data from Eta."), notice_line("  #{credit.text} ", credit.links))

      expect(described_class.lines.map(&:text)).to eq([ owner.text, credit.text, "Data from Eta." ])
    end

    it "keeps two lines with the same text and different links apart" do
      register_notice_catalog("zeta", notice_line(credit.text), credit)

      expect(described_class.lines.map(&:links)).to eq([ {}, { "Zeta Base" => "https://zeta.test" } ])
    end

    it "never gives a blank line" do
      register_notice_catalog("zeta", notice_line(""), notice_line(" \n "), notice_line(nil), owner)

      expect(described_class.lines).to eq([ owner ])
    end

    it "doesn't rescue a hook that raises" do
      register_notice_catalog("zeta") { raise "broken source" }

      expect { described_class.lines }.to raise_error("broken source")
    end
  end

  describe "Line#parts" do
    it "is the whole text when the line has no links" do
      expect(notice_line("Data from Zeta Base.").parts).to eq([ [ "Data from Zeta Base.", nil ] ])
    end

    it "splits the text around a link's phrase" do
      expect(notice_line("Data from Zeta Base.", "Zeta Base" => "https://zeta.test/about").parts)
        .to eq([ [ "Data from ", nil ], [ "Zeta Base", "https://zeta.test/about" ], [ ".", nil ] ])
    end

    it "puts links in reading order whatever order they were given in, with nothing empty between them" do
      line = notice_line("Zeta Base and Eta", "Eta" => "https://eta.test", "Zeta Base" => "https://zeta.test")

      expect(line.parts).to eq([ [ "Zeta Base", "https://zeta.test" ], [ " and ", nil ], [ "Eta", "https://eta.test" ] ])
    end

    it "accepts an https scheme in any case" do
      expect(notice_line("Zeta", "Zeta" => "HTTPS://zeta.test").parts).to eq([ [ "Zeta", "HTTPS://zeta.test" ] ])
    end

    [ [ "a phrase that isn't in the text", { "Eta" => "https://eta.test" } ],
      [ "a phrase in another case", { "zeta base" => "https://zeta.test" } ],
      [ "a phrase that occurs twice", { "Zeta" => "https://zeta.test" } ],
      [ "phrases that overlap", { "Zeta Base" => "https://zeta.test", "Base of" => "https://eta.test" } ],
      [ "an empty phrase", { "" => "https://zeta.test" } ],
      [ "an http address", { "Zeta Base" => "http://zeta.test" } ],
      [ "a script address", { "Zeta Base" => "javascript:alert(1)" } ],
      [ "a relative address", { "Zeta Base" => "/about" } ],
      [ "a bare host", { "Zeta Base" => "zeta.test" } ],
      [ "an address that isn't a URI", { "Zeta Base" => "https://zeta test" } ],
      [ "one good link and one bad", { "Zeta Base" => "https://zeta.test", "data" => "http://eta.test" } ]
    ].each do |fault, links|
      it "is plain text, with no link at all, for #{fault}" do
        text = "Zeta Base of Zeta data."

        expect(notice_line(text, links).parts).to eq([ [ text, nil ] ])
      end
    end

    it "counts a phrase that overlaps itself as occurring twice" do
      expect(notice_line("aaa", "aa" => "https://zeta.test").parts).to eq([ [ "aaa", nil ] ])
    end
  end

  describe "Line" do
    it "trims its text and compares by text and links", :aggregate_failures do
      expect(notice_line("  Data from Zeta Base.\n")).to eq(notice_line("Data from Zeta Base."))
      expect(notice_line("Zeta", "Zeta" => "https://zeta.test")).not_to eq(notice_line("Zeta"))
      expect(notice_line("Zeta", Zeta: "https://zeta.test")).to eq(notice_line("Zeta", "Zeta" => "https://zeta.test"))
    end

    it "keeps a phrase plain text even when a source marked it html_safe" do
      phrase, address = notice_line("Zeta".html_safe, "Zeta".html_safe => "https://zeta.test".html_safe).parts.first

      expect([ phrase, address ].map(&:html_safe?)).to eq([ false, false ])
    end
  end
end
```

- [ ] Run: `bin/rspec spec/models/catalog/content_notice_spec.rb` — expect: FAIL before any example runs, `NameError: uninitialized constant Catalog::ContentNotice` (`0 examples, 0 failures, 1 error occurred outside of examples`)
- [ ] Implement `app/models/catalog/content_notice.rb`:

```ruby
# The content notices in every page's footer (spec 018): what each catalog type's source asks to be said about its
# content, and where its data comes from. A source supplies its lines through the optional .content_notice hook
# (app/models/catalog/sources.rb). The core shows them in order and knows nothing of what they say or link to.
module Catalog::ContentNotice
  # One line of a notice: plain text, and the phrases of it that are links ({ "phrase" => "https://…" }).
  Line = Data.define(:text, :links) do
    def initialize(text:, links: {})
      # String.new: a phrase a source marked html_safe is still plain text here, so the view escapes it.
      super(text: text.to_s.strip, links: links.to_h.to_h { |phrase, address| [ String.new(phrase.to_s), String.new(address.to_s) ] }.freeze)
    end

    # The line in reading order as [text, address] parts, the address nil where the text isn't a link. A line with a
    # link that breaks a rule (FR-1) is one part of plain text.
    def parts
      return [ [ text, nil ] ] unless linked?

      cursor = 0
      linked = spans.flat_map do |start, phrase, address|
        before = text[cursor...start]
        cursor = start + phrase.length
        [ [ before, nil ], [ phrase, address ] ]
      end
      (linked << [ text[cursor..], nil ]).reject { |part, _| part.empty? }
    end

    private
      # Every phrase occurs exactly once, no two overlap, and every address is an absolute https URI.
      def linked?
        links.any? && links.all? { |phrase, address| once?(phrase) && https?(address) } &&
          spans.each_cons(2).all? { |(start, phrase, _), (following, _, _)| start + phrase.length <= following }
      end

      def spans = links.map { |phrase, address| [ text.index(phrase), phrase, address ] }.sort_by(&:first)

      def once?(phrase) = phrase.present? && text.index(phrase).present? && text.index(phrase) == text.rindex(phrase)

      def https?(address)
        uri = URI.parse(address)
        uri.is_a?(URI::HTTPS) && uri.host.present?
      rescue URI::InvalidURIError
        false
      end
  end

  # Every registered type's lines: types in registration order, each type's lines in the order its source gives
  # them, a repeated line (the same text and links) once, where it first appears. No query, no I/O.
  def self.lines
    Catalog.sources.each_value.flat_map { |name| lines_of(name.constantize) }.reject { |line| line.text.empty? }.uniq
  end

  def self.lines_of(source) = source.respond_to?(:content_notice) ? Array(source.content_notice) : []
  private_class_method :lines_of
end
```

- [ ] Run: `bin/rspec spec/models/catalog/content_notice_spec.rb spec/models/catalog_spec.rb` — expect: PASS, `32 examples, 0 failures`
- [ ] Run: `bin/rails zeitwerk:check` — expect: `All is good!`
- [ ] Run: `bin/rubocop` — expect: `no offenses detected`
- [ ] Commit: `feat(catalog): collect each source's content notice`

---

## Phase 1: The Magic catalog's notice

**Implements:** FR-1 (the `mtg` type's two lines) | **Satisfies:** the wording and addresses behind AC-1.1, AC-1.2, AC-1.9, AC-1.10
**Files:** `spec/models/mtg/scryfall/source_spec.rb`, `app/models/mtg/scryfall/source.rb`
**Interfaces:** Consumes: `Catalog::ContentNotice::Line.new(text:, links:)` from Phase 0. Produces: `MTG::Scryfall::Source.content_notice`, an Array of two `Line`s: the notice (link "Fan Content Policy"), then the attribution (link "Scryfall").

The wording lives in the Magic namespace and nowhere else. The spec pins it character for character, and checks that both links survive `#parts` (each phrase really occurs once).

- [ ] Add the example to `spec/models/mtg/scryfall/source_spec.rb`:

```diff
diff --git a/spec/models/mtg/scryfall/source_spec.rb b/spec/models/mtg/scryfall/source_spec.rb
index 960cbb1..9dc760c 100644
--- a/spec/models/mtg/scryfall/source_spec.rb
+++ b/spec/models/mtg/scryfall/source_spec.rb
@@ -14,6 +14,20 @@ RSpec.describe MTG::Scryfall::Source, type: :model do
     expect(described_class::ALLOWED_HOSTS).to include("cards.scryfall.io")
   end
 
+  # Spec 018 FR-1: the Fan Content Policy's wording with "Collector" as the title, and the attribution, each with its link.
+  it "supplies the unofficial-content notice and the source attribution for the footer", :aggregate_failures do
+    notice, attribution = described_class.content_notice
+
+    expect(notice.text).to eq("Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. " \
+      "Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.")
+    expect(notice.links).to eq("Fan Content Policy" => "https://company.wizards.com/en/legal/fancontentpolicy")
+    expect(attribution.text).to eq("Card data and images provided by Scryfall.")
+    expect(attribution.links).to eq("Scryfall" => "https://scryfall.com")
+    expect(described_class.content_notice.size).to eq(2)
+    expect(described_class.content_notice.flat_map(&:parts).filter_map(&:last))
+      .to eq([ "https://company.wizards.com/en/legal/fancontentpolicy", "https://scryfall.com" ])
+  end
+
   describe "#reapply?" do
     it "asks once for a catalog whose printings have no artwork ids yet (spec 011 AC-2.3)", :aggregate_failures do
       expect(source.reapply?).to be(false) # an empty catalog applies anyway
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/source_spec.rb` — expect: FAIL, `18 examples, 1 failure`: the new example, `NoMethodError: undefined method 'content_notice' for class MTG::Scryfall::Source`
- [ ] Implement the hook in `app/models/mtg/scryfall/source.rb`:

```diff
diff --git a/app/models/mtg/scryfall/source.rb b/app/models/mtg/scryfall/source.rb
index 702039f..4335c0a 100644
--- a/app/models/mtg/scryfall/source.rb
+++ b/app/models/mtg/scryfall/source.rb
@@ -17,6 +17,16 @@ class MTG::Scryfall::Source
   def self.title = "Magic: The Gathering"
   def self.operations(collectible_type) = [ MTG::Art::Operation.new(collectible_type) ]
 
+  # Spec 018 FR-1: this catalog's lines in every page's footer. First the notice Wizards of the Coast's Fan Content
+  # Policy asks for, word for word with the app as its title; then where the data comes from.
+  def self.content_notice
+    [ Catalog::ContentNotice::Line.new(
+        text: "Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. " \
+          "Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.",
+        links: { "Fan Content Policy" => "https://company.wizards.com/en/legal/fancontentpolicy" }),
+      Catalog::ContentNotice::Line.new(text: "Card data and images provided by Scryfall.", links: { "Scryfall" => "https://scryfall.com" }) ]
+  end
+
   # Spec 015 FR-2: a callable the refresh sets; called with (done, total) bytes of the download, then of the file read.
   attr_writer :progress
 
```

- [ ] Run: `bin/rspec spec/models/mtg/scryfall/source_spec.rb spec/models/catalog/content_notice_spec.rb` — expect: PASS, `44 examples, 0 failures`
- [ ] Run: `bin/rubocop` — expect: `no offenses detected`
- [ ] Commit: `feat(mtg): supply the Fan Content notice and the Scryfall attribution`

---

## Phase 2: The footer on every page

**Implements:** FR-2, FR-3 (the card page's line and its rule) | **Satisfies:** AC-1.1 to AC-1.10, AC-2.1 to AC-2.7, AC-3.5, AC-3.8 (attributes), AC-4.2, AC-4.3
**Files:** `spec/requests/footer_spec.rb` (new), `spec/footer_core_spec.rb` (new), `.rubocop.yml`, `spec/requests/catalog/entries_show_spec.rb`, `app/views/layouts/_footer.html.erb` (new), `app/views/layouts/application.html.erb`, `app/views/catalog/entries/show.html.erb`, `app/assets/stylesheets/collector/additions.css` (one rule removed)
**Interfaces:** Consumes: `Catalog::ContentNotice.lines` and `Line#parts` from Phase 0; `MTG::Scryfall::Source.content_notice` from Phase 1; the spec helpers `register_notice_catalog`, `with_catalog_sources`, `notice_line` from Phase 0. Produces: the partial `layouts/footer` (local `lines`), rendering `<footer class="c-footer">` with one `<p>` per line and `<a rel="noopener" href="…">` per link, as a direct child of `<body>` straight after the page's `<main>`; no element when `lines` is empty. Phase 3 styles `.c-footer`, `.c-footer p` and `.c-footer a`.

The layout renders the partial between `yield` and `yield :tabbar`, so no page does anything to get it. The card page's own attribution line goes, with the `.c-attribution` rule nothing else uses. The footer is unstyled until Phase 3; it is already complete and correct as a document.

- [ ] Write `spec/requests/footer_spec.rb`:

```ruby
require "rails_helper"

# Spec 018: every page carries one footer with the content notices of the registered catalog types.
RSpec.describe "The footer", type: :request do
  let(:notice) do
    "Collector is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. " \
      "Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."
  end
  let(:attribution) { "Card data and images provided by Scryfall." }
  let(:links) { [ [ "Fan Content Policy", "https://company.wizards.com/en/legal/fancontentpolicy" ], [ "Scryfall", "https://scryfall.com" ] ] }

  def html = Nokogiri::HTML5(response.body)

  def footers = html.css("footer")

  def footer = html.at_css("body > footer.c-footer")

  def lines = footer.css("> p").map(&:text)

  # The one footer, straight after the page's main content where it has one, with both lines and their two links.
  def expect_the_footer(on)
    expect(footers.size).to eq(1), "#{on}: #{footers.size} footers"
    expect(lines).to eq([ notice, attribution ]), on
    expect(footer.css("a").map { |link| [ link.text, link["href"] ] }).to eq(links), on
    expect(html.css("body > main + footer.c-footer").size).to eq(1), "#{on}: not straight after main" if html.at_css("main")
  end

  describe "for a signed-in collector" do
    let(:user) { create(:user) }
    let(:lot) { create(:lot, account: user.account) }

    before { sign_in_as(user) }

    it "is on every page, after the main content (AC-1.1, AC-1.2, AC-1.6, AC-1.9, AC-1.10)", :aggregate_failures do
      [ collection_path, collection_path(view: "table"), collection_path(view: "table", bulk: 1), catalog_entries_path,
        catalog_entries_path(q: lot.entry.name), catalog_entry_path(lot.entry), catalog_identity_path(lot.entry.identity),
        scanner_path, more_path, new_catalog_entry_lot_path(lot.entry), edit_lot_path(lot),
        new_lot_removal_path(lot) ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect_the_footer(path)
      end
    end

    it "sits between the main content and the tab bar" do
      get collection_path

      expect(html.css("body > *").map(&:name).last(3)).to eq(%w[main footer nav])
    end

    it "is there while the catalog isn't loaded (AC-1.5)", :aggregate_failures do
      create(:catalog_refresh_run, status: "failed")

      [ collection_path, catalog_entries_path ].each do |path|
        get path
        expect_the_footer(path)
      end
    end

    it "holds the card page's only attribution (AC-1.7)", :aggregate_failures do
      get catalog_entry_path(lot.entry)

      expect(response.body.scan("Card data and images provided by").size).to eq(1)
      expect(html.at_css("main").text).not_to include("provided by")
    end

    it "is on a form shown again after a failed submission (AC-1.6)", :aggregate_failures do
      patch lot_path(lot), params: { lot: { quantity: 0 } }

      expect(response).to have_http_status(:unprocessable_content)
      expect_the_footer("lot form, 422")
    end

    it "is left out of an answer that isn't a page (AC-1.8)", :aggregate_failures do
      printings = scanner_printings_path(card: lot.entry.identity.external_key, key: "c" * 32)
      get printings, headers: { "Turbo-Frame" => "scanner_printings" }
      expect(response.body).to include("<turbo-frame")
      expect(footers).to be_empty

      post scanner_readings_path, params: { reading: { name_text: "Bolt", collector_text: "", key: "c" * 32 } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).not_to include("<footer")

      get rails_health_check_path
      expect(response.body).not_to include("<footer")

      get printings
      expect_the_footer("the same address without the Turbo-Frame header")
    end

    it "is text and its links, with nothing else in it (AC-3.5, AC-3.8)", :aggregate_failures do
      get collection_path

      expect(footer.css("*").map(&:name).uniq).to match_array(%w[p a])
      expect(footer.css("a").map { |link| link.attributes.keys }).to all(match_array(%w[rel href]))
      expect(footer.css("a").map { |link| link["rel"] }).to all(eq("noopener"))
      expect(footer.to_html).not_to match(/style=|nonce=|<script|\son\w+=/)
    end

    it "runs no query (FR-2)" do
      expect(count_queries { Catalog::ContentNotice.lines.flat_map(&:parts) }).to eq(0)
    end
  end

  describe "for a signed-out visitor" do
    it "is on the first-run sign-up page (AC-1.3)" do
      get new_registration_path

      expect_the_footer("first-run sign-up")
    end

    it "is on the sign-in page and on open sign-up (AC-1.3)", :aggregate_failures do
      create(:user)
      InstanceSetting.current.update!(sign_up_open: true)

      [ new_session_path, new_registration_path ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect_the_footer(path)
      end
    end

    it "is on the sign-in form shown again with 422 and with 429 (AC-1.6)", :aggregate_failures do
      user = create(:user)

      10.times { post session_path, params: { email_address: user.email_address, password: "wrong" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect_the_footer("sign-in, 422")

      post session_path, params: { email_address: user.email_address, password: "wrong" }
      expect(response).to have_http_status(:too_many_requests)
      expect_the_footer("sign-in, 429")
    end
  end

  describe "for an admin" do
    it "is on the admin pages (AC-1.4)", :aggregate_failures do
      admin = sign_in_as(create(:admin))

      [ admin_users_path, new_admin_user_path, edit_admin_user_path(admin), admin_catalog_path, admin_jobs_path ].each do |path|
        get path
        expect(response).to have_http_status(:ok), path
        expect_the_footer(path)
      end
    end
  end

  describe "with other catalog types" do
    before { sign_in_as(create(:user)) }

    it "shows a second type's lines after the first's, a link only where a line names one (AC-2.1, AC-2.7)", :aggregate_failures do
      register_notice_catalog("zeta", notice_line("Zeta is shown with its owner's leave."),
        notice_line("Data from Zeta Base.", "Zeta Base" => "https://zeta.test/about"))
      get collection_path

      expect(lines).to eq([ notice, attribution, "Zeta is shown with its owner's leave.", "Data from Zeta Base." ])
      expect(footer.css("> p")[2].css("a")).to be_empty
      expect(footer.css("> p")[3].css("a").map { |link| [ link.text, link["href"] ] }).to eq([ [ "Zeta Base", "https://zeta.test/about" ] ])
    end

    it "shows nothing for a type whose source supplies no notice (AC-2.2)", :other_catalog do
      get collection_path

      expect_the_footer("with a type that has no notice")
    end

    it "shows a line two types supply once (AC-2.4)" do
      register_notice_catalog("zeta", notice_line("Data from Zeta Base."), notice_line(attribution, "Scryfall" => "https://scryfall.com"))
      get collection_path

      expect(lines).to eq([ notice, attribution, "Data from Zeta Base." ])
    end

    it "shows a line as escaped text, and as text alone when its link is unsafe", :aggregate_failures do
      register_notice_catalog("zeta", notice_line(%(Zeta <b>bold</b> & "quoted"), "bold" => "javascript:alert(1)"))
      get collection_path

      expect(lines.last).to eq(%(Zeta <b>bold</b> & "quoted"))
      expect(response.body).to include("Zeta &lt;b&gt;bold&lt;/b&gt; &amp; &quot;quoted&quot;")
      expect(footer.css("a").size).to eq(2)
      expect(response.body).not_to include("javascript:")
    end

    it "has no footer element when no type supplies a notice (AC-2.3)", :aggregate_failures do
      with_catalog_sources("other" => "OtherCatalogSource") { get more_path }

      expect(response).to have_http_status(:ok)
      expect(footers).to be_empty
    end
  end

  describe "under the scanner's Content-Security-Policy" do
    def policy = response.headers["Content-Security-Policy"].split(";").map(&:split).to_h { |name, *sources| [ name, sources ] }

    # Spec 007 AC-2.4, as ScannerPage sets it; only the nonce's value changes between requests.
    def expect_the_scanner_policy
      expect(policy).to match(
        "default-src" => [ "'self'" ], "script-src" => [ "'self'", "'wasm-unsafe-eval'", a_string_matching(/\A'nonce-[^']+'\z/) ],
        "worker-src" => [ "'self'", "blob:" ], "connect-src" => [ "'self'" ],
        "img-src" => [ "'self'", "data:", "blob:", "https://scryfall.com", "https://cards.scryfall.io", "https://svgs.scryfall.io" ],
        "style-src" => [ "'self'", "'unsafe-inline'" ], "font-src" => [ "'self'" ], "object-src" => [ "'none'" ],
        "frame-src" => [ "'none'" ], "base-uri" => [ "'self'" ], "form-action" => [ "'self'" ], "frame-ancestors" => [ "'self'" ])
    end

    before { sign_in_as(create(:user)) }

    it "is on the scanner page, which sends the policy it always sent (AC-4.2)", :aggregate_failures do
      get scanner_path

      expect_the_footer("scanner")
      expect_the_scanner_policy
      expect(footer.to_html).not_to match(/style=|nonce=|<script/)
    end

    context "with measurement mode on" do
      let(:corpus) { Pathname(Dir.mktmpdir("corpus")) }

      around do |example|
        corpus.join("manifest.csv").write("file,set,number,foil\nIMG_1.jpeg,mom,123,no\n")
        Rails.configuration.x.scanner_measurement = { manifest: corpus.join("manifest.csv").to_s, dir: corpus.join("runs/live").to_s }
        example.run
      ensure
        Rails.configuration.x.scanner_measurement = nil
        FileUtils.remove_entry(corpus)
      end

      it "is on the measurement page and its replay page, under the same policy (AC-4.3)", :aggregate_failures do
        [ scanner_measurement_path, scanner_measurement_replay_path(label: "a") ].each do |path|
          get path
          expect(response).to have_http_status(:ok), path
          expect_the_footer(path)
          expect_the_scanner_policy
        end
      end
    end
  end
end
```

- [ ] Write `spec/footer_core_spec.rb` (AC-2.5, AC-2.6), the footer's counterpart of `spec/admin_catalog_core_spec.rb`:

```ruby
require "rails_helper"

# Spec 018 AC-2.5 and AC-2.6: the core's footer code names no collectible, source or rights holder, in text or in an
# address. A type's notice reaches the footer only through its source's optional hook (app/models/catalog/sources.rb).
RSpec.describe "The core's footer code" do
  let(:files) do
    %w[app/views/layouts/application.html.erb app/views/layouts/_footer.html.erb app/models/catalog/content_notice.rb]
      .map { |path| Rails.root.join(path) }
  end

  it "covers the layout, the footer's partial and the model that collects the notices" do
    expect(files).to all(exist)
  end

  it "never says MTG, Magic, Wizards, Scryfall or Fan Content" do
    offenders = files.select { |file| file.read.match?(/mtg|magic|wizards|scryfall|fan content/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end

  it "leaves no attribution in the card page's own template, and no rule for it (AC-2.6, FR-3)", :aggregate_failures do
    expect(Rails.root.join("app/views/catalog/entries/show.html.erb").read).not_to match(/provided by|c-attribution/i)
    expect(Rails.root.join("app/assets/stylesheets/collector/additions.css").read).not_to include("c-attribution")
  end
end
```

- [ ] Let the file-content spec describe a string, as the other such specs do, in `.rubocop.yml`:

```diff
diff --git a/.rubocop.yml b/.rubocop.yml
index f43817e..6c56d8a 100644
--- a/.rubocop.yml
+++ b/.rubocop.yml
@@ -38,12 +38,13 @@ RSpec/Output:
 # class, so a string describe is intentional there, and the project-config spec
 # checks repository files, not a class. The hook spec exercises a git hook
 # script, and the collector rake spec a rake task, not a class. The image
-# publishing spec checks the publishing files, and the admin catalog core spec
-# the files of a page.
+# publishing spec checks the publishing files, and the admin catalog core and
+# footer core specs the files of a page.
 RSpec/DescribeClass:
   Exclude:
     - "spec/admin_catalog_core_spec.rb"
     - "spec/design_system_files_spec.rb"
+    - "spec/footer_core_spec.rb"
     - "spec/githooks/post_checkout_spec.rb"
     - "spec/image_publishing_spec.rb"
     - "spec/network_isolation_spec.rb"
```

- [ ] Change the card page's example in `spec/requests/catalog/entries_show_spec.rb`: it no longer expects the attribution in the body, and a new example says where it went (AC-1.7):

```diff
diff --git a/spec/requests/catalog/entries_show_spec.rb b/spec/requests/catalog/entries_show_spec.rb
index 4374441..81113c4 100644
--- a/spec/requests/catalog/entries_show_spec.rb
+++ b/spec/requests/catalog/entries_show_spec.rb
@@ -103,13 +103,22 @@ RSpec.describe "Card page", type: :request do
     expect(media.css("img")).to be_empty
   end
 
-  it "links to Scryfall with attribution, to the card's printings and back to search" do
+  it "links to Scryfall, to the card's printings and back to search" do
     get catalog_entry_path(entry)
 
-    expect(response.body).to include('href="https://scryfall.com/card/neo/172/ja/azusa"', "provided by Scryfall",
+    expect(response.body).to include('href="https://scryfall.com/card/neo/172/ja/azusa"',
       catalog_identity_path(identity), %(<li><a href="#{catalog_entries_path}">Search</a></li>))
   end
 
+  # Spec 018 AC-1.7: the attribution is the footer's, and the card's own body no longer repeats it.
+  it "leaves the source's attribution to the page's footer", :aggregate_failures do
+    get catalog_entry_path(entry)
+    page = Nokogiri::HTML5(response.body)
+
+    expect(page.at_css("main").text).not_to include("provided by")
+    expect(page.css("body > footer.c-footer p").map(&:text)).to include("Card data and images provided by Scryfall.")
+  end
+
   it "renders a retired printing with a notice", :aggregate_failures do
     entry.update!(retired_at: 1.day.ago)
 
```

- [ ] Run: `bin/rspec spec/requests/footer_spec.rb spec/footer_core_spec.rb spec/requests/catalog/entries_show_spec.rb` — expect: FAIL, `40 examples, 21 failures`: all three of `footer_core_spec.rb` (the partial doesn't exist; the card page still has its line), the new card page example, and 17 of `footer_spec.rb`'s 19 with `0 footers`. Its other two pass already: "runs no query (FR-2)" and "has no footer element when no type supplies a notice (AC-2.3)".
- [ ] Create `app/views/layouts/_footer.html.erb`:

```erb
<%# The page's footer (spec 018): the content notices of the registered catalog types, one line per paragraph; no
    element when there are none. The lines come from each type's source, never from this file. %>
<% if lines.any? %>
  <footer class="c-footer">
    <% lines.each do |line| %>
      <p><% line.parts.each do |text, address| %><%= address ? link_to(text, address, rel: "noopener") : text %><% end %></p>
    <% end %>
  </footer>
<% end %>
```

- [ ] Render it from `app/views/layouts/application.html.erb`:

```diff
diff --git a/app/views/layouts/application.html.erb b/app/views/layouts/application.html.erb
index c10d71d..517be42 100644
--- a/app/views/layouts/application.html.erb
+++ b/app/views/layouts/application.html.erb
@@ -22,6 +22,7 @@
     <%= yield :appbar %>
     <div id="status" class="c-status" role="status" aria-live="polite"><% if (message = flash[:alert] || flash[:notice]) %><%= render "shared/status_message", message:, alert: flash[:alert].present?, undo: (flash[:undo] unless flash[:alert]) %><% end %></div>
     <%= yield %>
+    <%= render "layouts/footer", lines: Catalog::ContentNotice.lines %>
     <%= yield :tabbar %>
   </body>
 </html>
```

- [ ] Remove the card page's own line from `app/views/catalog/entries/show.html.erb`:

```diff
diff --git a/app/views/catalog/entries/show.html.erb b/app/views/catalog/entries/show.html.erb
index 1e04c14..441e328 100644
--- a/app/views/catalog/entries/show.html.erb
+++ b/app/views/catalog/entries/show.html.erb
@@ -47,7 +47,6 @@
       <%= render "catalog/entries/copies", overview: @overview %>
       <%= render "catalog/entries/printings", overview: @overview %>
       <%= render_catalog_extension @entry, :legality %>
-      <p class="c-attribution">Card data and images provided by Scryfall.</p>
     </div>
   </div>
 </main>
```

- [ ] Remove its rule from `app/assets/stylesheets/collector/additions.css` (nothing else uses `c-attribution`), and the word from that block's comment:

```diff
diff --git a/app/assets/stylesheets/collector/additions.css b/app/assets/stylesheets/collector/additions.css
index 851ab7f..2250523 100644
--- a/app/assets/stylesheets/collector/additions.css
+++ b/app/assets/stylesheets/collector/additions.css
@@ -80,7 +80,7 @@
 .c-empty { margin:var(--space-6) 0; padding:var(--space-6); text-align:center; background:var(--surface-sunken);
   border-radius:var(--radius-md); font:400 15px/22px var(--font-sans); color:var(--ink); }
 
-/* ---------- Card page: details list, single stat, faces, attribution ---------- */
+/* ---------- Card page: details list, single stat, faces ---------- */
 .c-details { display:grid; grid-template-columns:repeat(auto-fill, minmax(180px, 1fr)); gap:var(--space-3) var(--space-4); margin:0; }
 .c-details dt { font:600 12px/16px var(--font-sans); color:var(--ink-muted); }
 .c-details dd { margin:var(--space-1) 0 0; font:400 14px/20px var(--font-sans); color:var(--ink); }
@@ -90,7 +90,6 @@
 .c-list li.is-unowned { color:var(--ink-muted); }
 .c-list .is-data { font-family:var(--font-mono); white-space:nowrap; }
 .c-list .c-tile__add .c-btn { width:auto; }
-.c-attribution { margin:0; font:400 12px/16px var(--font-sans); color:var(--ink-muted); }
 @container page (max-width: 639px) { .c-stats--single { grid-template-columns:minmax(0, 1fr); max-width:none; } }
 
 /* ---------- Sortable table header (spec 006): a link, or a bulk-form button, with the order's arrow ---------- */
```

- [ ] Run: `bin/rspec spec/requests/footer_spec.rb spec/footer_core_spec.rb spec/requests/catalog/entries_show_spec.rb` — expect: PASS, `40 examples, 0 failures`
- [ ] Run: `bin/rspec spec/requests spec/admin_catalog_core_spec.rb` — expect: PASS, 0 failures (no other request spec depended on the page ending at the tab bar)
- [ ] Run: `bin/rubocop` — expect: `no offenses detected`
- [ ] Commit: `feat(layout): show the content notices in a footer on every page`

---

## Phase 3: Presentation and the design-system pattern

**Implements:** FR-4 | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.6, AC-3.7, AC-3.8 (colour, hover, focus), AC-4.1, AC-4.4; FR-2's Turbo clause
**Files:** `spec/system/footer_spec.rb` (new), `app/assets/stylesheets/collector/additions.css` (new block at the end), `spec/design_system_files_spec.rb`, `docs/design-system/components/Footer.md` (new), `docs/design-system/README.md`
**Interfaces:** Consumes: the markup of Phase 2 (`body > footer.c-footer > p`, with `a` inside), and the existing shell classes `c-shell`, `c-main`, `c-tabbar`. Produces: the `Footer` pattern (`.c-footer`), documented.

Small print under a divider, on the page gutter, with brand links at the line's own weight. Below 640px the footer takes over the tab bar's clearance from `c-main` (see the facts above). The system spec measures the page after scrolling to its end: each line's box, whether the footer is what is drawn at each line (nothing covers it), and the fixed tab bar's top. Phone pages load in a 320px-tall frame so that every one of them scrolls.

- [ ] Write `spec/system/footer_spec.rb`:

```ruby
require "rails_helper"

# Spec 018 Stories 3 and 4: where the footer sits and how it reads, on wide screens and phones, in both themes and
# under the scanner's policy. Phone widths are loaded in a frame (spec/support/narrow_frame.rb).
RSpec.describe "The footer", type: :system do
  # What the page shows of the footer once scrolled to its end: each line's box, whether the footer is what's drawn at
  # each line's middle (nothing covers it), the tab bar's top, and how the footer sits against the main content.
  def measure
    page.evaluate_script(<<~JS)
      (() => {
        scrollTo(0, document.documentElement.scrollHeight)
        const footer = document.querySelector("body > footer.c-footer")
        const main = document.querySelector("main")
        const tabbar = document.querySelector("body > .c-tabbar")
        const lines = [ ...footer.querySelectorAll("p") ].map((line) => {
          const box = line.getBoundingClientRect()
          const seen = document.elementFromPoint(box.left + 4, box.top + box.height / 2)
          return { left: box.left, right: box.right, bottom: box.bottom, uncovered: Boolean(seen && seen.closest("footer.c-footer")) }
        })
        return { lines, scrolled: scrollY, height: innerHeight, position: getComputedStyle(footer).position,
          top: footer.getBoundingClientRect().top, bottom: footer.getBoundingClientRect().bottom,
          mainBottom: main ? main.getBoundingClientRect().bottom : null,
          mainPadding: main ? getComputedStyle(main).paddingBottom : null,
          contentBottom: main && main.lastElementChild ? main.lastElementChild.getBoundingClientRect().bottom : null,
          gutter: main ? main.getBoundingClientRect().left + parseFloat(getComputedStyle(main).paddingLeft) : null,
          tabbarTop: tabbar && getComputedStyle(tabbar).position === "fixed" ? tabbar.getBoundingClientRect().top : null }
      })()
    JS
  end

  # A frame much shorter than any page, so that each one scrolls and its end sits under the fixed tab bar.
  def measure_at(path, width:, ready: "body > footer.c-footer")
    fits = open_in_narrow_frame(path, width:, height: 320, ready:)
    [ fits, within_narrow_frame { measure } ]
  end

  def rgb(css) = css.scan(/[\d.]+/).first(3).map(&:to_f)

  # WCAG 2 contrast ratio of two computed colours.
  def contrast(one, other)
    light, dark = [ one, other ].map do |colour|
      red, green, blue = rgb(colour).map { |channel| (c = channel / 255) <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
      0.2126 * red + 0.7152 * green + 0.0722 * blue
    end.sort.reverse
    (light + 0.05) / (dark + 0.05)
  end

  def colours
    page.evaluate_script(<<~JS)
      (() => { const footer = document.querySelector("body > footer.c-footer")
        return { text: getComputedStyle(footer).color, link: getComputedStyle(footer.querySelector("a")).color,
          ground: getComputedStyle(document.body).backgroundColor } })()
    JS
  end

  let(:user) { create(:user) }

  it "follows short content directly, in normal flow, on a wide screen (AC-3.3)", :aggregate_failures do
    create(:user)
    page.current_window.resize_to(1280, 900) # tall enough that the sign-in page leaves room under its footer
    visit new_session_path
    footer = measure

    expect(footer["position"]).to eq("static")
    expect(footer["top"]).to be_within(0.5).of(footer["mainBottom"])
    expect(footer["bottom"]).to be < footer["height"] - 100
    expect(footer["lines"]).to all(include("uncovered" => true))
  end

  it "stops above the phone's tab bar, inside the gutter, at 390px and 360px (AC-3.1, AC-3.2)", :aggregate_failures do
    lot = create(:lot, account: user.account)
    system_sign_in_as(user)

    [ collection_path, catalog_entry_path(lot.entry), more_path ].each do |path|
      [ 390, 360 ].each do |width|
        fits, footer = measure_at(path, width:)

        expect(fits).to eq([ width, true ]), "#{path} scrolls sideways at #{width}px"
        expect(footer.values_at("tabbarTop", "scrolled")).to all(be_positive), "#{path} at #{width}px: no fixed tab bar, or nothing to scroll"
        expect(footer["lines"].map { |line| line["bottom"] }).to all(be <= footer["tabbarTop"]), "#{path} at #{width}px: text under the tab bar"
        expect(footer["lines"]).to all(include("uncovered" => true, "left" => footer["gutter"])), "#{path} at #{width}px: not on the gutter"
        expect(footer["lines"].map { |line| line["right"] }).to all(be <= width - footer["gutter"]), "#{path} at #{width}px: text past the gutter"
        expect(footer["top"]).to be_within(0.5).of(footer["mainBottom"]), "#{path} at #{width}px: a gap after main"
        expect(footer["mainPadding"]).to eq("16px"), "#{path} at #{width}px: main keeps the tab bar's clearance as well"
      end
    end
  end

  it "wraps inside the gutter on the sign-in page at 360px, where there is no tab bar (AC-3.2)", :aggregate_failures do
    create(:user)
    visit new_session_path
    fits, footer = measure_at(new_session_path, width: 360)

    expect(fits).to eq([ 360, true ])
    expect(footer["lines"]).to all(include("uncovered" => true, "left" => footer["gutter"]))
    expect(footer["lines"].map { |line| line["right"] }).to all(be <= 360 - footer["gutter"])
  end

  it "clears the sticky filter bar and the bulk bar (AC-3.6)", :aggregate_failures do
    create_list(:lot, 3, account: user.account)
    system_sign_in_as(user)

    [ collection_path, collection_path(view: "table", bulk: 1) ].each do |path|
      visit path
      expect(measure["lines"]).to all(include("uncovered" => true)), "#{path} on a wide screen"

      _, footer = measure_at(path, width: 390)
      expect(footer["lines"]).to all(include("uncovered" => true)), "#{path} at 390px"
      expect(footer["scrolled"]).to be_positive, "#{path} at 390px: nothing to scroll"
      expect(footer["lines"].map { |line| line["bottom"] }).to all(be <= footer["tabbarTop"]), "#{path} at 390px"
    end
  end

  it "reads as small print with brand links, in the light theme (AC-3.4, AC-3.8)", :aggregate_failures do
    system_sign_in_as(user)
    visit collection_path
    link = find("body > footer.c-footer a", text: "Scryfall")
    style = ->(property) { page.evaluate_script("getComputedStyle(arguments[0])[arguments[1]]", link, property) }

    # Light --ink-muted is #5f5a52 and --brand is #13595a in tokens.css.
    expect(colours.values_at("text", "link")).to eq([ "rgb(95, 90, 82)", "rgb(19, 89, 90)" ])
    expect(contrast(colours["text"], colours["ground"])).to be >= 4.5
    expect(contrast(colours["link"], colours["ground"])).to be >= 4.5
    expect([ style["fontSize"], style["lineHeight"], style["fontWeight"], style["textDecorationLine"] ]).to eq(%w[12px 16px 400 none])

    link.hover
    expect(style["textDecorationLine"]).to eq("underline")

    page.execute_script("arguments[0].focus({ focusVisible: true })", link)
    expect([ style["outlineStyle"], style["outlineWidth"], style["outlineOffset"] ]).to eq(%w[solid 2px 2px])
  end

  it "holds its contrast in the dark theme (AC-3.4)", :aggregate_failures do
    driven_by :selenium, using: :headless_firefox, screen_size: [ 1280, 900 ], options: { name: :firefox_dark } do |options|
      options.add_preference("ui.systemUsesDarkTheme", 1)
      options.add_preference("layout.css.prefers-color-scheme.content-override", 0) # 0 = dark
    end
    system_sign_in_as(user)
    visit collection_path

    # Dark --surface is #161513, --ink-muted #aaa298 and --brand #5fb7b2 in tokens.css.
    expect(colours.values_at("ground", "text", "link")).to eq([ "rgb(22, 21, 19)", "rgb(170, 162, 152)", "rgb(95, 183, 178)" ])
    expect(contrast(colours["text"], colours["ground"])).to be >= 4.5
    expect(contrast(colours["link"], colours["ground"])).to be >= 4.5
  end

  it "is styled on the scanner page, under its policy (AC-4.1)", :aggregate_failures do
    system_sign_in_as(user)
    visit scanner_path
    expect(page).to have_css(".c-scanner")

    expect(colours.values_at("text", "link")).to eq([ "rgb(95, 90, 82)", "rgb(19, 89, 90)" ])
    expect(page.all("body > footer.c-footer a").map { |link| link[:href] })
      .to eq([ "https://company.wizards.com/en/legal/fancontentpolicy", "https://scryfall.com/" ])
    expect(page).to have_no_css("body > footer.c-footer [style]")
    expect(measure["lines"]).to all(include("uncovered" => true))
  end

  it "clears the scanner and the tab bar on a phone (AC-4.4)", :aggregate_failures do
    system_sign_in_as(user)
    visit collection_path # the scanner's own policy lets it frame nothing, so the phone-width frame opens from here
    fits, footer = measure_at(scanner_path, width: 390, ready: ".c-scanner")
    expect(fits).to eq([ 390, true ])
    expect(footer["scrolled"]).to be_positive
    expect(footer["lines"]).to all(include("uncovered" => true))
    expect(footer["lines"].map { |line| line["bottom"] }).to all(be <= footer["tabbarTop"])
    expect(footer["top"]).to be >= footer["contentBottom"] # measured in the same moment: the scanner grows as the camera starts
  end

  it "is there once after a Turbo visit and after going back (FR-2)", :aggregate_failures do
    system_sign_in_as(user)
    visit collection_path
    within(".c-appbar__nav") { click_on "Search" }

    expect(page).to have_current_path(catalog_entries_path)
    expect(page).to have_css("body > footer.c-footer", count: 1)

    page.go_back
    expect(page).to have_current_path(collection_path)
    expect(page).to have_css("body > footer.c-footer", count: 1)
  end
end
```

- [ ] Run: `bin/rspec spec/system/footer_spec.rb` — expect: FAIL, `9 examples, 8 failures`. Only "is there once after a Turbo visit and after going back (FR-2)" passes: the footer is on the page and has no style yet.
- [ ] Add the footer's block to the end of `app/assets/stylesheets/collector/additions.css`:

```diff
diff --git a/app/assets/stylesheets/collector/additions.css b/app/assets/stylesheets/collector/additions.css
index 2250523..ae570ee 100644
--- a/app/assets/stylesheets/collector/additions.css
+++ b/app/assets/stylesheets/collector/additions.css
@@ -214,3 +214,17 @@
 .c-status__message a { color:var(--brand); font-weight:600; text-decoration:none; }
 .c-status__message a:hover { text-decoration:underline; }
 .c-status__message a:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
+
+/* ---------- Footer (spec 018): the content notices of the registered catalog types, on every page ---------- */
+.c-footer { display:flex; flex-direction:column; gap:var(--space-1); padding:var(--space-4) var(--space-8) var(--space-6);
+  border-top:1px solid var(--line); font:400 12px/16px var(--font-sans); color:var(--ink-muted); }
+.c-footer p { margin:0; overflow-wrap:anywhere; }
+.c-footer a { color:var(--brand); text-decoration:none; }
+.c-footer a:hover { text-decoration:underline; }
+.c-footer a:focus-visible { outline:2px solid var(--focus); outline-offset:2px; border-radius:var(--radius-sm); }
+/* Below bp-narrow the tab bar is fixed over the end of the page: the footer takes the clearance c-main carries for it
+   (80px, as in components.css), so the notice follows the content and its last line stops above the bar. */
+@media (max-width: 639px) {
+  .c-footer { padding:var(--space-4) var(--space-4) calc(80px + env(safe-area-inset-bottom)); }
+  .c-shell:has(> .c-footer) > .c-main { padding-bottom:var(--space-4); }
+}
```

- [ ] Run: `bin/rspec spec/system/footer_spec.rb` — expect: PASS, `9 examples, 0 failures`
- [ ] Add `Footer` to the documented patterns in `spec/design_system_files_spec.rb` (AC-3.7):

```diff
diff --git a/spec/design_system_files_spec.rb b/spec/design_system_files_spec.rb
index 9c9be3d..c1735ac 100644
--- a/spec/design_system_files_spec.rb
+++ b/spec/design_system_files_spec.rb
@@ -18,7 +18,8 @@ RSpec.describe "Design system files" do
     new_patterns = %w[StatusMessage Form AuthPage ConfirmPage SearchResults TileAdd FinishBadge FilterSelect Pager EmptyState
       Details SingleStat MorePage AdminUsers TableActions SystemLogo
       SortHeader StatusAction BulkConfirmPage ChoicePage BulkForm ViewSwitchForm TableItemLink Scanner
-      AdminJobs AdminCatalog StageList ProgressMeter]
+      AdminJobs AdminCatalog StageList ProgressMeter
+      Footer]
     readme = root.join("docs/design-system/README.md").read
     new_patterns.each do |name|
       expect(root.join("docs/design-system/components/#{name}.md")).to exist
```

- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect: FAIL, `4 examples, 1 failure`: "documents every new pattern and lists it in the README" (`Footer.md` doesn't exist)
- [ ] Write `docs/design-system/components/Footer.md`:

````markdown
# Footer

The small print at the end of every page: what the owners of the catalogs' content ask to be said, and where the data comes from. For Magic cards that is Wizards of the Coast's unofficial-content notice and the Scryfall attribution.

**Markup**: the layout renders it on every page, after the page's `<main>` and before the tab bar, through the `layouts/footer` partial. A page provides nothing. The lines come from each catalog type's source (`.content_notice`, see `app/models/catalog/sources.rb`), never from a view.

```html
<footer class="c-footer">
  <p>Collector is unofficial Fan Content permitted under the <a rel="noopener" href="https://company.wizards.com/en/legal/fancontentpolicy">Fan Content Policy</a>. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.</p>
  <p>Card data and images provided by <a rel="noopener" href="https://scryfall.com">Scryfall</a>.</p>
</footer>
```

- One `<footer>` per page, a direct child of the shell, so it is the page's `contentinfo` landmark. When no catalog type supplies a notice there is no element at all.
- One line per paragraph, in the order the types are registered and each type gives its lines. No heading, no type name, no list.
- Text only, apart from the links a line names: no logo, image, icon, set symbol or button. A source's name is a name, never a mark, and the wording never suggests the source or the owner endorses Collector.
- A line's wording belongs to its catalog type. Don't edit, shorten or translate a notice in a view; an owner's required wording is shown word for word.
- Small print: `ink-muted`, 12px on a 16px line (IBM Plex Sans 400), under a `line` divider, on the page gutter (`space-8` wide, `space-4` below 640px).
- Links are brand links at the line's own weight, as breadcrumb links are: `brand`, underlined on hover, with the `focus` ring. They open in the same tab. Inline links keep the line's height, as `StatusMessage` and breadcrumb links do; the 44px touch rule is applied to buttons and inputs.
- It follows the content in normal flow, directly after it, even when the page is shorter than the screen. It is never fixed or sticky.
- It is part of the shell, so it follows the viewport's 640px breakpoint. Below it the tab bar is fixed over the end of the page: the footer carries the clearance for it (its bottom padding), and `c-main` gives its own up, so the last line always stops above the bar.
- It needs no JavaScript and no inline style, so it renders unchanged under the scanner pages' Content-Security-Policy.
````

- [ ] List it in `docs/design-system/README.md`:

```diff
diff --git a/docs/design-system/README.md b/docs/design-system/README.md
index 6abb3b6..74e8af8 100644
--- a/docs/design-system/README.md
+++ b/docs/design-system/README.md
@@ -96,6 +96,8 @@ App additions (spec 007, in `collector/additions.css`): `Scanner`. Upstream it i
 
 App additions (spec 015, in `collector/additions.css`): `AdminJobs`, `AdminCatalog`, `StageList`, `ProgressMeter`. Upstream these into the published design system before the next export replaces this folder.
 
+App additions (spec 018, in `collector/additions.css`): `Footer`. Upstream it into the published design system before the next export replaces this folder.
+
 ## Logo
 
 - The mark is three fanned cards, the front one vault teal with a foil diamond: a collection, one piece of which is special. It is deliberately game-neutral so it grows past trading cards.
```

- [ ] Run: `bin/rspec spec/system/footer_spec.rb spec/design_system_files_spec.rb` — expect: PASS, `13 examples, 0 failures`
- [ ] Run: `bin/rspec spec/system` — expect: PASS, 0 failures (the narrow-page specs still find no sideways scrolling with the footer on every page)
- [ ] Run: `bin/rubocop` — expect: `no offenses detected`
- [ ] Commit: `feat(design-system): style and document the footer`

---

## Phase 4: Records

**Implements:** FR-3 (ADR 0018's consequence) | **Satisfies:** AC-2.5's guard being on record
**Files:** `docs/adr/0018-collectible-agnostic-catalog-core.md`, `CLAUDE.md`
**Interfaces:** Consumes: the file names of Phases 0 to 2. Produces: nothing code relies on.

ADR 0018 lists the card page's attribution as a known place where core code names a source. It no longer is one, and there is a second guard. `CLAUDE.md` gets one line under its non-obvious facts so a later session knows where the footer's words live. `README.md` stays as it is.

- [ ] Update the consequence in `docs/adr/0018-collectible-agnostic-catalog-core.md`:

```diff
diff --git a/docs/adr/0018-collectible-agnostic-catalog-core.md b/docs/adr/0018-collectible-agnostic-catalog-core.md
index d910732..50f4781 100644
--- a/docs/adr/0018-collectible-agnostic-catalog-core.md
+++ b/docs/adr/0018-collectible-agnostic-catalog-core.md
@@ -22,5 +22,5 @@ Catalog data is global. It changes only through a refresh that runs in a backgro
 - A new type is added by writing an adapter, a vocabulary and its own tables, without changing the core.
 - Pages work fully from the local copy when a source is down.
 - The boundary has been exercised by one type only. Comics, whenever built, is its first real test, and the core may need to change when it meets a source shaped unlike Scryfall.
-- `spec/admin_catalog_core_spec.rb` is the only automated guard that the core names no collectible, and it covers the admin catalog code and the not-loaded notice only. The rest of the core has known exceptions: comments in `Catalog::Entry` and `Catalog::Identity`, and the card page's Scryfall link and attribution.
+- Two automated guards check that core code names no collectible: `spec/admin_catalog_core_spec.rb` covers the admin catalog code and the not-loaded notice, and `spec/footer_core_spec.rb` (spec 018) covers the footer's layout, partial and model, whose notices come from each source's optional `.content_notice` hook. The rest of the core has known exceptions: comments in `Catalog::Entry` and `Catalog::Identity`, and the card page's Scryfall link. The card page's attribution was one until spec 018 moved it into the footer.
 - A source must also pass the north star's "source terms allow hosting" rule before it is adopted.
```

- [ ] Add the footer to `CLAUDE.md`:

```diff
diff --git a/CLAUDE.md b/CLAUDE.md
index 7cab6b5..6775234 100644
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -33,6 +33,7 @@ Ruby 4.0.7, Rails 8.1.4, SQLite in every environment (including production), Hot
 - **Deploy:** Compose (`compose.yaml`, `image:` defaults to the published `ghcr.io/plainprogrammer/collector:latest`, `COLLECTOR_IMAGE` overrides) and Kamal (`config/deploy.yml`, registry `ghcr.io`, placeholder server; deploy a release with `bin/kamal deploy --skip-push --version X.Y.Z`) both mount the `collector_storage` volume at `/rails/storage` and set `SOLID_QUEUE_IN_PUMA`. Both paths are documented in `README.md`; keep it in sync. `.dockerignore` keeps `docs/`, `spec/`, `spikes/`, `script/` and agent files out of the (public) image.
 - **Catalog data is global** (no `account_id`) and changes only through `Catalog::Refresh` (weekly `config/recurring.yml` schedule + the manual rake task, via `Catalog::RefreshJob`) and, for the MTG art index (spec 011, opt-in `COLLECTOR_MTG_ART_MATCHING`), `MTG::Art::BuildJob`, which the refresh queues and which writes `mtg_artworks`, `mtg_art_builds`, the image cache and the index under `storage/catalog/mtg/art/`. Downloads are kept in `storage/catalog/<type>/`. Pages never call Scryfall during render.
 - **Admin catalog and jobs (spec 015, ADRs 0014 and 0015):** `/admin/catalog` renders `Catalog::Health` (one per registered type) and its `Catalog::Operation`s: the core's `Catalog::RefreshOperation`, plus whatever a source's optional `.operations` hook adds (`MTG::Art::Operation`); the core code never names a collectible (`spec/admin_catalog_core_spec.rb`). A refresh run records its stage, progress, heartbeat and job id (`Catalog::Refresh::Progress`); 15 minutes without progress is a stall (`Catalog::RefreshRun::STALL_AFTER`), separate from the job's 6-hour queue lock (`Catalog::RefreshJob::LOCK_FOR`). "In flight" and the jobs pages (`BackgroundJobs::List`, `BackgroundJobs::Entry`) read Solid Queue's own tables. Pages poll with the `poll` Stimulus controller only while work is in flight. In specs, Solid Queue's tables are loaded into the test database (`spec/support/solid_queue.rb`); tag an example `:solid_queue` to queue through Solid Queue (no worker runs) and move jobs with `queue_job`, `claim_job`, `fail_job`, `finish_job`.
+- **Footer (spec 018):** the layout renders `layouts/footer` on every page with `Catalog::ContentNotice.lines`: each registered source's optional `.content_notice` (lines of plain text, each with the phrases that link out). The Fan Content Policy notice and the Scryfall attribution live in `MTG::Scryfall::Source`; core code never names them (`spec/footer_core_spec.rb`). It is text and links only, so it renders under the scanner's policy unchanged.
 - **Active Storage variants (spec 014, ADR 0013)** use libvips through `ruby-vips`, which is bundled with `require: false` so the app boots without libvips (it then logs "requires the ruby-vips gem"). Development needs libvips (`vips` on Fedora, `libvips` on Debian/Ubuntu): `bin/setup` prints a hint when it's missing (`Collector::LibvipsCheck`), CI installs it, and `bin/image-smoke` fails an image whose variant transformer isn't vips. No upload feature exists yet.
 - **Card scanner (specs 007, 009):** `/scanner`, linked from the navigation ("Scan") and the collection page. A scan is confirmed and added as a lot; the sitting's adds live in `scanner_sittings`/`scanner_sitting_entries` (one entry per reading key) until Done. Picked photos go through the hand-written detector (`app/javascript/scanner/detector.js`, ADR 0005); `script/scanner/detector_parity.rb` checks it against the spike's. Spec 009's findings tasks: `scanner:ranking`, `scanner:strong_sweep`, `scanner:foil_markers`, `scanner:detected_score`, `scanner:replay_score`, `scanner:overlap`, `scanner:sitting_findings` (results in `docs/specs/009-card-scanner-confirm-flow/research.md`). Its OCR engine is fetched and checksum-verified into the ignored `vendor/ocr/v7.0.0/` by `bin/fetch-ocr-engine` (run by `bin/setup` and the Dockerfile) and served by `OcrAssetsController`; scanner specs fail until it's installed. Art matching (spec 011, ADRs 0006, 0007 and 0012) needs ImageMagick (`magick` or `convert`) for the build and its specs; the page searches `/scanner/art/<index>` on the device. Only scanner pages send a Content-Security-Policy (`ScannerPage` concern); nonces exist only on those requests. Measurement mode (`/scanner/measurement`) is development-only (`config.x.scanner_measurement`; `COLLECTOR_SCANNER_MANIFEST`, `COLLECTOR_SCANNER_RUN_DIR`) and writes outside the repo. The art spike (spec 010) lives in `spikes/card_scanner/phase3/` (phone timing and replay server; spec 008's art tools take `CARD_SCANNER_WORK_DIR`, `CARD_SCANNER_TRUTH_CORPORA` and `CARD_SCANNER_BULK_FILE`), and measurement mode keeps live frames with `COLLECTOR_SCANNER_KEEP_FRAMES=1`. Phones need HTTPS: `bin/dev-certificate` makes a self-signed certificate outside the repo and prints the `bin/dev -b "ssl://…"` bind (alternative: a tunnel with `RAILS_DEVELOPMENT_HOSTS` + `COLLECTOR_HTTPS=true`).
 - **Off-limits for reads (permission-denied):** `.kamal/secrets`, `config/master.key`, `.env*`, `storage/`. Don't try to read them.
```

- [ ] Run: `bin/rspec spec/project_config_spec.rb spec/readme_spec.rb` — expect: PASS, 0 failures
- [ ] Commit: `docs(018): record the footer in ADR 0018 and CLAUDE.md`

---

## Phase 5: Integration Verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run the whole of local CI: `bin/ci` — expect: every step green (1,178 examples, 0 failures, 1 pending at the plan's last commit).
- [ ] Run the system specs under three seeds, since two of the footer's examples once depended on the window an earlier example left: `bin/rspec spec/system --seed 54457`, `--seed 1`, `--seed 2` — expect: `105 examples, 0 failures, 1 pending` each.
- [ ] Take screenshots for the PR into `docs/specs/018-content-notice-footer/screenshots/` (headless Firefox, phone widths in a 390px frame, a 0.6s pause after a theme switch): the sign-in page at 1280px; a card page at 1280px, scrolled to its end; a card page and the scanner page at 390px, scrolled to their end; the collection page at 1280px and at 390px in the dark theme. Look at each: the footer is small print under a divider on the page gutter, its two links are the brand colour, nothing overlaps it, and its last line is above the tab bar.
- [ ] Check each acceptance criterion against the table below, and say in the PR which were checked by eye.
- [ ] Commit the screenshots: `docs(018): add the footer's screenshots`

| Criterion | Where it is checked |
|---|---|
| AC-1.1, AC-1.2, AC-1.9, AC-1.10 | `spec/requests/footer_spec.rb` "is on every page, after the main content"; wording in `spec/models/mtg/scryfall/source_spec.rb` |
| AC-1.3 | `footer_spec.rb` "is on the first-run sign-up page", "is on the sign-in page and on open sign-up" |
| AC-1.4 | `footer_spec.rb` "is on the admin pages" |
| AC-1.5 | `footer_spec.rb` "is there while the catalog isn't loaded" (and every other example: the test catalog has no applied run) |
| AC-1.6 | `expect_the_footer` counts one footer and its lines on every page; "is on a form shown again after a failed submission"; "is on the sign-in form shown again with 422 and with 429" |
| AC-1.7 | `footer_spec.rb` "holds the card page's only attribution"; `spec/requests/catalog/entries_show_spec.rb` "leaves the source's attribution to the page's footer" |
| AC-1.8 | `footer_spec.rb` "is left out of an answer that isn't a page" |
| AC-2.1, AC-2.7 | `footer_spec.rb` "shows a second type's lines after the first's…"; `spec/models/catalog/content_notice_spec.rb` |
| AC-2.2 | `footer_spec.rb` "shows nothing for a type whose source supplies no notice"; `content_notice_spec.rb` |
| AC-2.3 | `footer_spec.rb` "has no footer element when no type supplies a notice"; `content_notice_spec.rb` |
| AC-2.4 | `footer_spec.rb` "shows a line two types supply once"; `content_notice_spec.rb` |
| AC-2.5, AC-2.6 | `spec/footer_core_spec.rb` |
| AC-3.1, AC-3.2 | `spec/system/footer_spec.rb` "stops above the phone's tab bar, inside the gutter, at 390px and 360px", "wraps inside the gutter on the sign-in page at 360px" |
| AC-3.3 | `system/footer_spec.rb` "follows short content directly, in normal flow, on a wide screen" |
| AC-3.4 | `system/footer_spec.rb` "reads as small print with brand links, in the light theme", "holds its contrast in the dark theme" (contrast computed from the computed colours) |
| AC-3.5 | `footer_spec.rb` "is text and its links, with nothing else in it" |
| AC-3.6 | `system/footer_spec.rb` "clears the sticky filter bar and the bulk bar" |
| AC-3.7 | `spec/design_system_files_spec.rb`; the document itself in review |
| AC-3.8 | `footer_spec.rb` (attributes: `rel` and `href` only, so no `target`); `system/footer_spec.rb` light-theme example (colour, weight, underline on hover, focus ring) |
| AC-4.1 | `system/footer_spec.rb` "is styled on the scanner page, under its policy" |
| AC-4.2, AC-4.3 | `footer_spec.rb` "under the scanner's Content-Security-Policy" (every directive and source, the nonce by pattern) |
| AC-4.4 | `system/footer_spec.rb` "clears the scanner and the tab bar on a phone" |
| FR-2: no query, Turbo | `footer_spec.rb` "runs no query"; `system/footer_spec.rb` "is there once after a Turbo visit and after going back" |
| Error Scenarios | `content_notice_spec.rb` (`Line#parts` faults, blank lines, a hook that raises, the same text with different links); `footer_spec.rb` "shows a line as escaped text, and as text alone when its link is unsafe" |

**Not covered by an example, and why:** a morph refresh (FR-2) replaces the body like any Turbo render and the footer has no state or id to lose; the admin catalog page morph-refreshes while it polls and its system specs pass with the footer present. Following a footer link from the scanner mid-sitting (Error Scenarios) is spec 009 AC-3.3's behaviour, unchanged here: the camera stops on `pagehide` and the sitting is kept on the server; it is checked by eye in the quickstart. Touch targets can't be tested in headless Firefox; the component document states the rule the links follow. On a real phone the `env(safe-area-inset-bottom)` part of the clearance is not zero: check one page on the maintainer's phone before merging.

---

## Quickstart Validation

1. `bin/setup --skip-server`, then `bin/dev`, and open the port it prints.
2. On the sign-in page, before signing in: the footer is directly under the form, with both lines. "Fan Content Policy" and "Scryfall" are links in the brand colour; each underlines on hover and shows the focus ring with Tab.
3. Sign in. The collection, search, a card page, the scanner, More and the admin pages each end with the same footer, once. On a card page the attribution appears only in the footer.
4. Follow "Scryfall": it opens `https://scryfall.com` in the same tab. Back returns to the page. Do the same from `/scanner` with a card added to the sitting: on return the camera starts again and the sitting still lists the card.
5. Narrow the window below 640px (or use a phone): scroll any page to its end. The footer's last line is above the tab bar, with no wide empty band between the content and the footer.
6. Open `/scanner`: the footer is there and styled, and the browser console shows no Content-Security-Policy report.
7. In a Rails console, `Catalog::ContentNotice.lines.map(&:text)` prints the two lines; `grep -rniE "mtg|magic|wizards|scryfall|fan content" app/views/layouts app/models/catalog/content_notice.rb` prints nothing.
