require "rails_helper"

# Spec 026: number entry is core code. Its models, controllers, helper, views and script never name a collectible
# type, a source, or a finish; finishes and their labels come from the type's vocabulary.
RSpec.describe "Number entry's code" do
  let(:files) do
    Rails.root.glob("{app/models/number_entry{,/*}.rb,app/controllers/collections/number_entries{_controller.rb,/**/*.rb}," \
      "app/controllers/concerns/number_entry_page.rb,app/helpers/number_entries_helper.rb,app/views/collections/number_entries/*.erb," \
      "app/javascript/controllers/number_entry_controller.js}")
  end

  it "covers every file of the feature" do
    expect(files.size).to eq(18)
  end

  it "never names a collectible type, a source or a finish" do
    offenders = files.select { |file| file.read.match?(/\b(mtg|scryfall|magic|foil|nonfoil|etched)\b/i) }
    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
