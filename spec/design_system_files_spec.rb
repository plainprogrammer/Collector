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
      # (components.css); an export that drops the fade removes it, and this expectation is edited then.
      rules = root.glob("app/assets/stylesheets/**/*.css")
        .flat_map { |path| path.read.gsub(%r{/\*.*?\*/}m, "").scan(/([^{}]*c-tile[^{}]*)(\{[^}]*\})/) }
      treating = rules.map(&:last).grep(/opacity|filter|mix-blend-mode/)
      expect(treating.map { |declarations| declarations.delete(" ") }.sort).to eq([ "{opacity:.45;}", "{opacity:1;}" ])
    end
  end

  describe "the untabbed shell (spec 023)" do
    let(:additions) { root.join("app/assets/stylesheets/collector/additions.css").read }
    let(:block) { additions[%r{/\* -+ Untabbed shell \(spec 023\).*?(?=\n\n/\* -|\z)}m] }

    it "keeps the rules in one block of their own, after the footer's, with no colour literal or font (AC-5.7)",
      :aggregate_failures do
      expect(additions.scan("spec 023").size).to eq(1)
      expect(additions.index("Untabbed shell (spec 023)")).to be > additions.index("Footer (spec 018)")
      expect(block).to include(".c-shell--untabbed > .c-main { padding-bottom:calc(var(--space-6) + env(safe-area-inset-bottom)); }",
        ".c-shell--untabbed.c-shell--footed > .c-main { padding-bottom:var(--space-4); }",
        ".c-shell--untabbed > .c-footer { padding-bottom:calc(var(--space-4) + env(safe-area-inset-bottom)); }")
      expect(block.scan(/^\s*[^\s\/@].*\{/).size).to eq(3)
      expect(block).not_to match(/#\h{3,8}\b|rgba?\(|hsla?\(|font/i)
    end
  end
end
