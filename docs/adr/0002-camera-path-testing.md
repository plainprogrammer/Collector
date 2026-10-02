# 0002: Test the camera path by substituting getUserMedia in the page

## Status

Accepted (2026-09-30, spec 007 plan)

## Context

Phase 1's scanner page will use the camera. The suite that gates merges (`bin/ci`) runs system specs in headless Firefox through Selenium, with no person and no camera, so a system test must be able to supply a known card image as the camera feed and assert something specific to that card (spec 005, Story 2).

Phase 0 tried three approaches against a throwaway camera page, asserting that a 256-bit average hash of the captured frame is within 32 bits of the source photo's hash ([research.md](../specs/005-card-scanner-phase-0/research.md), Section 4):

| Approach | Supplies the card? | Passes in 10 runs | Median time per example | Extra setup |
|---|---|---|---|---|
| Firefox fake camera (`media.navigator.streams.fake`, `media.navigator.permission.disabled`) | No: a synthetic pattern, distance 110 | 10/10 (asserting it is *not* the card) | 3.42 s | None |
| Chrome with `--use-file-for-fake-video-capture` and a `.y4m` made with ffmpeg | Yes: distance 27 | 10/10 | 1.41 s | Chrome as a second browser (on GitHub's `ubuntu-24.04` image; downloaded by Selenium Manager on the dev machine); ffmpeg, which the CI image lacks, or a `.y4m` written in Ruby |
| In-page `getUserMedia` substitution in Firefox (a canvas drawn from the photo, `captureStream`) | Yes: distance 0 | 10/10 | 1.61 s | None; no browser prefs |

No flakes were seen. Selenium Manager tried to send usage statistics to `plausible.io` on its first run; `SE_AVOID_STATS=true` turns that off. FR-1 forbids committing corpus photos, so Phase 1 needs a synthetic or suitably licensed card image as its fixture.

## Decision

- Cover the scanner's capture → OCR → candidates flow with system tests that replace `navigator.mediaDevices.getUserMedia` inside the page with a stream drawn from a fixture card image, in the existing headless Firefox driver. Assert on the card (a hash match or the recognised name), not just that a frame was captured.
- Optionally, if the maintainer accepts the cost, add one Chrome file-capture test that exercises the browser's real media and permission path, with the `.y4m` generated at test time and `SE_AVOID_STATS=true` set.
- Don't use Firefox's fake camera for any test that asserts on the content of the feed.
- Use a synthetic or suitably licensed card image as the fixture, never a corpus photo.

## Changes from the Proposed text (spec 007)

- The fixture card is drawn in the page: the substituted stream paints a white 63:88 card whose name and collector line sit exactly where the scanner cuts its strips (the page's own `scanner/geometry` module), so real OCR runs on it and no image is committed.
- The system driver grants camera access without a prompt and starts with Firefox's synthetic stream (`media.navigator.permission.disabled`, `media.navigator.streams.fake`); a spec then substitutes its card and restarts the page's camera controller.
- The optional Chrome file-capture test isn't added in spec 007.

## Consequences

- No CI change and no second browser for the main camera tests; they were deterministic in the spike.
- The substituted stream skips the browser's real `getUserMedia` and permission prompt, so bugs there (constraints, permission denial, track teardown) are not caught unless the optional Chrome test is added or they are tested separately.
- The page's camera code needs one seam the test can replace (`navigator.mediaDevices.getUserMedia`), which it has by default; no test-only code ships in the page.
- If the Chrome test is added: a second browser in CI, an ffmpeg install or a Ruby `.y4m` writer, and a hash margin that was tight in the spike (27 of a 32 threshold).
