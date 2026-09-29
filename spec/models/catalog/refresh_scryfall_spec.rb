require "rails_helper"

RSpec.describe Catalog::Refresh, type: :model do
  let(:env) { {} }
  let(:source) { MTG::Scryfall::Source.new(env:, client: MTG::Scryfall::Client.new(sleeper: ->(_) { })) }
  let(:cards) do
    [ scryfall_card("id" => "bolt-en"),
      scryfall_card("id" => "bolt-ja", "lang" => "ja", "printed_name" => "稲妻"),
      scryfall_card("id" => "bolt-arena", "digital" => true, "games" => [ "arena" ]),
      scryfall_card("id" => "goblin-token", "layout" => "token", "name" => "Goblin", "oracle_id" => "oracle-goblin") ]
  end

  def refresh = described_class.new("mtg", trigger: "manual", source:).call

  after { FileUtils.rm_rf(Rails.configuration.x.catalog_download_dir) }

  it "ingests English paper printings by default with MTG extensions", :aggregate_failures do
    stub_scryfall(cards:, type: "default_cards")

    refresh

    expect(Catalog::Entry.pluck(:external_key)).to contain_exactly("bolt-en", "goblin-token")
    expect(Catalog::Entry.find_by(external_key: "goblin-token").kind).to eq("token")
    expect(MTG::Printing.find_by(entry: Catalog::Entry.find_by(external_key: "bolt-en"))).to have_attributes(rarity: "common")
    expect(MTG::Card.count).to eq(2)
  end

  context "when Japanese is configured" do
    let(:env) { { "COLLECTOR_MTG_LANGUAGES" => "ja" } }

    it "also ingests Japanese printings and never digital-only ones", :aggregate_failures do
      stub_scryfall(cards:, type: "all_cards")

      refresh

      expect(Catalog::Entry.pluck(:external_key)).to contain_exactly("bolt-en", "bolt-ja", "goblin-token")
      expect(Catalog::Entry.find_by(external_key: "bolt-ja").localized_name).to eq("稲妻")
    end
  end
end
