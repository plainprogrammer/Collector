require "rails_helper"

# Spec 048: a table row's place line wraps, on a phone (AC-1.1, AC-1.2) and in the wide Location cell (AC-1.3, AC-1.4),
# so no name makes the page scroll sideways; a table with no location is unchanged (AC-1.7). AC-1.6 (a tile's place is
# still cut with an ellipsis) is spec 033's example "keeps a long place name to one line on a tile" in
# collection_table_spec.rb, which must stay green.
RSpec.describe "A table row's place line", type: :system do
  spaced = "Blue binder, shelf three, left side, behind the board games." # 60 code points
  unbroken = "W" * 60

  let(:user) { system_sign_in_as(create(:user)) }
  let(:table_path) { collection_path(view: "table") }

  def own_in(name)
    owned_printing("Lightning Bolt", account: user.account, number: "146", location: create(:location, account: user.account, name:))
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
        owned_printing("Lightning Bolt", account: user.account, number: "146", quantity: 9_999, finish: "foil", condition: "near_mint")
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
  end
end
