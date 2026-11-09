require "rails_helper"

# Issue #208: just above the 640px breakpoint the wide table's other columns need about 531px, so a name column that held
# its whole name pushed the table past .c-collection for a container of 640 to about 670px, even with a short place name.
# The name column gives (one line, an ellipsis) in a band of 640 to 699px of container, so the table is never wider than its
# container from 640px up, and a layout from 700px up, where the place line gives instead (spec 048), is as it was.
# A frame is 95px wider than its container: 735px is a container of 640px, 740px of 645px, 800px of 705px.
RSpec.describe "The wide collection table's fit", type: :system do
  let(:user) { system_sign_in_as(create(:user)) }
  let(:table_path) { collection_path(view: "table") }
  let(:spaced) { "Blue binder, shelf three, left side, behind the board games." } # 60 code points, as spec 048's

  def own(name, place)
    owned_printing(name, account: user.account, set: create(:catalog_set, code: "mh3"), number: "146",
                         location: create(:location, account: user.account, name: place))
  end

  # Measured in the narrow frame, from the top page (as collection_row_place_spec's #measures): the table's width and its
  # container's, and how many lines the name's link takes (a clamped name still lays out its second line, hidden).
  def measure_fit
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const doc = document.getElementById("narrow").contentWindow.document
        const range = doc.createRange()
        range.selectNodeContents(doc.querySelector(".c-table__name a"))
        return { table: doc.querySelector("table.c-table").getBoundingClientRect().width,
                 container: doc.querySelector(".c-collection").clientWidth,
                 lines: range.getClientRects().length }
      })()
    JS
  end

  def measure_at(width, path)
    expect(open_in_narrow_frame(path, width:, ready: "td.c-table__place")).to eq([ width, true ])
    measure_fit
  end

  describe "with a short place name" do
    [ 735, 740, 760, 800, 1280 ].each do |width|
      it "is no wider than .c-collection at a #{width}px frame", :aggregate_failures do
        own("Lightning Bolt", "Binder")
        visit table_path
        seen = measure_at(width, table_path)
        expect(seen[:table]).to be <= seen[:container] + 0.5
      end
    end
  end

  describe "in bulk mode, which adds a checkbox column" do
    [ 735, 740, 760, 800 ].each do |width|
      it "is no wider than .c-collection at a #{width}px frame", :aggregate_failures do
        own("Lightning Bolt", "Binder")
        visit collection_path(view: "table", bulk: 1)
        seen = measure_at(width, collection_path(view: "table", bulk: 1))
        expect(seen[:table]).to be <= seen[:container] + 0.5
      end
    end
  end

  describe "with a long card name" do
    it "cuts the name to one line at 740px, whole in its link's text, and still fits", :aggregate_failures do
      name = "Sword of Fire and Ice and Other Long Names of Cards"
      own(name, "Binder")
      visit table_path
      seen = measure_at(740, table_path)
      expect(seen[:table]).to be <= seen[:container] + 0.5
      expect(seen[:lines]).to be > 1 # laid out on more than one line, all but the first clamped away
      within_narrow_frame { expect(find(".c-table__item a").text).to eq(name) }
    end

    it "keeps the name where it is when a keyboard focus reaches its link", :aggregate_failures do
      own("Lightning Bolt", "Binder")
      visit table_path
      open_in_narrow_frame(table_path, width: 740, ready: "td.c-table__place")
      within_narrow_frame do
        find(".c-table__item a").evaluate_script("this.focus()")
        expect(page.evaluate_script("[...document.querySelectorAll('.c-table__name, .c-table__name a')].map((el) => el.scrollTop)")).to eq([ 0, 0 ])
      end
    end
  end

  describe "with a long place name (spec 048)" do
    [ 800, 900, 1024 ].each do |width|
      it "keeps the card name whole at a #{width}px frame, as the wrapping place line gives instead", :aggregate_failures do
        own("Lightning Bolt", spaced)
        visit table_path
        seen = measure_at(width, table_path)
        expect(seen[:table]).to be <= seen[:container] + 0.5
        expect(seen[:lines]).to eq(1)
      end
    end
  end
end
