---
name: bulk-file-copy
description: Copy tens of thousands of files with find -exec cp -t {} +, never a shell glob (Argument list too long)
metadata:
  type: feedback
---

To seed a directory with a large cache (the spike's 50,924 art images into `storage/catalog/mtg/art/small/`), give the maintainer `find <src> -maxdepth 1 -name '*.jpg' -exec cp -n -t <dest>/ {} +`, not `cp -n <src>/*.jpg <dest>/`.

**Why:** in spec 011 (2026-10-08) the plan's glob command failed in the maintainer's shell with "/usr/bin/cp: Argument list too long", costing a round trip.

**How to apply:** whenever a command handed to the maintainer (`! …`) or written into a plan copies, moves or lists more than a few thousand files, use `find … -exec … {} +` (or `cp -r src/. dest/` when every file is wanted). Related: [[secret-files-user-verified]] (agents can't write `storage/`, so these commands go to the maintainer).
