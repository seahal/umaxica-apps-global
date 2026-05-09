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
  `.harnes/context/auth_pipeline.md`, `.harnes/context/routing.md`
- Minitest work: `.harnes/tasks/write_minitest.md`, `.harnes/policies/testing_rules.md`
- Migration work: `.harnes/tasks/add_migration.md`, `.harnes/policies/migration_rules.md`
- Security-sensitive work or broad refactors: `.harnes/policies/forbidden_patterns.md`
- Surface, routing, or authentication changes: `.harnes/context/architecture.md`,
  `.harnes/context/routing.md`, `.harnes/context/auth_pipeline.md`

If a task touches one of these areas, read the relevant harness file before editing.

## Decision Context

Use `adr/`, `plans/`, and `docs/` as required decision inputs, not as optional background.

Before making non-trivial architecture, routing, authentication, authorization, database,
preference, engine/surface, or service-layer changes:

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
7. Archived plans in `plans/archive/`.

If an ADR or doc conflicts with current code, call out the conflict before choosing an
implementation path. If implementing an active plan changes stable behavior, update the relevant
`docs/` file or mention that documentation still needs to be updated.

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

## Rails Development Conventions

- Keep controllers focused on HTTP concerns.
- Put domain behavior in models, services, policies, or existing local abstractions.
- Use Pundit authorization through the established pipeline.
- Use RESTful routes and path helpers.
- Do not hardcode absolute URLs in application code.
- Prefer existing project patterns over new abstractions.
- Keep changes scoped to the requested behavior.

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

## Before Finishing

- Run the narrowest relevant tests first.
- Run broader tests when the change affects shared behavior or multiple surfaces.
- Mention any tests that could not be run.
- Keep changelog or documentation updates scoped to the component or feature being changed.
