# Restoration G1: Remove `any_instance.stub`

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/notes/any-instance-stub-removal.md`

## Goal

Eliminate `any_instance.stub` (and `Mocha`-style `any_instance` patterns) in favor of dependency
injection or real fixtures. Keeps test brittleness low and forces honest seams.

## Key surface

`test/` tree-wide. Refactor test setup and the production code seams the tests needed to stub.

## Verification

Grep finds zero `any_instance` matches in `test/`. Suite stays green.

## Related

- `plans/backlog/gh616-remove-any-instance-stub.md` — GitHub issue tracker for the same effort.
