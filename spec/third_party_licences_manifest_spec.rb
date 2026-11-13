require "rails_helper"

# Spec 087 decision 3 and AC-5.8: the guard on the repository's real files, in the suite and so in `bin/ci`. Each rule's
# failing fixture is in spec/lib/collector/third_party_licences/audit_spec.rb; this is the rules passing on the real manifest,
# the pinned OCR packages, the importmap, the fonts, the icons and the bundle.
RSpec.describe "The third-party licences manifest", type: :model do
  # The suite loads every Bundler group while the image holds all but `development`, so this checks a superset of the
  # image's gems, which is conservative; what the image really holds is proved by bin/image-smoke (spec 087 decision 3).
  it "agrees with what the repository ships, and names whatever doesn't (AC-5.1 to AC-5.6)" do
    problems = Collector::ThirdPartyLicences::Audit.for_repository.problems

    expect(problems).to be_empty, "the third-party licences manifest is out of step:\n  - #{problems.join("\n  - ")}"
  end
end
