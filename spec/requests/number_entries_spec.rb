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
