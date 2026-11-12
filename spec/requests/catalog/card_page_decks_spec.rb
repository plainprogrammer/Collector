require "rails_helper"

# Spec 073: the card page's stats strip (Story 1) and "In decks" section (Story 2) for a signed-in collector.
RSpec.describe "Card page: Free to use and In decks", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:card) { create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on: Date.new(2022, 1, 1))).entry }
  let(:older) { create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on: Date.new(2020, 1, 1))).entry }

  before { sign_in_as(user) }

  def html = Nokogiri::HTML5(response.body)

  # The strip as { "Owned" => [ "7", "3 printings" ], … }.
  def strip = html.css("dl.c-stats .c-stat").to_h { [ it.at_css("dt").text, [ it.at_css("dd").text, it.at_css("small").text ] ] }

  def place = create(:location, account:)

  # Another account whose deck holds the card: 5 copies in its Sideboard and 2 proxies in its Main. Every record is its own
  # account's (lesson 2026-11-11: another account's lot and zone are built from one account). Returns the other user.
  def other_account_deck(name)
    other_user = create(:user)
    deck = create(:deck, account: other_user.account, name:)
    create_lot_in_zone(deck, "sideboard", entry: card, quantity: 5)
    create(:deck_proxy, zone: deck.zone("main"), entry: card, account: other_user.account, quantity: 2)
    other_user
  end

  def switch_to(other_user)
    delete session_path
    sign_in_as(other_user)
  end

  describe "the stats strip" do
    it "shows Owned, In decks and Free to use as three stats for a card in no deck (AC-1.1)", :aggregate_failures do
      create(:lot, account:, entry: card, quantity: 3)
      get catalog_entry_path(card)

      expect(html.css("dl.c-stats").size).to eq(1)
      expect(html.at_css("dl.c-stats")["class"].split).to include("c-stats--three")
      expect(html.at_css("dl.c-stats")["class"]).not_to include("c-stats--single")
      expect(strip).to eq("Owned" => [ "3", "1 printing" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "3", "not in a deck" ])
    end

    it "counts copies in zones, Considering included, as in decks and the rest as free (AC-1.2)", :aggregate_failures do
      alpha, beta = create(:deck, account:, name: "Alpha"), create(:deck, account:, name: "Beta")
      create_lot_in_zone(alpha, "main", entry: card, quantity: 2)
      create_lot_in_zone(beta, "considering", entry: older, quantity: 1)
      create(:lot, account:, entry: card, quantity: 3, location: place)
      create(:lot, account:, entry: older, quantity: 1)
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "7", "2 printings" ], "In decks" => [ "3", "in 2 decks" ], "Free to use" => [ "4", "not in a deck" ])
    end

    it "writes each number with its delimiter (AC-1.2)" do
      deck = create(:deck, account:)
      create_lot_in_zone(deck, "main", entry: card, quantity: 9_999)
      create_lot_in_zone(deck, "sideboard", entry: older, quantity: 2_346)
      create(:lot, account:, entry: card, quantity: 9_999)
      create(:lot, account:, entry: older, quantity: 2_346)
      get catalog_entry_path(card)

      expect(strip.transform_values(&:first)).to eq("Owned" => "24,690", "In decks" => "12,345", "Free to use" => "12,345")
    end

    it "has Free to use 0 and In decks equal to Owned when every copy is in a deck (AC-1.3)" do
      deck = create(:deck, account:)
      create_lot_in_zone(deck, "main", entry: card, quantity: 2)
      create_lot_in_zone(deck, "sideboard", entry: card, quantity: 1)
      get catalog_entry_path(card)

      expect(strip.transform_values(&:first)).to eq("Owned" => "3", "In decks" => "3", "Free to use" => "0")
    end

    it "changes none of the three numbers when a proxy is added to a zone of the same deck or of another deck (AC-1.4)", :aggregate_failures do
      first, second = create(:deck, account:, name: "First"), create(:deck, account:, name: "Second")
      create_lot_in_zone(first, "main", entry: card, quantity: 1)
      create(:lot, account:, entry: card, quantity: 1)
      get catalog_entry_path(card)
      before = strip
      expect(before).to eq("Owned" => [ "2", "1 printing" ], "In decks" => [ "1", "in 1 deck" ], "Free to use" => [ "1", "not in a deck" ])

      [ first.zone("sideboard"), second.zone("main") ].each { create(:deck_proxy, zone: it, entry: card, quantity: 2) }
      get catalog_entry_path(card)
      expect(strip).to eq(before)
    end

    it "reads 0, 0 printings and in 0 decks for a card with only a proxy (AC-1.4)" do
      create(:deck_proxy, zone: create(:deck, account:).zone("main"), entry: card, quantity: 1)
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "0", "0 printings" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "0", "not in a deck" ])
    end

    it "gives the card's own numbers and agrees with Lot::FreeCopies (AC-1.5)", :aggregate_failures do
      deck = create(:deck, account:)
      other_card = create(:mtg_printing).entry
      create_lot_in_zone(deck, "main", entry: card, quantity: 4)
      create(:lot, account:, entry: card, quantity: 2, location: place)
      create(:lot, account:, entry: card, quantity: 1, finish: "foil")
      create_lot_in_zone(deck, "main", entry: other_card, quantity: 9) # another card in a zone
      create(:lot, account:, entry: other_card, quantity: 8) # another card, free
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "7", "1 printing" ], "In decks" => [ "4", "in 1 deck" ], "Free to use" => [ "3", "not in a deck" ])
      expect(Lot::FreeCopies.new(account:, entry: card).total).to eq(3)
    end

    it "counts nothing of another account's lots and proxies, and shows them on that account's own page (AC-1.6)", :aggregate_failures do
      create(:lot, account:, entry: card, quantity: 1)
      other_user = other_account_deck("Their Deck Name")
      get catalog_entry_path(card)

      expect(strip).to eq("Owned" => [ "1", "1 printing" ], "In decks" => [ "0", "in 0 decks" ], "Free to use" => [ "1", "not in a deck" ])
      expect(response.body).not_to include("Their Deck Name")

      switch_to(other_user) # the control: the same page for the other account shows their numbers and their deck
      get catalog_entry_path(card)
      expect(strip).to eq("Owned" => [ "5", "1 printing" ], "In decks" => [ "5", "in 1 deck" ], "Free to use" => [ "0", "not in a deck" ])
      expect(response.body).to include("Their Deck Name")
    end
  end
end
