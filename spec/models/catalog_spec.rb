require "rails_helper"

RSpec.describe Catalog, type: :model do
  it "keeps MTG vocabulary out of the core catalog tables" do
    mtg_terms = /mana|colou?r|power|toughness|loyalty|type_line|oracle|rules|legal|face|rarity|finishes|frame|border|security_stamp/
    columns = [ Catalog::Set, Catalog::Identity, Catalog::Entry, Catalog::RefreshRun ].flat_map(&:column_names)

    expect(columns.grep(mtg_terms)).to be_empty
  end
end
