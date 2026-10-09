# Art matching in specs (spec 011): `:art_matching` turns the instance setting on for one example and empties the art
# directory (tmp/catalog/mtg/art) before and after it, so no index or cached image leaks between examples.
RSpec.configure do |config|
  config.around(:each, :art_matching) do |example|
    previous = Rails.configuration.x.mtg_art_matching
    Rails.configuration.x.mtg_art_matching = true
    FileUtils.rm_rf(MTG::Art.root)
    example.run
  ensure
    Rails.configuration.x.mtg_art_matching = previous
    FileUtils.rm_rf(MTG::Art.root)
  end
end
