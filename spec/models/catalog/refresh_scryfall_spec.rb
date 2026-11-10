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

  describe "mana values (spec 058)" do
    def card_with_art(id, oracle, overrides = {})
      scryfall_card({ "id" => id, "oracle_id" => oracle, "illustration_id" => "art-#{id}", "name" => "Card #{id}" }.merge(overrides))
    end

    def apply(trigger) = described_class.new("mtg", trigger:, source:).call

    # An instance as it was before the upgrade: cards with no mana value and identity digests of the old shape (a real
    # upgraded instance holds digests computed without the key, which is what makes the refresh rewrite each card). Only
    # a spec does this; update_all skips validations and callbacks on purpose.
    def become_pre_upgrade
      MTG::Card.update_all(mana_value: nil)
      Catalog::Identity.update_all(content_digest: "before-058")
    end

    let(:file_cards) { [ card_with_art("a", "oracle-a", "cmc" => 2.0), card_with_art("b", "oracle-b", "cmc" => 0.5) ] }

    it "fills cards that had no mana value, leaving their entries and ids as they were", :aggregate_failures do
      stub_scryfall(cards: file_cards.map { |card| card.except("cmc") })
      refresh
      entry_ids = Catalog::Entry.order(:external_key).pluck(:id)
      other_attributes = MTG::Card.order(:catalog_identity_id).pluck(:catalog_identity_id, :mana_cost, :type_line, :oracle_text)
      expect(MTG::Card.pluck(:mana_value)).to eq([ nil, nil ])

      stub_scryfall(cards: file_cards, stamp: "20260930090555")
      refresh

      expect(MTG::Card.joins(:identity).order("catalog_identities.external_key").pluck(:mana_value)).to eq([ 2.0, 0.5 ])
      expect(Catalog::Entry.order(:external_key).pluck(:id)).to eq(entry_ids)
      expect(MTG::Card.order(:catalog_identity_id).pluck(:catalog_identity_id, :mana_cost, :type_line, :oracle_text)).to eq(other_attributes)
      expect(MTG::Card.count).to eq(2)
    end

    it "applies a scheduled refresh of an already-applied version while no card has a mana value (AC-3.2)", :aggregate_failures do
      stub_scryfall(cards: file_cards)
      refresh
      become_pre_upgrade
      expect(source.reapply?).to be(true)

      run = apply("scheduled")

      expect(run.status).to eq("applied")
      expect(MTG::Card.pluck(:mana_value)).to contain_exactly(2.0, 0.5)
    end

    it "skips a scheduled refresh of an already-applied version once a card has a mana value (AC-3.3)", :aggregate_failures do
      stub_scryfall(cards: file_cards)
      refresh

      run = apply("scheduled")

      expect(run.status).to eq("skipped")
      expect(run.message).to include("already applied")
    end

    it "applies a manual refresh of an already-applied version as always, and fills the column (AC-3.5)", :aggregate_failures do
      stub_scryfall(cards: file_cards)
      refresh
      become_pre_upgrade

      expect(apply("manual").status).to eq("applied")
      expect(MTG::Card.pluck(:mana_value)).to contain_exactly(2.0, 0.5)
    end

    it "changes nothing the second time over the same file (AC-3.6)", :aggregate_failures do
      stub_scryfall(cards: file_cards)
      refresh
      cards_before = MTG::Card.order(:id).pluck(:id, :mana_value, :updated_at)

      second = described_class.new("mtg", trigger: "manual", source:)
      second.call

      expect(MTG::Card.order(:id).pluck(:id, :mana_value, :updated_at)).to eq(cards_before)
      expect(second.made_progress?).to be(false)
    end

    it "writes a reversible card with its front face's value and counts no malformed record (AC-3.7)", :aggregate_failures do
      reversible = JSON.parse(file_fixture("scryfall/ajani_reversible_sld.json").read)
      stub_scryfall(cards: [ reversible ], sets: [ scryfall_set("code" => reversible.fetch("set"), "name" => reversible.fetch("set_name")) ])

      run = refresh

      expect(run.malformed_count).to eq(0)
      expect(Catalog::Entry.pluck(:external_key)).to eq([ reversible.fetch("id") ])
      expect(MTG::Card.pluck(:mana_value)).to eq([ 4.0 ])
    end
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
