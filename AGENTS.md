# Umaxica Apps Global Guide for AI Coding Agents

This is a Ruby on Rails application, not the Rails framework monorepo.

Agents must treat this file as the always-loaded entry point. The former harness rules live under
`.harnes/`; they are not loaded automatically unless this file points to them or the task explicitly
requires them.

## Application Shape

This app has three user-facing surfaces:

- `app` - end-user application
- `org` - staff / organization surface
- `com` - public / corporate surface

Treat each surface as an independent boundary. Do not mix controllers, routes, views, policies,
sessions, or state across surfaces unless the existing code has an explicit shared abstraction.

Read `.harnes/context/architecture.md` when a change touches surface boundaries, controllers,
models, services, policies, or shared concerns.

## Required Harness Context

Use these `.harnes/` files as task-specific instructions:

- Controller or endpoint work: `.harnes/tasks/implement_controller.md`,
  `.harnes/context/routing.md`, `docs/architecture/controller-lifecycle.md`
- Minitest work: `.harnes/tasks/write_minitest.md`, `.harnes/policies/testing_rules.md`
- Migration work: `.harnes/tasks/add_migration.md`, `.harnes/policies/migration_rules.md`
- Security-sensitive work or broad refactors: `.harnes/policies/forbidden_patterns.md`
- Surface, routing, or authentication changes: `.harnes/context/architecture.md`,
  `.harnes/context/routing.md`, `docs/architecture/controller-lifecycle.md`
- Non-trivial implementation decisions, plan deviations, or handoff notes:
  `.harnes/policies/implementation_notes.md`

If a task touches one of these areas, read the relevant harness file before editing.

## Decision Context

Use `memos/`, `notes/`, `adr/`, `plans/`, and `docs/` as required context inputs, not as optional
background. Only `adr/`, `docs/`, and current `plans/` are source-of-truth decision material.

Repository knowledge is separated by purpose:

- `adr/` - accepted architecture and design decisions.
- `plans/` - implementation plans, active work, proposals, and backlog items.
- `docs/` - current stable documentation for implemented behavior and operations.
- `docs/dictionary/` - Eric Evans' DDD ubiquitous language definitions for this application.
- `notes/` - non-authoritative ADR-adjacent notes and implementation handoff notes.
- `memos/` - exploratory observations and notes that do not affect implementation.

Before making non-trivial architecture, routing, authentication, authorization, database,
preference, engine/surface, or service-layer changes:

- Read `memos/` for exploratory notes, rough analysis, and unresolved observations.
- Read `notes/` for ADR-adjacent notes, handoff context, and implementation notes relevant to the
  change.
- Read `docs/index.md` to confirm the documentation model.
- Read `adr/README.md` and the ADRs relevant to the change.
- Read `plans/README.md` and relevant files under `plans/active/`.
- Check `plans/backlog/` when the task mentions an issue number, feature area, migration, or known
  follow-up.
- Use `plans/archive/` only for historical context; do not treat archived plans as current intent
  unless a current ADR, doc, or active plan points to them.

Decision priority when sources disagree:

1. Explicit user instruction in the current conversation.
2. Current code and tests.
3. Accepted ADRs in `adr/`.
4. Stable docs in `docs/`.
5. Active plans in `plans/active/`.
6. Backlog notes in `plans/backlog/`.
7. Notes in `notes/`.
8. Archived plans in `plans/archive/`.

If an ADR or doc conflicts with current code, call out the conflict before choosing an
implementation path. If implementing an active plan changes stable behavior, update the relevant
`docs/` file or mention that documentation still needs to be updated.

## Working Notes

- Use `notes/implementation/` for implementation decisions, plan deviations, compromises, and
  handoff context discovered while carrying out a plan.
- Add or update `notes/` when implementation uncovers durable context that future agents should know
  but that is not yet an accepted ADR, active plan, backlog item, or stable doc.
- Prefer leaving a note over losing context when you find contradictions between comments, code,
  tests, ADRs, docs, plans, or existing notes; record what was checked, the current interpretation,
  and what still needs promotion or follow-up.
- Use `notes/` for ADR-adjacent observations, handoff notes, gap notes, compatibility constraints,
  rejected alternatives likely to be revisited, and implementation caveats discovered during work.
- Use `memos/` for provisional analysis, investigation notes, and draft observations that do not
  affect implementation.
- Do not treat `notes/` or `memos/` as source of truth; promote stable or actionable content to
  `adr/`, `plans/`, or `docs/`.
- Never commit secrets, tokens, cookies, authorization headers, full request parameters, private
  keys, real credentials, or sensitive local environment details into `docs/`, `adr/`, `memos/`,
  `notes/`, or `plans/`.
- If sensitive context is needed during work, either keep it only in ephemeral working memory, write
  a masked/redacted version, or place local scratch material under the ignored `local/`, `private/`,
  or `tmp/` subdirectories for that documentation area.
- When preserving a finding without the sensitive value, describe the type of secret, the affected
  component, and the follow-up needed, but omit or mask the value itself.

## Non-Negotiable Rules

Do not:

- Mix the `app`, `org`, and `com` surfaces.
- Skip authentication, authorization, verification, CSRF, or rate-limit protections.
- Reorder the authentication and authorization pipeline.
- Put business logic in controllers.
- Use `permit!`, `skip_before_action`, `skip_authorization`, `skip_forgery_protection`, `html_safe`,
  `raw(...)`, `VERIFY_NONE`, `rescue nil`, or ignored rescues.
- Log tokens, cookies, authorization headers, or full request params.
- Store request state in class variables, globals, or `Thread.current`.

For database changes, do not use destructive operations such as `drop_table`, `remove_column`,
`change_column`, `delete_all`, `destroy_all`, `update_all`, or raw `execute(...)` unless the user
has explicitly approved the risk and migration plan.

Do not write migration helpers that silently no-op when DB state is unexpected (e.g. `rename_table`
wrapped in `return unless table_exists?(...)`). Use `rename_table_strict` or raise loudly — silent
skips hide partial migrations and corrupt schema_dump files over time.

## Rails Development Conventions

- Keep controllers focused on HTTP concerns.
- Put domain behavior in models, services, policies, or existing local abstractions.
- Use Pundit authorization through the established pipeline.
- Use RESTful routes and path helpers.
- Do not hardcode absolute URLs in application code.
- Prefer existing project patterns over new abstractions.
- Keep changes scoped to the requested behavior.

## Code Comments

When implementing or changing code:

- Read nearby comments before editing and verify that they still match the code, tests, ADRs, docs,
  and active plans.
- If a comment conflicts with the implementation or current source-of-truth material, fix the
  comment or call out the conflict before choosing an implementation path.
- Leave concise comments above classes, constants, variables, methods, and functions when the name
  or surrounding code does not fully explain the intent, constraint, lifecycle, security boundary,
  domain meaning, or non-obvious tradeoff.
- Keep comments factual and maintainable. Do not add comments that merely restate the code.
- After implementation, review the comments touched or made stale by the change and update them
  before finishing.

## Testing Commands

Use Minitest for Ruby code.

Common commands:

```bash
bin/rails test
bin/rails test test/path/to/file_test.rb
bin/rails test test/path/to/file_test.rb:LINE
```

Use Vitest for JavaScript code:

```bash
vp test
```

If behavior changes in both Ruby and JavaScript, add or update coverage on both sides where
appropriate.

## Testing Expectations

All meaningful changes need tests appropriate to their risk.

Tests should cover:

- Success paths
- Failure paths
- Authentication and authorization when relevant
- Edge cases for validation, routing, cookies, sessions, tokens, policies, and verification

For model-layer validation or classification logic, include boundary value analysis and equivalence
partitioning where relevant.

Do not add placeholder tests, `assert true`, skipped tests, TODO tests, or tests that mock away the
behavior being verified.

## Migration Expectations

Migrations must be reversible, backward-compatible, and safe for production.

- Separate schema changes from data changes.
- Avoid large data updates inside migrations.
- Do not use application models inside migrations.
- Check rollback behavior when practical.
- Consider lock impact before adding indexes or changing large tables.

### Table renames

- Use `rename_table_strict` (provided by `MigrationHelpers::SafeTableRename`) for any rename. It
  raises if state is inconsistent — never silently skips.
- Do not define a local `rename_table_if_present` or any other "skip if missing" wrapper around
  `rename_table`. The silent-skip pattern hides partial-rename failures and produces schema drift
  that surfaces days later as broken fixtures and unrunnable tests.
- While a rename migration is in flight on a branch, use `bin/db-reset-all` instead of
  `bin/rails db:migrate` for dev and test DBs. Incremental migrations against a half-renamed DB
  silently drift further; reload from the committed schema_dump every time.
- Before pushing a branch that adds rename migrations, run `bin/rails db:verify_no_schema_drift` to
  confirm the committed schema_dump files match what migrations produce from a clean DB.

See `docs/operations/db-workflow.md` for the full multi-DB workflow.

## Before Finishing

- Run the narrowest relevant tests first.
- Run broader tests when the change affects shared behavior or multiple surfaces.
- Mention any tests that could not be run.
- Keep changelog or documentation updates scoped to the component or feature being changed.
