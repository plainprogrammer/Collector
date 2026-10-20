require "rails_helper"

RSpec.describe "Art index on the scanner page", :art_matching, type: :system do
  let(:near) { "aaaaaaaa-0000-4000-8000-000000000001" }
  let(:far) { "bbbbbbbb-0000-4000-8000-000000000002" }

  before do
    system_sign_in_as(create(:user))
    visit scanner_path
  end

  def index_bytes = Base64.strict_encode64(Zlib.gunzip(MTG::Art::Index.write!("v1", [ [ near, "\x00".b * 128 ], [ far, "\xFF".b * 128 ] ]).binread))

  it "reads the file the build writes and finds the nearest artworks (ADR 0007)" do
    found = run_art_js(<<~JS, index_bytes, MTG::Art::Settings.digest)
      const [ data, digest ] = args
      const index = art.parseIndex(Uint8Array.from(atob(data), (c) => c.charCodeAt(0)), digest)
      const query = new Uint8Array(128); query[0] = 0x80
      done(art.search(index, [ query ], 2))
    JS

    expect(found).to eq([ { "id" => near, "distance" => 1 }, { "id" => far, "distance" => 1023 } ])
  end

  it "refuses an index built with other settings (AC-5.2)" do
    error = run_art_js(<<~JS, index_bytes)
      try { art.parseIndex(Uint8Array.from(atob(args[0]), (c) => c.charCodeAt(0)), "0123456789abcdef"); done(null) } catch (e) { done(e.message) }
    JS

    expect(error).to eq("The art index doesn't match this page.")
  end
end
