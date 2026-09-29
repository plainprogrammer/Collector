# Multi-Tenancy

- ✓ Row-level tenancy with one consistent foreign key (`account_id`) on every tenant-owned table — never mix `team_id`/`org_id`/`tenant_id`.
- ✓ Resolve the tenant once per request into `Current.account` in a controller concern; fail closed when it's nil.
- ✓ Scope every query through the tenant (`Current.account.collections.find(params[:id])`); bare `Model.find(params[:id])` on tenant data is a bug.
- ✓ Pass the account (or a record owning it) into every job and restore `Current.account` before the job body runs.
- ✓ Add a request spec per tenant-scoped resource proving another account's record returns 404.
- ✓ Shared catalog data (e.g. Scryfall cards) is global; user-owned data (copies, conditions, prices paid, notes) is always tenant-scoped.
- ✗ Never use `unscoped` or cross-tenant queries without an explanatory comment.
- ✗ Don't cache tenant data under keys that omit the account.
- ✗ Don't broadcast Turbo Streams on channels not namespaced to the account/user.
