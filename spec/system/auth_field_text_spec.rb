require "rails_helper"

# Issue #188: the auth card sizes its own paragraphs, and that rule must not reach the hints and
# errors inside the form, which follow Form's caption size like every other form.
RSpec.describe "Auth page field text", type: :system do
  # The font size the same class gets outside the auth card, on a bare probe in the page body.
  def caption_size(css_class)
    page.evaluate_script(<<~JS)
      (() => {
        const probe = document.createElement("p");
        probe.className = #{css_class.to_json};
        document.body.appendChild(probe);
        const size = getComputedStyle(probe).fontSize;
        probe.remove();
        return size;
      })()
    JS
  end

  def font_size_of(selector)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).fontSize")
  end

  it "sets the sign-up password hint at Form's caption size", :aggregate_failures do
    visit new_registration_path
    expect(page).to have_css(".c-auth .c-field__hint", text: "At least 12 characters.")
    expect(caption_size("c-field__hint")).to eq("12px")
    expect(font_size_of(".c-auth .c-field__hint")).to eq(caption_size("c-field__hint"))
  end

  it "sets the sign-up field errors at Form's caption size", :aggregate_failures do
    visit new_registration_path
    fill_in "Name", with: "Ada"
    fill_in "Email", with: "ada@example.com"
    fill_in "Password", with: "short"
    fill_in "Confirm password", with: "different"
    click_button "Create admin account"
    expect(page).to have_css(".c-auth .c-field__error")
    expect(caption_size("c-field__error")).to eq("12px")
    all(".c-auth .c-field__error").each do |error|
      expect(page.evaluate_script("getComputedStyle(arguments[0]).fontSize", error)).to eq(caption_size("c-field__error"))
    end
  end

  it "keeps the explanatory paragraph at the auth card's size", :aggregate_failures do
    visit new_registration_path
    expect(page).to have_css(".c-auth > p", text: "This first account will be the admin")
    expect(font_size_of(".c-auth > p")).to eq("15px")
  end
end
