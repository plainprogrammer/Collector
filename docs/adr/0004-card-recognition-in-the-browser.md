# 0004: Card recognition runs in the browser only

## Status

Proposed (2026-10-02, spec 008 brainstorm)

**Date:** 2026-10-02
**Feature:** 008-card-scanner-phase-2-spike

## Context

Phase 2 of the card scanner adds two techniques that work on the picture of the card, not on text read from it: card detection (finding the card's edges and straightening it) and art matching (comparing a fingerprint of the artwork with an index of every artwork in the catalog). Before either is tested, the project has to decide where that work may run, because the answer fixes which techniques the Phase 2 spike ([prd.md](../specs/008-card-scanner-phase-2-spike/prd.md)) compares.

What bears on the decision:

- **The current guarantee.** Spec 007 FR-3 says the app must not "send any frame, strip or photo to the app outside development measurement mode, or to any other host at all". [ADR 0001](0001-browser-ocr-engine-and-asset-hosting.md) runs text recognition in the browser for the same reason. Only recognised text reaches the app.
- **The roadmap allows more.** The scanner roadmap (`~/Downloads/card-scanner-research-and-roadmap.md`) states the privacy principle as "frames never leave the user's device or the user's own server", and proposes a Python/OpenCV sidecar (a Kamal accessory) when the scanner needs robust straightening or an exact reproduction of a published art-hash index.
- **Self-hosting.** The foundation's first principle is that an instance is easy to self-host. Both deployment paths (Compose and Kamal) run one container today.
- **Evidence so far.** In-browser text recognition takes a median of 168 ms per capture on the maintainer's iPhone (spec 007 research.md §5, n=49). In-browser detection and art fingerprinting have not been measured in this project; the spike measures them. The roadmap's figure for OpenCV.js is a download of about 8 MB, which is also unmeasured here.

## Options considered

### Option A: In the browser only

**Pros:**
- Keeps spec 007's guarantee as it stands: the picture never leaves the device.
- Self-hosters run nothing new, on either deployment path.
- No upload of a multi-megabyte picture per scan, so no added latency or server load from other tenants' scans.

**Cons:**
- Limited to what runs in a phone's browser, at a cost in download size and time per frame that is not yet measured.
- A published art index built with another tool's image resampling can't be assumed to match fingerprints computed in the browser, so the project builds and maintains its own index.

### Option B: The instance's own server too

**Pros:**
- Mature tools are available (OpenCV in Python, ruby-vips), including exact reproduction of a published index.
- No extra download for the collector's device.

**Cons:**
- The picture is uploaded to the instance, so spec 007 FR-3 and the scanner page's privacy promise have to change.
- A sidecar is a second container for every self-hoster, on both deployment paths.
- Every scan becomes server work on a multi-tenant instance.

### Option C: Test both in the spike and decide afterwards

**Pros:**
- The decision would rest on measured accuracy for both.

**Cons:**
- About twice the spike work.
- The server option's main costs are privacy and hosting, which no accuracy figure changes.

## Decision

**Option A: card recognition runs in the browser only.** Detection, straightening and fingerprinting of a picture happen on the collector's device. The app receives only what is derived from the picture: recognised text, or a fingerprint. The Phase 2 spike therefore tests in-browser techniques only.

The reason is the PRD's constraint that Phase 2 keeps spec 007's privacy guarantee and adds nothing a self-hoster has to run. Option B breaks both, and Option C spends spike effort on an option whose main costs measurement can't remove.

## Consequences

- The spike compares in-browser detectors only, and computes the art fingerprint in the browser. Server-side straightening and fingerprinting of collectors' pictures are not tested.
- If in-browser detection or art matching turns out too inaccurate, too large or too slow, the remedy is to defer or drop the technique. Moving it to the server needs a new ADR that supersedes this one, together with a change to spec 007 FR-3.
- The art index is built from the catalog source's images when the catalog refreshes. That work handles catalog data, not collectors' pictures, so it can run on the server. The fingerprint is then computed in two places (the index build and the browser), so the spike must measure whether the two agree closely enough to match.
- Whether the browser downloads the index and searches it, or sends the fingerprint for the server to search, stays open. Both satisfy this decision, and the spike measures both.
- Development-only measurement mode, which stores strips on the maintainer's machine, is unchanged.
- A later native app is consistent with this decision as long as it recognises cards on the device.
