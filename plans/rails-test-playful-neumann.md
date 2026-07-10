# Context

The user wants to run the Rails Minitest suite (`bin/rails test`) to see current state, then triage
and fix any failing tests together. `git status` shows many test files under
`test/controllers/auth/app/**` are already modified on the `develop` branch (uncommitted changes),
so the suite may reflect in-progress work rather than a clean baseline.

This is not an implementation task — there is nothing to design or architect yet. The actual "plan"
is just: run the test suite, read the failure output, and use that as the starting point for a
follow-up discussion/fix session with the user.

# Plan

1. Run `bin/rails test` (or the appropriate multi-DB/test-prep wrapper if this repo requires one —
   check `docs/operations/db-workflow.md` first) at the repo root.
2. Capture and summarize the output: pass/fail counts, list of failing/erroring tests grouped by
   file, and the first line of each failure/error message.
3. Do not attempt any fixes yet. Report the summary back to the user and jointly decide which
   failures to tackle first, in what order, and whether any are related to the in-flight controller
   test changes already showing in `git status`.
4. Once the user picks a starting point, follow the relevant harness rules
   (`.agents/harnesses/rules/generic/testing.mdc`, `no-test-only-code.mdc`, and any
   controller/routing/surfaces rules implicated by the specific failure) before editing code.

# Verification

Success is simply: `bin/rails test` has been run to completion (or to a clear stopping point if it's
very slow/large) and its output has been summarized accurately enough for the user to choose what to
fix next.

# Results of the first run (2026-07-01)

`bin/rails test` was run once, full suite, no DB reset first (no in-flight table renames on
`develop` per `git status`/recent commits). Finished in ~470s:

```
8886 runs, 38535 assertions, 570 failures, 142 errors, 0 skips
```

From the tail of the output, failures/errors cluster into distinct root causes rather than 570+142
unrelated bugs:

1. **TOTP settings controller — step-up/verification regression** (many failures in
   `test/controllers/auth/app/settings/totps_controller_test.rb`): requests that used to return 2XX
   now redirect (302) to `/verification?...flow=step_up.bootstrap...`, and recovery-passcode /
   `client_secret_credentials` counts don't change as expected. Looks like a step-up MFA requirement
   was added/changed for the TOTP settings flow and either the controller or the test setup
   (bootstrap session state) is out of sync. Likely the single largest cluster of the 570 failures
   since nearly every test in that file appears in the tail.
2. **Postgres deadlocks / FK violations during fixture load or teardown**
   (`ActiveRecord::Deadlocked` in `totps_controller_test.rb`, `ActiveRecord::InvalidForeignKey` on
   `client_token_binding_methods`/`client_tokens` in
   `test/controllers/side/com/dashboards_controller_test.rb`). These look like **test-run
   infrastructure** issues (parallel test workers or fixture ordering across the ~25-DB setup), not
   application logic bugs — worth confirming whether `bin/rails test` here runs with parallel
   workers, and whether that's new/expected per `docs/operations/db-workflow.md`.
3. **One real policy violation**: `ForbiddenRailsPatternsTest` fails because
   `app/controllers/concerns/preference_jwt_configuration.rb:127` uses `rescue nil`
   (`Rails.configuration.x.boot_config.fetch(:hosts, nil) rescue nil`), which
   `AGENTS.md`/`.agents/harnesses/rules/generic/absolute-rules.mdc` explicitly forbid. This is a
   small, isolated, clearly-actionable fix.

The full 8886-line output was not persisted to a file — only the tail (~200 lines) was captured. To
categorize the remaining failures/errors precisely (are they all in the 3 buckets above, or are
there more distinct root causes hiding earlier in the log?), we'd want a second run piping full
output to a log file (e.g. `tmp/` scratch or `/tmp`) and grep-summarizing by test file / exception
class.

# Next step (to do after exiting plan mode)

1. Re-run `bin/rails test`, this time redirecting full output to a log file, and grep/group all 570
   failures + 142 errors by file and exception type to get an exhaustive (not tail-only) breakdown.
2. Present the full breakdown to the user.
3. Ask the user which cluster to start with — the `rescue nil` policy violation is the smallest,
   most isolated fix and a reasonable first pick, but defer to the user's priority.
4. Only after the user picks a starting point, read the relevant harness rules for that area (e.g.
   `.agents/harnesses/rules/generic/testing.mdc`,
   `.agents/harnesses/rules/generic/no-silent-fallback.mdc` for the `rescue nil` case,
   `.agents/harnesses/rules/project/surfaces.mdc` if the TOTP step-up flow touches auth/session
   code) before editing anything.
