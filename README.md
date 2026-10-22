# Collector

Collector is a self-hostable, multi-tenant web app for tracking collectibles, starting with
Magic: The Gathering. Each person signs in to their own account and keeps their own collection.
Cards come from a catalog fed from Scryfall's bulk data (see [Card catalog](#card-catalog)): you
find a card by searching the catalog, or by reading it with the [card scanner](#card-scanner) on
a phone, and add it to your collection. An admin manages users and sign-up (see
[Accounts](#accounts)), starts and watches the catalog's refreshes, and sees, retries and
discards background jobs. Collector is pre-1.0; the [roadmap](docs/roadmap.md) says what is
built next.

Built with Rails 8.1, SQLite, and Hotwire (Turbo + Stimulus via importmap and Propshaft; no
Node.js). Background jobs, caching, and Action Cable use Solid Queue, Solid Cache, and Solid
Cable, all backed by SQLite.

## Requirements

- Ruby 4.0.7 (see `.ruby-version`)
- SQLite is provided by the `sqlite3` gem; no separate database server is needed
- Firefox, for the system specs (run headless)
- libvips, for Active Storage image variants (ADR 0013): `sudo dnf install vips` on Fedora,
  `sudo apt install libvips` on Debian or Ubuntu. `bin/setup` says so when it's missing
- ImageMagick, for the card scanner's art index build (ADR 0012): `sudo dnf install ImageMagick`
  on Fedora, `sudo apt install imagemagick` on Debian or Ubuntu

## Development

```sh
bin/setup   # install gems, prepare the database, then start the server
bin/dev     # start the server on http://localhost:3000 (another port in a worktree)
```

`bin/setup --skip-server` prepares everything without starting the server. `bin/setup` is
idempotent; run it again after pulling changes.

Development mirrors production: the app uses separate SQLite databases in `storage/`
(`development`, `development_cache`, `development_queue`, `development_cable`), and Solid Queue
runs inside Puma. `bin/dev` (or `bin/rails server`) therefore already processes background
jobs. Do not also run `bin/jobs`, as that starts a second supervisor on the same queue database.

### Worktrees

`bin/setup` also prepares git worktrees, so several branches can run side by side. Run it
once in your clone: it points `core.hooksPath` at the versioned `.githooks/` directory, and
from then on every new worktree runs `bin/setup --skip-server` automatically. This covers
plain `git worktree add`, `claude --worktree`, and Orca worktrees (local or remote); Orca
also runs the same command through `orca.yaml`. The hook ignores ordinary branch switches,
file checkouts, and the main checkout (including `git clone`), and concurrent runs in one
worktree are serialized (`tmp/setup.lock`), so running it twice is safe.

Enabling this replaces the clone's default `.git/hooks/` directory: setup lists any active
hooks there that stop running. An existing custom `core.hooksPath` is left alone, and
automatic setup stays off; run `bin/setup` in each new worktree yourself.

- **Copied from the main checkout:** the files listed in `.worktreeinclude`
  (`config/master.key` and `tmp/local_secret.txt`), only when missing in the worktree and
  with mode 0600. Existing files are never overwritten. If Orca's `ORCA_ROOT_PATH` disagrees
  with git about where the main checkout is, setup prints a notice and uses git's answer.
- **Regenerated per worktree:** the development databases (primary, queue, cache, cable),
  the test database, caches, logs, and pids. Nothing is shared between worktrees.
- **Ports:** the main checkout serves on 3000; each worktree gets a stable port in
  3001–3999, derived from its path and printed by `bin/setup`. Set `PORT` to override it,
  for example if two worktrees happen to get the same port.
- **Credentials:** a remote Orca runtime has no copy of your local `config/master.key`, so
  setup warns and continues; development and the specs work without it. Copy the key there,
  or set `RAILS_MASTER_KEY`, if you need credentials. A missing key only warns, but a wrong
  key makes the app fail to boot.
- **Failures:** if automatic setup fails, the worktree is still created; run `bin/setup` in
  it to finish.

### Card scanner on a phone

`bin/setup` also runs `bin/fetch-ocr-engine`, which downloads the card scanner's OCR engine (about 15 MB) from
`registry.npmjs.org`, checks every file against a pinned SHA-256 and keeps it in `vendor/ocr/` (ignored by git).

The scanner is at `/scanner` ("Scan" in the navigation). Browsers only allow a live camera on HTTPS (or on
`localhost`), so to use it from a phone on your network, serve the dev server over HTTPS with a self-signed
certificate that the phone trusts:

```sh
bin/dev-certificate          # creates or reuses the certificate; prints the next command for your worktree's port
bin/dev -b "ssl://0.0.0.0:3000?key=$HOME/.local/share/collector-dev-https/dev.key&cert=$HOME/.local/share/collector-dev-https/dev.crt"
bin/dev-certificate --serve  # in another terminal: serves only the certificate on port 3579 until you press Ctrl-C
```

Then, once per certificate, on the iPhone:

1. In Safari, open the download URL that `bin/dev-certificate --serve` prints (`http://<your address>:3579/`) and allow the profile.
2. Settings → General → VPN & Device Management: install the profile.
3. Settings → General → About → Certificate Trust Settings: turn on full trust for the certificate.
4. Open `https://<your address>:<port>/scanner` in any browser.

- The key and certificate stay outside the repository, in `~/.local/share/collector-dev-https/`
  (`COLLECTOR_DEV_CERT_DIR` overrides it). Only the certificate is ever served; the key never leaves your machine.
- The certificate names your machine's local network addresses (or the ones you pass as arguments). Run
  `bin/dev-certificate` again after the address changes; it makes a new certificate, which the phone must trust again.
- Puma ends TLS itself, so Rails sees real HTTPS and needs no other setting.
- An HTTPS tunnel of your choice also works: set `RAILS_DEVELOPMENT_HOSTS` to the tunnel's host names
  (comma-separated) and `COLLECTOR_HTTPS=true` (the tunnel ended TLS), then run `bin/dev`.
- Over plain HTTP from another device, the page offers a photo instead.

**Measurement mode** (development only) records live captures of known cards for the scanner's findings, at
`/scanner/measurement`. It reads the manifest at `COLLECTOR_SCANNER_MANIFEST` (default
`~/card-scanner-corpus/manifest.csv`, columns `file,set,number,foil[,era]`) and stores each capture's text and
strip images under `COLLECTOR_SCANNER_RUN_DIR` (default `~/card-scanner-corpus/runs/live`), outside the
repository. `bin/rails scanner:findings` scores a run; `bundle exec ruby script/scanner/replay.rb <label>`
re-reads its strips on the desktop (`SCANNER_URL=https://127.0.0.1:<port>` points it at an HTTPS server).
`SCANNER_EMAIL=… SCANNER_PASSWORD=… bundle exec ruby script/scanner/photo_run.rb` replays the photos beside the
manifest through the scanner's photo picker, storing each as a capture. For a sitting scanned and added in
measurement mode, `SCANNER_EMAIL=… GROUND_TRUTH=… bin/rails scanner:sitting_findings` scores what each card ended as
(run it before pressing Done).
`COLLECTOR_REQUEST_LOG=1` logs each response's size to `log/requests.jsonl`.

## Testing and CI

```sh
bin/rspec                                       # full suite
bin/rspec spec/requests/health_check_spec.rb:5  # a single file or example
```

The suite uses RSpec, FactoryBot, and Capybara. System specs run in headless Firefox; on the
first run Selenium Manager downloads geckodriver, which needs network access. WebMock and VCR
block all real HTTP from specs (cassettes live in `spec/cassettes`).

`bin/ci` is the single CI definition (`config/ci.rb`). It runs every step and exits non-zero,
naming the steps that failed:

1. Setup (`bin/setup --skip-server`)
2. Style: `bin/rubocop` (rubocop-rails-omakase + rubocop-rspec)
3. Security: `bin/brakeman`
4. Security: `bin/bundler-audit`
5. Security: `bin/importmap audit`
6. Tests: `bin/rspec`

GitHub Actions (`.github/workflows/ci.yml`) runs `bin/ci` first, so local and hosted CI are the same; it then
builds the container image for amd64 and arm64 and, on `main` and release tags, publishes it (see
[Self-hosting](#self-hosting) and `docs/releasing.md`). Dependabot keeps gems and GitHub Actions up to date.

## Self-hosting

Two deployment paths are supported: Docker Compose for a single machine, and Kamal for
deploying to your own servers. Both run the published image `ghcr.io/plainprogrammer/collector`
(built from the `Dockerfile` in this repository for amd64 and arm64) and keep all data in SQLite
on a persistent volume. `latest` is the newest release; `edge` follows `main`. Releases and their
tags are described in `docs/releasing.md`.

> **Before you expose Collector:** the first person to reach a new or freshly upgraded instance becomes its admin. Either sign up straight away while the instance is only reachable on your private network, or create the admin from the command line first (see [Accounts](#accounts)).

### Docker Compose

`compose.yaml` works with both `docker compose` and `podman compose`, and needs no checkout: download
the file and start it.

| Variable                    | Required | Default               | Purpose                                                                                                                               |
| --------------------------- | -------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `SECRET_KEY_BASE`           | yes      | none                  | Secret used to sign and encrypt sessions and cookies                                                                                  |
| `COLLECTOR_PORT`            | no       | `3000`                | Host port the app is published on                                                                                                     |
| `COLLECTOR_IMAGE`           | no       | `ghcr.io/plainprogrammer/collector:latest` | Image to run; set it to a tag such as `ghcr.io/plainprogrammer/collector:0.1` to pin a release, or to a locally built image |
| `COLLECTOR_MTG_LANGUAGES`   | no       | English only          | Extra card languages, e.g. `ja,de` (see [Card catalog](#card-catalog))                                                                |
| `COLLECTOR_MTG_ART_MATCHING` | no       | off                   | `true` turns on art matching for the card scanner (see [Card catalog](#card-catalog))                                                 |
| `COLLECTOR_PUBLIC_CATALOG`  | no       | off                   | `true` lets people who aren't signed in search the catalog and open card pages (see [Open catalog](#open-catalog))                   |
| `COLLECTOR_CURRENCY`        | no       | `USD`                 | Currency for the price you paid: USD, CAD, AUD, NZD, EUR, GBP, CHF, SEK, NOK, DKK, PLN, CZK, JPY, CNY, KRW, SGD, HKD, BRL, MXN or ZAR |
| `COLLECTOR_HTTPS`           | no       | `false`               | Set to `true` when Collector is served over HTTPS (secure cookies, redirect to HTTPS)                                                 |
| `COLLECTOR_TRUSTED_PROXIES` | no       | Rails' private ranges | Extra reverse proxies (IPs or CIDRs, comma-separated) whose `X-Forwarded-For` is trusted                                              |

Changing `COLLECTOR_CURRENCY` later doesn't convert prices you've already entered; they're shown with the new symbol. An unsupported code stops the app at boot, naming the setting.

Compose refuses to start without `SECRET_KEY_BASE`. Generate one with:

```sh
openssl rand -hex 64
# or, without openssl:
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Set the variables in your shell or in a `.env` file next to `compose.yaml`, then start it:

```sh
docker compose up -d     # or: podman compose up -d
```

The app is then available at `http://localhost:3000` (or your `COLLECTOR_PORT`).

- **Data:** all four production SQLite databases live in the named volume
  `collector_storage`, mounted at `/rails/storage`. Back it up with Collector's own command, not by copying
  the files of a running instance: see [Backup and restore](#backup-and-restore).
- **Jobs:** Solid Queue runs inside the web process; no separate worker is needed.
- **Health:** the container has a healthcheck on `/up`, and runs as a non-root user (uid 1000).
- **Upgrades:** `docker compose pull && docker compose up -d`. Database migrations run automatically
  when the container starts.
- **Building from source:** `docker build -t collector:local .` in a checkout, then start Compose with
  `COLLECTOR_IMAGE=collector:local`.
- **HTTPS:** the Compose setup serves plain HTTP. Signing in over plain HTTP sends your password unencrypted, which is only acceptable on a trusted private network. Put an HTTPS reverse proxy (for example Caddy, nginx, or Traefik) in front of it and set `COLLECTOR_HTTPS=true`.
- **Upload limit:** the app refuses a request body over 40 MB (Puma and Thruster), which is more than the largest export file it imports (32 MB). A reverse proxy in front may set a lower limit of its own; keep it at 40 MB or more.

### Kamal

Kamal (`bin/kamal`) deploys the same image to servers you control over SSH.

1. Edit `config/deploy.yml`: replace the placeholder server (`192.168.0.1`) with your own. The
   registry is already `ghcr.io` with the published image.
2. Secrets come from `.kamal/secrets`, which reads `RAILS_MASTER_KEY` from `config/master.key`
   and the registry password from the `KAMAL_REGISTRY_PASSWORD` environment variable. Kamal
   needs registry credentials even to pull a public image: use a GitHub token with `read:packages`.
3. Check the configuration with `bin/kamal config`.
4. Run `bin/kamal setup --skip-push --version X.Y.Z` for the first deployment, and
   `bin/kamal deploy --skip-push --version X.Y.Z` after that, naming the release to deploy. Kamal
   pulls that tag; nothing is built or pushed.

`config/deploy.yml`'s `proxy:` sets `buffering: max_request_body: 40_000_000`, so kamal-proxy refuses request bodies over 40 MB, as the app does, instead of buffering up to 1 GB to disk.

To deploy an image you build yourself, change `image` and `registry` in `config/deploy.yml` to
a registry you own, then run `bin/kamal deploy`. Never run a plain `bin/kamal deploy` with the
registry set to `ghcr.io/plainprogrammer/collector`: it would push a single-architecture `latest`
over the published image.

Data is stored in the `collector_storage` volume (mounted at `/rails/storage`), and Solid
Queue runs inside Puma (`SOLID_QUEUE_IN_PUMA`). How to back it up and restore it is in [Backup and restore](#backup-and-restore).

### Card scanner

The card scanner ("Scan" in the navigation, at `/scanner`) reads a card with the camera of the phone it runs on, or
from a photo, which it finds and straightens first. You confirm the printing and finish and add the card to your
collection with one tap; the sitting's adds are listed with Undo until you press Done. Photos never leave the phone:
only the text read from the card (and, with art matching on, the ids and distances of the closest artworks) and your add, Undo and printing choices are sent to your instance.
The image build downloads the scanner's OCR engine from `registry.npmjs.org` and checks each file against a pinned
SHA-256; your instance serves it from `/ocr/v7.0.0/`, so phones fetch it from you, not from a third party.
The published image already contains it.

Browsers only allow a live camera on HTTPS; that is the only part that needs it. Without HTTPS,
only the photo picker works, and adding cards from photos works the same way.

- **Docker Compose:** put an HTTPS reverse proxy in front of the app (see **HTTPS** under Docker Compose) and set
  `COLLECTOR_HTTPS=true`.
- **Kamal:** enable the proxy's certificate in `config/deploy.yml` (uncomment `ssl: true` under `proxy:` and set
  your `host:`), and uncomment `COLLECTOR_HTTPS: true` under `env: clear:`.

### Open catalog

By default the catalog needs sign-in, like the rest of the app. Set `COLLECTOR_PUBLIC_CATALOG` to `true` (or `1`,
`yes`, `on`) and people who aren't signed in can search the catalog, open a card's page and see all of a card's
printings ("Show all N printings").
Everything else still needs sign-in: collections, the card scanner, admin pages, and every add or change. A visitor's
catalog pages show no owned counts, no "Not owned" markers and no add buttons, and nothing from anyone's collection.
The header offers "Sign in", which brings them back to the page they were on.

It's off by default, and a hosted instance turns it on: for a paid hosted service, Scryfall's terms ask that the card
data it shows be publicly accessible, with search open to people who aren't signed in (research 016, ruling 27 in
`docs/roadmap.md`).

- **Docker Compose:** set `COLLECTOR_PUBLIC_CATALOG=true` in the environment you start Compose with.
- **Kamal:** uncomment `COLLECTOR_PUBLIC_CATALOG: true` under `env: clear:` in `config/deploy.yml`.

The setting is read at boot, so restart the app after changing it. Every search runs a name match against the whole
catalog, limited only by the query's length (100 characters), so when you open the catalog, rate-limit requests at
your reverse proxy.

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

1. Pull the new image (`docker compose pull`, or pick the release for Kamal).
2. Run `docker compose up -d` (or `bin/kamal deploy --skip-push --version X.Y.Z`). Migrations run when the container starts.
3. Create or claim the admin account as described above.

## Card catalog

Card data comes from [Scryfall](https://scryfall.com)'s bulk data files, which the app
downloads in a background job and caches in its own database. Pages are rendered only from
that local copy; the app never calls Scryfall while rendering a page.

**The catalog is empty until the first refresh.** After the first deployment, sign in as an
admin and open **Catalog** (in the account menu, or under More on a phone). Press
**Refresh now** and the page shows the download and the sync as they go, without reloading.
Until then, search and the scanner say that the catalog hasn't been loaded. Nothing downloads
until you start it or the weekly schedule first runs, so set the languages below first if you want more than English.

You can also queue the refresh from a shell:

```sh
bin/rails "catalog:refresh[mtg]"                          # locally
docker compose exec web bin/rails "catalog:refresh[mtg]"  # Docker Compose (or podman compose)
bin/kamal catalog-refresh                                 # Kamal
```

The command returns straight away; the refresh runs in the background (Solid Queue inside
Puma). To see how it went, list the 10 most recent runs, newest first, with their counts and
any error message:

```sh
bin/rails "catalog:status[mtg]"   # Kamal: bin/kamal catalog-status
```

- **Catalog page:** `/admin/catalog` shows each catalog's cards, its last applied refresh, when
  the next one is scheduled, the running refresh's stage and progress, and its recent runs. A
  refresh whose job has failed or left the queue without ending the run (after a crash, for
  example) is shown as interrupted once it has made no progress for 2 minutes, and so is one
  that stops making progress for 15 minutes; pressing **Refresh now** then starts it again.
- **Jobs page:** `/admin/jobs` lists the app's background jobs that failed, are running, are
  queued or are scheduled. A failed job shows its error and backtrace, and can be retried or
  discarded there. Both pages are for admins only.

- **Schedule:** in production the catalog refreshes weekly, on Mondays at 03:15 UTC
  (`config/recurring.yml`). A scheduled run is skipped when the same Scryfall file and
  language set were already applied (except once, after an upgrade that adds artwork ids); a manual run always applies. Only one refresh per
  collectible type runs at a time.
- **Languages:** set `COLLECTOR_MTG_LANGUAGES` to a comma-separated, case-insensitive list of
  extra languages (for example `ja,de`). The default is English only, and English is always
  included. Accepted codes: `en es fr de it pt ja ko ru zhs zht he la grc ar sa ph qya`.
  Changes take effect at the next refresh. Printings in a language you remove are retired,
  not deleted. An unsupported code fails the refresh before anything is downloaded.
- **Art matching (optional):** set `COLLECTOR_MTG_ART_MATCHING=true` and the card scanner also
  recognises a card by its artwork on live captures. It's off by default because the first
  build costs about 708 MB of downloads (one small image per artwork from Scryfall),
  about 2.6 hours of throttled fetching and then fingerprinting, and leaves an index of
  about 7.3 MB. The build runs in the background after a catalog refresh; to start it now, press
  **Build art index** on the Catalog page, which also shows its progress, or run
  `bin/rails "catalog:refresh[mtg]"` (Kamal: `bin/kamal catalog-refresh`), and follow it with
  `bin/rails "catalog:status[mtg]"`. Later refreshes fetch only new artworks. Until the first
  build finishes, and whenever art matching is off, the scanner works on text alone. Images
  are cached in `storage/catalog/mtg/art`; after turning art matching off you can delete that
  folder to reclaim the space.
- **Disk:** downloads are kept in `storage/catalog/mtg/` on the persistent volume, and only the
  two newest are kept. English only uses Scryfall's `default_cards` file (about 80 MB each);
  any other language needs the `all_cards` file (about 400 MB each). They can always be
  downloaded again, so they don't need backing up.
- **Attribution:** card data and images are © Wizards of the Coast and are provided by
  Scryfall. Collector follows Scryfall's API guidelines.

## Your data

A collector's data has a documented, versioned format: one JSON file that holds their profile,
the currency of their prices, their locations (the named places a collection is kept, managed at
`/locations` from the header or More) and every lot in their collection, keyed by the catalog
source's own ids and never by this instance's. It is defined in
[docs/export-format/README.md](docs/export-format/README.md), with a JSON Schema and example
files beside it. Export is built against it: a collector downloads their collection as one file
from the account menu or More. A collector can preview importing a file from the account menu or
More: the app says what applying it would do and which rows it can't apply, and changes nothing in
the collection. A file that can be applied is kept privately for an hour, so a collector applies it
with one click: the collection then holds exactly the file's lots and, for a version 2 file, exactly its locations, all or nothing, with no undo, so
the page leads to a download of the current collection first. A removal needs a confirmation, and an
apply whose collection changed since the preview is shown again instead of applied. Applying writes in one short transaction (under 4 seconds for 50,000 lots on the development machine); on slow hardware a very large import may briefly hold other writes (a scanner add, a lot edit), so import while nothing else is writing. Exports are format version 2; an instance older than the release that added locations reads one as newer than it can read, while this release reads files of versions 1 and 2 (a version 1 file leaves the locations alone).

A collector's export is not a backup of the instance, and a backup is not a collector's export: [Backup and restore](#backup-and-restore) says which to use for what and how to restore an instance.

## Backup and restore

Everything a collector owns, and the card catalog, is in one SQLite file on your instance's `storage/` volume. A **backup** is one file, made while Collector keeps running, that holds that file as it was at one moment: every account, user, lot and setting, and the catalog. A **restore** puts it onto a new, empty volume before Collector's first start. The backup is yours to keep wherever you like. Collector doesn't schedule, rotate or upload it.

### Export or backup?

| | Export (a collector, in the app) | Backup (you, the operator) |
|---|---|---|
| Whose | One collector's collection | The whole instance: every account, user and setting, and the catalog |
| Made by | The collector, from the account menu or More | The operator, with a command on the host |
| Holds | Profile, currency and lots, keyed by the card source's ids | The primary database as it is |
| Restores into | Any instance of any release, even one with another catalog build; replaces that collector's lots | A new, empty instance of the same release or a newer one |
| Doesn't hold | Passwords, other users, settings, the catalog | Secrets, `COLLECTOR_*` settings, queued jobs, the art index file, downloads |
| Use it for | Moving a collection between instances, a collector's own safety copy, a file they can read ([Your data](#your-data)) | Recovering the instance after a failed disk, moving it to new hardware, a copy before an upgrade |

### What to keep outside the backup

The backup holds no secret, so keep these yourself, apart from the backup file: `SECRET_KEY_BASE` (and, under Kamal, `RAILS_MASTER_KEY`), your `COLLECTOR_*` settings (a restored instance run with another `COLLECTOR_CURRENCY` shows the same prices with another symbol), and your `compose.yaml` or `config/deploy.yml`. Nothing in the database is encrypted with the secrets, so **a lost or changed secret costs only the signed-in sessions**: everyone signs in again with their password.

The file is **sensitive**: it holds every user's password hash and every collection. Collector writes it readable by its owner only; store it privately.

### Back up

Run the command in the running container, with a directory the container's user (uid 1000) can write. Quote the argument for your shell (it can't contain a comma). It prints the file, its size, the schema version, the counts of accounts, users and lots, and how long it took; it stops with a plain message when the directory is missing, isn't writable, has less than twice the database's size free, or the database fails its checks.

**Docker Compose** (the stock `compose.yaml`; `/tmp` is writable in the container):

```sh
docker compose exec web bin/rails "backup:create[/tmp]"
docker compose cp web:/tmp/collector-backup-20261021T142100Z.tar.gz .     # use the name the command printed
docker compose exec web rm /tmp/collector-backup-20261021T142100Z.tar.gz
```

**Podman** (`podman compose` has no `cp`; the container's name differs by tool, so look it up):

```sh
podman compose exec web bin/rails "backup:create[/tmp]"
podman ps --format '{{.Names}}'                    # for example collector_web_1 under podman-compose, collector-web-1 under Compose v2
podman cp collector_web_1:/tmp/collector-backup-20261021T142100Z.tar.gz .
podman compose exec web rm /tmp/collector-backup-20261021T142100Z.tar.gz
```

**With a host directory instead** (Compose; no copy out): make the directory belong to uid 1000 once, then mount it for a one-off run. Rootless Podman shows a bind mount to the container as root-owned unless the mount has `:U` (`-v "$PWD/backups:/backups:U"`) or the container has `--userns=keep-id`.

```sh
mkdir backups && sudo chown 1000:1000 backups
docker compose run --rm -v "$PWD/backups:/backups" web bin/rails "backup:create[/backups]"
```

**Kamal:** the `backup` alias is already in `config/deploy.yml`; the directory it writes to is a volume you add once. First create the directory on the server, owned by uid 1000; only then uncomment the `/srv/collector-backups:/backups` line under `volumes:` and deploy. The line is commented out in the stock file because Docker creates a missing bind-mount directory owned by root, which the container's user (uid 1000) could not write to, and the alias would then refuse.

```sh
ssh root@192.168.0.1 'install -d -o 1000 -g 1000 /srv/collector-backups'
# now uncomment the /srv/collector-backups:/backups line in config/deploy.yml, then:
bin/kamal deploy --skip-push --version 0.1.0     # mounts the directory
bin/kamal backup                                 # backup:create[/backups] in the running container
scp root@192.168.0.1:/srv/collector-backups/collector-backup-20261021T142100Z.tar.gz .
```

The file is mode 0600 and owned by uid 1000 on the server; Kamal logs in as root by default (`ssh:` in `config/deploy.yml`), which can read it. Any other login needs `sudo`.

**When to back up:** before every upgrade, and at least daily for a collection that changes daily. From a host's cron, for example (02:17 every day, clear of Monday 03:00 to 05:00 in the container's time zone, UTC unless you set one, when the weekly catalog refresh writes the most and a backup would hold the database's write-ahead log back):

```cron
17 2 * * * cd /srv/collector && docker compose run --rm -T -v /srv/collector-backups:/backups web bin/rails "backup:create[/backups]" >> /var/log/collector-backup.log 2>&1
```

Keep several, and delete old ones yourself.

### Restore

A restore needs a **new, empty volume** and runs **before the instance's first start**, as a one-off command in a container of the image you will run. It refuses a volume that already holds a Collector database (or the `-wal`, `-shm` or `-journal` file of one, or the queue, cache or cable database) and changes nothing: to restore over a running instance, restore onto a new volume and switch to it. It restores a backup taken by the same release or an older one, which the first start then migrates as any upgrade does; a backup from a newer release is refused. Use the image tag you run (`COLLECTOR_IMAGE`), and a release that has `backup:restore`.

A restore ends every session (everyone signs in again) and drops pending bulk-removal Undos and selections; no collection is lost. It leaves the art index file behind: with art matching on, press **Build art index** on the admin catalog page afterwards, which needs no downloads.

**Docker Compose.** Create the volume without starting Collector, and find its real name (Compose prefixes the project's name; a different project name is a different, empty volume):

```sh
docker compose up --no-start
docker volume ls | grep collector_storage          # for example collector_collector_storage
```

Then get the file in readable by uid 1000, the preferred way (a host directory that belongs to uid 1000, mounted read-only):

```sh
sudo install -d -o 1000 -g 1000 backups-in
sudo cp collector-backup-20261021T142100Z.tar.gz backups-in/ && sudo chown 1000:1000 backups-in/collector-backup-20261021T142100Z.tar.gz
docker run --rm -u 1000 -v collector_collector_storage:/rails/storage -v "$PWD/backups-in:/backups:ro" \
  -e SECRET_KEY_BASE_DUMMY=1 ghcr.io/plainprogrammer/collector:0.1.0 \
  bin/rails "backup:restore[/backups/collector-backup-20261021T142100Z.tar.gz]"
```

or, without a host directory (`docker cp` makes root-owned files, and uid 1000 can't give a file to itself, so one root one-off fixes the owner):

```sh
docker create --name collector-restore -v collector_collector_storage:/rails/storage ghcr.io/plainprogrammer/collector:0.1.0
docker cp collector-backup-20261021T142100Z.tar.gz collector-restore:/rails/storage/
docker rm collector-restore
docker run --rm -u 0 -v collector_collector_storage:/rails/storage ghcr.io/plainprogrammer/collector:0.1.0 \
  chown 1000:1000 /rails/storage/collector-backup-20261021T142100Z.tar.gz
docker run --rm -u 1000 -v collector_collector_storage:/rails/storage ghcr.io/plainprogrammer/collector:0.1.0 \
  bin/rails "backup:restore[/rails/storage/collector-backup-20261021T142100Z.tar.gz]"
```

(The restore never moves or deletes the file you give it; delete it from the volume yourself afterwards.) Then `docker compose up -d`. `SECRET_KEY_BASE_DUMMY=1` stands in for a secret: the restore reads none.

**Podman** is the same with `podman` for `docker` and `podman compose up --no-start`, the root `chown` one-off included. Under rootless Podman give the host directory `:U` (or run with `--userns=keep-id`) as above.

**Kamal.** A restore can't use `kamal app exec` before the first boot: its one-off container needs the role's env file, which only an app boot writes, and the `kamal` network, which only the proxy boot creates. So restore with a plain `docker run` of the exact release over SSH, then deploy that same release:

```sh
bin/kamal server bootstrap
ssh root@192.168.0.1 'install -d -o 1000 -g 1000 /srv/collector-backups'    # a freshly bootstrapped server doesn't have it
scp collector-backup-20261021T142100Z.tar.gz root@192.168.0.1:/srv/collector-backups/
ssh root@192.168.0.1 'chown 1000:1000 /srv/collector-backups/collector-backup-20261021T142100Z.tar.gz && docker run --rm -u 1000 \
  -v collector_storage:/rails/storage -v /srv/collector-backups:/backups:ro -e SECRET_KEY_BASE_DUMMY=1 \
  ghcr.io/plainprogrammer/collector:0.1.0 bin/rails "backup:restore[/backups/collector-backup-20261021T142100Z.tar.gz]"'
bin/kamal setup --skip-push --version 0.1.0
```

Give the exact release as the tag: releases deploy by version, so no `latest` tag is on the server. This path is documented and its container command is tested in CI, but it hasn't been run through Kamal itself.

**After a restore**, before you hand the instance back: compare the counts the command printed (accounts, users, lots) with what you expect; start it; sign in; with art matching on press **Build art index**; check your settings (`COLLECTOR_*`) and your secret.

**A damaged, cut-short or wrong file is refused** with a plain message and the volume is left as it was: a file still being copied, a file from another tool, a collector's export (use **Import collection** for that), a backup of a newer release, a snapshot that fails SQLite's integrity or foreign-key check.

### What Collector doesn't do

It doesn't back up for you (no schedule, no retention, no upload), encrypt the file, restore one account out of a backup, merge a backup into an instance, or restore onto an older release. Other ways to protect the volume exist and Collector doesn't test them: stopping the app and copying the volume, Litestream, and ZFS, LVM or btrfs snapshots. The file's layout, and how to open it with `tar` and `sqlite3` without Collector, are in [docs/backup-restore.md](docs/backup-restore.md#manual-recovery-with-tar-and-sqlite3).

## License

Collector is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
