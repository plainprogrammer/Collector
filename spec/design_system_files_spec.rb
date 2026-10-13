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
end
