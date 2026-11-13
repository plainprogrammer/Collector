# Feature 087: The Licences of the Third-Party Software and Assets in the Image, Readable from the App

**Status:** Approved (2026-11-13, Gate A: the coordinator under the maintainer's delegation, v0.3.1)
**Version:** 0.3.1
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 084](../084-version-and-licence-in-app/spec.md) (the licence line and the shared notice partial; frozen, by [catalog core](../../architecture/catalog-core.md)), [spec 007](../007-card-scanner-live-capture/spec.md) and [ADR 0001](../../adr/README.md) (the pinned OCR engine; frozen, by [scanner](../../architecture/scanner.md))
**Branch:** `087-third-party-licences`
**Issue:** [#376](https://github.com/plainprogrammer/Collector/issues/376) (the 1.0 milestone, housekeeping lane)
**ADR:** none. Every decision here is cheap to reverse: a page, a manifest and a guard. The one rule of lasting weight, that the list is read from the running image and not generated at build time, is written in the area docs (decision 3).
**Plan:** [plan.md](plan.md)

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.3.1 | 2026-11-13 | **Gate A: approved** by the coordinator under the maintainer's delegation (2026-11-13): two Fable rounds, nothing blocking after round 2, all findings fixed. The plan states the icon count the guard sees (13: `ls app/views/icons` lists thirteen partials; the first draft's "twelve" was a miscount by eye and was corrected in 0.2.0). No requirement changed |
| 0.3.0 | 2026-11-13 | Spec review round 2 (Fable, Mode A, APPROVE WITH CHANGES, 0 blocking, 3 important, 7 minor) fixed: the pin rule is inverted so a `vendor/javascript` pin or a URL pin can't pass with no entry, and `pin_all_from` directories are checked (decision 3, AC-5.3); a JavaScript entry records its gem's version (decision 3); the Lucide row's version reads "as in lucide-static 1.72.0" (decision 7); the memo's comparison with the build facts, the licence-file regex, AC-1.8's collector clause, AC-2.2's example version and AC-6.1's gem-text check are corrected. No requirement was removed |
| 0.2.1 | 2026-11-13 | The maintainer's ruling on decision 7: option (a), Lucide listed for all thirteen icons on the maintainer's word, with the Feather section; no `unattributed` list. The language data's upstream licence is owed to the maintainer in `verification.md` |
| 0.2.0 | 2026-11-13 | Spec review round 1 (Fable, Mode A, NEEDS REVISION, 4 blocking, 9 important, 8 minor) fixed. **Blocking:** icons are 13 files (decision 7); a manifest entry may declare `text: none` with a reason (decisions 3 and 4); the licence-file rule is an explicit pattern that includes `BSDL` and `LEGAL` (decision 3); OCR and JavaScript entries record the pinned digests so a bump can't leave a stale entry, and how a pin is known to resolve into a gem is stated (decision 3). **Also:** the guard covers a superset of the image's bundle and the image-specific proof is the smoke check (decision 3, AC-6.1); the supersessions of spec 084 are complete (decision 1); the sheets claim is true only once spec 082 merges (decision 1); where the link's address lives (decision 1); where the memo lives and how specs reset it (decision 3); testable AC-1.8; security notes; the base image's packages and Ruby are out of scope with the reason; a new pattern, not `Details` (decision 6); hosted-door rules; `CLAUDE.md`'s Project Status |
| 0.1.0 | 2026-11-13 | First draft from issue #376, the task brief and the maintainer's rulings of 2026-11-13 on its four scope questions (decisions 1 to 4, as recommended; the coordinator's additions in decisions 3 and 5). Decision 7 (the icons) is a question to the maintainer, *(pending)* |

## Problem Statement

Collector's image carries software and assets that other people made, and their licences (MIT, BSD, Apache-2.0, the SIL Open Font License, ISC) ask that their notices travel with the copies. Today nothing in the image or the app says what they are. The repository's `LICENSE` is Collector's own, the footer's licence line names only Collector's licence (spec 084), and spec 084 left the rest out on purpose (decision 8). Someone using an instance, or an operator who ships it, cannot read which third-party works are in the image or under which licences.

What ships, measured on `main` at `cb10f5b6` (the gem figures are from the lockfile's groups minus `development`, the image's bundle, on a development machine; the plan re-measures them on the built page):

- **139 gems** in the image's bundle, all with licence metadata (SPDX-style identifiers: MIT 101, Ruby 26, BSD-2-Clause 26, Apache-2.0 6, BSD-3-Clause 3, and a few others), 131 with a licence-like file in the gem's directory and 8 without (`bundler`, `brakeman`, `hana`, `minitest`, `rubocop-rails-omakase`, `vcr`, `websocket`, `xpath`). The image holds the `test` group too, because the `Dockerfile` sets `BUNDLE_WITHOUT` to `development` only; that is [#408](https://github.com/plainprogrammer/Collector/issues/408)'s, not this spec's (decision 8).
- **The OCR engine** pinned by `Collector::OcrEngine` (`lib/collector/ocr_engine.rb`): `tesseract.js` 7.0.0 and `tesseract.js-core` 7.0.0 (Apache-2.0 each) and the `@tesseract.js-data/eng` 1.0.0 language data, fetched as npm tarballs with pinned digests.
- **The JavaScript the gems serve through importmap**: Turbo (`turbo-rails` 2.0.23, `turbo.min.js`, whose header reads "Turbo 8.0.23, Copyright © 2026 37signals LLC", MIT) and Stimulus (`stimulus-rails` 1.3.4, `stimulus.min.js` and `stimulus-loading.js`, MIT; the files carry no version).
- **Four self-hosted font files** in `app/assets/fonts/collector/`: Fraunces 600, IBM Plex Sans 400 and 600, IBM Plex Mono 400. They are byte-identical to the `@fontsource` packages' 5.3.0 files (checked by SHA-256 on 2026-11-13), which carry the OFL-1.1 text and the copyright lines; the repository itself holds neither.
- **Thirteen inline icons** in `app/views/icons/`, which the design system says follow Lucide (ISC) (decision 7).

Also in the image and not listed here: Ruby and its default gems that have no entry in the lockfile, and the Debian packages the `Dockerfile` installs (libvips, ImageMagick, jemalloc, sqlite3, curl). See the Non-Goals.

> **Terms.** *Component*: one third-party work in the image (a gem, an OCR package, a JavaScript library, a font family, an icon set). *Licence page*: the page this spec adds. *Manifest*: the checked-in file of the components that aren't gems (decision 3). *Licence text*: the text of a component's own licence or notice files. *Image bundle*: the gems the running process has loaded (`Bundler.load.specs`), which in the image is the bundle minus `development`.

## Goals

- Anyone who can reach an instance, signed in or not, can read the third-party components in its image and each one's licence, beside Collector's own licence.
- The page is reached from the licence line (spec 084), so it is one click from every page that carries the small print.
- The list can't go stale: a gem, a pinned engine file, a JavaScript pin, a font that changes, or an icon that is added, without its entry fails `bin/ci`.
- A component whose licence can't be read still shows, with what is known, and never takes the page down.
- The page and its code are the core's and name no collectible.

## Non-Goals

- The licences of the catalog's data: Wizards of the Coast's notice and the Scryfall attribution stay spec 018's, in the footer.
- Checking each licence's compatibility with the AGPL-3.0, or any legal conclusion about what the page satisfies. The page reproduces the notices; it doesn't claim they are enough.
- Changing what the image installs: the test group's gems stay in the image here ([#408](https://github.com/plainprogrammer/Collector/issues/408), decision 8).
- Ruby itself, its default gems that the lockfile doesn't name, and the operating system's packages the `Dockerfile` installs. They come from the base image and `apt`, and carry their own notices there (`/usr/share/doc/<package>/copyright` in the image). The page says so in one sentence (AC-1.4); a list of them is a candidate.
- Generating a file during the image build, or any change to the `Dockerfile` or a workflow (decision 3).
- A machine-readable bill of materials (SPDX or CycloneDX document), a download, or an API for the list.
- The licences of Collector's own code, the design system's tokens and logos, or anything in `public/`; they are Collector's (the AGPL).
- Showing a gem's dependencies as a tree, or a gem's bundled sources beyond what its licence files say.
- A setting that hides the page.

## Users and Context

**Primary users:** an operator or collector who wants to know what is in the image they run, and someone who received a copy of the image or the source and wants the notices that go with it.
**Secondary users:** a maintainer adding a gem, bumping the OCR engine or changing a font, who must be told by CI what the page needs.
**Usage context:** read rarely, on phones and wide screens, mostly by following the licence line's link. A long list.
**User mental model:** an "Open source licences" screen in an app's settings: a list of names and versions, each opening to its licence text.

## Decisions

1. **A core page at `/licences`, linked from the licence line, open to everyone.** *(Ruled 2026-11-13, as recommended; over: a file in the image, both, a link from More only.)* `GET /licences` answers a signed-in collector, a visitor and a request before the first user exists, like the footer it is linked from; it shows no tenant data, so there is nothing to scope. The licence line (spec 084) gains a third sentence, "Read the third-party licences." with "third-party licences" as a link to the page, after "Get the source code." The address is a constant, `Collector::BuildFacts::LICENCES_PATH = "/licences"`, in the line's parts (`licence_parts` is in `lib/`, which has no route helpers), and an example asserts it equals `licences_path` so the route can't move without it. The partial's `rel="noopener"` on this internal link is accepted: it is harmless and keeps one rendering for every link. The link is part of the line's parts, so it is wherever the shared `layouts/notice_lines` partial is: the footer today, and, once spec 082 merges, the sheets of the scanner page, which render that partial (spec 084 decision 12); no scanner file is edited here. There is no file in the image besides the manifest and its text files the page reads (decision 3); the page is the way to read them.
   **Supersedes, in spec 084:** AC-1.4's "No other part of the line is a link" (the line now has three); the full wording of AC-2.1, AC-2.3, AC-2.4 and AC-2.14 (each ends with the new sentence) and decision 2's wording table; AC-2.13's two links; FR-1's "with two links on its fixed words", the Accessibility NFR's "two inline links" and Users and Context's "its only actions are its two links"; decision 12's no-script notice (it renders the partial, so it gains the link); the Non-Goals "a licence page in the app" and "Listing third-party licences"; and the statement in [catalog core](../../architecture/catalog-core.md) that "no other part is a link". Spec 084's decision 8 is carried out here. `bin/image-smoke`'s check of the line is a substring match ("Collector <version> (<short SHA>) is free software") and still holds.
2. **The page lists five kinds of component, and a row holds what its source says.** The sections, in this order: JavaScript, OCR engine, Fonts, Icons (decision 7), Ruby gems. Each row has a heading with the name, the version and the licence identifier(s). A row with readable text is a closed `<details>` whose body holds the home link, a copyright line when the manifest has one, and the licence text as a list of (file name, text) pairs; a gem's files are shown under their file names, a manifest entry's text under its own title, and a JavaScript row shows its gem's files under their file names. Rows are sorted by name, case-insensitively, within a section. The text is escaped plain text in a `<pre>`. A home link is shown only when it is an absolute `http` or `https` address.
3. **Gems are read from the running bundle; everything else comes from one checked-in manifest; a guard keeps them honest.** *(Ruled 2026-11-13, as recommended; over: generating a file at image build, which needs a `Dockerfile` edit.)*
   - **Gems.** The gems are `Bundler.load.specs`, so the list is the image's bundle by construction and has nothing to regenerate. A gem's identifiers are its `licenses`, its home its `homepage`, its texts the top-level regular files of its directory (`full_gem_path`, not its subdirectories) whose names match `/licen[sc]e|copying|copyright|notice|\A(bsdl|legal)(\.\w+)?\z/i`, read as UTF-8 and scrubbed, in name order. The pattern is chosen against the names seen in the bundle, for example `LICENSE`, `LICENSE.txt`, `LICENSE.md`, `LICENCE`, `License.txt`, `MIT-LICENSE`, `LICENSE.MIT`, `APACHE-LICENSE`, `LICENSE.SPECS`, `LICENSE-DEPENDENCIES.md`, `LICENSE.rdoc`, `COPYING`, `NOTICE`, `license_of_rb-readline`, `BSDL`, `LEGAL`, `LEGAL.rdoc`. A file over 1 MiB counts as unreadable (decision 4).
   - **The manifest.** The OCR packages, the JavaScript libraries, the fonts and the icons are in `config/third_party_licences.yml`, read with `YAML.safe_load`, and each licence text in `config/third_party_licences/`, which sits outside `docs/` (`.dockerignore` leaves `docs/` out of the image). An entry names its text files, which must resolve inside that directory, or declares `text: none` with a `reason`. A JavaScript entry takes its text from its gem's licence files instead of a copy. Each entry has a `source`, the place its facts were read (decision 5).
   - **What an entry records, so a change can't leave it stale.** An OCR entry records the pinned tarball's `sha256`, the value in `Collector::OcrEngine::PACKAGES`. A JavaScript entry records its gem with the version it was written against and the SHA-256 of each served file; the guard compares the gem's version with the loaded spec's, so a bump of `turbo-rails` or `stimulus-rails` fails it even when a file is byte-identical. A font entry records the SHA-256 of each file. An icon entry lists its files; it records no digest, because redrawing an icon is a design change and not a change of licence, and it states its version as "as in lucide-static 1.72.0", the release it was compared with (decision 7).
   - **The guard.** A spec in the suite (so in `bin/ci`, with no change to `config/ci.rb`'s steps, a workflow or the `Dockerfile`) fails when:
     - a `PACKAGES` entry's `sha256` is in no manifest entry, or an OCR entry's `sha256` is in no `PACKAGES` entry;
     - an importmap pin whose file isn't Collector's own has no entry, an entry names a pin that is gone, or a recorded digest or gem version differs. For each `Rails.application.importmap.packages` entry (the explicit `pin` lines), the guard finds its asset with `Rails.application.assets.load_path.find(path)` (it returns an asset; the file is `asset.path`); a pin under `Rails.root/app/javascript` is Collector's, and every other pin (a gem's file, a file in `vendor/javascript` that `bin/importmap pin` would download) needs an entry, and a pin that finds no asset (a URL pin, a missing file) fails the guard. Every `pin_all_from` directory (`importmap.directories`) must lie under `app/javascript`. Today the three pins that need an entry are `@hotwired/turbo-rails`, `@hotwired/stimulus` and `@hotwired/stimulus-loading`;
     - a file under `app/assets/fonts/` is in no entry's `files`, an entry lists a file that is gone, or a recorded digest differs (a changed font must be looked at);
     - a file under `app/views/icons/` is in no entry's `files` (decision 7), or an entry lists a file that is gone;
     - a gem has neither licence metadata nor a licence file;
     - an entry names a text file that is missing, empty or outside the directory, or has neither text files nor `text: none` with a reason, or lacks its name, version, identifier or home.
   - **The guard covers a superset of the image.** The suite loads every group, the image all but `development`, so the guard may check a gem the image doesn't hold; that is conservative. What the image really holds is proved by `bin/image-smoke` (Story 6).
   - **Memoised for the process.** `Collector::ThirdPartyLicences.current` builds the list on the first request under a mutex and keeps it in the class, so every later request reads the built value. Like the build facts it is kept for the process, but it is built lazily and held in the class, where `Collector::BuildFacts` is read at boot into `Rails.configuration.x`. A build that raises isn't kept, so the next request tries again. This is safe because nothing it reads changes while the process runs: the bundle is fixed when Bundler sets up, and nothing writes the gems' directories or `config/` at run time; a new gem, engine or font is a new image and so a new process (coordinator's ruling, 2026-11-13). Each forked Puma worker builds its own. In development a code reload drops the memo, which is harmless, and an edit of the manifest shows after a restart. The spec helper `third_party_licences(...)` replaces the value for an example and restores the real one in an `after` hook, so the examples that read the real bundle are never polluted in random order.
4. **A component whose licence can't be read is shown, flagged and never raises.** *(Ruled 2026-11-13, as recommended.)* A row with no readable text shows its identifier(s) and home link when it has them and the words "Licence text not found", with no `<details>`. A licence file that can't be read (missing, unreadable, over 1 MiB) is that case; one that isn't valid UTF-8 is scrubbed and shown. The page never answers 500 because of one component. The guard fails only when a component has neither an identifier nor a text; a gem with an identifier and no file is a legitimate row (today the eight gems named in the Problem Statement), and so is a manifest entry with `text: none`: the OCR language data package, on `main` today, declares MIT but ships no licence text or copyright line, so its entry says `text: none` and why, and its row shows "MIT (as the package declares)" and "Licence text not found" (decision 5).
5. **The manifest says only what a source we can cite says.** *(Coordinator, 2026-11-13.)* A copyright line or licence text that isn't in a cited source is not written from memory; the row then reads "Licence text not found". The sources found on 2026-11-13:
   - Fonts: `@fontsource/fraunces`, `@fontsource/ibm-plex-sans` and `@fontsource/ibm-plex-mono` 5.3.0 on npm (`license` OFL-1.1; each `LICENSE` holds the copyright line and the full OFL-1.1). The four files in `app/assets/fonts/collector/` are byte-identical to the packages' `files/…-latin-…-normal.woff2`. The version a font row shows is the package's, "5.3.0 (Fontsource)", not the typeface's.
   - `tesseract.js` 7.0.0 and `tesseract.js-core` 7.0.0: Apache-2.0, `LICENSE.md` and `LICENSE` in the tarballs the engine already pins. The `.LICENSE.txt` files beside `tesseract.js`'s minified bundles name what is bundled into them (regenerator-runtime, the Node `buffer` module, ieee754, zlib.js); the manifest carries those lines as the engine's notice text.
   - `@tesseract.js-data/eng` 1.0.0: `package.json` says MIT, and the tarball holds no licence file (decision 4).
   - Turbo: the minified file's own header ("Turbo 8.0.23, Copyright © 2026 37signals LLC") and `turbo-rails`'s licence file (MIT); the row shows the library's version and names the gem. Stimulus: `stimulus-rails`'s licence file (MIT); its files carry no version, so the row shows the gem's, "1.3.4 (stimulus-rails)".
6. **The page is a plain page in the shell: no JavaScript, one new pattern.** A collector gets the application header and tab bar (no section current), a visitor gets the brand-only header that sign-in has; the layout's footer follows, as on every page. It is built from `c-main`, `c-pagehead` and `c-list`. The row is a disclosure with a scrolling text box, which no existing pattern is (the design system's `Details` is a fact list, and `c-menu` is a menu), so it is a new pattern: a rule block in `additions.css` and `docs/design-system/components/Licences.md`, as the project's rule for a new pattern says. The page needs no JavaScript and no inline style, so it also renders under a Content-Security-Policy.
7. **Icons: Lucide, on the maintainer's word.** *(Ruled 2026-11-13, option (a): list Lucide for all the inline icons.)* The design system says "use Lucide (ISC-licensed)" and `app/views/icons/` holds thirteen inline SVGs (`_alert`, `_back`, `_check`, `_collection`, `_cross`, `_decks`, `_grid`, `_more`, `_plus`, `_scan`, `_search`, `_star`, `_table`). **That they derive from Lucide is the maintainer's word, not established from the files:** compared on 2026-11-13 with `lucide-static` 1.72.0, only `_check` and `_back` match its `check` and `chevron-left` paths; the other eleven match nothing (older Lucide versions, redrawn, or Collector's own). The manifest has one Lucide entry listing all thirteen files, with the text and copyright line of `lucide-static` 1.72.0's `LICENSE` (ISC, "Copyright (c) 2026 Lucide Icons and Contributors") and, because `check` and `chevron-left` are among the icons that file says derive from Feather, its Feather section (MIT, "Copyright (c) 2013-present Cole Bemis"). Its `source` says so. The guard fails when an icon file is in no entry's `files`. The row's version reads "as in lucide-static 1.72.0": the release whose `LICENSE` is the source, not a claim about which release the icons came from. Should the maintainer later rule some icons are Collector's own, only the entry's `files` and this row change.
8. **No ADR, and the image's contents are #408's.** The test group's gems (`brakeman` under the Brakeman Public Use License, `bundler-audit` GPL-3.0-or-later, `vcr` Hippocratic-2.1 among them) are in the image today, so they are on the page: it lists what the image holds. Whether they should be there is [#408](https://github.com/plainprogrammer/Collector/issues/408); this spec doesn't change `BUNDLE_WITHOUT`, and when #408 lands the page follows by construction.
9. **The page shows exact versions to everyone, on purpose.** An unauthenticated reader learns the version of every gem. That is accepted: the licence line already names the commit, whose `Gemfile.lock` is public (spec 084 decision 2), so the page adds nothing a visitor couldn't read.

## User Stories and Acceptance Criteria

### Story 1: Anyone reads the third-party licences

**As** an operator, a collector or a visitor **I want** to open one page that lists the third-party software and assets in Collector's image **so that** I can read each one's licence.

- [ ] **AC-1.1** Given a signed-in collector When they request `/licences` Then the response is 200 with the application header and tab bar, an `h1` "Third-party licences", and the footer.
- [ ] **AC-1.2** Given no session When `/licences` is requested Then it is 200 with the brand-only header and the footer, whether or not the open catalog is on, and with no redirect to sign-in.
- [ ] **AC-1.3** Given an instance with no users When `/licences` is requested Then it is 200, not a redirect to sign-up.
- [ ] **AC-1.4** Given the page When it is read Then it opens with a sentence saying Collector is free software under the AGPL-3.0 (linked to the licence's text as the footer's is) and that what follows ships in the image under its own licence, one sentence saying Ruby and the operating system's packages in the image carry their notices in the image (`/usr/share/doc/<package>/copyright`), then the sections JavaScript, OCR engine, Fonts, Icons and Ruby gems, in that order, each heading with its count.
- [ ] **AC-1.5** Given any component When its row is read Then the heading shows its name, its version and its licence identifier(s), and a component with readable text has a closed `<details>` holding the home link (when absolute `http(s)`), the copyright line (when the manifest has one) and the text, escaped, in a `<pre>`, one per file under its file name.
- [ ] **AC-1.6** Given a stand-in bundle of specs with known identifiers and licence files (including one named `BSDL` and one `MIT-LICENSE`) When the page is rendered Then every gem has a row with the identifiers its `licenses` list gives, and each matching top-level file of its directory under its file name, and no subdirectory's file.
- [ ] **AC-1.7** Given a gem whose licence text holds `<script>` or markup When the page is rendered Then it is shown as text and nothing executes.
- [ ] **AC-1.8** Given the reader When `.current` is called twice Then it returns the same object and the builder ran once. Given a visitor When `/licences` is requested Then the request runs no database query (`require_first_user` is skipped, and with no cookie no session is looked up). Given a collector Then the action and its view run no query beyond those a signed-in page with the same header and footer runs. Given any request Then no outbound call is made.
- [ ] **AC-1.9** Given the suite's real bundle and manifest When the page is rendered Then its HTML is at most 1 MiB (a ceiling set against the 394 KB of licence texts measured on the image's bundle, about 0.45 MiB with markup, to be measured on the built page in the plan; a bundle that outgrows it fails the example, and raising the ceiling is then a decision).
- [ ] **AC-1.10** Given the page When it is opened at 360px wide and in both themes Then nothing scrolls sideways, the headings wrap, and a long licence text scrolls inside its own box.

### Story 2: The licence line reaches the page, wherever the small print is

- [ ] **AC-2.1** Given any page with the footer, signed in or not When its licence line is read Then it ends "Read the third-party licences." with "third-party licences" a link to `/licences`, and the line's other two links are unchanged ("AGPL-3.0" and "source code").
- [ ] **AC-2.2** Given each reading of the build facts in spec 084's table When the line is read Then each ends with the new sentence (supersedes the full wording of spec 084 AC-2.1, AC-2.3, AC-2.4 and AC-2.14), and a build version equal to `third-party-licences`, `AGPL-3.0` or `source-code` still can't move or drop a link (spec 084 AC-2.13; now three links).
- [ ] **AC-2.3** Given `Collector::BuildFacts::LICENCES_PATH` When it is compared with `licences_path` Then they are equal.
- [ ] **AC-2.4** Given the shared partial `layouts/notice_lines` rendered on its own, as a focused page's sheet foot renders it When it is read Then it contains the link to `/licences`; the link comes from the line's parts, so no scanner file is edited. Given the scanner page, which today has the footer, under the Content-Security-Policy it sends When it is rendered Then the link is there and the policy is unchanged.
- [ ] **AC-2.5** Given the page opened from the link When it is rendered Then its footer's licence line appears once.
- [ ] **AC-2.6** Given the core's footer code and the page's files (the controller, the view, `Collector::ThirdPartyLicences`, the manifest and the files in `config/third_party_licences/`) When they are searched, case-insensitively, for "mtg", "magic", "wizards", "scryfall" and "fan content" Then none is found (`spec/licences_core_spec.rb`, as `spec/footer_core_spec.rb`).

### Story 3: What each kind of component shows

- [ ] **AC-3.1** Given the OCR engine When the page is read Then it lists `tesseract.js` 7.0.0 and `tesseract.js-core` 7.0.0 under Apache-2.0 with the full Apache text and, for `tesseract.js`, the bundled-library notice lines, and `@tesseract.js-data/eng` 1.0.0 as in AC-4.2.
- [ ] **AC-3.2** Given the JavaScript the importmap serves from gems When the page is read Then Turbo (8.0.23, naming `turbo-rails`) and Stimulus ("1.3.4 (stimulus-rails)") are listed under MIT with the licence files of their gems, and the Turbo row's copyright line is the one its file header carries.
- [ ] **AC-3.3** Given the fonts When the page is read Then Fraunces, IBM Plex Sans and IBM Plex Mono are listed under OFL-1.1 as "5.3.0 (Fontsource)", each with the copyright line and full OFL-1.1 text of its `@fontsource` 5.3.0 package, and the files in `app/assets/fonts/collector/` each belong to one of them.
- [ ] **AC-3.4** Given a stand-in gem with several licence-like files When it is read Then each file is shown under its own file name.
- [ ] **AC-3.5** Given the icons When the page is read Then one Lucide row is listed under ISC with its text and copyright line and the Feather section, and the files in `app/views/icons/` each belong to its entry (decision 7).

### Story 4: A component whose licence can't be read

- [ ] **AC-4.1** Given a stand-in gem with identifiers and no licence file When the page is rendered Then its row shows the identifiers, the home link and "Licence text not found", has no `<details>`, and the page is 200.
- [ ] **AC-4.2** Given `@tesseract.js-data/eng` 1.0.0, whose entry says `text: none` When the page is read Then its row shows "MIT (as the package declares)", its home link and "Licence text not found".
- [ ] **AC-4.3** Given a licence file that raises when read, or is over 1 MiB, or holds bytes that aren't UTF-8 When the page is rendered Then the first two show "Licence text not found", the third its scrubbed text, no other row changes and the page is 200.
- [ ] **AC-4.4** Given a gem whose `homepage` is `javascript:…`, empty or relative When the page is rendered Then its row has no home link.

### Story 5: The list can't go stale

- [ ] **AC-5.1** Given a stand-in gem with neither identifier nor licence file When the guard's rule runs on it Then it fails naming the gem.
- [ ] **AC-5.2** Given a `PACKAGES` entry whose `sha256` is in no manifest entry, or a manifest entry whose `sha256` is in no `PACKAGES` entry When the guard runs Then it fails naming it. A `tesseract.js` bump (a new tarball digest, the same package name) fails it.
- [ ] **AC-5.3** Given an importmap pin that isn't under `app/javascript` with no entry, a pin that finds no asset, an entry whose pin is gone, a served file whose digest differs from the recorded one, or a gem whose version differs from the recorded one When the guard runs Then it fails naming it. A `turbo-rails` bump fails it, whether or not a served file changed.
- [ ] **AC-5.4** Given a font file added, removed or changed (its SHA-256 differs) When the guard runs Then it fails naming the file.
- [ ] **AC-5.5** Given an icon file in no entry, or an entry listing a file that is gone When the guard runs Then it fails naming the file.
- [ ] **AC-5.6** Given a manifest entry that names a missing, empty or out-of-directory text file, or has neither text files nor `text: none` with a reason, or lacks a name, version, identifier or home When the guard runs Then it fails naming the entry; an entry with `text: none` and a reason passes.
- [ ] **AC-5.7** Given the guard's own examples When they run Then each rule is shown to fail on a fixture and to pass on the repository's real files, so a guard that stopped checking would fail its own spec.
- [ ] **AC-5.8** Given `bin/ci` When it runs Then the guard runs in the RSpec step with no change to `config/ci.rb`, a workflow or the `Dockerfile`.

### Story 6: The image proves it

- [ ] **AC-6.1** Given an image built by CI When `bin/image-smoke` runs, after the build facts check and before the nothing-unexpected check, Then it requests `/licences` without a session (so also before any user exists), and fails unless the answer is 200 and holds "Third-party licences", "tesseract.js" and "turbo-rails", holds a string that only a gem's licence text supplies ("Permission is hereby granted, free of charge"), and does not hold "yard" as a gem row (a `development` gem the image leaves out), capturing the output first and testing it after, as the other checks do. Exact strings and the gem-row form are fixed in the plan from the rendered page.
- [ ] **AC-6.2** Given the image's licence line When `bin/image-smoke` reads the sign-in page Then its existing check of the line still passes (decision 1's substring) and the page holds the link to `/licences`.

### Story 7: Documents and evidence

- [ ] **AC-7.1** Given the area docs When the work is done Then [catalog core](../../architecture/catalog-core.md) records the licence line's third sentence (and no longer says no other part is a link), the page, the reader and the manifest; [release and deploy](../../architecture/release-and-deploy.md) the smoke check; [tenancy and accounts](../../architecture/tenancy-and-accounts.md) the endpoint that skips sign-in; the design system `Footer.md` the new link and `Licences.md` the page; each statement with its source inline.
- [ ] **AC-7.2** Given `README.md`, `CLAUDE.md` and `docs/roadmap.md` When the work is done Then the README says where an operator reads the licences, `CLAUDE.md`'s Project Status names the page, the manifest and the guard (spec 084 AC-5.4's form), and the roadmap's row for #376 is marked in progress and then done.
- [ ] **AC-7.3** Given `docs/specs/README.md` When it is read Then spec 087's row exists, spec 084's row names 087 under "Superseded by" and 087's names 084 under "Supersedes" (both directions).
- [ ] **AC-7.4** Given the pull request When it is opened Then it carries screenshots of the page, desktop and phone, both themes, and a GIF of opening a row and following the licence line's link, embedded by SHA-pinned links.

## Functional Requirements

- **FR-1** A `LicencesController#show` for `GET /licences` that skips sign-in and the first-user redirect, resumes a session when there is one (`before_action :resume_session`, as `OpenCatalog` does: `allow_unauthenticated_access` alone never resumes it), answers HTML only, and holds no state.
- **FR-2** `Collector::ThirdPartyLicences`, a core object that builds the sections from the image bundle and the manifest once per process and returns them as plain values (name, version, identifiers, home, copyright, and a list of (file name, text) pairs, empty when none), never raising for one component.
- **FR-3** `config/third_party_licences.yml` and `config/third_party_licences/*.txt`: the manifest and its texts (decision 3), each entry with its `source` (decision 5).
- **FR-4** The licence line's parts gain the third sentence and the link, through `Collector::BuildFacts::LICENCES_PATH` (decision 1).
- **FR-5** The guard spec and its fixtures (decision 3, Story 5), and the `third_party_licences(...)` spec helper.
- **FR-6** `bin/image-smoke`'s check (Story 6).

## Non-Functional Requirements

- **Performance:** the first request in a process reads about 400 KB of licence files and the manifest (measured: 139 gems, 394 KB, 103 distinct texts); every later request reads only the built list, held for the process (about half a megabyte), and renders and escapes up to 1 MiB of HTML for any visitor with no sign-in. The plan measures the render time of the real page; no fragment cache is added unless that measure asks for one. The page is at most 1 MiB of HTML (AC-1.9), compressed by the proxy as every page is.
- **Security:** every text and name is escaped; a home link is `http(s)` only, with `rel="noopener"` and no `target`; the manifest is read with `YAML.safe_load`; the page reads only files under the gems' directories and `config/third_party_licences/`, by names taken from the bundle and the manifest, never a path from a request. Versions are shown to everyone (decision 9).
- **Accessibility:** each `<details>`'s `<summary>` is the browser's own disclosure button, named by its text; the page keeps one `h1` and an `h2` per section; text contrast and focus ring as the design system's links.
- **Self-hosting:** nothing to configure, no network, no build step; it works offline and from the image as shipped.
- **Collectible-agnostic core:** AC-2.6.

### Hosted-door rules

- Source terms: no source is touched. Operator is not the user: no collection data is shown. Collector choices: none stored. Bounded cost: no query for a visitor; one built list per process, escaped on each request (NFR Performance).
- Export: no collector-owned data is added, so the export format is unchanged.

## Error Scenarios

| Situation | Result |
|---|---|
| A gem has identifiers and no licence file | Row with identifiers, home and "Licence text not found" (AC-4.1) |
| A manifest entry has `text: none` | Row with its identifier "(as the package declares)" and "Licence text not found" (AC-4.2) |
| A licence file is unreadable or over 1 MiB, or not UTF-8 | That row alone shows "Licence text not found", or the scrubbed text (AC-4.3) |
| A gem's homepage isn't an absolute `http(s)` address | The row has no home link (AC-4.4) |
| A gem has neither identifier nor file | The guard fails in CI; the page, if it were served, shows the row with "Licence text not found" and no identifier |
| `config/third_party_licences.yml` is missing or malformed | Boot isn't affected; the build raises on the page's request and the 500 page answers, and every later request tries again (a failed build isn't kept). The guard has already failed in CI, and the manifest is in the image, so this is a build defect, not a runtime state |
| The bundle outgrows the page's ceiling | AC-1.9's example fails in CI |
| An image built before this spec | No `/licences`; the licence line has no third sentence |

## Open Questions

1. **The icons' origin (decision 7).** Ruled as Lucide on the maintainer's word; whether the eleven icons that match nothing are Lucide-derived is not established from the files, and the row does not claim more than the manifest's `source` says.
2. **The OCR language data's licence.** `@tesseract.js-data/eng` 1.0.0 declares MIT and ships no text. The data's upstream licence is owed to the maintainer to confirm, and `verification.md` records it as owed; this spec shows what the package says and nothing more (decisions 4 and 5).

## Out of Scope (Candidates)

- #408: what the image's bundle holds (the test group).
- A list of Ruby and the operating system's packages the image holds.
- An SPDX or CycloneDX document of the same list.
- A review of each licence against the AGPL-3.0.
