# PublicController Preference Leak Test

**Status:** Archived as superseded (verified 2026-05-19).

Do not implement this backlog note as originally written. Reuse only the open-controller leak
coverage ideas that match the accepted `Actor.tld`, `Actor.authentication`, and `Actor.preference`
API.

The surviving work is tracked by `plans/active/actor-current-context-api-cleanup.md`. Current
coverage exists in the public/open controller tests, including
`test/controllers/jump/public_controller_test.rb`,
`test/controllers/acme/public_controller_test.rb`, and
`test/controllers/sign/public_controller_test.rb`.

Extracted from `plans/active/public-controller-base-plan.md` during archive.

## Problem

The plan specified that lightweight open controller tests must verify no `Actor`, preference, or
session state leaks into the response. Specifically, after a request to an `OpenController` endpoint
or a legacy compatibility `PublicController` endpoint:

- `Actor.authentication.login_public_id` is unchanged.
- `Actor.tld` is `nil` for surfaces where the lifecycle was not invoked.

The existing `Jump::PublicController` test (at `test/controllers/jump/public_controller_test.rb`)
covers part of this, but the `Acme` and `Sign` equivalents must stay aligned as those bases migrate
from `PublicController` naming to `OpenController` naming. Additionally, `Actor.preference` reset
behavior should remain explicit for each lightweight base.

## Acceptance

For each lightweight open base (`Acme::OpenController`, `Sign::OpenController`, and existing
compatibility `PublicController` bases while they remain):

- After a GET request to a public endpoint, `Actor.authentication.login_public_id` is unchanged from
  before the request.
- After a GET request to a public endpoint without the `Actor` lifecycle, `Actor.tld` is `nil`.
- `Actor.preference` is not populated (remains `NULL`) after a public endpoint request — the
  `Preference` resolution pipeline is not invoked.
- Do not add new coverage against removed readers such as `Actor.surface` or `Actor.domain`.
- Do not add new direct `Actor.session` or `Actor.token` coverage except while verifying migration
  behavior.

## Related

- `plans/archive/public-controller-base-plan.md` (original plan)
- `test/controllers/jump/public_controller_test.rb` (existing partial coverage)
- `app/controllers/acme/public_controller.rb`
- `app/controllers/sign/public_controller.rb`
- `app/controllers/jump/public_controller.rb`
