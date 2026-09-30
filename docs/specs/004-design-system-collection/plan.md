# Implementation Plan: Design System, Accounts, Adding Cards and the Collection Grid

**Spec:** docs/specs/004-design-system-collection/spec.md (v2.1.0, Approved)
**Decisions:** none (no ADRs; the plan decisions below are traced to the spec)
**Supporting docs:** [data-model.md](data-model.md)
**Created:** 2026-09-29

## Context

Collector can search the Scryfall-backed catalog (feature 002), but search is unstyled and public, and a collector can't record what they own. Spec 004 does four things:
- Installs the exported design system and puts every page in its app shell.
- Adds accounts: the first visitor becomes admin, sign-up is closed by default and the admin can open it, and admins manage users in the app.
- Restyles search to show what you own, and adds cards with a quick add or a detailed form.
- Adds the `ItemPage`-style card page (your copies, printings, legality) and the collection image grid.

Two Fable spec reviews passed it, and an Opus plan review revised this plan. After this come bulk/table views and export.

**Plan decisions (not spelled out in the spec, each traced to it):**
- **Authentication:** hand-written in the Rails 8 authentication-generator pattern: `Session` model, `Authentication` concern, `Current`, and `has_secure_password` with the `bcrypt` gem. It's written by hand rather than generated so that no password-reset mailer or views are created (FR-2 must not send email). `bcrypt` is the one new gem, needed by `has_secure_password` (FR-2 "salted hash").
- **Sessions:** a `sessions` table, so that "sign out ends only the current session" (FR-2) and "a password change ends that user's sessions" (AC-5.3) can be implemented.
- **Lot identity (FR-6, AC-12.5):**
  - The `lots` table has a `lot_key` string column built from finish, condition and price, with a unique index on `[account_id, catalog_entry_id, lot_key]`.
  - A plain unique index can't be used because SQLite treats NULLs as distinct.
  - An expression index isn't used because the schema dump doesn't reliably keep it.
  - Price is stored as integer minor units (`price_paid_cents`), so it's exact.
- **Collectible vocabulary:** a new registry, `Catalog.collecting` (`"mtg" => "MTG::Collecting"`), sits next to `Catalog.sources`. The core `Lot` asks it for valid finishes, special finishes and the condition scale, so the core doesn't interpret finish or condition (FR-6).
- **Updating the page after an add (AC-7.2):**
  - Quick add, add, edit and remove all redirect with 303 back to a local `return_to` path. The layout turns on Turbo 8 page-refresh morphing with scroll preservation.
  - When the redirect lands on the current URL, Turbo morphs the page: no reload, same URL, same scroll position, and the live status region updates.
  - The same 303 serves browsers without scripting (AC-7.3), so there is one code path.
  - The one exception is an over-cap quick add (AC-7.3a). With scripting on, it answers 422 with a Turbo Stream that updates `#status` and leaves the page as it was; without scripting, it renders the card page at 422.
- **Header and tab bar:** these are *not* `data-turbo-permanent`. The header changes per page (the detail variant, the add button, the current section), and server rendering keeps it correct (FR-13 allows this; review note N10).
- **Stylesheet order:**
  - New patterns (FR-11) go in `app/assets/stylesheets/collector/additions.css`, beside the export's two files.
  - The layout links the stylesheets explicitly, in order: tokens, components, additions, application. This replaces `stylesheet_link_tag :app` (AC-1.2).
  - Keeping additions in their own file means `components.css` can be replaced wholesale by a future re-export.
- **Sign-in rate limit:**
  - It uses a store set in `config.x.sign_in_rate_limit_store`: `Rails.cache` in development and production, and a `MemoryStore` in test, because the test cache is `:null_store` (review note N5).
  - The key is `"<client ip>|<normalised email>"`.
  - The client IP comes from `request.remote_ip`, whose trusted proxies are Rails' defaults (private ranges and loopback) plus `COLLECTOR_TRUSTED_PROXIES`.
- **HTTPS:** `COLLECTOR_HTTPS=true` turns on `assume_ssl` and `force_ssl` (excluding `/up`) in production. The session cookie is `secure: request.ssl?`.
- **Currency:** `COLLECTOR_CURRENCY` (default `USD`) is checked at boot against a curated table of ISO 4217 codes and symbols in `Collector::Currency`, documented in the README.
- **Command-line user command:** `bin/rails "collector:user[email]"`. The password comes from `COLLECTOR_PASSWORD`; otherwise it's prompted for on a TTY; otherwise it's generated (24 characters) and printed once.
- **Confirmation pages:** removing a lot and deleting a user each confirm on their own page (`GET …/removal/new`, `GET …/deletion/new`), so confirmation works without scripting (AC-10.5, FR-5) and follows the hotwire rule of a new resource controller rather than a custom action.
- **Where you came from (AC-8.9):** links from the collection add `from=collection`. `CardContext` (a controller concern) reads it and passes it along on card-page links and return paths. Return paths go through Rails' `url_from`, so only paths on this instance are followed.
- **Results frames:** the search and collection results sit in `<turbo-frame id="results" target="_top">`. The filter form and the pagination links target the frame, so they update in place. Every other link inside the frame (tiles, "Show all N printings") navigates the whole page.
- **Routes grow with each phase:** each phase adds its own routes, with a routing example as its first failing test. A route to a controller that doesn't exist yet fails `route_to`.

**Plan review revisions (Opus, 2026-09-29):**
- **Phase order:** lots now come before user administration, so the admin copy counts and user deletion are tested with real lots.
- **Routing:** routing examples are added phase by phase.
- **Boot:** the currency is set in a `to_prepare` block, because initializers run before `lib/` autoloads.
- **Spec expectations fixed:**
  - lowercase Rack cookie attributes
  - the `href`-last attribute order of `link_to`
  - raw apostrophes and quotes in literal ERB text
  - an "Email" attribute name through the locale file
  - the rate-limit store cleared before every request spec
- **Browser specs:** each viewport size and theme gets its own Capybara driver name, so it really takes effect.
- **Forms:** `Lot::Form` validates the collectible's vocabulary itself and parses quantities in base 10.
- **Security and queries:** `admin` is assigned explicitly, never mass-assigned, and the admin copy counts use one grouped query.
- **Names:** `MTG::Collecting.category_name` replaces an override of `Module#name`, and `MTG::ManaCost::Pip` replaces a class that shadowed `::Symbol`.
- **Tests:** coverage gaps from the review are closed with added examples.

## Global Constraints

- Ruby 4.0.7, Rails 8.1.4, SQLite (primary DB), Propshaft + importmap, Hotwire. The only new gem is `bcrypt` (`has_secure_password`).
- UI is built only from design-system tokens and `c-*` classes. There are no colour literals or `font-family` outside `app/assets/stylesheets/collector/` (AC-1.3). Game-publisher symbols are never used.
- Copy is sentence case, speaks to "you", never says "we", uses no emoji or exclamation marks, and states numbers exactly. Messages are verbatim from the spec.
- Every page except sign-in, sign-up and `/up` requires sign-in. On an instance with no users, everything except sign-up and `/up` redirects to sign-up.
- Tenant data (`lots`) carries `account_id` with a foreign key and an index, and every query goes through `Current.account`. Catalog tables stay global.
- Magic numbers:

  | Setting | Value |
  |---|---|
  | Password minimum | 12 characters |
  | Name maximum | 100 characters |
  | Sign-in rate limit | 10 attempts / 3 minutes per email + client address → 429 |
  | Lot quantity | 1–9,999 |
  | Search page size | 12 cards |
  | Printings per group | 10 |
  | Printings page size | 12 printings |
  | Collection page size | 120 tiles |
  | Newest printings on the card page | 10 |
- Scripting only enhances. Every page and action works without JavaScript, menus are `<details>`, and state lives in the URL.
- Migrations are reversible, never edited after release, and never reference app models. Specs tag their `type:`, multi-expectation examples use `:aggregate_failures`, and there's no real HTTP.
- One Conventional Commit per step (`docs/git-convention.md`), with RSpec green at every commit. Branch: `feat/004-design-system-collection`.

---

## Goal

Every page uses the Collector design system. Collectors sign in to private, account-scoped collections, add cards from search or the card page, manage lots, and browse a paginated image grid, and the first-run admin manages users and sign-up.

**Components (Simplicity Gate: 3):**
1. Design system and app shell (stylesheets, layout, navigation).
2. Accounts and access (users, sessions, sign-up setting, admin, command).
3. Collection (the `Lot` model and collecting vocabulary, the search/card/collection pages, and the add/edit/remove flows).

**Anti-Abstraction:** Rails features are used directly (`has_secure_password`, `rate_limit`, `normalizes`, Turbo morphing). The POROs, each with a single job, are `Catalog::CardOverview`, `CollectionGrid`, `MTG::ManaCost` and `Collector::Currency`, and there are no parallel view models. **Integration-First:** Phase 0 locks the existing catalog routes in a routing spec, and each later phase adds its routes behind a failing routing example.

---

## Data model

See [data-model.md](data-model.md): Account, User, Session, InstanceSetting, Lot.

---

## Phase 0: Doc-first commit and routing spec

**Implements:** — | **Satisfies:** — (enables all)
**Files:** `docs/specs/004-design-system-collection/{spec.md,plan.md,data-model.md}`, `spec/routing/routes_spec.rb`
**Interfaces:** Consumes: nothing. Produces: `spec/routing/routes_spec.rb`, which Phases 2, 3, 4, 6, 7 and 9 extend with one `it` per phase for the routes they add.

- [ ] Create the branch `feat/004-design-system-collection` from `main` (`sdd-superpowers:using-git`).
- [ ] Commit: `docs(specs): add spec, plan and data model for 004 design system and collection`
- [ ] Write the routing spec `spec/routing/routes_spec.rb`, which locks the catalog routes 004 builds on (it passes straight away; later phases add failing examples to it):
  ```ruby
  require "rails_helper"

  RSpec.describe "Routes", type: :routing do
    it "routes the catalog pages by external key", :aggregate_failures do
      expect(get: "/catalog/entries").to route_to("catalog/entries#index")
      expect(get: "/catalog/entries/abc").to route_to("catalog/entries#show", external_key: "abc")
      expect(get: "/catalog/identities/abc").to route_to("catalog/identities#show", external_key: "abc")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb` — expect: PASS.
- [ ] Commit: `test(routes): lock the catalog routes 004 builds on`

---

## Phase 1: Install the design system

**Implements:** FR-1, FR-11 (file scaffold) | **Satisfies:** AC-1.1, AC-1.2, AC-1.3
**Files:** `app/assets/stylesheets/collector/{tokens,components,additions}.css`, `app/assets/fonts/collector/*.woff2`, `app/assets/images/collector/*.svg`, `docs/design-system/**`, `.claude/skills/collector-design-system/SKILL.md`, `CLAUDE.md`, `app/assets/stylesheets/application.css`, `app/views/layouts/application.html.erb`, `spec/requests/design_system_spec.rb`, `spec/design_system_files_spec.rb`, `.rubocop.yml`
**Interfaces:** Consumes: nothing. Produces: the `collector/*` stylesheets and images; `additions.css` (grown in Phases 2, 4, 6, 7 and 8); a layout with `body.c-shell`, `#status` live region (`role="status"`, `aria-live="polite"`), `yield :appbar`, and Turbo morph refresh meta tags.

- [ ] Write the failing file spec `spec/design_system_files_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Design system files" do
    let(:root) { Rails.root }

    it "installs the export's stylesheets, fonts, logos, docs and skill", :aggregate_failures do
      %w[tokens components additions].each { |name| expect(root.join("app/assets/stylesheets/collector/#{name}.css")).to exist }
      expect(root.glob("app/assets/fonts/collector/*.woff2").size).to eq(4)
      expect(root.glob("app/assets/images/collector/*.svg").size).to eq(4)
      %w[README.md tokens.json logos.md components/ItemPage.md previews/ItemPage.html].each do |path|
        expect(root.join("docs/design-system", path)).to exist
      end
      expect(root.join(".claude/skills/collector-design-system/SKILL.md")).to exist
      expect(root.join("CLAUDE.md").read).to include("## UI and design system", "collector-design-system")
    end

    it "keeps colour literals and font families inside the design system directory" do
      offenders = root.glob("app/assets/stylesheets/**/*.css").reject { |path| path.to_s.include?("/collector/") }
        .select { |path| path.read.match?(/#\h{3,8}\b|rgba?\(|hsla?\(|font-family/i) }
      expect(offenders).to be_empty
    end

    it "removes feature 002's ad-hoc catalog styles" do
      expect(root.join("app/assets/stylesheets/application.css").read).not_to include(".catalog")
    end
  end
  ```
- [ ] Add to `.rubocop.yml` under `RSpec/DescribeClass: Exclude:` the line `    - "spec/design_system_files_spec.rb"`.
- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect: FAIL.
- [ ] Copy the export (`~/Downloads/collector-design-system.zip`) into the repo:
  ```sh
  DS="$(mktemp -d)/collector-design-system" && unzip -q ~/Downloads/collector-design-system.zip -d "$(dirname "$DS")"
  cp -r "$DS/app/assets/stylesheets/collector" app/assets/stylesheets/
  mkdir -p app/assets/fonts app/assets/images && cp -r "$DS/app/assets/fonts/collector" app/assets/fonts/ && cp -r "$DS/app/assets/images/collector" app/assets/images/
  mkdir -p docs && cp -r "$DS/docs/design-system" docs/
  mkdir -p .claude/skills && cp -r "$DS/.claude/skills/collector-design-system" .claude/skills/
  ```
- [ ] Create `app/assets/stylesheets/collector/additions.css` (later phases append to it):
  ```css
  /* Collector app additions: patterns the export lacks (spec 004 FR-11), built only on tokens.
     Documented in docs/design-system/components/; upstream them into the published design system. */
  ```
- [ ] Replace `app/assets/stylesheets/application.css` with:
  ```css
  /*
   * App-wide styles. Design-system styles live in collector/ and are linked explicitly, in order,
   * by the layout. Don't add colours, spacing or fonts here; use collector/ tokens and c-* classes.
   */
  ```
- [ ] Append the export's `CLAUDE.md.snippet` to the root `CLAUDE.md` as a `## UI and design system` section, adapted to this repo:
  ```markdown
  ## UI and design system

  All UI follows the Collector design system in `docs/design-system/`. Before creating or changing any view, partial, stylesheet or UI copy, use the `collector-design-system` skill (`.claude/skills/collector-design-system/SKILL.md`) and read `docs/design-system/README.md`. Use only the token variables and `c-*` classes from `app/assets/stylesheets/collector/`; never hard-code colours, spacing or fonts. The export's files (`tokens.css`, `components.css`, fonts, logos, `docs/design-system/`) are replaced wholesale by re-exporting the published design system; app-specific patterns live in `collector/additions.css` with a doc per pattern under `docs/design-system/components/`.
  ```
- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect: PASS.
- [ ] Commit: `feat(design): install the Collector design system export`
- [ ] Write the failing request spec `spec/requests/design_system_spec.rb` (search is still public in Phase 1; Phase 2 adds sign-in to this spec):
  ```ruby
  require "rails_helper"

  RSpec.describe "Design system assets", type: :request do
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
  ```
- [ ] Run: `bin/rspec spec/requests/design_system_spec.rb` — expect: FAIL (the layout still links `:app`, and there's no `c-shell`).
- [ ] Replace `app/views/layouts/application.html.erb`:
  ```erb
  <!DOCTYPE html>
  <html lang="en">
    <head>
      <title><%= content_for(:title) || "Collector" %></title>
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <meta name="apple-mobile-web-app-capable" content="yes">
      <meta name="application-name" content="Collector">
      <meta name="mobile-web-app-capable" content="yes">
      <%= csrf_meta_tags %>
      <%= csp_meta_tag %>
      <%= turbo_refreshes_with method: :morph, scroll: :preserve %>
      <%= yield :head %>

      <link rel="icon" href="<%= asset_path("collector/collector-mark.svg") %>" type="image/svg+xml">
      <link rel="apple-touch-icon" href="/icon.png">

      <%= stylesheet_link_tag "collector/tokens", "collector/components", "collector/additions", "application", "data-turbo-track": "reload" %>
      <%= javascript_importmap_tags %>
    </head>

    <body class="c-shell">
      <%= yield :appbar %>
      <div id="status" class="c-status" role="status" aria-live="polite"><% if (message = flash[:notice] || flash[:alert]) %><p class="c-status__message<%= " c-status__message--alert" if flash[:alert] %>"><%= message %></p><% end %></div>
      <%= yield %>
      <%= yield :tabbar %>
    </body>
  </html>
  ```
- [ ] Run: `bin/rspec spec/requests/design_system_spec.rb spec/requests spec/system` — expect: PASS (002's pages still render inside the new layout).
- [ ] Commit: `feat(design): link design-system stylesheets in order and adopt the app shell body`

---

## Phase 2: Users, sessions and sign-in

**Implements:** FR-2, FR-3 (models), FR-11 (auth form pattern) | **Satisfies:** AC-4.4, AC-4.4a (sign-in half), AC-4.5, AC-4.6, AC-4.7, AC-4.8, AC-1.2
**Files:** `Gemfile`, `config/routes.rb`, `spec/routing/routes_spec.rb`, `db/migrate/*_create_accounts_users_sessions.rb`, `app/models/{account,user,session,current}.rb`, `app/controllers/concerns/authentication.rb`, `app/controllers/application_controller.rb`, `app/controllers/sessions_controller.rb`, `app/controllers/collections_controller.rb` (placeholder `show`), `app/views/collections/show.html.erb` (placeholder), `app/views/sessions/new.html.erb`, `app/views/shared/_field_errors.html.erb`, `app/views/layouts/_brand_appbar.html.erb`, `lib/collector/trusted_proxies.rb`, `config/application.rb`, `config/environments/{test,production}.rb`, `spec/factories/accounts.rb`, `spec/support/authentication_helpers.rb`, `spec/models/user_spec.rb`, `spec/lib/collector/trusted_proxies_spec.rb`, `spec/requests/sessions_spec.rb`, `spec/requests/design_system_spec.rb`, `spec/requests/home_spec.rb`, `spec/system/home_spec.rb`, every `spec/requests/catalog/*_spec.rb`, `spec/system/catalog_search_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: layout (Phase 1). Produces:
- routes `session_path`, `new_session_path`, `collection_path`
- `Current.session`, `Current.user`, `Current.account`
- `Authentication` concern: `allow_unauthenticated_access(**)`, `authenticated?`, `start_new_session_for(user)`, `terminate_session`, `after_authentication_url`, `redirect_signed_in_users`
- `User` (`#initial`, `#end_sessions!`, `.admins`, `PASSWORD_MINIMUM`); `Account#lots` is added in Phase 5
- `CollectionsController#show` (a placeholder page until Phase 10)
- factories `:account`, `:user`, `:admin`
- spec helpers `sign_in_as(user)` (request) and `system_sign_in_as(user)` (system), and a `before` hook that clears the sign-in rate-limit store before every request spec

- [ ] Add `gem "bcrypt", "~> 3.1.7"` to the `Gemfile` (uncomment the existing line); `bundle install`.
- [ ] Commit: `chore(deps): add bcrypt for has_secure_password`
- [ ] Write the failing spec `spec/lib/collector/trusted_proxies_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Collector::TrustedProxies do
    it "adds the configured proxies to Rails' private and loopback defaults", :aggregate_failures do
      proxies = described_class.parse(" 203.0.113.0/24, ,198.51.100.4 ")
      expect(proxies).to include(IPAddr.new("203.0.113.0/24"), IPAddr.new("198.51.100.4"))
      expect(proxies).to include(*ActionDispatch::RemoteIp::TRUSTED_PROXIES)
    end

    it "keeps the defaults when nothing is configured" do
      expect(described_class.parse(nil)).to eq(ActionDispatch::RemoteIp::TRUSTED_PROXIES)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/lib/collector/trusted_proxies_spec.rb` — expect: FAIL.
- [ ] Write `lib/collector/trusted_proxies.rb` (plain Ruby, because `config/application.rb` loads it before autoloading starts):
  ```ruby
  require "ipaddr"
  require "action_dispatch"

  module Collector
    # Reverse proxies whose X-Forwarded-For is trusted: Rails' private/loopback defaults plus the
    # comma-separated IPs or CIDRs in COLLECTOR_TRUSTED_PROXIES (spec 004 AC-4.8).
    module TrustedProxies
      def self.parse(value)
        ActionDispatch::RemoteIp::TRUSTED_PROXIES +
          value.to_s.split(",").map(&:strip).reject(&:empty?).map { |proxy| IPAddr.new(proxy) }
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/lib/collector/trusted_proxies_spec.rb` — expect: PASS.
- [ ] Commit: `feat(auth): parse the trusted reverse proxies setting`
- [ ] Write the failing model spec `spec/models/user_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe User, type: :model do
    describe "validations" do
      it "normalises the email and requires a well-formed, unique one", :aggregate_failures do
        create(:user, email_address: "Ann@Example.test")

        expect(build(:user, email_address: "  ANN@example.TEST ").tap(&:validate).errors[:email_address]).to include("is already used")
        expect(build(:user, email_address: "no-at-sign").tap(&:validate).errors[:email_address]).to include("must look like name@example.com")
        expect(build(:user, email_address: "two@@x.test").tap(&:validate).errors[:email_address]).to be_present
        expect(build(:user, email_address: "sp ace@x.test").tap(&:validate).errors[:email_address]).to be_present
      end

      it "requires a name of at most 100 characters and a password of at least 12", :aggregate_failures do
        expect(build(:user, name: "").tap(&:validate).errors[:name]).to be_present
        expect(build(:user, name: "a" * 101).tap(&:validate).errors[:name]).to be_present
        expect(build(:user, password: "short").tap(&:validate).errors[:password]).to include("must be at least 12 characters")
      end
    end

    it "creates its own account" do
      expect { create(:user) }.to change(Account, :count).by(1)
    end

    it "uses the first letter of the name as the avatar initial" do
      expect(build(:user, name: "james").initial).to eq("J")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/user_spec.rb` — expect: FAIL (no `User`).
- [ ] Write the migration `db/migrate/20260929120000_create_accounts_users_sessions.rb`:
  ```ruby
  class CreateAccountsUsersSessions < ActiveRecord::Migration[8.1]
    def change
      create_table :accounts, &:timestamps

      create_table :users do |t|
        t.references :account, null: false, foreign_key: true, index: { unique: true }
        t.string :name, null: false
        t.string :email_address, null: false, index: { unique: true }
        t.string :password_digest, null: false
        t.boolean :admin, null: false, default: false
        t.timestamps
      end

      create_table :sessions do |t|
        t.references :user, null: false, foreign_key: true
        t.string :ip_address
        t.string :user_agent
        t.timestamps
      end
    end
  end
  ```
- [ ] Write the models:
  ```ruby
  # app/models/account.rb
  # The tenant: owns every piece of collection data. One per user (spec 004 FR-3).
  class Account < ApplicationRecord
    has_one :user, dependent: nil
  end
  ```
  ```ruby
  # app/models/user.rb
  class User < ApplicationRecord
    PASSWORD_MINIMUM = 12
    # One "@" with text on both sides and no whitespace (spec 004 AC-4.3).
    EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\z/

    has_secure_password
    belongs_to :account, dependent: :destroy
    has_many :sessions, dependent: :delete_all

    normalizes :email_address, with: ->(email) { email.strip.downcase }
    normalizes :name, with: ->(name) { name.strip }

    validates :name, presence: true, length: { maximum: 100 }
    validates :email_address, presence: true, uniqueness: { message: "is already used" },
      format: { with: EMAIL_FORMAT, message: "must look like name@example.com", allow_blank: true }
    validates :password, length: { minimum: PASSWORD_MINIMUM, message: "must be at least #{PASSWORD_MINIMUM} characters" },
      allow_nil: true

    before_validation :build_account, on: :create, unless: :account

    scope :admins, -> { where(admin: true) }

    def initial = name.to_s.first.to_s.upcase

    def end_sessions! = sessions.delete_all
  end
  ```
  ```ruby
  # app/models/session.rb
  class Session < ApplicationRecord
    belongs_to :user
  end
  ```
  ```ruby
  # app/models/current.rb
  class Current < ActiveSupport::CurrentAttributes
    attribute :session
    delegate :user, to: :session, allow_nil: true

    def account = user&.account
  end
  ```
- [ ] Add factories `spec/factories/accounts.rb`:
  ```ruby
  FactoryBot.define do
    factory :account

    factory :user do
      sequence(:name) { |n| "Collector #{n}" }
      sequence(:email_address) { |n| "collector#{n}@example.test" }
      password { "correct horse battery" }

      factory :admin do
        admin { true }
      end
    end
  end
  ```
- [ ] Run: `bin/rails db:migrate && bin/rspec spec/models/user_spec.rb` — expect: PASS.
- [ ] Commit: `feat(accounts): add accounts, users and sessions`
- [ ] Add the sign-in routing example to `spec/routing/routes_spec.rb`:
  ```ruby
  it "routes sign-in, sign-out and the collection", :aggregate_failures do
    expect(get: "/session/new").to route_to("sessions#new")
    expect(post: "/session").to route_to("sessions#create")
    expect(delete: "/session").to route_to("sessions#destroy")
    expect(get: "/collection").to route_to("collections#show")
  end
  ```
- [ ] Write the failing request spec `spec/requests/sessions_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Sign-in", type: :request do
    before { create(:user, email_address: "ann@example.test") }

    def sign_in(email: "ann@example.test", password: "correct horse battery", env: {})
      post session_path, params: { email_address: email, password: }, env:
    end

    it "redirects signed-out requests to sign-in and back after signing in", :aggregate_failures do
      get catalog_entries_path(q: "bolt")
      expect(response).to redirect_to(new_session_path)

      sign_in(email: "ANN@example.test")
      expect(response).to redirect_to(catalog_entries_path(q: "bolt"))
    end

    it "goes to the collection when no page was requested" do
      sign_in
      expect(response).to redirect_to(collection_path)
    end

    it "rejects a wrong password without saying which field was wrong", :aggregate_failures do
      sign_in(password: "wrong password!")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Email or password is incorrect.")
    end

    it "lets the health check through without signing in" do
      get rails_health_check_path
      expect(response).to have_http_status(:ok)
    end

    it "signs out only the current session", :aggregate_failures do
      sign_in
      expect { delete session_path }.to change(Session, :count).by(-1)
      get collection_path
      expect(response).to redirect_to(new_session_path)
    end

    it "sends a signed-in user away from sign-in" do
      sign_in
      get new_session_path
      expect(response).to redirect_to(collection_path)
    end

    it "sets an http-only, same-site session cookie that is secure over https" do
      https!
      sign_in
      # Rack 3 writes cookie attributes in lowercase.
      expect(response.headers["Set-Cookie"].to_s).to match(/httponly/i).and match(/samesite=lax/i).and match(/secure/i)
    end

    describe "rate limiting" do
      it "refuses the 11th attempt for one email from one address within 3 minutes", :aggregate_failures do
        10.times { sign_in(password: "wrong password!") }
        sign_in
        expect(response).to have_http_status(:too_many_requests)
        expect(response.body).to include("Too many attempts. Try again in a few minutes.")
      end

      it "doesn't lock out a different email from the same address" do
        create(:user, email_address: "bo@example.test")
        10.times { sign_in(password: "wrong password!") }
        sign_in(email: "bo@example.test")
        expect(response).to redirect_to(collection_path)
      end

      it "doesn't lock out the same email from a different client address" do
        10.times { sign_in(password: "wrong password!") }
        sign_in(env: { "REMOTE_ADDR" => "203.0.113.9" })
        expect(response).to redirect_to(collection_path)
      end

      it "counts the address a trusted proxy forwards, not the proxy's own", :aggregate_failures do
        # Requests come from 127.0.0.1, a trusted proxy, so X-Forwarded-For is honoured.
        10.times { sign_in(password: "wrong password!", env: { "HTTP_X_FORWARDED_FOR" => "198.51.100.7" }) }
        sign_in(env: { "HTTP_X_FORWARDED_FOR" => "198.51.100.7" })
        expect(response).to have_http_status(:too_many_requests)
        sign_in(env: { "HTTP_X_FORWARDED_FOR" => "198.51.100.8" })
        expect(response).to redirect_to(collection_path)
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/sessions_spec.rb` — expect: FAIL.
- [ ] Add the configuration:
  - In `config/application.rb`, add `require_relative "../lib/collector/trusted_proxies"` after `Bundler.require(*Rails.groups)`, and inside the class:
    ```ruby
    # Reverse proxies whose X-Forwarded-For is trusted (spec 004 AC-4.8).
    config.action_dispatch.trusted_proxies = Collector::TrustedProxies.parse(ENV["COLLECTOR_TRUSTED_PROXIES"])
    config.x.sign_in_rate_limit_store = nil # nil: Rails.cache
    ```
  - In `config/environments/test.rb`, add `config.x.sign_in_rate_limit_store = ActiveSupport::Cache::MemoryStore.new` (the test cache is `:null_store`, which never counts).
  - In `config/environments/production.rb`, replace the commented `assume_ssl`/`force_ssl` lines with:
    ```ruby
    # Set COLLECTOR_HTTPS=true when the instance is served over HTTPS (directly or behind a TLS proxy).
    https = ENV["COLLECTOR_HTTPS"] == "true"
    config.assume_ssl = https
    config.force_ssl = https
    config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
    ```
  - `config/initializers/filter_parameter_logging.rb` already filters `:passw`, which covers `password` and `password_confirmation`; leave it as it is.
- [ ] Add the routes to `config/routes.rb`, above the `namespace :catalog` block:
  ```ruby
  resource :session, only: %i[new create destroy]
  resource :collection, only: :show
  ```
- [ ] Write the placeholder landing page (Phase 10 fills it in). `app/controllers/collections_controller.rb`:
  ```ruby
  class CollectionsController < ApplicationController
    def show
    end
  end
  ```
  `app/views/collections/show.html.erb`:
  ```erb
  <% content_for :title, "My collection · Collector" %>
  <main class="c-main"><div class="c-pagehead"><div><h1 class="c-pagehead__title">My collection</h1></div></div></main>
  ```
- [ ] Write `app/controllers/concerns/authentication.rb`:
  ```ruby
  # Cookie sessions for signed-in users (spec 004 FR-2), in the Rails 8 generator's shape.
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :require_authentication
      helper_method :authenticated?
    end

    class_methods do
      def allow_unauthenticated_access(**options)
        skip_before_action :require_authentication, **options
      end
    end

    private
      def authenticated? = resume_session.present?

      def require_authentication
        resume_session || request_authentication
      end

      def resume_session
        Current.session ||= find_session_by_cookie
      end

      def find_session_by_cookie
        Session.includes(user: :account).find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
      end

      def request_authentication
        session[:return_to_after_authenticating] = request.fullpath if request.get?
        redirect_to new_session_path
      end

      def after_authentication_url
        session.delete(:return_to_after_authenticating) || collection_path
      end

      def start_new_session_for(user)
        user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |new_session|
          Current.session = new_session
          cookies.signed.permanent[:session_id] = { value: new_session.id, httponly: true, same_site: :lax, secure: request.ssl? }
        end
      end

      def terminate_session
        Current.session&.destroy
        cookies.delete(:session_id)
      end

      def redirect_signed_in_users
        redirect_to collection_path if authenticated?
      end
  end
  ```
- [ ] Update `app/controllers/application_controller.rb`:
  ```ruby
  class ApplicationController < ActionController::Base
    include Authentication

    # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
    allow_browser versions: :modern

    # Changes to the importmap will invalidate the etag for HTML responses
    stale_when_importmap_changes
  end
  ```
- [ ] Write `app/controllers/sessions_controller.rb`:
  ```ruby
  class SessionsController < ApplicationController
    allow_unauthenticated_access only: %i[new create]
    before_action :redirect_signed_in_users, only: %i[new create]
    rate_limit to: 10, within: 3.minutes, only: :create,
      store: Rails.application.config.x.sign_in_rate_limit_store || Rails.cache,
      by: -> { "#{request.remote_ip}|#{params[:email_address].to_s.strip.downcase}" },
      with: -> { render_new("Too many attempts. Try again in a few minutes.", :too_many_requests) }

    def new
    end

    def create
      if (user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s))
        start_new_session_for(user)
        redirect_to after_authentication_url, status: :see_other
      else
        render_new("Email or password is incorrect.", :unprocessable_entity)
      end
    end

    def destroy
      terminate_session
      redirect_to new_session_path, status: :see_other
    end

    private
      def render_new(message, status)
        flash.now[:alert] = message
        render :new, status:
      end
  end
  ```
- [ ] Write `app/views/layouts/_brand_appbar.html.erb` (the header on signed-out pages, FR-13 "brand only"):
  ```erb
  <header class="c-appbar" id="appbar">
    <span class="c-appbar__brand">
      <span class="c-appbar__wordmark"><%= image_tag "collector/collector-wordmark.svg", alt: "Collector", class: "c-logo--light" %><%= image_tag "collector/collector-wordmark-reversed.svg", alt: "Collector", class: "c-logo--dark" %></span>
      <span class="c-appbar__mark"><%= image_tag "collector/collector-mark.svg", alt: "Collector", class: "c-logo--light" %><%= image_tag "collector/collector-mark-reversed.svg", alt: "Collector", class: "c-logo--dark" %></span>
    </span>
  </header>
  ```
- [ ] Write `app/views/shared/_field_errors.html.erb`:
  ```erb
  <% record.errors.full_messages_for(field).each do |message| %>
    <p class="c-field__error" id="<%= "#{field}-error" %>"><%= message %></p>
  <% end %>
  ```
- [ ] Write `app/views/sessions/new.html.erb`:
  ```erb
  <% content_for :title, "Sign in · Collector" %>
  <% content_for :appbar, render("layouts/brand_appbar") %>
  <main class="c-main c-auth">
    <h1 class="c-pagehead__title">Sign in</h1>
    <%= form_with url: session_path, class: "c-form" do |form| %>
      <div class="c-field">
        <%= form.label :email_address, "Email", class: "c-field__label" %>
        <label class="c-input"><%= form.email_field :email_address, autocomplete: "username", required: true, value: params[:email_address] %></label>
      </div>
      <div class="c-field">
        <%= form.label :password, "Password", class: "c-field__label" %>
        <label class="c-input"><%= form.password_field :password, autocomplete: "current-password", required: true %></label>
      </div>
      <div class="c-form__actions"><%= form.submit "Sign in", class: "c-btn c-btn--primary" %></div>
    <% end %>
  </main>
  ```
- [ ] Append the auth/form patterns to `app/assets/stylesheets/collector/additions.css`:
  ```css
  /* ---------- Status message (live region under the header) ---------- */
  .c-status:empty { display:none; }
  .c-status { padding:var(--space-3) var(--space-8) 0; }
  .c-status__message { margin:0; padding:var(--space-2) var(--space-3); background:var(--brand-tint); color:var(--ink);
    border:1px solid var(--brand); border-radius:var(--radius-md); font:400 14px/20px var(--font-sans); }
  .c-status__message--alert { background:var(--surface-raised); border-color:var(--warning); }
  @media (max-width: 639px) { .c-status { padding:var(--space-3) var(--space-4) 0; } }

  /* ---------- Form: stacked fields with per-field errors ---------- */
  .c-form { display:flex; flex-direction:column; gap:var(--space-4); max-width:420px; }
  .c-field { display:flex; flex-direction:column; gap:var(--space-1); }
  .c-field__label { font:600 12px/16px var(--font-sans); color:var(--ink); }
  .c-field__hint { margin:0; font:400 12px/16px var(--font-sans); color:var(--ink-muted); }
  .c-field__error { margin:0; font:600 12px/16px var(--font-sans); color:var(--danger); }
  .c-field select { height:36px; padding:0 var(--space-3); background:var(--surface-raised); color:var(--ink);
    border:1px solid var(--line-strong); border-radius:var(--radius-md); font:400 15px/22px var(--font-sans); }
  .c-field select:focus-visible { outline:2px solid var(--focus); outline-offset:2px; }
  .c-field--invalid .c-input, .c-field--invalid select { border-color:var(--danger); }
  .c-form__actions { display:flex; flex-wrap:wrap; gap:var(--space-2); }
  .c-check { display:flex; align-items:center; gap:var(--space-2); font:400 14px/20px var(--font-sans); }
  .c-check input { width:16px; height:16px; accent-color:var(--brand); }

  /* ---------- Auth page (sign-in, sign-up) ---------- */
  .c-auth { max-width:480px; margin:0 auto; display:flex; flex-direction:column; gap:var(--space-6); }
  .c-auth p { margin:0; font:400 15px/22px var(--font-sans); }
  ```
  (`.c-field__error` uses `danger` as a status colour with a word, per README.)
- [ ] Write `spec/support/authentication_helpers.rb` and sign in across the 002 specs:
  ```ruby
  module AuthenticationHelpers
    PASSWORD = "correct horse battery".freeze

    def sign_in_as(user)
      post session_path, params: { email_address: user.email_address, password: PASSWORD }
      user
    end

    def system_sign_in_as(user)
      visit new_session_path
      fill_in "Email", with: user.email_address
      fill_in "Password", with: PASSWORD
      click_on "Sign in"
      user
    end
  end

  RSpec.configure do |config|
    config.include AuthenticationHelpers, type: :request
    config.include AuthenticationHelpers, type: :system
    # The sign-in rate limit counts in a process-wide MemoryStore in test; start every request spec at zero.
    config.before(type: :request) { Rails.application.config.x.sign_in_rate_limit_store&.clear }
  end
  ```
- [ ] Sign in across the existing specs, which would otherwise be redirected to sign-in:
  - `spec/requests/catalog/entries_search_spec.rb` and `spec/requests/catalog/identities_spec.rb`: add `before { sign_in_as(create(:user)) }` as the first line inside `RSpec.describe`.
  - `spec/requests/catalog/entries_show_spec.rb`: it already has a top-level `before`, so add `sign_in_as(create(:user))` as the last line of that block rather than a second hook (`RSpec/ScatteredSetup`).
  - `spec/requests/design_system_spec.rb` and `spec/requests/home_spec.rb`: add `before { sign_in_as(create(:user)) }`.
  - `spec/system/catalog_search_spec.rb` and `spec/system/home_spec.rb`: add `system_sign_in_as(create(:user))` as the first line of each example.
- [ ] Run: `bin/rspec` — expect: PASS (the whole suite, including 002's specs and the routing spec).
- [ ] Commit: `feat(auth): require sign-in with rate-limited email and password sessions`

---

## Phase 3: First run, sign-up and the sign-up setting

**Implements:** FR-4 (first run, setting), FR-3 (first user is admin) | **Satisfies:** AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-4.1, AC-4.2, AC-4.3, AC-4.4a, AC-12.3 (sign-up)
**Files:** `config/routes.rb`, `spec/routing/routes_spec.rb`, `config/locales/en.yml`, `db/migrate/*_create_instance_settings.rb`, `app/models/instance_setting.rb`, `app/models/registration.rb`, `app/controllers/concerns/first_run.rb`, `app/controllers/application_controller.rb`, `app/controllers/registrations_controller.rb`, `app/views/registrations/new.html.erb`, `app/views/registrations/_closed.html.erb`, `spec/models/registration_spec.rb`, `spec/requests/registrations_spec.rb`
**Interfaces:** Consumes: `User`, `start_new_session_for`, `redirect_signed_in_users` (Phase 2). Produces: routes `registration_path`, `new_registration_path`; `InstanceSetting.current` (`#sign_up_open?`, `#update!(sign_up_open:)`); `Registration.new(params).save` → `User` or false; `Registration.open?`; `Registration::PERMITTED`; the `FirstRun` concern (`before_action :require_first_user`, `allow_before_first_user`); the locale name "Email" for `User#email_address`.

- [ ] Write the failing model spec `spec/models/registration_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Registration, type: :model do
    let(:params) { { name: "Ann", email_address: "ann@example.test", password: "correct horse battery", password_confirmation: "correct horse battery" } }

    it "makes the first user an admin and closes sign-up", :aggregate_failures do
      user = described_class.new(params).save
      expect(user).to be_admin
      expect(InstanceSetting.current).not_to be_sign_up_open
    end

    it "creates non-admin users while sign-up is open" do
      create(:admin)
      InstanceSetting.current.update!(sign_up_open: true)
      expect(described_class.new(params).save).not_to be_admin
    end

    it "refuses when another user exists and sign-up is closed", :aggregate_failures do
      create(:admin)
      registration = described_class.new(params)
      expect(registration.save).to be(false)
      expect(registration).to be_closed
    end

    it "ignores admin and account values in the submission" do
      create(:admin)
      InstanceSetting.current.update!(sign_up_open: true)
      user = described_class.new(params.merge(admin: true, account_id: 999)).save
      expect([ user.admin?, user.account_id ]).not_to include(true, 999)
    end

    it "reports mismatched confirmations on the confirmation field" do
      registration = described_class.new(params.merge(password_confirmation: "something else!"))
      registration.save
      expect(registration.user.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/registration_spec.rb` — expect: FAIL.
- [ ] Write the migration `db/migrate/20260929120100_create_instance_settings.rb`:
  ```ruby
  class CreateInstanceSettings < ActiveRecord::Migration[8.1]
    def change
      create_table :instance_settings do |t|
        t.boolean :sign_up_open, null: false, default: false
        t.timestamps
      end
    end
  end
  ```
- [ ] Write `app/models/instance_setting.rb`:
  ```ruby
  # Instance-wide settings; a single row (spec 004 FR-4).
  class InstanceSetting < ApplicationRecord
    def self.current = first || create!
  end
  ```
- [ ] Write `app/models/registration.rb`:
  ```ruby
  # Sign-up: creates the first admin on an empty instance, or a regular user while sign-up is open
  # (spec 004 AC-3.2, AC-3.4, AC-4.1, AC-4.2). The check and the insert share one IMMEDIATE write
  # transaction, so two submissions can't both become the first admin.
  class Registration
    PERMITTED = %i[name email_address password password_confirmation].freeze

    attr_reader :user

    def self.open? = !User.exists? || InstanceSetting.current.sign_up_open?

    def initialize(params)
      @user = User.new(params.to_h.symbolize_keys.slice(*PERMITTED))
      @closed = false
    end

    def closed? = @closed

    def save
      User.transaction do
        first = !User.exists?
        next @closed = true unless first || InstanceSetting.current.sign_up_open?

        user.admin = first
        next unless user.save

        InstanceSetting.current.update!(sign_up_open: false) if first
        user
      end.then { |result| result.is_a?(User) ? result : false }
    end
  end
  ```
- [ ] Run: `bin/rails db:migrate && bin/rspec spec/models/registration_spec.rb` — expect: PASS.
- [ ] Commit: `feat(accounts): add sign-up with a first-run admin and a closed-by-default setting`
- [ ] Add the sign-up routing example to `spec/routing/routes_spec.rb`:
  ```ruby
  it "routes sign-up", :aggregate_failures do
    expect(get: "/registration/new").to route_to("registrations#new")
    expect(post: "/registration").to route_to("registrations#create")
  end
  ```
- [ ] Write the failing request spec `spec/requests/registrations_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Sign-up", type: :request do
    let(:params) { { user: { name: "Ann", email_address: "ann@example.test", password: "correct horse battery", password_confirmation: "correct horse battery" } } }

    context "when the instance has no users" do
      it "sends every page except sign-up and the health check to sign-up", :aggregate_failures do
        get catalog_entries_path
        expect(response).to redirect_to(new_registration_path)
        get new_session_path
        expect(response).to redirect_to(new_registration_path)
        get rails_health_check_path
        expect(response).to have_http_status(:ok)
      end

      it "explains that the first account is the admin and signs the new admin in", :aggregate_failures do
        get new_registration_path
        expect(response.body).to include("This first account will be the admin of this instance.")

        post registration_path, params: params
        expect(response).to redirect_to(collection_path)
        expect(User.sole).to be_admin
      end
    end

    context "when sign-up is closed" do
      before { create(:admin) }

      it "shows the closed message without a form, and refuses submissions", :aggregate_failures do
        get new_registration_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Sign-up is closed on this instance. Ask the person who runs it for an account.")
        expect(response.body).not_to include("<form")

        expect { post registration_path, params: params }.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Sign-up is closed on this instance.")
      end
    end

    context "when sign-up is open" do
      before do
        create(:admin)
        InstanceSetting.current.update!(sign_up_open: true)
      end

      it "creates a non-admin user with their own account" do
        expect { post registration_path, params: params }.to change(Account, :count).by(1)
      end

      it "shows each invalid field's message with 422", :aggregate_failures do
        post registration_path, params: { user: { name: "", email_address: "nope", password: "short", password_confirmation: "other" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Name can&#39;t be blank", "Email must look like name@example.com",
          "Password must be at least 12 characters", "Password confirmation doesn&#39;t match Password")
      end
    end

    it "sends a signed-in user away from sign-up" do
      sign_in_as(create(:admin))
      get new_registration_path
      expect(response).to redirect_to(collection_path)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/requests/registrations_spec.rb` — expect: FAIL.
- [ ] Add the route to `config/routes.rb`, below `resource :session`: `resource :registration, only: %i[new create]`.
- [ ] Replace `config/locales/en.yml` so validation messages name the field as the form labels it ("Email must look like…", AC-4.3):
  ```yaml
  en:
    activerecord:
      attributes:
        user:
          email_address: "Email"
  ```
- [ ] Write `app/controllers/concerns/first_run.rb`:
  ```ruby
  # On an instance with no users, every page goes to sign-up, which creates the first admin
  # (spec 004 AC-3.1). The health check doesn't inherit ApplicationController, so it's exempt.
  module FirstRun
    extend ActiveSupport::Concern

    included do
      before_action :require_first_user
    end

    class_methods do
      def allow_before_first_user(**options) = skip_before_action(:require_first_user, **options)
    end

    private
      def require_first_user
        redirect_to new_registration_path unless User.exists?
      end
  end
  ```
  In `ApplicationController`, add `include FirstRun` **before** `include Authentication` (first run wins over sign-in).
- [ ] Write `app/controllers/registrations_controller.rb`:
  ```ruby
  class RegistrationsController < ApplicationController
    allow_before_first_user
    allow_unauthenticated_access
    before_action :redirect_signed_in_users

    def new
      @first_user = !User.exists?
      @registration = Registration.new({}) if Registration.open?
    end

    def create
      @registration = Registration.new(registration_params)
      if (user = @registration.save)
        start_new_session_for(user)
        redirect_to collection_path, status: :see_other
      else
        @first_user = !User.exists? && !@registration.closed?
        render :new, status: :unprocessable_entity
      end
    end

    private
      def registration_params = params.expect(user: Registration::PERMITTED)
  end
  ```
- [ ] Write `app/views/registrations/new.html.erb`:
  ```erb
  <% content_for :title, "Sign up · Collector" %>
  <% content_for :appbar, render("layouts/brand_appbar") %>
  <main class="c-main c-auth">
    <h1 class="c-pagehead__title"><%= @first_user ? "Set up Collector" : "Sign up" %></h1>
    <% if @registration.nil? || @registration.closed? %>
      <%= render "registrations/closed" %>
    <% else %>
      <% if @first_user %>
        <p>This first account will be the admin of this instance. You can open sign-up for others and manage users afterwards.</p>
      <% end %>
      <%= form_with model: @registration.user, url: registration_path, scope: :user, class: "c-form" do |form| %>
        <% user = @registration.user %>
        <% [ [ :name, "Name", :text_field, "name" ], [ :email_address, "Email", :email_field, "username" ],
             [ :password, "Password", :password_field, "new-password" ], [ :password_confirmation, "Confirm password", :password_field, "new-password" ] ].each do |field, label, type, autocomplete| %>
          <div class="c-field<%= " c-field--invalid" if user.errors[field].any? %>">
            <%= form.label field, label, class: "c-field__label" %>
            <label class="c-input"><%= form.public_send(type, field, autocomplete:, "aria-describedby": ("#{field}-error" if user.errors[field].any?)) %></label>
            <% if field == :password %><p class="c-field__hint">At least 12 characters.</p><% end %>
            <%= render "shared/field_errors", record: user, field: %>
          </div>
        <% end %>
        <div class="c-form__actions"><%= form.submit(@first_user ? "Create admin account" : "Sign up", class: "c-btn c-btn--primary") %></div>
      <% end %>
    <% end %>
  </main>
  ```
  and `app/views/registrations/_closed.html.erb`:
  ```erb
  <p>Sign-up is closed on this instance. Ask the person who runs it for an account.</p>
  <p><%= link_to "Sign in", new_session_path, class: "c-btn c-btn--secondary" %></p>
  ```
- [ ] Run: `bin/rspec` — expect: PASS. (Every earlier request and system spec creates a user before its first request, so first run doesn't trigger; `/up` doesn't inherit `ApplicationController`.)
- [ ] Commit: `feat(accounts): send an empty instance to first-admin sign-up`
- [ ] Add AC-3.4 to `spec/requests/registrations_spec.rb`:
  ```ruby
  it "refuses a first-admin form submitted after someone else became the first user", :aggregate_failures do
    get new_registration_path
    create(:admin)
    expect { post registration_path, params: params }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Sign-up is closed on this instance.")
  end
  ```
- [ ] Run: `bin/rspec spec/requests/registrations_spec.rb` — expect: PASS.
- [ ] Commit: `test(accounts): cover the first-admin race`

---

## Phase 4: App shell and navigation

**Implements:** FR-13, FR-11 (OS-dark logo swap, More page) | **Satisfies:** AC-2.1, AC-2.2, AC-2.3, AC-2.4 (sign-out half; the admin link is added in Phase 6), AC-2.5, AC-2.6, AC-2.8, AC-4.7 (sign-out control)
**Files:** `config/routes.rb`, `spec/routing/routes_spec.rb`, `app/views/layouts/{_appbar,_tabbar}.html.erb`, `app/views/icons/{_collection,_search,_more,_plus,_back,_star,_check,_cross}.html.erb`, `app/controllers/collections_controller.rb` (adds `root`), `app/controllers/mores_controller.rb`, `app/views/mores/show.html.erb`, `app/views/collections/show.html.erb` (still a placeholder until Phase 10), `app/javascript/controllers/menu_controller.js`, `app/assets/stylesheets/collector/additions.css`, `app/views/catalog/entries/{index,show}.html.erb`, `app/views/catalog/identities/show.html.erb`; deleted: `app/controllers/home_controller.rb`, `app/views/home/`, `spec/requests/home_spec.rb`, `spec/system/home_spec.rb`; `spec/requests/shell_spec.rb`, `spec/system/theme_spec.rb`, `spec/system/catalog_search_spec.rb`
**Interfaces:** Consumes: `Current.user` (Phase 2). Produces:
- routes `more_path` and `root_path` (→ `collections#root`)
- partials `layouts/appbar` (locals: `section:` one of `:collection`, `:search` or `nil`; `detail:` boolean, default false; `back_path:`, default nil) and `layouts/tabbar` (local `section:`)
- icon partials `icons/{collection,search,more,plus,back,star,check,cross}`
- `CollectionsController#root` (redirects to `collection_path`)

- [ ] Add the routing example to `spec/routing/routes_spec.rb`:
  ```ruby
  it "routes the root and the More page", :aggregate_failures do
    expect(get: "/").to route_to("collections#root")
    expect(get: "/more").to route_to("mores#show")
  end
  ```
- [ ] Write the failing request spec `spec/requests/shell_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "App shell", type: :request do
    before { sign_in_as(create(:user, name: "james")) }

    it "shows the brand, Collection then Search, and the avatar menu", :aggregate_failures do
      get catalog_entries_path
      nav = response.body[%r{<nav class="c-appbar__nav".*?</nav>}m]
      expect(nav.index("Collection")).to be < nav.index("Search")
      # link_to writes its html options before href.
      expect(nav).to include(%(aria-current="page" href="#{catalog_entries_path}">Search</a>))
      expect(nav.scan('aria-current="page"').size).to eq(1)
      expect(response.body).to include('aria-label="Account: james"', ">J<", "Sign out", 'aria-label="Collector home"')
    end

    it "shows the tab bar with Collection, Search and More, marking the current section", :aggregate_failures do
      get collection_path
      tabbar = response.body[%r{<nav class="c-tabbar".*?</nav>}m]
      expect(tabbar).to include("Collection", "Search", "More")
      expect(tabbar).to include(%(aria-current="page" href="#{collection_path}">))
      expect(tabbar.scan('aria-current="page"').size).to eq(1)
    end

    it "shows an icon-only add button that leads to search" do
      get collection_path
      expect(response.body).to include(
        %(class="c-btn c-btn--primary c-btn--sm c-btn--icon c-appbar__add" aria-label="Add items" href="#{catalog_entries_path}"))
    end

    it "redirects the root to the collection" do
      get root_path
      expect(response).to redirect_to(collection_path)
    end

    it "offers sign out on the More page and marks no section", :aggregate_failures do
      get more_path
      expect(response.body).to include("Sign out", "Signed in as")
      expect(response.body).not_to include('aria-current="page"')
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/requests/shell_spec.rb` — expect: FAIL.
- [ ] In `config/routes.rb`, add `resource :more, only: :show` below `resource :collection`, and replace `root "home#index"` with `root "collections#root"`. Delete `app/controllers/home_controller.rb`, `app/views/home/`, `spec/requests/home_spec.rb` and `spec/system/home_spec.rb`: AC-2.6 replaces the placeholder home page, and `spec/system/theme_spec.rb` below takes over the "Turbo is loaded" check.
- [ ] Write the icon partials: Lucide paths, 1.5px stroke, `currentColor`, `aria-hidden`. For example, `app/views/icons/_search.html.erb`:
  ```erb
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
  ```
  The others use the same `<svg>` wrapper with these inner paths:

  | Partial | Paths |
  |---|---|
  | `_collection` | `<rect x="3" y="3" width="7" height="9" rx="1"/><rect x="14" y="3" width="7" height="9" rx="1"/><rect x="3" y="15" width="7" height="6" rx="1"/><rect x="14" y="15" width="7" height="6" rx="1"/>` |
  | `_more` | `<circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/>` |
  | `_plus` | `<path d="M12 5v14M5 12h14"/>` |
  | `_back` | `<path d="m15 18-6-6 6-6"/>` |
  | `_star` (foil badge; wrapper uses `fill="currentColor" stroke="none"`) | `<path d="m12 2 3 6.5 7 .8-5.2 4.8 1.4 7L12 17.6 5.8 21.1l1.4-7L2 9.3l7-.8z"/>` |
  | `_check` | `<path d="M20 6 9 17l-5-5"/>` |
  | `_cross` | `<path d="M18 6 6 18M6 6l12 12"/>` |
- [ ] Write `app/views/layouts/_appbar.html.erb`:
  ```erb
  <% detail = local_assigns.fetch(:detail, false) %>
  <% content_for :appbar do %>
    <header class="c-appbar<%= " c-appbar--detail" if detail %>" id="appbar">
      <% if detail && local_assigns[:back_path] %>
        <%= link_to local_assigns[:back_path], class: "c-btn c-btn--ghost c-btn--icon c-appbar__back", "aria-label": "Back" do %><%= render "icons/back" %><% end %>
      <% end %>
      <%= link_to root_path, class: "c-appbar__brand", "aria-label": "Collector home" do %>
        <span class="c-appbar__wordmark"><%= image_tag "collector/collector-wordmark.svg", alt: "", class: "c-logo--light" %><%= image_tag "collector/collector-wordmark-reversed.svg", alt: "", class: "c-logo--dark" %></span>
        <span class="c-appbar__mark"><%= image_tag "collector/collector-mark.svg", alt: "", class: "c-logo--light" %><%= image_tag "collector/collector-mark-reversed.svg", alt: "", class: "c-logo--dark" %></span>
      <% end %>
      <nav class="c-appbar__nav" aria-label="Main">
        <%= link_to "Collection", collection_path, "aria-current": ("page" if section == :collection) %>
        <%= link_to "Search", catalog_entries_path, "aria-current": ("page" if section == :search) %>
      </nav>
      <div class="c-appbar__actions">
        <% unless detail %>
          <%= link_to catalog_entries_path, class: "c-btn c-btn--primary c-btn--sm c-btn--icon c-appbar__add", "aria-label": "Add items" do %><%= render "icons/plus" %><% end %>
        <% end %>
        <details class="c-menu" data-controller="menu">
          <summary class="c-avatar" aria-label="Account: <%= Current.user.name %>"><%= Current.user.initial %></summary>
          <div class="c-menu__list">
            <%= button_to "Sign out", session_path, method: :delete, class: "c-menu__item", form: { class: "c-menu__form" } %>
          </div>
        </details>
      </div>
    </header>
  <% end %>
  ```
- [ ] Write `app/views/layouts/_tabbar.html.erb`:
  ```erb
  <% content_for :tabbar do %>
    <nav class="c-tabbar" id="tabbar" aria-label="Main">
      <%= link_to collection_path, "aria-current": ("page" if section == :collection) do %><span class="c-tabbar__icon"><%= render "icons/collection" %></span>Collection<% end %>
      <%= link_to catalog_entries_path, "aria-current": ("page" if section == :search) do %><span class="c-tabbar__icon"><%= render "icons/search" %></span>Search<% end %>
      <%= link_to more_path do %><span class="c-tabbar__icon"><%= render "icons/more" %></span>More<% end %>
    </nav>
  <% end %>
  ```
  (The More page is in no section, per FR-13, so its tab is never marked current.)
- [ ] Replace `app/controllers/collections_controller.rb` (the `show` page is filled in Phase 10):
  ```ruby
  class CollectionsController < ApplicationController
    def root
      redirect_to collection_path
    end

    def show
    end
  end
  ```
  and `app/views/collections/show.html.erb` (still a placeholder until Phase 10):
  ```erb
  <% content_for :title, "My collection · Collector" %>
  <%= render "layouts/appbar", section: :collection %>
  <main class="c-main"><div class="c-pagehead"><div><h1 class="c-pagehead__title">My collection</h1></div></div></main>
  <%= render "layouts/tabbar", section: :collection %>
  ```
- [ ] Write `app/controllers/mores_controller.rb` and `app/views/mores/show.html.erb`:
  ```ruby
  class MoresController < ApplicationController
    def show
    end
  end
  ```
  ```erb
  <% content_for :title, "More · Collector" %>
  <%= render "layouts/appbar", section: nil %>
  <main class="c-main">
    <h1 class="c-pagehead__title">More</h1>
    <ul class="c-list c-more">
      <li><span>Signed in as <strong><%= Current.user.name %></strong></span><span class="c-list__meta"><%= Current.user.email_address %></span></li>
      <li><%= button_to "Sign out", session_path, method: :delete, class: "c-btn c-btn--secondary" %></li>
    </ul>
  </main>
  <%= render "layouts/tabbar", section: nil %>
  ```
- [ ] Write `app/javascript/controllers/menu_controller.js` (enhancement only: closes on an outside click or Esc):
  ```js
  import { Controller } from "@hotwired/stimulus"

  // Closes a <details> menu on outside click or Escape; the menu works without it.
  export default class extends Controller {
    connect() {
      this.close = this.close.bind(this)
      this.onKeydown = this.onKeydown.bind(this)
      document.addEventListener("click", this.close)
      document.addEventListener("keydown", this.onKeydown)
    }

    disconnect() {
      document.removeEventListener("click", this.close)
      document.removeEventListener("keydown", this.onKeydown)
    }

    close(event) {
      if (!this.element.contains(event.target)) this.element.open = false
    }

    onKeydown(event) {
      if (event.key === "Escape" && this.element.open) {
        this.element.open = false
        this.element.querySelector("summary")?.focus()
      }
    }
  }
  ```
- [ ] Append to `additions.css`:
  ```css
  /* ---------- Logo follows the OS theme when the page pins none (the export swaps only on data-theme="dark") ---------- */
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme]) .c-logo--light { display:none; }
    :root:not([data-theme]) .c-logo--dark { display:inline; }
  }

  /* ---------- Menu items that are forms (button_to) ---------- */
  .c-menu__form { display:contents; }
  .c-menu__form .c-menu__item { width:100%; }

  /* ---------- More page: c-list of account links ---------- */
  .c-more { margin-top:var(--space-6); }
  .c-more li { flex-wrap:wrap; }
  ```
- [ ] Switch the existing pages to the shell: add `<%= render "layouts/appbar", section: :search %>` as the first line after `content_for :title`, and `<%= render "layouts/tabbar", section: :search %>` as the last line, in `app/views/catalog/entries/index.html.erb`, `app/views/catalog/identities/show.html.erb` and `app/views/catalog/entries/show.html.erb`. Phases 7 and 8 rewrite these views.
- [ ] The header now has a "Search" nav link, so `click_on "Search"` in `spec/system/catalog_search_spec.rb` is ambiguous between the link and the submit button. Change it to `click_button "Search"`.
- [ ] Run: `bin/rspec` — expect: PASS (including `spec/system`).
- [ ] Commit: `feat(shell): add the app header, tab bar, More page and root redirect`
- [ ] Write the system spec `spec/system/theme_spec.rb` (AC-2.5). Each viewport or theme variant gets its own driver name, because Capybara reuses a session per driver name and would otherwise keep the 1400×1400 light default from `spec/support/system.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Theme", type: :system do
    it "follows the OS dark preference for tokens and the logo, with Turbo loaded", :aggregate_failures do
      driven_by :selenium, using: :headless_firefox, screen_size: [ 1280, 900 ], options: { name: :firefox_dark } do |options|
        options.add_preference("ui.systemUsesDarkTheme", 1)
        options.add_preference("layout.css.prefers-color-scheme.content-override", 0) # 0 = dark
      end
      system_sign_in_as(create(:user))
      visit collection_path

      # Dark --surface is #161513 in tokens.css.
      expect(page.evaluate_script("getComputedStyle(document.body).backgroundColor")).to eq("rgb(22, 21, 19)")
      expect(page).to have_css(".c-appbar__wordmark .c-logo--dark", visible: :visible)
      expect(page).to have_no_css(".c-appbar__wordmark .c-logo--light", visible: :visible)
      expect(page.evaluate_script("typeof window.Turbo")).to eq("object")
    end
  end
  ```
  The phone header (AC-2.7, AC-2.8 at 390px) is covered by Phase 8's and Phase 10's system specs.
- [ ] Run: `bin/rspec spec/system/theme_spec.rb` — expect: PASS.
- [ ] Commit: `test(shell): cover the OS dark theme and logo swap`

---

## Phase 5: Lots, collecting vocabulary and currency

**Implements:** FR-6 | **Satisfies:** AC-12.4, AC-12.5 (model and data store), AC-7.4, AC-7.5, AC-9.3, AC-9.4 and AC-10.2 (model level), and the 9,999 cap of AC-7.3a, AC-9.3 and AC-10.2 (model level)
**Files:** `db/migrate/*_create_lots.rb`, `app/models/lot.rb`, `app/models/account.rb`, `app/models/catalog.rb`, `app/models/mtg/collecting.rb`, `config/initializers/catalog.rb`, `lib/collector/currency.rb`, `config/initializers/currency.rb`, `README.md`, `spec/factories/lots.rb`, `spec/models/lot_spec.rb`, `spec/models/mtg/collecting_spec.rb`, `spec/lib/collector/currency_spec.rb`
**Interfaces:** Consumes: `Account` (Phase 2), `Catalog::Entry`, `MTG::Printing` (feature 002). Produces:
- `Catalog.collecting_for(collectible_type)` → a module with `.category_name`, `.conditions` (ordered `{ value => [label, short] }`), `.special_finishes`, `.finishes_for(entry)` and `.finish_label(value)`
- `Lot.add!(account:, entry:, quantity: 1, finish: nil, condition: nil, price_paid_cents: nil)` → `Lot` (raises `ActiveRecord::RecordInvalid`)
- `Lot#revise!(attributes)` → the surviving `Lot` (raises `ActiveRecord::RecordInvalid` with errors on the receiver)
- `Lot.owned_quantities(account, entry_ids)` → `{ entry_id => Integer }`
- `Lot.key_for(finish, condition, price_paid_cents)`, `Lot#price_paid` (a string such as `"12.40"`, or nil), `Lot#vocabulary`, `Lot::MAX_QUANTITY`, `Lot::FULL_MESSAGE`
- `Account#lots` (`dependent: :delete_all`) and `Account#copies_count`
- `Collector::Currency.fetch!(code)` → `Collector::Currency::Unit(code, symbol)`, and `Rails.configuration.x.currency`
- factory `:lot`

- [ ] Write the failing spec `spec/lib/collector/currency_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Collector::Currency do
    it "knows USD and EUR", :aggregate_failures do
      expect(described_class.fetch!("usd").symbol).to eq("$")
      expect(described_class.fetch!("EUR").symbol).to eq("€")
    end

    it "rejects an unknown code, naming it" do
      expect { described_class.fetch!("XYZ") }.to raise_error(ArgumentError, /COLLECTOR_CURRENCY.*"XYZ"/)
    end

    it "is configured at boot from the environment, defaulting to USD" do
      expect(Rails.configuration.x.currency).to eq(described_class::Unit.new(code: "USD", symbol: "$"))
    end
  end
  ```
- [ ] Run: `bin/rspec spec/lib/collector/currency_spec.rb` — expect: FAIL.
- [ ] Write `lib/collector/currency.rb`:
  ```ruby
  module Collector
    # Currencies price paid can be shown in (spec 004 FR-6). Amounts are stored in minor units and
    # always shown with two decimals.
    module Currency
      Unit = Data.define(:code, :symbol)

      SYMBOLS = {
        "USD" => "$", "CAD" => "CA$", "AUD" => "A$", "NZD" => "NZ$", "EUR" => "€", "GBP" => "£", "CHF" => "CHF ",
        "SEK" => "kr ", "NOK" => "kr ", "DKK" => "kr ", "PLN" => "zł ", "CZK" => "Kč ", "JPY" => "¥", "CNY" => "CN¥",
        "KRW" => "₩", "SGD" => "S$", "HKD" => "HK$", "BRL" => "R$", "MXN" => "MX$", "ZAR" => "R "
      }.freeze

      def self.fetch!(code)
        normalized = code.to_s.strip.upcase
        symbol = SYMBOLS.fetch(normalized) do
          raise ArgumentError, "COLLECTOR_CURRENCY #{code.inspect} is not supported; use one of #{SYMBOLS.keys.join(', ')}"
        end
        Unit.new(code: normalized, symbol:)
      end
    end
  end
  ```
  and `config/initializers/currency.rb`. Initializers run before `lib/` is autoloaded, so the lookup waits for `to_prepare`, which still runs during boot and so still stops the app on a bad code:
  ```ruby
  # Stops the app on an unsupported COLLECTOR_CURRENCY (spec 004 FR-6).
  Rails.application.config.to_prepare do
    Rails.configuration.x.currency = Collector::Currency.fetch!(ENV.fetch("COLLECTOR_CURRENCY", "USD"))
  end
  ```
- [ ] Add to `README.md`'s Compose variable table (columns: Variable, Required, Default, Purpose): `| \`COLLECTOR_CURRENCY\` | no | \`USD\` | Currency for the price you paid: USD, CAD, AUD, NZD, EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, JPY, CNY, KRW, SGD, HKD, BRL, MXN or ZAR |`. Below the table, add: "Changing `COLLECTOR_CURRENCY` later doesn't convert prices you've already entered; they're shown with the new symbol. An unsupported code stops the app at boot, naming the setting."
- [ ] Run: `bin/rspec spec/lib/collector/currency_spec.rb` — expect: PASS.
- [ ] Commit: `feat(collection): add the instance currency setting`
- [ ] Write the failing spec `spec/models/mtg/collecting_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe MTG::Collecting, type: :model do
    it "is registered for mtg" do
      expect(Catalog.collecting_for("mtg")).to eq(described_class)
    end

    it "offers the printing's finishes, nonfoil first", :aggregate_failures do
      printing = create(:mtg_printing, finishes: %w[etched foil nonfoil])
      expect(described_class.finishes_for(printing.entry)).to eq(%w[nonfoil foil etched])
      expect(described_class.finishes_for(create(:catalog_entry))).to eq([])
    end

    it "defines the category name, condition scale and special finishes", :aggregate_failures do
      expect(described_class.category_name).to eq("Magic: The Gathering")
      expect(described_class.conditions.values.map(&:last)).to eq(%w[NM LP MP HP DMG])
      expect(described_class.special_finishes).to eq(%w[foil etched])
      expect(described_class.finish_label("glossy")).to eq("Glossy")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/collecting_spec.rb` — expect: FAIL.
- [ ] Add to `app/models/catalog.rb`, inside `module Catalog`:
  ```ruby
  # Collecting vocabulary per collectible type (finishes, conditions); see config/initializers/catalog.rb.
  mattr_accessor :collecting, default: {}

  def self.collecting_for(collectible_type)
    collecting.fetch(collectible_type) { raise ArgumentError, "unknown collectible type: #{collectible_type}" }.constantize
  end
  ```
  and to `config/initializers/catalog.rb`, inside the `to_prepare` block: `Catalog.collecting["mtg"] = "MTG::Collecting"`.
- [ ] Write `app/models/mtg/collecting.rb`:
  ```ruby
  # How Magic cards are collected: finishes, conditions and the category name (spec 004 FR-6).
  module MTG::Collecting
    CATEGORY_NAME = "Magic: The Gathering"
    CONDITIONS = {
      "near_mint" => [ "Near mint", "NM" ], "lightly_played" => [ "Lightly played", "LP" ],
      "moderately_played" => [ "Moderately played", "MP" ], "heavily_played" => [ "Heavily played", "HP" ],
      "damaged" => [ "Damaged", "DMG" ]
    }.freeze
    SPECIAL_FINISHES = %w[foil etched].freeze
    FINISH_ORDER = %w[nonfoil foil etched].freeze

    def self.category_name = CATEGORY_NAME
    def self.conditions = CONDITIONS
    def self.special_finishes = SPECIAL_FINISHES
    def self.finish_label(finish) = finish.to_s.humanize

    def self.finishes_for(entry)
      Catalog::Entry.preload_extensions([ entry ]) if entry.extension.nil?
      Array(entry.extension&.finishes).sort_by { |finish| [ FINISH_ORDER.index(finish) || FINISH_ORDER.size, finish ] }
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/collecting_spec.rb` — expect: PASS.
- [ ] Commit: `feat(mtg): define MTG finishes and conditions for collecting`
- [ ] Write the failing spec `spec/models/lot_spec.rb` (the schema checks for AC-12.4 live here, so the spec describes a class):
  ```ruby
  require "rails_helper"

  RSpec.describe Lot, type: :model do
    let(:account) { create(:user).account }
    let(:entry) { create(:mtg_printing, finishes: %w[foil nonfoil]).entry }

    describe ".add!" do
      it "merges into the lot with the same finish, condition and price", :aggregate_failures do
        described_class.add!(account:, entry:)
        lot = described_class.add!(account:, entry:, quantity: 2)
        expect(lot.quantity).to eq(3)
        expect(account.lots.count).to eq(1)
      end

      it "creates a separate lot when any identity field differs" do
        described_class.add!(account:, entry:, finish: "foil", condition: "near_mint", price_paid_cents: 400)
        described_class.add!(account:, entry:)
        expect(account.lots.count).to eq(2)
      end

      it "refuses a sum above 9,999 and changes nothing", :aggregate_failures do
        described_class.add!(account:, entry:, quantity: 9_999)
        expect { described_class.add!(account:, entry:) }.to raise_error(ActiveRecord::RecordInvalid, /at most 9,999/)
        expect(account.lots.sole.quantity).to eq(9_999)
      end

      it "rejects a finish the printing lacks, an unknown condition and bad prices", :aggregate_failures do
        expect { described_class.add!(account:, entry:, finish: "etched") }.to raise_error(ActiveRecord::RecordInvalid, /Finish/)
        expect { described_class.add!(account:, entry:, condition: "mint") }.to raise_error(ActiveRecord::RecordInvalid, /Condition/)
        expect { described_class.add!(account:, entry:, price_paid_cents: -1) }.to raise_error(ActiveRecord::RecordInvalid, /Price/)
      end
    end

    describe "#revise!" do
      it "merges into another lot when the edit makes their identities equal", :aggregate_failures do
        foil = described_class.add!(account:, entry:, finish: "foil")
        plain = described_class.add!(account:, entry:, quantity: 2)
        survivor = plain.revise!(quantity: 2, finish: "foil", condition: nil, price_paid_cents: nil)
        expect(survivor).to eq(foil)
        expect([ survivor.quantity, account.lots.count ]).to eq([ 3, 1 ])
      end

      it "refuses a merge above 9,999 and leaves both lots as they were", :aggregate_failures do
        foil = described_class.add!(account:, entry:, finish: "foil", quantity: 9_000)
        plain = described_class.add!(account:, entry:, quantity: 1_000)
        expect { plain.revise!(quantity: 1_000, finish: "foil", condition: nil, price_paid_cents: nil) }
          .to raise_error(ActiveRecord::RecordInvalid)
        expect(plain.errors[:quantity]).to include(described_class::FULL_MESSAGE)
        expect([ foil.reload.quantity, plain.reload.finish ]).to eq([ 9_000, nil ])
      end
    end

    it "sums owned quantities per printing for one account" do
      described_class.add!(account:, entry:, quantity: 2)
      described_class.add!(account:, entry:, finish: "foil")
      described_class.add!(account: create(:user).account, entry:, quantity: 5)
      expect(described_class.owned_quantities(account, [ entry.id ])).to eq(entry.id => 3)
    end

    describe "data store" do
      let(:connection) { described_class.connection }

      it "rejects a duplicate identity even when validations are skipped" do
        described_class.add!(account:, entry:)
        duplicate = described_class.new(account:, entry:, quantity: 1, lot_key: described_class.key_for(nil, nil, nil))
        expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "gives lots an indexed, non-null account foreign key", :aggregate_failures do
        expect(connection.columns("lots").find { |column| column.name == "account_id" }.null).to be(false)
        expect(connection.foreign_keys("lots").map(&:to_table)).to include("accounts")
        expect(connection.indexes("lots").map(&:columns)).to include(a_collection_starting_with("account_id"))
      end

      it "keeps catalog tables global" do
        catalog = connection.tables.grep(/\A(catalog|mtg)_/)
        expect(catalog.select { |table| connection.column_exists?(table, :account_id) }).to be_empty
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/lot_spec.rb` — expect: FAIL.
- [ ] Write the migration `db/migrate/20260929120200_create_lots.rb` (check constraints inside `create_table`, so SQLite builds the table once):
  ```ruby
  class CreateLots < ActiveRecord::Migration[8.1]
    def change
      create_table :lots do |t|
        t.references :account, null: false, foreign_key: true, index: false
        t.references :catalog_entry, null: false, foreign_key: true
        t.integer :quantity, null: false
        t.string :finish
        t.string :condition
        t.integer :price_paid_cents
        t.string :lot_key, null: false
        t.timestamps
        t.index %i[account_id catalog_entry_id lot_key], unique: true
        t.check_constraint "quantity BETWEEN 1 AND 9999", name: "lots_quantity_range"
        t.check_constraint "price_paid_cents IS NULL OR price_paid_cents >= 0", name: "lots_price_non_negative"
      end
    end
  end
  ```
- [ ] Write `app/models/lot.rb`:
  ```ruby
  # Copies of one catalog entry with the same finish, condition and price paid, owned by an account
  # (spec 004 FR-6). Finish and condition are values the collectible's vocabulary defines
  # (Catalog.collecting_for); the core doesn't interpret them.
  class Lot < ApplicationRecord
    MAX_QUANTITY = 9_999
    FULL_MESSAGE = "One lot can hold at most 9,999 copies.".freeze

    belongs_to :account
    belongs_to :entry, class_name: "Catalog::Entry", foreign_key: :catalog_entry_id

    normalizes :finish, :condition, with: ->(value) { value.presence }

    validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :price_paid_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validate :quantity_within_cap, :finish_offered, :condition_known

    before_validation { self.lot_key = self.class.key_for(finish, condition, price_paid_cents) }

    def self.key_for(finish, condition, price_paid_cents) = [ finish, condition, price_paid_cents ].join("|")

    # Adds copies, merging into the lot with the same identity (spec 004 AC-7.4, AC-9.3). SQLite
    # IMMEDIATE transactions serialise writers; the unique index backs that up, and a lost race
    # retries once so it merges instead of failing (AC-12.5).
    def self.add!(account:, entry:, quantity: 1, finish: nil, condition: nil, price_paid_cents: nil)
      retried = false
      begin
        transaction do
          lot = find_or_initialize_by(account:, entry:, lot_key: key_for(finish.presence, condition.presence, price_paid_cents))
          lot.assign_attributes(finish:, condition:, price_paid_cents:, quantity: lot.quantity.to_i + quantity.to_i)
          lot.save!
          lot
        end
      rescue ActiveRecord::RecordNotUnique
        raise if retried

        retried = true
        retry
      end
    end

    def self.owned_quantities(account, entry_ids)
      account.lots.where(catalog_entry_id: entry_ids).group(:catalog_entry_id).sum(:quantity)
    end

    # Edits this lot. If the new identity matches another lot of the same printing, the two merge and
    # the other survives with the summed quantity (spec 004 AC-10.2). Errors always end up on self.
    def revise!(attributes)
      transaction do
        assign_attributes(attributes)
        validate!
        other = self.class.where(account_id:, catalog_entry_id:, lot_key:).where.not(id:).first
        next tap(&:save!) unless other

        other.quantity += quantity
        other.save!
        destroy!
        other
      end
    rescue ActiveRecord::RecordInvalid => error
      errors.merge!(error.record.errors) unless error.record == self
      raise ActiveRecord::RecordInvalid, self
    end

    def price_paid = price_paid_cents && format("%.2f", price_paid_cents / 100r)

    def vocabulary = Catalog.collecting_for(entry.collectible_type)

    private
      def quantity_within_cap
        errors.add(:quantity, :too_many, message: FULL_MESSAGE) if quantity.to_i > MAX_QUANTITY
      end

      def finish_offered
        errors.add(:finish, "isn't available for this printing") if finish && vocabulary.finishes_for(entry).exclude?(finish)
      end

      def condition_known
        errors.add(:condition, "isn't a known condition") if condition && vocabulary.conditions.exclude?(condition)
      end
  end
  ```
  In `app/models/account.rb`, add `has_many :lots, dependent: :delete_all` and `def copies_count = lots.sum(:quantity)`. Add the factory `spec/factories/lots.rb`:
  ```ruby
  FactoryBot.define do
    factory :lot do
      account { association(:user).account }
      entry { association(:mtg_printing).entry }
      quantity { 1 }
    end
  end
  ```
- [ ] Run: `bin/rails db:migrate && bin/rspec spec/models/lot_spec.rb` — expect: PASS.
- [ ] Run: `bin/rspec` — expect: PASS.
- [ ] Commit: `feat(collection): add lots with merge-on-identity and a unique identity index`

---

## Phase 6: User administration and the command-line user command

**Implements:** FR-5, FR-3 (last admin, deletion), FR-4 (command, README), FR-11 (admin list, confirmation page), FR-13 (admin link) | **Satisfies:** AC-5.1–AC-5.7, AC-2.4 (admin half), AC-3.5, AC-3.6
**Files:** `config/routes.rb`, `spec/routing/routes_spec.rb`, `app/controllers/concerns/admin_only.rb`, `app/controllers/admin/users_controller.rb`, `app/controllers/admin/users/deletions_controller.rb`, `app/controllers/admin/sign_up_settings_controller.rb`, `app/views/admin/users/{index,new,edit,_form}.html.erb`, `app/views/admin/users/deletions/new.html.erb`, `app/views/layouts/_appbar.html.erb`, `app/views/mores/show.html.erb`, `app/models/user.rb`, `app/models/user/command.rb`, `lib/tasks/collector.rake`, `README.md`, `.rubocop.yml`, `spec/requests/admin/users_spec.rb`, `spec/models/user/command_spec.rb`, `spec/tasks/collector_rake_spec.rb`, `app/assets/stylesheets/collector/additions.css`
**Interfaces:** Consumes: `Current.user`, `User`, `InstanceSetting`, `Registration.open?`, `Account#copies_count`, `Lot` (Phases 2–5), and the `layouts/appbar`/`layouts/tabbar` partials (Phase 4). Produces:
- routes `admin_users_path`, `new_admin_user_path`, `edit_admin_user_path(user)`, `admin_user_path(user)`, `new_admin_user_deletion_path(user)`, `admin_sign_up_setting_path`
- `User::Command.call(email:, password:)` → `[user, created]`
- the `AdminOnly` concern
- the `c-confirm` and `c-table__actions` patterns

- [ ] Add the routing example to `spec/routing/routes_spec.rb`:
  ```ruby
  it "routes user administration", :aggregate_failures do
    expect(get: "/admin/users").to route_to("admin/users#index")
    expect(post: "/admin/users").to route_to("admin/users#create")
    expect(get: "/admin/users/1/edit").to route_to("admin/users#edit", id: "1")
    expect(delete: "/admin/users/1").to route_to("admin/users#destroy", id: "1")
    expect(get: "/admin/users/1/deletion/new").to route_to("admin/users/deletions#new", user_id: "1")
    expect(patch: "/admin/sign_up_setting").to route_to("admin/sign_up_settings#update")
  end
  ```
- [ ] Write the failing request spec `spec/requests/admin/users_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "User administration", type: :request do
    let!(:admin) { create(:admin, name: "Ann") }

    context "when signed in as an admin" do
      before { sign_in_as(admin) }

      it "lists users with their details, copy counts and the sign-up setting", :aggregate_failures do
        bo = create(:user, name: "Bo", email_address: "bo@example.test")
        create(:lot, account: bo.account, quantity: 3)
        get admin_users_path
        expect(response.body).to include("Users and sign-up", "Bo", "bo@example.test", "Sign-up is closed", '<td class="is-num">3</td>')
      end

      it "links to user administration from the avatar menu and the More page", :aggregate_failures do
        get collection_path
        expect(response.body[%r{<details class="c-menu".*?</details>}m]).to include(%(href="#{admin_users_path}"))
        get more_path
        expect(response.body).to include("Users and sign-up")
      end

      it "opens sign-up" do
        patch admin_sign_up_setting_path, params: { sign_up_open: "1" }
        expect(InstanceSetting.current).to be_sign_up_open
      end

      it "creates a user who can sign in, with the admin flag set explicitly", :aggregate_failures do
        post admin_users_path, params: { user: { name: "Bo", email_address: "bo@example.test", password: "another long secret", admin: "1" } }
        expect(response).to redirect_to(admin_users_path)
        bo = User.find_by(email_address: "bo@example.test")
        expect([ bo.authenticate("another long secret").present?, bo.admin? ]).to eq([ true, true ])
      end

      it "edits a user's name and email" do
        bo = create(:user)
        patch admin_user_path(bo), params: { user: { name: "Bo B", email_address: "bo.b@example.test", password: "" } }
        expect(bo.reload.slice(:name, :email_address).values).to eq([ "Bo B", "bo.b@example.test" ])
      end

      it "sets a new password that replaces the old one and ends the user's sessions", :aggregate_failures do
        bo = create(:user)
        bo.sessions.create!
        patch admin_user_path(bo), params: { user: { name: bo.name, email_address: bo.email_address, password: "brand new password" } }
        expect(bo.reload.authenticate("correct horse battery")).to be(false)
        expect(bo.sessions).to be_empty
      end

      it "deletes another user with their lots and sessions after confirmation, leaving others alone", :aggregate_failures do
        bo = create(:user, name: "Bo")
        create(:lot, account: bo.account, quantity: 2)
        bo.sessions.create!
        kept = create(:lot, account: admin.account)
        get new_admin_user_deletion_path(bo)
        expect(response.body).to include("This permanently deletes Bo's account and all 2 copies in their collection. It can't be undone.")
        expect { delete admin_user_path(bo) }
          .to change(User, :count).by(-1).and change(Account, :count).by(-1).and change(Lot, :count).by(-1).and change(Session, :count).by(-1)
        expect(kept.reload.quantity).to eq(1)
      end

      it "refuses to delete yourself or demote the only admin", :aggregate_failures do
        delete admin_user_path(admin)
        expect(User.exists?(admin.id)).to be(true)
        expect(flash[:alert]).to eq("You can't delete your own account.")

        patch admin_user_path(admin), params: { user: { name: "Ann", email_address: admin.email_address, admin: "0" } }
        expect(admin.reload).to be_admin
        expect(response.body).to include("Collector needs at least one admin.")
      end
    end

    context "when signed in as a member" do
      before { sign_in_as(create(:user)) }

      it "returns 404 for every admin page and action", :aggregate_failures do
        [ -> { get admin_users_path }, -> { get new_admin_user_path }, -> { get edit_admin_user_path(admin) },
          -> { get new_admin_user_deletion_path(admin) }, -> { post admin_users_path, params: { user: { name: "X" } } },
          -> { patch admin_user_path(admin), params: { user: { name: "X" } } }, -> { delete admin_user_path(admin) },
          -> { patch admin_sign_up_setting_path, params: { sign_up_open: "1" } } ].each do |request|
          instance_exec(&request)
          expect(response).to have_http_status(:not_found)
        end
        expect(InstanceSetting.current).not_to be_sign_up_open
      end

      it "doesn't show the admin link" do
        get more_path
        expect(response.body).not_to include("Users and sign-up")
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/requests/admin/users_spec.rb` — expect: FAIL.
- [ ] Add to `config/routes.rb`, above `root`:
  ```ruby
  namespace :admin do
    resources :users, except: :show do
      resource :deletion, only: :new, module: :users
    end
    resource :sign_up_setting, only: :update
  end
  ```
- [ ] Write `app/controllers/concerns/admin_only.rb`:
  ```ruby
  # Admin pages and actions are invisible to everyone else (spec 004 AC-5.6).
  module AdminOnly
    extend ActiveSupport::Concern

    included do
      before_action { raise ActiveRecord::RecordNotFound unless Current.user&.admin? }
    end
  end
  ```
- [ ] Add to `app/models/user.rb` (above `private`, which it adds):
  ```ruby
  validate :keeps_an_admin, on: :update, if: -> { admin_changed?(from: true, to: false) }

  private
    def keeps_an_admin
      errors.add(:admin, "can't be removed: Collector needs at least one admin.") if User.admins.where.not(id:).none?
    end
  ```
- [ ] Write `app/controllers/admin/users_controller.rb`. The admin flag is assigned explicitly from its checkbox, never mass-assigned (`.claude/rules/security.md`):
  ```ruby
  class Admin::UsersController < ApplicationController
    include AdminOnly

    before_action :set_user, only: %i[edit update destroy]

    def index
      @users = User.order(:name)
      # Admin-only cross-account read (spec 004 AC-5.1): copies per account, in one grouped query.
      @copies = Lot.group(:account_id).sum(:quantity)
      @setting = InstanceSetting.current
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      assign_admin
      if @user.save
        redirect_to admin_users_path, notice: "Added #{@user.name}.", status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attributes = user_params
      attributes = attributes.except(:password) if attributes[:password].blank?
      @user.assign_attributes(attributes)
      assign_admin
      if @user.save
        @user.end_sessions! if attributes.key?(:password)
        redirect_to admin_users_path, notice: "Saved.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == Current.user
        redirect_to admin_users_path, alert: "You can't delete your own account.", status: :see_other
      else
        @user.destroy!
        redirect_to admin_users_path, notice: "Deleted #{@user.name}'s account.", status: :see_other
      end
    end

    private
      def set_user = @user = User.find(params[:id])

      def user_params = params.expect(user: %i[name email_address password])

      def assign_admin
        @user.admin = params[:user][:admin] == "1" if params[:user]&.key?(:admin)
      end
  end
  ```
  (`User belongs_to :account, dependent: :destroy` and `Account has_many :lots, dependent: :delete_all` remove the account and its lots; `has_many :sessions, dependent: :delete_all` removes the sessions.)
- [ ] Write `app/controllers/admin/users/deletions_controller.rb`:
  ```ruby
  # The no-script confirmation page for deleting a user (spec 004 FR-5, AC-5.4).
  class Admin::Users::DeletionsController < ApplicationController
    include AdminOnly

    def new
      @user = User.find(params[:user_id])
    end
  end
  ```
- [ ] Write `app/controllers/admin/sign_up_settings_controller.rb`:
  ```ruby
  class Admin::SignUpSettingsController < ApplicationController
    include AdminOnly

    def update
      open = params[:sign_up_open] == "1"
      InstanceSetting.current.update!(sign_up_open: open)
      redirect_to admin_users_path, notice: open ? "Sign-up is open." : "Sign-up is closed.", status: :see_other
    end
  end
  ```
- [ ] Write the views. `app/views/admin/users/index.html.erb`:
  ```erb
  <% content_for :title, "Users and sign-up · Collector" %>
  <%= render "layouts/appbar", section: nil %>
  <main class="c-main">
    <div class="c-pagehead">
      <div><h1 class="c-pagehead__title">Users and sign-up</h1><p class="c-pagehead__stats"><%= pluralize(@users.size, "user") %></p></div>
      <div class="c-pagehead__actions"><%= link_to "Add a user", new_admin_user_path, class: "c-btn c-btn--primary" %></div>
    </div>
    <p><%= link_to "Add a user", new_admin_user_path, class: "c-btn c-btn--secondary c-admin__add" %></p>

    <section class="c-admin__signup">
      <p><%= @setting.sign_up_open? ? "Sign-up is open: anyone who can reach this instance can create an account." : "Sign-up is closed: only you can add users." %></p>
      <%= button_to(@setting.sign_up_open? ? "Close sign-up" : "Open sign-up", admin_sign_up_setting_path, method: :patch,
            params: { sign_up_open: @setting.sign_up_open? ? "0" : "1" }, class: "c-btn c-btn--secondary") %>
    </section>

    <div class="c-collection">
      <table class="c-table">
        <thead><tr><th>Name</th><th class="is-opt">Email</th><th class="is-opt">Role</th><th class="is-num">Copies</th><th><span class="c-sr">Actions</span></th></tr></thead>
        <tbody>
          <% @users.each do |user| %>
            <tr>
              <td><div><%= user.name %><span class="c-table__sub"><%= user.email_address %> · <%= user.admin? ? "Admin" : "Member" %></span></div></td>
              <td class="is-opt is-data"><%= user.email_address %></td>
              <td class="is-opt"><%= user.admin? ? "Admin" : "Member" %></td>
              <td class="is-num"><%= number_with_delimiter(@copies.fetch(user.account_id, 0)) %></td>
              <td class="c-table__actions">
                <details class="c-menu" data-controller="menu">
                  <summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for <%= user.name %>"><%= render "icons/more" %></summary>
                  <div class="c-menu__list">
                    <%= link_to "Edit", edit_admin_user_path(user), class: "c-menu__item" %>
                    <% unless user == Current.user %>
                      <div class="c-menu__sep"></div>
                      <%= link_to "Delete…", new_admin_user_deletion_path(user), class: "c-menu__item c-menu__item--danger" %>
                    <% end %>
                  </div>
                </details>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  </main>
  <%= render "layouts/tabbar", section: nil %>
  ```
  (`c-pagehead__actions` hides below 640px, so the second, secondary "Add a user" link shows only on phones: `.c-admin__add` is hidden on wide screens.)

  `app/views/admin/users/_form.html.erb`:
  ```erb
  <%= form_with model: [ :admin, user ], class: "c-form" do |form| %>
    <% [ [ :name, "Name", :text_field ], [ :email_address, "Email", :email_field ], [ :password, (user.persisted? ? "New password" : "Password"), :password_field ] ].each do |field, label, type| %>
      <div class="c-field<%= " c-field--invalid" if user.errors[field].any? %>">
        <%= form.label field, label, class: "c-field__label" %>
        <label class="c-input"><%= form.public_send(type, field, autocomplete: (field == :password ? "new-password" : "off")) %></label>
        <% if field == :password %><p class="c-field__hint"><%= user.persisted? ? "Leave blank to keep the current password. At least 12 characters." : "At least 12 characters." %></p><% end %>
        <%= render "shared/field_errors", record: user, field: %>
      </div>
    <% end %>
    <div class="c-field<%= " c-field--invalid" if user.errors[:admin].any? %>">
      <label class="c-check"><%= form.check_box :admin %> Admin (can manage users and sign-up)</label>
      <%= render "shared/field_errors", record: user, field: :admin %>
    </div>
    <div class="c-form__actions">
      <%= form.submit(user.persisted? ? "Save" : "Add user", class: "c-btn c-btn--primary") %>
      <%= link_to "Cancel", admin_users_path, class: "c-btn c-btn--secondary" %>
    </div>
  <% end %>
  ```
  `app/views/admin/users/new.html.erb`:
  ```erb
  <% content_for :title, "Add a user · Collector" %>
  <%= render "layouts/appbar", section: nil %>
  <main class="c-main"><h1 class="c-pagehead__title">Add a user</h1><%= render "form", user: @user %></main>
  <%= render "layouts/tabbar", section: nil %>
  ```
  `app/views/admin/users/edit.html.erb`:
  ```erb
  <% content_for :title, "Edit #{@user.name} · Collector" %>
  <%= render "layouts/appbar", section: nil %>
  <main class="c-main"><h1 class="c-pagehead__title">Edit <%= @user.name %></h1><%= render "form", user: @user %></main>
  <%= render "layouts/tabbar", section: nil %>
  ```
  `app/views/admin/users/deletions/new.html.erb`:
  ```erb
  <% content_for :title, "Delete #{@user.name} · Collector" %>
  <%= render "layouts/appbar", section: nil %>
  <main class="c-main">
    <section class="c-confirm">
      <h1 class="c-pagehead__title">Delete <%= @user.name %>?</h1>
      <p>This permanently deletes <%= @user.name %>'s account and all <%= number_with_delimiter(@user.account.copies_count) %> copies in their collection. It can't be undone.</p>
      <div class="c-form__actions">
        <%= button_to "Delete #{@user.name}", admin_user_path(@user), method: :delete, class: "c-btn c-btn--danger" %>
        <%= link_to "Cancel", admin_users_path, class: "c-btn c-btn--secondary" %>
      </div>
    </section>
  </main>
  <%= render "layouts/tabbar", section: nil %>
  ```
- [ ] Add the admin link for admins. In `app/views/layouts/_appbar.html.erb`, make the avatar menu list:
  ```erb
  <div class="c-menu__list">
    <% if Current.user.admin? %><%= link_to "Users and sign-up", admin_users_path, class: "c-menu__item" %><div class="c-menu__sep"></div><% end %>
    <%= button_to "Sign out", session_path, method: :delete, class: "c-menu__item", form: { class: "c-menu__form" } %>
  </div>
  ```
  and in `app/views/mores/show.html.erb`, add between the "Signed in as" item and the "Sign out" item:
  ```erb
  <% if Current.user.admin? %><li><%= link_to "Users and sign-up", admin_users_path %></li><% end %>
  ```
- [ ] Append to `additions.css`:
  ```css
  /* ---------- Confirmation page (no-script confirm for destructive actions) ---------- */
  .c-confirm { max-width:560px; display:flex; flex-direction:column; gap:var(--space-4); }
  .c-confirm p { margin:0; font:400 15px/22px var(--font-sans); }

  /* ---------- Table action cell: as narrow as its "…" menu ---------- */
  .c-table td.c-table__actions { width:1%; }

  /* ---------- Admin users list: c-table in .c-collection, plus the sign-up setting row ---------- */
  .c-admin__signup { display:flex; flex-wrap:wrap; align-items:center; gap:var(--space-3); margin:var(--space-6) 0;
    padding:var(--space-3) var(--space-4); background:var(--surface-raised); border:1px solid var(--line); border-radius:var(--radius-md); }
  .c-admin__signup p { margin:0; font:400 14px/20px var(--font-sans); }
  .c-admin__add { display:none; }
  @media (max-width: 639px) { .c-admin__add { display:inline-flex; } }
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/requests/admin/users_spec.rb spec/requests/shell_spec.rb` — expect: PASS.
- [ ] Commit: `feat(admin): let admins manage users and open or close sign-up`
- [ ] Write the failing spec `spec/models/user/command_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe User::Command, type: :model do
    it "creates an admin named after the email, which ends first run", :aggregate_failures do
      user, created = described_class.call(email: "Owner@Example.test", password: "a long enough secret")
      expect([ created, user.admin?, user.name ]).to eq([ true, true, "owner" ])
      expect(Registration).not_to be_open
    end

    it "resets an existing user's password and ends their sessions" do
      existing = create(:user, email_address: "bo@example.test")
      existing.sessions.create!
      user, created = described_class.call(email: "bo@example.test", password: "a long enough secret")
      expect([ created, user.authenticate("a long enough secret").present?, user.sessions.count ]).to eq([ false, true, 0 ])
    end

    it "refuses a malformed email" do
      expect { described_class.call(email: "not an email", password: "a long enough secret") }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/user/command_spec.rb` — expect: FAIL.
- [ ] Write `app/models/user/command.rb` (`find_or_initialize_by` normalises the email through `normalizes`; a malformed email fails `save!` with `RecordInvalid`):
  ```ruby
  # Operator shell command: set a user's password, or create an admin (spec 004 AC-5.7, AC-3.6).
  class User::Command
    def self.call(email:, password:)
      User.transaction do
        user = User.find_or_initialize_by(email_address: email.to_s.strip.downcase)
        created = user.new_record?
        if created
          user.assign_attributes(name: user.email_address.split("@").first.presence || user.email_address, admin: true)
          InstanceSetting.current.update!(sign_up_open: false)
        end
        user.password = password
        user.save!
        user.end_sessions! unless created
        [ user, created ]
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/user/command_spec.rb` — expect: PASS.
- [ ] Commit: `feat(accounts): set passwords and create admins from the command line`
- [ ] Write the failing task spec `spec/tasks/collector_rake_spec.rb`, and add `"spec/tasks/collector_rake_spec.rb"` to `RSpec/DescribeClass: Exclude:` in `.rubocop.yml` (it describes a rake task). Stdin is stubbed as "not a terminal" by default, so no example ever waits for input:
  ```ruby
  require "rails_helper"
  require "rake"
  require "io/console"

  RSpec::Matchers.define_negated_matcher :not_include, :include

  RSpec.describe "collector:user", type: :task do
    before do
      Rails.application.load_tasks unless Rake::Task.task_defined?("collector:user")
      Rake::Task["collector:user"].reenable
      allow($stdin).to receive(:tty?).and_return(false)
    end

    def run_task(email)
      original_out, original_err = $stdout, $stderr
      $stdout = $stderr = StringIO.new
      Rake::Task["collector:user"].invoke(email)
      $stdout.string
    ensure
      $stdout, $stderr = original_out, original_err
    end

    it "uses COLLECTOR_PASSWORD and never prints it", :aggregate_failures do
      ENV["COLLECTOR_PASSWORD"] = "from the environment"
      output = run_task("owner@example.test")
      expect(User.find_by(email_address: "owner@example.test").authenticate("from the environment")).to be_truthy
      expect(output).to include("Created admin owner@example.test").and not_include("from the environment")
    ensure
      ENV.delete("COLLECTOR_PASSWORD")
    end

    it "prompts for the password in a terminal without echoing it", :aggregate_failures do
      allow($stdin).to receive_messages(tty?: true, noecho: "typed at the prompt\n")
      output = run_task("owner@example.test")
      expect(User.find_by(email_address: "owner@example.test").authenticate("typed at the prompt")).to be_truthy
      expect(output).to include("New password").and not_include("typed at the prompt")
    end

    it "generates and prints a password when none is given and stdin isn't a terminal", :aggregate_failures do
      password = run_task("owner@example.test")[/Password: (\S+)/, 1]
      expect(password.length).to be >= 16
      expect(User.find_by(email_address: "owner@example.test").authenticate(password)).to be_truthy
    end

    it "exits non-zero for a malformed email, creating nobody", :aggregate_failures do
      expect { run_task("nope") }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      expect(User.count).to eq(0)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/tasks/collector_rake_spec.rb` — expect: FAIL.
- [ ] Write `lib/tasks/collector.rake`:
  ```ruby
  namespace :collector do
    desc "Set a user's password, or create an admin with that email (password from COLLECTOR_PASSWORD, a prompt, or generated)"
    task :user, [ :email ] => :environment do |_task, args|
      password = ENV["COLLECTOR_PASSWORD"].presence
      generated = false
      if password.nil? && $stdin.tty?
        require "io/console"
        print "New password (at least #{User::PASSWORD_MINIMUM} characters): "
        password = $stdin.noecho(&:gets).to_s.chomp
        puts
      end
      if password.blank?
        password = SecureRandom.base58(24)
        generated = true
      end

      user, created = User::Command.call(email: args[:email], password:)
      puts created ? "Created admin #{user.email_address}." : "Set a new password for #{user.email_address} and signed them out everywhere."
      puts "Password: #{password}" if generated
    rescue ActiveRecord::RecordInvalid => error
      warn "Could not save #{args[:email].inspect}: #{error.record.errors.full_messages.to_sentence}"
      exit 1
    end
  end
  ```
- [ ] Run: `bin/rspec spec/tasks/collector_rake_spec.rb` — expect: PASS.
- [ ] Commit: `feat(accounts): add the collector:user rake task`
- [ ] Update `README.md` (Phase 11 checks this text):
  - Under `## Self-hosting`, directly after its opening paragraph and before `### Docker Compose`, add:
    ```markdown
    > **Before you expose Collector:** the first person to reach a new or freshly upgraded instance becomes its admin. Either sign up straight away while the instance is only reachable on your private network, or create the admin from the command line first (see [Accounts](#accounts)).
    ```
  - Add these rows to the Compose variable table (columns: Variable, Required, Default, Purpose):
    ```markdown
    | `COLLECTOR_HTTPS`           | no | `false`               | Set to `true` when Collector is served over HTTPS (secure cookies, redirect to HTTPS) |
    | `COLLECTOR_TRUSTED_PROXIES` | no | Rails' private ranges | Extra reverse proxies (IPs or CIDRs, comma-separated) whose `X-Forwarded-For` is trusted |
    | `COLLECTOR_PASSWORD`        | no | none                  | Password for the user command below; never stored in logs                              |
    ```
  - Replace the "**HTTPS:**" bullet with:
    ```markdown
    - **HTTPS:** the Compose setup serves plain HTTP. Signing in over plain HTTP sends your password unencrypted, which is only acceptable on a trusted private network. Put an HTTPS reverse proxy (for example Caddy, nginx, or Traefik) in front of it and set `COLLECTOR_HTTPS=true`.
    ```
  - Add, after the Kamal section:
    ````markdown
    ### Accounts

    Each person has their own account and collection. The first account is the admin: whoever signs up first, or whoever you create with the user command. The admin opens or closes sign-up and manages users under **Users and sign-up** in the avatar menu (or **More** on a phone).

    The user command sets a user's password, or creates an admin if no user has that email. It takes the password from `COLLECTOR_PASSWORD`, or asks for it when run in a terminal, or generates one and prints it once. Setting a password signs that user out everywhere.

    ```sh
    bin/rails "collector:user[you@example.com]"                                                    # locally
    docker compose exec -e COLLECTOR_PASSWORD='…' web bin/rails "collector:user[you@example.com]"  # Docker Compose
    bin/kamal app exec -i "bin/rails 'collector:user[you@example.com]'"                           # Kamal
    ```

    ### Upgrading to accounts

    **Read this before you upgrade.** An instance upgraded from a version without accounts has no users, and the first person to reach it becomes its admin. If others can reach your instance, stop exposing it (for example, take it off your reverse proxy) before you upgrade, or run the user command straight after the upgrade to create your admin. Then sign in, and only then expose it again.

    1. Pull the new code.
    2. Run `docker compose up -d --build` (or `bin/kamal deploy`). Migrations run when the container starts.
    3. Create or claim the admin account as described above.
    ````
- [ ] Commit: `docs(readme): document accounts, the user command and first-run upgrade notes`

---

## Phase 7: Search in the design system, with owned counts and quick add

**Implements:** FR-14, FR-7 (quick add), FR-11 (result group, tile with add, filter-bar select, pagination, empty state) | **Satisfies:** AC-6.1–AC-6.7, AC-7.1–AC-7.6, AC-7.3a (scripting on; the no-script card page follows in Phase 8), AC-12.1 (search), AC-12.5 (request level), AC-1.5 (search)
**Files:** `config/routes.rb`, `spec/routing/routes_spec.rb`, `config/locales/en.yml`, `app/controllers/concerns/card_context.rb`, `app/controllers/application_controller.rb`, `app/controllers/catalog/entries_controller.rb`, `app/controllers/catalog/identities_controller.rb`, `app/controllers/catalog/quick_adds_controller.rb`, `app/helpers/catalog_helper.rb`, `app/views/shared/_status_message.html.erb`, `app/views/layouts/application.html.erb`, `app/views/catalog/entries/index.html.erb`, `app/views/catalog/entries/_group.html.erb`, `app/views/catalog/entries/_tile.html.erb`, `app/views/catalog/identities/show.html.erb`, `app/views/catalog/_pagination.html.erb`; deleted: `app/views/catalog/entries/_summary.html.erb`, `app/views/mtg/printings/_summary.html.erb`; `app/javascript/controllers/search_shortcut_controller.js`, `app/assets/stylesheets/collector/additions.css`, `spec/support/system.rb`, `spec/requests/catalog/entries_search_spec.rb`, `spec/requests/catalog/identities_spec.rb`, `spec/requests/catalog/quick_adds_spec.rb`, `spec/system/catalog_search_spec.rb`, `spec/system/quick_add_spec.rb`
**Interfaces:** Consumes: `Lot.add!`, `Lot.owned_quantities` (Phase 5), `Catalog::Search`, `Current.account`, `layouts/appbar`/`layouts/tabbar` and `icons/*` (Phase 4). Produces:
- route `catalog_entry_quick_add_path(entry)`
- the `CardContext` concern: `card_context` (`:collection` or `:search`), `card_params` (`{ from: "collection" }` or `{}`), and `safe_return_to(fallback)` (Rails' `url_from`, else the fallback)
- `Catalog::QuickAddsController::FULL_LOT`
- helpers `set_number(entry)` (→ `"M10 · 146"`) and `quick_add_button(entry, return_to:)`
- partials `catalog/entries/tile` (locals `entry:`, `owned:`, `return_to:`, `link_params: {}`), `catalog/pagination` (locals `pagination:`, `link_params:`, `frame: nil`) and `shared/status_message` (locals `message:`, `alert: false`)

- [ ] Add the routing example to `spec/routing/routes_spec.rb`:
  ```ruby
  it "routes quick add under a printing" do
    expect(post: "/catalog/entries/abc/quick_add").to route_to("catalog/quick_adds#create", entry_external_key: "abc")
  end
  ```
- [ ] Update `spec/requests/catalog/entries_search_spec.rb` for the new presentation, keeping every 002 behaviour example:
  - Replace Phase 2's `before { sign_in_as(create(:user)) }` with `let(:user) { create(:user) }` and `before { sign_in_as(user) }`.
  - Replace the example "shows image, set, number, language, rarity and finishes for each printing" (002 AC-1.5, superseded by AC-6.2) with:
    ```ruby
    it "shows each printing as a tile with image, name, set · number and language", :aggregate_failures do
      set = create(:catalog_set, code: "m10", name: "Magic 2010")
      entry = printing("Lightning Bolt", set:, number: "146", image_url: "https://cards.scryfall.io/normal/front/a/b/bolt.jpg")
      create(:mtg_printing, entry:)

      search(q: "bolt")

      expect(response.body).to include('src="https://cards.scryfall.io/normal/front/a/b/bolt.jpg"', "M10 · 146", ">EN<",
        %(href="#{catalog_entry_path(entry)}"))
    end
    ```
  - Change these expectations (AC-6.5's new messages; literal ERB text is not HTML-escaped):

    | Example | Old | New |
    |---|---|---|
    | "says no cards were found" | `include("No cards found")` | `include(%(No cards match "nothing matches". Check the spelling or try part of the name.))` |
    | "prompts for a name when the query is blank or whitespace" | `include("Enter a card name")` | `include("Type part of a card name to search.")` |
    | "treats wildcard characters literally" | `include("No cards found")` | `include(%(No cards match "Fire_".))` |
    | "hides tokens, emblems, art cards and retired printings" | `include("No cards found")` | `include(%(No cards match "goblin".))` |
    | "returns no results for an unknown set code" | `include("No cards found")` | `include(%(No cards match "bolt".))` |
    | "says the catalog has not been loaded until a refresh has applied" | `include("has not been loaded yet")` | `include("The card catalog hasn't been loaded yet.")` |
    | "shows the date of the last applied refresh" | `include("September 28, 2026")` | `include("Catalog updated 28 September 2026")` |
  - Add:
    ```ruby
    it "shows owned quantities and fades printings you don't own", :aggregate_failures do
      owned = printing("Lightning Bolt")
      create(:lot, account: user.account, entry: owned, quantity: 3)
      create(:lot, entry: owned, quantity: 7) # someone else's copies
      unowned = printing("Lightning Bolt", identity: owned.identity, language: "ja")

      search(q: "bolt")

      expect(response.body).to include(">×3<")
      expect(response.body).not_to include(">×7<", ">×10<")
      expect(response.body).to match(/class="c-tile c-tile--owned-none" href="#{Regexp.escape(catalog_entry_path(unowned))}"/)
    end

    it "counts matching cards on the line under the filter bar" do
      printing("Lightning Bolt")
      search(q: "bolt")
      expect(response.body).to match(%r{<div class="c-results__meta"><span class="c-filterbar__count">1 card</span>})
    end

    it "puts each add button outside its tile link, named for what it adds", :aggregate_failures do
      entry = printing("Lightning Bolt", set: create(:catalog_set, code: "m10"), number: "146")
      search(q: "bolt")
      html = Nokogiri::HTML(response.body)
      expect(html.css("a.c-tile form, a.c-tile button")).to be_empty
      expect(html.at_css("##{ActionView::RecordIdentifier.dom_id(entry, :tile)} button")["aria-label"]).to eq("Add 1 × Lightning Bolt (M10 · 146)")
    end
    ```
- [ ] Update `spec/requests/catalog/identities_spec.rb`: replace Phase 2's `before { sign_in_as(create(:user)) }` with `let(:user) { create(:user) }` and `before { sign_in_as(user) }`, and add (AC-6.6):
  ```ruby
  it "shows owned quantities and an add control on each printing", :aggregate_failures do
    entry = create(:catalog_entry, identity: forest, number: "7", set: create(:catalog_set, code: "abc"))
    create(:lot, account: user.account, entry:, quantity: 2)

    get catalog_identity_path(forest)

    expect(response.body).to include(">×2<", 'aria-label="Add 1 × Forest (ABC · 7)"')
  end
  ```
  Its other examples keep working: the tiles still link with `href="/catalog/entries/…"`, and the breadcrumb's `/catalog/entries?q=Forest` doesn't match that pattern.
- [ ] Write `spec/requests/catalog/quick_adds_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Quick add", type: :request do
    let(:user) { create(:user) }
    let(:entry) { create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt", number: "146") } }
    let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

    before { sign_in_as(user) }

    it "adds one copy with nothing else specified and returns to the page", :aggregate_failures do
      return_to = catalog_entries_path(q: "bolt")
      post catalog_entry_quick_add_path(entry), params: { return_to: }
      expect(response).to redirect_to(return_to)
      expect(response).to have_http_status(:see_other)
      expect(user.account.lots.sole).to have_attributes(quantity: 1, finish: nil, condition: nil, price_paid_cents: nil)
      follow_redirect!
      expect(response.body).to include("Added 1 × Lightning Bolt (#{entry.set.code.upcase} · 146) to your collection.")
    end

    it "merges two quick adds into one lot" do
      2.times { post catalog_entry_quick_add_path(entry) }
      expect(user.account.lots.sole.quantity).to eq(2)
    end

    it "ignores return paths that aren't on this instance", :aggregate_failures do
      post catalog_entry_quick_add_path(entry), params: { return_to: "https://evil.example/x" }
      expect(response).to redirect_to(catalog_entry_path(entry))
      post catalog_entry_quick_add_path(entry), params: { return_to: "//evil.example/x" }
      expect(response).to redirect_to(catalog_entry_path(entry))
    end

    it "answers an over-cap add with scripting on by updating only the status region", :aggregate_failures do
      create(:lot, account: user.account, entry:, quantity: 9_999)
      post catalog_entry_quick_add_path(entry), headers: turbo
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="status">',
        "You already have the most copies one lot can hold (9,999).")
      expect(user.account.lots.sole.quantity).to eq(9_999)
    end

    it "answers an over-cap add without scripting with 422 and the message", :aggregate_failures do
      create(:lot, account: user.account, entry:, quantity: 9_999)
      post catalog_entry_quick_add_path(entry)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("You already have the most copies one lot can hold (9,999).")
    end

    it "returns 404 for an unknown printing" do
      post catalog_entry_quick_add_path("nope")
      expect(response).to have_http_status(:not_found)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/requests/catalog` — expect: FAIL.
- [ ] Add the route: inside `namespace :catalog` in `config/routes.rb`, give `resources :entries` a block:
  ```ruby
  resources :entries, only: %i[index show], param: :external_key do
    resource :quick_add, only: :create
  end
  ```
- [ ] Replace `config/locales/en.yml` (adds the long date format "28 September 2026"):
  ```yaml
  en:
    activerecord:
      attributes:
        user:
          email_address: "Email"
    date:
      formats:
        long: "%-d %B %Y"
  ```
- [ ] Write `app/controllers/concerns/card_context.rb` and add `include CardContext` to `ApplicationController`:
  ```ruby
  # Where the collector came from (spec 004 AC-8.9, FR-13): collection links carry from=collection;
  # everything else is Search. Return paths are followed only when they're on this instance (AC-7.3).
  module CardContext
    extend ActiveSupport::Concern

    included { helper_method :card_context, :card_params }

    private
      def card_context = params[:from] == "collection" ? :collection : :search

      def card_params = card_context == :collection ? { from: "collection" } : {}

      def safe_return_to(fallback) = url_from(params[:return_to]) || fallback
  end
  ```
- [ ] Write `app/views/shared/_status_message.html.erb`, and use it in the layout's `#status` div in place of the inline `<p>`:
  ```erb
  <%# locals: (message:, alert: false) %>
  <p class="c-status__message<%= " c-status__message--alert" if alert %>"><%= message %></p>
  ```
  `app/views/layouts/application.html.erb`:
  ```erb
  <div id="status" class="c-status" role="status" aria-live="polite"><% if (message = flash[:notice] || flash[:alert]) %><%= render "shared/status_message", message:, alert: flash[:alert].present? %><% end %></div>
  ```
- [ ] Write `app/controllers/catalog/quick_adds_controller.rb`:
  ```ruby
  # Adds one copy of a printing with nothing else specified (spec 004 Story 7).
  class Catalog::QuickAddsController < ApplicationController
    FULL_LOT = "You already have the most copies one lot can hold (9,999).".freeze

    def create
      @entry = Catalog::Entry.find_by!(external_key: params[:entry_external_key])
      Lot.add!(account: Current.account, entry: @entry)
      redirect_to safe_return_to(catalog_entry_path(@entry, **card_params)), status: :see_other,
        notice: "Added 1 × #{@entry.name} (#{helpers.set_number(@entry)}) to your collection."
    rescue ActiveRecord::RecordInvalid
      respond_to do |format|
        # Scripting on (AC-7.3a): show the message and leave the page as it is.
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("status", partial: "shared/status_message", locals: { message: FULL_LOT, alert: true }),
            status: :unprocessable_entity
        end
        format.html { render_full_lot }
      end
    end

    private
      # Replaced in Phase 8 by the card page rendered at 422.
      def render_full_lot = render(plain: FULL_LOT, status: :unprocessable_entity)
  end
  ```
- [ ] Update `Catalog::EntriesController#index` and `Catalog::IdentitiesController#show` to load owned quantities:
  ```ruby
  # entries#index, after @groups:
  @owned = Lot.owned_quantities(Current.account, @groups.flat_map(&:entries).map(&:id))
  # identities#show, after @entries:
  @owned = Lot.owned_quantities(Current.account, @entries.map(&:id))
  ```
- [ ] Add to `app/helpers/catalog_helper.rb` (keep `catalog_url` and `render_catalog_extension`):
  ```ruby
  def set_number(entry) = "#{entry.set.code.upcase} · #{entry.number}"

  def quick_add_button(entry, return_to:, label: "Add")
    button_to catalog_entry_quick_add_path(entry), params: { return_to: }, class: "c-btn c-btn--ghost c-btn--sm",
      form: { class: "c-tile__add", data: { turbo_frame: "_top" } },
      "aria-label": "Add 1 × #{entry.name} (#{set_number(entry)})" do
      safe_join([ render("icons/plus"), label ])
    end
  end
  ```
- [ ] Write `app/views/catalog/entries/_tile.html.erb`:
  ```erb
  <%# locals: (entry:, owned:, return_to:, link_params: {}) %>
  <div class="c-tilecell" id="<%= dom_id(entry, :tile) %>">
    <%= link_to catalog_entry_path(entry, **link_params), class: class_names("c-tile", "c-tile--owned-none": owned.to_i.zero?) do %>
      <div class="c-tile__media">
        <% if (image = catalog_url(entry.image_url)) %>
          <%= image_tag image, alt: entry.name, loading: "lazy", width: 146, height: 204 %>
        <% else %>
          <div class="c-tile__missing"><strong><%= entry.name %></strong><span><%= set_number(entry) %></span></div>
        <% end %>
        <% if owned.to_i.positive? %><span class="c-tile__qty">×<%= owned %></span><% end %>
      </div>
      <div class="c-tile__name"><%= entry.localized_name || entry.name %></div>
      <div class="c-tile__meta"><span class="c-tag"><%= set_number(entry) %></span><span class="c-tag"><%= entry.language.upcase %></span></div>
    <% end %>
    <%= quick_add_button(entry, return_to:) %>
  </div>
  ```
  Delete `app/views/catalog/entries/_summary.html.erb` and `app/views/mtg/printings/_summary.html.erb`; their content moves to the card page (002 AC-1.5 is superseded).
- [ ] Write `app/views/catalog/entries/_group.html.erb`:
  ```erb
  <%# locals: (group:, owned:, set_code:, return_to:) %>
  <section class="c-group" aria-labelledby="<%= dom_id(group.identity, :heading) %>">
    <div class="c-section__head">
      <h2 class="c-section__title" id="<%= dom_id(group.identity, :heading) %>"><%= group.identity.name %></h2>
      <span class="c-section__count"><%= pluralize(group.total_entries, "printing") %></span>
      <% if group.total_entries > group.entries.size %>
        <span class="c-section__actions"><%= link_to "Show all #{group.total_entries} printings", catalog_identity_path(group.identity, set: set_code), class: "c-btn c-btn--ghost c-btn--sm" %></span>
      <% end %>
    </div>
    <div class="c-grid">
      <% group.entries.each do |entry| %>
        <%= render "catalog/entries/tile", entry:, owned: owned[entry.id], return_to: %>
      <% end %>
    </div>
  </section>
  ```
- [ ] Rewrite `app/views/catalog/entries/index.html.erb`. The results frame has `target="_top"`, so tile and "Show all" links load the whole page; the filter form and the pager target the frame:
  ```erb
  <% content_for :title, "Search · Collector" %>
  <%= render "layouts/appbar", section: :search %>
  <main class="c-main">
    <div class="c-pagehead"><div><h1 class="c-pagehead__title">Search</h1></div></div>
    <div class="c-collection" data-controller="search-shortcut">
      <%= form_with url: catalog_entries_path, method: :get, class: "c-filterbar", role: "search",
            data: { turbo_frame: "results", turbo_action: "advance" } do |form| %>
        <label class="c-input"><%= render "icons/search" %><%= form.search_field :q, value: @search.query, placeholder: "Lightning Bolt", "aria-label": "Card name",
              data: { search_shortcut_target: "input" } %><kbd>/</kbd></label>
        <div class="c-filterbar__filters">
          <label class="c-select"><span class="c-sr">Set</span><%= form.select :set,
                options_for_select(@sets.map { |set| [ "#{set.name} (#{set.code.upcase})", set.code ] }, @search.set_code),
                include_blank: "All sets" %></label>
          <%= form.submit "Search", name: nil, class: "c-btn c-btn--secondary c-btn--sm" %>
        </div>
      <% end %>

      <turbo-frame id="results" target="_top" data-turbo-action="advance">
        <div class="c-results__meta"><% if @search.active? %><span class="c-filterbar__count"><%= pluralize(@search.pagination.total_count, "card") %></span><% end %><% if @last_refresh %><span class="c-results__freshness">Catalog updated <%= l(@last_refresh.finished_at.to_date, format: :long) %></span><% end %></div>
        <% if @last_refresh.nil? %>
          <p class="c-status__message c-status__message--alert">The card catalog hasn't been loaded yet.</p>
        <% end %>
        <% if !@search.active? %>
          <p class="c-empty">Type part of a card name to search.</p>
        <% elsif @groups.empty? %>
          <p class="c-empty">No cards match "<%= @search.query %>". Check the spelling or try part of the name.</p>
        <% else %>
          <% @groups.each do |group| %>
            <%= render "catalog/entries/group", group:, owned: @owned, set_code: @search.set_code, return_to: request.fullpath %>
          <% end %>
          <%= render "catalog/pagination", pagination: @search.pagination, link_params: { q: @search.query.presence, set: @search.set_code }, frame: "results" %>
        <% end %>
      </turbo-frame>
    </div>
  </main>
  <%= render "layouts/tabbar", section: :search %>
  ```
  The not-loaded notice (002 AC-1.11) shows above whatever else the frame renders, as in 002.
- [ ] Rewrite `app/views/catalog/identities/show.html.erb`. "Show all sets" sits under the stats line, because `c-pagehead__actions` hides on phones:
  ```erb
  <% content_for :title, "#{@identity.name} printings · Collector" %>
  <%= render "layouts/appbar", section: :search %>
  <main class="c-main">
    <ol class="c-crumbs"><li><%= link_to "Search", catalog_entries_path(q: @identity.name) %></li><li><%= @identity.name %></li></ol>
    <div class="c-pagehead">
      <div>
        <h1 class="c-pagehead__title"><%= @identity.name %></h1>
        <p class="c-pagehead__stats"><%= pluralize(@pagination.total_count, "printing") %></p>
        <% if @set_code %><%= link_to "Show all sets", catalog_identity_path(@identity), class: "c-btn c-btn--ghost c-btn--sm" %><% end %>
      </div>
    </div>
    <div class="c-collection">
      <div class="c-grid">
        <% @entries.each do |entry| %>
          <%= render "catalog/entries/tile", entry:, owned: @owned[entry.id], return_to: request.fullpath %>
        <% end %>
      </div>
      <%= render "catalog/pagination", pagination: @pagination, link_params: { set: @set_code } %>
    </div>
  </main>
  <%= render "layouts/tabbar", section: :search %>
  ```
- [ ] Rewrite `app/views/catalog/_pagination.html.erb` (`frame:` makes the links update a results frame in place; `data: { turbo_frame: nil }` renders no attribute):
  ```erb
  <%# locals: (pagination:, link_params:, frame: nil) %>
  <% if pagination.total_pages > 1 %>
    <nav class="c-pager" aria-label="Pagination">
      <% if pagination.previous_page %>
        <%= link_to "Previous", url_for(link_params.compact.merge(page: pagination.previous_page)), rel: "prev", class: "c-btn c-btn--secondary c-btn--sm", data: { turbo_frame: frame } %>
      <% end %>
      <span class="c-pager__position">Page <%= pagination.page %> of <%= pagination.total_pages %></span>
      <% if pagination.next_page %>
        <%= link_to "Next", url_for(link_params.compact.merge(page: pagination.next_page)), rel: "next", class: "c-btn c-btn--secondary c-btn--sm", data: { turbo_frame: frame } %>
      <% end %>
    </nav>
  <% end %>
  ```
- [ ] Write `app/javascript/controllers/search_shortcut_controller.js`:
  ```js
  import { Controller } from "@hotwired/stimulus"

  // "/" focuses the search field unless you're already typing somewhere (spec 004 AC-6.7).
  export default class extends Controller {
    static targets = ["input"]

    connect() {
      this.onKeydown = this.onKeydown.bind(this)
      document.addEventListener("keydown", this.onKeydown)
    }

    disconnect() {
      document.removeEventListener("keydown", this.onKeydown)
    }

    onKeydown(event) {
      const typing = event.target.closest("input, textarea, select, [contenteditable]")
      if (event.key !== "/" || typing || event.metaKey || event.ctrlKey || event.altKey) return
      event.preventDefault()
      this.inputTarget.focus()
    }
  }
  ```
- [ ] Append to `additions.css`:
  ```css
  /* ---------- Search result group: card heading + tile grid ---------- */
  .c-group { display:flex; flex-direction:column; gap:var(--space-2); margin-top:var(--space-6); }
  .c-results__meta { display:flex; flex-wrap:wrap; gap:var(--space-3); padding:var(--space-2) 0; }
  .c-results__freshness { font:400 12px/16px var(--font-sans); color:var(--ink-muted); }

  /* ---------- Tile with an add control outside its link ---------- */
  .c-tilecell { display:flex; flex-direction:column; gap:var(--space-1); min-width:0; }
  .c-tile__add { display:flex; }
  .c-tile__add .c-btn { width:100%; justify-content:flex-start; }

  /* ---------- Select inside the filter bar ---------- */
  .c-select select { height:28px; max-width:220px; padding:0 var(--space-2); background:var(--surface-raised); color:var(--ink);
    border:1px solid var(--line-strong); border-radius:var(--radius-md); font:400 13px/18px var(--font-sans); }
  .c-select select:focus-visible { outline:2px solid var(--focus); outline-offset:2px; }
  @media (pointer: coarse) { .c-select select { min-height:40px; } }

  /* ---------- Pagination ---------- */
  .c-pager { display:flex; align-items:center; justify-content:center; gap:var(--space-3); margin:var(--space-6) 0; }
  .c-pager__position { font:400 13px/18px var(--font-mono); color:var(--ink-muted); }

  /* ---------- Empty state ---------- */
  .c-empty { margin:var(--space-6) 0; padding:var(--space-6); text-align:center; background:var(--surface-sunken);
    border-radius:var(--radius-md); font:400 15px/22px var(--font-sans); color:var(--ink); }
  ```
- [ ] The search field is now labelled by `aria-label` (the design system's `c-input` pattern), so add `Capybara.enable_aria_label = true` to `spec/support/system.rb`. Then update `spec/system/catalog_search_spec.rb`:
  - `have_css("h2", text: "Lightning Bolt")` becomes `have_css(".c-group h2", text: "Lightning Bolt")`.
  - `click_on "Lightning Bolt"` becomes `click_link "Lightning Bolt"`, because the tile's Add button is also named after the card.
- [ ] Run: `bin/rspec spec/routing spec/requests spec/system` — expect: PASS.
- [ ] Commit: `feat(search): restyle search with owned counts and quick add`
- [ ] Write the system spec `spec/system/quick_add_spec.rb` (AC-6.1 in-place update, AC-7.2, AC-7.3a with scripting, AC-6.7, and AC-1.5 for search). The 360px example uses its own driver name, so Capybara really opens a 360px window:
  ```ruby
  require "rails_helper"

  RSpec.describe "Quick add from search", type: :system do
    let!(:entry) { create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt") } }
    let(:tile) { "##{ActionView::RecordIdentifier.dom_id(entry, :tile)}" }

    before { create(:catalog_refresh_run) }

    it "adds a copy without reloading the page and announces it", :aggregate_failures do
      system_sign_in_as(create(:user))
      visit catalog_entries_path(q: "bolt")
      page.execute_script("window.__marker = 'still here'")
      within(tile) { click_button "Add" }

      expect(page).to have_css("[role=status]", text: "Added 1 × Lightning Bolt")
      expect(page).to have_css("#{tile} .c-tile__qty", text: "×1")
      expect(page.evaluate_script("window.__marker")).to eq("still here")
      expect(page).to have_current_path(catalog_entries_path(q: "bolt"))
    end

    it "shows the over-cap message in place", :aggregate_failures do
      user = system_sign_in_as(create(:user))
      create(:lot, account: user.account, entry:, quantity: 9_999)
      visit catalog_entries_path(q: "bolt")
      page.execute_script("window.__marker = 'still here'")
      within(tile) { click_button "Add" }

      expect(page).to have_css("[role=status]", text: "You already have the most copies one lot can hold (9,999).")
      expect(page).to have_current_path(catalog_entries_path(q: "bolt"))
      expect(page.evaluate_script("window.__marker")).to eq("still here")
    end

    it "updates results in place and focuses search with /", :aggregate_failures do
      system_sign_in_as(create(:user))
      visit catalog_entries_path
      page.execute_script("window.__marker = 'still here'")
      find("body").send_keys("/")
      expect(page).to have_css("input[name=q]:focus")
      fill_in "Card name", with: "bolt"
      click_button "Search"
      expect(page).to have_css(".c-group h2", text: "Lightning Bolt")
      expect(page).to have_current_path(catalog_entries_path(q: "bolt", set: ""))
      expect(page.evaluate_script("window.__marker")).to eq("still here")
    end

    it "fits a 360px screen without horizontal scrolling" do
      driven_by :selenium, using: :headless_firefox, screen_size: [ 360, 800 ], options: { name: :firefox_360 }
      system_sign_in_as(create(:user))
      visit catalog_entries_path(q: "bolt")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/quick_add_spec.rb` — expect: PASS.
- [ ] Commit: `test(search): cover quick add in the browser and the narrow layout`

---

## Phase 8: The card page

**Implements:** FR-9, FR-11 (details list, single stat), FR-7 (quick add from Printings) | **Satisfies:** AC-8.1–AC-8.10, AC-6.5 (the card page parts of 002 AC-3.x), AC-2.3 (card page from the collection), AC-2.7, AC-7.3a (no-script card page), AC-12.1 (card page)
**Files:** `config/routes.rb`, `app/models/catalog/card_overview.rb`, `app/models/mtg/mana_cost.rb`, `app/models/mtg/legality.rb`, `app/helpers/mtg_helper.rb`, `app/controllers/catalog/entries_controller.rb`, `app/controllers/catalog/quick_adds_controller.rb`, `app/views/catalog/entries/show.html.erb`, `app/views/catalog/entries/{_copies,_printings,_finish_badge}.html.erb`, `app/views/mtg/printings/{_head,_details,_legality}.html.erb`, `app/assets/stylesheets/collector/additions.css`, `spec/models/catalog/card_overview_spec.rb`, `spec/models/mtg/mana_cost_spec.rb`, `spec/requests/catalog/entries_show_spec.rb`, `spec/requests/catalog/quick_adds_spec.rb`, `spec/system/card_page_spec.rb`
**Interfaces:** Consumes: `Lot`, `Catalog.collecting_for` (Phase 5), `CardContext`, `set_number`, `quick_add_button`, `shared/status_message`, `Catalog::QuickAddsController::FULL_LOT` (Phase 7), `layouts/appbar` with `detail:`/`back_path:` and `icons/{plus,more,check,cross,star}` (Phase 4). Produces:
- `Catalog::CardOverview.new(account:, entry:)` with `#lots` (`Lot`s with their entry and set, newest printing first), `#owned_count`, `#printings_owned`, `#rows` (`[Row(entry, owned, shown)]`), `#total_printings`, `#identity`, `#entry` and `#vocabulary`
- `MTG::ManaCost.new(cost)` with `#pips` (`[MTG::ManaCost::Pip(text, css, label, pip?)]`) and `#label`
- `MTG::Legality.rows(legalities)` and `MTG::Legality.word(status)`
- the `mana_cost_tag(cost, large: false)` helper
- the `catalog/entries/finish_badge` partial (local `label:`), reused by Phase 10
- routes `new_catalog_entry_lot_path(entry)`, `catalog_entry_lots_path(entry)`, `edit_lot_path(lot)`, `lot_path(lot)` and `new_lot_removal_path(lot)`

- [ ] Write the failing spec `spec/models/mtg/mana_cost_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe MTG::ManaCost, type: :model do
    it "reads each symbol aloud in printed order", :aggregate_failures do
      expect(described_class.new("{1}{R}{R}").label).to eq("Mana cost: 1 generic, 1 red, 1 red")
      expect(described_class.new("{X}{C}{W}{U}{B}{G}").label).to eq("Mana cost: X, 1 colourless, 1 white, 1 blue, 1 black, 1 green")
    end

    it "shows undesigned symbols as text tags", :aggregate_failures do
      cost = described_class.new("{W/U}{G/P}{S}")
      expect(cost.pips.map(&:pip?)).to eq([ false, false, false ])
      expect(cost.label).to eq("Mana cost: white or blue, Phyrexian green, snow")
    end

    it "is empty for a blank cost" do
      expect(described_class.new(nil).pips).to eq([])
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/mana_cost_spec.rb` — expect: FAIL.
- [ ] Write `app/models/mtg/mana_cost.rb`:
  ```ruby
  # Parses a Scryfall mana cost into Collector's own pips (spec 004 AC-8.3). Hybrid, Phyrexian and
  # snow symbols aren't designed yet, so they render as text tags (pip? false).
  class MTG::ManaCost
    COLOURS = { "W" => "white", "U" => "blue", "B" => "black", "R" => "red", "G" => "green" }.freeze
    Pip = Data.define(:text, :css, :label, :pip?)

    attr_reader :pips

    def initialize(cost)
      @pips = cost.to_s.scan(/\{([^}]+)\}/).flatten.map { |raw| pip_for(raw) }
    end

    def label = "Mana cost: #{pips.map(&:label).join(', ')}"

    private
      def pip_for(raw)
        case raw
        when /\A\d+\z/ then Pip.new(text: raw, css: "c-mana", label: "#{raw} generic", pip?: true)
        when "X" then Pip.new(text: "X", css: "c-mana", label: "X", pip?: true)
        when "C" then Pip.new(text: "C", css: "c-mana", label: "1 colourless", pip?: true)
        when *COLOURS.keys then Pip.new(text: raw, css: "c-mana c-mana--#{raw.downcase}", label: "1 #{COLOURS[raw]}", pip?: true)
        when "S" then Pip.new(text: "{S}", css: "c-tag", label: "snow", pip?: false)
        when %r{\A(.)/P\z} then Pip.new(text: "{#{raw}}", css: "c-tag", label: "Phyrexian #{COLOURS.fetch(Regexp.last_match(1), Regexp.last_match(1))}", pip?: false)
        else
          parts = raw.split("/").map { |part| COLOURS.fetch(part, part) }
          Pip.new(text: "{#{raw}}", css: "c-tag", label: parts.join(" or "), pip?: false)
        end
      end
  end
  ```
  and `app/helpers/mtg_helper.rb`:
  ```ruby
  module MTGHelper
    def mana_cost_tag(cost, large: false)
      mana = MTG::ManaCost.new(cost)
      return if mana.pips.empty?

      tag.span(class: class_names("c-cost", "c-cost--lg": large), role: "img", "aria-label": mana.label) do
        safe_join(mana.pips.map { |pip| tag.span(pip.text, class: pip.css, "aria-hidden": "true") })
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/mtg/mana_cost_spec.rb` — expect: PASS.
- [ ] Commit: `feat(mtg): render mana costs as Collector pips with spoken labels`
- [ ] Write the failing spec `spec/models/catalog/card_overview_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe Catalog::CardOverview, type: :model do
    let(:account) { create(:user).account }
    let(:identity) { create(:catalog_identity, name: "Lightning Bolt") }

    def printing(released_on, **attributes)
      create(:mtg_printing, entry: create(:catalog_entry, identity:, released_on:, **attributes)).entry
    end

    it "counts copies and printings owned across the whole card", :aggregate_failures do
      a, b = printing(Date.new(2020, 1, 1)), printing(Date.new(2021, 1, 1))
      create(:lot, account:, entry: a, quantity: 3)
      create(:lot, account:, entry: b, quantity: 4, finish: "foil")
      create(:lot, entry: a, quantity: 9) # another account
      overview = described_class.new(account:, entry: a)
      expect([ overview.owned_count, overview.printings_owned, overview.lots.size ]).to eq([ 7, 2, 2 ])
    end

    it "lists the shown printing, then owned ones, then the 10 newest others", :aggregate_failures do
      old = printing(Date.new(1993, 1, 1))
      owned_retired = printing(Date.new(1994, 1, 1), retired_at: 1.day.ago)
      create(:lot, account:, entry: owned_retired)
      newest = (1..12).map { |i| printing(Date.new(2000 + i, 1, 1)) }

      rows = described_class.new(account:, entry: old).rows
      expect(rows.first).to have_attributes(entry: old, shown: true)
      expect(rows.second).to have_attributes(entry: owned_retired, owned: 1)
      expect(rows.drop(2).map(&:entry)).to eq(newest.reverse.first(10))
      expect(described_class.new(account:, entry: old).total_printings).to eq(13)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/card_overview_spec.rb` — expect: FAIL.
- [ ] Write `app/models/catalog/card_overview.rb`:
  ```ruby
  # What an account holds of one card, seen from one of its printings (spec 004 AC-8.4, AC-8.5, AC-8.7).
  class Catalog::CardOverview
    NEWEST = 10
    Row = Data.define(:entry, :owned, :shown)

    attr_reader :entry

    def initialize(account:, entry:)
      @account, @entry = account, entry
    end

    def identity = entry.identity
    def vocabulary = Catalog.collecting_for(entry.collectible_type)

    def lots
      @lots ||= @account.lots.joins(:entry).where(catalog_entries: { catalog_identity_id: identity.id })
        .includes(entry: :set).merge(Catalog::Entry.newest_first).order(:finish, :condition, :price_paid_cents).to_a
    end

    def owned_count = lots.sum(&:quantity)
    def printings_owned = lots.map(&:catalog_entry_id).uniq.size
    def total_printings = @total_printings ||= identity.entries.searchable.count

    def rows
      @rows ||= begin
        owned = lots.group_by(&:catalog_entry_id).transform_values { |group| group.sum(&:quantity) }
        owned_entries = Catalog::Entry.where(id: owned.keys).where.not(id: entry.id).newest_first.includes(:set).to_a
        listed = [ entry.id, *owned_entries.map(&:id) ]
        newest = identity.entries.searchable.where.not(id: listed).newest_first.includes(:set).limit(NEWEST).to_a
        [ entry, *owned_entries, *newest ].map { |row_entry| Row.new(entry: row_entry, owned: owned.fetch(row_entry.id, 0), shown: row_entry == entry) }
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/catalog/card_overview_spec.rb` — expect: PASS.
- [ ] Commit: `feat(collection): summarise an account's copies and printings of a card`
- [ ] Replace `spec/requests/catalog/entries_show_spec.rb`. It keeps 002's examples (Scryfall ID addressing, every attribute, escaping, Scryfall link and attribution, retired notice, 404, no outbound requests) with their expectations moved to the new markup, and adds the card page's own:
  ```ruby
  require "rails_helper"

  RSpec.describe "Card page", type: :request do
    let(:user) { create(:user) }
    let(:set) { create(:catalog_set, code: "neo", name: "Kamigawa: Neon Dynasty", released_on: Date.new(2022, 2, 18)) }
    let(:identity) { create(:catalog_identity, name: "Azusa's Many Journeys // Likeness of the Seeker") }
    let(:entry) do
      create(:catalog_entry, external_key: "ec725e92", set:, identity:, number: "172", language: "ja",
        localized_name: "梓の幾多の旅 // 探求者の肖像", released_on: Date.new(2022, 2, 18))
    end

    before do
      create(:mtg_printing, entry:, rarity: "uncommon", finishes: %w[foil nonfoil],
        scryfall_uri: "https://scryfall.com/card/neo/172/ja/azusa",
        legalities: { "modern" => "legal", "standard" => "not_legal", "alchemy" => "legal" },
        faces: [
          { "name" => "Azusa's Many Journeys", "printed_name" => "梓の幾多の旅", "mana_cost" => "{1}{G}",
            "type_line" => "Enchantment — Saga", "oracle_text" => "Chapter one", "artist" => "Lindsey Look",
            "image_uris" => { "large" => "https://cards.scryfall.io/large/front/e/c/ec725e92.jpg" } },
          { "name" => "Likeness of the Seeker", "printed_name" => "探求者の肖像", "mana_cost" => "",
            "type_line" => "Enchantment Creature — Human Monk", "oracle_text" => "<script>x</script>Blocked",
            "artist" => "Lindsey Look", "image_uris" => { "large" => "https://cards.scryfall.io/large/back/e/c/ec725e92.jpg" } }
        ])
      sign_in_as(user)
    end

    it "is addressed by the Scryfall ID and shows everything about the printing", :aggregate_failures do
      get "/catalog/entries/ec725e92"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        "Azusa&#39;s Many Journeys // Likeness of the Seeker", "梓の幾多の旅 // 探求者の肖像",
        "Kamigawa: Neon Dynasty", "NEO · 172", ">JA<", "Uncommon", "Nonfoil, Foil", "18 February 2022",
        'aria-label="Mana cost: 1 generic, 1 green"', "Enchantment — Saga", "Chapter one", "Enchantment Creature — Human Monk",
        "Lindsey Look // Lindsey Look", "https://cards.scryfall.io/large/front/e/c/ec725e92.jpg",
        "https://cards.scryfall.io/large/back/e/c/ec725e92.jpg")
    end

    it "escapes source text" do
      get catalog_entry_path(entry)

      expect(response.body).not_to include("<script>x</script>")
    end

    it "links to Scryfall with attribution, to the card's printings and back to search" do
      get catalog_entry_path(entry)

      expect(response.body).to include('href="https://scryfall.com/card/neo/172/ja/azusa"', "provided by Scryfall",
        catalog_identity_path(identity), %(<li><a href="#{catalog_entries_path}">Search</a></li>))
    end

    it "renders a retired printing with a notice", :aggregate_failures do
      entry.update!(retired_at: 1.day.ago)

      get catalog_entry_path(entry)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("no longer present in the upstream source")
    end

    it "returns 404 for an unknown Scryfall ID" do
      get "/catalog/entries/does-not-exist"

      expect(response).to have_http_status(:not_found)
    end

    it "makes no outbound requests while rendering" do
      get catalog_entry_path(entry)

      expect(a_request(:any, /.*/)).not_to have_been_made
    end

    it "shows the sections in order and only the listed paper formats", :aggregate_failures do
      get catalog_entry_path(entry)

      body = response.body
      order = [ "c-item__image", "c-item__title", "c-chip--cards", "c-rules", "c-details", "<dt>Owned</dt>", "Your copies",
        %(<h2 class="c-section__title">Printings</h2>), "Format legality" ]
      expect(order.map { |marker| body.index(marker) }).to eq(order.map { |marker| body.index(marker) }.sort)
      expect(body).to include("Magic: The Gathering", "Legal", "Not legal", "Standard", "Modern", "Premodern")
      expect(body).not_to include("Alchemy")
    end

    it "counts owned copies across printings and lists lots", :aggregate_failures do
      other = create(:mtg_printing, entry: create(:catalog_entry, identity:)).entry
      create(:lot, account: user.account, entry:, quantity: 3, condition: "near_mint", price_paid_cents: 125)
      create(:lot, account: user.account, entry: other, quantity: 4, finish: "foil")

      get catalog_entry_path(entry)

      expect(response.body).to include("<dd>7</dd>", "2 printings", "7 in 2 lots", "NM", "$1.25", "Foil", "Edit copy", "Remove")
    end

    it "shows the empty copies state with an add action" do
      get catalog_entry_path(entry)
      expect(response.body).to include("You don't have this card yet.", "Add a copy")
    end

    it "lists the shown printing, owned retired printings and a link to all printings", :aggregate_failures do
      retired = create(:catalog_entry, identity:, retired_at: 1.day.ago, set: create(:catalog_set, code: "old"), number: "9")
      create(:lot, account: user.account, entry: retired)

      get catalog_entry_path(entry)

      printings = response.body[%r{<section id="printings">.*?</section>}m]
      expect(printings).to include(%(NEO · 172</span><span class="c-tag">Shown</span>), "OLD · 9", "· Retired", "×1")
      expect(printings).to include("Show all 1 printings", %(href="#{catalog_identity_path(identity)}"))
    end

    it "starts the breadcrumb and section from the collection only when marked", :aggregate_failures do
      get catalog_entry_path(entry, from: "collection")
      expect(response.body).to include(%(<li><a href="#{collection_path}">Collection</a></li>),
        %(aria-current="page" href="#{collection_path}">Collection</a>))
      expect(response.body[%r{<nav class="c-tabbar".*?</nav>}m]).to include(%(aria-current="page" href="#{collection_path}">))

      get catalog_entry_path(entry)
      expect(response.body).to include(%(<li><a href="#{catalog_entries_path}">Search</a></li>),
        %(aria-current="page" href="#{catalog_entries_path}">Search</a>))
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/catalog/entries_show_spec.rb` — expect: FAIL.
- [ ] Write `app/models/mtg/legality.rb`:
  ```ruby
  # Paper formats shown on a card page, in order (spec 004 AC-8.8).
  module MTG::Legality
    FORMATS = %w[standard pioneer modern legacy vintage pauper commander oathbreaker premodern].freeze
    WORDS = { "legal" => "Legal", "not_legal" => "Not legal", "banned" => "Banned", "restricted" => "Restricted" }.freeze

    def self.rows(legalities) = FORMATS.map { |format| [ format.titleize, legalities.fetch(format, "not_legal") ] }
    def self.word(status) = WORDS.fetch(status, "Not legal")
  end
  ```
- [ ] Add the lots routes the card page links to (their controllers and routing example arrive in Phase 9) to `config/routes.rb`, below `namespace :catalog`:
  ```ruby
  scope "catalog/entries/:entry_external_key", as: :catalog_entry do
    resources :lots, only: %i[new create]
  end
  resources :lots, only: %i[edit update destroy] do
    resource :removal, only: :new, module: :lots
  end
  ```
- [ ] Update `Catalog::EntriesController#show`:
  ```ruby
  def show
    @entry = Catalog::Entry.includes(:set, :identity).find_by!(external_key: params[:external_key])
    Catalog::Entry.preload_extensions([ @entry ])
    @overview = Catalog::CardOverview.new(account: Current.account, entry: @entry)
  end
  ```
- [ ] Write `app/views/catalog/entries/show.html.erb`:
  ```erb
  <% content_for :title, "#{@entry.name} · Collector" %>
  <% crumb_path = card_context == :collection ? collection_path : catalog_entries_path %>
  <%= render "layouts/appbar", section: card_context, detail: true, back_path: crumb_path %>
  <main class="c-main c-page">
    <ol class="c-crumbs">
      <li><%= link_to(card_context == :collection ? "Collection" : "Search", crumb_path) %></li>
      <li><%= @overview.vocabulary.category_name %></li>
      <li><%= @entry.name %></li>
    </ol>
    <% if @entry.retired? %>
      <p class="c-status__message c-status__message--alert">This printing is no longer present in the upstream source.</p>
    <% end %>
    <div class="c-item">
      <div class="c-item__media">
        <% faces = @entry.extension&.faces.presence || [ { "image_uris" => { "normal" => @entry.image_url }, "name" => @entry.name } ] %>
        <% faces.each do |face| %>
          <div class="c-item__image">
            <% if (image = catalog_url(face.dig("image_uris", "large") || face.dig("image_uris", "normal"))) %>
              <%= image_tag image, alt: face["name"], width: 300, height: 419 %>
            <% else %>
              <div class="c-tile__missing"><strong><%= face["name"] %></strong></div>
            <% end %>
          </div>
        <% end %>
        <p class="c-item__caption">Showing <%= set_number(@entry) %> · <%= @entry.language.upcase %></p>
      </div>
      <div class="c-item__body">
        <div class="c-item__head">
          <div>
            <h1 class="c-item__title"><%= @entry.name %></h1>
            <p class="c-item__type"><span class="c-chip c-chip--cards"><span class="c-chip__dot"></span><%= @overview.vocabulary.category_name %></span></p>
          </div>
          <div class="c-item__actions">
            <%= link_to new_catalog_entry_lot_path(@entry, **card_params), class: "c-btn c-btn--primary" do %><%= render "icons/plus" %>Add a copy<% end %>
            <% if (scryfall = catalog_url(@entry.extension&.scryfall_uri)) %>
              <details class="c-menu" data-controller="menu">
                <summary class="c-btn c-btn--secondary c-btn--icon" aria-label="More actions"><%= render "icons/more" %></summary>
                <div class="c-menu__list"><%= link_to "View on Scryfall", scryfall, class: "c-menu__item", rel: "noopener" %></div>
              </details>
            <% end %>
          </div>
        </div>
        <%= render_catalog_extension @entry, :head %>
        <%= render_catalog_extension @entry, :details %>
        <dl class="c-stats c-stats--single">
          <div class="c-stat"><dt>Owned</dt><dd><%= number_with_delimiter(@overview.owned_count) %></dd><small><%= pluralize(@overview.printings_owned, "printing") %></small></div>
        </dl>
        <%= render "catalog/entries/copies", overview: @overview %>
        <%= render "catalog/entries/printings", overview: @overview %>
        <%= render_catalog_extension @entry, :legality %>
        <p class="c-attribution">Card data and images provided by Scryfall.</p>
      </div>
    </div>
  </main>
  <%= render "layouts/tabbar", section: card_context %>
  ```
- [ ] Write the MTG partials. `app/views/mtg/printings/_head.html.erb` (type line, cost and rules, per face):
  ```erb
  <% extension.faces.each do |face| %>
    <section class="c-face">
      <% if extension.faces.size > 1 %><h2 class="c-section__title"><%= face["name"] %></h2><% end %>
      <p class="c-item__type"><%= face["type_line"] %> <%= mana_cost_tag(face["mana_cost"], large: true) %></p>
      <% if face["oracle_text"].present? %><div class="c-rules"><%= simple_format(h(face["oracle_text"])) %></div><% end %>
    </section>
  <% end %>
  ```
  `app/views/mtg/printings/_details.html.erb` (replaces 002's):
  ```erb
  <% entry = extension.entry %>
  <dl class="c-details">
    <div><dt>Set</dt><dd><%= entry.set.name %> <span class="c-tag"><%= set_number(entry) %></span></dd></div>
    <div><dt>Language</dt><dd class="is-data"><%= entry.language.upcase %></dd></div>
    <% if entry.localized_name %><div><dt>Printed name</dt><dd lang="<%= entry.language %>"><%= entry.localized_name %></dd></div><% end %>
    <div><dt>Rarity</dt><dd><%= extension.rarity.humanize %></dd></div>
    <div><dt>Finishes</dt><dd><%= MTG::Collecting.finishes_for(entry).map { |finish| MTG::Collecting.finish_label(finish) }.join(", ") %></dd></div>
    <div><dt>Released</dt><dd><%= entry.released_on ? l(entry.released_on, format: :long) : "Unknown" %></dd></div>
    <div><dt><%= extension.faces.size > 1 ? "Artists" : "Artist" %></dt><dd><%= extension.faces.map { |face| face["artist"] }.compact.join(" // ") %></dd></div>
  </dl>
  ```
  `app/views/mtg/printings/_legality.html.erb`:
  ```erb
  <section>
    <div class="c-section__head"><h2 class="c-section__title">Format legality</h2></div>
    <ul class="c-legality">
      <% MTG::Legality.rows(extension.legalities).each do |format, status| %>
        <li><span><%= format %></span>
          <% if status == "legal" %>
            <span class="c-legal c-legal--yes"><%= render "icons/check" %><%= MTG::Legality.word(status) %></span>
          <% else %>
            <span class="c-legal c-legal--no"><%= render "icons/cross" %><%= MTG::Legality.word(status) %></span>
          <% end %>
        </li>
      <% end %>
    </ul>
  </section>
  ```
- [ ] Write `app/views/catalog/entries/_copies.html.erb`:
  ```erb
  <section id="copies">
    <div class="c-section__head">
      <h2 class="c-section__title">Your copies</h2>
      <% if overview.lots.any? %><span class="c-section__count"><%= overview.owned_count %> in <%= pluralize(overview.lots.size, "lot") %></span><% end %>
    </div>
    <% if overview.lots.empty? %>
      <p class="c-empty">You don't have this card yet. <%= link_to "Add a copy", new_catalog_entry_lot_path(overview.entry, **card_params) %></p>
    <% else %>
      <div class="c-collection">
        <table class="c-table">
          <thead><tr><th>Printing</th><th class="is-opt">Finish</th><th class="is-opt">Condition</th><th class="is-opt">Language</th><th class="is-num">Qty</th><th class="is-num is-opt">Paid</th><th><span class="c-sr">Actions</span></th></tr></thead>
          <tbody>
            <% overview.lots.each do |lot| %>
              <% vocab = overview.vocabulary %>
              <% finish = lot.finish && (vocab.special_finishes.include?(lot.finish) ? render("catalog/entries/finish_badge", label: vocab.finish_label(lot.finish)) : tag.span(vocab.finish_label(lot.finish), class: "is-muted")) %>
              <% condition = lot.condition ? vocab.conditions.fetch(lot.condition).last : "—" %>
              <tr>
                <td><div class="c-table__item"><div><span class="is-data"><%= set_number(lot.entry) %></span>
                  <span class="c-table__sub"><%= safe_join([ (lot.finish ? vocab.finish_label(lot.finish) : nil), condition, lot.entry.language.upcase ].compact, " · ") %></span></div></div></td>
                <td class="is-opt"><%= finish || "—" %></td>
                <td class="is-data is-opt"><%= condition %></td>
                <td class="is-data is-opt"><%= lot.entry.language.upcase %></td>
                <td class="is-num"><%= lot.quantity %></td>
                <td class="is-num is-opt"><%= lot.price_paid ? number_to_currency(lot.price_paid, unit: Rails.configuration.x.currency.symbol) : "—" %></td>
                <td class="c-table__actions">
                  <details class="c-menu" data-controller="menu">
                    <summary class="c-btn c-btn--ghost c-btn--sm c-btn--icon" aria-label="Actions for <%= set_number(lot.entry) %> <%= condition %>"><%= render "icons/more" %></summary>
                    <div class="c-menu__list">
                      <%= link_to "Edit copy", edit_lot_path(lot, **card_params), class: "c-menu__item" %>
                      <div class="c-menu__sep"></div>
                      <%= link_to "Remove", new_lot_removal_path(lot, **card_params), class: "c-menu__item c-menu__item--danger" %>
                    </div>
                  </details>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
  </section>
  ```
  and `app/views/catalog/entries/_finish_badge.html.erb`:
  ```erb
  <span class="c-badge c-badge--foil"><%= render "icons/star" %><%= label %></span>
  ```
- [ ] Write `app/views/catalog/entries/_printings.html.erb`:
  ```erb
  <section id="printings">
    <div class="c-section__head">
      <h2 class="c-section__title">Printings</h2>
      <span class="c-section__count"><%= overview.total_printings %> known · <%= overview.printings_owned %> owned</span>
      <% if overview.total_printings.positive? %>
        <span class="c-section__actions"><%= link_to "Show all #{overview.total_printings} printings", catalog_identity_path(overview.identity), class: "c-btn c-btn--ghost c-btn--sm" %></span>
      <% end %>
    </div>
    <ul class="c-list">
      <% overview.rows.each do |row| %>
        <li class="<%= "is-unowned" if row.owned.zero? %>">
          <% if row.shown %>
            <span class="is-data"><%= set_number(row.entry) %></span><span class="c-tag">Shown</span>
          <% else %>
            <%= link_to set_number(row.entry), catalog_entry_path(row.entry, **card_params), class: "is-data" %>
          <% end %>
          <span class="c-list__meta"><%= row.entry.set.name %> · <%= row.entry.language.upcase %><%= " · Retired" if row.entry.retired? %></span>
          <span class="c-list__end">
            <% if row.owned.positive? %>×<%= row.owned %><% else %><%= quick_add_button(row.entry, return_to: catalog_entry_path(overview.entry, **card_params)) %><% end %>
          </span>
        </li>
      <% end %>
    </ul>
  </section>
  ```
  (The quick-add return path is the card page itself, not `request.fullpath`, because this page is also rendered at 422 by the quick-add `POST`.)
- [ ] Append to `additions.css`:
  ```css
  /* ---------- Card page: details list, single stat, faces, attribution ---------- */
  .c-details { display:grid; grid-template-columns:repeat(auto-fill, minmax(180px, 1fr)); gap:var(--space-3) var(--space-4); margin:0; }
  .c-details dt { font:600 12px/16px var(--font-sans); color:var(--ink-muted); }
  .c-details dd { margin:var(--space-1) 0 0; font:400 14px/20px var(--font-sans); color:var(--ink); }
  .c-details .is-data { font-family:var(--font-mono); }
  .c-stats--single { grid-template-columns:minmax(0, 1fr); max-width:240px; }
  .c-face { display:flex; flex-direction:column; gap:var(--space-2); }
  .c-list li.is-unowned { color:var(--ink-muted); }
  .c-list .c-tile__add .c-btn { width:auto; }
  .c-attribution { margin:0; font:400 12px/16px var(--font-sans); color:var(--ink-muted); }
  @container page (max-width: 639px) { .c-stats--single { grid-template-columns:minmax(0, 1fr); max-width:none; } }
  ```
- [ ] In `spec/requests/catalog/quick_adds_spec.rb`, make the no-script over-cap example check that it's the card page (AC-7.3a):
  ```ruby
  it "answers an over-cap add without scripting with the card page at 422", :aggregate_failures do
    create(:lot, account: user.account, entry:, quantity: 9_999)
    post catalog_entry_quick_add_path(entry)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("You already have the most copies one lot can hold (9,999).", "Your copies", "9999")
  end
  ```
  (It replaces Phase 7's "answers an over-cap add without scripting with 422 and the message".)
- [ ] Replace `render_full_lot` in `Catalog::QuickAddsController` so the no-script answer is the card page at 422:
  ```ruby
  def render_full_lot
    flash.now[:alert] = FULL_LOT
    Catalog::Entry.preload_extensions([ @entry ])
    @overview = Catalog::CardOverview.new(account: Current.account, entry: @entry)
    render "catalog/entries/show", status: :unprocessable_entity
  end
  ```
  and delete its "Replaced in Phase 8" comment.
- [ ] Run: `bin/rspec spec/requests spec/system` — expect: PASS.
- [ ] Commit: `feat(card): add the card page with copies, printings and legality`
- [ ] Write the system spec `spec/system/card_page_spec.rb` (AC-8.10, AC-2.7). The phone example uses its own driver name, so the 390px window really opens:
  ```ruby
  require "rails_helper"

  RSpec.describe "Card page", type: :system do
    let(:entry) { create(:mtg_printing).entry }

    it "keeps the image in view while scrolling on a wide screen" do
      system_sign_in_as(create(:user))
      visit catalog_entry_path(entry)
      expect(page.evaluate_script("getComputedStyle(document.querySelector('.c-item__media')).position")).to eq("sticky")
    end

    it "shows a back link to search instead of the logo on a phone", :aggregate_failures do
      driven_by :selenium, using: :headless_firefox, screen_size: [ 390, 844 ], options: { name: :firefox_390 }
      system_sign_in_as(create(:user))
      visit catalog_entry_path(entry)
      expect(page).to have_link("Back", href: catalog_entries_path)
      expect(page).to have_no_css(".c-appbar__brand", visible: :visible)
      expect(page).to have_no_css(".c-appbar__add", visible: :visible)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/card_page_spec.rb` — expect: PASS.
- [ ] Commit: `test(card): cover the sticky image and phone header`

---

## Phase 9: Add a copy, edit and remove lots

**Implements:** FR-7 (form), FR-8 | **Satisfies:** AC-9.1–AC-9.5, AC-10.1–AC-10.5, AC-12.2, AC-12.3 (lots)
**Files:** `spec/routing/routes_spec.rb`, `app/controllers/lots_controller.rb`, `app/controllers/lots/removals_controller.rb`, `app/models/lot/form.rb`, `app/helpers/lots_helper.rb`, `app/views/lots/{new,edit,_form}.html.erb`, `app/views/lots/removals/new.html.erb`, `spec/requests/lots_spec.rb`, `spec/system/card_page_spec.rb`
**Interfaces:** Consumes: the lots routes (added in Phase 8), `Lot.add!`, `Lot#revise!`, `Lot::MAX_QUANTITY` (Phase 5), `CardContext`, `set_number` (Phase 7), `layouts/appbar`/`layouts/tabbar` (Phase 4). Produces:
- `Lot::Form` (an ActiveModel with `entry`, `quantity`, `finish`, `condition` and `price_paid`; `.from(lot)`, `#lot_attributes`, `#absorb(lot)` and `#vocabulary`), which validates each field itself and reports per-field errors
- the `lot_error_messages(form, field)` helper

- [ ] Add the routing example to `spec/routing/routes_spec.rb` (the routes exist since Phase 8; the example fails until the controllers do):
  ```ruby
  it "routes adding and managing copies", :aggregate_failures do
    expect(get: "/catalog/entries/abc/lots/new").to route_to("lots#new", entry_external_key: "abc")
    expect(post: "/catalog/entries/abc/lots").to route_to("lots#create", entry_external_key: "abc")
    expect(get: "/lots/1/edit").to route_to("lots#edit", id: "1")
    expect(patch: "/lots/1").to route_to("lots#update", id: "1")
    expect(delete: "/lots/1").to route_to("lots#destroy", id: "1")
    expect(get: "/lots/1/removal/new").to route_to("lots/removals#new", lot_id: "1")
  end
  ```
- [ ] Write the failing request spec `spec/requests/lots_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Lots", type: :request do
    let(:user) { create(:user) }
    let(:entry) { create(:mtg_printing, finishes: %w[nonfoil foil]).entry.tap { |e| e.update!(name: "Lightning Bolt", number: "146") } }
    let(:added) { "Lightning Bolt (#{entry.set.code.upcase} · 146)" }

    before { sign_in_as(user) }

    describe "adding" do
      it "offers only the printing's finishes and the condition scale", :aggregate_failures do
        get new_catalog_entry_lot_path(entry)
        expect(response.body).to include("Nonfoil", "Foil", "Near mint (NM)", "Damaged (DMG)", "Price paid per copy (USD)")
        expect(response.body).not_to include("Etched")
      end

      it "doesn't offer a finish when the printing lists none" do
        get new_catalog_entry_lot_path(create(:mtg_printing, finishes: []).entry)
        expect(response.body).not_to include('name="lot[finish]"')
      end

      it "adds copies with details and returns to the card page", :aggregate_failures do
        post catalog_entry_lots_path(entry), params: { lot: { quantity: "2", finish: "foil", condition: "near_mint", price_paid: "4.00" } }
        expect(response).to redirect_to(catalog_entry_path(entry))
        expect(user.account.lots.sole).to have_attributes(quantity: 2, finish: "foil", condition: "near_mint", price_paid_cents: 400)
        follow_redirect!
        expect(response.body).to include("Added 2 × #{added} to your collection.")
      end

      it "rejects invalid values with a message per field", :aggregate_failures do
        post catalog_entry_lots_path(entry), params: { lot: { quantity: "0", finish: "etched", condition: "mint", price_paid: "1.234" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Quantity must be a whole number from 1 to 9,999", "Finish isn&#39;t available for this printing",
          "Condition isn&#39;t a known condition", "Price paid must be a non-negative amount with at most two decimal places")
        expect(Lot.count).to eq(0)
      end

      it "reads quantities in base 10" do
        post catalog_entry_lots_path(entry), params: { lot: { quantity: "010" } }
        expect(user.account.lots.sole.quantity).to eq(10)
      end

      it "refuses an add that would push a lot past 9,999", :aggregate_failures do
        create(:lot, account: user.account, entry:, quantity: 9_998)
        post catalog_entry_lots_path(entry), params: { lot: { quantity: "2" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("One lot can hold at most 9,999 copies.")
      end

      it "ignores account values in submissions" do
        other = create(:user).account
        post catalog_entry_lots_path(entry), params: { lot: { quantity: "1", account_id: other.id } }
        expect(Lot.sole.account).to eq(user.account)
      end
    end

    describe "editing" do
      let(:lot) { create(:lot, account: user.account, entry:, quantity: 3, condition: "near_mint") }

      it "prefills the form and saves valid values", :aggregate_failures do
        get edit_lot_path(lot)
        expect(response.body).to include('value="3"', '<option selected="selected" value="near_mint">')
        patch lot_path(lot), params: { lot: { quantity: "4", finish: "foil", condition: "near_mint", price_paid: "" } }
        expect(response).to redirect_to(catalog_entry_path(entry))
        expect(lot.reload.slice(:quantity, :finish).values).to eq([ 4, "foil" ])
        follow_redirect!
        expect(response.body).to include("Saved.")
      end

      it "rejects invalid values with 422 and leaves the lot unchanged", :aggregate_failures do
        patch lot_path(lot), params: { lot: { quantity: "lots", finish: "", condition: "", price_paid: "-1" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Quantity must be a whole number from 1 to 9,999", "Price paid must be a non-negative amount")
        expect(lot.reload.quantity).to eq(3)
      end

      it "merges into a matching lot", :aggregate_failures do
        foil = create(:lot, account: user.account, entry:, finish: "foil")
        plain = create(:lot, account: user.account, entry:, quantity: 2)
        patch lot_path(plain), params: { lot: { quantity: "2", finish: "foil", condition: "", price_paid: "" } }
        expect(response).to redirect_to(catalog_entry_path(entry))
        expect(foil.reload.quantity).to eq(3)
        expect(Lot.exists?(plain.id)).to be(false)
      end

      it "refuses a merge that would pass 9,999 copies", :aggregate_failures do
        foil = create(:lot, account: user.account, entry:, finish: "foil", quantity: 9_000)
        plain = create(:lot, account: user.account, entry:, quantity: 1_000)
        patch lot_path(plain), params: { lot: { quantity: "1000", finish: "foil", condition: "", price_paid: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("One lot can hold at most 9,999 copies.")
        expect([ foil.reload.quantity, plain.reload.finish ]).to eq([ 9_000, nil ])
      end
    end

    describe "removing" do
      it "confirms on its own page, then reports what was removed", :aggregate_failures do
        lot = create(:lot, account: user.account, entry:, quantity: 3)
        get new_lot_removal_path(lot)
        expect(response.body).to include("Remove 3 × Lightning Bolt?", %(action="#{lot_path(lot)}"))
        expect(response.body).to match(%r{<button[^>]*class="c-btn c-btn--danger"[^>]*>Remove</button>})
        delete lot_path(lot)
        follow_redirect!
        expect(response.body).to include("Removed 3 × #{added} from your collection.", "You don't have this card yet.")
      end

      it "keeps the collection context" do
        lot = create(:lot, account: user.account, entry:)
        delete lot_path(lot, from: "collection")
        expect(response).to redirect_to(catalog_entry_path(entry, from: "collection"))
      end
    end

    context "with another account's lot" do
      let(:foreign) { create(:lot, entry:, quantity: 5) }

      it "returns 404 for its edit form, update, removal page and removal", :aggregate_failures do
        get edit_lot_path(foreign)
        expect(response).to have_http_status(:not_found)
        patch lot_path(foreign), params: { lot: { quantity: "1" } }
        expect(response).to have_http_status(:not_found)
        get new_lot_removal_path(foreign)
        expect(response).to have_http_status(:not_found)
        delete lot_path(foreign)
        expect(response).to have_http_status(:not_found)
        expect(foreign.reload.quantity).to eq(5)
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/requests/lots_spec.rb` — expect: FAIL.
- [ ] Write `app/models/lot/form.rb`. It validates every field itself, including the collectible's finishes and conditions, so a bad quantity doesn't hide the other messages (AC-9.4):
  ```ruby
  # Parses the add/edit form's text fields into lot attributes with per-field errors (spec 004 AC-9.4).
  class Lot::Form
    include ActiveModel::Model
    include ActiveModel::Attributes

    PRICE = /\A\d+(\.\d{1,2})?\z/

    attribute :quantity, :string, default: "1"
    attribute :finish, :string
    attribute :condition, :string
    attribute :price_paid, :string
    attr_accessor :entry

    validate :quantity_in_range, :price_well_formed, :finish_offered, :condition_known

    def self.from(lot)
      new(entry: lot.entry, quantity: lot.quantity.to_s, finish: lot.finish, condition: lot.condition, price_paid: lot.price_paid)
    end

    def vocabulary = Catalog.collecting_for(entry.collectible_type)

    def lot_attributes
      { quantity: parsed_quantity, finish: finish.presence, condition: condition.presence,
        price_paid_cents: price_paid.present? ? (BigDecimal(price_paid.strip) * 100).to_i : nil }
    end

    # Copies model errors (for example the 9,999 cap on a merge) onto the form's fields.
    def absorb(lot)
      lot.errors.each do |error|
        field = error.attribute == :price_paid_cents ? :price_paid : error.attribute
        errors.add(field, error.message) if attribute_names.include?(field.to_s)
      end
      self
    end

    private
      def parsed_quantity = Integer(quantity.to_s.strip, 10, exception: false)

      def quantity_in_range
        errors.add(:quantity, "must be a whole number from 1 to 9,999") unless parsed_quantity&.between?(1, Lot::MAX_QUANTITY)
      end

      def price_well_formed
        return if price_paid.blank? || price_paid.strip.match?(PRICE)

        errors.add(:price_paid, "must be a non-negative amount with at most two decimal places")
      end

      def finish_offered
        errors.add(:finish, "isn't available for this printing") if finish.present? && vocabulary.finishes_for(entry).exclude?(finish)
      end

      def condition_known
        errors.add(:condition, "isn't a known condition") if condition.present? && vocabulary.conditions.exclude?(condition)
      end
  end
  ```
- [ ] Write `app/helpers/lots_helper.rb`. The model's cap message ("One lot can hold at most 9,999 copies.") is a whole sentence, so it mustn't get the "Quantity" prefix that `full_message` adds; every other message is a fragment and needs it:
  ```ruby
  module LotsHelper
    def lot_error_messages(form, field)
      form.errors.where(field).map { |error| error.message.match?(/\A[A-Z]/) ? error.message : error.full_message }
    end
  end
  ```
- [ ] Write `app/controllers/lots_controller.rb`:
  ```ruby
  class LotsController < ApplicationController
    before_action :set_entry, only: %i[new create]
    before_action :set_lot, only: %i[edit update destroy]

    def new
      @form = Lot::Form.new(entry: @entry)
    end

    def create
      @form = Lot::Form.new(**lot_params.to_h.symbolize_keys, entry: @entry)
      return render(:new, status: :unprocessable_entity) unless @form.valid?

      Lot.add!(account: Current.account, entry: @entry, **@form.lot_attributes)
      redirect_to catalog_entry_path(@entry, **card_params), status: :see_other,
        notice: "Added #{@form.lot_attributes[:quantity]} × #{@entry.name} (#{helpers.set_number(@entry)}) to your collection."
    rescue ActiveRecord::RecordInvalid => error
      @form.absorb(error.record)
      render :new, status: :unprocessable_entity
    end

    def edit
      @form = Lot::Form.from(@lot)
    end

    def update
      @form = Lot::Form.new(**lot_params.to_h.symbolize_keys, entry: @lot.entry)
      return render(:edit, status: :unprocessable_entity) unless @form.valid?

      @lot.revise!(@form.lot_attributes)
      redirect_to catalog_entry_path(@lot.entry, **card_params), status: :see_other, notice: "Saved."
    rescue ActiveRecord::RecordInvalid
      @form.absorb(@lot)
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @lot.destroy!
      redirect_to catalog_entry_path(@lot.entry, **card_params), status: :see_other,
        notice: "Removed #{@lot.quantity} × #{@lot.entry.name} (#{helpers.set_number(@lot.entry)}) from your collection."
    end

    private
      def set_entry = @entry = Catalog::Entry.includes(:set).find_by!(external_key: params[:entry_external_key])

      def set_lot = @lot = Current.account.lots.includes(entry: :set).find(params[:id])

      def lot_params = params.expect(lot: %i[quantity finish condition price_paid])
  end
  ```
  (`Lot#revise!` always raises with its errors on the receiver, so `update` absorbs `@lot`.)
- [ ] Write `app/controllers/lots/removals_controller.rb`:
  ```ruby
  # The no-script confirmation page for removing a lot (spec 004 AC-10.5).
  class Lots::RemovalsController < ApplicationController
    def new
      @lot = Current.account.lots.includes(entry: :set).find(params[:lot_id])
    end
  end
  ```
- [ ] Write `app/views/lots/_form.html.erb`:
  ```erb
  <%# locals: (form_model:, url:, method:, submit:) %>
  <% entry = form_model.entry %>
  <% vocab = form_model.vocabulary %>
  <% finishes = vocab.finishes_for(entry) %>
  <%= form_with model: form_model, scope: :lot, url:, method:, class: "c-form" do |form| %>
    <div class="c-field<%= " c-field--invalid" if form_model.errors[:quantity].any? %>">
      <%= form.label :quantity, "Quantity", class: "c-field__label" %>
      <label class="c-input"><%= form.number_field :quantity, min: 1, max: Lot::MAX_QUANTITY, step: 1, inputmode: "numeric", required: true %></label>
      <% lot_error_messages(form_model, :quantity).each do |message| %><p class="c-field__error"><%= message %></p><% end %>
    </div>
    <% if finishes.any? %>
      <div class="c-field<%= " c-field--invalid" if form_model.errors[:finish].any? %>">
        <%= form.label :finish, "Finish", class: "c-field__label" %>
        <%= form.select :finish, finishes.map { |finish| [ vocab.finish_label(finish), finish ] }, include_blank: "Not specified" %>
        <% lot_error_messages(form_model, :finish).each do |message| %><p class="c-field__error"><%= message %></p><% end %>
      </div>
    <% end %>
    <div class="c-field<%= " c-field--invalid" if form_model.errors[:condition].any? %>">
      <%= form.label :condition, "Condition", class: "c-field__label" %>
      <%= form.select :condition, vocab.conditions.map { |value, (label, short)| [ "#{label} (#{short})", value ] }, include_blank: "Not specified" %>
      <% lot_error_messages(form_model, :condition).each do |message| %><p class="c-field__error"><%= message %></p><% end %>
    </div>
    <div class="c-field<%= " c-field--invalid" if form_model.errors[:price_paid].any? %>">
      <%= form.label :price_paid, "Price paid per copy (#{Rails.configuration.x.currency.code})", class: "c-field__label" %>
      <label class="c-input"><span aria-hidden="true"><%= Rails.configuration.x.currency.symbol %></span><%= form.text_field :price_paid, inputmode: "decimal", placeholder: "1.25" %></label>
      <p class="c-field__hint">Optional.</p>
      <% lot_error_messages(form_model, :price_paid).each do |message| %><p class="c-field__error"><%= message %></p><% end %>
    </div>
    <div class="c-form__actions">
      <%= form.submit submit, class: "c-btn c-btn--primary" %>
      <%= link_to "Cancel", catalog_entry_path(entry, **card_params), class: "c-btn c-btn--secondary" %>
    </div>
  <% end %>
  ```
  `app/views/lots/new.html.erb`:
  ```erb
  <% content_for :title, "Add #{@entry.name} · Collector" %>
  <%= render "layouts/appbar", section: card_context, detail: true, back_path: catalog_entry_path(@entry, **card_params) %>
  <main class="c-main c-page">
    <h1 class="c-pagehead__title">Add <%= @entry.name %></h1>
    <p class="c-pagehead__stats"><%= set_number(@entry) %> · <%= @entry.language.upcase %></p>
    <%= render "lots/form", form_model: @form, url: catalog_entry_lots_path(@entry, **card_params), method: :post, submit: "Add to collection" %>
  </main>
  <%= render "layouts/tabbar", section: card_context %>
  ```
  `app/views/lots/edit.html.erb`:
  ```erb
  <% content_for :title, "Edit #{@lot.entry.name} · Collector" %>
  <%= render "layouts/appbar", section: card_context, detail: true, back_path: catalog_entry_path(@lot.entry, **card_params) %>
  <main class="c-main c-page">
    <h1 class="c-pagehead__title">Edit copy</h1>
    <p class="c-pagehead__stats"><%= @lot.entry.name %> · <%= set_number(@lot.entry) %> · <%= @lot.entry.language.upcase %></p>
    <%= render "lots/form", form_model: @form, url: lot_path(@lot, **card_params), method: :patch, submit: "Save" %>
  </main>
  <%= render "layouts/tabbar", section: card_context %>
  ```
  `app/views/lots/removals/new.html.erb`:
  ```erb
  <% content_for :title, "Remove copies · Collector" %>
  <%= render "layouts/appbar", section: card_context, detail: true, back_path: catalog_entry_path(@lot.entry, **card_params) %>
  <main class="c-main">
    <section class="c-confirm">
      <h1 class="c-pagehead__title">Remove <%= @lot.quantity %> × <%= @lot.entry.name %>?</h1>
      <p><%= set_number(@lot.entry) %> · <%= @lot.entry.language.upcase %>. This removes the whole lot from your collection.</p>
      <div class="c-form__actions">
        <%= button_to "Remove", lot_path(@lot, **card_params), method: :delete, class: "c-btn c-btn--danger" %>
        <%= link_to "Cancel", catalog_entry_path(@lot.entry, **card_params), class: "c-btn c-btn--secondary" %>
      </div>
    </section>
  </main>
  <%= render "layouts/tabbar", section: card_context %>
  ```
- [ ] Run: `bin/rspec spec/routing/routes_spec.rb spec/requests/lots_spec.rb spec/requests/catalog` — expect: PASS.
- [ ] Commit: `feat(collection): add copies with details, and edit or remove lots`
- [ ] AC-9.5: the export's `@container page (max-width: 639px)` rule already makes `.c-item__actions .c-btn--primary` full width, with the "…" menu beside it. Add this line to the phone example ("shows a back link to search instead of the logo on a phone") in `spec/system/card_page_spec.rb`:
  ```ruby
  expect(page.evaluate_script("document.querySelector('.c-item__actions .c-btn--primary').getBoundingClientRect().width")).to be > 200
  ```
- [ ] Run: `bin/rspec spec/system/card_page_spec.rb` — expect: PASS.
- [ ] Commit: `test(card): check the full-width add action on phones`

---

## Phase 10: The collection grid

**Implements:** FR-10 | **Satisfies:** AC-11.1–AC-11.9, AC-12.1 (collection), AC-1.5 (collection)
**Files:** `app/models/collection_grid.rb`, `app/controllers/collections_controller.rb`, `app/views/collections/{show,_tile}.html.erb`, `app/views/catalog/entries/_finish_badge.html.erb` (reused), `spec/models/collection_grid_spec.rb`, `spec/requests/collections_spec.rb`, `spec/system/collection_spec.rb`
**Interfaces:** Consumes: `Lot` (Phase 5), `Catalog::Pagination`, `Catalog::Search::MAX_QUERY_LENGTH`, `Catalog::Entry.named_like`/`.newest_first` (feature 002), `Catalog.collecting_for` (Phase 5), `catalog_url`, `set_number`, the `catalog/pagination` partial with `frame:` (Phase 7), `catalog/entries/finish_badge` (Phase 8), `layouts/appbar`/`layouts/tabbar` (Phase 4). Produces: `CollectionGrid.new(account:, query:, page:)` with `#tiles` (`[Tile(entry, quantity, special_finishes)]`), `#pagination`, `#total_quantity`, `#matching_quantity`, `#unique_cards`, `#filtered?`, `#empty_collection?`.

- [ ] Write the failing spec `spec/models/collection_grid_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe CollectionGrid, type: :model do
    let(:account) { create(:user).account }

    def own(name, quantity: 1, finish: nil, released_on: Date.new(2020, 1, 1), **entry_attributes)
      identity = Catalog::Identity.find_by(name:) || create(:catalog_identity, name:)
      entry = create(:mtg_printing, finishes: %w[nonfoil foil etched],
        entry: create(:catalog_entry, identity:, name:, released_on:, **entry_attributes)).entry
      create(:lot, account:, entry:, quantity:, finish:)
      entry
    end

    it "makes one tile per printing with summed quantity and one finish label", :aggregate_failures do
      entry = own("Lightning Bolt", quantity: 2)
      create(:lot, account:, entry:, finish: "foil")
      create(:lot, account:, entry:, finish: "etched")
      tile = described_class.new(account:, query: nil, page: nil).tiles.sole
      expect([ tile.quantity, tile.special_finishes ]).to eq([ 4, %w[foil etched] ])
    end

    it "orders by name, then newest printing", :aggregate_failures do
      own("Opt")
      old = own("Lightning Bolt", released_on: Date.new(1993, 1, 1))
      new = own("Lightning Bolt", released_on: Date.new(2021, 1, 1))
      expect(described_class.new(account:, query: nil, page: nil).tiles.map(&:entry)).to eq([ new, old, Catalog::Entry.find_by(name: "Opt") ])
    end

    it "filters by name and reports whole-collection counts", :aggregate_failures do
      own("Lightning Bolt", quantity: 3)
      own("Opt", quantity: 2)
      grid = described_class.new(account:, query: "BOLT", page: nil)
      expect([ grid.tiles.size, grid.matching_quantity, grid.total_quantity, grid.unique_cards ]).to eq([ 1, 3, 5, 2 ])
    end

    it "keeps retired printings and pages at 120", :aggregate_failures do
      own("Lightning Bolt", retired_at: 1.day.ago)
      expect(described_class.new(account:, query: nil, page: nil).tiles.size).to eq(1)
      expect(described_class::PER_PAGE).to eq(120)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/models/collection_grid_spec.rb` — expect: FAIL.
- [ ] Write `app/models/collection_grid.rb`:
  ```ruby
  # One page of an account's collection as image tiles: one per owned printing (spec 004 Story 11).
  class CollectionGrid
    PER_PAGE = 120
    Tile = Data.define(:entry, :quantity, :special_finishes)

    attr_reader :query

    def initialize(account:, query:, page:)
      @account = account
      @query = query.to_s.strip.first(Catalog::Search::MAX_QUERY_LENGTH)
      @requested_page = page
    end

    def filtered? = query.present?
    def empty_collection? = total_quantity.zero?
    def total_quantity = @total_quantity ||= @account.lots.sum(:quantity)
    def matching_quantity = @matching_quantity ||= matching_lots.sum(:quantity)

    def unique_cards
      @unique_cards ||= @account.lots.joins(:entry).distinct.count("catalog_entries.catalog_identity_id")
    end

    def pagination
      @pagination ||= Catalog::Pagination.for(total_count: matching_lots.distinct.count(:catalog_entry_id),
        requested_page: @requested_page, per_page: PER_PAGE)
    end

    def tiles
      @tiles ||= begin
        rows = matching_lots.group(:catalog_entry_id)
          .order(Catalog::Entry.arel_table[:name].asc).merge(Catalog::Entry.newest_first)
          .offset(pagination.offset).limit(PER_PAGE)
          .pluck(:catalog_entry_id, Arel.sql("SUM(lots.quantity)"), Arel.sql("GROUP_CONCAT(DISTINCT lots.finish)"))
        entries = Catalog::Entry.includes(:set).where(id: rows.map(&:first)).index_by(&:id)
        rows.map do |entry_id, quantity, finishes|
          entry = entries.fetch(entry_id)
          special = Catalog.collecting_for(entry.collectible_type).special_finishes & finishes.to_s.split(",")
          Tile.new(entry:, quantity:, special_finishes: special)
        end
      end
    end

    private
      def matching_lots
        scope = @account.lots.joins(:entry)
        filtered? ? scope.merge(Catalog::Entry.named_like(query)) : scope
      end
  end
  ```
  Note: `matching_lots` joins only `:entry`; `merge(Catalog::Entry.newest_first)` brings its own `joins(:set)` for the ordering, so the set is joined once. `Arel.sql` holds only literal SQL, with no user input (security rule). SQLite allows ordering by the entry and set columns under `GROUP BY catalog_entry_id`, because each group has exactly one entry row.
- [ ] Run: `bin/rspec spec/models/collection_grid_spec.rb` — expect: PASS.
- [ ] Commit: `feat(collection): build the collection grid query`
- [ ] Write the failing request spec `spec/requests/collections_spec.rb`:
  ```ruby
  require "rails_helper"

  RSpec.describe "Collection", type: :request do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    it "shows the empty state without a filter bar", :aggregate_failures do
      get collection_path
      expect(response.body).to include("My collection", "No cards in your collection yet. Search for a card to start adding.")
      expect(response.body).not_to include("c-filterbar")
    end

    it "shows stats, tiles and the Add items action", :aggregate_failures do
      entry = create(:mtg_printing, finishes: %w[nonfoil foil]).entry
      entry.update!(name: "Lightning Bolt", number: "146")
      create(:lot, account: user.account, entry:, quantity: 3)
      create(:lot, account: user.account, entry:, finish: "foil")
      get collection_path
      expect(response.body).to include("4 items · 1 unique", ">×4<", "Foil", "Lightning Bolt", "#{entry.set.code.upcase} · 146", ">EN<",
        %(href="#{catalog_entry_path(entry, from: 'collection')}"), %(href="#{catalog_entries_path}"))
      expect(response.body).not_to include('type="checkbox"', "Edit many", "c-seg")
    end

    it "filters by name and counts matching of total", :aggregate_failures do
      bolt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Lightning Bolt") }
      opt = create(:mtg_printing).entry.tap { |e| e.update!(name: "Opt") }
      create(:lot, account: user.account, entry: bolt, quantity: 3)
      create(:lot, account: user.account, entry: opt, quantity: 2)
      get collection_path(q: "bolt")
      expect(response.body).to include("3 of 5 items")
      get collection_path(q: "zzz")
      expect(response.body).to include(%(No cards in your collection match "zzz".), "0 of 5 items")
    end

    it "only shows the signed-in account's copies" do
      create(:lot, quantity: 7)
      get collection_path
      expect(response.body).to include("No cards in your collection yet.")
    end

    it "falls back to the first or last page for invalid page numbers", :aggregate_failures do
      stub_const("CollectionGrid::PER_PAGE", 1)
      2.times { create(:lot, account: user.account) }
      get collection_path(page: "abc")
      expect(response.body).to include("Page 1 of 2")
      get collection_path(page: "99")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Page 2 of 2")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/requests/collections_spec.rb` — expect: FAIL.
- [ ] Update `CollectionsController#show`:
  ```ruby
  def show
    @grid = CollectionGrid.new(account: Current.account, query: params[:q], page: params[:page])
  end
  ```
- [ ] Write `app/views/collections/_tile.html.erb`:
  ```erb
  <%# locals: (tile:) %>
  <% entry = tile.entry %>
  <%= link_to catalog_entry_path(entry, from: "collection"), class: "c-tile" do %>
    <div class="c-tile__media">
      <% if (image = catalog_url(entry.image_url)) %>
        <%= image_tag image, alt: entry.name, loading: "lazy", width: 146, height: 204 %>
      <% else %>
        <div class="c-tile__missing"><strong><%= entry.name %></strong><span><%= set_number(entry) %></span></div>
      <% end %>
      <span class="c-tile__qty">×<%= tile.quantity %></span>
      <% if tile.special_finishes.any? %>
        <span class="c-tile__flags"><%= render "catalog/entries/finish_badge", label: tile.special_finishes.join(", ").capitalize %></span>
      <% end %>
    </div>
    <div class="c-tile__name"><%= entry.localized_name || entry.name %></div>
    <div class="c-tile__meta"><span class="c-tag"><%= set_number(entry) %></span><span class="c-tag"><%= entry.language.upcase %></span></div>
  <% end %>
  ```
  (The badge label is "Foil", "Etched" or "Foil, etched".)
- [ ] Replace `app/views/collections/show.html.erb`:
  ```erb
  <% content_for :title, "My collection · Collector" %>
  <%= render "layouts/appbar", section: :collection %>
  <main class="c-main">
    <div class="c-pagehead">
      <div>
        <h1 class="c-pagehead__title">My collection</h1>
        <p class="c-pagehead__stats"><%= number_with_delimiter(@grid.total_quantity) %> items · <%= number_with_delimiter(@grid.unique_cards) %> unique</p>
      </div>
      <div class="c-pagehead__actions"><%= link_to catalog_entries_path, class: "c-btn c-btn--primary" do %><%= render "icons/plus" %>Add items<% end %></div>
    </div>
    <% if @grid.empty_collection? %>
      <p class="c-empty">No cards in your collection yet. Search for a card to start adding. <%= link_to "Search cards", catalog_entries_path %></p>
    <% else %>
      <div class="c-collection" data-controller="search-shortcut">
        <%= form_with url: collection_path, method: :get, class: "c-filterbar", role: "search", data: { turbo_frame: "results", turbo_action: "advance" } do |form| %>
          <label class="c-input"><%= render "icons/search" %><%= form.search_field :q, value: @grid.query, placeholder: "Search your collection", "aria-label": "Search your collection",
                data: { search_shortcut_target: "input" } %><kbd>/</kbd></label>
        <% end %>
        <turbo-frame id="results" target="_top" data-turbo-action="advance">
          <div class="c-results__meta">
            <span class="c-filterbar__count"><%= @grid.filtered? ? "#{number_with_delimiter(@grid.matching_quantity)} of #{number_with_delimiter(@grid.total_quantity)} items" : "#{number_with_delimiter(@grid.total_quantity)} items" %></span>
          </div>
          <% if @grid.tiles.empty? %>
            <p class="c-empty">No cards in your collection match "<%= @grid.query %>".</p>
          <% else %>
            <div class="c-grid"><%= render partial: "collections/tile", collection: @grid.tiles, as: :tile %></div>
            <%= render "catalog/pagination", pagination: @grid.pagination, link_params: { q: @grid.query.presence }, frame: "results" %>
          <% end %>
        </turbo-frame>
      </div>
    <% end %>
  </main>
  <%= render "layouts/tabbar", section: :collection %>
  ```
  The count sits inside the results frame, so it updates along with the filter ("0 of 5 items" when nothing matches, AC-11.5).
- [ ] Run: `bin/rspec spec/requests/collections_spec.rb` — expect: PASS.
- [ ] Commit: `feat(collection): show the collection as an image grid with a name filter`
- [ ] Write the system spec `spec/system/collection_spec.rb` (AC-11.8, AC-2.8, AC-1.5). It uses its own driver name, so the 390px window really opens:
  ```ruby
  require "rails_helper"

  RSpec.describe "Collection on a phone", type: :system do
    it "shows two columns, a full-width search and the header add button", :aggregate_failures do
      driven_by :selenium, using: :headless_firefox, screen_size: [ 390, 844 ], options: { name: :firefox_390 }
      user = system_sign_in_as(create(:user))
      3.times { create(:lot, account: user.account) }
      visit collection_path

      columns = page.evaluate_script("getComputedStyle(document.querySelector('.c-grid')).gridTemplateColumns.split(' ').length")
      expect(columns).to eq(2)
      search_share = "document.querySelector('.c-filterbar .c-input').getBoundingClientRect().width / document.querySelector('.c-filterbar').getBoundingClientRect().width"
      expect(page.evaluate_script(search_share)).to be > 0.95
      expect(page).to have_link("Add items", href: catalog_entries_path, visible: :visible)
      expect(page).to have_no_css(".c-pagehead__actions", visible: :visible)
      expect(page).to have_css(".c-tabbar", visible: :visible)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/collection_spec.rb` — expect: PASS.
- [ ] Commit: `test(collection): cover the phone layout`

---

## Phase 11: Design-system docs, 360px sweep and README

**Implements:** FR-11 (docs), FR-12, FR-1 (docs) | **Satisfies:** AC-1.4, AC-1.5 (remaining pages), AC-3.5 (README check)
**Files:** `docs/design-system/components/{StatusMessage,Form,AuthPage,ConfirmPage,SearchResults,TileAdd,FinishBadge,FilterSelect,Pager,EmptyState,Details,SingleStat,MorePage,AdminUsers,TableActions,SystemLogo}.md`, `docs/design-system/README.md`, `spec/design_system_files_spec.rb`, `spec/system/narrow_pages_spec.rb`, `spec/readme_spec.rb`, `.rubocop.yml`
**Interfaces:** Consumes: every view. Produces: nothing new.

- [ ] Add to `spec/design_system_files_spec.rb` (the list is a local variable, because a constant in a `describe` block leaks: `RSpec/LeakyConstantDeclaration`):
  ```ruby
  it "documents every new pattern and lists it in the README", :aggregate_failures do
    new_patterns = %w[StatusMessage Form AuthPage ConfirmPage SearchResults TileAdd FinishBadge FilterSelect Pager EmptyState
      Details SingleStat MorePage AdminUsers TableActions SystemLogo]
    readme = root.join("docs/design-system/README.md").read
    new_patterns.each do |name|
      expect(root.join("docs/design-system/components/#{name}.md")).to exist
      expect(readme).to include("`#{name}`")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect: FAIL.
- [ ] Write one doc per pattern, in the export's format (a title; one sentence on the purpose; **Markup** with the exact HTML the app renders, copied from the partial; then rules as bullets). For example, `docs/design-system/components/TileAdd.md`:
  ```markdown
  # TileAdd

  A tile in search results or a card's printings with an add button beside its link, so one tap adds a copy.

  **Markup** — the consumer provides the tile (as `ItemTile`) and a `button_to` form after it, never inside the link.

  ```html
  <div class="c-tilecell" id="tile_catalog_entry_1">
    <a class="c-tile c-tile--owned-none" href="/catalog/entries/…">…ItemTile content…</a>
    <form class="c-tile__add" data-turbo-frame="_top" method="post" action="/catalog/entries/…/quick_add">
      <button class="c-btn c-btn--ghost c-btn--sm" aria-label="Add 1 × Lightning Bolt (M10 · 146)"><svg …/>Add</button>
    </form>
  </div>
  ```

  - The button is outside the link: nested interactive elements are invalid and unusable by keyboard.
  - Its accessible name says exactly what is added: quantity, card name and `SET · number`.
  - It posts a form (works without JavaScript) and returns to the same URL; Turbo morphs the page so scroll and focus stay.
  - Owned tiles show `c-tile__qty`; tiles you don't own use `c-tile--owned-none` and no quantity.
  ```
  Write the other 15 docs the same way, from their partials and `additions.css` rules:

  | Doc | Covers |
  |---|---|
  | `StatusMessage` | the live region |
  | `Form` | `c-form`, `c-field`, errors, hints, `c-check`, select |
  | `AuthPage` | sign-in, sign-up and the closed state |
  | `ConfirmPage` | removals and user deletion |
  | `SearchResults` | `c-group`, `c-results__meta` |
  | `FinishBadge` | one foil-fill badge per tile: "Foil", "Etched" or "Foil, etched" |
  | `FilterSelect` | `c-select` |
  | `Pager` | `c-pager` |
  | `EmptyState` | `c-empty` and its copy rules |
  | `Details` | `c-details` |
  | `SingleStat` | `c-stats--single` |
  | `MorePage` | the More page |
  | `AdminUsers` | `c-admin__signup`, `c-admin__add` plus `c-table` |
  | `TableActions` | `c-table__actions`, the narrow cell holding a row's "…" menu |
  | `SystemLogo` | the OS-dark logo swap |
- [ ] In `docs/design-system/README.md` → **Components**, append a paragraph: "App additions (spec 004, in `collector/additions.css`): `StatusMessage`, `Form`, `AuthPage`, `ConfirmPage`, `SearchResults`, `TileAdd`, `FinishBadge`, `FilterSelect`, `Pager`, `EmptyState`, `Details`, `SingleStat`, `MorePage`, `AdminUsers`, `TableActions`, `SystemLogo`. Upstream these into the published design system before the next export replaces this folder."
- [ ] Run: `bin/rspec spec/design_system_files_spec.rb` — expect: PASS.
- [ ] Commit: `docs(design): document the patterns added for spec 004`
- [ ] Write `spec/system/narrow_pages_spec.rb` (AC-1.5 for every page this feature builds). It uses its own driver name, so the 360px window really opens:
  ```ruby
  require "rails_helper"

  RSpec.describe "Pages at 360px", type: :system do
    before { driven_by :selenium, using: :headless_firefox, screen_size: [ 360, 800 ], options: { name: :firefox_360 } }

    it "never scrolls sideways", :aggregate_failures do
      user = create(:admin)
      lot = create(:lot, account: user.account)
      [ new_session_path, new_registration_path ].each do |path|
        visit path
        expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true), "#{path} scrolls sideways"
      end
      system_sign_in_as(user)
      [ collection_path, catalog_entries_path(q: lot.entry.name), catalog_entry_path(lot.entry), catalog_identity_path(lot.entry.identity),
        new_catalog_entry_lot_path(lot.entry), edit_lot_path(lot), new_lot_removal_path(lot), more_path, admin_users_path,
        new_admin_user_path ].each do |path|
        visit path
        expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true), "#{path} scrolls sideways"
      end
    end
  end
  ```
- [ ] Run: `bin/rspec spec/system/narrow_pages_spec.rb` — expect: PASS. A failure names the overflowing path; the fix goes in `additions.css`, using tokens only, and the spec is re-run before committing.
- [ ] Commit: `test(design): check every page at 360px`
- [ ] Write `spec/readme_spec.rb`, which checks the README text from Phases 5 and 6, and add `"spec/readme_spec.rb"` to `RSpec/DescribeClass: Exclude:` in `.rubocop.yml`:
  ```ruby
  require "rails_helper"

  RSpec.describe "README" do
    let(:readme) { Rails.root.join("README.md").read }

    it "documents accounts and the new settings", :aggregate_failures do
      expect(readme).to include("collector:user", "COLLECTOR_HTTPS", "COLLECTOR_TRUSTED_PROXIES", "COLLECTOR_CURRENCY", "COLLECTOR_PASSWORD")
      expect(readme).to include("only acceptable on a trusted private network", "doesn't convert prices you've already entered")
    end

    it "warns about the first-run admin before the deployment steps", :aggregate_failures do
      expect(readme).to match(/first person to reach .* becomes its admin/i)
      expect(readme.index("Before you expose Collector")).to be < readme.index("### Docker Compose")
    end

    it "puts the upgrade warning before the upgrade steps" do
      upgrade = readme[/### Upgrading to accounts.*?(?=^## )/m]
      expect(upgrade.index("Read this before you upgrade")).to be < upgrade.index("1. Pull the new code.")
    end
  end
  ```
- [ ] Run: `bin/rspec spec/readme_spec.rb` — expect: PASS.
- [ ] Commit: `test(docs): check the README covers accounts and settings`

---

## Phase 12: Integration verification

**Implements:** All FRs | **Satisfies:** All ACs

- [ ] Run: `bin/rails zeitwerk:check` — expect: `All is good!` (new constants: `MTG::Collecting`, `MTG::ManaCost` with `MTG::ManaCost::Pip`, `MTG::Legality`, `MTGHelper`, `LotsHelper`, `Lot::Form`, `User::Command`, `Catalog::CardOverview`, `CollectionGrid`, `Collector::Currency`, `Collector::TrustedProxies`, and the controllers and concerns `Authentication`, `FirstRun`, `AdminOnly`, `CardContext`).
- [ ] Run: `bin/ci` — expect: every step green (RuboCop, Brakeman, bundler-audit, importmap audit, RSpec).
- [ ] Check the migrations are reversible: `bin/rails db:rollback STEP=3 && bin/rails db:migrate` — expect: no errors, and `db/schema.rb` unchanged (`git diff --exit-code db/schema.rb`).
- [ ] Walk through every AC by hand in the browser (`bin/dev`, worktree port), at 1280px and 390px, in light and dark (the OS preference), comparing against `docs/design-system/previews/{CollectionPage,CollectionPagePhone,ItemPage,ItemPagePhone}.html`. Focus rings must be visible on every control (FR-12, verified manually).
- [ ] Performance (NFR, manual): seed 5,000 lots for one account against a full English catalog (`bin/rails runner` snippet below), then time `/collection` and `/catalog/entries?q=dragon` in the log. Expect under 500 ms each.
  ```ruby
  account = User.first.account
  Catalog::Entry.searchable.limit(5_000).find_each { |entry| Lot.add!(account:, entry:, quantity: rand(1..4)) }
  ```
- [ ] Capture screenshots for the PR (see the memory note on the PR screenshots workflow).
- [ ] Commit: `chore(specs): record 004 verification` (only if verification changed files, e.g. screenshots).

---

## Quickstart Validation

```sh
bin/setup --skip-server && bin/rails db:migrate
bin/dev                                   # open the printed URL
# 1. Empty instance → redirected to "Set up Collector"; create the admin → lands on "My collection" (empty state).
bin/rails "catalog:refresh[mtg]"          # if the catalog isn't loaded yet
# 2. Search → type "bolt" → tap Add on a printing → "Added 1 × Lightning Bolt (…)" appears, the tile shows ×1, no reload.
# 3. Open the printing → card page: Owned 1, Your copies row, Printings (Shown), Format legality.
# 4. Add a copy → Foil, Near mint, 4.00 → Your copies shows the foil badge, NM, $4.00.
# 5. Edit copy → change to match another lot → lots merge; Remove → confirm page → removed message.
# 6. Collection → grid tile ×N with the foil badge; filter "bolt" → "N of M items".
# 7. Avatar → Users and sign-up → open sign-up; add a member; sign out; sign in as the member → empty collection.
# 8. Resize to 390px: tab bar, + button, back arrow on the card page; toggle the OS dark mode: dark tokens and the reversed logo.
bin/rails "collector:user[you@example.com]"   # resets the password (prompted), signs that user out everywhere
```

---

## Spec coverage (self-review)

| FR | Phases | | FR | Phases |
|---|---|---|---|---|
| FR-1 | 1, 11 | | FR-8 | 9 |
| FR-2 | 2 | | FR-9 | 8 |
| FR-3 | 2, 3, 5, 6 | | FR-10 | 10 |
| FR-4 | 3, 6 | | FR-11 | 1, 2, 4, 6, 7, 8, 11 |
| FR-5 | 6 | | FR-12 | 4, 7, 8, 10, 11, 12 |
| FR-6 | 5 | | FR-13 | 4, 6, 8 |
| FR-7 | 7, 8, 9 | | FR-14 | 7 |

**Acceptance criteria → the spec that asserts them:**

| AC | Phase | Spec |
|---|---|---|
| 1.1, 1.3 | 1 | `design_system_files_spec` |
| 1.2 | 1 | `requests/design_system_spec` |
| 1.4 | 11 | `design_system_files_spec` |
| 1.5 | 7, 8, 10, 11 | `system/quick_add_spec`, `card_page_spec`, `collection_spec`, `narrow_pages_spec` (driver `:firefox_360`/`:firefox_390`) |
| 2.1, 2.2, 2.6 | 4 | `requests/shell_spec` |
| 2.3 | 4, 8 | `shell_spec`; `entries_show_spec` (card page from the collection marks Collection in the header and tab bar) |
| 2.4 | 4, 6 | `shell_spec` (sign out); `admin/users_spec` (admin link for admins only) |
| 2.5 | 4 | `system/theme_spec` (driver `:firefox_dark`) |
| 2.7 | 8 | `system/card_page_spec` |
| 2.8 | 4, 10 | `shell_spec`; `system/collection_spec` |
| 3.1–3.4 | 3 | `models/registration_spec`, `requests/registrations_spec` |
| 3.5 | 6, 11 | `readme_spec` |
| 3.6 | 6 | `models/user/command_spec` |
| 4.1–4.3, 4.4a | 3 | `registrations_spec` |
| 4.4–4.8 | 2 | `requests/sessions_spec` (4.8 includes another client address and a trusted proxy's forwarded address), `lib/collector/trusted_proxies_spec` |
| 5.1–5.6 | 6 | `admin/users_spec` (copy counts from real lots; deletion removes lots and sessions only for that user; every admin page and action is 404 for members) |
| 5.7 | 6 | `user/command_spec`, `tasks/collector_rake_spec` (environment variable, prompt, generated, malformed email) |
| 6.1, 6.7 | 7 | `system/quick_add_spec` |
| 6.2–6.5 | 7 | `catalog/entries_search_spec` |
| 6.6 | 7 | `catalog/identities_spec` |
| 7.1, 7.3, 7.4 | 7 | `catalog/quick_adds_spec` |
| 7.2 | 7 | `system/quick_add_spec` |
| 7.3a | 7, 8 | `quick_adds_spec` (Turbo Stream at 422; card page at 422 without scripting), `system/quick_add_spec` |
| 7.5 | 5 | `models/lot_spec` |
| 7.6 | 7 | `entries_search_spec` (button outside the link, accessible name) |
| 8.1–8.9 | 8 | `catalog/entries_show_spec`, `models/catalog/card_overview_spec`, `models/mtg/mana_cost_spec` |
| 8.10 | 8 | `system/card_page_spec` |
| 9.1–9.4 | 9 | `requests/lots_spec` |
| 9.5 | 9 | `system/card_page_spec` |
| 10.1–10.5 | 9 | `lots_spec` (prefilled edit and "Saved.", 422 on invalid edits and on a merge past 9,999, confirmation page) |
| 11.1–11.7, 11.9 | 10 | `models/collection_grid_spec`, `requests/collections_spec` (page fallback both ways) |
| 11.8 | 10 | `system/collection_spec` |
| 12.1 | 7, 8, 10 | `entries_search_spec`, `entries_show_spec`, `collections_spec` |
| 12.2 | 9 | `lots_spec` |
| 12.3 | 3, 6, 9 | `registration_spec`, `admin/users_spec` (admin assigned explicitly), `lots_spec` |
| 12.4 | 5 | `models/lot_spec` ("data store") |
| 12.5 | 5, 7 | `lot_spec` (unique index), `quick_adds_spec` (two adds make one lot) |

**Stories:**
- Story 1 → Phases 1, 11
- Story 2 → Phases 4, 6, 8
- Story 3 → Phases 3, 6
- Story 4 → Phases 2, 3
- Story 5 → Phase 6
- Story 6 → Phase 7
- Story 7 → Phases 7, 8
- Story 8 → Phase 8
- Story 9 → Phase 9
- Story 10 → Phase 9
- Story 11 → Phase 10
- Story 12 → Phases 5, 7, 8, 9, 10

**NFRs:**
- **Performance:** Phase 12 (manual). Bounded queries come from `owned_quantities`, `CardOverview`, `CollectionGrid` and the grouped admin copy counts, which each run a constant number of queries.
- **Security:**
  - Phase 2: hashing, the cookie, CSRF on by default, and the rate limit per email and client address.
  - Phase 6: admin checks, and admin assigned explicitly rather than mass-assigned.
  - Phase 7: return paths through `url_from`.
  - Phase 9: tenant 404s and strong params.
- **Reliability:** Phase 12 (rollback check). A catalog refresh never touches `lots`, because the refresh writes only catalog tables.
