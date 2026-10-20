# Verification: Content Notice Footer (spec 018)

**Spec:** [spec.md](spec.md) v1.2.1 · **Plan:** [plan.md](plan.md) Phase 5 · **Recorded:** 2026-10-11 ·
**Branch:** `018-content-notice-footer` · **Issue:** [#34](https://github.com/plainprogrammer/Collector/issues/34)

Evidence for every acceptance criterion. The suite examples are in `spec/requests/footer_spec.rb`,
`spec/system/footer_spec.rb`, `spec/models/catalog/content_notice_spec.rb`, `spec/models/mtg/scryfall/source_spec.rb`,
`spec/footer_core_spec.rb`, `spec/design_system_files_spec.rb`, `spec/requests/catalog/entries_show_spec.rb` and
`spec/requests/design_system_spec.rb`; all run in `bin/ci`. Three checks need the maintainer in person and are
listed under [Owed](#owed); none is claimed here.

## Commits

`git log --oneline 8e89c3d..HEAD` at the time of recording (`8e89c3d` marks the spec approved):

```text
134ce3e docs(018): record the footer in ADR 0018 and CLAUDE.md
52788e0 feat(design-system): style and document the footer
8ab8683 feat(layout): show the content notices in a footer on every page
3f998f8 feat(mtg): supply the Fan Content notice and the Scryfall attribution
1cefb9c feat(catalog): collect each source's content notice
c0ea4bb docs(018): approve the plan with a body class for the phone layout
b19231c docs(018): revise the plan after its review
dd2fb08 docs(018): plan the content notice footer
```

The five code commits are the plan's five phases, in order. Their tree is identical to the plan's tested phase
commits: `git diff 923663d HEAD` shows only `docs/specs/018-content-notice-footer/`.

## Red, then green

Each phase's specs were run before its implementation existed, then after, on this branch:

| Phase | Before | After |
|---|---|---|
| 0 | `content_notice_spec.rb`: `0 examples, 0 failures, 1 error occurred outside of examples` (`uninitialized constant Catalog::ContentNotice`) | with `catalog_spec.rb`: `32 examples, 0 failures`; `zeitwerk:check`: `All is good!` |
| 1 | `source_spec.rb`: `18 examples, 1 failure` (`undefined method 'content_notice' for class MTG::Scryfall::Source`) | with `content_notice_spec.rb`: `44 examples, 0 failures` |
| 2 | the four request and file-content specs: `42 examples, 22 failures` | `42 examples, 0 failures`; `spec/requests` and `spec/admin_catalog_core_spec.rb`: `359 examples, 0 failures` |
| 3 | `spec/system/footer_spec.rb`: `9 examples, 8 failures`; `design_system_files_spec.rb`: `4 examples, 1 failure` | both: `13 examples, 0 failures`; `spec/system`: `105 examples, 0 failures, 1 pending` |
| 4 | documents only | `project_config_spec.rb`, `readme_spec.rb`: `13 examples, 0 failures` |

RuboCop reported `no offenses detected` before each commit.

## `bin/ci`

Run on `134ce3e`, the last code commit (only documents are committed after it):

```text
✅ Setup passed in 7.58s
456 files inspected, no offenses detected
✅ Style: Ruby passed in 1.76s
No warnings found
✅ Security: Brakeman code analysis passed in 6.81s
No vulnerabilities found
✅ Security: Gem audit passed in 0.67s
No vulnerable packages found
✅ Security: Importmap vulnerability audit passed in 1.68s
Finished in 3 minutes 31 seconds (files took 4.86 seconds to load)
1178 examples, 0 failures, 1 pending
✅ Tests: RSpec passed in 3m37.43s
✅ Continuous Integration passed in 3m55.92s
```

The pending example is the art fingerprint agreement check, which needs `COLLECTOR_ART_AGREEMENT` and is not part
of this feature. The suite ran with seed 48078.

The plan also asks for the system specs under three seeds. That was done on the plan's phase commits, whose code is
this branch's: `spec/system` under seeds 54457, 1 and 2 gave `105 examples, 0 failures, 1 pending` each before the
plan review, and `spec/system/footer_spec.rb` under seeds 1 and 2 gave `9 examples, 0 failures` after its fixes. On
this branch `spec/system` ran twice more (once alone, once in `bin/ci`), green both times.

## Acceptance criteria

| Criterion | Result | Evidence |
|---|---|---|
| AC-1.1, AC-1.2, AC-1.9, AC-1.10 | Met | `requests/footer_spec.rb` "is on every page, after the main content" (12 pages); wording and addresses in `source_spec.rb` |
| AC-1.3 | Met | "is on the first-run sign-up page", "is on the sign-in page and on open sign-up" |
| AC-1.4 | Met | "is on the admin pages" (users, new user, edit user, catalog, jobs) |
| AC-1.5 | Met | "is there while the catalog isn't loaded" |
| AC-1.6 | Met | one footer and its two lines asserted on every page; a lot form at 422; the sign-in form at 422 and 429 |
| AC-1.7 | Met | "holds the card page's only attribution"; `entries_show_spec.rb` "leaves the source's attribution to the page's footer" |
| AC-1.8 | Met | "is left out of an answer that isn't a page" (a `Turbo-Frame` request, a Turbo Stream answer, the health check; the same address without the header carries it) |
| AC-2.1, AC-2.7 | Met | "shows a second type's lines after the first's, a link only where a line names one"; `content_notice_spec.rb` |
| AC-2.2 | Met | "shows nothing for a type whose source supplies no notice"; `content_notice_spec.rb` |
| AC-2.3 | Met | "has no footer element when no type supplies a notice" (and the shell isn't marked); `content_notice_spec.rb` |
| AC-2.4 | Met | "shows a line two types supply once"; `content_notice_spec.rb` |
| AC-2.5, AC-2.6 | Met | `spec/footer_core_spec.rb` |
| AC-3.1, AC-3.2 | Met | `system/footer_spec.rb` "stops above the phone's tab bar, inside the gutter, at 390px and 360px" (collection, card page, More), "wraps inside the gutter on the sign-in page at 360px"; screenshots 03, 04, 06 |
| AC-3.3 | Met | "follows short content directly, in normal flow, on a wide screen"; screenshot 01 |
| AC-3.4 | Met | light and dark examples compute the contrast of the footer's text and links against the page: 6.12:1 and 7.22:1 light, 7.24:1 and 7.74:1 dark; screenshots 05, 06 |
| AC-3.5 | Met | "is text and its links, with nothing else in it" (only `p` and `a` elements) |
| AC-3.6 | Met | "clears the sticky filter bar and the bulk bar", wide and at 390px |
| AC-3.7 | Met | `design_system_files_spec.rb`; `docs/design-system/components/Footer.md`; the README's spec 018 line |
| AC-3.8 | Met | attributes are `rel` and `href` only (no `target`); colour, weight, underline on hover and the focus ring in the light-theme system example |
| AC-4.1 | Met | "is styled on the scanner page, under its policy"; screenshot 04 |
| AC-4.2, AC-4.3 | Met | every directive and source of the policy asserted on the scanner, measurement and replay pages, the nonce by pattern |
| AC-4.4 | Met | "clears the scanner and the tab bar on a phone"; screenshot 04 |

Checked by eye, in the screenshots, in addition to the examples: AC-3.1, AC-3.3, AC-3.4, AC-4.1, AC-4.4 and the
overall look (small print under a divider, on the page gutter, brand-coloured links, nothing over it).

**Not covered by an example.** A morph refresh (FR-2): the footer has no state or id to lose, and the admin catalog
page's polling specs pass with the footer present. Touch targets, which headless Firefox can't test: `Footer.md`
states the rule the links follow. Following a footer link from the scanner mid-sitting (Error Scenarios): spec 009
AC-3.3's behaviour, unchanged here, and owed below.

## Screenshots

Taken on this branch in headless Firefox from test data (the cards have no images, so each shows its name on a
blank card). Phone shots are a 390 × 844 frame scrolled to the end of the page.

| File | Shows |
|---|---|
| [01-sign-in.jpg](screenshots/01-sign-in.jpg) | Sign-in at 1280px: the footer directly under a short page |
| [02-card-page-end.jpg](screenshots/02-card-page-end.jpg) | A card page at 1280px, scrolled to its end: the attribution only in the footer |
| [03-card-page-phone.jpg](screenshots/03-card-page-phone.jpg) | A card page at 390px: the last line above the tab bar, no empty band before the footer |
| [04-scanner-phone.jpg](screenshots/04-scanner-phone.jpg) | The scanner at 390px, under its Content-Security-Policy |
| [05-collection-dark.jpg](screenshots/05-collection-dark.jpg) | The collection at 1280px, dark theme |
| [06-collection-phone-dark.jpg](screenshots/06-collection-phone-dark.jpg) | The collection at 390px, dark theme |

## Deviations from the plan

- **The plan's one approved change** was made before execution and is in the plan: the shell carries
  `c-shell--footed` where the reviewed plan used a `:has()` selector. It changed one existing assertion
  (`spec/requests/design_system_spec.rb` expected the bare `class="c-shell"`), which Phase 2 updates.
- **How it was executed.** The phases were applied in the main session from the plan's tested phase commits,
  each seen red then green here, not by one subagent per phase as `sdd-execute` prescribes. The code is the plan's,
  byte for byte.
- **Screenshots.** The plan's 0.6s pause after a theme switch was kept. The dark shots set `data-theme="dark"`
  by script, which is what the suite's theme spec doesn't do (it uses the OS preference); both paths are covered
  between them.
- Nothing else differs: no requirement, wording, file or commit message beyond the plan's.

## Implementation review

A read-only Fable review (sdd-review Mode B) of `8e89c3d..3507443` found the implementation **spec-aligned**, with
nothing blocking: the code is byte-identical to the plan's blocks, and its own runs gave `99 examples, 0 failures`
for the eight feature files, `1178 examples, 0 failures, 1 pending` for the whole suite (seed 9544) and no RuboCop
offense. Its minor notes:

- This document said 13 pages for AC-1.1; the example visits 12. Corrected above.
- FR-2's "runs no query" example counts queries at the model (`Catalog::ContentNotice.lines` and each line's
  parts), not around a page render. The partial and the layout's two lines make no database call, so the
  requirement holds; the example would not catch a query added to the partial later. Left as it is, and recorded.
- The red-then-green table and the three-seed runs are records of runs, which a read-only review can't repeat.

## Owed

Checks that need the maintainer and are not claimed:

1. **A real phone.** `env(safe-area-inset-bottom)` is zero in headless Firefox. On the phone, scroll one page with
   the tab bar to its end and confirm the footer's last line stops above the bar, with the home indicator clear.
2. **Touch.** Tap both links on the phone: each opens in the same tab and Back returns.
3. **The scanner mid-sitting.** With a card added to the sitting, follow a footer link from `/scanner` and come
   back: the camera starts again and the sitting still lists the card.

Also for the PR: an adjacent-line conflict with spec 019 is likely at the end of `collector/additions.css`, in
`docs/design-system/README.md` after the spec 015 line, and in the pattern list of
`spec/design_system_files_spec.rb`. Keep both sides. The local scratch branch `018-plan-phases` is deleted.
