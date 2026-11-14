require "rails_helper"

# Spec 087 AC-2.6, modelled on spec/footer_core_spec.rb: the files of the third-party licences page, its reader and its manifest name no
# collectible, source or rights holder. What the page lists is whatever the bundle and the manifest hold. Spec 091 AC-5.1 adds the licence
# policy, its check, the rake task and the policy file: what a licence check judges is a name and a set of SPDX ids, never a collectible.
RSpec.describe "The third-party licences page's files" do
  let(:files) do
    %w[lib/collector/third_party_licences.rb lib/collector/third_party_licences/audit.rb config/third_party_licences.yml
       lib/collector/third_party_licences/policy.rb lib/collector/third_party_licences/check.rb lib/tasks/licences.rake
       config/licence_policy.yml
       app/controllers/licences_controller.rb app/views/licences/show.html.erb app/views/licences/_component.html.erb]
      .map { |path| Rails.root.join(path) } + Rails.root.glob("config/third_party_licences/*.txt")
  end

  it "covers the reader, the guard's rules, the controller, the views, the manifest and its texts", :aggregate_failures do
    expect(files.size).to be > 10
    expect(files).to all(exist)
  end

  it "never says MTG, Magic, Wizards, Scryfall or Fan Content" do
    offenders = files.select { |file| file.read.match?(/mtg|magic|wizards|scryfall|fan content/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
