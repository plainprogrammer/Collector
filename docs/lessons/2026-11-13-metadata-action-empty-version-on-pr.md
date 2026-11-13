---
date: 2026-11-13
spec: 084 (#374)
tags: [ci, image, github-actions]
---

# Lesson: docker/metadata-action gives no version on a pull request

## What happened

Spec 084 passes the image's version to its build from `steps.meta.outputs.version`. The first draft assumed a pull request's build would read `pr-N`. The spec review traced the image job's tag rules (`type=edge,branch=main`, `type=sha` on `main` only, `type=semver`) and found that none matches `refs/pull/N/merge`, so the output is empty on a pull request (the action warns "No Docker image version has been generated"). Every PR image would have read "unknown version" and failed `bin/image-smoke`. The workflow now passes `${{ steps.meta.outputs.version || format('pr-{0}', github.event.pull_request.number) }}`.

## What to do next time

- Before using a `docker/metadata-action` output, check which configured tag type yields it on each trigger: pull request, `main` and tag. `pr-N` comes only from `type=ref,event=pr`.
- Give an output that is empty on some trigger a fallback in the expression, and name the trigger in a static check (`spec/image_publishing_spec.rb`).
