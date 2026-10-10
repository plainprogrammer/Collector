# Verification: Active Storage Variants with vips (spec 014)

**Spec:** [spec.md](spec.md) v1.1.1 · **Plan:** [plan.md](plan.md) Phase 5 · **Recorded:** 2026-10-09 ·
**Branch:** `014-active-storage-vips`

Evidence for every acceptance criterion. The suite examples are in
`spec/config/active_storage_variant_transformer_spec.rb`, `spec/lib/collector/libvips_check_spec.rb`,
`spec/image_publishing_spec.rb` and `spec/readme_spec.rb`; all four run in `bin/ci`. The image criteria are shown
by local runs on an amd64 build. Two criteria needed this PR's GitHub Actions run, which passed; see [Pull request CI](#pull-request-ci-ac-13-ac-23). The image
size measurement corrected the spec's figure (1.1.1); see [Image size](#image-size).

## Commits

`git log --oneline main..HEAD` at the time of recording (`main` is at `ff06ebd`):

```text
22871fc test(image): smoke-check that the image's variants use libvips (014)
a60e493 ci(test): install libvips for the test job and list system libraries in the README (014)
4d72e3f feat(setup): report a missing libvips in bin/setup (014)
04020de feat(storage): process Active Storage variants with ruby-vips (014)
38d2b50 docs(014): correct the plan after the second Fable review
275159a docs(014): add the approved implementation plan
fc659fc docs(014): revise the spec after the Fable spec review (1.1.0)
c8a31b0 chore(memory): make Fable reviews of PRDs, specs and plans the default
168976f docs(014): add the approved Active Storage vips spec
75f4ec9 docs(014): add the Active Storage vips PRD
30593b9 docs(adr): process Active Storage variants with vips (0013)
```

## Machine

Development machine, x86_64, Fedora 44, Ruby 4.0.7. `rpm -q vips ImageMagick`:

```text
vips-8.18.3-2.fc44.x86_64
ImageMagick-7.1.2.32-1.fc44.x86_64
```

## Local gate: `bin/ci` (AC-2.4)

Run on 2026-10-09 at `22871fc`, exit status 0. Every step passed
(`✅ Continuous Integration passed in 2m24.86s`).

| Step | Result |
|---|---|
| Setup | passed in 4.98s |
| Style: Ruby (RuboCop) | 416 files inspected, no offenses detected; passed in 3.30s |
| Security: Brakeman | Security Warnings: 0; passed in 5.44s |
| Security: Gem audit (bundler-audit) | No vulnerabilities found; passed in 0.55s |
| Security: Importmap audit | No vulnerable packages found; passed in 1.42s |
| Tests: RSpec | 925 examples, 0 failures, 1 pending (seed 34214); passed in 2m9.17s |

The pending example is `spec/system/art_agreement_spec.rb:16` (spec 011 AC-8.2), which is skipped unless
`COLLECTOR_ART_AGREEMENT` is set. It is not part of this feature.

## Feature specs

`bin/rspec spec/config/active_storage_variant_transformer_spec.rb spec/lib/collector/libvips_check_spec.rb
spec/image_publishing_spec.rb spec/readme_spec.rb --format documentation` at `22871fc`:
`38 examples, 0 failures` (seed 2446). The examples for this feature:

```text
Image publishing files
  bin/image-smoke
    checks that Active Storage variants use libvips without a warning (spec 014 AC-1.3, FR-2)
  .github/workflows/ci.yml
    installs libvips and ImageMagick before bin/ci (spec 014 AC-2.3, FR-3)

Collector::LibvipsCheck
  is what bin/setup runs, beside the ImageMagick check (AC-3.5)
  probes by loading ruby-vips in the bundle, not with a vips command (AC-3.4)
  #hint
    is nil when the probe succeeds (AC-3.1)
    finds libvips with the default probe where it's installed, as in development and CI (AC-3.4)
    names libvips and both packages when the probe fails, exits non-zero or can't run (AC-3.2)

ActiveStorage.variant_transformer
  resizes an image with libvips (AC-2.1)
  comes from a ruby-vips that Bundler.require doesn't load, so the app boots without libvips (AC-3.3)
  is the vips transformer (AC-2.2)

README
  lists libvips and ImageMagick with their packages (spec 014 AC-4.1)
```

## `bin/setup` on this machine (AC-3.5)

`bin/setup --skip-server 2>&1 | grep -A2 "Checking libvips"`:

```text
== Checking libvips (Active Storage variants, ADR 0013) ==

== Configuring linked worktree ==
```

The heading is followed by a blank line and the next heading. No hint is printed.

## The image, locally (AC-1.1, AC-1.2, AC-1.3 amd64 half, AC-1.4)

`collector:vips` is a local `linux/amd64` build of this branch (`podman build`, image `74e1850efd90`, created
2026-10-10T02:19:51Z). It was built and smoke-tested in Phase 4; the two smoke outputs below are that phase's
saved files, not re-run here. The `bin/rails runner` call was re-run for this record.

`bin/image-smoke collector:vips`, exit status 0:

```text
== boot collector:vips
== first run
== operational tasks
== Active Storage variants use libvips (spec 014)
== pages and assets (a user exists now, so first-run redirects are over)
== development-only paths and secrets must be absent
OK: collector:vips passed the smoke test
```

`bin/image-smoke ghcr.io/plainprogrammer/collector:0.1.0`, exit status 1:

```text
== boot ghcr.io/plainprogrammer/collector:0.1.0
== first run
== operational tasks
== Active Storage variants use libvips (spec 014)
FAIL: vips: variants can't use libvips:
Generating image variants with libvips requires the ruby-vips gem. Please add `gem "ruby-vips", "~> 2.3"` to your Gemfile.
```

`podman run --rm -e SECRET_KEY_BASE=smoke-only-not-a-secret collector:vips bin/rails runner 'puts
ActiveStorage.variant_transformer' 2>&1`, exit status 0, the whole output:

```text
ActiveStorage::Transformers::Vips
```

## Pull request CI (AC-1.3, AC-2.3)

Draft PR [#30](https://github.com/plainprogrammer/Collector/pull/30), run on 2026-10-10 (UTC).

- Run URL: https://github.com/plainprogrammer/Collector/actions/runs/38017148420
- Commit: `31b36e9`
- Conclusion: success. `Publish manifest list` was skipped, as it is on every PR.

| Job | Result |
|---|---|
| [`ci`](https://github.com/plainprogrammer/Collector/actions/runs/38017148420/job/114109856067) (`bin/ci`, after the libvips install step) | ✓ The install step set up `libvips42t64:amd64 (8.15.1-1.1build4)`. `bin/ci`: `925 examples, 0 failures, 1 pending`, `Continuous Integration passed in 2m20.79s` |
| [Image (linux/amd64)](https://github.com/plainprogrammer/Collector/actions/runs/38017148420/job/114110419246), `Smoke test` step | ✓ `== Active Storage variants use libvips (spec 014)`, then `OK: collector:smoke passed the smoke test` |
| [Image (linux/arm64)](https://github.com/plainprogrammer/Collector/actions/runs/38017148420/job/114110419241), `Smoke test` step | ✓ the same two lines |

Both image builds installed `libvips42t64 8.16.1-1+deb13u1`. The spec and evidence commits pushed after `31b36e9`
change only `docs/`, which `.dockerignore` keeps out of the image.
Nothing has been run on arm64 locally; the arm64 evidence is the workflow job above.

## Acceptance criteria

| AC | Evidence | Status |
|---|---|---|
| AC-1.1 | Local `bin/image-smoke collector:vips` passes its vips check, which fails on either warning. The `bin/rails runner` output above has one line and neither warning | ✓ (amd64, local build) |
| AC-1.2 | `bin/rails runner 'puts ActiveStorage.variant_transformer'` in `collector:vips` prints `ActiveStorage::Transformers::Vips` | ✓ (amd64, local build) |
| AC-1.3 | File shape: `image_publishing_spec.rb` `bin/image-smoke` "checks that Active Storage variants use libvips without a warning (spec 014 AC-1.3, FR-2)". amd64: the local smoke run above. Both architectures: the PR's workflow run, where each `Smoke test` step printed the vips heading and passed | ✓ |
| AC-1.4 | `bin/image-smoke ghcr.io/plainprogrammer/collector:0.1.0` exits 1 with `FAIL: vips: variants can't use libvips:` and the ruby-vips warning | ✓ |
| AC-2.1 | `active_storage_variant_transformer_spec.rb` "resizes an image with libvips (AC-2.1)" | ✓ |
| AC-2.2 | `active_storage_variant_transformer_spec.rb` "is the vips transformer (AC-2.2)" | ✓ |
| AC-2.3 | File shape: `image_publishing_spec.rb` `.github/workflows/ci.yml` "installs libvips and ImageMagick before bin/ci (spec 014 AC-2.3, FR-3)". Run: the `ci` job installed `libvips42t64` before `bin/ci`, which passed with 0 failures | ✓ |
| AC-2.4 | `bin/ci` above: 925 examples, 0 failures on this machine, which has libvips 8.18.3 | ✓ |
| AC-3.1 | `libvips_check_spec.rb` `#hint` "is nil when the probe succeeds (AC-3.1)" | ✓ |
| AC-3.2 | `libvips_check_spec.rb` `#hint` "names libvips and both packages when the probe fails, exits non-zero or can't run (AC-3.2)" | ✓ |
| AC-3.3 | `active_storage_variant_transformer_spec.rb` "comes from a ruby-vips that Bundler.require doesn't load, so the app boots without libvips (AC-3.3)"; `Gemfile:43` is `gem "ruby-vips", "~> 2.3", require: false` | ✓ |
| AC-3.4 | `libvips_check_spec.rb` "probes by loading ruby-vips in the bundle, not with a vips command (AC-3.4)" and `#hint` "finds libvips with the default probe where it's installed, as in development and CI (AC-3.4)" | ✓ |
| AC-3.5 | File shape: `libvips_check_spec.rb` "is what bin/setup runs, beside the ImageMagick check (AC-3.5)". Run: the `bin/setup --skip-server` output above, with no hint | ✓ |
| AC-4.1 | `readme_spec.rb` "lists libvips and ImageMagick with their packages (spec 014 AC-4.1)" | ✓ |

## Functional requirements: "must not" checks

| Requirement | Command | Result |
|---|---|---|
| FR-1: don't set `config.active_storage.variant_processor` | `grep -rn "variant_processor" config/` | no match (exit 1) |
| FR-1: don't add `mini_magick` | `grep -n "mini_magick" Gemfile Gemfile.lock` | no match (exit 1) |
| FR-2: don't change the `Dockerfile`'s packages | `git diff ff06ebd..HEAD --stat -- Dockerfile` | empty: the `Dockerfile` is unchanged on this branch |
| FR-3: don't skip or tag out the variant spec | `bin/ci` ran it: "resizes an image with libvips (AC-2.1)" is among the 925 examples | ran, passed |

FR-1 "must" lines seen in the same session: `Gemfile:41` keeps `gem "image_processing", "~> 2.2"`;
`config/application.rb:26` keeps `config.load_defaults 8.1`; `Gemfile.lock` has `ruby-vips (2.3.0)` and
`ffi (1.17.4-…)` for `x86_64-linux-gnu`, `aarch64-linux-gnu`, `arm-linux-gnu` and the three `musl` variants.

## Non-functional requirements

| NFR | Evidence | Status |
|---|---|---|
| Testability | The suite examples, file-shape examples and evidence listed in the NFR are the rows above | ✓ |
| Security | libvips versions seen: 8.16.1 in the image (`libvips42t64:amd64 8.16.1-1+deb13u1`, from `dpkg -l` in `collector:vips`) and 8.18.3 on this machine. All are newer than 8.13. Ubuntu 24.04 installed 8.15.1 in the PR's `ci` job. No code on this branch touches `Vips.block_untrusted`; that default was not tested directly | partly checked |
| Portability | amd64: local build and smoke run. amd64 and arm64: both image jobs built and passed `Smoke test` in the PR's workflow run | ✓ |
| Image size | The two gems add about 2.7 MB; see below | ✓ (figure corrected in spec 1.1.1) |
| Boot | AC-3.3's example shows `Bundler.require` doesn't load `ruby-vips`. The app was not booted on a machine without libvips | shown by the spec only |

### Image size

The NFR says the image grows by at most the `ruby-vips` and `ffi` gems. Spec 1.1.0 put that under 1 MB, an
estimate from spec 008. Measured in `collector:vips` with `du -sk` on each gem's `bundle info --path`:

```text
644	/usr/local/bundle/ruby/4.0.0/gems/ruby-vips-2.3.0
2056	/usr/local/bundle/ruby/4.0.0/gems/ffi-1.17.4-x86_64-linux-gnu
```

The two gems take 2,700 KB on disk, about 2.7 MB, so the "under 1 MB" estimate was wrong. The maintainer accepted
the growth on 2026-10-09, and spec 1.1.1 states the measured figure. Neither gem is in
`0.1.0`'s bundle (its `Gemfile.lock` has no `ffi` entry). `du -sk /usr/local/bundle` is 170,940 KB in
`collector:vips` and 168,232 KB in `0.1.0`: a difference of 2,708 KB, which matches the two gems.

Whole images, from `podman image inspect --format '{{.Size}}'`:

| Image | Size (bytes) |
|---|---|
| `collector:vips` (this branch, local build) | 555,472,104 |
| `ghcr.io/plainprogrammer/collector:0.1.0` (commit `63596c6`) | 534,815,625 |
| Difference | 20,656,479 (about 20.7 MB) |

This difference is not a measure of this feature. `0.1.0` is 87 commits behind this branch, and the two builds
differ in other ways:

- **A duplicate OCR engine in the local build, 14,496 KB.** `collector:vips` has both `/rails/vendor/ocr/v7.0.0`
  and `/rails/vendor/v7.0.0`; `0.1.0` has only the first. The worktree holds the ignored `vendor/ocr/v7.0.0`
  (installed by `bin/setup`), and `Dockerfile:39` (`COPY vendor/* ./vendor/`) copies the contents of `vendor/ocr`
  into `/rails/vendor`. The `Dockerfile` is unchanged on this branch, so this comes from building in a set-up
  worktree, not from this feature. `0.1.0` was built by CI from a fresh checkout and has no duplicate. Tracked in
  [#31](https://github.com/plainprogrammer/Collector/issues/31).
- **ImageMagick**, added to the `Dockerfile`'s packages after `0.1.0` (spec 011). Its size was not measured
  separately. `du -sk /usr` grew by 5,112 KB, which includes the 2,708 KB of gems.
- **App code** from specs 011 and 013: `/rails/app`, `config`, `lib` and `db` are each slightly larger.

No comparison was made against an image built from `main` at `ff06ebd`, which would isolate this branch's growth.

## Still owed

1. The duplicate `/rails/vendor/v7.0.0` in locally built images is outside this feature:
   [#31](https://github.com/plainprogrammer/Collector/issues/31).
