require "rails_helper"

# The narrow-frame helper (spec/support/narrow_frame.rb) is what every phone-width example trusts to say a page doesn't
# scroll sideways (#318), so it is checked against a page it can make overflow.
RSpec.describe "The narrow-frame helper", type: :system do
  # A short frame, so the sign-up page (the first-run page, with no account yet) is taller than it and the frame draws its
  # vertical scrollbar (classic in system specs, about 12 to 15px by platform).
  def open_sign_up_frame
    visit new_registration_path
    open_in_narrow_frame(new_registration_path, width: 360, height: 320, ready: "main")
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
    expect(open_sign_up_frame).to eq([ 360, true ])
    expect(narrow_frame_fits?).to be(true)
  end

  # The trap of #318: the old comparison was against innerWidth, which includes the scrollbar, so a page scrolling sideways
  # by less than the scrollbar's width passed whenever the frame scrolled vertically.
  it "reports a page that scrolls sideways by less than a scrollbar's width", :aggregate_failures do
    open_sign_up_frame
    measured = overflow_frame_page(5)
    expect(measured["scrollbar"]).to be > 5
    expect(measured["overflow"]).to eq(5)
    expect(narrow_frame_fits?).to be(false)
  end

  # A phone's viewport is its width, with no scrollbar taken from it; the frame's classic scrollbar is (about 12 to 15px by platform).
  it "opens a frame whose viewport is the width asked for, whatever the scrollbar", :aggregate_failures do
    visit new_registration_path
    expect(open_in_viewport_frame(new_registration_path, viewport: 360, height: 320, ready: "main")).to eq(360)
    within_narrow_frame do
      expect(page.evaluate_script("document.documentElement.clientWidth")).to eq(360)
      expect(page.evaluate_script("window.innerWidth")).to be > 360 # the scrollbar is drawn, and sits outside the viewport asked for
    end
    expect(narrow_frame_fits?).to be(true)
  end

  # The same trap for the checks that run inside within_narrow_frame, or on the top page, and measure the page they are in.
  it "reports the same overflow for the page the driver is in", :aggregate_failures do
    open_sign_up_frame
    within_narrow_frame { expect(page_fits_sideways?).to be(true) }
    overflow_frame_page(5)
    within_narrow_frame { expect(page_fits_sideways?).to be(false) }
  end
end
