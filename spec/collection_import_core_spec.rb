require "rails_helper"

# Spec 025 FR-9: the import preview's reader, controller, views and helper name no collectible type or source.
RSpec.describe "The import preview's code" do
  let(:files) do
    %w[app/models/collection_import.rb app/models/export_format/rules.rb app/controllers/collections/import_previews_controller.rb
       app/views/collections/import_previews/new.html.erb app/views/collections/import_previews/show.html.erb
       app/helpers/import_previews_helper.rb].map { |path| Rails.root.join(path) }
  end

  it "exists, every file of it" do
    expect(files.reject(&:exist?)).to be_empty
  end

  it "never names a collectible type or a source" do
    offenders = files.select { |file| file.exist? && file.read.match?(/\b(mtg|scryfall)\b/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
