---
date: 2026-11-06
spec: "041"
tags: [forms, spec-review, locations]
---

# Lesson: A required select's prompt owns the blank value; give every real option another

## Context

Spec 041's move page has one select, To, with a "Choose…" prompt first, then "No location", then the account's locations. The spec made it required so the browser refuses a submission with no destination (AC-2.1, AC-2.2). Its draft named Move copies (spec 032) as the model, and Move copies submits "No location" as `""`.

## What happened

Spec review round 3 found that the two can't both hold: a required select is refused by the browser only when the chosen option's value is `""`, so the prompt has to carry `""`, and then "No location" can't. A planner couldn't have written AC-2.2's example ("submitted with no destination chosen") against AC-3.2's ("moved to No location") without inventing a value. The spec then gave "No location" the value `none`, the location filter's own word (spec 037 decision 1), and said any other value is a location id or 404. `Form.md` gained a line: a required select's prompt says "Choose…" and submits `""`; "Not specified" is for an optional field's blank.

## What to do next time

- When a select becomes required with a prompt, give every real choice a non-blank value, and say the values in the spec, not only the labels.
- Reuse an existing word for "none" where one exists (`none` from the location filter), so the server parses one vocabulary.

## Signals to watch for

- A spec that says "as Move copies does" for a form that adds `required` or a prompt.
- An option whose meaning is "nothing" (No location, Not specified) on a form whose blank must mean "not chosen".
