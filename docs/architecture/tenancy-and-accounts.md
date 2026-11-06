# Tenancy and accounts

Who may use an instance and whose data a request sees: the account that owns every collector's data, the user and the admin flag, first-run setup and the sign-up setting, sign-in and sessions, the admin users page, the operator's command, and the rules that keep one account's data from another. This is the current truth; the specs it distils record what each feature promised when it shipped (see Sources and the [specs index](../specs/README.md)). The rules an agent follows when writing code are in [`.claude/rules/multi-tenancy.md`](../../.claude/rules/multi-tenancy.md), which stays their home; this doc says what the code does and why.

## Scope

**Covers:**

- The tenant and its holder: `Account`, `User`, `Session`, `InstanceSetting`, `Current` (`Current.session`, `.user`, `.account`) (spec 004 FR-2, FR-3, FR-4; [ADR 0017](../adr/0017-row-level-tenancy-one-user-per-account.md)).
- Resolving the tenant and failing closed: `Authentication`, `FirstRun`, `AdminOnly`, `ApplicationController`, and the list of endpoints that skip the sign-in requirement (spec 004 FR-2, AC-3.1, AC-4.6, AC-5.6).
- First run and sign-up: `Registration`, `RegistrationsController`, the sign-up setting and `Admin::SignUpSettingsController` (spec 004 Story 3, Story 4, FR-4).
- Sign-in, the sign-in rate limit, sessions and sign-out: `SessionsController` (spec 004 Story 4, AC-4.8, FR-2, NFR Security).
- Administering users: `Admin::UsersController`, `Admin::Users::DeletionsController`, `User::Command` and `collector:user` (spec 004 Story 5, FR-5, AC-5.7, AC-3.6).
- Isolation: that every collector-owned table carries `account_id` (spec 004 AC-12.4) and that no request can name another account (spec 004 Story 12, NFR Security; ADR 0017), and the admin gate every admin page uses (spec 004 AC-5.6; spec 015 AC-7.1, AC-7.3).
- The ownership rule behind `ActiveStorageGate` (spec 028 decision 8; [ADR 0022](../adr/0022-stored-import-upload-retention.md)).

**Neighbours:**

- What lots, locations and the working-state records hold, how they are scoped in each page, bulk mode's selection and Undo, and each account's currency and saved view: **[collection and lots](collection-and-lots.md)** (spec 004 AC-12.1–AC-12.3 and AC-12.5 for lots, spec 006 Story 8, spec 029 Story 4, spec 032 Story 6, spec 038). This doc states the rule they apply and says only that a session owns its bulk selection and Undo by foreign key.
- `Catalog::EntriesController` and `Catalog::IdentitiesController` answering visitors, `collector?`, the visitor's header and the page sign-in returns to: **[catalog core](catalog-core.md)** (spec 023). This doc says how a request without a session is let through and what `Current` holds then.
- What the export, the preview and the apply do with a collector's profile and account: **[data portability](data-portability.md)** (specs 022, 025, 028). Backup and restore, and the stored import upload's retention and its sweep: **[release and deploy](release-and-deploy.md)** (specs 028, 030; ADR 0022). `compose.yaml` passes `COLLECTOR_HTTPS` and `COLLECTOR_TRUSTED_PROXIES` to the app and `config/deploy.yml` lists them for Kamal; what they do is here (spec 004 FR-2, NFR Security). The README's upgrade warning and command text are documentation, not checked here (spec 004 AC-3.5, AC-5.7).
- What the admin catalog and jobs pages show and do: **[catalog operations](catalog-operations.md)** (spec 015); this doc holds only who may open them.
- The scanner's own pages and sitting: **scanner** (no area doc yet; specs 007, 009); this doc says only which of its endpoints skip sign-in.
- The sign-in, sign-up and admin pages' patterns (`AppHeader`, forms, `Confirm`): the [design system](../design-system/README.md).
- The rules' home, the multi-tenancy rule file, is `.claude/rules/`; this doc links it and doesn't restate it (spec 027 D2).

## Glossary

- **Account:** the tenant: the owner of all of one collector's data (`Account`). It is created with its user and deleted with it (spec 004 FR-3; ADR 0017). It carries the currency prices are shown in, which is [collection and lots](collection-and-lots.md)'.
- **User:** a person who signs in (`User`): a name (at most 100 characters), an email address, a password kept only as a salted hash (`has_secure_password`), the admin flag, and a saved collection view. Every user has exactly one account and every account exactly one user (`users.account_id` is unique) (spec 004 FR-2, FR-3, AC-4.3; ADR 0017).
- **Session:** a signed-in browser (`Session`): a row per sign-in, found by the signed cookie `session_id`. It carries no tenant data itself; `Current.user` and `Current.account` come from it (spec 004 FR-2).
- **`Current`:** the request's session, user and account (`Current.session`, `.user`, `.account`). `Current.account` is the signed-in user's account, nil without a session (spec 004 FR-2, FR-3; `app/models/current.rb`).
- **Collector / visitor:** a collector is a signed-in user (`collector?`, `Current.user.present?`); a visitor has no session. A visitor exists only where an endpoint is open (see the list under Invariants) (spec 023 Terms).
- **Admin / member:** a user with or without the `admin` flag. The first user is an admin; the flag governs the instance's operations and gives no view into another account's collection (spec 004 FR-3; ADR 0017 Consequences). "Member" is spec 015's word (spec 015 Glossary).
- **First run:** an instance with no user. The first visitor becomes its admin (spec 004 Story 3, FR-4). An upgraded instance starts there (spec 004 NFR Reliability, AC-3.5).
- **Sign-up setting:** `instance_settings.sign_up_open`, one instance-wide switch: closed once the first user exists, opened and closed by an admin (spec 004 FR-4, AC-3.3).
- **Tenant-owned table:** a table with `account_id`, a foreign key to `accounts` and an index. Today: `lots`, `locations`, `import_uploads`, `number_entries`, `number_entry_lines`, `scanner_sittings`, `scanner_sitting_entries`, `bulk_selections`, `bulk_selection_marks`, `bulk_removals` (spec 004 AC-12.4; `db/schema.rb`). `users` carries `account_id` too, unique. The catalog's tables carry none.
- **Operator command:** `bin/rails "collector:user[EMAIL]"` (`User::Command`): sets a user's password, or creates an admin (spec 004 AC-5.7, AC-3.6).

## Invariants

- **The account is the only tenant key.** Every collector-owned table carries `account_id` with a foreign key and an index; the catalog's tables have none (spec 004 AC-12.4; ADR 0017; `.claude/rules/multi-tenancy.md`). The export document's Coverage tables must list any new table with `account_id` or `user_id` or the suite fails ([data portability](data-portability.md); spec 017 FR-9, AC-3.4, AC-3.5; ADR 0020).
- **One user per account.** `users.account_id` has a unique index and the account is built with the user (`before_validation :build_account`); a user is the only way an account exists (spec 004 FR-3; ADR 0017). Specs shouldn't assume it will always hold where that costs nothing to avoid (ADR 0017 Consequences).
- **A request resolves its tenant once and fails closed.** `ApplicationController` includes `FirstRun` then `Authentication`; `require_authentication` runs before every action and redirects a request with no session to sign-in, so no controller meets a nil `Current.account` unless it asked for a visitor (spec 004 FR-2, AC-4.6; ADR 0017). `Current.session` is set once, from the signed cookie, and `Session.includes(user: :account)` loads the account with it (`Authentication#find_session_by_cookie`).
- **A tenant query goes through `Current.account`.** Controllers read collector-owned data from `Current.account.lots`, `.locations`, `.scanner_sitting`, `.number_entry` and the like, or pass `account: Current.account` to the model that does, so an id from another account is not found and answers 404 (spec 004 AC-12.1, AC-12.2, NFR Security; ADR 0017). Nothing in a request names an account: `account_id`, `user_id` and `admin` are never permitted from parameters; sign-up permits only `name`, `email_address`, `password` and `password_confirmation` (`Registration::PERMITTED`), a user form `name`, `email_address` and `password`, and `admin` is set by the admin-only controller from its own checkbox (spec 004 AC-12.3, NFR Security; `.claude/rules/security.md`). The app has no `default_scope` and no `unscoped`.
- **Another account's record is a 404, never a 403.** A lookup through `Current.account` raises `ActiveRecord::RecordNotFound`, which answers 404 and leaves the record unchanged; the admin pages answer 404 to a member the same way (spec 004 AC-12.2, AC-5.6; spec 015 AC-7.1). A request spec per tenant-scoped resource proves it (spec 004 AC-12.2; `.claude/rules/multi-tenancy.md`).
- **Cross-account reads are few, and each has a reason.** `Lot.group(:account_id).sum(:quantity)` and `account.copies_count` on the admin users page and its delete confirmation: a count of copies per account, for admins only (spec 004 AC-5.1, AC-5.4; hosted-door rule 2 in the [north star](../north-star.md)); `User.order(:name)` (the list) and `User.find` on the admin pages (users, not collections), and `User.authenticate_by` at sign-in; `User.exists?`, `User.admins` and `User.find_or_initialize_by` in first-run, the last-admin check and the command (spec 004 AC-3.1, AC-5.5, AC-5.7); `ImportUpload.sweep!`, cross-tenant by nature because the instance runs it (spec 028 decision 9); the scanner findings tasks' `User.find_by!(email_address: SCANNER_EMAIL).account` (development tools of spec 009 and spec 011, which name the account on purpose); the backup's counts of `accounts`, `users` and `lots`, read with SQLite directly (spec 030). Any other cross-tenant query needs a comment saying why (`.claude/rules/multi-tenancy.md`).
- **The operator is not the user.** No admin page or task shows or edits the items in a collector's collection: the admin users page shows each account's copy count and may create or delete an account (deleting a user deletes their collection), change a name, email address or password; it never lists or opens what a collection holds (ADR 0017 Consequences; [north star](../north-star.md) hosted-door rule 2; spec 004 AC-5.1, AC-5.4; spec 029 AC-4.5).
- **Jobs and broadcasts carrying the tenant is a rule with no instance yet.** ADR 0017 requires an account-scoped job or broadcast to carry and restore the account; no such job or broadcast exists, `ApplicationJob` restores no `Current.account`, and no view subscribes to a Turbo Stream channel. The jobs the app runs are global: the catalog refresh and the art build (catalog data), and `ImportUpload::SweepJob` (the one that touches tenant data, which it does for every account) (ADR 0017 Decision; spec 028 decision 9). The first account-scoped job or broadcast makes the rule's code, and updates this doc.
- **Cache keys that hold tenant data name the account.** Nothing caches tenant data today; the one thing cached per client is the sign-in rate limit's counters, keyed by address and email (spec 004 AC-4.8; `.claude/rules/multi-tenancy.md`). The art index is served as global data: "never stored under a tenant key, and serving it reads no tenant data" (spec 011 AC-4.4).
- **Only these endpoints answer without a sign-in.** Everything else redirects to sign-in, whatever the setting (spec 004 FR-2, AC-4.6):

  | Endpoint | Why open | Source |
  |---|---|---|
  | Sign-in and sign-up | They are how one gets a session | spec 004 AC-4.1–AC-4.5 |
  | `/up` (the health check; inherits `Rails::HealthController`, not `ApplicationController`) | A monitor has no session; also on an instance with no users | spec 004 AC-3.1, Error Scenarios |
  | `/ocr/<version>/*path` (`OcrAssetsController`) | A public library, immutable and versioned; also before the first user | spec 011 AC-4.1 ("as the OCR engine … are"); the controller says it is a public library (no spec says so for the engine itself); [ADR 0001](../adr/0001-browser-ocr-engine-and-asset-hosting.md) serves it |
  | `/scanner/art/<name>` (`Scanner::ArtIndexesController`) | Global catalog data; also before the first user | spec 011 AC-4.1, Story 4; [ADR 0007](../adr/0007-art-search-in-the-browser.md) |
  | The search, card and printings pages | Only with `COLLECTOR_PUBLIC_CATALOG` on; never on an instance with no users | spec 023 FR-1, FR-2, AC-2.3; [catalog core](catalog-core.md) |
  | Scanner measurement mode's photos, replays and strips (development only) | A local headless browser isn't signed in; every action 404s unless measurement mode is on (spec 007 AC-5.1, FR-6), and every request must be local (`request.local?`; no spec source) | spec 007 AC-5.1, AC-5.6, FR-6 |

  Active Storage's routes need a sign-in too, and more (see the ownership rule below). A controller that inherits `ApplicationController` opts out only with `allow_unauthenticated_access` (and, to be reachable before the first user, `allow_before_first_user`); the health check passes both gates by not inheriting it.
- **Active Storage answers a blob only to the account that owns it.** `ActiveStorageGate`, included in `ActiveStorage::BaseController`, serves a blob only when `Current.account` exists and an attachment of the blob belongs to a record that answers `account_id` with that account's id; a record with no `account_id` is served to no one, and anything else answers 404. Direct uploads and the disk service's upload `PUT` are refused (404) until a feature needs them (spec 028 decision 8; ADR 0022). The gate's refusals and the stored upload's retention are [release and deploy](release-and-deploy.md)'s.
- **A user's passwords and email are kept out of the log.** `filter_parameters` lists `:passw`, `:email` and the other secret-bearing names, so a password or an email address in a request isn't logged (spec 004 NFR Security; `config/initializers/filter_parameter_logging.rb`). The operator command never writes the password to the application log (spec 004 AC-5.7).
- **Every state-changing request is CSRF-protected.** Rails' forgery protection is on for every controller; the one `skip_forgery_protection` in the app is `OcrAssetsController`, a GET-only public library (spec 004 NFR Security; `config/environments/test.rb` turns it off for specs only). Names and catalog text are escaped when rendered; that is the views' and the design system's (spec 004 NFR Security; `.claude/rules/security.md`).
- **Sign-in tells nothing about which half was wrong.** A wrong email and a wrong password get the same 422 "Email or password is incorrect.", and an email's case doesn't matter (spec 004 AC-4.4, AC-4.5, FR-2 must-not). Email is never sent: no password reset by email, no invitation (spec 004 FR-2 must-not, Non-Goals).
- **Sign-in and sign-up send a signed-in user home.** Opening either page, or submitting either form, redirects a signed-in user to the collection; the root path does the same (spec 004 AC-4.4a, AC-2.6).

## States and transitions

### The instance: first run, closed, open

| State | Sign-up page (`GET /registration/new`) | Sign-up submitted | Every other page |
|---|---|---|---|
| **No users** (first run) | 200: "Set up Collector", "This first account will be the admin of this instance." and the form | Creates the first user as an admin with a new account, closes sign-up, signs them in and goes to the collection | Redirect to sign-up, except `/up`, the OCR files and the art index (spec 004 AC-3.1, AC-3.2, AC-3.3) |
| **Closed** (the default once a user exists) | 200: "Sign-up is closed on this instance. Ask the person who runs it for an account." and a "Sign in" link, no form | 422 with the same message; no user is created, which also answers a submission that lost the first-user race (spec 004 AC-4.2, AC-3.4) | Needs sign-in |
| **Open** (an admin opened it) | 200: the form | Creates a non-admin user with a new account, signs them in and goes to the collection (spec 004 AC-4.1) | Needs sign-in |

- **The first user.** `Registration#save` checks for no user and inserts in one `User.transaction`, which SQLite opens as a write transaction (IMMEDIATE, Rails' default), so two submissions can't both find none: the second sees a user and gets the closed answer (spec 004 AC-3.4, FR-4). The first user is an admin and closes sign-up in the same transaction; the first user created by the command does the same (spec 004 AC-3.2, AC-3.3, AC-3.6).
- **Invalid sign-up** answers 422 with a message under each invalid field and no user: a blank name or one over 100 characters; an email that isn't exactly one "@" with text on both sides or contains whitespace, or is already used (compared case-insensitively: the address is stored stripped and lower-cased); a password under 12 characters, or a confirmation that doesn't match (spec 004 AC-4.3; `User`). What a missing confirmation does is [#218](https://github.com/plainprogrammer/Collector/issues/218)'s (no spec source).
- **Sign-up lands in the collection,** whatever catalog page a visitor opened first (spec 004 AC-3.2, AC-4.1; spec 023 AC-3.7).
- **Opening and closing** is one admin action on the admin users page: the page says "Sign-up is open: anyone who can reach this instance can create an account." or "Sign-up is closed: only you can add users." with a "Close sign-up" or "Open sign-up" button; a member's request is a 404 (spec 004 AC-5.1, AC-5.6, FR-4).

### Sign-in

`GET /session/new` is the form; `POST /session` signs in. An email in any letter case and the password sign the user in and go to the page they first asked for, or to the collection (spec 004 AC-4.4). The page asked for is kept in the Rails session (`return_to_after_authenticating`) when a request without a sign-in was a GET or HEAD, and is the request's own path, set by the server and never read from a parameter, so it can't send anyone off the instance (spec 004 AC-4.4, FR-2; `Authentication#request_authentication`). A visitor's catalog page is also stored there, and sign-up clears it (spec 023 decision 4; [catalog core](catalog-core.md)).

| Request | Answer |
|---|---|
| Right email and password | 303 to the page asked for, or the collection; a session exists (spec 004 AC-4.4) |
| Wrong email or password | 422, "Email or password is incorrect."; no hint which (spec 004 AC-4.5) |
| The 11th attempt for one email from one client address within 3 minutes | 429, "Too many attempts. Try again in a few minutes."; no password is checked. Another email, or another address, isn't refused (spec 004 AC-4.8) |
| A signed-in user | Redirect to the collection (spec 004 AC-4.4a) |

The limit is `rate_limit to: 10, within: 3.minutes`, keyed `"<client address>|<email, stripped and lower-cased>"`, and counted in `config.x.sign_in_rate_limit_store`, which is nil (so `Rails.cache`, Solid Cache in production) except in specs, where it is a memory store (spec 004 AC-4.8; [#218](https://github.com/plainprogrammer/Collector/issues/218)). The client address is `request.remote_ip`, the forwarded address only from a trusted proxy: Rails' private and loopback ranges plus the IPs or CIDRs in `COLLECTOR_TRUSTED_PROXIES` (`Collector::TrustedProxies`; spec 004 FR-2, AC-4.8).

### A session

- **Created** by a successful sign-in or sign-up: a `sessions` row (user, client address, user agent) and the cookie `session_id`: signed, permanent, HTTP-only, same-site lax, and `secure` whenever the request is HTTPS (`request.ssl?`). With `COLLECTOR_HTTPS=true` the production app assumes and forces SSL, so a TLS-terminating proxy gets the secure flag too; the README says that signing in over plain HTTP is only acceptable on a trusted private network (spec 004 FR-2, NFR Security; `config/environments/production.rb`).
- **Resumed** on every request by looking the cookie up: a cookie that doesn't verify, or names a row that is gone, is no session, and the request is treated as signed out (`resume_session`).
- **Ended** by: signing out (the current session only: its row and cookie go, and the redirect to sign-in is 303) (spec 004 AC-4.7, FR-2); an admin setting a user's new password, or the operator command setting an existing user's, which ends all that user's sessions (spec 004 AC-5.3, AC-5.7); deleting the user, which removes the sessions with it (spec 004 FR-3, AC-5.4); a restore, which ends every session (spec 030 decision 3, AC-2.1, AC-2.4; [release and deploy](release-and-deploy.md)). A user's other changes (name, email, admin flag) end none. Nothing else ends one: sessions have no expiry (see Decisions).
- **What ends with it:** a session's bulk selection and its pending Undo go with it by the database's `ON DELETE CASCADE`, since the ways above include `delete_all`, which runs no callbacks (spec 006 FR-4, FR-6; `Session`).

### The admin users page (`/admin/users`)

Admin only; a member gets 404 for every page and action (spec 004 AC-5.6, FR-5; `AdminOnly`). The header's account menu and More show "Users and sign-up" (and "Catalog" and "Jobs") to admins and to no one else, and "Sign out" to every collector (spec 004 AC-2.4; spec 015 AC-7.3). The page lists every user ordered by name with email, "Admin" or "Member" and the number of copies, the sign-up setting and its button, and an "Add a user" action (spec 004 AC-5.1).

| Action | Result |
|---|---|
| Create (name, email, password, admin checkbox) | A user with its own new account who can sign in; 422 with a message per field for an invalid one (spec 004 AC-5.2, AC-4.3) |
| Edit name, email, admin flag, or a new password | Saved under AC-4.3's rules (the password has no confirmation; left blank it is unchanged). A new password replaces the old at once and ends that user's sessions (spec 004 AC-5.3) |
| Remove the admin flag from the only admin | Refused: the form shows "Admin can't be removed: Collector needs at least one admin."; nothing changes (spec 004 AC-5.5; `User#keeps_an_admin`) |
| Delete another user | A confirmation page (it works without script): "This permanently deletes <name>'s account and all <n> copies in their collection. It can't be undone."; confirming removes the user, their account, their sessions and everything the account owns, and changes no other account (spec 004 AC-5.4, FR-5) |
| Delete oneself | Refused with "You can't delete your own account."; the page offers no link for it (spec 004 AC-5.5) |

Deleting a user destroys the account, which deletes its lots first and then its locations, because a lot's place blocks deleting the location (`Account` declares `lots` before `locations`; `spec/models/account_spec.rb`; spec 032 AC-6.6), and destroys its scanner sitting, number entry and stored import upload with their callbacks; the lines and the sitting's entries go by their parents' `delete_all`, and `bulk_selections`, `bulk_removals` and `bulk_selection_marks` by `ON DELETE CASCADE` (the foreign keys of every account-owned table but `lots` cascade too; `lots` has none, so `Account` deletes them itself) (spec 004 FR-3, AC-5.4; spec 029 AC-4.6). Every table above has a foreign key to its account.

### The operator command

`bin/rails "collector:user[EMAIL]"` (Compose: `docker compose exec web bin/rails …`, Kamal: its alias; the README documents both) (spec 004 AC-5.7, FR-4). The password comes from `COLLECTOR_PASSWORD`, else is asked for when run in a terminal, else is generated and printed once (`SecureRandom.base58(24)`: 24 characters; at least 16 are required). If a user has the email (stripped, lower-cased), their password is set and their sessions ended; otherwise an admin with its own account is created, named for the part of the email before "@". Creating the first user closes sign-up and stops the first-run redirect, so an operator can create the admin from the shell instead of a browser (spec 004 AC-3.6, FR-4). An email or password that fails the rules makes it exit 1 and change nothing, because the work is one transaction (spec 004 AC-5.7).

## Named constants

| Name | Value | Defined in | Why this value | Source |
|---|---|---|---|---|
| `User::PASSWORD_MINIMUM` | 12 | `app/models/user.rb` | The shortest password; a sign-up and a user form check it, a blank password on an edit leaves it unchanged | spec 004 AC-4.1, AC-4.3, FR-2 |
| `User::EMAIL_FORMAT` | `/\A[^@\s]+@[^@\s]+\z/` | `app/models/user.rb` | Exactly one "@" with text on both sides and no whitespace | spec 004 AC-4.3 |
| A name's length | 1 to 100 characters, stripped | `app/models/user.rb` | Blank or over 100 is refused | spec 004 AC-4.3 |
| Sign-in rate limit | 10 attempts within 3 minutes, per client address and email | `SessionsController` | Keyed on both, so one address's failures don't refuse another's attempts and one email's don't count against another (the criterion's own conditions) | spec 004 AC-4.8 |
| `Registration::PERMITTED` | `name`, `email_address`, `password`, `password_confirmation` | `app/models/registration.rb` | The only parameters a sign-up reads; never an account, user or admin value | spec 004 AC-12.3 |
| The session cookie | `session_id`: signed, permanent, HTTP-only, same-site lax, `secure` when `request.ssl?` | `app/controllers/concerns/authentication.rb` | The cookie can't be read by script or sent from another site's forms; secure on HTTPS | spec 004 NFR Security |
| Generated password | `SecureRandom.base58(24)` | `lib/tasks/collector.rake` | The command's password when none is given or typed; at least 16 characters are required | spec 004 AC-5.7 |
| `COLLECTOR_PASSWORD` | the command's password | `lib/tasks/collector.rake` | The documented variable the command reads first | spec 004 AC-5.7 |
| `COLLECTOR_HTTPS` | `true` makes production assume and force SSL | `config/environments/production.rb` | Marks the session cookie secure behind a TLS-terminating proxy; passed through by `compose.yaml` and `config/deploy.yml` | spec 004 FR-2, NFR Security |
| `COLLECTOR_TRUSTED_PROXIES` | IPs or CIDRs, comma-separated, added to Rails' private ranges | `lib/collector/trusted_proxies.rb`, `config/application.rb` | Whose `X-Forwarded-For` counts as the client address for the rate limit | spec 004 AC-4.8, FR-2 |

## Decisions not in an ADR

- **The user holds the account, and the account is created with the user.** There is no way to create an account without a user, and none to give a user a second one (spec 004 FR-3, Open Questions "minimal accounts and sign-in, one user per account"; ADR 0017).
- **The admin sees counts and nothing inside.** The admin users page shows each account's copy count and the delete confirmation says how many copies it will remove; nothing lists, opens or edits a collection (ADR 0017 Consequences; spec 004 AC-5.1, AC-5.4). That is the one deliberate cross-account read of spec 004.
- **Another account's data is "not found", not "forbidden",** and a member's request for an admin page answers the same 404 (spec 004 AC-12.2, AC-5.6, Error Scenarios; the spec states the status, not a reason).
- **First run is a redirect to sign-up, and the first visitor to an upgraded instance is the admin,** because an upgraded instance has no user (spec 004 NFR Reliability). The README's upgrade notes warn of it before the upgrade steps, and the operator can instead create the admin from the shell, which stops the redirect (spec 004 Open Questions "First run (after review)", AC-3.5, AC-3.6, FR-4).
- **Sign-up is closed once the first user exists, and one admin action opens or closes it** from the app, not an environment variable (spec 004 Open Questions "Sign-up", FR-3, FR-4, FR-5).
- **No email, so no password reset by email.** A user can't change their own name, email or password; the admin, or the command for the operator, does it. Self-service profile and email are out of scope for later features (spec 004 Non-Goals, Out of Scope, Open Questions).
- **A new password ends the user's sessions; other edits don't.** Changing an email, name or the admin flag leaves sessions alone; an admin loses the pages the moment their flag is removed, because `AdminOnly` checks the flag on every request (spec 004 AC-5.3, NFR Security "Admin-only actions check admin status on the server").
- **Signing out ends only the current session,** so another browser stays signed in (spec 004 FR-2).
- **The rate limit is per email and client address,** and behind a trusted proxy the address is the one the proxy forwards, not the proxy's own (spec 004 AC-4.8, Open Questions "Rate limit").
- **The ownership rule for Active Storage is "a record of the signed-in account holds the blob,"** by `account_id`, because the only upload today is the import preview's stored file; the first image upload extends it to variants and previews (ADR 0022; spec 028 decision 8). Rails' route helpers aren't visible to Active Storage's controllers, so the gate redirects to sign-in through `main_app`.
- **Five behaviours have no spec source.** None is written down anywhere: a session never expires (a permanent cookie, no expiry, no sweep); `sessions.ip_address` and `user_agent` are stored and read by nothing; `InstanceSetting.current` is `first || create!` with nothing making it one row; the sign-in rate limit's counters live in the cache, so a cache clear resets them; and a sign-up that omits `password_confirmation` isn't checked for a match (`has_secure_password` checks it only when present). They are open for a ruling in [#218](https://github.com/plainprogrammer/Collector/issues/218); a ruling changes this doc's States and its Accepted limits.

**Accepted limits and open issues:**

- A session lasts until it is ended; a lost phone keeps its access until an admin resets the password or the user is deleted ([#218](https://github.com/plainprogrammer/Collector/issues/218), no spec source).
- A member can't change their own name, email address or password (spec 004 Non-Goals); an admin who forgets theirs uses the command (spec 004 AC-5.7).
- An account has exactly one user. Personal and household collections side by side will supersede that half of ADR 0017, with an export format version bump and migrations (ADR 0017 Consequences; [north star](../north-star.md)).
- No account-scoped job or broadcast exists, so the rule that one carries and restores the account has no code behind it yet (ADR 0017).
- The sign-in rate limit is only as lasting as the cache that holds it ([#218](https://github.com/plainprogrammer/Collector/issues/218), no spec source).
- `sessions.ip_address` and `user_agent` are stored and read by nothing ([#218](https://github.com/plainprogrammer/Collector/issues/218), no spec source).

## Sources

- [Spec 004](../specs/004-design-system-collection/spec.md): Story 3, Story 4, Story 5, Story 12 (AC-12.4 and the rule behind AC-12.1–AC-12.3, AC-12.5, whose lots are [collection and lots](collection-and-lots.md)'), FR-2 (its supersession of 002 FR-7 is [catalog core](catalog-core.md)'), FR-3, FR-4, FR-5, AC-2.4's admin entries and AC-2.6, NFR Security, NFR Reliability's first run, the Error Scenarios rows for sign-in, sign-up, first run, admin actions and another account's lot, and Open Questions for accounts, sign-up, first run, rate limit and the session cookie. Its design-system stories and FRs (Story 1, Story 2 but for AC-2.4 and AC-2.6, FR-1, FR-11–FR-13) are the [design system](../design-system/README.md)'s.
- [ADR 0017](../adr/0017-row-level-tenancy-one-user-per-account.md); [ADR 0022](../adr/0022-stored-import-upload-retention.md) (the ownership rule); [ADR 0001](../adr/0001-browser-ocr-engine-and-asset-hosting.md) and [ADR 0007](../adr/0007-art-search-in-the-browser.md) (the two public files).
- [Spec 015](../specs/015-admin-catalog-and-jobs/spec.md): AC-7.1, AC-7.3 (the admin gate on `/admin/catalog` and `/admin/jobs`, and their More links); the pages are [catalog operations](catalog-operations.md)'.
- [Spec 023](../specs/023-signed-out-catalog-browsing/spec.md): FR-1–FR-4, AC-2.3, AC-3.7 as far as who is a visitor and which endpoints skip sign-in; the rest is [catalog core](catalog-core.md)'.
- [Spec 007](../specs/007-card-scanner-live-capture/spec.md) AC-2.2, AC-5.1, AC-5.6, FR-6 and [spec 011](../specs/011-card-scanner-art-matching/spec.md) Story 4, AC-4.4 (the public files and measurement mode's sign-in exemption). [Spec 028](../specs/028-apply-import/spec.md) decisions 8, 9 (the gate; the sweep); [spec 029](../specs/029-manage-locations/spec.md) AC-4.5, AC-4.6; [spec 032](../specs/032-lot-in-a-location/spec.md) AC-6.6; [spec 006](../specs/006-collection-list-view/spec.md) FR-4, FR-6 (a session's selection and Undo end with it).
- [North star](../north-star.md): the hosted-door rules, "The operator is not the user" and "Collector choices are stored per account or user".
- [`.claude/rules/multi-tenancy.md`](../../.claude/rules/multi-tenancy.md) and [`.claude/rules/security.md`](../../.claude/rules/security.md): where the coding rules stay.
- Issues: open: [#218](https://github.com/plainprogrammer/Collector/issues/218) (five behaviours with no spec source).

## Distillation log

| Date | Distilled | Pull request |
|---|---|---|
| 2026-11-06 | The accounts parts of spec 004 (Stories 3, 4, 5 and 12; FR-2–FR-5; NFR Security), ADR 0017, and CLAUDE.md's row-level tenancy paragraph | #106's pull request |
