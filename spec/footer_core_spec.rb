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
