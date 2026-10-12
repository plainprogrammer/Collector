---
name: no-readme-wording-specs
description: Don't write or extend RSpec examples that test README.md's wording or section order; the maintainer had spec/readme_spec.rb removed in spec 020
metadata:
  type: feedback
---

Don't add RSpec examples that assert phrases, section order or links in the root `README.md`. Plans for specs 004, 007, 011, 012, 014 and 015 each added such examples to `spec/readme_spec.rb`; spec 020 removes that file.

**Why:** on 2026-10-12, while approving spec 020 (issue #63), the maintainer said: "I want to drop the README RSpec. It is without precedence in my experience to have such a spec." It came up because the file pinned README phrases that a correction to the README would have had to keep or update.

**How to apply:** when a spec has a README criterion ("the README documents X"), verify it by reading and record it in `verification.md`; don't turn it into a failing-test-first step. My interpretation, not the maintainer's words: this is about the root README's prose. The ruling didn't cover the other file-shape specs (`spec/image_publishing_spec.rb`, `spec/project_config_spec.rb`, `spec/design_system_files_spec.rb`, the export format's document specs), which check configuration and documents the app or tooling depends on; ask before removing or adding to those on this ground. Related: [[sdd-review-model-choice]].
