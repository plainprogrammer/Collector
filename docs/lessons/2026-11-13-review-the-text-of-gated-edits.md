---
date: 2026-11-13
spec: 084 (#374)
tags: [permissions, image, reviews, comments]
---

# Lesson: review the claims in a prompt-gated edit's text before sending it

## What happened

`Dockerfile` and `.github/workflows/**` edits prompt the maintainer, so spec 084 sent the exact text for approval before making them. The approved `Dockerfile` comment said the build facts are "declared last, so a new commit rebuilds only this layer". That is false: every commit changes the build context, so `COPY . .` and every later layer rebuild anyway. The only true claim is that values which change with every commit invalidate no earlier layer. The implementation review caught it, and correcting the comment cost the maintainer a second prompt (`12ca0372`).

## What to do next time

- Put the exact text of every prompt-gated edit in the plan, and ask the plan review to check its comments' claims as well as its syntax.
- A comment that gives a reason is a claim: test it against how the tool behaves (here, Docker's layer cache) before the text goes for approval.
