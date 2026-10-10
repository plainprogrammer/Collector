require "rails_helper"

# Spec 015 AC-5.4: the core's admin catalog code names no collectible type, source or operation. A type reaches the
# page only through its source's optional hooks (app/models/catalog/sources.rb).
RSpec.describe "The core's admin catalog code" do
  let(:files) do
    Rails.root.glob("app/controllers/admin/catalogs{_controller.rb,/**/*.rb}") + Rails.root.glob("app/views/admin/catalogs/**/*.erb") +
      Rails.root.glob("app/models/catalog/{operation,operation/*,refresh_operation,health,refresh/progress}.rb") +
      [ Rails.root.join("app/views/catalog/_not_loaded.html.erb"), Rails.root.join("app/helpers/admin_helper.rb"),
        Rails.root.join("app/javascript/controllers/poll_controller.js") ]
  end

  it "covers the controllers, views, models, helper and script of the page" do
    expect(files.size).to eq(14)
  end

  it "never says MTG, Scryfall or art" do
    offenders = files.select { |file| file.read.match?(/\b(mtg|scryfall|art)\b/i) }

    expect(offenders.map { |file| file.relative_path_from(Rails.root).to_s }).to be_empty
  end
end
