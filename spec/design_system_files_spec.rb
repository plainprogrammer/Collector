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

  it "keeps colour literals and font families inside the design system directory" do
    offenders = root.glob("app/assets/stylesheets/**/*.css").reject { |path| path.to_s.include?("/collector/") }
      .select { |path| path.read.match?(/#\h{3,8}\b|rgba?\(|hsla?\(|font-family/i) }
    expect(offenders).to be_empty
  end

  it "removes feature 002's ad-hoc catalog styles" do
    expect(root.join("app/assets/stylesheets/application.css").read).not_to include(".catalog")
  end
end
