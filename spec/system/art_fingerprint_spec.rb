require "rails_helper"

RSpec.describe "Art fingerprint on the scanner page", type: :system do
  before do
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  it "makes the same six fingerprints as the build on a lossless picture (spec 011 AC-8.3)" do
    png = noisy_png
    path = Rails.root.join("tmp/art-agreement-spec.png")
    path.binwrite(png)
    image = MTG::Art::Decoder.decode(path)
    expected = MTG::Art::Settings.fingerprint.fetch("offsets").map { MTG::Art::Fingerprint.of(image, it).unpack1("H*") }

    expect(browser_fingerprints(png)).to eq(expected)
  ensure
    path&.delete if path&.exist?
  end

  it "crops the guide rect at the frame's own pixels, rounded outward and kept inside the frame (spec 011 AC-5.3)" do
    sizes = run_art_js(<<~JS)
      const frame = Object.assign(document.createElement("canvas"), { width: 100, height: 80 })
      done([ { x: 10.4, y: 5.6, width: 30.2, height: 60.9 }, { x: -3, y: 70.5, width: 50, height: 30 } ]
        .map((guide) => { const crop = art.cropGuide(frame, guide); return [ crop.width, crop.height ] }))
    JS

    expect(sizes).to eq([ [ 31, 62 ], [ 47, 10 ] ])
  end
end
