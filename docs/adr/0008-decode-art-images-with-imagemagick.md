# 0008: Decode art images with ImageMagick's command line

## Status

Accepted (2026-10-08, approved with spec 011's plan). ADR 0006 left the build's image decoder to spec 011's plan. The production image's agreement is checked in that plan's Phase 15 (Consequences).

**Date:** 2026-10-07
**Feature:** 011-card-scanner-art-matching

## Context

[ADR 0006](0006-art-fingerprint-and-index.md) builds the art index on the server: one fingerprint per artwork from Scryfall's `small` JPEG images. Ruby can't decode a JPEG itself, so the build needs a decoder, and ADR 0006 requires that whatever decodes the images agrees with the browser's canvas to 0 bits before its index is used. Agreement is the whole point: the page fingerprints the live capture with canvas pixels, and a decoder that rounds differently would shift every distance.

What the project has measured and has to hand (spec 011 plan, "Facts established during planning"):

- **ImageMagick's CLI** (`magick <file> -depth 8 ppm:-`, the raw pixels then read in Ruby) is what specs 008 and 010 used. It agreed with the browser to 0 bits on 198 `small` and 98 `normal` images (spec 008) and on 134 `small` images (spec 010).
- **The development machine** has ImageMagick 7 and no libvips.
- **The production image** has libvips (Rails' default `Dockerfile`) and no ImageMagick.
- **CI** (GitHub's `ubuntu-latest`) can install either with `apt`.
- **The bundle** has `image_processing` 2.2.0 without `ruby-vips`, `mini_magick` or `ffi`.

## Options considered

### Option A: ImageMagick's command line

**Pros:**
- Measured: 0-bit agreement on 330 image checks across two spikes, at the frozen settings.
- No gem. The decoder is a shell-out with fixed arguments, and the parsing is 15 lines of Ruby the spikes already tested.
- Already on the development machine; one `apt` package in CI and in the image.

**Cons:**
- About 3.2 MB more in the production image (`imagemagick` and its libraries).
- One process per image (about 50,900 for a first build). The spike's whole build, fetch included, ran at this rate; fingerprinting took 1,067 s (spec 008) and 2,901 s (spec 010) on the desktop.
- ImageMagick 6 (Ubuntu) names its command `convert`; the decoder accepts either.

### Option B: libvips through `ruby-vips`

**Pros:**
- libvips is already in the production image.
- In-process: no process per image.

**Cons:**
- Its agreement with the browser has never been measured. A different JPEG decoding path (IDCT, chroma upsampling) could put every distance off by a few bits.
- Adds the `ruby-vips` and `ffi` gems (`ffi` is a native extension) and libvips on the development machine, which doesn't have it.

### Option C: A pure-Ruby JPEG decoder

**Pros:**
- No system dependency.

**Cons:**
- No maintained gem; it would be the project's own JPEG decoder, far beyond "don't add gems for trivial functionality", and its agreement unmeasured.
- Orders of magnitude slower for 50,900 images.

## Decision

**Option A.** `MTG::Art::Decoder` runs `magick` (or `convert`) with fixed arguments on a cached image and parses the binary P6 output. The production image, CI and `bin/setup`'s check provide it. Before an index built with it is used, the shipped build and the shipped page must agree to 0 bits on spec 010's 134 artworks (spec 011 AC-8.2), and the gating suite checks the arithmetic on a generated lossless image (AC-8.3).

Option B is rejected because its agreement is unmeasured and it adds a native gem; Option C because no maintained decoder exists.

## Consequences

- The production image grows by ImageMagick (about 3.2 MB). The `Dockerfile` checks the command exists at build time.
- Developers and CI need ImageMagick to run the art specs; `bin/setup` says so when it's missing, and the workflow installs it.
- A first build spawns one short process per artwork, in the background job.
- If a later ImageMagick release changed its JPEG decoding, AC-8.2's agreement check would show it; it's re-run whenever the decoder or the settings change.
- Every agreement figure so far (330 checks) was measured with ImageMagick 7 (`magick`) on the desktop. The production image installs its Debian release's `imagemagick`, which may be version 6 (`convert`); its agreement is unmeasured until spec 011's plan compares its fingerprints of the 134 agreement images with the desktop's (Phase 15). Until that comparison shows no difference, an index built in the image isn't used.
- If the shipped agreement (Phase 16) isn't 0 bits, this decision is revisited before the index is used.
