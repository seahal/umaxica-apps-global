# Publishing CMS lifecycle, authentication, and provenance: implementation verification

## Scope

Implemented the gaps recorded in this session's earlier audit of the Base.Org Publishing CMS:
`Publication` create/end (publish/unpublish/schedule), entry create, archive/unarchive, staff
authentication and authorization, and operator provenance on every write. Full decision record is in
`notes/implementation/2026-09-06-publishing-cms-lifecycle-and-authentication.md`.

## Migration

`db/publishing_migrate/20260906120000_add_publishing_operator_provenance.rb` adds
`archived_by_operator_public_id` (entries) and `ended_by_operator_public_id` (publications) across
all twelve cells. Applied to the test database:

```
RAILS_ENV=test bin/rails db:migrate:publishing
```

24 `add_column` statements ran clean (visible in the command's own output; each cell's entries and
publications table). Not applied to `development_publishing_db`, consistent with the 2026-09-05
evidence's standing note that a development database reset is not made without asking.

## Ruby tests run (individually, before the final full-suite run below)

| File                                                                                                                                                               | Result                              |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------- |
| `test/controllers/base/org/publishing/entries_controller_test.rb`                                                                                                  | 19 runs, 128 assertions, 0 failures |
| `test/controllers/base/org/publishing/entry_publications_controller_test.rb`                                                                                       | 12 runs, 60 assertions, 0 failures  |
| `test/controllers/base/org/publishing/entry_archives_controller_test.rb`                                                                                           | 8 runs, 34 assertions, 0 failures   |
| `test/controllers/base/org/publishing/management_matrix_test.rb`                                                                                                   | 3 runs, 309 assertions, 0 failures  |
| `test/operations/publishing/revise_entry_operation_test.rb`                                                                                                        | 5 runs, 25 assertions, 0 failures   |
| `test/operations/publishing/publish_entry_operation_test.rb`                                                                                                       | 4 runs, 17 assertions, 0 failures   |
| `test/policies/publishing_entry_policy_test.rb`                                                                                                                    | 5 runs, 24 assertions, 0 failures   |
| `test/queries/publishing_management_entries_query_test.rb`                                                                                                         | 11 runs, 33 assertions, 0 failures  |
| `test/forms/publishing/{create_entry_form,publish_entry_form}_test.rb`                                                                                             | 18 runs, 108 assertions, 0 failures |
| `test/tooling/database_reconstruction_authority_test.rb` + `test/jobs/security_one_time_reveal_purge_job_test.rb` + `test/models/security_one_time_reveal_test.rb` | 15 runs, 99 assertions, 0 failures  |
| `test/integration/routes/base_org_publishing_management_route_contract_test.rb`                                                                                    | 5 runs, 351 assertions, 0 failures  |
| `test/tooling/evidence_layout_test.rb`                                                                                                                             | 3 runs, 6 assertions, 0 failures    |

New test files: `test/controllers/base/org/publishing/entry_publications_controller_test.rb`,
`test/controllers/base/org/publishing/entry_archives_controller_test.rb`,
`test/operations/publishing/publish_entry_operation_test.rb`,
`test/policies/publishing_entry_policy_test.rb`,
`test/forms/publishing/{create_entry_form,publish_entry_form}_test.rb`. Extended: the entries
controller test (authentication, pagination, create, provenance cases), the management matrix test
(nested-controller cell identity), the publishing management entries query test (pagination), the
route contract test (new/create routes, publications/archive nested resources), the revise entry
operation test (`operator_public_id`).

## Two pre-existing tests broken by this change, fixed in this session

- `test/unit/security/ri_routing_contract_test.rb`: the twelve publishing entries controllers were
  allowlisted as running without `set_region` because they inherited `BareController`, which skips
  the whole preference pipeline. They now inherit `Base::Org::ApplicationController`, so
  `set_region` runs like it does for every other staff page; removed the twelve-entry exemption and
  updated the comment. Verified: `4 runs, 7 assertions, 0 failures`.
- `test/unit/security/action_policy_usage_test.rb`: its
  `private mutation controller actions explicitly call authorize or document an exception` check
  reads each controller _file's own source text_ for a literal `authorize!` call. The 36 generated
  per-cell controllers each declare only their cell's identity and delegate every action to a shared
  concern (`PublishingManagementEntriesActions`/`PublishingManagementPublicationsActions`/
  `PublishingManagementArchivesActions`), so the literal text never appears in the 72 flagged
  `create`/`update`/`destroy` action bodies even though `authorize!` genuinely runs (through
  `PublishingManagementCell#authorize_publishing!`). Added the 72 file#action pairs to
  `PRIVATE_MUTATION_AUTHORIZATION_EXCEPTIONS` with a comment explaining why, rather than lowering
  the check or duplicating an inline `authorize!` call 72 times across otherwise-identical generated
  files. Verified: `5 runs, 78 assertions, 0 failures` standalone, and confirmed non-flaky with two
  more standalone reruns during investigation of a full-suite run described below.

## Full Ruby suite: two runs, one contaminated by concurrent load

First full run (`bin/rails test`, before the two fixes above):
`12456 runs, 72542 assertions, 5 failures, 0 errors, 1 skip`. Failures: the two above (before their
fixes), plus the three pre-existing failures
`evidence/2026-09-05-merge-package-update-and-review.md` already recorded as not this session's to
resolve (`ComposeLocalOverrideOptionalTest`, the two `FlatRubySourceLayoutInvariantTest` cases).

A second full run was started concurrently with this session's `pnpm install`,
`npx playwright install chromium` (a 300 MB download), and repeated `pnpm vitest` benchmark
invocations for the separate Vitest-hardening task in this same session. It reported
`12456 runs, 72528 assertions, 14 failures, 0 errors, 1 skip` -- nine additional failures, all in
`PreferenceInertiaPageContractTest` (409 Conflict where 2xx was expected) and none touching anything
this session changed. Re-running just `test/integration/preference_inertia_page_contract_test.rb`
and `test/unit/security/ri_routing_contract_test.rb` alone, without concurrent load, reproduced only
the (by-then-already-understood) `ri_routing_contract_test.rb` failure and zero
`PreferenceInertiaPageContractTest` failures (`37 runs, 916 assertions, 1 failure`) -- the nine
extra failures were transient contention from running a CPU/network-heavy install and multiple
benchmark passes alongside a 24-worker parallel Rails run, not a defect. A third full run, started
alone with no concurrent work, is the number this evidence file reports as authoritative; see below.

**Full-suite result (clean, no concurrent load):**
`12456 runs, 72546 assertions, 3 failures, 0 errors, 1 skip` (846.9s). All three failures are
pre-existing and unrelated to this session's changes: the two `FlatRubySourceLayoutInvariantTest`
cases and `ComposeLocalOverrideOptionalTest`, both already recorded in
`evidence/2026-09-05-merge-package-update-and-review.md` as not this session's to resolve (a layout
decision on code still being written on `origin/feature`, and a read-only bind-mount artefact of
this container). Neither publishing, the two fixed contract tests, nor anything else this session
touched appears in the failure list.

## JavaScript tests

`pnpm test` was run once against the CMS-only frontend changes, before this session's separate
Vitest-architecture hardening replaced the single jsdom project with two projects: **84 files, 1037
tests, all passing** under the then-current single-project jsdom configuration
(`spec/features/publishing/management_pages.test.tsx` alone: 20 tests, including the new
`ManagementNew`, index-pagination, and `ManagementShow` lifecycle-control cases). This file's own
number is now split across the `unit`/`component` projects described in
`evidence/2026-09-07-vitest-hardening.md`; the publishing-CMS spec file itself is in the `component`
project (it renders through `@testing-library/react`, not `renderToStaticMarkup`), so its post-split
result is unverified for the same sandbox reason recorded there.

`pnpm run format`, `pnpm run lint`, `pnpm run typecheck`, `pnpm run deadcode`, and `pnpm run build`
all ran clean against the full set of CMS changes (36 controllers, the shared concerns, six
operations, five forms, three values, the query, the policy, and every `.tsx` component and page
wrapper).

## RuboCop

`bundle exec rubocop 1.90.0 --force-exclusion` against every Ruby file this session touched or added
(84 files: controllers, concerns, operations, forms, values, the query, the policy, the migration,
`config/routes/base.rb`, and every new/changed test): **0 offenses** after one autocorrect pass
(`-a`) fixed 77 formatting-only offenses (trailing commas, brace layout, string quoting) introduced
by hand-written test fixtures; none touched application logic.

## What was not implemented

Recorded in the implementation note's "Deviations From Plan": taxonomy assignment editing,
vocabulary/term CRUD, and media upload. Each needs its own design (a term picker needs term CRUD
first; media needs a Shrine storage decision this container cannot verify) rather than being a gap
in this slice.
