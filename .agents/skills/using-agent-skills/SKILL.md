---
name: using-agent-skills
description:
  Routes a task to the engineering-workflow skill that covers it. Use at the start of a task, when
  more than one skill could apply, or when it is unclear which phase the work is in. Covers the
  lifecycle from intent extraction through spec, planning, implementation, review, and launch.
---

# Using Agent Skills

These skills encode the engineering workflow by development phase. This one routes a task to the
right skill; the rest carry the procedure.

Behavioral defaults — output length, narration, scope, self-verification, and delegation — are set
in `AGENTS.md` and `.agents/harnesses/rules/generic/model-behavior-calibration.mdc`. They are not
restated here, so that there is one place to change them.

## Routing

```
Task arrives
    │
    ├── Don't know what the user wants yet? ─→ interview-me
    ├── Rough concept, need variants? ───────→ idea-refine
    ├── New project/feature/change? ─────────→ spec-driven-development
    ├── Have a spec, need tasks? ────────────→ planning-and-task-breakdown
    ├── Implementing code? ──────────────────→ incremental-implementation
    │   ├── UI work? ────────────────────────→ frontend-ui-engineering
    │   ├── API work? ───────────────────────→ api-and-interface-design
    │   ├── Need better context? ────────────→ context-engineering
    │   ├── Need doc-verified code? ─────────→ source-driven-development
    │   └── Stakes high / unfamiliar code? ──→ doubt-driven-development
    ├── Writing/running tests? ──────────────→ test-driven-development
    │   └── Browser-based? ──────────────────→ browser-testing-with-devtools
    ├── Something broke? ────────────────────→ debugging-and-error-recovery
    ├── Reviewing code? ─────────────────────→ code-review-and-quality
    │   ├── Too complex? ────────────────────→ code-simplification
    │   ├── Security concerns? ──────────────→ security-and-hardening
    │   └── Performance concerns? ───────────→ performance-optimization
    ├── Committing/branching? ───────────────→ git-workflow-and-versioning
    ├── CI/CD pipeline work? ────────────────→ ci-cd-and-automation
    ├── Deprecating/migrating? ──────────────→ deprecation-and-migration
    ├── Writing docs/ADRs? ──────────────────→ documentation-and-adrs
    ├── Adding logs/metrics/alerts? ─────────→ observability-and-instrumentation
    └── Deploying/launching? ────────────────→ shipping-and-launch
```

## Sequencing

Several skills usually apply to one task. A full feature typically runs `interview-me` →
`idea-refine` → `spec-driven-development` → `planning-and-task-breakdown` →
`incremental-implementation` → `test-driven-development` → `code-review-and-quality` →
`git-workflow-and-versioning` → `documentation-and-adrs` → `shipping-and-launch`, with
`observability-and-instrumentation` running alongside implementation rather than after it. A bug fix
usually needs only `debugging-and-error-recovery` → `test-driven-development` →
`code-review-and-quality`.

Once a skill applies, follow its steps in order — the ordering is what prevents the mistakes the
skill exists to catch. When the task is non-trivial and no spec exists, start with
`spec-driven-development`.

## Quick reference

| Phase  | Skill                             | What it does                                                               |
| ------ | --------------------------------- | -------------------------------------------------------------------------- |
| Define | interview-me                      | Surface what the user actually wants before any plan, spec, or code exists |
| Define | idea-refine                       | Refine ideas through structured divergent and convergent thinking          |
| Define | spec-driven-development           | Requirements and acceptance criteria before code                           |
| Plan   | planning-and-task-breakdown       | Decompose into small, verifiable tasks                                     |
| Build  | incremental-implementation        | Thin vertical slices, test each before expanding                           |
| Build  | source-driven-development         | Verify against official docs before implementing                           |
| Build  | doubt-driven-development          | Adversarial review of irreversible decisions                               |
| Build  | context-engineering               | Right context at the right time                                            |
| Build  | frontend-ui-engineering           | Production-quality UI with accessibility                                   |
| Build  | api-and-interface-design          | Stable interfaces with clear contracts                                     |
| Verify | test-driven-development           | Failing test first, then make it pass                                      |
| Verify | browser-testing-with-devtools     | Chrome DevTools MCP for runtime verification                               |
| Verify | debugging-and-error-recovery      | Reproduce, localize, fix, guard                                            |
| Review | code-review-and-quality           | Five-axis review with quality gates                                        |
| Review | code-simplification               | Preserve behavior while reducing unnecessary complexity                    |
| Review | security-and-hardening            | OWASP prevention, input validation, least privilege                        |
| Review | performance-optimization          | Measure first, optimize only what matters                                  |
| Ship   | git-workflow-and-versioning       | Atomic commits, clean history                                              |
| Ship   | ci-cd-and-automation              | Automated quality gates on every change                                    |
| Ship   | deprecation-and-migration         | Remove old systems and migrate users safely                                |
| Ship   | documentation-and-adrs            | Document the why, not just the what                                        |
| Ship   | observability-and-instrumentation | Structured logs, RED metrics, traces, symptom-based alerts                 |
| Ship   | shipping-and-launch               | Pre-launch checklist, monitoring, rollback plan                            |
