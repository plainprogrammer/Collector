# Testing Strategy

## Overview

This document defines the testing approach for Collector using RSpec. The strategy emphasizes confidence in critical paths while maintaining development velocity. Tests should enable refactoring, not impede it.

**Framework**: RSpec with FactoryBot
**System Tests**: Capybara with headless Chrome
**Coverage Target**: >80% on models and critical paths

---

## Test Pyramid

```
                    ┌─────────────┐
                    │   System    │  Few, high-value user journeys
                    │   Tests     │  
                   ─┴─────────────┴─
                  ┌─────────────────┐
                  │   Request/      │  Controller integration,
                  │   Integration   │  Turbo responses
                 ─┴─────────────────┴─
                ┌─────────────────────┐
                │   Component Tests   │  ViewComponent rendering
               ─┴─────────────────────┴─
              ┌─────────────────────────┐
              │      Model/Unit         │  Business logic, validations
             ─┴─────────────────────────┴─
```

### Layer Guidelines

| Layer | Quantity | Speed | Purpose |
|-------|----------|-------|---------|
| Model/Unit | Many | Fast | Validate business rules, scopes, associations |
| Component | Many | Fast | Verify rendering with various inputs |
| Request | Moderate | Medium | Test controller behavior, authorization, Turbo responses |
| System | Few | Slow | Verify critical user journeys end-to-end |

---

## Directory Structure

```
spec/
├── factories/
│   ├── catalogs.rb
│   ├── mtg_sets.rb
│   ├── mtg_cards.rb
│   ├── collections.rb
│   ├── items.rb
│   ├── mtg_card_item_details.rb
│   ├── storage_units.rb
│   └── ...
├── models/
│   ├── catalog_spec.rb
│   ├── mtg_set_spec.rb
│   ├── mtg_card_spec.rb
│   ├── collection_spec.rb
│   ├── item_spec.rb
│   └── ...
├── components/
│   ├── ui/
│   │   ├── button_component_spec.rb
│   │   └── ...
│   ├── catalog/
│   │   ├── card_thumbnail_component_spec.rb
│   │   ├── card_detail_component_spec.rb
│   │   ├── set_card_component_spec.rb
│   │   └── ...
│   ├── collection/
│   │   └── ...
│   └── storage/
│       └── ...
├── requests/
│   ├── cards_spec.rb
│   ├── sets_spec.rb
│   ├── items_spec.rb
│   └── ...
├── system/
│   ├── card_browsing_spec.rb
│   ├── item_management_spec.rb
│   └── ...
└── support/
    ├── factory_bot.rb
    ├── capybara.rb
    ├── component_helpers.rb
    └── ...
```

---

## RSpec Configuration

### Base Configuration

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods
  
  # Include ViewComponent test helpers
  config.include ViewComponent::TestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
end
```

### Capybara Configuration

```ruby
# spec/support/capybara.rb
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :selenium_chrome_headless

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,900')
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
```

---

## FactoryBot Patterns

### Factory Organization

One factory file per model, with related traits grouped logically.

```ruby
# spec/factories/catalogs.rb
FactoryBot.define do
  factory :catalog do
    sequence(:name) { |n| "Catalog #{n}" }
    source_type { "mtgjson" }
    source_config { {} }
    
    trait :mtgjson do
      source_type { "mtgjson" }
      source_config { { version: "5.2.2" } }
    end
    
    trait :api do
      source_type { "api" }
      source_config { { endpoint: "https://api.example.com" } }
    end
    
    trait :custom do
      source_type { "custom" }
      source_config { {} }
    end
  end
end
```

```ruby
# spec/factories/mtg_sets.rb
FactoryBot.define do
  factory :mtg_set do
    sequence(:code) { |n| "TS#{n}" }
    sequence(:name) { |n| "Test Set #{n}" }
    release_date { Date.new(2024, 1, 1) }
    set_type { "expansion" }
    card_count { 300 }
    
    trait :core do
      set_type { "core" }
    end
    
    trait :masters do
      set_type { "masters" }
    end
  end
end
```

```ruby
# spec/factories/mtg_cards.rb
FactoryBot.define do
  factory :mtg_card do
    sequence(:uuid) { |n| SecureRandom.uuid }
    sequence(:scryfall_id) { |n| SecureRandom.uuid }
    sequence(:name) { |n| "Test Card #{n}" }
    set_code { "TST" }
    sequence(:collector_number) { |n| n.to_s }
    rarity { "common" }
    type_line { "Creature — Human" }
    mana_cost { "{1}{W}" }
    colors { ["W"] }
    finishes { ["nonfoil"] }
    
    association :mtg_set
    
    trait :rare do
      rarity { "rare" }
    end
    
    trait :mythic do
      rarity { "mythic" }
    end
    
    trait :foil_available do
      finishes { ["nonfoil", "foil"] }
    end
    
    trait :foil_only do
      finishes { ["foil"] }
    end
    
    trait :creature do
      type_line { "Creature — Human Soldier" }
      power { "2" }
      toughness { "2" }
    end
    
    trait :instant do
      type_line { "Instant" }
      power { nil }
      toughness { nil }
    end
    
    trait :land do
      type_line { "Basic Land — Plains" }
      mana_cost { nil }
      colors { [] }
    end
  end
end
```

```ruby
# spec/factories/collections.rb
FactoryBot.define do
  factory :collection do
    sequence(:name) { |n| "Collection #{n}" }
    description { "A test collection" }
    item_type { "mtg_card" }
    
    association :catalog
    
    trait :with_mtgjson_catalog do
      association :catalog, :mtgjson
    end
  end
end
```

```ruby
# spec/factories/items.rb
FactoryBot.define do
  factory :item do
    association :collection
    catalog_entry { association :mtg_card }
    
    quantity { 1 }
    
    # Optional storage unit - not created by default
    storage_unit { nil }
    
    trait :with_storage do
      storage_unit { association :storage_unit, collections: [instance.collection] }
    end
    
    trait :with_detail do
      after(:create) do |item|
        create(:mtg_card_item_detail, item: item)
      end
    end
    
    trait :bulk do
      quantity { 100 }
    end
  end
end
```

```ruby
# spec/factories/mtg_card_item_details.rb
FactoryBot.define do
  factory :mtg_card_item_detail do
    association :item
    
    condition { "NM" }
    finish { "nonfoil" }
    language { "EN" }
    signed { false }
    altered { false }
    graded { false }
    grading_service { nil }
    grade { nil }
    
    trait :near_mint do
      condition { "NM" }
    end
    
    trait :lightly_played do
      condition { "LP" }
    end
    
    trait :heavily_played do
      condition { "HP" }
    end
    
    trait :foil do
      finish { "foil" }
    end
    
    trait :etched do
      finish { "etched" }
    end
    
    trait :signed do
      signed { true }
    end
    
    trait :altered do
      altered { true }
    end
    
    trait :graded do
      graded { true }
      grading_service { "PSA" }
      grade { "9" }
    end
    
    trait :japanese do
      language { "JP" }
    end
  end
end
```

```ruby
# spec/factories/storage_units.rb
FactoryBot.define do
  factory :storage_unit do
    sequence(:name) { |n| "Storage Unit #{n}" }
    unit_type { "box" }
    notes { nil }
    parent { nil }
    
    # Storage units need collection associations
    transient do
      collections { [] }
    end
    
    after(:create) do |unit, evaluator|
      evaluator.collections.each do |collection|
        create(:collection_storage_unit, storage_unit: unit, collection: collection)
      end
    end
    
    trait :shelf do
      unit_type { "shelf" }
    end
    
    trait :binder do
      unit_type { "binder" }
    end
    
    trait :deck do
      unit_type { "deck" }
    end
    
    trait :with_parent do
      association :parent, factory: :storage_unit
    end
  end
end
```

### Trait Conventions

| Trait Type | Naming Pattern | Example |
|------------|----------------|---------|
| Rarity | Rarity name | `:rare`, `:mythic`, `:common` |
| Card type | Type name | `:creature`, `:instant`, `:land` |
| Variant | Feature name | `:foil_available`, `:showcase` |
| Condition | Condition name | `:near_mint`, `:lightly_played` |
| State | State description | `:graded`, `:signed`, `:altered` |
| Invalid | `invalid_*` | `:invalid_condition` |

### Association Handling

Use `association` for required relationships, explicit `create` for optional:

```ruby
# When building items with specific storage
let(:collection) { create(:collection) }
let(:storage) { create(:storage_unit, collections: [collection]) }
let(:item) { create(:item, collection: collection, storage_unit: storage) }
```

### Sequences

Use sequences for attributes that must be unique:

```ruby
sequence(:uuid) { |n| SecureRandom.uuid }
sequence(:name) { |n| "Card #{n}" }
sequence(:collector_number) { |n| n.to_s.rjust(3, '0') }
sequence(:code) { |n| "TS#{n}" }
```

---

## Model Specs

### What to Test

- Validations (presence, format, inclusion, custom)
- Associations (existence, dependent behavior)
- Scopes (correct filtering, ordering)
- Instance methods (business logic)
- Class methods (queries, aggregations)
- Callbacks (side effects)
- Interface compliance (for polymorphic types)

### Structure

```ruby
# spec/models/item_spec.rb
RSpec.describe Item, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:collection) }
    it { is_expected.to belong_to(:storage_unit).optional }
    it { is_expected.to belong_to(:catalog_entry) }
    it { is_expected.to have_one(:detail).dependent(:destroy) }
  end
  
  describe "validations" do
    it { is_expected.to validate_presence_of(:collection) }
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than(0) }
    
    describe "storage_unit collection constraint" do
      let(:collection) { create(:collection) }
      let(:other_collection) { create(:collection) }
      let(:storage_unit) { create(:storage_unit, collections: [other_collection]) }
      
      it "rejects storage units from other collections" do
        item = build(:item, collection: collection, storage_unit: storage_unit)
        expect(item).not_to be_valid
        expect(item.errors[:storage_unit]).to include(/must belong to/)
      end
    end
  end
  
  describe "scopes" do
    describe ".in_storage" do
      it "returns items with storage units assigned" do
        collection = create(:collection)
        storage = create(:storage_unit, collections: [collection])
        with_storage = create(:item, collection: collection, storage_unit: storage)
        without_storage = create(:item, collection: collection, storage_unit: nil)
        
        expect(Item.in_storage).to include(with_storage)
        expect(Item.in_storage).not_to include(without_storage)
      end
    end
  end
  
  describe "#display_name" do
    it "delegates to catalog entry" do
      card = create(:mtg_card, name: "Lightning Bolt")
      item = create(:item, catalog_entry: card)
      
      expect(item.display_name).to eq("Lightning Bolt")
    end
  end
end
```

### Catalog Entry Interface Spec

```ruby
# spec/models/mtg_card_spec.rb
RSpec.describe MTGCard, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:mtg_set) }
    it { is_expected.to have_many(:items) }
  end
  
  describe "CatalogEntryInterface compliance" do
    let(:card) { create(:mtg_card, uuid: "abc-123", name: "Lightning Bolt") }
    
    it "responds to #identifier" do
      expect(card.identifier).to eq("abc-123")
    end
    
    it "responds to #display_name" do
      expect(card.display_name).to eq("Lightning Bolt")
    end
    
    it "responds to #image_url" do
      expect(card).to respond_to(:image_url)
    end
  end
  
  describe "#image_url" do
    let(:card) { create(:mtg_card, scryfall_id: "ab12cd34-5678-90ef-ghij-klmnopqrstuv") }
    
    it "constructs Scryfall CDN URL" do
      url = card.image_url(:normal)
      expect(url).to include("cards.scryfall.io")
      expect(url).to include("normal")
      expect(url).to include(card.scryfall_id)
    end
    
    it "supports different sizes" do
      expect(card.image_url(:small)).to include("small")
      expect(card.image_url(:large)).to include("large")
    end
  end
end
```

---

## Component Specs

### What to Test

- Renders correctly with required parameters
- Handles optional parameters / defaults
- Slot content renders properly
- Conditional rendering based on parameters
- Accessibility attributes present
- CSS classes applied correctly for variants

### Structure

```ruby
# spec/components/ui/button_component_spec.rb
RSpec.describe UI::ButtonComponent, type: :component do
  it "renders with required label" do
    render_inline(described_class.new(label: "Click me"))
    
    expect(page).to have_button("Click me")
  end
  
  describe "variants" do
    it "applies primary styles by default" do
      render_inline(described_class.new(label: "Primary"))
      
      expect(page).to have_css("button.bg-blue-600")
    end
    
    it "applies danger styles for danger variant" do
      render_inline(described_class.new(label: "Delete", variant: :danger))
      
      expect(page).to have_css("button.bg-red-600")
    end
  end
  
  describe "as link" do
    it "renders anchor tag when href provided" do
      render_inline(described_class.new(label: "Go", href: "/somewhere"))
      
      expect(page).to have_link("Go", href: "/somewhere")
      expect(page).not_to have_button
    end
  end
  
  describe "disabled state" do
    it "adds disabled attribute and styling" do
      render_inline(described_class.new(label: "Disabled", disabled: true))
      
      expect(page).to have_button("Disabled", disabled: true)
      expect(page).to have_css("button.opacity-50")
    end
  end
end
```

### Domain Component Example

```ruby
# spec/components/catalog/card_thumbnail_component_spec.rb
RSpec.describe Catalog::CardThumbnailComponent, type: :component do
  let(:set) { create(:mtg_set, code: "LEB") }
  let(:card) { create(:mtg_card, name: "Lightning Bolt", set_code: "LEB", mtg_set: set) }
  
  it "renders card image" do
    render_inline(described_class.new(card: card))
    
    expect(page).to have_css("img[alt='Lightning Bolt']")
  end
  
  it "links to card detail by default" do
    render_inline(described_class.new(card: card))
    
    expect(page).to have_link(href: "/cards/#{card.id}")
  end
  
  it "can disable linking" do
    render_inline(described_class.new(card: card, linkable: false))
    
    expect(page).not_to have_link
  end
  
  describe "set badge" do
    it "shows set code when enabled" do
      render_inline(described_class.new(card: card, show_set: true))
      
      expect(page).to have_text("LEB")
    end
    
    it "hides set code by default" do
      render_inline(described_class.new(card: card))
      
      expect(page).not_to have_text("LEB")
    end
  end
end
```

---

## Request Specs

### What to Test

- HTTP response status
- Correct template/redirect
- Flash messages
- Turbo Frame responses
- Authorization (when added)
- Parameter handling

### Structure

```ruby
# spec/requests/items_spec.rb
RSpec.describe "Items", type: :request do
  let(:catalog) { create(:catalog, :mtgjson) }
  let(:collection) { create(:collection, catalog: catalog) }
  let(:card) { create(:mtg_card) }
  
  describe "GET /items" do
    it "returns success" do
      get items_path
      
      expect(response).to have_http_status(:ok)
    end
    
    it "renders item list" do
      item = create(:item, collection: collection, catalog_entry: card)
      
      get items_path
      
      expect(response.body).to include(card.name)
    end
  end
  
  describe "POST /items" do
    let(:valid_params) do
      {
        item: {
          catalog_entry_type: "MTGCard",
          catalog_entry_id: card.id,
          collection_id: collection.id
        }
      }
    end
    
    it "creates item and redirects" do
      expect {
        post items_path, params: valid_params
      }.to change(Item, :count).by(1)
      
      expect(response).to redirect_to(Item.last)
    end
    
    context "with invalid params" do
      it "returns unprocessable entity" do
        post items_path, params: { item: { collection_id: nil } }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
  
  describe "Turbo Frame responses" do
    it "responds to frame requests" do
      get items_path, headers: { "Turbo-Frame" => "collection_items_list" }
      
      expect(response.body).to include('id="collection_items_list"')
    end
  end
end
```

---

## System Specs

### What to Test

System tests verify complete user journeys. Focus on:

- Critical happy paths
- Complex multi-step workflows
- JavaScript-dependent interactions
- Turbo Frame navigation

### Guidelines

- **Few but valuable**: Each system test should cover a meaningful user journey
- **Stable selectors**: Use `data-testid` attributes for test-specific targeting
- **Avoid over-specification**: Test outcomes, not implementation details
- **Keep them fast**: Minimize database setup, use `js: true` only when needed

### Structure

```ruby
# spec/system/item_management_spec.rb
RSpec.describe "Item Management", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end
  
  let!(:catalog) { create(:catalog, :mtgjson) }
  let!(:collection) { create(:collection, name: "My Cards", catalog: catalog) }
  let!(:mtg_set) { create(:mtg_set, code: "LEB", name: "Limited Edition Beta") }
  let!(:card) { create(:mtg_card, name: "Lightning Bolt", set_code: "LEB", mtg_set: mtg_set, finishes: ["nonfoil", "foil"]) }
  
  describe "adding a card to collection" do
    it "completes quick add workflow", js: true do
      visit card_path(card)
      
      expect(page).to have_content("Lightning Bolt")
      
      click_button "Add to Collection"
      
      within "[data-testid='quick-add-modal']" do
        select "Foil", from: "Finish"
        click_button "Add"
      end
      
      expect(page).to have_content("Item added to collection")
    end
  end
  
  describe "browsing collection" do
    it "filters by condition" do
      nm_item = create(:item, :with_detail, collection: collection, catalog_entry: card)
      nm_item.detail.update!(condition: "NM")
      
      other_card = create(:mtg_card, mtg_set: mtg_set)
      lp_item = create(:item, :with_detail, collection: collection, catalog_entry: other_card)
      lp_item.detail.update!(condition: "LP")
      
      visit items_path
      
      select "Near Mint", from: "Condition"
      click_button "Filter"
      
      expect(page).to have_css("[data-testid='item-row']", count: 1)
    end
  end
  
  describe "managing storage units" do
    it "creates nested storage hierarchy", js: true do
      # Associate storage with collection
      visit storage_units_path
      
      click_link "New Storage Unit"
      fill_in "Name", with: "Main Shelf"
      select "Shelf", from: "Type"
      check collection.name  # Associate with collection
      click_button "Create"
      
      expect(page).to have_content("Main Shelf")
      
      within "[data-testid='unit-Main Shelf']" do
        click_link "Add Child"
      end
      
      fill_in "Name", with: "Binder A"
      select "Binder", from: "Type"
      click_button "Create"
      
      expect(page).to have_content("Binder A")
      # Verify hierarchy
      expect(page).to have_css("[data-testid='unit-Main Shelf'] [data-testid='unit-Binder A']")
    end
  end
end
```

### Test Data Attributes

Add `data-testid` attributes for stable test selectors:

```erb
<div data-testid="item-row" data-item-id="<%= item.id %>">
  ...
</div>

<div data-testid="quick-add-modal">
  ...
</div>
```

---

## Test Data Management

### MTGJSON Test Fixtures

For tests requiring realistic card data, create a minimal fixture set:

```ruby
# spec/support/mtgjson_fixtures.rb
module MTGJSONFixtures
  def self.seed_test_data
    # Create a test catalog
    catalog = Catalog.find_or_create_by!(name: "Test Catalog") do |c|
      c.source_type = "mtgjson"
      c.source_config = { version: "test" }
    end
    
    # Create a small set with known cards for testing
    set = MTGSet.find_or_create_by!(code: "TST") do |s|
      s.name = "Test Set"
      s.release_date = Date.new(2024, 1, 1)
      s.set_type = "expansion"
      s.card_count = 10
    end
    
    # Known cards for specific test scenarios
    create_test_card(set, "Lightning Bolt", "R", "instant", ["nonfoil", "foil"])
    create_test_card(set, "Grizzly Bears", "G", "creature", ["nonfoil"])
    create_test_card(set, "Island", "U", "land", ["nonfoil", "foil"])
    # ... etc
  end
  
  def self.create_test_card(set, name, color, type, finishes)
    MTGCard.find_or_create_by!(name: name, mtg_set: set) do |c|
      c.uuid = SecureRandom.uuid
      c.scryfall_id = SecureRandom.uuid
      c.set_code = set.code
      c.collector_number = (MTGCard.where(mtg_set: set).count + 1).to_s
      c.rarity = "common"
      c.type_line = type.capitalize
      c.colors = [color]
      c.finishes = finishes
    end
  end
end
```

### Database Cleaner Strategy

Use transactional fixtures for most tests, truncation for system tests:

```ruby
# spec/support/database_cleaner.rb
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end
  
  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation
  end
  
  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

---

## Running Tests

```bash
# Full suite
bundle exec rspec

# Specific layer
bundle exec rspec spec/models
bundle exec rspec spec/components
bundle exec rspec spec/requests
bundle exec rspec spec/system

# Single file
bundle exec rspec spec/models/item_spec.rb

# Single example
bundle exec rspec spec/models/item_spec.rb:42

# With documentation format
bundle exec rspec --format documentation
```

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-01-XX | — | Initial draft |
| 2025-01-XX | — | Added catalog, mtg_set, mtg_card_item_detail factories; aligned with reconciled data model |
