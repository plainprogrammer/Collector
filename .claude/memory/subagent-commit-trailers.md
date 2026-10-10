---
name: subagent-commit-trailers
description: Implementer subagents use their own session's Co-Authored-By trailer whatever the brief says; don't name a trailer in briefs
metadata:
  type: reference
---

A subagent dispatched with the Agent tool gets its own attribution reminder, and follows it over a trailer named in the brief. In spec 014 (2026-10-09) the controller's reminder said `Claude Opus 5.5` and every implementer subagent's said `Claude Sonnet 5.5` (dispatched with `model: "opus"`), so the Phase 1–5 commits carry the Sonnet trailer and the controller's commits the Opus one. Three subagents reported it as a concern. The maintainer saw the mix in the final report and left it.

**How to apply:** don't name a trailer in a subagent brief; tell the subagent to use the one its session's attribution reminder gives. If a branch needs one consistent trailer, have the subagent leave the work staged and make the commit in the controller session. Related: [[precommit-hook-staging]], [[small-incremental-commits]].
