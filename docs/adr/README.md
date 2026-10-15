# Architecture Decision Records

One file per decision: `docs/adr/NNNN-<slug>.md`, four digits, numbered from 0001 in the order written and never renumbered once merged. An ADR written on a branch takes the next free number when another branch's ADR took its number first (check `origin/main` and open branches before numbering); its Status line then says what it was written as and why it moved, as 0012, 0014 and 0015 do.

Each ADR has these sections, in this order:

- **Title**: `# NNNN: <decision>` as the first line
- **Status**: `Proposed`, `Accepted`, `Rejected` or `Superseded by NNNN`
- **Context**: the problem and the evidence, linking the spec or research
- **Decision**: what we will do
- **Consequences**: what follows, good and bad

Specs and plans link the ADRs they rely on. To change a decision, write a new ADR that supersedes the old one.

An ADR that records a decision made before it was written says so in its Status line ("recorded …, after the fact; decided in spec NNN"), as 0016–0019 do.

## Index

Add a line here with each new ADR. All are Accepted unless the line says otherwise.

### Foundation

- [0016](0016-sqlite-in-every-environment.md): SQLite in every environment, one file per role
- [0017](0017-row-level-tenancy-one-user-per-account.md): Row-level tenancy, one user per account
- [0018](0018-collectible-agnostic-catalog-core.md): A collectible-agnostic catalog core with per-type extensions
- [0019](0019-lot-as-the-unit-of-ownership.md): The lot is the unit of ownership

### Card scanner

- [0001](0001-browser-ocr-engine-and-asset-hosting.md): Self-host Tesseract.js 7 for in-browser OCR
- [0002](0002-camera-path-testing.md): Test the camera path by substituting getUserMedia in the page
- [0003](0003-card-name-index.md): Index card names with an FTS5 trigram table
- [0004](0004-card-recognition-in-the-browser.md): Card recognition runs in the browser only
- [0005](0005-hand-written-card-detector-for-the-photo-path.md): Detect and straighten the card with a hand-written detector on the photo path
- [0006](0006-art-fingerprint-and-index.md): Fingerprint the artwork and build the art index from the catalog's images
- [0007](0007-art-search-in-the-browser.md): Search the art index in the browser
- [0012](0012-decode-art-images-with-imagemagick.md): Decode art images with ImageMagick's command line

### Images and publishing

- [0008](0008-public-images-from-the-private-repository.md): Publish public container images from the private repository
- [0009](0009-image-tags-and-release-channels.md): Image tags and release channels
- [0010](0010-native-multi-architecture-image-builds.md): Native multi-architecture image builds
- [0011](0011-own-ghcr-cleanup-script.md): Own script for GHCR untagged-version cleanup
- [0013](0013-active-storage-variants-with-vips.md): Process Active Storage variants with libvips through `ruby-vips`

### Admin

- [0014](0014-hand-built-admin-jobs-console.md): Hand-build the admin jobs console on Solid Queue's models
- [0015](0015-admin-progress-by-polling.md): Show live progress on admin pages by polling with Turbo morph refreshes

### Data safety

- [0020](0020-export-format.md): The export format is one versioned JSON document keyed by source ids
- [0021](0021-export-format-rules-in-the-app.md): The app checks export files with `json_schemer` and its own copy of the schema

### Expected

Named by the [roadmap](../roadmap.md) and written with their specs: the backup mechanism (item 6), lots in locations (item 10).
