require "rails_helper"

# Issue #208: just above the 640px breakpoint the wide table's other columns need about 661px, so for a container of 640 to
# about 660px the table spilled out of .c-collection even with a short place name. The widest flexible column gives instead,
# so the table is never wider than its container at 640px and up.
RSpec.describe "The wide collection table's fit", type: :system do
  let(:user) { system_sign_in_as(create(:user)) }
  let(:table_path) { collection_path(view: "table") }

  # Measured in the narrow frame, from the top page (as collection_row_place_spec's #measures): the table's width and its container's.
  def measure_fit
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const doc = document.getElementById("narrow").contentWindow.document
        return { table: doc.querySelector("table.c-table").getBoundingClientRect().width,
                 container: doc.querySelector(".c-collection").clientWidth }
      })()
    JS
  end

  # Frames 740, 760 and 800 are containers of about 645, 665 and 705px; 1280 is the wide layout the fix leaves as it is.
  describe "with a short place name" do
    [ 735, 740, 760, 800, 1280 ].each do |width| # 735px is a container of exactly 640px, the first with the wide layout
      it "is no wider than .c-collection at a #{width}px frame", :aggregate_failures do
        owned_printing("Lightning Bolt", account: user.account, set: create(:catalog_set, code: "mh3"), number: "146",
                       location: create(:location, account: user.account, name: "Binder"))
        visit table_path
        expect(open_in_narrow_frame(table_path, width:, ready: "td.c-table__place")).to eq([ width, true ])
        seen = measure_fit
        expect(seen[:table]).to be <= seen[:container] + 0.5
      end
    end
  end

  describe "with a long card name" do
    it "cuts the name to one line at 740px and still fits", :aggregate_failures do
      owned_printing("Sword of Fire and Ice and Other Long Names of Cards", account: user.account, set: create(:catalog_set, code: "mh3"), number: "146",
                     location: create(:location, account: user.account, name: "Binder"))
      visit table_path
      expect(open_in_narrow_frame(table_path, width: 740, ready: "td.c-table__place")).to eq([ 740, true ])
      seen = measure_fit
      expect(seen[:table]).to be <= seen[:container] + 0.5
      within_narrow_frame do
        link = find(".c-table__item a")
        expect(link.text).to eq("Sword of Fire and Ice and Other Long Names of Cards")
        expect(find(".c-table__name").evaluate_script("this.getBoundingClientRect().height")).to be < 20
      end
    end
  end
end
