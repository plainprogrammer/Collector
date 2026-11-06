require "rails_helper"

# Spec 043 AC-4.1, FR-7 (ADR 0018): the retry rule is core code. It asks the job whether its attempt made progress and
# names no collectible type, source, host, MTG constant or catalog table; each operation answers for itself.
RSpec.describe "The core's rate-limit retry rule" do
  let(:file) { Rails.root.join("app/jobs/catalog/rate_limit_retry.rb") }

  it "is the file the rule lives in" do
    expect(file).to exist
  end

  it "names no collectible, source, host, MTG constant or catalog table", :aggregate_failures do
    source = file.read

    expect(source).not_to match(/mtg|magic|wizards|scryfall/i)
    expect(source).not_to match(/\.io\b|https?:\/\//) # no host or address
    expect(source).not_to match(/MTG::|Art::|ArtBuild|BuildJob|RefreshJob|Catalog::Refresh\b/)
    expect(source).not_to match(/Catalog::(Entry|Identity|Set|RefreshRun)\b/) # no catalog model
    expect(source).not_to match(/catalog_(entries|identities|sets|refresh_runs)|mtg_/) # no catalog table
  end
end
