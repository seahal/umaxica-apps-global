# Implementation Notes

## Purpose

Implementation notes preserve the decisions made while carrying out a plan. They are for durable
handoff context, not transcripts or source-of-truth documentation.

## When To Write

Write an implementation note when a non-trivial task involves any of the following:

- a decision not written in the original spec, plan, ADR, or docs
- a change, compromise, or deferral from the accepted plan
- an interpretation of ambiguous existing code or tests
- a contradiction between comments, code, tests, ADRs, docs, plans, or existing notes
- a compatibility constraint, lifecycle constraint, or security boundary that is easy to miss
- a rejected alternative that future maintainers are likely to revisit
- a constraint reviewers or future agents need to know

When in doubt, prefer a short note over losing durable context. Keep exploratory scratch work in
`memos/`, but promote implementation-relevant observations into `notes/` before finishing.

Use `notes/implementation/YYYY-MM-DD-<task-slug>.md`.

## What To Include

Include:

- original plan or spec reference
- related ADRs, docs, plans, or notes
- comments, code paths, or tests that were checked for consistency
- decisions made during implementation and why
- deviations from the plan and their risk
- contradictions or stale guidance found, and the current interpretation
- follow-up work that should be promoted to `plans/`
- tests run and tests not run

Do not include:

- chain-of-thought
- raw command history
- secrets, tokens, cookies, authorization headers, or full request parameters
- stable decisions that belong directly in `adr/`
- current behavior documentation that belongs directly in `docs/`

## Promotion Rule

Before finishing, review any implementation notes created for the task:

- promote accepted design decisions to `adr/`
- promote future work to `plans/active/` or `plans/backlog/`
- promote implemented stable behavior to `docs/`
- leave only provisional or handoff context in `notes/`

## Template

```markdown
# <Task Name> Implementation Notes

## Context

- Original plan/spec:
- Related ADR/docs/plans:
- Implementation date:

## Decisions Made During Implementation

- Decision:
  - Why:
  - Alternatives considered:
  - Follow-up needed:

## Deviations From Plan

- Change:
  - Why:
  - Risk:
  - Follow-up:

## Review Notes

- Tests run:
- Tests not run:
- Documentation or ADR promotion needed:
```
