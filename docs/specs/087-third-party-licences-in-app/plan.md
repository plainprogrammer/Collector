# Implementation Plan: The Licences of the Third-Party Software and Assets in the Image, Readable from the App (spec 087, issue #376)

**Spec:** `docs/specs/087-third-party-licences-in-app/spec.md` (Approved v0.3.1) · **Issue:** #376 · **Branch:** `087-third-party-licences` · **Created:** 2026-11-13
**Status:** Draft, for Gate B. Plan review (Fable, read-only): pending. Retired by `distill-feature` after the merge (spec 027).

## Context

Spec 087 adds `GET /licences`, a core page that lists the third-party software and assets in Collector's image and each one's licence text, open to everyone (signed in, signed out, before the first user), and links it from the licence line of spec 084 with a third sentence, "Read the third-party licences." The gems are read from the running bundle once per process; the OCR engine, the two JavaScript libraries, the fonts and the icons come from a checked-in manifest, `config/third_party_licences.yml`, with its texts in `config/third_party_licences/`. A guard spec in the suite fails when a pin, an engine package, a font, an icon or a gem has no entry or has changed. `bin/image-smoke` requests the page. No `Dockerfile`, workflow, `config/ci.rb`, `config/deploy*.yml` or `.claude/settings.json` edit is needed.

The icon count: `app/views/icons/` holds **13** partials (`_alert _back _check _collection _cross _decks _grid _more _plus _scan _search _star _table`), which is what the guard sees (`Dir.children("app/views/icons")`). The spec's first draft said twelve, a miscount by eye, corrected in v0.2.0.

## Global Constraints

- **Repo rules:** `CLAUDE.md`, `.claude/rules/*.md`.
  - Spec types are tagged (`type: :model|:request|:system|:config`); the files under `lib/` are specced as `type: :model`, as `spec/lib/collector/build_facts_spec.rb` is.
  - `RSpec/ExampleLength` max 15 lines; `RSpec/MultipleMemoizedHelpers` max 5 (use `def`); multi-expectation examples use `:aggregate_failures`.
  - Prose documents are verified by reading and recorded in `verification.md`, never from RSpec (`.claude/rules/testing.md`).
- **Core names no collectible.** `spec/licences_core_spec.rb` (T3.2) reads whole files, comments included, for `/mtg|magic|wizards|scryfall|fan content/i`. Never write those words in the new files (the controller, the view and its partial, `lib/collector/third_party_licences.rb` and `third_party_licences/audit.rb`, `config/third_party_licences.yml`, `config/third_party_licences/*.txt`). "The OCR engine", "the scanner" and "Tesseract" are fine.
- **One commit per task, test first** (red, implement, green, RuboCop).
  - Conventional Commits with `(#376)`. The trailer is the attribution reminder in force at commit time; a Sonnet implementer's commits name Sonnet 5.5.
  - One git operation per shell call; `git add` and `git commit` in separate calls (the pre-commit hook reads the command text).
  - Every `git grep` ends with `':!.kamal/secrets'`. Never read `.kamal/secrets`, `config/master.key`, `.env*`, `storage/` or any `*.sqlite3`.
- **Prompting files.** None is edited. Never touch `Dockerfile`, `.github/workflows/**`, `config/deploy*.yml`, `config/ci.rb` or `.claude/settings.json`. `bin/image-smoke` and `spec/image_publishing_spec.rb` are edited normally.
- **Scanner files and spec 082.** Spec 082 (#344) isn't merged and renders `layouts/notice_lines` in the scanner's sheets and changes `spec/requests/licence_line_spec.rb`. Edit no file under `app/views/scanner*`, `app/javascript/scanner*`, `app/controllers/scanner*` or `docs/design-system/components/{Scanner,Sheet}.md`. `layouts/_notice_lines.html.erb` is **not edited at all**: the link comes from `Collector::BuildFacts#licence_parts`. Edits to `spec/requests/licence_line_spec.rb` are the smallest possible and in a commit of their own (T1.2); whichever of the two lands second resolves the conflict there, and T7.1 re-reads the scanner's sheet-foot example after a merge of `main`.
- **Comments:** every public class, module and method gets a summary (the comment ratchet in `bin/ci checks`), with `@param`/`@return` on reusable code. No `{…}` outside YARD links. Use `@see file:catalog-core.md` and `@see file:release-and-deploy.md`. Private helpers are `private`/`private_class_method`.
- **No migration, no export, import or backup change**; the export format stays 4. No gem, no JS. `spec/support/runtime_log.txt` is not refreshed.
- **UI:** the `collector-design-system` skill applies (read `docs/design-system/README.md` first). The one new pattern is `Licences` (T4.2): tokens only, no colour literal, no font family but `var(--font-mono)`.
- **Never run `printenv` or `env` as a Bash command.** `bin/image-smoke` may, inside the container.
- **Shared test database:** one test run at a time in this worktree. A targeted `bin/rspec <file>` needs no CI slot; a full `bin/ci`, and a push, need one from the coordinator.
- **The manifest never carries text from memory** (spec decision 5): every copyright line and licence text is copied from the cited source files kept in the scratchpad (T2.4).

## Goal

Anyone can open `/licences` and read what is in the image and under which licences; the licence line leads there; CI fails when the list would go stale; the image smoke test proves the page in the image.

## Pre-implementation gates

- **Simplicity (≤3 components): pass.** (1) The reader `Collector::ThirdPartyLicences` with its manifest, and its `Audit` (the guard's rules, which the guard spec runs); (2) the page (route, controller, view, one CSS block); (3) the licence line's link and the image smoke check.
- **Anti-abstraction: pass.** Plain `Data` values, no registry, no gem, no wrapper around Bundler: `Bundler.load.specs` and `YAML.safe_load` are called directly.
- **Integration-first: pass.** The link and its route come first (Phase 1) so the line's contract is fixed; the reader and its manifest (Phase 2) before the guard (Phase 3) and the page (Phase 4).

## Files

| File | Change | Responsibility |
|---|---|---|
| `lib/collector/build_facts.rb` | edit | `LICENCES_PATH`; the third sentence in `licence_parts`; comments |
| `config/routes.rb` | edit | `resource :licences, only: :show` |
| `lib/collector/third_party_licences.rb` | create | the reader: sections of components from the bundle and the manifest, memoised |
| `lib/collector/third_party_licences/audit.rb` | create | the guard's rules over injected inputs |
| `config/third_party_licences.yml`, `config/third_party_licences/*.txt` | create | the manifest and its texts |
| `app/controllers/licences_controller.rb` | create | `GET /licences` |
| `app/views/licences/show.html.erb`, `_component.html.erb` | create | the page |
| `app/assets/stylesheets/collector/additions.css` | edit | the `Licences (spec 087)` block |
| `bin/image-smoke` | edit | the `/licences` check |
| `spec/support/third_party_licences.rb` | create | `third_party_licences(...)` helper, stand-in gem specs |
| `spec/lib/collector/third_party_licences_spec.rb`, `spec/lib/collector/third_party_licences/audit_spec.rb`, `spec/third_party_licences_manifest_spec.rb`, `spec/licences_core_spec.rb`, `spec/requests/licences_spec.rb`, `spec/requests/licences_link_spec.rb`, `spec/system/licences_spec.rb` | create | the proofs |
| `spec/lib/collector/build_facts_spec.rb`, `spec/requests/licence_line_spec.rb`, `spec/requests/footer_spec.rb`, `spec/system/footer_spec.rb`, `spec/image_publishing_spec.rb`, `spec/design_system_files_spec.rb` | edit | the line's wording; the smoke script's shape; the CSS block |
| `docs/design-system/components/Footer.md`, `Licences.md`, `docs/design-system/README.md` | edit, create, edit | the new link; the new pattern |
| `docs/architecture/catalog-core.md`, `release-and-deploy.md`, `tenancy-and-accounts.md`, `README.md`, `CLAUDE.md`, `docs/roadmap.md`, `docs/specs/README.md` | edit | Story 7 |
| `docs/specs/087-third-party-licences-in-app/verification.md`, `screenshots/` | create | evidence |

## Phase 1: The licence line leads to the page

**Implements:** decision 1, FR-4 · **Satisfies:** AC-2.1 to AC-2.5
**Files:** `lib/collector/build_facts.rb`, `config/routes.rb`, `spec/lib/collector/build_facts_spec.rb`, `spec/requests/licence_line_spec.rb`, `spec/requests/footer_spec.rb`, `spec/system/footer_spec.rb`, `spec/requests/licences_link_spec.rb`

- [ ] **T1.1 The line's parts gain the sentence and the route exists.** Test first, `spec/lib/collector/build_facts_spec.rb` (edit the tail at line 96 and the parts at lines 100–110: `licence_parts` now ends `[ " Read the ", nil ], [ "third-party licences", "/licences" ], [ ".", nil ]`), and a new example for `LICENCES_PATH`. Then in `lib/collector/build_facts.rb`:

  ```ruby
  # The page that lists the third-party licences (spec 087). A constant, because `licence_parts` is in lib/ with no route
  # helpers; spec/requests/licences_link_spec.rb asserts it equals `licences_path`, so the route can't move without it.
  LICENCES_PATH = "/licences"
  ```

  `licence_parts` returns the five parts it does today plus `[ " Read the ", nil ], [ "third-party licences", LICENCES_PATH ], [ ".", nil ]` (the last "." of the second sentence stays; the new sentence follows it), and its comment says the links sit on the fixed words "AGPL-3.0", "source code" and "third-party licences" (spec 087 decision 1; spec 084 AC-2.13 now has three links). Update the class comment's mention. Add to `config/routes.rb` beside `resource :more, only: :show`: `resource :licences, only: :show # spec 087: the third-party licences, for everyone`. `Collector::BuildFacts` still never names a collectible. Commit: `feat(licences): the licence line links the third-party licences (#376)`.

- [ ] **T1.2 `licence_line_spec.rb`, minimal edit, own commit.** Only what the new wording needs: `let(:tail)` ends with ` Get the source code. Read the third-party licences.`; `expect_the_unknown_line`'s `link_pairs` gains `[ "third-party licences", "/licences" ]` as the last pair; lines 156 and 160 (`end_with?("Get the source code.")`) end with `"Read the third-party licences."`; the `to all(match_array(%w[rel href]))` stays; the `link_pairs.last` expectations at lines 70 and 76 (`source code`'s address) become `link_pairs[1]`. Nothing else in the file changes, and no example is added there. Commit: `test(licences): the licence line's third sentence in spec 084's examples (#376)`.

- [ ] **T1.3 The other examples that read the line, and the new link examples.**
  - `spec/requests/footer_spec.rb:16` (`def licence`) and `spec/system/footer_spec.rb:86` and `:99` (`end_with("Get the source code.")`) take the new ending.
  - New `spec/requests/licences_link_spec.rb` (`type: :request`): AC-2.3 (`Collector::BuildFacts::LICENCES_PATH == licences_path`); AC-2.2's stand-in versions (`build_facts(version: "third-party-licences", revision: sha)`, then `"AGPL-3.0"`, `"source-code"`) keep exactly three links on the fixed words, signed out on `new_session_path`; AC-2.4's partial alone (`ApplicationController.render(partial: "layouts/notice_lines")`, parsed with `Nokogiri::HTML5.fragment`, contains `a[href="/licences"]`) and the scanner page for a signed-in collector (`get scanner_path`, the footer's last paragraph holds the link, the response's `Content-Security-Policy` header is the one `spec/requests/scanner_page_spec.rb` already expects; read that spec for the exact assertion and reuse its helper, do not copy the policy string).
  - Run `bin/rspec spec/requests/licence_line_spec.rb spec/requests/footer_spec.rb spec/requests/licences_link_spec.rb spec/lib/collector/build_facts_spec.rb`; the system footer spec runs in T4.4's batch.
  - Commit: `test(licences): the link's address, its three-link rule and the shared partial (#376)`.

## Phase 2: The reader and the manifest

**Implements:** FR-2, FR-3; decisions 2 to 5 · **Satisfies:** AC-1.5 to AC-1.8, AC-3.1 to AC-3.5, AC-4.1 to AC-4.4
**Files:** `lib/collector/third_party_licences.rb`, `config/third_party_licences.yml`, `config/third_party_licences/*.txt`, `spec/support/third_party_licences.rb`, `spec/lib/collector/third_party_licences_spec.rb`

- [ ] **T2.1 The values and the gems.** Test first, `spec/lib/collector/third_party_licences_spec.rb` (`type: :model`), with stand-in gem specs from `spec/support/third_party_licences.rb`:

  ```ruby
  # Stand-ins for Bundler's specs: a gem directory under a temp dir with the files named, and the three readers the
  # reader asks (name, version, licenses, homepage, full_gem_path).
  module ThirdPartyLicencesHelpers
    StandIn = Struct.new(:name, :version, :licenses, :homepage, :full_gem_path, keyword_init: true)

    def stand_in_gem(dir, name: "example", version: "1.2.3", licenses: [ "MIT" ], homepage: "https://example.test", files: {})
      path = dir.join(name)
      path.mkpath
      files.each { |file, text| path.join(file).write(text) }
      StandIn.new(name:, version: Gem::Version.new(version), licenses:, homepage:, full_gem_path: path.to_s)
    end
  end
  ```

  (Use `Dir.mktmpdir` with a `Pathname`, cleaned in an `after`, as `spec/support/` helpers do.) Examples, each for one AC: a gem with `MIT-LICENSE`, `BSDL` and `LEGAL.rdoc` shows all three under their file names in name order and not `README.md` or a `lib/LICENSE`; identifiers are the gem's `licenses`; a gem with identifiers and no file has no texts; a file that raises (a directory named `LICENSE` is not a regular file and is skipped; a file with mode 000 raises `Errno::EACCES`, which is rescued, skip when running as root), one over 1 MiB, show no text; invalid UTF-8 is scrubbed; a `homepage` of `javascript:…`, `""`, `nil` or `"/relative"` gives no home, `http://` and `https://` addresses are kept. Then `lib/collector/third_party_licences.rb`:

  ```ruby
  module Collector
    # The third-party software and assets in the image and their licences, for the page at /licences (spec 087). ...
    # @see file:catalog-core.md
    class ThirdPartyLicences
      Component = Data.define(:name, :version, :identifiers, :home, :copyright, :texts, :note)
      Section = Data.define(:key, :title, :components)
      TEXT_FILE = /licen[sc]e|copying|copyright|notice|\A(bsdl|legal)(\.\w+)?\z/i
      MAX_TEXT_BYTES = 1.megabyte
      MANIFEST = "config/third_party_licences.yml"
      TEXT_DIR = "config/third_party_licences"
      TITLES = { javascript: "JavaScript", ocr: "OCR engine", fonts: "Fonts", icons: "Icons", gems: "Ruby gems" }.freeze

      # the gem's components: one per spec, sorted by name
      def self.gem_components(specs) = specs.map { gem_component(it) }.sort_by { it.name.downcase }
      def self.texts_in(directory) # [[file name, text], ...] of the top-level regular files that match TEXT_FILE
      def self.safe_home(address)   # an absolute http(s) address, or nil
  ```

  `texts_in` lists `Dir.children(directory).sort`, keeps `File.file?` names that match, skips a file over `MAX_TEXT_BYTES`, reads `File.read(path, encoding: "UTF-8").scrub` and rescues `SystemCallError` and `IOError` per file (that file is left out); `safe_home` parses with `URI.parse`, accepts `URI::HTTP` (which includes `URI::HTTPS`) with a host, rescues `URI::InvalidURIError`. Comment each public method per `.claude/rules/code-documentation.md` (the reusable-code rule), and say why: the pattern's names come from the bundle (`MIT-LICENSE`, `LICENSE.SPECS`, `LICENSE-DEPENDENCIES.md`, `license_of_rb-readline`, `BSDL`, `LEGAL`). Commit: `feat(licences): read the gems' licences from a bundle (#376)`.

- [ ] **T2.2 The manifest, the sections and the memo.** Test first (same spec file), with a manifest written to a temp dir: sections come in the order JavaScript, OCR engine, Fonts, Icons, Ruby gems with each section's components sorted by name case-insensitively; an entry with `texts` shows each file's text under its `title`; an entry with `text: none` shows no texts, `note: "as the package declares"` (the entry's `reason` is not shown); a JavaScript entry with a `gem` takes that gem's files from the stand-in specs under their file names, and has no texts when the gem isn't in the specs; a text file that is missing shows no text (AC-4.3 at the manifest); `YAML.safe_load` is used (an entry with a `!ruby/object` tag raises `Psych::DisallowedClass` from `load_manifest`, not executes); `.current` called twice returns the same object and the builder ran once (give `build` a `builder:` keyword defaulting to the real one, and pass a counting lambda in the example: no stub of the object under test); a build that raises is not kept and the next call tries again (AC-1.8, decision 3). Manifest shape (`config/third_party_licences.yml`; keys are strings):

  ```yaml
  javascript:
    - name: Turbo
      version: "8.0.23"
      gem: turbo-rails
      gem_version: "2.0.23"
      pins: ["@hotwired/turbo-rails"]
      spdx: MIT
      home: https://github.com/hotwired/turbo-rails
      copyright: "Copyright © 2026 37signals LLC"
      files: { "turbo.min.js": "<sha256>" }
      source: "…"
  ocr:
    - { name: tesseract.js, version: "7.0.0", sha256: "<PACKAGES' sha256>", spdx: Apache-2.0, home: …, texts: [ { title: LICENSE.md, file: tesseract-js-LICENSE.txt }, { title: "Bundled libraries", file: tesseract-js-bundled.txt } ], source: … }
    - { name: "@tesseract.js-data/eng", …, text: none, reason: "…", note: "as the package declares" }
  fonts:
    - { name: Fraunces, version: "5.3.0 (Fontsource)", spdx: OFL-1.1, home: …, copyright: "…", files: { "collector/fraunces-latin-600-normal.woff2": "<sha256>" }, texts: […], source: … }
  icons:
    - { name: Lucide, version: "as in lucide-static 1.72.0", spdx: ISC, home: https://lucide.dev, copyright: "Copyright (c) 2026 Lucide Icons and Contributors", files: ["_alert.html.erb", …13], texts: […], source: … }
  ```

  `Collector::ThirdPartyLicences.current` builds under a `Mutex` and keeps the value in the class (`@current`); `.current=` and `.reset` exist for specs (documented `@api private`: used by `spec/support/third_party_licences.rb`); `.build(specs: Bundler.load.specs, manifest: Rails.root.join(MANIFEST), text_dir: Rails.root.join(TEXT_DIR))` returns the instance whose `sections` are the five `Section`s. Verify before relying on it, in a spec example and not in a console: `Bundler.load.specs` answers specs with `name`, `version`, `licenses`, `homepage` and `full_gem_path` in the suite. The comment says why the memo is safe (spec decision 3) and that a failed build isn't kept. Commit: `feat(licences): read the manifest and keep the list for the process (#376)`.

- [ ] **T2.3 The helper.** `spec/support/third_party_licences.rb` also holds `third_party_licences(sections)` (sets `Collector::ThirdPartyLicences.current = ThirdPartyLicences.new(sections)`) and `config.after { Collector::ThirdPartyLicences.reset }`, so an example's replacement never survives it. Test: an example replaces the list and the next example reads the real bundle (two examples in a described order are not enough under random order: assert in one example that after `reset` `.current` is not the replacement). Commit: `test(licences): a spec helper that replaces the list for an example (#376)`.

- [ ] **T2.4 The manifest's content (the supervisor writes it, not a subagent).** The facts come only from the cited sources, kept in the scratchpad `…/scratchpad/{fonts,ocr,lucide}/` of this run (re-fetch from the npm registry if they are gone: `curl` GET with a descriptive User-Agent, never a POST):
  - `config/third_party_licences/tesseract-js-LICENSE.txt` ← `tesseract.js-7.0.0/package/LICENSE.md`; `tesseract-js-core-LICENSE.txt` ← `tesseract.js-core-7.0.0/package/LICENSE`; `tesseract-js-bundled.txt` ← the two `.LICENSE.txt` files under `dist/` (`tesseract.min.js.LICENSE.txt`, `worker.min.js.LICENSE.txt`), each under a title line naming its file; `fraunces-OFL.txt`, `ibm-plex-sans-OFL.txt`, `ibm-plex-mono-OFL.txt` ← each `@fontsource/<name>-5.3.0/package/LICENSE`; `lucide-LICENSE.txt` ← `lucide-static-1.72.0/package/LICENSE` whole (the ISC text, the Feather list and the MIT text for it).
  - The copyright lines are the first line of each font's `LICENSE` (Fraunces: "Copyright 2020 The Fraunces Project Authors (github.com/undercasetype/Fraunces)"; IBM Plex Sans: "Copyright 2019 IBM Corp. All rights reserved."; IBM Plex Mono: "Copyright 2017 IBM Corp. All rights reserved."); Turbo's is its file header's ("Copyright © 2026 37signals LLC"); Lucide's is "Copyright (c) 2026 Lucide Icons and Contributors". `tesseract.js`, `tesseract.js-core` and Stimulus carry no copyright line of their own in a cited source and get none.
  - Digests: the OCR packages' `sha256` are `Collector::OcrEngine::PACKAGES`'s (`9a93bf51…`, `ba584355…`, `c9bddf2e…`); the fonts' are `shasum -a 256` of the four files (`fraunces-latin-600-normal.woff2` 3a1de771…, `ibm-plex-mono-latin-400-normal.woff2` 08949f72…, `ibm-plex-sans-latin-400-normal.woff2` 3b646991…, `ibm-plex-sans-latin-600-normal.woff2` 8960851d…, full values from the command); Turbo's `turbo.min.js` 16b92621…; Stimulus's `stimulus.min.js` 0acd6333… and `stimulus-loading.js` 64807470… (full values from the command). Gem versions: `turbo-rails` 2.0.23, `stimulus-rails` 1.3.4.
  - Homes (from the sources' `package.json` or gem metadata): `tesseract.js` https://github.com/naptha/tesseract.js; `tesseract.js-core` https://github.com/naptha/tesseract.js-core; `@tesseract.js-data/eng` https://github.com/naptha/tessdata; the fonts' https://fontsource.org/fonts/{fraunces,ibm-plex-sans,ibm-plex-mono}; Turbo https://github.com/hotwired/turbo-rails; Stimulus https://stimulus.hotwired.dev; Lucide https://lucide.dev.
  - `@tesseract.js-data/eng`: `text: none`, reason "the package declares MIT in its package.json and ships no licence text or copyright line", `note: "as the package declares"`.
  - Each entry's `source` names the file it was read from (for example "npm @fontsource/fraunces 5.3.0: package.json, LICENSE; files byte-identical by SHA-256, checked 2026-11-13").
  - Check by running `spec/lib/collector/third_party_licences_spec.rb` and, once T3.1 exists, the manifest spec. Commit: `docs(licences): the manifest of the OCR engine, the JavaScript, the fonts and the icons (#376)`.

## Phase 3: The guard

**Implements:** decision 3's guard · **Satisfies:** AC-5.1 to AC-5.8, AC-2.6
**Files:** `lib/collector/third_party_licences/audit.rb`, `spec/lib/collector/third_party_licences/audit_spec.rb`, `spec/third_party_licences_manifest_spec.rb`, `spec/licences_core_spec.rb`

- [ ] **T3.1 `Audit`: the rules over injected inputs.** Test first, `audit_spec.rb` (`type: :model`): for each rule one fixture that fails and names the offender, and one that passes (AC-5.7). `Audit.new(manifest:, text_dir:, specs:, ocr_digests:, pins:, pin_directories:, app_javascript:, font_files:, icon_files:)`; `#problems` returns an array of strings, empty when the inputs agree. Inputs: `manifest` the loaded hash; `ocr_digests` the pinned tarballs' `sha256` values; `pins` an array of `Audit::Pin = Data.define(:name, :asset)` where `asset` is an absolute path or nil; `pin_directories` the `pin_all_from` directory keys; `app_javascript` the absolute `app/javascript` path; `font_files` a hash of path relative to `app/assets/fonts` to SHA-256; `icon_files` the names under `app/views/icons`. Rules (spec decision 3; each a private method returning strings):
  - **OCR:** every `ocr_digests` value is in some `ocr` entry's `sha256` and every `ocr` entry's `sha256` is in `ocr_digests`.
  - **JavaScript:** each pin with a nil `asset` fails ("finds no asset"); a pin whose asset is under `app_javascript` is skipped; any other pin must be in some `javascript` entry's `pins`; the served file's basename must be a key of that entry's `files` and its SHA-256 equal the recorded one; the entry's `gem_version` must equal the version of the spec named `gem` (`specs`); an entry's pin that no pin matches, and an entry's `files` key no pin serves, are stale; every `pin_directories` value must lie under `app_javascript`.
  - **Fonts:** every `font_files` path is in some `fonts` entry's `files` with an equal digest; every `files` path is in `font_files`.
  - **Icons:** every `icon_files` name is in some `icons` entry's `files`, and every listed name is in `icon_files`.
  - **Gems:** each spec with an empty `licenses` and no `ThirdPartyLicences.texts_in(full_gem_path)` fails.
  - **Entries:** every entry of the four sections has a non-empty `name`, `version`, `spdx`, `home` and `source`; has `texts` (each `file` an existing, non-empty file whose real path lies under `text_dir`), or `text: none` with a non-empty `reason`, or a `gem` (JavaScript only; its texts are the gem's).
  `Audit.for_repository` builds the real inputs: `Bundler.load.specs`, `Collector::OcrEngine::PACKAGES.map(&:sha256)`, `Rails.application.importmap.packages.map { |name, pin| Audit::Pin.new(name:, asset: Rails.application.assets.load_path.find(pin.path)&.path) }` (`find` returns a `Propshaft::Asset`; the file is `asset.path`; a pin that is a URL has no asset), `Rails.application.importmap.directories.keys`, the files under `app/assets/fonts/**` and the names in `app/views/icons`. Verify in the spec, not a console, that the real `pins` are the four explicit ones. Commit: `feat(licences): the guard's rules (#376)`.

- [ ] **T3.2 The guard on the repository, and the core guard.**
  - `spec/third_party_licences_manifest_spec.rb` (`type: :model`): `Audit.for_repository.problems` is empty, with the message listing the problems. Also: the page's gem list is a subset-or-equal of the guard's gems (both read `Bundler.load.specs`), and a note in the example's comment that the suite holds every group while the image holds all but `development`, so the guard covers a superset (spec decision 3).
  - `spec/licences_core_spec.rb`, modelled on `spec/footer_core_spec.rb`: the files `lib/collector/third_party_licences.rb`, `lib/collector/third_party_licences/audit.rb`, `config/third_party_licences.yml` and every `config/third_party_licences/*.txt` exist and none matches `/mtg|magic|wizards|scryfall|fan content/i` (AC-2.6). The controller and the view files don't exist yet; T4.1 adds `app/controllers/licences_controller.rb`, `app/views/licences/show.html.erb` and `app/views/licences/_component.html.erb` to the same list, so the example is complete when the page is.
  - Commit: `test(licences): the guard on the repository and the core names no collectible (#376)`.

## Phase 4: The page

**Implements:** FR-1; decisions 2 and 6 · **Satisfies:** AC-1.1 to AC-1.4, AC-1.9, AC-1.10, AC-4.x at the page
**Files:** `app/controllers/licences_controller.rb`, `app/views/licences/`, `app/assets/stylesheets/collector/additions.css`, `docs/design-system/components/Licences.md`, `spec/requests/licences_spec.rb`, `spec/system/licences_spec.rb`, `spec/design_system_files_spec.rb`

- [ ] **T4.1 The controller, the view and the request specs.** Test first, `spec/requests/licences_spec.rb` (`type: :request`; use `third_party_licences(...)` for stand-ins and the real list for AC-1.9): AC-1.1 (signed in: 200, `h1` "Third-party licences", the application header's nav, the tab bar, the footer); AC-1.2 (signed out, once with `:public_catalog` and once without: 200, the brand-only header (`header.c-appbar` with no `nav`), the footer, no redirect); AC-1.3 (no users: 200); AC-1.4 (the intro sentence with its AGPL-3.0 link, the sentence about Ruby and the operating system's packages, the five `h2`s in order each with its count); AC-1.5, AC-1.7 and AC-4.x with stand-in components (a row with text is a closed `details` (no `open` attribute) whose `pre` holds the escaped text, one per file under its file name; a `<script>` in a text is escaped; a row with no text has no `details` and reads "Licence text not found"; the `note` "(as the package declares)" shows after the identifier; no home link for a bad address; `rel="noopener"` and no `target` on a home link); AC-1.8 (visitor request runs zero queries with `count_queries`; a collector request runs no more than `get collection_path`'s-header-equivalent baseline: compare with a trivial signed-in page that has the same header and footer, `get more_path`, minus nothing, and assert `<=`); AC-1.9 (the real page's body is at most `1.megabyte`; print its size). The controller:

  ```ruby
  # The third-party licences (spec 087): every component in the image and its licence, for everyone, with no tenant data.
  class LicencesController < ApplicationController
    allow_unauthenticated_access
    allow_before_first_user
    before_action :resume_session # allow_unauthenticated_access alone never resumes a session; the header needs to know who is here

    def show
      @sections = Collector::ThirdPartyLicences.current.sections
    end
  end
  ```

  The view (`licences/show.html.erb`): `content_for :title, "Third-party licences · Collector"`; a collector gets `render "layouts/appbar", section: nil` and, after `<main>`, `render "layouts/tabbar", section: nil`; a visitor gets `content_for :appbar, render("layouts/brand_appbar")` (as `sessions/new` does; read it); `<main class="c-main c-page">`, `c-pagehead` with the `h1`, the intro paragraph (the AGPL-3.0 link is `link_to "AGPL-3.0", Collector::BuildFacts::LICENCE_URL, rel: "noopener"`) and the Ruby/OS sentence, then per section `<section class="c-licences" aria-labelledby="…"><h2 class="c-licences__title" id="…">JavaScript <span class="c-licences__count">2</span></h2><ul class="c-licences__list">` and one `render "licences/component"` per component. `_component.html.erb` renders `<li class="c-licences__row">`: the heading `<span class="c-licences__name">NAME</span> <span class="c-licences__meta">VERSION · IDENTIFIERS(, note)</span>` (the exact `c-licences__name">NAME<` markup is what `bin/image-smoke` greps, T5.1), and either `<details class="c-licences__details"><summary>` (the heading) `…</summary>` with the home link, the copyright line and one `<h3 class="c-licences__file">TITLE</h3><pre class="c-licences__text">TEXT</pre>` per text, or, with no texts, the heading, the home link and `<p class="c-licences__missing">Licence text not found</p>`. Everything through ERB's escaping; no `html_safe`, `raw` or `<%==`. Add the three view and controller paths to `spec/licences_core_spec.rb`'s list. Commit: `feat(licences): the third-party licences page (#376)`.

- [ ] **T4.2 The pattern: CSS and its document.** Read the `collector-design-system` skill, `docs/design-system/README.md` and `docs/design-system/components/Footer.md`, `Menu.md` (for the `<details>` treatment) first. Add a block headed `/* ---------- Licences (spec 087): the third-party licences page ---------- */` to `additions.css` after the footer's block: `.c-licences` (spacing, `space-6` between sections), `.c-licences__title` (the heading; the count in `ink-muted`), `.c-licences__list` (no list style, a `line` divider between rows), `.c-licences__row` (padding `space-3` 0), the summary (`cursor:pointer`, the `focus` ring on `:focus-visible`, `overflow-wrap:anywhere` so a long name wraps), `.c-licences__meta` (`ink-muted`, 12px/16px as the footer), `.c-licences__text` (`pre`: `font-family:var(--font-mono)`, `white-space:pre-wrap`, `overflow-wrap:anywhere`, `max-height:24rem`, `overflow:auto`, `background:var(--surface-sunken)`, `padding:var(--space-3)`, `border-radius:var(--radius-sm)`), `.c-licences__missing` (`ink-muted`), links as the footer's. Tokens only; no colour literal or font name but the token. Write `docs/design-system/components/Licences.md` (markup, rules, a11y, the new pattern's reason: the design system has no disclosure with a scrolling text box) and add its line to the README's Components list. Extend `spec/design_system_files_spec.rb` with a block example in the style of the image-fit one (one block of its own, `spec 087` mentioned once, no colour literal). Commit: `feat(design): the Licences pattern (#376)`.

- [ ] **T4.3 The system spec and the measures.** `spec/system/licences_spec.rb` (`type: :system`, headless Firefox): at 360px (`open_in_narrow_frame` or `open_in_viewport_frame` from `spec/support/narrow_frame.rb`; read its comments and use the viewport form), the page has no horizontal scroll with a long text open (open the Apache row: click its `summary`, then assert the `pre` has a scrollable overflow inside its box and the page's `scrollWidth <= clientWidth`), in the light and the dark theme (set `data-theme` as `spec/system/footer_spec.rb` does); clicking the licence line's link from a signed-in page lands on the page. A `:timing` example in `spec/requests/licences_spec.rb`'s style of `bulk_move_timing_spec.rb` (never gating): the render time of the real page over 20 requests, median and maximum, and the page's bytes; the figures go in `verification.md`. Commit: `test(licences): the page fits a phone and opens from the line (#376)`.

- [ ] **T4.4 Run the footer's system specs** (`bin/rspec spec/system/footer_spec.rb spec/system/licences_spec.rb`) now that the page exists; fix nothing in scanner files. No commit unless an expectation needs the new wording (it is T1.3's).

## Phase 5: The image proves it

**Implements:** FR-6 · **Satisfies:** AC-6.1, AC-6.2, AC-5.8
**Files:** `bin/image-smoke`, `spec/image_publishing_spec.rb`

- [ ] **T5.1 The smoke check.** Test first: `spec/image_publishing_spec.rb` (read how it asserts the build-facts check at line 102 and the no-pipe rule in `spec/smoke_scripts_spec.rb`; add the new check's lines in the same style). In `bin/image-smoke`, after the build-facts block and before "nothing unexpected in /rails/vendor", add:

  ```bash
  # The page that lists the third-party licences, read before any user exists (spec 087): the image's own bundle, engine,
  # JavaScript and licence texts, not the repository's. Captured, then tested (no pipe).
  echo "== the third-party licences page (spec 087)"
  licences="$(curl -s "http://127.0.0.1:${port}/licences")" || fail "the licence page did not load"
  [ "$(status /licences)" = "200" ] || fail "/licences did not answer 200"
  for want in 'Third-party licences' 'c-licences__name">tesseract.js<' 'c-licences__name">turbo-rails<' 'Permission is hereby granted, free of charge'; do
    grep -qF "$want" <<<"$licences" || fail "the licence page lacks: ${want}"
  done
  grep -qF 'c-licences__name">yard<' <<<"$licences" && fail "the licence page lists yard, a development gem the image leaves out"
  ```

  and a check in the sign-in block that the sign-in page holds `href="/licences"`. The header comment of the script lists the new check. The exact strings are fixed from the page's real markup (T4.1). Commit: `feat(image): the smoke test reads the licence page (#376)`.

- [ ] **T5.2 The local proof (the supervisor; needs a CI slot and the container engine).** Ask the coordinator for a slot and the engine before this run, and say "slot released" with the SHA and result after. Build: `docker build -t collector:licences-smoke --build-arg COLLECTOR_VERSION=0.0.0-087 --build-arg COLLECTOR_REVISION="$(git rev-parse HEAD)" --build-arg COLLECTOR_SOURCE_URL="https://github.com/plainprogrammer/Collector/tree/$(git rev-parse HEAD)" .` through colima's docker (`PATH="$PATH:/opt/homebrew/bin"`, appended; `.claude/memory/container-engine-colima-macos.md`), then `bin/image-smoke collector:licences-smoke`; keep scratch files under the worktree's ignored `tmp/`. It proves the page in the image as built (the bundle minus `development`, no `yard` row, gem licence texts present, the page before any user). Then the negative: a copy of the script in `tmp/` whose `yard` check is turned into a requirement fails against the same image, shown once in `verification.md`. Record the output tail and the page's size in the image. No commit unless the check needs a fix.

## Phase 6: Documents and evidence

**Implements:** Story 7 · **Satisfies:** AC-7.1 to AC-7.4. All edits cite their source (spec criterion) inline, as `.claude/rules/documentation.md` asks.

- [ ] **T6.1 The area docs.** `docs/architecture/catalog-core.md`: the footer section (line 116 onward; line 118 and 132: the licence line has a third sentence and three links, not "no other part is a link"), a new subsection "The third-party licences page" (the route, who sees it, the sections, a row, "Licence text not found", the reader, the manifest and the guard, the memo, the page's ceiling), the scope list at line 14, the Sources list and the distillation log. `docs/architecture/release-and-deploy.md`: the smoke check (line 82, a new bullet beside the build-facts one at line 102), Sources and log. `docs/architecture/tenancy-and-accounts.md`: `/licences` in the endpoints that skip sign-in (line 64's list; find the list). Each new statement names spec 087's decision or AC.
- [ ] **T6.2 Design system, README, CLAUDE.md, roadmap, index.** `docs/design-system/components/Footer.md` (the markup example and the "licence line" bullets: three links, the third sentence); `README.md` (where an operator reads the licences, in the same place as the build facts' text); `CLAUDE.md` Project Status (extend the footer sentence: "... and the line links the page of the third-party licences, `/licences`, whose gems come from the running bundle and whose other entries come from `config/third_party_licences.yml`, kept honest by a guard spec (spec 087)"); `docs/roadmap.md` (the #376 row: in progress, then done, with the spec link); `docs/specs/README.md` (spec 087's row: status Approved → Shipped at merge; the distillation step changes it).
- [ ] **T6.3 `verification.md`.** Per AC: how each was verified, the run, the numbers (the page's bytes and render time, the guard's count of components, the local image smoke output), the screenshots under `screenshots/` (desktop and phone, light and dark, of the page with a row open and the licence line) and the GIF of opening a row and following the link (`.claude/memory/pr-screenshots-workflow.md`), and the open items owed to the maintainer: open question 2, the `@tesseract.js-data/eng` upstream licence, and that the icons' Lucide attribution is on the maintainer's word (decision 7), with #408. The implementation review (Mode B, Opus) goes under `## Implementation review`, verdict on its first line.

## Phase 7: After a merge of main

- [ ] **T7.1 If spec 082 is in `main` when the branch is pushed or when its PR shows a conflict:** merge `origin/main` (never rebase), run `bin/rails db:prepare`, resolve `spec/requests/licence_line_spec.rb` by taking 082's scanner-through-its-sheets example and re-applying T1.2's three edits (the tail, the third link pair, the `end_with?` lines), then re-read the scanner's sheet-foot example in that file and in `spec/system/scanner*` for any expectation of the line's old ending (`git grep -n "Get the source code" -- spec ':!.kamal/secrets'`), and run those specs. Touch no scanner file. If 082 is not in `main`, this task is a note in `verification.md` that the scanner's sheets reach the link through the shared partial once 082 merges (AC-2.4's partial example proves it today).

## Order, batches and the work for implementers

Sonnet implementers take 2 to 4 consecutive tasks each, test first, one commit per task, reading this file by line range, with the supervisor checking each batch's diff:

1. **Batch A:** T1.1, T1.2, T1.3.
2. **Batch B:** T2.1, T2.2, T2.3. Then the supervisor does T2.4.
3. **Batch C:** T3.1, T3.2, then T4.1 (the page).
4. **Batch D:** T4.2, T4.3, T4.4, T5.1.
5. The supervisor: T5.2 (slot), Phase 6, T7.1, the implementation review, `session-wrap` and `distill-feature`, the push (slot), the draft PR.

## Risks

- `Bundler.load.specs` in the suite versus the image (a superset in the suite): the spec says so; `bin/image-smoke` is the image proof.
- A gem that is a default gem has no directory (`bundler`): `full_gem_path` may not exist; `texts_in` rescues `SystemCallError` on `Dir.children` and returns `[]`.
- `Rails.application.assets.load_path.find` is Propshaft's API (1.3.2) and importmap-rails 2.2.3's `packages` is public; T3.1 asserts the real inputs in a spec so an upgrade that changes either fails loudly.
- The 1 MiB ceiling: measured in T4.1/T4.3 on the real bundle before it is trusted; raise it only by a decision in the spec.
- Merge conflicts with spec 082 in `licence_line_spec.rb` (T7.1).
