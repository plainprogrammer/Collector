require "rails_helper"

RSpec.describe "Design system files" do
  let(:root) { Rails.root }

  it "installs the export's stylesheets, fonts, logos, docs and skill", :aggregate_failures do
    %w[tokens components additions].each { |name| expect(root.join("app/assets/stylesheets/collector/#{name}.css")).to exist }
    expect(root.glob("app/assets/fonts/collector/*.woff2").size).to eq(4)
    expect(root.glob("app/assets/images/collector/*.svg").size).to eq(4)
    %w[README.md tokens.json logos.md components/ItemPage.md previews/ItemPage.html].each do |path|
      expect(root.join("docs/design-system", path)).to exist
    end
    expect(root.join(".claude/skills/collector-design-system/SKILL.md")).to exist
    expect(root.join("CLAUDE.md").read).to include("## UI and design system", "collector-design-system")
  end

  it "documents every new pattern and lists it in the README", :aggregate_failures do
    new_patterns = %w[StatusMessage Form AuthPage ConfirmPage SearchResults TileAdd FinishBadge FilterSelect Pager EmptyState
      Details SingleStat MorePage AdminUsers TableActions SystemLogo
      SortHeader StatusAction BulkConfirmPage ChoicePage BulkForm ViewSwitchForm TableItemLink Scanner
      AdminJobs AdminCatalog StageList ProgressMeter
      Footer]
    readme = root.join("docs/design-system/README.md").read
    new_patterns.each do |name|
      expect(root.join("docs/design-system/components/#{name}.md")).to exist
      expect(readme).to include("`#{name}`")
    end
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

    it "documents the pattern, its three slots and that it overrides the export (AC-4.1, AC-4.2)", :aggregate_failures do
      expect(root.join("docs/design-system/components/ImageFit.md").read).to include("`c-tile__media`", "`c-item__image`",
        "`c-table__thumb`", "whole and in its own proportions", "`surface-sunken`", "overrides the export", "Upstream it")
      expect(root.join("docs/design-system/README.md").read).to match(/^App additions \(spec 019, .*`ImageFit`.*Upstream it/)
    end

    it "keeps the rules in one block of their own, with no colour literal or font (AC-4.3)", :aggregate_failures do
      expect(additions.scan("spec 019").size).to eq(1)
      expect(block).to include(".c-tile__media img, .c-item__image img { object-fit:contain; }",
        "img.c-table__thumb { height:auto; object-fit:contain; }", ".c-item__image { position:relative; }")
      expect(block.scan(/^[^\s\/].*\{/).size).to eq(3)
      expect(block).not_to match(/#\h{3,8}\b|rgba?\(|hsla?\(|font/i)
    end
  end
end
