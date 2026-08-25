# Plan: Systematically Reduce Rails Test Failures/Errors (Batch 1)

## Context

The goal is to **reduce Rails test failures and errors** in a controlled, auditable way — **not** a
coverage task. The suite is large (~1,100 test files; models 407, controllers 351, services 165,
integration 77) across three surfaces (app/org/com) and a 16-database test topology (8 primary + 8
replica). Existing `notes/implementation/` entries flag pre-existing breakage (a "791
pending-migration gate" that has blocked `bin/rails test`, a stale verification skip allowlist, and
failing security-invariant tests), so failures are expected and the job is to drive them down
cluster-by-cluster without weakening tests.

This plan executes **one repair batch** end-to-end and stops with a clear next-batch plan, per the
task's required workflow.

## Hard constraints (from the task brief)

- **Repository boundary**: read/modify only files under repo root. No inspecting Ruby runtime,
  stdlib, gems, `/usr`, `/lib`, `/etc`, `~`, credentials, shell history, OS/container config. Stack
  traces pointing outside the repo are context only.
- **No questions / no pausing**: make the safest allowed decision; if blocked, write notes and stop.
- **Allowed commands ONLY**: `bin/rails test test/`, `bin/rails test`, `bin/rails test <path>`,
  `bin/rails test <path>:<line>`, `pnpm test`, `pnpm check`, `pnpm fix`, `bundle exec rubocop -a`.
- **Forbidden commands**: all `git`, `bundle install/update`, coverage commands, network/external,
  runtime/gem/Bundler/OS diagnostics. **NOTE:** `bin/rails db:migrate:reset` / `db:migrate` are
  **not** in the allowed list → treated as forbidden (see Risk R1).
- **Allowed file changes**: `app/**`, `db/**`, `test/**`, `notes/implementation/**`,
  `TEST_REPAIR_NOTES.md`.
- **Forbidden file changes**: `config/**`, `bin/**`, `Gemfile*`, package files, CI files, docs
  outside `notes/implementation`.
- **Never** skip/delete/weaken/loosen tests, reduce assertions, or mock away verified behavior to go
  green. Do not work on coverage or read coverage reports. Preserve domain boundaries (app/org/com
  separation, auth pipeline order, no `permit!`/`skip_*`/`rescue nil`, no flash).

## Workflow for this batch

### Step 1 — Baseline

Run the full suite once and capture the summary line:

```
bin/rails test test/
```

Record **runs / assertions / failures / errors / skips**. If the suite cannot boot (e.g. the
pending-migration gate), go to Risk R1.

### Step 2 — Error inventory & clustering

From the output, build an inventory of every error/failure and group into **root-cause clusters**
(same exception class + same originating repo file/constant = one cluster). Capture which clusters
span many tests (highest leverage).

### Step 3 — Prioritize, pick ONE low-risk cluster

Cluster priority order:

1. **Boot/load errors** — `NameError`, `LoadError`, missing constants, broken helpers, malformed
   tests, uninitialized fixtures. (Highest leverage; one fix often clears many tests.)
2. Deterministic **model/service/unit** failures.
3. **Controller/request/routing/integration** failures.
4. **Last:** security-sensitive auth/session/OIDC/token/logout/credential flows (only if the fix is
   obvious; otherwise note + stop — see Risk R2).

Pick exactly one cluster with one obvious root cause affecting many failures. Prefer cluster
category 1 or 2 for this first batch.

### Step 4 — Investigate (repo files only)

Read only the repo files implicated by that cluster: the failing test(s), the
app/model/service/fixture under test, and relevant support helpers (`test/support/*.rb`,
`test/test_helper.rb`, fixtures under `test/fixtures/`). Map any external stack-trace paths back to
repo files.

### Step 5 — Apply the smallest correct fix

Decide per the repair policy:

- Test outdated but current behavior clearly intended → **update the test** (without weakening it).
- App behavior wrong → **fix app code minimally**.
- Schema/test-data/fixture wrong → **fix `db/**`or`test/**` minimally**, documenting evidence. (DB
  file changes only when directly required by a confirmed failure; no speculative changes.)

### Step 6 — Verify narrowly

Run the narrowest relevant command:

```
bin/rails test <path-to-affected-test>
bin/rails test <path-to-affected-test>:<line>
```

If fixed, move to the next cluster. **Do not** rerun the full suite after every edit.

### Step 7 — Repeat for a small batch

Apply Steps 3–6 to a small number of low-risk clusters (target ~2–4 this batch). Avoid unrelated
drive-by fixes.

### Step 8 — Batch lint + full re-run

After the small batch of fixes:

```
pnpm fix
bundle exec rubocop -a
bin/rails test test/
```

Rebuild the inventory and compute the delta vs baseline.

### Step 9 — Stop with next-batch plan

Stop after this one batch. Produce the final report and the next-batch plan.

## Notes / audit trail (required)

Create `notes/implementation/test-repair-batch-1.md` (and a running `TEST_REPAIR_NOTES.md` at repo
root for the rolling summary). The batch note must include, per cluster:

- date/time, baseline failures/errors, cluster ID, affected tests, suspected root cause, files
  inspected, files changed, command run, result, decision (fixed/skipped/stopped), next recommended
  cluster.

## Risks & kill switches

- **R1 — Suite won't boot / DB schema out of sync.** Notes mention a pending-migration gate that has
  blocked `bin/rails test`. The DB-rebuild command (`db:migrate:reset`) is **not** in the allowed
  list. If the suite cannot boot without a DB rebuild or a `config/**` change, this is a **kill
  switch**: write notes documenting the exact blocker and stop. Do **not** silently edit config or
  run a forbidden command.
- **R2 — Security-sensitive cluster.** If the only remaining/large cluster is in
  auth/session/OIDC/logout/token/credential flows and the correct fix is not obvious, write notes
  and stop rather than guess.
- **R3 — Failures increase or root cause unclear.** If a change increases failures/errors or the
  root cause is uncertain, revert that change (within allowed files) and note it; do not stack
  speculative fixes.
- **R4 — Required change outside allowed files** (`config/**`, `bin/**`, `Gemfile*`, routes, deps) →
  kill switch: note and stop.
- **R5 — SimpleCov coverage gate.** `test_helper.rb` enforces a coverage minimum. Since I cannot
  edit `config/**`/`test_helper.rb`-driven coverage policy as a coverage task and must not pursue
  coverage, if the _only_ "failure" is a coverage-threshold exit (not a test failure/error), treat
  it as out of scope: note it and exclude it from the failure/error count.

## Verification

Success for this batch = **net reduction in failures + errors** between the Step 1 baseline and the
Step 8 re-run, with:

- no test skipped/deleted/weakened and no assertions removed,
- no coverage work performed,
- all changes confined to allowed paths,
- every change backed by evidence in `notes/implementation/test-repair-batch-1.md`.

## Final report (delivered at end of batch)

- starting vs ending runs/assertions/failures/errors/skips
- net failures/errors reduced
- clusters fixed / clusters skipped
- files changed / commands run
- remaining top clusters
- next-batch plan
