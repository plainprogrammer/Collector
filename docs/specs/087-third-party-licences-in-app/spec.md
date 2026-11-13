# Feature 087: The Licences of the Third-Party Software and Assets in the Image, Readable from the App

**Status:** Draft
**Version:** 0.1.0
**Created:** 2026-11-13
**Last Updated:** 2026-11-13
**Depends on:** [spec 084](../084-version-and-licence-in-app/spec.md) (the licence line and the shared notice partial; frozen, by [catalog core](../../architecture/catalog-core.md)), [spec 007](../007-card-scanner-live-capture/spec.md) and [ADR 0001](../../adr/README.md) (the pinned OCR engine; frozen, by [scanner](../../architecture/scanner.md))
**Branch:** `087-third-party-licences`
**Issue:** [#376](https://github.com/plainprogrammer/Collector/issues/376) (the 1.0 milestone, housekeeping lane)
**ADR:** none. Every decision here is cheap to reverse: a page, a manifest and a guard. The one rule of lasting weight, that the list is read from the running image and not generated at build time, is written in the area docs (decision 3).
**Plan:** none yet

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-11-13 | First draft from issue #376, the task brief and the maintainer's rulings of 2026-11-13 on its four scope questions (decisions 1 to 4, as recommended; the coordinator's additions in decisions 3 and 5). Decision 7 (the icons) is a question to the maintainer, *(pending)* |

## Problem Statement

Collector's image carries software and assets that other people made, and their licences (MIT, BSD, Apache-2.0, the SIL Open Font License, ISC) ask that their notices travel with the copies. Today nothing in the image or the app says what they are. The repository's `LICENSE` is Collector's own, the footer's licence line names only Collector's licence (spec 084), and spec 084 left the rest out on purpose (decision 8). Someone using an instance, or an operator who ships it, cannot read which third-party works are in the image or under which licences.

What ships, measured on `main` at `cb10f5b6`:

- **139 gems** in the image's bundle, all with licence metadata (SPDX-style identifiers: MIT 101, Ruby 26, BSD-2-Clause 26, Apache-2.0 6, BSD-3-Clause 3, and a few others), 131 with a licence file in the gem's directory and 8 without (`bundler`, `brakeman`, `hana`, `minitest`, `rubocop-rails-omakase`, `vcr`, `websocket`, `xpath`). The image holds the `test` group too, because the `Dockerfile` sets `BUNDLE_WITHOUT` to `development` only; that is [#408](https://github.com/plainprogrammer/Collector/issues/408)'s, not this spec's (decision 8).
- **The OCR engine** pinned by `Collector::OcrEngine` (`lib/collector/ocr_engine.rb`): `tesseract.js` 7.0.0 and `tesseract.js-core` 7.0.0 (Apache-2.0 each) and the `@tesseract.js-data/eng` 1.0.0 language data, fetched as npm tarballs with pinned digests.
- **The JavaScript the gems serve through importmap**: Turbo (`turbo-rails`, `turbo.min.js`, 37signals, MIT) and Stimulus (`stimulus-rails`, `stimulus.min.js` and `stimulus-loading.js`, MIT).
- **Four self-hosted font files** in `app/assets/fonts/collector/`: Fraunces 600, IBM Plex Sans 400 and 600, IBM Plex Mono 400. They are byte-identical to the `@fontsource` packages' 5.3.0 files (checked by SHA-256 on 2026-11-13), which carry the OFL-1.1 text and the copyright lines; the repository itself holds neither.
- **Inline icons** in `app/views/icons/`, which the design system says follow Lucide (ISC) (decision 7).

> **Terms.** *Component*: one third-party work in the image (a gem, an OCR package, a JavaScript library, a font family, an icon set). *Licence page*: the page this spec adds. *Manifest*: the checked-in file of the components that aren't gems (decision 3). *Licence text*: the text of a component's own licence or notice file. *Image bundle*: the gems the running process has loaded (`Bundler.load.specs`), which in the image is the bundle minus `development`.

## Goals

- Anyone who can reach an instance, signed in or not, can read the third-party components in its image and each one's licence, beside Collector's own licence.
- The page is reached from the licence line (spec 084), so it is one click from every page, the card scanner's sheets included.
- The list can't go stale: a gem, a pinned engine file, a JavaScript pin, a font or an icon that changes or is added without its entry fails `bin/ci`.
- A component whose licence can't be read still shows, with what is known, and never takes the page down.
- The page and its code are the core's and name no collectible.

## Non-Goals

- The licences of the catalog's data: Wizards of the Coast's notice and the Scryfall attribution stay spec 018's, in the footer.
- Checking each licence's compatibility with the AGPL-3.0, or any legal conclusion about what the page satisfies. The page reproduces the notices; it doesn't claim they are enough.
- Changing what the image installs: the test group's gems stay in the image here ([#408](https://github.com/plainprogrammer/Collector/issues/408), decision 8).
- Generating a file during the image build, or any change to the `Dockerfile` or a workflow (decision 3).
- A machine-readable bill of materials (SPDX or CycloneDX document), a download, or an API for the list.
- The licences of Collector's own code, the design system's tokens and logos, or anything in `public/`; they are Collector's (the AGPL).
- Showing a gem's dependencies' dependencies as a tree, or a gem's own bundled sources beyond what its licence files say.
- A setting that hides the page.

## Users and Context

**Primary users:** an operator or collector who wants to know what is in the image they run, and someone who received a copy of the image or the source and wants the notices that go with it.
**Secondary users:** a maintainer adding a gem, bumping the OCR engine or changing a font, who must be told by CI what the page needs.
**Usage context:** read rarely, on phones and wide screens, mostly by following the licence line's link. A long list.
**User mental model:** an "Open source licences" screen in an app's settings: a list of names and versions, each opening to its licence text.

## Decisions

1. **A core page at `/licences`, linked from the licence line, open to everyone.** *(Ruled 2026-11-13, as recommended; over: a file in the image, both, a link from More only.)* `GET /licences` answers a signed-in collector, a visitor and a request before the first user exists, like the footer it is linked from; it shows no tenant data, so there is nothing to scope. The licence line (spec 084) gains a third sentence, "Read the third-party licences." with "third-party licences" as a link to the page, after "Get the source code." The link is part of the line's parts, so it is wherever the shared `layouts/notice_lines` partial is: the footer, and the sheets of a focused page that carries the small print (spec 084 decision 12). There is no file in the image besides the manifest and its text files the page reads (decision 3); the page is the way to read them.
   **Supersedes, in spec 084:** AC-1.4's "No other part of the line is a link" (the line now has three), the full wording of AC-2.1, AC-2.3, AC-2.4 and AC-2.14 (each ends with the new sentence), AC-2.13's count of two links, and the Non-Goal "a licence page in the app". Spec 084's decision 8 is carried out here. `bin/image-smoke`'s check of the line is a prefix match ("Collector <version> (<short SHA>) is free software") and still holds.
2. **The page lists four kinds of component and a gem's row holds what the gem says.** The sections, in this order: JavaScript, OCR engine, Fonts, Icons (decision 7), Ruby gems. Each row is a closed `<details>` whose summary is the name, the version and the licence identifier(s), and whose body holds the home link, a copyright line when the manifest has one, and the licence text. Rows are sorted by name, case-insensitively, within a section. The text is escaped plain text in a `<pre>`. A home link is shown only when it is an absolute `http` or `https` address.
3. **Gems are read from the running bundle; everything else comes from one checked-in manifest; a guard keeps them honest.** *(Ruled 2026-11-13, as recommended; over: generating a file at image build, which needs a `Dockerfile` edit.)* The gems are `Bundler.load.specs`, so the list is the image's bundle by construction and has nothing to regenerate; a gem's identifiers are its `licenses`, its home its `homepage`, its text the files in its directory whose names say licence, copying, notice or unlicense (all of them, each under its file name, in name order). The OCR packages, the JavaScript libraries, the fonts and the icons are in `config/third_party_licences.yml`, with each licence text in `config/third_party_licences/` (outside `docs/`, which `.dockerignore` leaves out of the image). A JavaScript entry that names a gem takes its text from that gem's licence file instead of a copy. A guard spec in the suite (so in `bin/ci`, with no change to `config/ci.rb`'s steps or a workflow) fails when:
   - a pinned OCR package (`Collector::OcrEngine::PACKAGES`) has no entry, or an entry names a package that isn't pinned;
   - an importmap pin that resolves into a gem has no entry naming that gem, or an entry names a pin that is gone;
   - a file under `app/assets/fonts/` is in no entry's `files`, an entry lists a file that is gone, or a listed file's SHA-256 differs from the one recorded (a changed font must be looked at);
   - a file under `app/views/icons/` is in no entry's `files` or an entry lists one that is gone (decision 7);
   - a gem has neither licence metadata nor a licence file;
   - an entry's text file is missing or empty, or an entry lacks its name, version, identifier or home.
   The reader is memoised for the process in one place, `Collector::ThirdPartyLicences.current`, the first request building it under a mutex and every later request reading the built list. That is safe because nothing it reads changes while the process runs: the bundle is fixed when Bundler sets up, the gems' files and `config/` live in the image's read-only layers, and a new gem, engine or font is a new image and so a new process (coordinator's ruling, 2026-11-13). Specs replace the reading with `third_party_licences(...)` (`spec/support/`), as spec 084 does for the build facts.
4. **A component whose licence can't be read is shown, flagged and never raises.** *(Ruled 2026-11-13, as recommended.)* A row with no readable text shows its identifier(s) and home link when it has them and the words "Licence text not found", with no `<details>`. A licence file that can't be read (missing, unreadable, not valid UTF-8 after scrubbing) is that case too. The page never answers 500 because of one component. The guard fails only when a component has neither an identifier nor a text; a gem with an identifier and no file is a legitimate row (today: the eight gems named in the Problem Statement). The OCR language data package is another, on `main` today: it declares MIT but ships no licence text or copyright line, and the manifest records only what the package declares (decision 5).
5. **The manifest says only what a source we can cite says.** *(Coordinator, 2026-11-13.)* Each entry carries a `source`: where its facts were read (an npm tarball's `package.json` and licence file, a gem, a minified file's header). A copyright line or licence text that isn't in such a source is not written from memory; the row then reads "Licence text not found". The sources found on 2026-11-13:
   - Fonts: `@fontsource/fraunces`, `@fontsource/ibm-plex-sans` and `@fontsource/ibm-plex-mono` 5.3.0 on npm (`license` OFL-1.1; each `LICENSE` holds the copyright line and the full OFL-1.1). The four files in `app/assets/fonts/collector/` are byte-identical to the packages' `files/…-latin-…-normal.woff2`.
   - `tesseract.js` 7.0.0 and `tesseract.js-core` 7.0.0: Apache-2.0, `LICENSE.md` and `LICENSE` in the tarballs the engine already pins. The `.LICENSE.txt` files beside the minified bundles name what is bundled into them (regenerator-runtime, the Node `buffer` module, ieee754, zlib.js); the manifest carries those lines as the engine's own notice text.
   - `@tesseract.js-data/eng` 1.0.0: `package.json` says MIT, and the tarball holds no licence file (decision 4).
   - Turbo and Stimulus: the licence files of `turbo-rails` and `stimulus-rails` (MIT), the minified file's own header for Turbo ("Turbo 8.0.23, Copyright © 2026 37signals LLC").
6. **The page is a plain page in the shell: no JavaScript, no new CSS system.** A collector gets the application header and tab bar (no section current), a visitor gets the brand-only header that sign-in has; the layout's footer follows, as on every page. It is built from `c-main`, `c-pagehead`, the design system's `Details` pattern and `c-list`. A new rule goes in `additions.css` only if those can't carry the long text, with a `docs/design-system/components/Licences.md` (the project's rule for a new pattern). The page needs no JavaScript and no inline style, so it also renders under a Content-Security-Policy.
7. **Icons are a component, and who made them is the maintainer's to say.** *(Pending.)* The design system says "use Lucide (ISC-licensed)" and `app/views/icons/` holds twelve inline SVGs. Compared on 2026-11-13 with `lucide-static` 1.72.0, only `check` and `chevron-left` match its paths (both Feather-derived, which Lucide's `LICENSE` credits); the other ten match nothing. The draft lists one "Lucide" entry for the set, with Lucide's ISC text and its copyright line from `lucide-static` 1.72.0, and the guard counts the files. If the maintainer rules the ten are Collector's own, the entry covers two files; if the whole set is out of scope, decision 7 and the section go. *Open question 1.*
8. **No ADR, and the image's contents are #408's.** The test group's gems (`brakeman` under the Brakeman Public Use License, `bundler-audit` GPL-3.0-or-later, `vcr` Hippocratic-2.1 among them) are in the image today, so they are on the page: it lists what the image holds. Whether they should be there is [#408](https://github.com/plainprogrammer/Collector/issues/408); this spec doesn't change `BUNDLE_WITHOUT`, and when #408 lands the page follows by construction.

## User Stories and Acceptance Criteria

### Story 1: Anyone reads the third-party licences

**As** an operator, a collector or a visitor **I want** to open one page that lists the third-party software and assets in Collector's image **so that** I can read each one's licence.

- [ ] **AC-1.1** Given a signed-in collector When they request `/licences` Then the response is 200 with the application header and tab bar, an `h1` "Third-party licences", and the footer.
- [ ] **AC-1.2** Given no session When `/licences` is requested Then it is 200 with the brand-only header and the footer, whether or not the open catalog is on, and with no redirect to sign-in.
- [ ] **AC-1.3** Given an instance with no users When `/licences` is requested Then it is 200, not a redirect to sign-up.
- [ ] **AC-1.4** Given the page When it is read Then it opens with a sentence saying Collector is free software under the AGPL-3.0 (linked to the licence's text as the footer's is) and that what follows ships in the image under its own licence, and then the sections JavaScript, OCR engine, Fonts, Icons (if decision 7 stands) and Ruby gems, in that order, each heading with its count.
- [ ] **AC-1.5** Given any component When its row is read Then the summary shows its name, its version and its licence identifier(s), and a component with a readable text has a closed `<details>` holding the home link (when absolute `http(s)`), the copyright line (when the manifest has one) and the text, escaped, in a `<pre>`.
- [ ] **AC-1.6** Given the image bundle When the page is rendered Then every gem of `Bundler.load.specs` has a row, with the identifiers its `licenses` list gives, and each licence-like file in its directory shown under its file name.
- [ ] **AC-1.7** Given a gem whose licence text holds `<script>` or markup When the page is rendered Then it is shown as text and nothing executes.
- [ ] **AC-1.8** Given the page When it is rendered Then it runs no query beyond the session's, calls nothing outside the process, and after the first request in a process reads no file (decision 3).
- [ ] **AC-1.9** Given the page, in the suite's real bundle When it is rendered Then its HTML is at most 1 MiB (a ceiling set against the 394 KB of licence texts measured on the image bundle, about 0.45 MiB with markup, to be measured on the built page in the plan; a bundle that outgrows it fails the example, and raising the ceiling is then a decision).
- [ ] **AC-1.10** Given the page When it is opened at 360px wide and in both themes Then nothing scrolls sideways, the summaries wrap, and a long licence text scrolls inside its own box.

### Story 2: The licence line reaches the page, wherever the small print is

- [ ] **AC-2.1** Given any page with the footer, signed in or not When its licence line is read Then it ends "Read the third-party licences." with "third-party licences" a link to `/licences`, and the line's other two links are unchanged (spec 084 AC-1.4's "AGPL-3.0" and "source code").
- [ ] **AC-2.2** Given the licence line's wording for each reading of the build facts When it is read Then each reading of spec 084's table ends with the new sentence (supersedes spec 084 AC-2.1, AC-2.3, AC-2.4 and AC-2.14's full wording), and a version of `third-party licences` still can't move or drop a link (spec 084 AC-2.13, now three).
- [ ] **AC-2.3** Given the shared partial `layouts/notice_lines` When it is rendered on its own, as a focused page's sheet foot renders it Then it contains the link to `/licences`; the link is made by the licence line's parts and no scanner file is edited.
- [ ] **AC-2.4** Given the scanner page under the Content-Security-Policy it sends When it is rendered Then the licence line and its link are there and the policy is unchanged.
- [ ] **AC-2.5** Given the page opened from the link When it is rendered Then its footer's licence line is the same line (the link points at the page it is on) and appears once.
- [ ] **AC-2.6** Given the core's footer code and the page's files (the controller, the view, `Collector::ThirdPartyLicences`, the manifest) When they are searched, case-insensitively, for "mtg", "magic", "wizards", "scryfall" and "fan content" Then none is found (`spec/licences_core_spec.rb`, as `spec/footer_core_spec.rb`).

### Story 3: What each kind of component shows

- [ ] **AC-3.1** Given the OCR engine When the page is read Then it lists `tesseract.js` 7.0.0 and `tesseract.js-core` 7.0.0 under Apache-2.0 with the full Apache text and the bundled-library notice lines, and `@tesseract.js-data/eng` 1.0.0 as in AC-4.2.
- [ ] **AC-3.2** Given the JavaScript the importmap serves from gems When the page is read Then Turbo and Stimulus are listed under MIT with the licence file of `turbo-rails` and `stimulus-rails`, and the Turbo row's copyright line is the one its file header carries.
- [ ] **AC-3.3** Given the fonts When the page is read Then Fraunces, IBM Plex Sans and IBM Plex Mono are listed under OFL-1.1, each with the copyright line and full OFL-1.1 text of its `@fontsource` 5.3.0 package, and the files in `app/assets/fonts/collector/` each belong to one of them.
- [ ] **AC-3.4** Given a gem with several licence-like files (`nokogiri`, `ffi`, `marcel`) When it is read Then each file is shown under its own file name.

### Story 4: A component whose licence can't be read

- [ ] **AC-4.1** Given a gem with identifiers and no licence file (a spec's stand-in for `minitest`) When the page is rendered Then its row shows the identifiers, the home link and "Licence text not found", has no `<details>`, and the page is 200.
- [ ] **AC-4.2** Given `@tesseract.js-data/eng` 1.0.0, whose package declares MIT and ships no licence text When the page is read Then its row shows "MIT", its home link and "Licence text not found".
- [ ] **AC-4.3** Given a licence file that raises when read, or holds bytes that aren't UTF-8 When the page is rendered Then that component shows "Licence text not found" (or the scrubbed text, for the second), no other row changes and the page is 200.
- [ ] **AC-4.4** Given a gem whose `homepage` is `javascript:…`, empty or relative When the page is rendered Then its row has no home link.

### Story 5: The list can't go stale

- [ ] **AC-5.1** Given a gem added to the bundle with neither identifier nor licence file (a stand-in) When the guard runs Then it fails naming the gem.
- [ ] **AC-5.2** Given a package added to `Collector::OcrEngine::PACKAGES`, or an entry whose package is gone When the guard runs Then it fails naming it.
- [ ] **AC-5.3** Given an importmap pin that resolves into a gem with no entry, or an entry whose pin is gone When the guard runs Then it fails naming it.
- [ ] **AC-5.4** Given a font file added, removed or changed (its SHA-256 differs) When the guard runs Then it fails naming the file.
- [ ] **AC-5.5** Given a manifest entry with a missing or empty text file, or without a name, version, identifier or home When the guard runs Then it fails naming the entry.
- [ ] **AC-5.6** Given the guard's own examples When they run Then each rule is shown to fail on a fixture and to pass on the repository's real files, so a guard that stopped checking would fail its own spec.
- [ ] **AC-5.7** Given `bin/ci` When it runs Then the guard runs in the RSpec step with no change to `config/ci.rb`, a workflow or the `Dockerfile`.

### Story 6: The image proves it

- [ ] **AC-6.1** Given an image built by CI When `bin/image-smoke` runs Then it requests `/licences` without a session, and fails unless the answer is 200 and holds "Third-party licences", `tesseract.js`, `turbo-rails` (as a gem row) and at least one gem's licence text, capturing the output first and testing it after, as the other checks do.
- [ ] **AC-6.2** Given the image's licence line When `bin/image-smoke` reads the sign-in page Then its existing check of the line still passes (decision 1's prefix) and the new link is in the page.

### Story 7: Documents and evidence

- [ ] **AC-7.1** Given the area docs When the work is done Then [catalog core](../../architecture/catalog-core.md) records the licence line's third sentence, the page, the reader and the manifest; [release and deploy](../../architecture/release-and-deploy.md) the smoke check; [tenancy and accounts](../../architecture/tenancy-and-accounts.md) the endpoint that skips sign-in; the design system `Footer.md` the new link and, if added, `Licences.md` the page; each statement with its source inline.
- [ ] **AC-7.2** Given `README.md` and `docs/roadmap.md` When the work is done Then the README says where an operator reads the licences, and the roadmap's row for #376 is marked in progress and then done.
- [ ] **AC-7.3** Given `docs/specs/README.md` When it is read Then spec 087's row exists, spec 084's row names 087 under "Superseded by" and 087's names 084 under "Supersedes" (both directions).
- [ ] **AC-7.4** Given the pull request When it is opened Then it carries screenshots of the page, desktop and phone, both themes, and a GIF of opening a row and following the licence line's link, embedded by SHA-pinned links.

## Functional Requirements

- **FR-1** A `LicencesController#show` for `GET /licences` that skips sign-in and the first-user redirect, resumes a session when there is one, answers HTML only, and holds no state.
- **FR-2** `Collector::ThirdPartyLicences`, a core object that builds the sections from the image bundle and the manifest once per process and returns them as plain values (name, version, identifiers, home, copyright, text or nil), never raising for one component.
- **FR-3** `config/third_party_licences.yml` and `config/third_party_licences/*.txt`: the manifest and its texts (decision 3), each entry with its `source` (decision 5).
- **FR-4** The licence line's parts gain the third sentence and the link (decision 1).
- **FR-5** The guard spec and its fixtures (decision 3, Story 5), and the `third_party_licences(...)` spec helper.
- **FR-6** `bin/image-smoke`'s check (Story 6).

## Non-Functional Requirements

- **Performance:** the first request in a process reads about 400 KB of licence files and the manifest (measured: 139 gems, 394 KB, 103 distinct texts); every later request reads nothing. The built list is held for the process (about half a megabyte). The page is at most 1 MiB of HTML (AC-1.9), compressed by the proxy as every page is.
- **Security:** every text and name is escaped; a home link is `http(s)` only, with `rel="noopener"` and no `target`; the page reads only files under the gems' directories and `config/`, never a path taken from a request.
- **Accessibility:** each row's summary is a button by the browser's own `<details>`, named by its text; the page keeps one `h1`, `h2` per section; text contrast and focus ring as the design system's links and details.
- **Self-hosting:** nothing to configure, no network, no build step; it works offline and from the image as shipped.
- **Collectible-agnostic core:** AC-2.6.

## Error Scenarios

| Situation | Result |
|---|---|
| A gem has identifiers and no licence file | Row with identifiers, home and "Licence text not found" (AC-4.1) |
| A licence file is unreadable or not UTF-8 | That row alone shows "Licence text not found", or the scrubbed text (AC-4.3) |
| A gem's homepage isn't an absolute `http(s)` address | The row has no home link (AC-4.4) |
| A gem has neither identifier nor file | The guard fails in CI; the page, if it were served, shows the row with "Licence text not found" and no identifier |
| `config/third_party_licences.yml` is missing or malformed | Boot isn't affected; the first request to the page raises, answering the 500 page, and the guard has already failed in CI. The manifest is in the image, so this is a build defect, not a runtime state |
| The bundle outgrows the page's ceiling | AC-1.9's example fails in CI |
| An image built before this spec | No `/licences`; the licence line has no third sentence |

## Open Questions

1. **The icons (decision 7).** Are the ten inline icons that don't match Lucide's current paths Lucide-derived, redrawn from it, or Collector's own? Asked of the maintainer through the coordinator on 2026-11-13.
2. **The OCR language data's licence.** `@tesseract.js-data/eng` 1.0.0 declares MIT and ships no text. The data's upstream licence is for the maintainer to confirm; this spec shows what the package says and nothing more (decisions 4 and 5).

## Out of Scope (Candidates)

- #408: what the image's bundle holds (the test group).
- An SPDX or CycloneDX document of the same list.
- A review of each licence against the AGPL-3.0.
