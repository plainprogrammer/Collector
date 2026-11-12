require "rails_helper"

# The narrow-frame helper (spec/support/narrow_frame.rb) is what every phone-width example trusts to say a page doesn't
# scroll sideways (#318), so it is checked against a page it can make overflow.
RSpec.describe "The narrow-frame helper", type: :system do
  # A short frame, so the sign-in page is taller than it and the frame draws its (classic, 15px in system specs) vertical scrollbar.
  def open_sign_in_frame
    visit new_session_path
    open_in_narrow_frame(new_session_path, width: 360, height: 320, ready: "main")
  end

  it "reports a page that fits as fitting", :aggregate_failures do
    expect(open_sign_in_frame).to eq([ 360, true ])
    expect(narrow_frame_fits?).to be(true)
  end
end
