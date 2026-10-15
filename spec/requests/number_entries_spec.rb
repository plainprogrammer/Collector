require "rails_helper"

RSpec.describe "Number entry", type: :request do
  let(:user) { create(:user) }
  let(:mh3) { create(:catalog_set, code: "mh3", name: "Modern Horizons 3", released_on: Date.new(2024, 6, 14)) }
  let(:page_params) { { type: "mtg", set: "mh3", language: "en" } }

  def printing(number, name = "Card #{number}", set: mh3, language: "en", finishes: %w[nonfoil foil], **attributes)
    entry = create(:catalog_entry, set:, number:, language:, identity: create(:catalog_identity, name:), name:, **attributes)
    create(:mtg_printing, entry:, finishes:) if finishes
    entry
  end

  def add(number, quantity: "1", finish: nil, line_key: SecureRandom.hex(16), pick: nil, **context)
    post collection_number_entry_lines_path,
      params: { **page_params, **context, line: { number:, quantity:, finish:, line_key:, pick: }.compact }
  end

  context "when signed in" do
    before { sign_in_as(user) }

    describe "the ways in" do
      it "links Add by number from the collection's header and its empty message, and from More (AC-1.1, AC-1.2)", :aggregate_failures do
        get collection_path
        expect(response.body).to include(%(<a class="c-btn c-btn--secondary" href="#{collection_number_entry_path}">Add by number</a>))
        expect(response.body).to include(%(No cards in your collection yet. Search for a card or <a href="#{collection_number_entry_path}">add cards by number</a> to start adding.))
        get more_path
        expect(Nokogiri::HTML5(response.body).at_css(".c-more li:nth-child(3) a")&.text).to eq("Add by number")
        expect(response.body).to include(%(<a href="#{collection_number_entry_path}">Add by number</a>))
      end
    end

    describe "choosing a set" do
      it "starts with the set field, focused, offering sets newest first (AC-1.1, AC-1.3)", :aggregate_failures do
        printing("1")
        older = create(:catalog_set, code: "tmh3", name: "Modern Horizons 3 Tokens", released_on: Date.new(2023, 1, 1))
        printing("1", set: older, kind: "token")
        get collection_number_entry_path
        expect(response.body).to include("<h1 class=\"c-pagehead__title\">Add by number</h1>")
        expect(response.body).to match(/<input[^>]*id="number_entry_set"[^>]*autofocus/)
        expect(response.body.index("Modern Horizons 3 (MH3)")).to be < response.body.index("Modern Horizons 3 Tokens (TMH3)")
        expect(response.body).not_to include('id="line_number"')
      end

      it "takes a code, a name or a label, and links the set as type, code and language (AC-1.4, AC-1.5)", :aggregate_failures do
        printing("1")
        [ "MH3", "mh3", "modern horizons 3", "Modern Horizons 3 (MH3)" ].each do |text|
          get collection_number_entry_path(set: text)
          expect(response).to redirect_to(collection_number_entry_path(**page_params)), text
        end
        follow_redirect!
        expect(response.body).to include("Modern Horizons 3", "MH3", "Change set")
        expect(response.body).to match(/<input[^>]*id="line_number"[^>]*autofocus/)
      end

      it "offers the set's languages, EN chosen (AC-1.5)", :aggregate_failures do
        printing("1")
        printing("1", language: "ja")
        get collection_number_entry_path(**page_params)
        expect(response.body).to include('<option selected="selected" value="en">EN</option>', '<option value="ja">JA</option>')
      end

      it "states a set's one language with no field (AC-1.7)", :aggregate_failures do
        printing("1")
        get collection_number_entry_path(**page_params)
        expect(response.body).to include("Language: EN")
        expect(response.body).not_to include('id="number_entry_language"')
      end

      it "says when no set matches, keeping the text (AC-1.8)", :aggregate_failures do
        printing("1")
        get collection_number_entry_path(set: "zzz")
        expect(response.body).to include("No set matches “zzz”. Type a set code or choose a set from the list.", 'value="zzz"')
        expect(response.body).not_to include('id="line_number"')
      end

      it "answers a forged type parameter without an error" do
        printing("1")
        get collection_number_entry_path(set: "mh3", type: { a: "b" })
        expect(response).to redirect_to(collection_number_entry_path(**page_params))
      end

      it "says so for a language the set lacks (AC-1.11)" do
        printing("1")
        get collection_number_entry_path(**page_params, language: "fr")
        expect(response.body).to include("No set matches “mh3”. Type a set code or choose a set from the list.")
      end

      it "shows the list under the set field after Change set (AC-1.9)", :aggregate_failures do
        NumberEntry.add!(account: user.account, entry: printing("1", "Flare"), quantity: 1, finish: "nonfoil", line_key: "a" * 32)
        get collection_number_entry_path
        expect(response.body).to include('id="number_entry_set"', "This list: 1 line, 1 card", "Flare")
      end

      it "replaces the page on a refresh, where other pages morph", :aggregate_failures do
        printing("1")
        get collection_number_entry_path(**page_params)
        expect(response.body).to include('<meta name="turbo-refresh-method" content="replace">')
        get collection_path
        expect(response.body).to include('<meta name="turbo-refresh-method" content="morph">')
      end

      it "says when the catalog has no sets, showing no form", :aggregate_failures do
        get collection_number_entry_path
        expect(response.body).to include("The card catalog hasn't been loaded yet.")
        expect(response.body).not_to include('id="number_entry_set"')
      end
    end

    describe "adding a line" do
      it "adds a copy with the type's first finish and lists it, keeping the set (AC-2.1, AC-2.2)", :aggregate_failures do
        entry = printing("47", "Psychic Frog")
        add("47")
        expect(response).to redirect_to(collection_number_entry_path(**page_params, finish: "nonfoil"))
        expect(user.account.lots.sole).to have_attributes(entry:, quantity: 1, finish: "nonfoil", condition: nil, price_paid_cents: nil)
        follow_redirect!
        expect(response.body).to include("Added 1 × Psychic Frog (MH3 · 47, Nonfoil) to your collection.", "This list: 1 line, 1 card", "MH3 · 47 · ×1")
        expect(response.body).to match(/<input[^>]*id="line_number"[^>]*value=""|<input(?![^>]*value=)[^>]*id="line_number"/)
      end

      it "adds the quantity typed (AC-2.3)" do
        printing("47")
        add("47", quantity: "4")
        expect(user.account.lots.sole.quantity).to eq(4)
      end

      it "adds a chosen finish and keeps it for the next line (AC-2.4)", :aggregate_failures do
        printing("47")
        add("47", finish: "foil")
        expect(user.account.lots.sole.finish).to eq("foil")
        follow_redirect!
        expect(response.body).to include('<option selected="selected" value="foil">Foil</option>')
      end

      it "merges into the lot of the same identity (AC-2.5)", :aggregate_failures do
        entry = printing("47")
        create(:lot, account: user.account, entry:, finish: "nonfoil", quantity: 2)
        add("47", quantity: "3", finish: "nonfoil")
        expect(user.account.lots.sole.quantity).to eq(5)
      end

      it "matches ignoring spaces, case and leading zeros, in the chosen language (AC-2.6, AC-2.7)", :aggregate_failures do
        seven = printing("7")
        letter = printing("117a")
        printing("7", language: "ja")
        [ "007", " 7 ", "117A" ].each { add(it) }
        expect(user.account.lots.to_h { [ it.entry, it.quantity ] }).to eq(seven => 2, letter => 1)
      end

      it "asks which of two matches, adding nothing, and adds the one picked (AC-2.9)", :aggregate_failures do
        one = printing("049", "Frog A")
        printing("49", "Frog B")
        add("0049", quantity: "2")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("More than one card matches 0049. Choose one.", "Frog A (MH3 · 049)", "Frog B (MH3 · 49)")
        expect(user.account.lots).to be_empty
        add("0049", quantity: "2", pick: one.external_key)
        expect(user.account.lots.sole).to have_attributes(entry: one, quantity: 2)
      end

      it "adds nothing for a pick that isn't one of the matches (AC-2.10)", :aggregate_failures do
        printing("049")
        printing("49")
        elsewhere = create(:catalog_entry, number: "49")
        add("0049", pick: elsewhere.external_key)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("No card numbered 0049 in Modern Horizons 3 (EN).")
        expect(user.account.lots).to be_empty
      end

      it "adds a line once for one line key, and twice for two (AC-2.11, AC-2.12)", :aggregate_failures do
        printing("47")
        add("47", line_key: "a" * 32)
        add("47", line_key: "a" * 32)
        expect(user.account.lots.sole.quantity).to eq(1)
        add("47", line_key: "b" * 32)
        expect(user.account.lots.sole.quantity).to eq(2)
        expect(user.account.number_entry.lines.count).to eq(2)
      end

      it "adds a token from a token set (AC-2.14)" do
        tokens = create(:catalog_set, code: "tmh3", name: "Modern Horizons 3 Tokens")
        token = printing("5", set: tokens, kind: "token", finishes: %w[nonfoil])
        add("5", set: "tmh3")
        expect(user.account.lots.sole.entry).to eq(token)
      end

      it "adds no finish for an entry that lists none (AC-2.15)" do
        printing("60", finishes: nil)
        add("60")
        expect(user.account.lots.sole.finish).to be_nil
      end
    end

    describe "a rejected line" do
      it "keeps the line when no entry has the number (AC-4.1)", :aggregate_failures do
        printing("47")
        add("999", quantity: "3", finish: "foil")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("No card numbered 999 in Modern Horizons 3 (EN).", 'value="999"', 'value="3"',
          '<option selected="selected" value="foil">Foil</option>')
        expect(response.body).to match(/<input[^>]*id="line_number"[^>]*autofocus/)
        expect(response.body).to include('data-select="true"')
        expect(user.account.lots).to be_empty
      end

      it "says what's wrong with the quantity, focusing it (AC-4.2)", :aggregate_failures do
        printing("47")
        %w[0 -1 2.5 x 10000].each do |quantity|
          add("47", quantity:)
          expect(response.body).to include("Quantity must be a whole number from 1 to 9,999"), quantity
          expect(response.body).to match(/<input[^>]*id="line_quantity"[^>]*autofocus/)
        end
        expect(user.account.lots).to be_empty
      end

      it "refuses a finish the entry doesn't offer (AC-4.3)", :aggregate_failures do
        printing("50", finishes: %w[nonfoil])
        add("50", finish: "foil")
        expect(response.body).to include("Finish isn&#39;t available for this printing")
        expect(user.account.lots).to be_empty
      end

      it "refuses at the lot cap (AC-4.4)", :aggregate_failures do
        entry = printing("47")
        create(:lot, account: user.account, entry:, finish: "nonfoil", quantity: 9_998)
        add("47", quantity: "2")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("One lot can hold at most 9,999 copies.")
        expect(user.account.lots.sole.quantity).to eq(9_998)
        expect(NumberEntry::Line.count).to eq(0)
      end

      it "adds nothing for an empty number, with no message (AC-4.5)", :aggregate_failures do
        printing("47")
        add("  ")
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).not_to include("c-field__error")
        expect(response.body).to match(/<input[^>]*id="line_number"[^>]*autofocus/)
        expect(user.account.lots).to be_empty
      end
    end
  end

  context "when signed out" do
    before { user } # with no account at all, the app sends a first visitor to sign up instead

    it "sends a visitor to sign in (AC-1.10)" do
      get collection_number_entry_path
      expect(response).to redirect_to(new_session_path)
    end

    it "sends a visitor to sign in when the catalog is open (AC-1.10)", :public_catalog do
      get collection_number_entry_path(**page_params)
      expect(response).to redirect_to(new_session_path)
    end
  end
end
