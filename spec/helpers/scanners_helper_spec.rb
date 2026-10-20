require "rails_helper"

RSpec.describe ScannersHelper, type: :helper do
  let(:reading_class) { Data.define(:art_status, :overruled, :overruled_scope) }

  def reading(art_status, overruled = nil, overruled_scope = nil) = reading_class.new(art_status, overruled, overruled_scope)

  it "names the artwork's outcome for a reading sent with artworks, and nothing otherwise (AC-7.1)", :aggregate_failures do
    expect(%i[matched similar no_match].map { helper.scanner_art_outcome(reading(it)) }).to eq([ "Matched", "Looks similar", "No match" ])
    expect(helper.scanner_art_outcome(reading(nil))).to be_nil
  end

  it "says what confident art overruled, the name or the collector line, and whether the card or the printing (AC-7.4)" do
    notes = [ %i[name card], %i[name printing], %i[collector_line card], %i[collector_line printing] ]
      .map { |overruled, scope| helper.scanner_overrule_note(reading(:matched, overruled, scope)) }

    expect(notes).to eq([
      "The artwork matches a different card from the one the name suggests. The artwork's match is first.",
      "The artwork matches a different printing from the one the name suggests. The artwork's match is first.",
      "The artwork matches a different card from the one the collector line suggests. The artwork's match is first.",
      "The artwork matches a different printing from the one the collector line suggests. The artwork's match is first."
    ])
  end

  it "has no note when art overruled nothing" do
    expect(helper.scanner_overrule_note(reading(:matched))).to be_nil
  end
end
