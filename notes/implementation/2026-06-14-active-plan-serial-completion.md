# Active Plan Serial Completion Notes

## Context

- Original plan/spec: `plans/active` serial completion request.
- Related decisions/docs/plans:
  - `plans/README.md`
  - `adr/acme-sign-core-base-port-boundary.md`
  - `plans/active/csp-violation-reporting-plan.md`
- Implementation date: 2026-06-14

## Decisions Made During Implementation

- Decision: Treat `plans/active` strictly as currently implementable or currently verifying work.
  - Why: The directory contained completed, superseded, inventory-only, and future-gated plans that
    made the active set look larger than the implementable set.
  - Follow-up needed: Continue moving completed plans to `plans/archive` and future-gated plans to
    `plans/backlog` as each active item is completed or blocked by a source-of-truth decision.

- Decision: Move publication work to backlog.
  - Why: `docs/architecture/regional-content.md` and the plan itself say regional content delivery
    is outside this repository until a current ADR changes that boundary.
  - Follow-up needed: Re-promote only after an ADR decides repository, routing, and storage
    ownership.

- Decision: Implement CSP report intake as a service behind the existing public bare controllers.
  - Why: The existing controller concern logged raw report fields directly. The active plan required
    defensive parsing, sanitization, classification, and structured aggregation.
  - Follow-up needed: Re-run focused CSP tests after the test DB host and fixture cleanup state are
    stable.

## Deviations From Plan

- Change: The CSP plan remains in `plans/active` after implementation.
  - Why: Focused verification was blocked by local test DB instability after one run reached the
    test assertions.
  - Risk: The implementation has only syntax checks plus a partially completed focused Rails run in
    this checkout.
  - Follow-up: Run the focused tests and archive the plan when they pass.

## Review Notes

- Tests run:
  - `ruby -c app/services/csp_violation_report_intake.rb`
  - `ruby -c app/controllers/concerns/csp_violation_report.rb`
  - `ruby -c test/services/csp_violation_report_intake_test.rb`
  - `ruby -c test/controllers/csp_violation_reports_controller_test.rb`
  - `bin/rails test test/services/csp_violation_report_intake_test.rb test/controllers/csp_violation_reports_controller_test.rb`
  - `PARALLEL_WORKERS=1 bin/rails test test/services/csp_violation_report_intake_test.rb test/controllers/csp_violation_reports_controller_test.rb`
- Tests not run:
  - Full suite.
  - Broader surface/routing tests.
- Blocking details:
  - `RAILS_ENV=test bin/rails db:prepare` failed because host `primary` could not be resolved.
  - The first focused CSP Rails run later hit fixture cleanup deadlock/foreign-key state.
  - The second focused CSP Rails run failed before tests because host `primary` could not be
    resolved.
