require "rails_helper"

# The narrow-frame helper (spec/support/narrow_frame.rb) is what every phone-width example trusts to say a page doesn't
# scroll sideways (#318), so it is checked against a page it can make overflow.
RSpec.describe "The narrow-frame helper", type: :system do
  # A short frame, so the sign-in page is taller than it and the frame draws its (classic, 15px in system specs) vertical scrollbar.
  def open_sign_in_frame
    visit new_session_path
    open_in_narrow_frame(new_session_path, width: 360, height: 320, ready: "main")
  end

  # Makes the frame's page scroll sideways by overflow px (a one-pixel-high box at the left edge, wider than the viewport) and
  # returns what the frame measured, so an example can't pass while its overflow or its scrollbar is not really there.
  def overflow_frame_page(overflow)
    within_narrow_frame do
      page.evaluate_script(<<~JS, overflow)
        (() => { const doc = document.documentElement
          const box = document.createElement("div")
          box.style.cssText = `position:absolute;left:0;top:0;height:1px;width:${doc.clientWidth + arguments[0]}px`
          document.body.append(box)
          return { scrollbar: window.innerWidth - doc.clientWidth, overflow: doc.scrollWidth - doc.clientWidth } })()
      JS
    end
  end

  it "reports a page that fits as fitting", :aggregate_failures do
    expect(open_sign_in_frame).to eq([ 360, true ])
    expect(narrow_frame_fits?).to be(true)
  end

  # The trap of #318: the old comparison was against innerWidth, which includes the scrollbar, so a page scrolling sideways
  # by less than the scrollbar's width passed whenever the frame scrolled vertically.
  it "reports a page that scrolls sideways by less than a scrollbar's width", :aggregate_failures do
    open_sign_in_frame
    measured = overflow_frame_page(5)
    expect(measured["scrollbar"]).to be > 5
    expect(measured["overflow"]).to eq(5)
    expect(narrow_frame_fits?).to be(false)
  end
end
