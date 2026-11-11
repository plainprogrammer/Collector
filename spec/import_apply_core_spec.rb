require "rails_helper"

# Spec 028 FR-8: the apply and the stored upload name no collectible type or source. FR-6: the file isn't logged.
# Issue #209: the names are matched anywhere in a word (scryfall_id, MTGPrinting), because `_` is a word character and
# `\b` would let them through.
RSpec.describe "Apply an import, core code", type: :config do
  let(:files) do
    %w[
      app/models/import_upload.rb app/jobs/import_upload/sweep_job.rb app/models/collection_import/plan.rb
      app/models/collection_import/apply.rb app/models/collection_import/working_state.rb
      app/controllers/collections/imports_controller.rb app/controllers/concerns/active_storage_gate.rb
      app/views/collections/import_previews/_apply.html.erb app/views/collections/imports/failed.html.erb
      app/models/collection_import/locations.rb app/models/collection_import/decks.rb app/models/collection_import/deck_changes.rb app/models/location.rb app/models/location/name.rb
      app/controllers/locations_controller.rb app/views/locations/index.html.erb
      app/views/collections/import_previews/_locations.html.erb app/views/collections/import_previews/_decks.html.erb
      app/models/collection_import/location_changes.rb
      app/models/location/holdings.rb app/views/locations/removals/refused.html.erb app/helpers/locations_helper.rb
      app/models/lot/move.rb app/controllers/lots/moves_controller.rb app/views/lots/moves/new.html.erb
      app/models/lot/bulk_move.rb app/controllers/collections/moves_controller.rb app/views/collections/moves/new.html.erb
      app/controllers/locations/selections_controller.rb
    ]
  end

  it "never names a collectible type or a source" do
    named = files.select { |file| Rails.root.join(file).exist? && Rails.root.join(file).read.match?(/mtg|scryfall/i) }

    expect(named).to be_empty
  end

  it "exists, every file of it" do
    expect(files.reject { |file| Rails.root.join(file).exist? }).to be_empty
  end

  it "keeps the uploaded file out of the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("export_file" => "the file's content")).to eq("export_file" => "[FILTERED]")
  end
end
