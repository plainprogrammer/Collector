---
name: no-readme-wording-specs
description: Don't check prose documents (README.md, CLAUDE.md, skill files, Markdown under docs/) from RSpec; verify document criteria by reading. The export format's document is the one exception (spec 020, decision 7)
metadata:
  type: feedback
---

Don't add RSpec examples that check the wording, order, links or existence of a prose document: `README.md`, `CLAUDE.md`, an agent skill file, or Markdown under `docs/` (`docs/releasing.md`, the design system's documents, the ADR index). The design system's reference files beside its Markdown (`tokens.json`, `previews/`) count too: the line is who reads the file, not its extension. Plans for about eleven specs between 004 and 019 added such examples; spec 020 removes them.

**Why:** on 2026-10-12, approving spec 020 (issue #63), the maintainer said: "I want to drop the README RSpec. It is without precedence in my experience to have such a spec." I first read that as the one file. They corrected me the same day: "I mean more broadly regarding the README spec. I think it's odd to check documents outside code from RSpec. So, please apply my ruling more broadly."

**How to apply:** when a spec has a document criterion ("the README documents X", "docs/releasing.md records Y"), verify it by reading and record it in `verification.md`; don't turn it into a failing-test-first step. Asked how far the ruling goes, the maintainer chose "prose documents only". These stay and may still be added to: the export format's document checked against its schema, examples and the app's tables (`spec/export_format_document_spec.rb`, the guard for new collector-owned columns), the schema and example files' checks, configuration-file checks (`compose.yaml`, `config/deploy.yml`, workflows, `.dockerignore`, `orca.yaml`) and checks of code files. The rule is also in `.claude/rules/testing.md` once spec 020 merges. When the maintainer rules on one instance of a pattern, ask whether it covers the others before scoping it narrowly. Related: [[sdd-review-model-choice]].
