require "rails_helper"

RSpec.describe "Scanner other printings", type: :request do
  let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }
  let(:key) { "c" * 32 }

  before do
    sign_in_as(create(:user))
    { "m10" => Date.new(2009, 7, 17), "m11" => Date.new(2010, 7, 16) }.each do |code, released_on|
      set = create(:catalog_set, code:, name: "Set #{code}", released_on:)
      create(:mtg_printing, finishes: %w[nonfoil foil], entry: create(:catalog_entry, identity:, name: "Lightning Bolt", set:, number: "146", released_on:))
    end
  end

  def other_printings(**params)
    get scanner_printings_path(card: identity.external_key, key:, **params), headers: { "Turbo-Frame" => "scanner_printings" }
  end

  it "answers the frame with the card's printings, each with add buttons for the same reading (AC-2.2, AC-2.6)", :aggregate_failures do
    other_printings(set: "m10", number: "146")
    frame = Nokogiri::HTML5(response.body).at_css("turbo-frame#scanner_printings")
    expect(frame.at_css("h2").text).to eq("Other printings of Lightning Bolt")
    expect(frame.css("li .is-data").map(&:text)).to eq([ "M10 · 146", "M11 · 146" ])
    expect(frame.css("li .c-list__meta").first.text).to include("Set m10", "17 July 2009")
    expect(frame.css("input[name='entry[reading_key]']").map { it["value"] }.uniq).to eq([ key ])
    expect(frame.css("form.c-scanner__add").map { it["data-rank"] }.uniq).to eq([ "other" ])
    expect(response.body).not_to include("turbo-visit-control")
  end

  it "marks the Foil buttons when the reading suggested foil (AC-6.5)" do
    other_printings(finish_hint: "foil")
    expect(Nokogiri::HTML5(response.body).css("form.c-scanner__add button").map { it.text.strip }.uniq).to eq([ "Nonfoil", "Foil · read from the card" ])
  end

  it "shows 20, and the rest behind a control (AC-2.5)", :aggregate_failures do
    25.times { create(:catalog_entry, identity:, name: "Lightning Bolt", released_on: Date.new(2000, 1, 1)) }
    other_printings
    html = Nokogiri::HTML5(response.body)
    expect(html.css("turbo-frame > section > ul > li").size).to eq(20)
    expect(html.at_css("details summary").text.strip).to eq("Show 7 more")
  end

  it "answers 404 for a malformed key or an unknown card", :aggregate_failures do
    other_printings(key: "nope")
    expect(response).to have_http_status(:not_found)
    get scanner_printings_path(card: "unknown", key:)
    expect(response).to have_http_status(:not_found)
  end

  it "lists the confident artwork's printings first, newest first, then spec 009's order (spec 011 AC-7.5)", :aggregate_failures do
    art = "aaaaaaaa-0000-4000-8000-000000000001"
    m11 = Catalog::Entry.joins(:set).find_by!(catalog_sets: { code: "m11" })
    MTG::Printing.find_by!(catalog_entry_id: m11.id).update!(illustration_id: art)

    other_printings(set: "m10", number: "146", artwork: art)
    expect(Nokogiri::HTML5(response.body).css("li .is-data").map(&:text)).to eq([ "M11 · 146", "M10 · 146" ])

    other_printings(set: "m10", number: "146", artwork: "not-an-artwork")
    expect(Nokogiri::HTML5(response.body).css("li .is-data").map(&:text)).to eq([ "M10 · 146", "M11 · 146" ])
  end
end
