require "rails_helper"

# Spec 048: a table row's place line wraps, on a phone (AC-1.1, AC-1.2) and in the wide Location cell (AC-1.3, AC-1.4),
# so no name makes the page scroll sideways; a table with no location is unchanged (AC-1.7). A no-location line wider than
# its room wraps at a phone's 360px content width (spec 061 AC-1.1, AC-1.2, which restates AC-1.8). AC-1.6 (a tile's place is
# still cut with an ellipsis) is spec 033's example "keeps a long place name to one line on a tile" in
# collection_table_spec.rb, which must stay green.
RSpec.describe "A table row's place line", type: :system do
  spaced = "Blue binder, shelf three, left side, behind the board games." # 60 code points
  unbroken = "W" * 60

  let(:user) { system_sign_in_as(create(:user)) }
  let(:table_path) { collection_path(view: "table") }

  # The set code is pinned to a realistic three-character one: the factory's sequence makes it up to five characters late in a full run
  # (such as `S2000`), which can wrap the line in the suite's 360px frame, whose classic scrollbar leaves 345px, and not on a phone (spec 061).
  def own_in(name)
    owned_printing("Lightning Bolt", account: user.account, set: create(:catalog_set, code: "mh3"), number: "146", location: create(:location, account: user.account, name:))
  end

  # Called from the top page, after open_in_narrow_frame (it reaches the frame through #narrow; inside within_narrow_frame that
  # element doesn't exist). Measured in the narrow frame: the table's width, its container's clientWidth, the name span's width in rem,
  # whether the name's text stays inside the span (it doesn't when it can't break), and the span's height in px.
  def measures
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const view = document.getElementById("narrow").contentWindow
        const doc = view.document
        const span = doc.querySelector(".c-table__place-name")
        const root = parseFloat(view.getComputedStyle(doc.documentElement).fontSize)
        return { table: doc.querySelector("table.c-table").getBoundingClientRect().width,
                 container: doc.querySelector(".c-collection").clientWidth,
                 rem: span && span.getBoundingClientRect().width / root,
                 inside: span && span.scrollWidth <= span.clientWidth + 1,
                 height: span && span.getBoundingClientRect().height }
      })()
    JS
  end

  # Measured in the narrow frame (spec 061 decision 2): the phone line's room (its clientWidth while its text wraps), its
  # height, its unwrapped width (a range over its contents with wrapping switched off, then restored) and the page's
  # scrollbar width (15px classic, 0 overlay). Room grows one for one with the frame's content width, so
  # room + scrollbar is the room a 360px content width gives.
  def line_measures
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const view = document.getElementById("narrow").contentWindow
        const doc = view.document
        const line = doc.querySelector(".c-table__sub")
        const room = line.clientWidth
        const height = line.getBoundingClientRect().height
        const before = line.style.whiteSpace
        line.style.whiteSpace = "nowrap"
        const range = doc.createRange()
        range.selectNodeContents(line)
        const unwrapped = range.getBoundingClientRect().width
        line.style.whiteSpace = before
        return { room, height, unwrapped, scrollbar: view.innerWidth - doc.documentElement.clientWidth }
      })()
    JS
  end

  describe "on a phone" do
    [ 360, 390 ].each do |width|
      { "with spaces" => spaced, "with no space" => unbroken }.each do |label, name|
        it "shows a name #{label} whole in the line under the name, with no sideways scroll, at #{width}px", :aggregate_failures do # AC-1.1, AC-1.2
          own_in(name)
          visit table_path
          expect(open_in_narrow_frame(table_path, width:, ready: "tbody tr")).to eq([ width, true ])
          within_narrow_frame do
            expect(find(".c-table__sub", visible: :visible).text).to end_with(" · #{name}")
          end
        end
      end
    end
  end

  describe "in the wide table" do
    [ 800, 900, 1024, 1280 ].each do |width|
      { "with spaces" => spaced, "with no space" => unbroken }.each do |label, name|
        it "keeps a name #{label} whole in the cell, within 20rem and within the table's container, at #{width}px", :aggregate_failures do # AC-1.3, AC-1.4
          own_in(name)
          visit table_path
          expect(open_in_narrow_frame(table_path, width:, ready: "td.c-table__place")).to eq([ width, true ])
          seen = measures
          within_narrow_frame { expect(find(".c-table__place-name", visible: :visible).text.squish).to eq(name) }
          expect([ seen[:table] <= seen[:container] + 1, seen[:rem] <= 20.01, seen[:inside] ]).to eq([ true, true, true ])
          expect(seen[:height]).to be > 18 if name.include?(" ") && width == 800
        end
      end
    end

    { "with spaces" => spaced, "with no space" => unbroken }.each do |label, name|
      it "does not scroll the page sideways for a name #{label} at 760px, the first width with the Location column", :aggregate_failures do # AC-1.3, AC-1.4
        own_in(name)
        visit table_path
        expect(open_in_narrow_frame(table_path, width: 760, ready: "td.c-table__place")).to eq([ 760, true ])
      end
    end
  end

  describe "for an account with no location" do
    [ 360, 390 ].each do |width|
      it "fits one line under the name at #{width}px and shows no place", :aggregate_failures do # AC-1.7
        owned_printing("Lightning Bolt", account: user.account, set: create(:catalog_set, code: "mh3"), number: "146", quantity: 9_999, finish: "foil", condition: "near_mint")
        visit table_path
        expect(open_in_narrow_frame(table_path, width:, ready: "tbody tr")).to eq([ width, true ])
        within_narrow_frame do
          expect(page).to have_no_css("th", text: "Location", visible: :all)
          line = find(".c-table__sub", visible: :visible)
          expect(line.text).to end_with("· 146 · Foil · NM · EN")
          expect(line.evaluate_script("this.getBoundingClientRect().height")).to be < 20
        end
      end
    end

    it "wraps a line wider than its room at a phone's 360px content width, with no sideways scroll and no place", :aggregate_failures do # spec 061 AC-1.1, AC-1.2
      owned_printing("Lightning Bolt", account: user.account, set: create(:catalog_set, code: "plst"), number: "PCY-132", quantity: 9_999, finish: "etched", condition: "near_mint")
      visit table_path
      expect(open_in_narrow_frame(table_path, width: 360, ready: "tbody tr")).to eq([ 360, true ])
      within_narrow_frame do
        expect(page).to have_no_css("th", text: "Location", visible: :all)
        expect(find(".c-table__sub", visible: :visible).text).to end_with("PLST · PCY-132 · Etched · NM · EN")
      end
      seen = line_measures
      expect(seen[:height]).to be >= 20
      margin = seen[:unwrapped] - (seen[:room] + seen[:scrollbar])
      expect(margin).to be >= 20, "margin #{margin.round(1)}: unwrapped #{seen[:unwrapped].round(1)}, room #{seen[:room]}, scrollbar #{seen[:scrollbar]}"
    end
  end

  describe "a tile" do
    it "names the whole place line in its link's accessible name, after the card's name", :aggregate_failures do # spec 033 AC-1.6, spec 048 AC-2.2
      entry = owned_printing("Lightning Bolt", account: user.account, quantity: 3, location: create(:location, account: user.account, name: "Blue binder")).entry
      create(:lot, account: user.account, entry:, finish: "foil", location: create(:location, account: user.account, name: "Long box"))
      visit collection_path(view: "grid")
      name = find("a.c-tile").native.accessible_name
      expect(name).to include("Lightning Bolt")
      expect(name).to end_with("Blue binder +1 more")
      expect(name.index("Lightning Bolt")).to be < name.index("Blue binder +1 more")
    end
  end
end
