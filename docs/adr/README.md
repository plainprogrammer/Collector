# Architecture Decision Records

One file per decision: `docs/adr/NNNN-<slug>.md`, four digits, numbered from 0001 in the order written and never renumbered once merged. An ADR written on a branch takes the next free number when another branch's ADR took its number first (check `origin/main` and open branches before numbering); its Status line then says what it was written as and why it moved, as 0012, 0014 and 0015 do.

Each ADR has these sections, in this order:

- **Title**: `# NNNN: <decision>` as the first line
- **Status**: `Proposed`, `Accepted`, `Rejected` or `Superseded by NNNN`
- **Context**: the problem and the evidence, linking the spec or research
- **Decision**: what we will do
- **Consequences**: what follows, good and bad

Specs and plans link the ADRs they rely on. To change a decision, write a new ADR that supersedes the old one.
