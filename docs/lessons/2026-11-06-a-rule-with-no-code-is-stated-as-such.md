---
date: 2026-11-06
spec: "027"
tags: [documentation, area-docs, tenancy]
---

# Lesson: when an area doc distils a rule no code applies, say so

## Context

ADR 0017 and `.claude/rules/multi-tenancy.md` say jobs and broadcasts must carry and restore the account.

## What happened

Searching for the code that applies the rule found none: no account-scoped job or broadcast exists, `ApplicationJob` restores no `Current.account`, and the one job touching tenant data (`ImportUpload::SweepJob`) is cross-tenant by nature. The doc says "a rule with no instance yet", names the sweep and lists the other cross-account reads each with its reason; the ADR had already said "a rule so far".

## What to do next time

- For each rule an area doc distils, grep for the code that applies it. State the absence rather than describing the rule as practice.
- List the exceptions to a rule (here, cross-tenant reads) with the reason for each, so the next one added has to justify itself.
