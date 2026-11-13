require "rails_helper"

RSpec.describe "Design system files" do
  let(:root) { Rails.root }

  it "installs the export's stylesheets, fonts and logos", :aggregate_failures do
    %w[tokens components additions].each { |name| expect(root.join("app/assets/stylesheets/collector/#{name}.css")).to exist }
    expect(root.glob("app/assets/fonts/collector/*.woff2").size).to eq(4)
    expect(root.glob("app/assets/images/collector/*.svg").size).to eq(4)
  end

  it "keeps colour literals and font families inside the design system directory" do
    offenders = root.glob("app/assets/stylesheets/**/*.css").reject { |path| path.to_s.include?("/collector/") }
      .select { |path| path.read.match?(/#\h{3,8}\b|rgba?\(|hsla?\(|font-family/i) }
    expect(offenders).to be_empty
  end

  it "removes feature 002's ad-hoc catalog styles" do
    expect(root.join("app/assets/stylesheets/application.css").read).not_to include(".catalog")
  end

  describe "the image fit override (spec 019)" do
    let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
    let(:block) { additions[%r{/\* -+ Image fit \(spec 019\).*?(?=\n\n/\* -|\z)}m] }

    it "keeps the rules in one block of their own, with no colour literal or font (AC-4.3)", :aggregate_failures do
      expect(additions.scan("spec 019").size).to eq(1)
      expect(block).to include(".c-tile__media img, .c-item__image img { object-fit:contain; }",
        "img.c-table__thumb { height:auto; object-fit:contain; }", ".c-item__image { position:relative; }")
      expect(block.scan(/^[^\s\/].*\{/).size).to eq(3)
      expect(block).not_to match(/#\h{3,8}\b|rgba?\(|hsla?\(|font/i)
    end
  end

  describe "the unowned tile override (spec 021)" do
    let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
    let(:block) { additions[%r{/\* -+ Unowned tile \(spec 021\).*?(?=\n\n/\* -|\z)}m] }

    it "keeps the rules in one block of their own, with no colour literal or font (AC-3.2)", :aggregate_failures do
      expect(additions.scan("spec 021").size).to eq(1)
      expect(block).to include(".c-tile--owned-none .c-tile__media > img, .c-tile--owned-none .c-tile__missing { opacity:1; }",
        ".c-tilecell > .c-tile__add { margin-top:auto; }")
      expect(block.scan(/^[^\s\/].*\{/).size).to eq(2)
      expect(block).not_to match(/#\h{3,8}\b|rgba?\(|hsla?\(|font/i)
    end

    it "leaves the export's fade and its override as the only rules that fade, filter or blend anything on a tile (FR-3)" do
      # Comments are dropped first, so only a rule's own declarations are read. The first of the two is the export's
      # (components.css), which still carries the fade; the second is the override that applies (spec 057 decision 12).
      rules = root.glob("app/assets/stylesheets/**/*.css")
        .flat_map { |path| path.read.gsub(%r{/\*.*?\*/}m, "").scan(/([^{}]*c-tile[^{}]*)(\{[^}]*\})/) }
      treating = rules.map(&:last).grep(/opacity|filter|mix-blend-mode/)
      expect(treating.map { |declarations| declarations.delete(" ") }.sort).to eq([ "{opacity:.45;}", "{opacity:1;}" ])
    end
  end

  describe "the licences page's block (spec 087)" do
    let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
    let(:block) { additions[%r{/\* -+ Licences \(spec 087\).*?(?=\n\n/\* -|\z)}m] }

    it "keeps the rules in one block of their own, with tokens only and a document (AC-1.10)", :aggregate_failures do
      expect(additions.scan("spec 087").size).to eq(1)
      expect(additions.index("Licences (spec 087)")).to be > additions.index("Footer (spec 018)")
      expect(additions.index("Licences (spec 087)")).to be < additions.index("Untabbed shell (spec 023)")
      expect(block).to include(".c-licences__text {", "var(--font-mono)", "max-height:24rem")
      expect(block).not_to match(/#\h{3,8}\b|rgba?\(|hsla?\(|font-family|["']/i)
      expect(root.join("docs/design-system/components/Licences.md")).to exist
    end
  end

  describe "the untabbed shell (spec 023, spec 084 decision 11)" do
    let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
    let(:block) { additions[%r{/\* -+ Untabbed shell \(spec 023\).*?(?=\n\n/\* -|\z)}m] }

    it "keeps the rules in one block of their own, after the footer's, with no colour literal or font (AC-5.7)",
      :aggregate_failures do
      expect(additions.scan("spec 023").size).to eq(1)
      expect(additions.index("Untabbed shell (spec 023)")).to be > additions.index("Footer (spec 018)")
      expect(block).to include(".c-shell--untabbed > .c-footer { padding-bottom:calc(var(--space-4) + env(safe-area-inset-bottom)); }")
      expect(block).not_to include(".c-shell--untabbed > .c-main")
      expect(block.scan(/^\s*[^\s\/@].*\{/).size).to eq(1)
      expect(block).not_to match(/#\h{3,8}\b|rgba?\(|hsla?\(|font/i)
    end
  end

  describe "the phone-first scanner's blocks (spec 080)" do
    let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
    let(:blocks) { additions.scan(%r{/\* -+ [^\n]*\(spec 080[^\n]*\n.*?(?=\n\n/\* -|\z)}m) }

    it "uses !important only in the reduced-motion block, which is the last block (FR-7)", :aggregate_failures do
      rules = root.glob("app/assets/stylesheets/**/*.css").map { |path| path.read.gsub(%r{/\*.*?\*/}m, "") }.join
      expect(rules.scan("!important").size).to eq(2)
      expect(blocks.last).to include("transition:none !important; animation:none !important;")
      expect(additions.rstrip).to end_with(blocks.last.rstrip)
    end

    it "keeps each part in a block of its own, with no colour literal and no font but the tokens' (AC-6.2)", :aggregate_failures do
      expect(blocks.map { it[%r{/\* -+ (.+?) \(spec 080}, 1] }).to eq([ "StatusBand", "Focused shell", "Sheet", "Scan shell", "Scan pane", "Reduced motion, app-wide" ])
      rules = blocks.map { it.gsub(%r{/\*.*?\*/}m, "") }
      expect(rules.grep(/#\h{3,8}\b|rgba?\(|hsla?\(/i)).to be_empty
      expect(rules.join.scan(/font(?:-family)?:[^;}]*/).reject { it.include?("var(--font-") || it == "font:inherit" }).to be_empty
    end

    it "sets box-sizing:border-box on each rule that sets a size (decision 15)" do
      # A rule sets a size when it gives width, height or a min- or max- of either a value with a digit in it other than a
      # bare 0 (so 100% and calc() count; none, auto and max-content don't). The test reads each rule on its own: a rule
      # that gets border-box from another rule on the same element still fails, so the decision holds literally. It reads
      # the innermost braces, so a rule inside @container or @media is read as a rule; it doesn't resolve var() or know
      # which elements a selector matches.
      rules = blocks.join.gsub(%r{/\*.*?\*/}m, "").scan(/([^{}]+)\{([^{}]*)\}/)
      sizing = rules.select { |_, body| body.match?(/(?<![\w-])(?:(?:min|max)-)?(?:width|height)\s*:\s*(?!0\s*(?:;|\z))[^;]*\d/) }
      offenders = sizing.reject { |_, body| body.match?(/box-sizing\s*:\s*border-box/) }.map { it.first.strip }
      expect(offenders).to be_empty, "Sized with no box-sizing:border-box: #{offenders.join(' | ')}"
    end
  end
end
