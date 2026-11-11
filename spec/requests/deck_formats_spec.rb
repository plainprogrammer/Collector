require "rails_helper"

# Spec 064 Stories 1 to 3: the Change format page and the change, with the refusals and tenant isolation.
RSpec.describe "Deck formats", type: :request do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let!(:deck) { create(:deck, account:, name: "Izzet Tempo", format: "modern") }

  def html = Nokogiri::HTML5(response.body)
  def patch_format(value, target: deck) = patch(deck_format_path(target), params: { deck: { format: value } })

  context "when signed in" do
    before { sign_in_as(user) }

    describe "GET /decks/:id/format/edit (AC-1.2)" do
      it "shows the head, the deck's name and format, the select with the current format, the hint and Save and Cancel", :aggregate_failures do
        get edit_deck_format_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css("title").text).to eq("Change format of Izzet Tempo · Collector")
        expect(html.at_css("h1").text).to eq("Change format")
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Izzet Tempo · Modern")
        expect(html.css("select[name='deck[format]'] option").map(&:text)).to include("Casual", "Commander", "Modern")
        expect(html.at_css("select[name='deck[format]'] option[selected]")["value"]).to eq("mtg/modern")
        expect(html.at_css(".c-field__hint").text).to eq("Cards in zones the new format doesn't have move to Considering.")
        expect(html.at_css("input[type=submit]")["value"]).to eq("Save")
        expect(html.at_css("a.c-btn--secondary[href='#{decks_path}']").text).to eq("Cancel")
        expect(html.at_css(".c-appbar--detail")).to be_present
      end

      it "opens for a deck whose format is no longer registered, shows its stored key and starts the select on the default (AC-1.7)", :aggregate_failures do
        deck.update!(format: "retired")

        get edit_deck_format_path(deck)

        expect(response).to have_http_status(:ok)
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Izzet Tempo · retired")
        expect(html.at_css("select[name='deck[format]'] option[selected]")["value"]).to eq("mtg/casual")
      end
    end

    describe "PATCH /decks/:id/format" do
      it "changes the format, answers 303 to the Decks page with the notice and shows the new format (AC-1.3, AC-1.4)", :aggregate_failures do
        patch_format("mtg/pauper")

        expect(response).to redirect_to(decks_path)
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Changed “Izzet Tempo” to Pauper.")
        follow_redirect!
        expect(html.css(".c-decks tbody td.is-opt").first.text).to eq("Pauper")
      end

      it "says how many cards moved into Considering (AC-2.1)", :aggregate_failures do
        commander = create(:deck, account:, name: "Krenko", format: "commander")
        create_lot_in_zone(commander, "commander", quantity: 2)
        create_lot_in_zone(commander, "commander", quantity: 1)

        patch_format("mtg/modern", target: commander)

        expect(flash[:notice]).to eq("Changed “Krenko” to Modern. 3 cards moved to Considering.")
        expect(commander.reload.holdings.copies).to eq(3)
      end

      it "says '1 card' for one" do
        commander = create(:deck, account:, name: "Krenko", format: "commander")
        create_lot_in_zone(commander, "commander", quantity: 1)

        patch_format("mtg/modern", target: commander)

        expect(flash[:notice]).to eq("Changed “Krenko” to Modern. 1 card moved to Considering.")
      end

      it "says the deck already has the format and writes nothing (AC-1.6)", :aggregate_failures do
        expect { patch_format("mtg/modern") }.not_to change { [ Deck.pluck(:updated_at), Location.pluck(:updated_at) ] }

        expect(response).to redirect_to(decks_path)
        expect(flash[:notice]).to eq("“Izzet Tempo” is already Modern.")
      end

      it "answers 422 on the page with the alert and the chosen format kept when a merge passes the cap, changing nothing (AC-2.6)", :aggregate_failures do
        commander = create(:deck, account:, name: "Krenko", format: "commander")
        entry = create(:mtg_printing).entry
        create_lot_in_zone(commander, "considering", entry:, quantity: 9_999)
        create_lot_in_zone(commander, "commander", entry:, quantity: 1)

        patch_format("mtg/modern", target: commander)

        expect(response).to have_http_status(:unprocessable_content)
        expect(html.at_css("#status .c-status__message--alert").text).to include("Nothing changed. #{entry.name}", "would have more than 9,999 copies in one lot.")
        expect(html.at_css("select option[selected]")["value"]).to eq("mtg/modern")
        expect(html.at_css(".c-pagehead__stats").text.squish).to eq("Krenko · Commander")
        expect(commander.reload.format).to eq("commander")
      end

      it "answers 422 with 'Choose a format.' on the Format field for a value that is not a registered pair, writing nothing (AC-3.1)", :aggregate_failures do
        [ "", "modern", "nope/modern" ].each do |value|
          patch_format(value)

          expect(response).to have_http_status(:unprocessable_content)
          expect(html.at_css("#deck_format-error, .c-field__error").text).to include("Choose a format.")
        end
        expect(deck.reload.format).to eq("modern")
      end

      it "answers 400 without the deck parameter (AC-3.1)" do
        patch deck_format_path(deck), params: { other: "x" }

        expect(response).to have_http_status(:bad_request)
      end

      it "ignores an account, a kind, a parent, a zone, a collectible type, a name and a location id (AC-3.2)", :aggregate_failures do
        other = create(:user).account

        patch deck_format_path(deck), params: { deck: { format: "mtg/pauper", account_id: other.id, kind: "place", parent_id: 1, zone: "x",
                                                        collectible_type: "other", name: "Hacked", location_id: 1 } }

        expect(deck.reload).to have_attributes(collectible_type: "mtg", format: "pauper", account_id: account.id)
        expect(deck.name).to eq("Izzet Tempo")
      end
    end

    it "costs the same number of queries whatever the deck holds (NFR)" do
      empty = create(:deck, account:, name: "Empty")
      full = create(:deck, account:, name: "Full", format: "commander")
      10.times { create_lot_in_zone(full, "commander", quantity: 1) }
      get edit_deck_format_path(empty) # warms what the count would otherwise see once

      expect(count_queries { get edit_deck_format_path(full) }).to eq(count_queries { get edit_deck_format_path(empty) })
    end

    describe "tenant isolation and bad ids (AC-3.3, AC-3.4)" do
      let(:foreign) { create(:deck, account: create(:user).account, name: "Theirs", format: "modern") }
      let(:place) { create(:location, account:) }

      it "answers 404 for another account's deck, a place and a zone, and changes nothing", :aggregate_failures do
        zone = deck.zone("main")
        [ foreign.location_id, place.id, zone.id, deck.id + 10_000 ].each do |id|
          get "/decks/#{id}/format/edit"
          expect(response).to have_http_status(:not_found)
          patch "/decks/#{id}/format", params: { deck: { format: "mtg/pauper" } }
          expect(response).to have_http_status(:not_found)
        end
        expect([ foreign.reload.format, deck.reload.format ]).to eq(%w[modern modern])
      end

      it "answers 404 for the decks row's own id, which is not a location id (AC-3.3)" do
        3.times { create(:location, account:) } # place and zone ids move past the decks table's ids
        other = create(:deck, account:, name: "Other")

        get "/decks/#{other.id}/format/edit"

        expect(response).to have_http_status(:not_found)
      end

      it "answers 404 for a deck removed in another tab, on the page and on the change (AC-3.4)", :aggregate_failures do
        removed = create(:deck, account:, name: "Gone")
        removed.remove!

        get "/decks/#{removed.location_id}/format/edit"
        expect(response).to have_http_status(:not_found)
        patch_format("mtg/pauper", target: removed.location_id)
        expect(response).to have_http_status(:not_found)
      end

      it "changes nothing of another account's deck of the same name (AC-3.6)", :aggregate_failures do
        theirs = create(:deck, account: create(:user).account, name: "Izzet Tempo", format: "commander")
        create_lot_in_zone(theirs, "commander", quantity: 2)

        patch_format("mtg/pauper")

        expect(theirs.reload.format).to eq("commander")
        expect(theirs.holdings.copies).to eq(2)
        expect(theirs.zones.pluck(:zone)).to include("commander")
      end
    end
  end

  context "when signed out (AC-3.5)" do
    it "sends the visitor to sign in", :aggregate_failures do
      get edit_deck_format_path(deck)
      expect(response).to redirect_to(new_session_path)
      patch_format("mtg/pauper")
      expect(response).to redirect_to(new_session_path)
      expect(deck.reload.format).to eq("modern")
    end
  end
end
