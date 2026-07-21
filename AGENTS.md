# Umaxica Apps Global Guide for AI Coding Agents

This repository is a Ruby on Rails application, not the Rails framework monorepo.

Treat this file as the always-loaded entry point. Detailed rules live under
`.agents/harnesses/rules/`; load only the rules relevant to the current task before editing. Detailed
behavior rules are canonical within their area.

## Working Method

For every task:

1. Confirm the requested scope and inspect the current worktree. Preserve unrelated changes.
2. Read the files to be changed, their tests, one nearby precedent, and the task-specific rules
   listed below.
3. For non-trivial work, inspect relevant current decisions and plans before choosing an approach.
4. Make the smallest coherent change. Do not broaden the task without explicit approval.
5. Run the narrowest relevant verification first, then broaden only when the affected boundary
   warrants it.
6. Report what changed, what was verified, and any remaining blocker or documentation gap.

## Application Boundaries

The application has three independent user-facing surfaces:

- `app` — end-user application
- `org` — staff and organization surface
- `com` — public and corporate surface

Do not mix controllers, routes, views, policies, sessions, or state across surfaces unless current
code provides an explicit shared abstraction. For any surface-related work, read
`.agents/harnesses/rules/project/surfaces.mdc` before editing.

## Required Task Context

Read these files when the task touches the corresponding area:

- Controllers or endpoints:
  `.agents/harnesses/rules/generic/controllers.mdc`,
  `.agents/harnesses/rules/generic/routing.mdc`,
  `.agents/harnesses/rules/project/surfaces.mdc`,
  `.agents/harnesses/rules/project/controller-inheritance.mdc`, and
  `docs/architecture/controller-lifecycle.md`
- Minitest or behavior changes:
  `.agents/harnesses/rules/generic/testing.mdc` and
  `.agents/harnesses/rules/generic/no-test-only-code.mdc`
- Value objects, services, resolvers, policies, queries, or commands:
  `.agents/harnesses/rules/project/value-object-boundaries.mdc`
- Migrations: `.agents/harnesses/rules/generic/migrations.mdc`
- Security-sensitive work or broad refactors:
  `.agents/harnesses/rules/generic/absolute-rules.mdc`,
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`, and
  `.agents/harnesses/rules/project/regression-guards.mdc`
- Configuration or environment variables:
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`
- Routing or authentication workflows:
  `.agents/harnesses/rules/project/surfaces.mdc`,
  `.agents/harnesses/rules/generic/routing.mdc`,
  `.agents/harnesses/rules/generic/no-workflow-drift.mdc`, and
  `docs/architecture/controller-lifecycle.md`
- User-facing notices, alerts, or feedback:
  `.agents/harnesses/rules/generic/no-flash-messages.mdc`
- External technical sources:
  `.agents/harnesses/rules/generic/source-policy.mdc`
- Documentation, ADRs, plans, notes, memos, harnesses, code comments, or test names:
  `.agents/harnesses/rules/generic/repository-language.mdc`
- Logging, audit records, telemetry, or product analytics:
  `adr/application-logging-boundary.md` and `docs/security/observability-boundary.md`
- Non-trivial decisions, plan deviations, or handoff context:
  `.agents/harnesses/rules/generic/implementation-notes.mdc` and
  `.agents/harnesses/rules/project/repository-knowledge-tree.mdc`

## Decision Sources

For non-trivial architecture, routing, authentication, authorization, database, preference,
surface, or service-layer work, read the relevant material under `memos/`, `notes/`, `adr/`,
`plans/`, and `docs/`. Use `.agents/harnesses/rules/project/repository-knowledge-tree.mdc` for the
exact loading, authority, conflict, and promotion rules.

In brief, current user instructions come first, followed by current code and tests, accepted ADRs,
stable docs, active plans, backlog notes, notes, and archived plans. Call out conflicts between
current code and an ADR or stable doc before choosing an implementation path.

## Non-Negotiable Boundaries

Do not:

- mix the `app`, `org`, and `com` surfaces
- skip or reorder authentication, authorization, verification, CSRF, or rate-limit protections
- put business logic in controllers
- use `permit!`, `skip_before_action`, `skip_authorization`, `skip_forgery_protection`, `html_safe`,
  `raw(...)`, `VERIFY_NONE`, `rescue nil`, or ignored rescues
- use Rails flash; render feedback inline instead
- log tokens, cookies, authorization headers, full request parameters, or secrets
- use application logs as the authoritative record for audit, security, compliance, or purchase
  events
- store request state in class variables, globals, or `Thread.current`
- introduce test-only behavior into application code
- use silent configuration, workflow, or migration fallbacks
- perform destructive database operations without the user's explicit approval of the risk and
  migration plan
- write repository prose in a non-English language merely because the conversation, requested
  report, or handoff is in that language

Required Ruby environment variables must use one-argument `ENV.fetch("NAME")`. For exact security,
routing, migration, and fallback constraints, follow the task-specific rules above.

## Repository Content

Repository files must be written in English except explicit localization content, translation
fixtures, non-English customer copy, or necessary quotations. Follow
`docs/reference/repository-language-policy.md` when adding or substantially editing prose.
Conversation language does not override this repository rule. If a user requests a non-English
report without explicitly requesting a repository policy change, provide that report in chat and
keep committed repository material in English.

Agent assets live under `.agents/`:

- `.agents/skills/` is reserved for Codex skills, each with `SKILL.md` as its entry point.
- `.agents/harnesses/` contains rules and review, evaluation, audit, and grill-me harnesses.
- Do not place arbitrary files directly under `.agents/skills/`.
- Do not add repository goal files under `.agents/goals/`; keep task scope in the conversation or
  the Codex goal surface.

## Communication Principles

- Code explains how the behavior is implemented.
- Tests explain what behavior is expected.
- Commit messages explain why the change was made.
- Code comments explain why this implementation is necessary instead of an obvious alternative.

Comments must remain factual and maintainable. Do not add comments that restate code. Update any
nearby comment made stale by a change.

## Verification

Use Minitest for Ruby code:

```bash
bin/rails test
bin/rails test test/path/to/file_test.rb
bin/rails test test/path/to/file_test.rb:LINE
```

Use Vitest for JavaScript code:

```bash
pnpm test
```

All meaningful behavior changes need risk-appropriate tests. Cover success, failure, authorization,
and relevant boundary cases. Do not add placeholder, skipped, TODO, or behavior-mocking tests.

Before finishing, run the narrowest relevant checks, review touched comments and documentation,
and state clearly which checks could not be run.
