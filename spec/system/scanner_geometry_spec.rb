require "rails_helper"

# Spec 082 decisions 2 and 3: the live guide sits in the stage's aiming area (the stage less its top 64px), as large as 80% of
# that height allows, never narrower than the shipped framing's guide for the stage's width, at most 97.5% of the width and 95%
# of the area's height. The shipped framing (the photo path's) is unchanged. The module is loaded into the page as the scanner
# helpers load it.
RSpec.describe "The scanner's guide geometry", type: :system do
  before do
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  def geometry(script)
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      #{ScannerHelpers::MODULES_JS}
      window.__modules.then(({ geometry }) => done((#{script})(geometry)))
    JS
  end

  def rounded(rect) = rect.transform_values { it.round(1) }

  it "gives the live guide decision 2's boxes at the three stages (AC-3.1)", :aggregate_failures do
    boxes = geometry("(g) => [ [390, 692], [360, 488], [360, 408] ].map(([w, h]) => g.liveGuideRect(w, h))")
    expect(rounded(boxes[0])).to eq("x" => 15.2, "y" => 126.8, "width" => 359.7, "height" => 502.4)
    expect(rounded(boxes[1])).to eq("x" => 42.5, "y" => 84.0, "width" => 274.9, "height" => 384.0)
    expect(rounded(boxes[2])).to eq("x" => 63.0, "y" => 72.6, "width" => 234.0, "height" => 326.8)
  end

  it "draws the shipped framing's card size in the tall stage, for measurement mode (AC-7.2)" do
    box = geometry("(g) => g.liveGuideRect(390, 692, 'shipped')")
    expect(rounded(box)).to eq("x" => 46.1, "y" => 170.0, "width" => 297.8, "height" => 416.0)
  end

  it "keeps the shipped framing for a picked photo (AC-3.3)", :aggregate_failures do
    box = geometry("(g) => ({ guide: g.guideRect(900, 1200), photo: g.guideInFrame(1200, 1600, g.STAGE_ASPECT, 1), aspect: g.STAGE_ASPECT, shares: g.GUIDE })")
    expect(rounded(box["guide"])).to eq("x" => 106.4, "y" => 120.0, "width" => 687.3, "height" => 960.0)
    expect(rounded(box["photo"])).to eq("x" => 141.8, "y" => 160.0, "width" => 916.4, "height" => 1280.0)
    expect(box["aspect"]).to eq(0.75)
    expect(box["shares"]).to eq("height" => 0.8, "maxWidth" => 0.9)
  end

  it "maps a live guide into a 3:4 frame covering a taller stage, inside the frame (AC-3.2)", :aggregate_failures do
    box = geometry("(g) => g.guideInFrame(900, 1200, 390, 692, g.liveGuideRect(390, 692))")
    expect(box["x"]).to be >= 0
    expect(box["x"] + box["width"]).to be <= 900
    expect(box["y"]).to be >= 0
    expect(box["y"] + box["height"]).to be <= 1200
  end
end
