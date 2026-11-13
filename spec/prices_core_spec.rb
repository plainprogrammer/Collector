require "rails_helper"

RSpec.describe "the prices schema is core (spec 081 decision 9, AC-3.5)", type: :model do
  it "names no collectible or source in its migrations, structure file or connection class, comments included", :aggregate_failures do
    files = Dir[Rails.root.join("db/prices_migrate/*.rb").to_s] + [ Rails.root.join("db/prices_structure.sql").to_s, Rails.root.join("app/models/prices_record.rb").to_s ]

    expect(files.size).to eq(3) # one migration so far, the structure file and the class; a new migration raises this
    expect(files.select { File.read(it).match?(/\b(mtg|scryfall|magic)\b/i) }).to be_empty
  end
end
