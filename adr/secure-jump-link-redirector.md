# Secure Jump-Link Redirector (2026-04-27)

## Status

Accepted implementation note.

## Context

If you share or transfer the private URL as is, URL itself will be treated like authorization
information. In particular, the following problems occur when designing with jump pages and redirect
interceptors.

- query `destination_url` If you include it in the parameter, the hidden URL will be hidden by a
  third party or log viewer who saw the jump URL.
- For "private public URL without access control" such as Teams, knowing URL becomes the effective
  authority, and it is easy to leak through transfers, logs, referers, and browser history.
- If you post the jump destination URL in the response body or the normal Rails log, the secret URL
  will be brought out to the operational side of the public URL.
- If you process a jump on a domain with cookies, unnecessary authentication/session information
  will be included in the jump request.

Therefore, the jump URL that is made public is only a random token that does not contain
confidential information, and the corresponding destination URL, status, authority information,
number of uses, expiration time, and deletion possible time are managed on the server side.

## Decision

Jump URL is limited to the following format.

```text
GET /?to=:public_id
```

`public_id` is a Nanoid 21 character opaque identifier and public URL is `destination_url` or
permission information.

Separate the model and table 1:1 for each TLD.

- `jump.example.app` -> `AppJumpLink` -> `app_jump_links`
- `jump.example.com` -> `ComJumpLink` -> `com_jump_links`
- `jump.example.org` -> `OrgJumpLink` -> `org_jump_links`

Do not use a single polymorphic table. Place each table in its own `redirector` database connection.

Each record has the following operational information.

- `destination_url`: Actual transition destination managed only on the server side
- `status_id`: Represent `active`, `disabled`, `revoked` as an integer constant
- `revoked_at`: Used for expiration/revocation determination. Unexpired is far-future sentinel
- `deletable_at`: Deletable time after retention. far-future sentinel if not set
- `max_uses` / `uses_count`: Limit on number of uses. `max_uses = 0` is unlimited
- `policy`: hook for future authorization conditions

`revoked_at` and `deletable_at` should not be nullable, and the unset state should be set to
`Time.utc(9999, 12, 31, 23, 59, 59)` Expressed as

## Implemented Behavior

In this implementation, the following is consolidated into the shared model concern `JumpLinkable`.

- Nanoid generation of `public_id`
- far-future sentinel completion
- State management with integer constant. Don't use Rails enums
- `active?`
- `available_for?(user:)`
- `revoke!`
- Race-safe `uses_count` increment with row lock

Redirect processing is centralized in `Jump::ToRedirector` controller concern, and each TLD
controller explicitly specifies the model.

- `Jump::App::RootsController::JUMP_LINK_MODEL = AppJumpLink`
- `Jump::Com::RootsController::JUMP_LINK_MODEL = ComJumpLink`
- `Jump::Org::RootsController::JUMP_LINK_MODEL = OrgJumpLink`

Each controller uses root (`GET /`) as redirect endpoint, and from `to` query parameter Get
`public_id`.

The controller searches for records using only `public_id`, and performs availability checks and
usage count additions in the same row. Do this within lock. Returns `404` if unavailable,
non-existent, or limit reached.

Observe the following when redirecting.

- `redirect_to destination_url, allow_other_host: true`
- `Referrer-Policy: no-referrer`
- Skip cookie session
- In order to make it difficult to output `destination_url` to the normal redirect log line, the
  redirect call is run in silence
- Do not display `destination_url` in the response body

## Tradeoffs

The design of having records in the DB is more expensive to operate than a simple signed URL.
However, server-side state is required to meet the following requirements:

- Do not include destination URL in public URL
- Can be revoke later
- Do not allow `max_uses` to exceed even under concurrent access
- Ability to add future policy/authorization conditions
- Retention and deletion time can be specified

`deletable_at` does not implement the deletion job in the initial implementation, but it is included
from the beginning to clarify the record lifecycle in the DB schema.

## Follow-up

- For the real domain, use a jump-only domain that does not include cookies.
- Until the evaluation contents of `policy` are determined, the hook should always be explicitly
  allowed.
- Retention job / purge job will be implemented separately.
- Run redirector DB migration and CI before actual operation.
