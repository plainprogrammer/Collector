require "rails_helper"

RSpec.describe "Design system assets", type: :request do
  before { sign_in_as(create(:user)) }

  it "links tokens before components before additions", :aggregate_failures do
    get catalog_entries_path

    body = response.body
    tokens = body.index("collector/tokens")
    expect(tokens).to be < body.index("collector/components")
    expect(body.index("collector/components")).to be < body.index("collector/additions")
    expect(body).to include('class="c-shell"', "viewport-fit=cover")
  end

  it "serves every font file" do
    %w[fraunces-latin-600-normal ibm-plex-sans-latin-400-normal ibm-plex-sans-latin-600-normal ibm-plex-mono-latin-400-normal]
      .each do |font|
        get ActionController::Base.helpers.asset_path("collector/#{font}.woff2")
        expect(response).to have_http_status(:ok)
      end
  end
end
