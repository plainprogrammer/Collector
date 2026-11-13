require "rails_helper"

# Spec 087 AC-2.6, modelled on spec/footer_core_spec.rb: the files of the third-party licences page and its manifest name no
# collectible, source or rights holder. What the page lists is whatever the bundle and the manifest hold.
RSpec.describe "The third-party licences page's files" do
  let(:files) do
    %w[lib/collector/third_party_licences.rb lib/collector/third_party_licences/audit.rb config/third_party_licences.yml]
      .map { |path| Rails.root.join(path) } + Rails.root.glob("config/third_party_licences/*.txt")
  end

  it "covers the reader, the guard's rules, the manifest and its texts", :aggregate_failures do
    expect(files.size).to be > 3
    expect(files).to all(exist)
  end

  it "never says MTG, Magic, Wizards, Scryfall or Fan Content" do
    offenders = files.select { |file| file.read.match?(/mtg|magic|wizards|scryfall|fan content/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
