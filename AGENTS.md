# Umaxica Apps Global Guide for AI Coding Agents

This repository is a Ruby on Rails application, not the Rails framework monorepo.

`AGENTS.md` contains only guidance needed across the repository. Detailed rules live under
`.agents/harnesses/rules/` and are loaded only for matching tasks. Read the applicable rules before
editing; each rule is canonical within its area.

## Authorization and Scope

- For requests to answer, explain, review, diagnose, or plan, inspect the relevant material and
  report the result without changing repository files or external state.
- For requests to change, build, or fix, make the requested in-scope local changes and run relevant
  non-destructive verification without asking first.
- Ask before destructive or irreversible actions, external writes, purchases, material scope
  expansion, or work that requires information only the user can provide.
- Preserve unrelated staged, unstaged, and untracked changes. Never reset or clean the worktree to
  simplify a task.

## Implementation Method

1. Confirm the requested scope and inspect the current worktree.
2. Read the files to change, their tests, one nearby precedent, and the applicable task rules.
3. For non-trivial work, inspect relevant current decisions and plans before choosing an approach.
4. Make the smallest coherent change. Prefer direct edits over compatibility shims unless a safe
   deployment requires compatibility.
5. Use established, well-maintained libraries instead of custom implementations when practical.
6. Run the narrowest relevant verification first, then broaden only when the affected boundary
   warrants it.
7. Report the outcome, verification evidence, and anything blocked or unverified.

Do not add unrelated cleanup, speculative abstractions, or support for hypothetical requirements.

## Application Boundaries

The application has three independent user-facing trust boundaries:

- `app` — end-user application
- `org` — staff and organization surface
- `com` — public and corporate surface

Keep each surface's controllers, routes, views, policies, sessions, and state separate unless current
code provides an explicit shared abstraction. Cross-surface leakage is a security defect. Read
`.agents/harnesses/rules/project/surfaces.mdc` for any surface-related work.

## Required Task Context

Rule paths below are relative to `.agents/harnesses/rules/`; documentation paths are relative to the
repository root. Load only the entries that match the task.

- Controllers or endpoints: `generic/controllers.mdc`, `generic/routing.mdc`,
  `project/surfaces.mdc`, `project/controller-inheritance.mdc`,
  `docs/architecture/controller-lifecycle.md`
- Minitest or behavior changes: `generic/testing.mdc`, `generic/no-test-only-code.mdc`
- Value objects, services, resolvers, policies, queries, or commands:
  `project/value-object-boundaries.mdc`
- Migrations: `generic/migrations.mdc`
- Persistent data or API shape, including JSON and database schemas: `generic/data-shape-design.mdc`
- Security-sensitive work or broad refactors: `generic/absolute-rules.mdc`,
  `generic/no-silent-fallback.mdc`, `project/regression-guards.mdc`
- Configuration or environment variables: `generic/no-silent-fallback.mdc`
- Routing or authentication workflows: `project/surfaces.mdc`, `generic/routing.mdc`,
  `generic/no-workflow-drift.mdc`, `docs/architecture/controller-lifecycle.md`
- User-facing notices, alerts, or feedback: `generic/no-flash-messages.mdc`
- Google or Apple sign-in buttons and provider branding:
  `docs/reference/third-party-sign-in-button-requirements.md`
- External technical sources: `generic/source-policy.mdc`
- Documentation, ADRs, plans, notes, memos, harnesses, comments, or test names:
  `generic/repository-language.mdc`
- Logging, audit records, telemetry, or product analytics: `adr/application-logging-boundary.md`,
  `docs/security/observability-boundary.md`
- Non-trivial decisions, plan deviations, or handoff context: `generic/implementation-notes.mdc`,
  `project/repository-knowledge-tree.mdc`

For non-trivial architecture, routing, authentication, authorization, database, preference, surface,
or service-layer work, use `project/repository-knowledge-tree.mdc` to load and prioritize relevant
material under `memos/`, `notes/`, `adr/`, `plans/`, and `docs/`. Call out conflicts between current
code and an accepted ADR or stable document before choosing an implementation path.

## Non-Negotiable Boundaries

Do not:

- mix the `app`, `org`, and `com` surfaces
- skip or reorder authentication, authorization, verification, CSRF, or rate-limit protections
- put business logic in controllers; use a service, query, policy, or value object
- use `permit!`, `skip_before_action`, `skip_authorization`, `skip_forgery_protection`, `html_safe`,
  `raw(...)`, `VERIFY_NONE`, `rescue nil`, or ignored rescues
- use Rails flash; render feedback inline in the response
- log tokens, cookies, authorization headers, full request parameters, or secrets; log identifiers
  and outcomes instead
- use application logs as the authoritative record for audit, security, compliance, or purchase
  events; persist those events as data
- store request state in class variables, globals, or `Thread.current`; pass it explicitly
- introduce test-only behavior into application code; change the test instead
- use silent configuration, workflow, or migration fallbacks; fail loudly and name what is missing
- perform destructive database operations without explicit approval of the risk and migration plan

Required Ruby environment variables must use one-argument `ENV.fetch("NAME")` in application and
configuration code so missing configuration fails at boot.

## Repository Content

Write repository prose in English except explicit localization content, translation fixtures,
non-English customer copy, or necessary quotations. Conversation language does not override this
rule. Follow `docs/reference/repository-language-policy.md` for prose changes.

- `.agents/skills/` contains Codex skills, each within its own directory with a `SKILL.md` entrypoint.
- `.agents/harnesses/rules/` is the only harness directory; do not invent other harness locations.
- Keep task scope in the conversation or Codex goal surface. Do not add `.agents/goals/` files.

Code explains implementation, tests explain expected behavior, commit messages explain why, and
comments explain why a non-obvious implementation is necessary. Keep comments factual and update
comments made stale by a change.

## Verification and Reporting

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

All meaningful behavior changes need risk-appropriate tests covering success, failure,
authorization, and relevant boundary cases. Do not add placeholder, skipped, TODO, or
behavior-mocking tests.

Before finishing, run the narrowest relevant checks and review touched comments and documentation.
Report only claims supported by results from the current session. State failed, skipped, blocked,
and unverified checks plainly.

Lead with the outcome and keep responses proportional to the task. Preserve required facts,
decisions, caveats, and next actions; remove repetition and optional background first. Do not add a
separate verifier pass or delegate verification. Delegate only independent, substantial work whose
parallel execution outweighs the cost of re-establishing context.
