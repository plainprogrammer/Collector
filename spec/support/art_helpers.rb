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

# A finished build's index file: writes an index for the version and returns its name, to set as the build's index_file
# (spec 039). A bare finished build row has none, which now reads as "index file missing".
module ArtIndexHelpers
  def art_index_name(version = "default-cards-1") = MTG::Art::Index.write!(version, []).basename.to_s
end

RSpec.configure { |config| config.include ArtIndexHelpers }
