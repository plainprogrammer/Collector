# Code Documentation (YARD)

Comments are the API documentation: `bin/yard doc` builds them into a site with the area docs and ADRs (spec 054, ADR 0027), and agents read them in the source. Write them for a reader who has the code but not the conversation that produced it. Apply these rules to code you add or change; don't retrofit untouched files just to comply.

## Rationale

- ✓ Comment the **why**, not the what: the constraint, the trap, the alternative that was rejected and why, the order that matters. If deleting the comment would let a careful reader "simplify" the code into a bug, the comment is needed.
- ✓ Name the source of a decision in the comment: a spec criterion as plain text ("spec 055 FR-2"), an issue ("#127"), and an area doc or ADR as a tag, `@see file:catalog-operations.md`.
- ✓ Each fact has one home. A local "why" (this method, this line) goes in the comment; a rule of the subsystem goes in its area doc, and the comment points there with `@see file:…`; a decision of lasting weight goes in an ADR. Don't copy an area doc's rule into a comment, and don't leave a subsystem rule only in a comment.
- ✓ Document a constant with why it has its value (a measurement, a source's limit, a ruling), as the area docs' Named constants tables do.
- ✗ Don't narrate the code ("loops over the lots"), restate the method name, or write history ("changed in PR #…"); git and the specs keep history.

## Reusable code

Code written to be called from elsewhere: concerns, helpers, `lib/`, plain Ruby objects under `app/models/`, query methods and scopes, and `spec/support/` helpers.

- ✓ Start with a one-line summary saying what it gives the caller, then document `@param` and `@return` with types, and `@raise` for each error a caller should handle.
- ✓ Say what a caller can't see from the signature: side effects (database writes, jobs enqueued, files written, network calls), whether it needs `Current.account` set or takes the account explicitly, whether it is safe to call twice (idempotent) or inside a transaction, and its cost when that matters (queries per call, loads a whole table).
- ✓ Add an `@example` when the right call isn't obvious from the parameters.
- ✓ Mark helpers that exist for one caller and aren't meant for reuse with `@api private`.

## Extension contracts

- ✓ A class or module a collectible extension implements or subclasses (`Catalog::Sources`, `Catalog::Operation` and its hooks) says in its comment exactly what an implementation must provide and what each part returns or raises, so a new collectible can be added by reading the contract, not the MTG code. Mark a base class meant only for subclassing `@abstract`, and a hook method a subclass must override `@abstract` with what it returns.
- ✓ The contract's comment is the one place it is written down: when the contract changes, change that comment in the same commit, and point to it from the area doc rather than restating it.
- ✗ Don't name a collectible in a core file's comments: the core-names-no-collectible specs (`spec/*_core_spec.rb`) read whole files, comments included (`spec/admin_catalog_core_spec.rb` even matches "art" as a word).

## Keeping comments true

- ✓ A change to behaviour updates the comment that describes it in the same commit. A stale comment is a bug: agents act on it.
- ✓ A plan's task that changes a public method's behaviour or contract names the comment it updates.
- ✓ Code reviews (`sdd-review` Mode B, code-review subagents) check new and changed public methods for a missing, stale or what-not-why comment, and report it as a finding.

## Finding code before writing it

- ✓ Before adding a helper, scope, concern or spec support method, look for one that exists: grep the comments' summaries in `app/`, `lib/` and `spec/support/`, or build the docs (`bin/yard doc`) and query them, for example `bin/yard ri Catalog::Operation` (one object's documentation) or `bin/yard list --query 'docstring =~ /lot_key/i'` (every object whose comment mentions a term). Reuse or extend what exists rather than writing a near-duplicate, and document what you extend.

## Syntax

- ✓ Comments are Markdown (`--markup markdown`).
- ✓ Point a comment at an area doc or an ADR with a YARD tag, `@see file:<file name>.md` (for example `@see file:release-and-deploy.md`), not wrapped in braces; a spec stays a plain mention ("spec 015 AC-2.16"), as in the existing comments.
- ✓ Keep `{…}` out of comments unless it is YARD's link syntax: put paths and formats that contain braces in backticks. An unresolved `{…}`, an unknown tag or a malformed tag fails `bin/ci checks` (step "Docs: YARD builds without warnings").
- ✗ Don't invent tags; `.yardopts` declares none, so only YARD's standard tags (`@param`, `@return`, `@raise`, `@example`, `@see`, `@note`, `@abstract`, `@api`, `@deprecated`) build without a warning.
