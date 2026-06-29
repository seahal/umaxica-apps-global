# Preference JWT → JS-Visible Cookie Projection Decision

## Status

Backlog. **Final decision required from 2026-06-06 onward.** Captured 2026-06-05 while moving
preference and gate cookies to `SameSite=Strict` (see `adr/session-token-hardening-baseline.md`).

**Domain scope resolved (2026-06-29):** Mirror cookies (`ct`, `tz`, `cu`, etc.) now written with
`domain: true` via `preference_cookie_options` → apex-scoped per surface (`.umaxica.app` etc.).
Implemented in `preference_cookie_options` (`preference_base.rb`) and `write_preference_cookie`
(`preference_cookie_writer.rb`). Remaining open questions (items 1–4 below) are unchanged.

## Context

The preference JWT (`*_preference_access` cookie, ES384, `Security::Jwt::PreferenceTokenCodec`) is
the single source of truth for preference state. Its payload already carries the JS-relevant values:
`ct`, `lx`/`language`, `ri`, `tz`, `cu`, `df`, `tf`, `mo`, `dn`, `ps`, `r18s`, and the consent flags
(`consented` / `functional` / `performant` / `targetable`) — see
`app/controllers/concerns/preference/base.rb` (`build_preferences_payload`, ~lines 654-715).

The JWT access cookie is `HttpOnly`, so **JavaScript cannot read it**. The system therefore projects
the values JS needs into separate non-`HttpOnly` cookies (`r18s`, `language`, the consent buffer
`preference_consented`, the 2-char display cookies). These projection cookies are write-only mirrors
of the JWT; Rails reads them only as a fallback. The consent buffer
(`preference/consented_buffer.rb`) is one such JS-visible projection.

Recently (around 2026-06-03 to 2026-06-05) the projection parameters for the 2-char display cookies
(e.g. `ct`) were removed. Because some of those values must still be readable by client-side code
(and possibly by a separate Hono/JS service that shares the `language` cookie name), removing the
projection without a replacement leaves JS unable to read them without a round-trip. This needs a
deliberate, recorded decision rather than ad-hoc re-adding.

## Decision Needed

1. **Which JWT values must be JS-visible**, and therefore must be projected into non-`HttpOnly`
   cookies (candidates: `ct`, `language`, `r18s`, `tz`, and the consent flags). Confirm the Hono
   shared-cookie contract for `language`.
2. **Re-add the removed projections by transcribing from the JWT** so the JWT stays the single
   source of truth and the cookies remain pure mirrors (no independent writes).
3. **Where the projection runs.** Preferred direction (per owner, 2026-06-05): project from the JWT
   **when a preference is updated** and **when the request passes through the refresh-token path**,
   rather than on every request. This keeps the mirrors fresh at the points the JWT itself changes.
4. **SameSite for the projections.** They are now `SameSite=Strict` (this change). Confirm Strict is
   acceptable for the JS-visible mirrors (cost: a one-paint stale/missing value on the first
   cross-site inbound hit before a same-site request repopulates them; SSOT is the JWT).

## Related, Same-Track Items

### R18 anonymous acknowledgment (do NOT permanently restructure)

The anonymous R18 acknowledgment is a 30-day signed cookie (`r18_gate.rb`,
`cookies.signed[:r18_acknowledged]`), separate from the JWT. The `r18s` display preference is
already in the JWT. Owner direction (2026-06-05): **do not refactor this permanently.** Instead,
project the relevant gate state from the JWT on the same triggers as item 3 (preference update /
refresh-token path) so JS sees a consistent value. Keep the simple signed-cookie gate otherwise.

Open question to resolve before any consolidation: does a truly anonymous (logged-out) visitor get a
`VisitorPreference` JWT issued? If yes, the acknowledgment could ride the visitor JWT projection; if
no, the standalone signed cookie stays.

### Dormant verification cookie

The step-up verification cookie machinery is currently **defined but unwired in application code**:

- `Sign::VerificationAuditAndCookie#set_verification_cookie!` has no caller in `app/`.
- `*Verification.issue_for_token!` is called only from tests.
- The read path `Verification::Base#verification_record_satisfied?`
  (`app/controllers/concerns/verification/base.rb:55`) is reached only on the no-scope fallback
  branch; live step-up uses the scope-based `recorded_step_up_satisfied?` (DB-recorded) path.

Decision needed: **wire it up or remove it.** Regardless of that choice, this proof-of-possession
token (raw token in cookie, digest in DB, `__Host-`, ~15-min TTL, independently revocable) must NOT
be folded into the preference JWT — it is a different security domain (host-only vs apex-scoped,
short-lived vs long-lived, distinct audience). Its SameSite was set to `Strict` in the same change
as the projections (harmless while unwired; correct once wired).

## References

- `adr/session-token-hardening-baseline.md` (cookie hardening; session stays Lax)
- `app/controllers/concerns/preference/base.rb` (payload build, cookie option helpers)
- `app/controllers/concerns/preference/consented_buffer.rb` (JS consent projection)
- `app/controllers/concerns/preference/cookie_writer.rb` (display-cookie projection writer)
- `app/controllers/concerns/r18_gate.rb` (anonymous acknowledgment)
- `app/controllers/concerns/verification/base.rb`, `concerns/sign/verification_audit_and_cookie.rb`
