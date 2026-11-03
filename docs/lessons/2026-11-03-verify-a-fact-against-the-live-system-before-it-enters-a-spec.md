---
date: 2026-11-03
spec: "036"
tags: [specification, facts, review, github]
---

# Lesson: Verify a fact against the live system before it enters a spec, or a question to the maintainer

## Context

Spec 036 (the advisory response) was drafted from a diagnosis of one day's blockade: five Dependabot pull requests failing on advisories for locked gems. The spec, and the questions that produced the maintainer's rulings, stated several facts about the repository and about GitHub.

## What happened

Four statements were wrong or empty when written, and each was caught only by a read-only review or a later fetch, not by the author:

- "The repository is private now (ADR 0008)" came from the ADR's date (2026-10-07), not from the repository. `gh api repos/plainprogrammer/Collector` says public, which made the 60-day disabling of idle scheduled workflows and the public run logs real.
- "The importmap audit shares the failure mode with the gem audit" was put to the maintainer as the reason to run both. `config/importmap.rb` has no versioned pin, so `bin/importmap audit` checks nothing. The maintainer had ruled on a wrong premise and had to rule again.
- "All but one of the 16 pull requests were opened on a Tuesday" was 12 of 16: four were opened on one Wednesday.
- "GitHub notifies whoever last changed the cron" was the documentation's rule only in part: it notifies the user who created the workflow, replaced by whoever changes the cron or re-enables it.

Each fact was one command or one page away: `gh api`, `grep`, a date check, a fetch of the documentation.

## What to do next time

Before a fact goes into a spec, a plan, or a question that asks the maintainer to decide, run the one command that proves it and cite the source inline, or say it is inferred. The more a decision rests on a fact, the more it needs that. Treat three kinds of statement as unverified until checked: a "now/currently" claim taken from an older ADR or note, a claim that two things "share" a mechanism, and any count or date worked out from memory.

## Signals to watch for

- A present-tense claim about the repository's state whose only source is a document with a date.
- "X works the same way as Y" offered as the reason for a choice.
- A summary figure ("all but one") written without the list it summarises in front of you.
- Documentation paraphrased from memory when a page fetch would settle it.
