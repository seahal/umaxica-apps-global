# Coverage Expansion via Test-Only Additions

## Summary

Use explicit-path coverage runs to identify under-covered executable lines, then add focused
Minitest coverage under `test/**` only. Do not change production code.

## Key Changes

- Keep coverage work limited to `test/**` plus the two tracking files used by the workflow.
- Add new `*_coverage_test.rb` files in the repo's existing coverage-test style.
- Prioritize files currently below the per-file threshold before chasing aggregate coverage.
- Skip unreachable lines and record them in `COVERAGE_TEST_ONLY_NOTES.md`.

## Test Plan

- Run `bin/rails db:test:prepare` when the environment can reach PostgreSQL.
- Run `COVERAGE=true bin/rails test test/` to refresh the authoritative baseline.
- Re-run targeted files first, then the full explicit-path suite after each batch.

## Assumptions

- `test/` is the full suite.
- SimpleCov already starts early enough in `test/test_helper.rb`.
- Coverage scratch output under `coverage/` is disposable.
