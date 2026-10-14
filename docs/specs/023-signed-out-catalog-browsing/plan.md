# Implementation Plan: Browse the Catalog Without Signing In

**Spec:** [spec.md](spec.md) (v1.2.0, approved with changes on 2026-10-14)
**Decisions:** no ADR. Decisions 1 and 2 and the untabbed rule of decision 3 are the maintainer's rulings of 2026-10-14; the rest are the spec's.

**How this plan was made.** Its two framework assumptions were run in scratch first (see Risks). Each phase's examples are run red before its change and green after; the red runs are quoted in `verification.md`.
**Created:** 2026-10-14
**Issue:** [#59](https://github.com/plainprogrammer/Collector/issues/59)

## Global Constraints

- One test of the setting, `Catalog.public?` (FR-1). Views never ask it; they ask `collector?` (FR-4).
- Only `Catalog::EntriesController` and `Catalog::IdentitiesController` change their access. Quick add, lots, the scanner, More, sessions and admin controllers are untouched. Two small touches outside them, both from the approved spec: `CollectionsController#prefetch?` moves to `ApplicationController` unchanged (decision 4), and `RegistrationsController#create` clears the return path (decision 4).
- No migration, no gem, no JavaScript. The visitor header is built from existing `c-*` classes; the only CSS is one `additions.css` block, `Untabbed shell (spec 023)`. `components.css`, `tokens.css` and the exported documents stay as they are.
- Each phase's examples are seen to fail before its change and pass after; each phase is one Conventional Commit (scope `023`), staged and committed in separate commands. Nothing is pushed without the coordinator's permission.
- Out of scope: `/`, the sign-in and sign-up pages, registration's redirect, rate limiting, the export format.

## How the pieces fit

```
ApplicationController
  before_action :require_first_user      (FirstRun, unchanged: an empty instance still goes to sign-up, AC-2.3)
  before_action :require_authentication  (Authentication, unchanged)
Catalog::EntriesController / Catalog::IdentitiesController
  include OpenCatalog
    skip_before_action :require_authentication, if: -> { Catalog.public? }
    before_action :resume_session                          (one sessions lookup; Current.session set or nil)
    after_action  :remember_visited_page                   (visitor, GET, not prefetch?: the sign-in return path)
    owned_quantities(ids) -> {} with no account, no query  (FR-3)
Views
  collector? (ApplicationHelper) = Current.user.present?   (reads what the controller resolved; no query)
  every controller resolves Current before rendering (require_authentication, or OpenCatalog's resume_session),
  so the quick add's full-lot re-render of the card page reads collector? as true (AC-6.2)
Layout
  body.c-shell--untabbed unless content_for?(:tabbar)     (decision 3; the views render before the layout)
```

`resume_session` is `Current.session ||= find_session_by_cookie`. For a stale cookie it returns nil and isn't memoised, so the views must never call `authenticated?`: `collector?` reads `Current.user`, which the before_action already resolved (AC-2.4, FR-4).

## Phase 1: The setting (AC-1.1, AC-1.2)

**Red.** `spec/models/catalog_spec.rb` gains `.public_in?` (true for `1`, `true`, `yes`, `on`, `TRUE`, ` On `; false for `{}`, `""`, `0`, `false`, `maybe`) and `.public?` (false in tests by default; true under a `:public_catalog` example; false when the configuration is anything but `true`, e.g. `"true"`). A new `spec/support/public_catalog.rb` adds the `:public_catalog` tag (around hook, restores the previous value), in the shape of `spec/support/art_helpers.rb`.

**Green.**

```ruby
# app/models/catalog.rb
  # Spec 023: the operator's choice to open catalog search and card pages to visitors. Off unless
  # COLLECTOR_PUBLIC_CATALOG is 1, true, yes or on (decision 1); parsed once at boot (config/initializers/public_catalog.rb).
  PUBLIC_ENV = "COLLECTOR_PUBLIC_CATALOG"
  TRUE_VALUES = %w[1 true yes on].freeze

  def self.public_in?(env) = TRUE_VALUES.include?(env.fetch(PUBLIC_ENV, "").to_s.strip.downcase)
  def self.public? = Rails.configuration.x.public_catalog == true
```

`config/application.rb`: `config.x.public_catalog = false` with a one-line comment. `config/initializers/public_catalog.rb`, as `art_matching.rb`:

```ruby
Rails.application.config.after_initialize do
  Rails.configuration.x.public_catalog = !Rails.env.test? && Catalog.public_in?(ENV)
end
```

**Commit:** `feat(023): add the COLLECTOR_PUBLIC_CATALOG operator setting`.

## Phase 2: Deployment files (AC-1.3)

**Red.** `spec/image_publishing_spec.rb`: the compose key list gains `COLLECTOR_PUBLIC_CATALOG`; new examples `include('COLLECTOR_PUBLIC_CATALOG: "${COLLECTOR_PUBLIC_CATALOG:-}"')` for compose and `include("# COLLECTOR_PUBLIC_CATALOG: true")` for `config/deploy.yml`.

**Green.** `compose.yaml`: header comment `# Optional: COLLECTOR_PUBLIC_CATALOG ("true" opens catalog search and card pages to visitors who aren't signed in; default off)` and the environment line. `config/deploy.yml`: a comment and `# COLLECTOR_PUBLIC_CATALOG: true` after the art matching entry.

**Commit:** `feat(023): pass COLLECTOR_PUBLIC_CATALOG through Compose and Kamal`.

## Phase 3: Open the catalog actions, without tenant data (AC-2.1–2.4, AC-3.1–3.5, AC-4.1–4.5, AC-6.1)

**Red.** A new `spec/requests/catalog/visitors_spec.rb`, with one fixture: a set, an identity with two printings (one with an image, one without), another account owning 3 copies of the first printing in 2 lots (user "Morgan Owner", `morgan@example.com`).

- *Setting off* (default): a visitor's GET of search, the card page and all printings redirects to `new_session_path`; signing in afterwards lands on the requested page (AC-2.1). A stale cookie (sign in, `Session.delete_all`) redirects too (AC-2.4).
- *Setting on* (`:public_catalog`):
  - each page answers 200 with the catalog content (AC-3.1–3.3); search with `q`, `set` and `page`; all printings with and without `set`;
  - a missing card and an identity with no searchable entry answer 404 (AC-3.4);
  - the structural absences of AC-4.1 on all three pages, with Nokogiri (`.c-avatar`, `.c-tile__qty`, `.c-tile__add`, `form[action*="quick_add"]`, `a[href*="/lots/new"]`, `#copies`, `.c-stat`, `.c-tile--owned-none`, `li.is-unowned`), and the text absences ("Not owned", "Your copies", "Add a copy", " owned", "Morgan Owner", `morgan@example.com`);
  - no SQL statement naming `"lots"` runs during any of the three requests (AC-4.2, `sql.active_record` subscriber);
  - a quick-add POST, a new-lot GET, the collection, the scanner and More redirect to sign in, and `Lot.count` doesn't change (AC-4.3);
  - `from=collection` on the card page: crumbs and back arrow go to `catalog_entries_path`, and printings links carry no `from=` (AC-4.4);
  - `Cache-Control` contains `private` and not `public`, for a visitor and a collector (AC-4.5);
  - sign-in after a visitor's card page lands on it; a prefetch GET of a second card page in between (once with `X-Sec-Purpose: prefetch`, once with `Sec-Purpose: prefetch`) doesn't change that;
  - a visitor opens a card page, signs up, signs out and in: lands in the collection both times (AC-3.7); a collector's catalog GET leaves `session[:return_to_after_authenticating]` unset, checked by signing out then in and landing in the collection (AC-3.5);
  - a stale cookie gets the visitor's page (AC-2.4);
  - a collector sees every collection part on all three pages (AC-6.1): `×3`, the stat, `#copies`, quick-add forms.
- *No users* (`User.delete_all` before the request, setting on and off): redirects to `new_registration_path` (AC-2.3).

`spec/requests/catalog/quick_adds_spec.rb`'s full-lot example (without scripting) also expects the "Owned" stat and `.c-avatar` (AC-6.2); it passes before and after (a guard, not a red).

**Green.**

```ruby
# app/controllers/concerns/open_catalog.rb
# Spec 023: with the operator's setting on (Catalog.public?), catalog pages answer visitors too. A visitor gets no
# tenant data (FR-3); views tell the two apart with collector? (FR-4). Signing in from a catalog page returns to it.
module OpenCatalog
  extend ActiveSupport::Concern

  included do
    allow_unauthenticated_access if: -> { Catalog.public? }
    before_action :resume_session
    after_action :remember_visited_page, unless: -> { Current.user }
  end

  private
    def owned_quantities(entry_ids) = Current.account ? Lot.owned_quantities(Current.account, entry_ids) : {}

    def remember_visited_page
      return unless request.get? && !prefetch?

      session[:return_to_after_authenticating] = request.fullpath
    end
end
```

`prefetch?` moves from `CollectionsController` to `ApplicationController`'s private methods, unchanged (`Sec-Purpose`, `X-Sec-Purpose`, `X-Moz`, `Purpose`); the collection's prefetch examples (spec 006 AC-1.10) keep it honest. `RegistrationsController#create` deletes `session[:return_to_after_authenticating]` after a successful sign-up (AC-3.7). Both controllers `include OpenCatalog` and call `owned_quantities(...)` instead of `Lot.owned_quantities(Current.account, ...)`. `Catalog::CardOverview#lots` returns `[]` when `@account` is nil. `CardContext#card_context` becomes `params[:from] == "collection" && Current.user ? :collection : :search`. `ApplicationHelper#collector?` is `Current.user.present?`.

Views (each change gated on `collector?`):

| File | Visitor |
|---|---|
| `catalog/entries/_tile` | plain `c-tile`, no `×N`, no marker, no quick add |
| `catalog/entries/show` | no "Add a copy", no `c-stats`, no `_copies` |
| `catalog/entries/_printings` | count "N known"; no `is-unowned`; no `c-list__end` |
| `catalog/_not_loaded` | first sentence only (AC-5.4) |
| `layouts/_appbar` | visitor form (Phase 4) |
| `layouts/_tabbar` | not rendered (Phase 4) |

Phase 3 makes `_appbar` and `_tabbar` safe for a visitor (they would raise on `Current.user.name`), so it carries the minimal visitor branch; Phase 4 finishes the header form and its documents.

**Commit:** `feat(023): open catalog search and card pages to visitors when the operator allows`.

## Phase 4: The visitor shell (AC-5.1–5.4, AC-5.6, AC-5.7 markup)

**Red.** In `visitors_spec.rb`: the body has `c-shell--untabbed` for a visitor and on sign-in and sign-up, and not for a collector; the header's brand links to `catalog_entries_path` with `aria-label="Collector search"`; the nav holds one link, "Search", `aria-current="page"`; the actions hold a "Sign in" link to `new_session_path` with `c-btn c-btn--secondary c-btn--sm`; no `#tabbar`; `.c-footer` present with the content notice; on the card page the header is `c-appbar--detail` with a back link to search. The not-loaded notice reads exactly "The card catalog hasn't been loaded yet." for a visitor (an instance with no applied refresh).

**Green.** `_appbar`:

```erb
<% if collector? %> … today's header … <% else %>
  <header class="c-appbar<%= " c-appbar--detail" if detail %>" id="appbar">
    <% if detail && local_assigns[:back_path] %>…back link…<% end %>
    <%= link_to catalog_entries_path, class: "c-appbar__brand", "aria-label": "Collector search" do %>…logos…<% end %>
    <nav class="c-appbar__nav" aria-label="Main"><%= link_to "Search", catalog_entries_path, "aria-current": "page" %></nav>
    <div class="c-appbar__actions"><%= link_to "Sign in", new_session_path, class: "c-btn c-btn--secondary c-btn--sm" %></div>
  </header>
<% end %>
```

The shared logos move into a small partial `layouts/_appbar_logos` so the two forms don't repeat them. `_tabbar` wraps its body in `<% if collector? %>`. The layout's body class becomes `class_names("c-shell", "c-shell--footed": notice_lines.any?, "c-shell--untabbed": !content_for?(:tabbar))` (the exact `c-shell c-shell--footed` assertions in `design_system_spec.rb` and `footer_spec.rb` are on collector pages and still hold).

`additions.css`, a block after `Footer (spec 018)`:

```css
/* ---------- Untabbed shell (spec 023) ----------
   Below bp-narrow c-main (or, on a footed shell, the footer) keeps 80px clear for the fixed tab bar. A page with no tab
   bar (a visitor's catalog page, sign-in, sign-up) is marked c-shell--untabbed and gives that clearance up. */
@media (max-width: 639px) {
  .c-shell--untabbed > .c-main { padding-bottom:calc(var(--space-6) + env(safe-area-inset-bottom)); }
  .c-shell--untabbed.c-shell--footed > .c-main { padding-bottom:var(--space-4); }
  .c-shell--untabbed > .c-footer { padding-bottom:calc(var(--space-4) + env(safe-area-inset-bottom)); }
}
```

`spec/design_system_files_spec.rb` gains the block's shape check as spec 021's (one block, its heading, no colour literal, no font).

Documents: `docs/design-system/components/VisitorHeader.md` (markup, when it shows, no tab bar and the untabbed shell, the phone and detail forms); the design system README's additions gain a spec 023 line naming `VisitorHeader` in `collector/additions.css`; `AuthPage.md`'s "nothing else is reachable before signing in" names the open catalog as the exception and says the auth pages' brand stays unlinked (accepted).

**Commit:** `feat(023): give the header a visitor form and drop the tab bar for visitors`.

## Phase 5: The visitor's flow in the browser (AC-3.6, AC-5.5, AC-5.7)

**Red → green.** `spec/system/visitor_catalog_spec.rb`, `:public_catalog`: without signing in, visit search, fill "Card name" with "bolt", click Search, click the result, see the card page's `h1`, no `.c-avatar`, no "Add a copy", the footer's notice on both pages, and "Sign in" in the header; then a narrow-frame check (`spec/support/narrow_frame.rb`) at 390px of the search and card pages: no horizontal overflow, "Sign in" visible; and, in a 320px-tall frame scrolled to the end, the computed `padding-bottom` of `c-main` and of the footer is below 80px on a visitor's page and sign-in, and 80px or more under a collector's tab bar (AC-5.7; proved by deleting the block once). Red is shown by running it with the setting off (redirect to sign-in).

Screenshots for AC-5.5: search and card page at 1280px and 390px (frame), light and dark, from a dev server on this worktree's port with the setting on, cut and compressed into `screenshots/` as spec 021 did. Each is looked at.

**Commit:** `test(023): a visitor searches and opens a card in the browser`, then `docs(023): screenshots of the visitor's pages`.

## Phase 6: Documents (AC-1.4, FR-5)

- `README.md`: the Compose table gains `COLLECTOR_PUBLIC_CATALOG | no | off | true opens catalog search and card pages to visitors (see [Open catalog](#open-catalog))`; a short "Open catalog" section (what opens, what stays private, that a hosted instance turns it on per the Scryfall research, how to set it for Compose and Kamal, and one sentence advising a rate limit at the reverse proxy, since every search runs a name match).
- `CLAUDE.md`: the status line's "which has needed sign-in since accounts (spec 004)" gains "unless the operator opens it with `COLLECTOR_PUBLIC_CATALOG` (spec 023)", plus a Non-obvious Facts line on `OpenCatalog` and `collector?`.
- `docs/roadmap.md`: the #59 line says spec 023 and the PR, once open.

**Commit:** `docs(023): document the open catalog setting`.

## Phase 7: Verification

`bin/ci` green; `verification.md` maps every AC to its example or reading, with the red runs quoted; read-only Opus review of the branch; fixes from it in their own commits.

## Risks

- **Conditional `skip_before_action`.** Rails evaluates the `if:` per request, so turning the setting on in an example takes effect without reloading the controller; the request specs prove it. Checked in scratch on 2026-10-14 (Rails 8.1.4): `skip_before_action :a, if:` leaves `:a` in the chain with one `unless` condition. The bundled Turbo sets `X-Sec-Purpose: prefetch` on its prefetch requests.
