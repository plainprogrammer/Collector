require "rails_helper"

# Spec 011 AC-8.2: the shipped build and the shipped page fingerprint the same Scryfall small images to 0 bits, on the 134
# artworks spec 010 checked. Opt-in, so the gating suite never needs Scryfall images. Run on the desktop before the sitting:
#   COLLECTOR_ART_AGREEMENT=~/card-scanner-corpus/art-cache bin/rspec spec/system/art_agreement_spec.rb
# Medians are conventional (the mean of the middle two for an even count).
RSpec.describe "Art fingerprint agreement on Scryfall images", type: :system do
  let(:cache) { Pathname(File.expand_path(ENV.fetch("COLLECTOR_ART_AGREEMENT", ""))) }

  before do
    skip "Set COLLECTOR_ART_AGREEMENT to the spike's art-cache directory" if ENV["COLLECTOR_ART_AGREEMENT"].blank?
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  it "agrees to 0 bits on every image and records the result (AC-8.2)", :aggregate_failures do
    ids = JSON.parse(cache.join("agreement_small.json").read).fetch("results").map { it.fetch("id") }
    distances = ids.map do |id|
      path = cache.join("artwork/small/#{id}.jpg")
      server = MTG::Art::Fingerprint.of(MTG::Art::Decoder.decode(path))
      page_hex = browser_fingerprints_of_jpeg(path.binread).first
      MTG::Art::Fingerprint.hamming(server, [ page_hex ].pack("H*"))
    end
    result = { "format_version" => 1, "spec" => "011", "n" => ids.size, "median" => median(distances), "max" => distances.max,
               "decoder" => MTG::Art::Decoder.command, "settings_digest" => MTG::Art::Settings.digest }
    Rails.root.join("spec/fixtures/card_scanner/phase3_shipped_agreement.json").write(JSON.pretty_generate(result) + "\n")
    expect(ids.size).to eq(134)
    expect(distances.max).to eq(0)
  end

  def median(values)
    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
  end

  def browser_fingerprints_of_jpeg(jpeg)
    run_art_js(<<~JS, Base64.strict_encode64(jpeg), MTG::Art::Settings.fingerprint)
      const [ data, settings ] = args
      const image = new Image()
      image.onload = () => {
        const canvas = Object.assign(document.createElement("canvas"), { width: image.naturalWidth, height: image.naturalHeight })
        canvas.getContext("2d").drawImage(image, 0, 0)
        done([ art.hex(art.fingerprint(canvas, settings, { dx: 0, dy: 0 })) ])
      }
      image.src = `data:image/jpeg;base64,${data}`
    JS
  end
end
