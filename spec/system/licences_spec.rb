require "rails_helper"

# Spec 087 AC-1.10 and AC-2.1: the licences page fits a 360px phone with a long text open, in both themes (the theme is set
# through `data-theme`, as spec/system/locations_spec.rb does), and the licence line's link lands on it.
RSpec.describe "The third-party licences page", type: :system do
  before { system_sign_in_as(create(:user)) }

  # The text box of the open row, as the browser measures it: whether it scrolls inside itself.
  def text_box
    page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector("details[open] .c-licences__text")
        const style = getComputedStyle(box)
        return { overflowY: style.overflowY, scrolls: box.scrollHeight > box.clientHeight, fitsSideways: box.scrollWidth <= box.clientWidth }
      })()
    JS
  end

  %w[light dark].each do |theme|
    it "scrolls a long licence text inside its own box and never sideways at 360px, in the #{theme} theme (AC-1.10)", :aggregate_failures do
      expect(open_in_viewport_frame(licences_path, viewport: 360, ready: "h1")).to eq(360)
      within_narrow_frame do
        page.execute_script("document.documentElement.setAttribute('data-theme', arguments[0])", theme)
        find(".c-licences__name", exact_text: "tesseract.js").click
        expect(page).to have_css("details[open] .c-licences__text")

        expect(text_box).to include("scrolls" => true, "overflowY" => "auto", "fitsSideways" => true)
        expect(page_fits_sideways?).to be(true)
      end
    end
  end

  it "opens from the licence line's link on a signed-in page (AC-2.1)", :aggregate_failures do
    visit more_path
    within("footer.c-footer") { click_link "third-party licences" }

    expect(page).to have_current_path(licences_path)
    expect(page).to have_css("h1", text: "Third-party licences")
  end
end
