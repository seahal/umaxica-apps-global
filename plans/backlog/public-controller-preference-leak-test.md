# PublicController Preference Leak Test

Extracted from `plans/active/public-controller-base-plan.md` during archive.

## Problem

The plan specified that public controller tests must verify no `Current` / `Actor` / `Preference` /
`Session` state leaks into the response. Specifically, after a request to a `PublicController`
endpoint:

- `Actor.session` is unchanged.
- For jump tests: `Actor.surface` is `nil` (the lifecycle was not invoked).

The existing `Jump::PublicController` test (at `test/controllers/jump/public_controller_test.rb`)
covers part of this, but the `Apex::PublicController` and `Sign::PublicController` equivalents are
missing. Additionally, `Actor.preference` reset behavior is not explicitly verified for any of the
three bases.

## Acceptance

For each of the three `PublicController` bases (`Apex::PublicController`, `Sign::PublicController`,
`Jump::PublicController`):

- After a GET request to a public endpoint, `Actor.session` is unchanged from before the request.
- After a GET request to a jump public endpoint, `Actor.surface` is `nil`.
- `Actor.preference` is not populated (remains `NULL`) after a public endpoint request — the
  `Preference` resolution pipeline is not invoked.

## Related

- `plans/archive/public-controller-base-plan.md` (original plan)
- `test/controllers/jump/public_controller_test.rb` (existing partial coverage)
- `app/controllers/apex/public_controller.rb`
- `app/controllers/sign/public_controller.rb`
- `app/controllers/jump/public_controller.rb`
