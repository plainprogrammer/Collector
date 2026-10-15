require "rails_helper"

# Spec 022 FR-6: the export's writer and controller name no collectible type or source, and never ask the catalog's
# registry about a type, so a lot of any type, registered or not, exports.
RSpec.describe "The collection export's code" do
  let(:files) { [ Rails.root.join("app/models/collection_export.rb"), Rails.root.join("app/controllers/collections/exports_controller.rb") ] }

  it "never names a collectible type, a source or the registry" do
    offenders = files.select { |file| file.read.match?(/\b(mtg|scryfall)\b|collecting_for|source_class|preload_extensions/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
