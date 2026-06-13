# Goal: Move the Project Toward 93% Rails Test Line Coverage

## Context

Starting baseline: 7301 runs, 28525 assertions, 19 failures, 20 errors, 0 skips. Target: 93% line
coverage (SimpleCov threshold already set in `test/test_helper.rb`). Starting coverage %: unknown —
measured on first run.

Recent in-flight changes (git status) that likely affect the test suite:

- `config/routes/{base,palm,sign,acme}.rb` — CSP violation report routes added to all surfaces
- `test/controllers/public_robots_routing_test.rb` — updated for new surfaces
- `adr/csp-violation-report-route-naming.md` — new (untracked), naming rationale

Active remediation context: `plans/active/surface-routing-pass-remediation-plan.md` — three streams
(tests, health-refactor consistency, contradiction docs). An in-flight ~127-file health refactor is
uncommitted; failures touching that path are likely in a forbidden zone.

The user explicitly said: do not ask questions, do not pause, make the safest decision yourself.

---

## Allowed File Changes

| Allowed                                                 | Forbidden                                            |
| ------------------------------------------------------- | ---------------------------------------------------- |
| `test/**/*`                                             | `config/**/*` (routes, env, credentials)             |
| `app/**/*` (confirmed production bug, minimal fix only) | `db/**/*`, fixtures, factories                       |
| `TEST_REPAIR_AND_COVERAGE_NOTES.md`                     | `bin/**/*`, Gemfile\*, package files, CI files, docs |

This constraint is the decisive gate: any failure whose correct fix lives in a forbidden path is a
**kill-switch event** — document in the notes file, skip, move on.

---

## Process

### Step 1 — Establish Baseline

```bash
COVERAGE=true bin/rails test
```

Record:

- Starting coverage %
- Failure count, error count
- Full failure/error backtraces in `TEST_REPAIR_AND_COVERAGE_NOTES.md`

Parallelization is disabled during coverage runs (SimpleCov config), so this will be slow.

### Step 2 — Triage Into Clusters

Classify each failure/error:

| Category                                                    | Action                      |
| ----------------------------------------------------------- | --------------------------- |
| Test is stale/wrong, fix lives in `test/**`                 | Fix it                      |
| Confirmed production bug, minimal `app/**` fix              | Fix it, note why            |
| Fix requires `config/routes/db/fixtures/factories/deps`     | Kill switch: document, skip |
| Failure traces to in-flight health refactor (~127 files)    | Kill switch: document, skip |
| Failure traces to auth/session/OIDC/token/security ceremony | Kill switch: document, skip |

Prioritize **errors before failures** — errors often mask coverage data for unrelated code.

Hypotheses to confirm against backtrace output (not assumed true until seen):

- Palm surface controllers may be missing or misrouted
- CSP violation report route helpers may be stale in tests
- `public_robots_routing_test.rb` may reference helpers added in the new route files
- Health-controller namespace (HealthsController → HealthController) may be causing NameErrors

### Step 3 — Fix In-Scope Clusters

One cluster at a time. After each fix, run the narrowest relevant test:

```bash
bin/rails test test/path/to/affected_test.rb
```

After all fixes for a cluster are confirmed green, proceed to the next.

Do not skip, delete, weaken, or loosen any test. If a test is genuinely broken and unfixable within
the allowed file set, document under kill switch.

### Step 4 — Re-Measure After Fixes

```bash
COVERAGE=true bin/rails test
```

Record new coverage %, failure count, error count.

### Step 5 — Coverage Targeting

After failures/errors are reduced (or blocked), identify high-yield, low-risk coverage gaps.

**Preferred targets** (deterministic, constructible without fixtures/factories):

- Value objects and normalizers under `app/`
- Validators and predicates
- Model scopes and class methods with no DB fixtures needed (or re-using existing fixtures)
- Helpers and simple formatters
- Mailer templates
- Simple service objects with no external calls
- Deterministic error classes under `app/errors/`
- Policy predicates that don't require live auth context

**Avoid:**

- Auth/session/OIDC/logout/refresh/token/credential/security ceremony flows
- Payment or destructive flows
- Anything requiring new fixtures, factories, config, or routes
- External services, network, Redis, browser/system tests
- Time-sensitive, random, or parallelism-sensitive behavior
- The in-flight health-check refactor (127 files, uncommitted)

Coverage adds follow existing test file patterns. Reference:

- `test/test_helper.rb` for setup and SimpleCov configuration
- Existing test files in the relevant subdirectory for naming and fixture conventions

### Step 6 — Final Cleanup and Report

```bash
vp check --fix
bundle exec rubocop -a
COVERAGE=true bin/rails test
```

Final report in `TEST_REPAIR_AND_COVERAGE_NOTES.md`:

- Starting and ending coverage %
- Starting and ending failure/error counts
- Clusters fixed
- Files changed
- Commands run
- Kill-switch events (skipped risky areas)
- Ranked next steps toward 93% (if not reached)

---

## Key Files

| File                                                                       | Role                                                    |
| -------------------------------------------------------------------------- | ------------------------------------------------------- |
| `test/test_helper.rb`                                                      | SimpleCov config, 93% threshold, parallelization toggle |
| `plans/active/surface-routing-pass-remediation-plan.md`                    | Three remediation streams for new surfaces              |
| `plans/active/surface-routing-controller-pass-base-palm-help-docs-news.md` | Route/controller scaffold decisions                     |
| `config/routes/{base,palm,sign,acme}.rb`                                   | Recent route changes (forbidden to edit)                |
| `test/controllers/public_robots_routing_test.rb`                           | Modified test, verify correctness                       |
| `test/controllers/csp_violation_reports_controller_test.rb`                | 27-endpoint CSP test, verify after route changes        |
| `test/controllers/controller_inheritance_invariant_test.rb`                | Inheritance guard, read before any controller change    |
| `adr/csp-violation-report-route-naming.md`                                 | Route naming decision (read before renaming anything)   |
| `TEST_REPAIR_AND_COVERAGE_NOTES.md`                                        | Living log, create on first run                         |

---

## Honest Expectation

Given the forbidden-file constraints and the in-flight health refactor, a large fraction of the 39
failures/errors may have correct fixes in forbidden paths. The realistic deliverable for this run
is:

1. A documented triage of all 39 failures/errors
2. Fixes for the in-scope subset
3. Meaningful coverage additions for deterministic units
4. A ranked plan for reaching 93% in future runs
