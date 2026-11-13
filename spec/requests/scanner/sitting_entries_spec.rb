require "rails_helper"

RSpec.describe "Scanner adds", type: :request do
  let(:user) { create(:user) }
  let(:mom) { create(:catalog_set, code: "mom", name: "March of the Machine") }
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:printing) do
    create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set: mom, number: "123")).entry
  end
  let(:key) { "a" * 32 }

  before { sign_in_as(user) }

  def add(finish: "foil", reading_key: key, to: printing.external_key)
    post scanner_sitting_entries_path, params: { entry: { printing: to, finish:, reading_key: } },
      headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
  end

  # The stream of an answer for `target`, as Nokogiri sees it; its template's text is what the page gets.
  def stream(target, action = nil)
    selector = "turbo-stream[target=#{target}]#{"[action=#{action}]" if action}"
    Nokogiri::HTML5(response.body).at_css(selector)
  end

  def text_of(target, action = "update") = stream(target, action).at_css("template").text.strip

  it "adds one copy, empties the pane and the lines, says so on the after-add line and redraws the sitting (AC-4.7, AC-5.1, AC-5.2)", :aggregate_failures do
    add
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect([ text_of("scanner_result"), text_of("status"), text_of("scanner_status_text") ]).to all(be_empty)
    expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
    expect(user.account.lots.sole).to have_attributes(entry: printing, finish: "foil", quantity: 1, condition: nil)
  end

  it "offers Undo for the entry, with focus on the main button, redraws the bar and the count and retitles the list (AC-5.1, AC-5.3)", :aggregate_failures do
    add
    undo = stream("scanner_added_action", "replace").at_css("form[data-scanner-event=undo]")
    expect(undo["action"]).to eq(scanner_sitting_entry_undo_path(Scanner::SittingEntry.sole))
    expect(stream("scanner_added_action", "replace").at_css("[data-sitting-focus-to-value=main]")).to be_present
    expect(stream("scanner_sitting", "replace")).to be_present
    expect(stream("scanner_sitting_bar", "replace")).to be_present
    expect(stream("scanner_count", "replace").at_css("[aria-label]")["aria-label"]).to eq("1 added. Show this sitting's cards.")
    expect(text_of("scanner-sitting-heading")).to eq("This sitting: 1 card")
  end

  it "escapes a place's name in the list's title (security)", :aggregate_failures do
    Scanner::Sitting.choose!(account: user.account, location: create(:location, account: user.account, name: "<b>bold</b>"))
    add
    template = stream("scanner-sitting-heading", "update").at_css("template")
    expect(template.inner_html).to include("&lt;b&gt;")
    expect(template.at_css("b")).to be_nil
  end

  it "leaves the finish out of the message for a printing with none listed (AC-1.3)" do
    MTG::Printing.find_by!(catalog_entry_id: printing.id).update!(finishes: [])
    add(finish: "")
    expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123")
  end

  it "adds nothing for a reading already added, and answers as if it had just succeeded (AC-1.5)", :aggregate_failures do
    add
    add(finish: "nonfoil")
    expect(response).to have_http_status(:ok)
    expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
    expect(user.account.lots.sum(:quantity)).to eq(1)
  end

  it "says so when the reading's add was undone, or its copy changed, adding nothing (AC-1.5)", :aggregate_failures do
    add
    Scanner::SittingEntry.sole.undo!
    add
    expect(text_of("status")).to eq("You added this card, then undid it. Scan it again to add it.")
    expect(stream("status").at_css(".c-status__message--alert")).to be_present
    expect(stream("scanner_added_text")).to be_nil
    expect(text_of("scanner_result")).to be_empty
    add(reading_key: "b" * 32)
    user.account.lots.sole.destroy!
    add(reading_key: "b" * 32)
    expect(text_of("status")).to eq("You added this card, and it has since changed in your collection.")
    expect(user.account.lots).to be_empty
  end

  it "refuses at the lot cap, adding nothing (AC-1.6)", :aggregate_failures do
    create(:lot, account: user.account, entry: printing, finish: "foil", quantity: Lot::MAX_QUANTITY)
    add
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("You already have the most copies one lot can hold (9,999).")
    expect(Scanner::SittingEntry.count).to eq(0)
  end

  it "refuses a missing or malformed key, an unknown or retired printing and a finish it doesn't come in (Error Scenarios)", :aggregate_failures do
    retired = create(:mtg_printing, entry: create(:catalog_entry, :retired)).entry
    [ { reading_key: "" }, { reading_key: "XYZ" }, { to: "nope" }, { to: retired.external_key }, { finish: "etched" } ].each do |change|
      add(**change)
      expect(response).to have_http_status(:unprocessable_content), change.inspect
      expect(CGI.unescapeHTML(response.body)).to include("That card couldn't be added. Scan it again.")
    end
    expect(user.account.lots).to be_empty
  end

  it "adds to the signed-in account's own sitting only (AC-3.8)", :aggregate_failures do
    other = create(:user).account
    Scanner::Sitting.add!(account: other, printing:, finish: "nonfoil", reading_key: key)
    add
    expect(other.lots.sole.finish).to eq("nonfoil")
    expect(user.account.scanner_sitting.entries.sole.finish).to eq("foil")
  end

  describe "into the sitting's place (spec 040)" do
    def blue = @blue ||= create(:location, account: user.account, name: "Blue binder")
    def place(location) = Scanner::Sitting.choose!(account: user.account, location:)
    def html = Nokogiri::HTML5(response.body)

    it "adds into the place, names it on the top bar and not on the after-add line (AC-5.1, decision 12)", :aggregate_failures do
      place(blue)
      add
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
      expect(user.account.lots.sole).to have_attributes(location: blue, quantity: 1, finish: "foil")
      expect(html.at_css("#scanner_sitting_bar .c-scan__dest-text").text).to eq("Blue binder")
    end

    it "shows No location on the top bar with no place set (AC-2.3)", :aggregate_failures do
      blue
      add
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
      expect(user.account.lots.sole.location).to be_nil
      expect(html.at_css("#scanner_sitting_bar .c-scan__dest-text").text).to eq("No location")
    end

    it "refuses at the cap in the place with the existing message (AC-1.6)", :aggregate_failures do
      create(:lot, account: user.account, entry: printing, finish: "foil", quantity: Lot::MAX_QUANTITY, location: blue)
      place(blue)
      add
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("You already have the most copies one lot can hold (9,999).")
    end

    it "adds nothing on a replay after the sitting's place changed (AC-4.3)", :aggregate_failures do
      place(blue)
      add
      place(create(:location, account: user.account, name: "Long box"))
      add
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
      expect(user.account.lots.sum(:quantity)).to eq(1)
    end

    it "adds unplaced and shows No location once the place's location was removed (AC-3.2)", :aggregate_failures do
      place(blue)
      delete location_path(blue)
      add
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
      expect(user.account.lots.sole.location).to be_nil
      expect(html.at_css("#scanner_sitting_bar .c-scan__dest-text").text).to eq("No location")
    end
  end

  describe "with the sitting's condition (spec 042)" do
    def blue = @blue ||= create(:location, account: user.account, name: "Blue binder")
    def choose(**choices) = Scanner::Sitting.choose!(account: user.account, **choices)
    def html = Nokogiri::HTML5(response.body)

    it "adds into the lot of that condition and shows its short label on the top bar (AC-1.3, AC-2.3)", :aggregate_failures do
      choose(condition: "near_mint")
      add
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
      expect(user.account.lots.sole).to have_attributes(condition: "near_mint", finish: "foil", location: nil, price_paid_cents: nil)
      expect(html.at_css("#scanner_sitting_bar .c-scan__dest-text").text).to eq("No location · NM")
      expect(html.at_css("#scanner_sitting li .c-list__meta").text.squish).to match(/\AMOM · 123 · Foil · NM · Added/)
    end

    it "adds into the condition and the place together, the top bar naming both (AC-1.4)", :aggregate_failures do
      choose(condition: "near_mint", location: blue)
      add
      expect(html.at_css("#scanner_sitting_bar .c-scan__dest-text").text).to eq("Blue binder · NM")
      expect(user.account.lots.sole).to have_attributes(condition: "near_mint", location: blue)
    end

    it "leaves the finish out for a printing with none listed, keeping the condition (decision 3)", :aggregate_failures do
      MTG::Printing.find_by!(catalog_entry_id: printing.id).update!(finishes: [])
      choose(condition: "near_mint")
      add(finish: "")
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123")
      expect(user.account.lots.sole.condition).to eq("near_mint")
    end

    # Passes before the change: regression guard.
    it "adds with no condition when the sitting has none (AC-1.5)", :aggregate_failures do
      choose(location: blue)
      add
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
      expect(user.account.lots.sole.condition).to be_nil
    end

    # Passes before the change: regression guard.
    it "keeps the Undo announcement and the accessible names free of the condition (decision 3)", :aggregate_failures do
      choose(condition: "near_mint")
      add
      expect(html.at_css("#scanner_sitting form.c-scanner__undo input[type=submit], #scanner_sitting form.c-scanner__undo button")["aria-label"]).to eq("Undo Lightning Bolt (MOM · 123, Foil)")
      expect(html.at_css("#scanner_added_action button")["aria-label"]).to eq("Undo Lightning Bolt (MOM · 123, Foil)")
      expect(html.at_css("#scanner_sitting a[data-scanner-event=details]")["aria-label"]).to eq("Details of Lightning Bolt (MOM · 123, Foil)")
      post scanner_sitting_entry_undo_path(Scanner::SittingEntry.sole), headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(text_of("scanner_added_text")).to eq("Removed 1 × Lightning Bolt (MOM · 123, Foil) from your collection.")
    end

    # Passes before the change: regression guard.
    it "refuses at the cap of the lot of that condition with the existing message, while Not specified takes the card (AC-1.6)", :aggregate_failures do
      create(:lot, account: user.account, entry: printing, finish: "foil", condition: "near_mint", quantity: Lot::MAX_QUANTITY)
      choose(condition: "near_mint")
      add
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("You already have the most copies one lot can hold (9,999).")
      expect(Scanner::SittingEntry.count).to eq(0)
      choose(condition: nil)
      add
      expect(response).to have_http_status(:ok)
    end

    it "adds nothing on a replay after the sitting's condition and place changed (AC-4.4)", :aggregate_failures do
      choose(condition: "near_mint", location: blue)
      add
      choose(condition: "damaged", location: create(:location, account: user.account, name: "Long box"))
      add
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
      expect(user.account.lots.sum(:quantity)).to eq(1)
    end

    it "keeps the after-add line free of the condition after the lot was edited (decision 12)" do
      choose(condition: "near_mint")
      add
      user.account.lots.sole.update!(condition: "lightly_played")
      add
      expect(text_of("scanner_added_text")).to eq("Added Lightning Bolt MOM · 123, foil")
    end

    # Passes before the change: regression guard.
    it "refuses a condition the printing's vocabulary doesn't know with the not-added message, not the cap, recording nothing (AC-4.5)", :aggregate_failures, :other_collecting do
      other = create(:catalog_entry, collectible_type: "other")
      choose(condition: "near_mint")
      add(finish: "", to: other.external_key)
      expect(response).to have_http_status(:unprocessable_content)
      body = CGI.unescapeHTML(response.body)
      expect(body).to include("That card couldn't be added. Scan it again.")
      expect(body).not_to include("9,999")
      expect([ user.account.lots.count, Scanner::SittingEntry.count ]).to eq([ 0, 0 ])
    end
  end

  it "sends a signed-out visitor to sign in" do
    delete session_path
    add
    expect(response).to redirect_to(new_session_path)
  end
end
