---
name: rubocop-stdin-lint
description: Lint plan or scratch Ruby against the project's config without running it or putting it in the tree
metadata:
  type: reference
---

`bin/rubocop --stdin spec/system/some_spec.rb --format simple < scratch.rb` lints a file kept outside the repo as if it lived at the given path, so the project's cops and path-specific rules apply (RSpec/MultipleMemoizedHelpers, LetSetup, ExampleLength at 15, InstanceVariable, MultipleExpectations). `ruby -c scratch.rb` checks syntax. Neither runs the code, so it fits plan writing and plan reviews (reviewers run nothing; see [[plan-reviews-run-the-code]]).

**Why:** spec 074's first plan draft had a 460-line system spec whose offenses would have blocked Task 1's commit (the pre-commit hook), and only a reviewer reading the file noticed.

**How to apply:** extract the plan's Ruby block to a scratch path (the session scratchpad), run the stdin lint with the path the file will have, fix the offenses in the plan text, then send the plan to review. Redo it after every plan patch that touches code.
