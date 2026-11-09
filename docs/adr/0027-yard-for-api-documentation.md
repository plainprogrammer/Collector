# 0027: Generate the Ruby API documentation with YARD, from the code's comments and the area docs

## Status

Proposed (2026-11-09); Accepted when the coordinator approves the plan of [spec 054](../specs/054-adopt-yard/spec.md). The decisions it records were ruled by the maintainer on 2026-11-09 (spec 054 decisions 1, 2 and 6, OD1–OD3, all as recommended). It took the number 0027: [spec 027](../specs/027-architecture-area-docs/spec.md), the issue ([#103](https://github.com/plainprogrammer/Collector/issues/103)) and the roadmap expected "0023", which [0023](0023-locations-make-export-format-version-2.md) took, and 0024–0026 took the next numbers; the coordinator of the run that wrote spec 054 confirmed 0027.

## Context

A reader of the Ruby code reads source files one at a time. [Spec 027](../specs/027-architecture-area-docs/spec.md) put the current architecture into [area docs](../architecture/README.md) and left "slice B" open: a generated, browsable API site with the area docs beside it, none of it committed or shipped in the public image ([ADR 0008](0008-public-images-from-the-private-repository.md)). About 54% of the code's classes, modules, constants and methods carry a comment, and many existing comments cite a spec criterion in prose.

A spike of YARD 0.9.45 on the current code (spec 054, Problem Statement) gave 3 warnings, about 8 s, a 5.6 MB site including the area docs and 26 ADRs as pages, and links between those pages that don't resolve: they are relative `.md` links, as spec 027's compatibility requirement keeps them for GitHub, while YARD names its pages `file.<name>.html`.

## Decision

1. **Generate the site with YARD** (`yard` in the `:development` group, `require: false`; a `bin/yard` binstub; options in `.yardopts`; output in `doc/`, with the cache in `.yardoc/`, both ignored by Git and left out of the image). Spec 054 decision 3 and the Non-Goals keep coverage out: nothing measures or gates how much is documented.
2. **The pages and the comments are Markdown** (`--markup markdown`), rendered by YARD's own Markdown renderer, which is the first of YARD's providers and always present: no gem is added for it. The area docs and ADRs are pages (`docs/architecture/*.md`, the numbered `docs/adr/0*.md`, not the ADR index, whose name `README` would collide with the front page); the area map `docs/architecture/README.md` is the front page.
3. **`bin/ci checks` fails on a YARD warning** (`bin/yard doc --no-cache`, with `--fail-on-warning` in `.yardopts`): a step after the Ruby style step, about 8 s, so a comment that breaks a link is found in the pull request that made it, and a documentation-only push is gated by it too.
4. **A small extension makes the pages' links work** (`script/yard/links.rb`, loaded by `.yardopts`): a relative link to another included page becomes a link to its page in the site, with a heading fragment mapped to YARD's heading id; any other relative link becomes a link to that file on GitHub's `main`; a link to a file that doesn't exist, or to a heading that isn't there, is a warning and so fails the check. It works on the text a page is rendered from; the files on disk are never rewritten. It lives in `script/`, which the app doesn't autoload and the build context leaves out.
5. **Comments point at area docs and ADRs with `@see file:<file name>.md`**; a reference to a spec (not a page of the site) stays in the prose, and the existing "spec NNN AC-x" comments stay as they are.

### Options considered

- **RDoc** (`rdoc` is in the bundle already): it renders Markdown pages and the API from comments too, but its comment syntax is its own and it has no equivalent of YARD's tags (`@see`, `@param`) that the comments can grow into; the issue and spec 027 named YARD, and nothing found in the spike argued against it.
- **No generated documentation** (read the source and the area docs on GitHub): costs nothing, and is what the repository has. It keeps a class and the area doc that explains it apart, which is the problem.
- **Leave the links as written, or rewrite the included-to-included links only**: simpler (no extension to test), but 46% of the area docs' and ADRs' relative links point at documents outside the site (specs, `docs/releasing.md`) and would be dead in it.
- **Check coverage in CI** (`yard stats --list-undoc`): at 53.7% most of the code is undocumented; a gate would need comments written for their own sake. Not now; nothing here prevents a later spec.
- **Publish the site** (GitHub Pages, or in the image): out of scope; the image is public and carries only what it runs.

## Consequences

- A developer, or an agent, runs `bin/yard doc` and opens `doc/index.html`; the architecture and the Ruby API are in one site, and `@see` takes a reader from a class to its area doc.
- `yard` is a development-only gem: the image's bundle leaves it out (`BUNDLE_WITHOUT="development"`), and `.dockerignore` and `bin/image-smoke` keep `doc/`, `.yardoc/`, `.yardopts`, `bin/yard` and `script/yard/` out of the image; `spec/image_publishing_spec.rb` checks that the two agree.
- A comment that YARD warns about (an unresolved `{…}`, a malformed tag) fails `bin/ci checks`, so the warning count stays at zero; a new YARD release that warns about more fails Dependabot's pull request until its comments are fixed in the same change. `{…}` is YARD's link syntax, so a comment that means braces literally writes them in code (backticks) or without them.
- A small piece of code, `script/yard/links.rb`, is owned by the repository: it depends on two things in YARD, `ExtraFileObject`'s `initialize` and `contents`, and on how YARD makes a heading's id (each character that isn't a letter or digit becomes `_`). Its specs run a real `yard doc` over a fixture, so a YARD release that changes either fails them.
- A comment's `@see file:` that names a page that doesn't exist renders a dead link and is not caught (YARD doesn't warn for it); a later spec may add a check.
- The area docs and ADRs keep plain relative links (spec 027); nothing in them is YARD syntax.
