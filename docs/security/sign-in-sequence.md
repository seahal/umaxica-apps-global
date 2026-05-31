# Sign-In Sequence

This document records the current sign-in routing sequence after primary credential verification.
Sign-in establishes the product's `AAL1` boundary. The surface-specific AAL1 methods are listed in
`docs/security/authentication-assurance-levels.md`.

## Sequence

Successful sign-in proceeds through these gates in order:

1. Primary credential verification.
2. MFA challenge when the actor requires MFA and the primary method does not bypass MFA.
3. Session-limit handling.
4. Guardrail.
5. Checkpoint.
6. Selector.
7. Session issuance.
8. Welcome.
9. Final return path or dashboard.

The DB-backed sign-in cycle uses these states for the authoritative lifecycle:

| State                      | Meaning                                                                   |
| -------------------------- | ------------------------------------------------------------------------- |
| `PRIMARY_PENDING`          | Primary credential verification is in progress.                           |
| `MFA_PENDING`              | Sign-in MFA must complete before the sequence can continue.               |
| `SESSION_LIMIT_PENDING`    | Session-limit handling must complete before selector or normal issuance.  |
| `GUARDRAIL_PENDING`        | Pre-activation guardrail checks must stop or clear.                       |
| `CHECKPOINT_PENDING`       | Pre-activation checkpoint participants must stop or clear.                |
| `SELECTOR_PENDING`         | Region/persona activation selection must commit before welcome or return. |
| `SESSION_ISSUANCE_PENDING` | Selector has committed and the normal signed-in session may be issued.    |
| `DASHBOARD_PENDING`        | Legacy state; it is not an authentication boundary for new flows.         |
| `RETURN_PENDING`           | Legacy state; final return is post-auth UX for new flows.                 |
| `COMPLETED`                | The sign-in sequence has completed.                                       |
| `FAILED`                   | The sign-in sequence failed or was abandoned.                             |

Session-limit handling happens before selector and before active token issuance. If the active
session limit is full and no restricted session exists, sign-in stores a pending cycle credential
and redirects to the session-management gate. If a pending/restricted session already exists,
sign-in is rejected through the guardrail path.

`SignIn::SessionLimitManager` is the cycle-backed session-limit boundary. Legacy `SessionLimitGate`
session keys remain only as compatibility fallback for sign-in entry points that have not yet been
fully wired to DB-backed cycle locators.

## Signed-In Actor Re-entry

A signed-in actor must not start a new sign-in sequence without first signing out. Attempting to
enter sign-in while already signed in is an abnormal request.

The server must reject that request with a status code and a plain-text message. It must not
redirect to dashboard, continue a return path, start another sign-in sequence, or sign the actor out
on their behalf.

## Guardrail

Guardrail is the sign-in stop point for cases where the system must not continue toward selector or
issue a signed-in session. Examples include login cooldown, sign-in ban or suspension notices, and
hard session-limit rejections.

Guardrail is different from checkpoint:

- Guardrail happens during the sign-in process before selector and normal session issuance.
- Checkpoint happens before selector. The actor is identity-proofed but not signed in yet.

`/sign/in/guardrail` returns plain text. It must not redirect to welcome, checkpoint, or a return
path. Direct access without a valid in-sequence guardrail state is rejected with plain text instead
of being treated as a normal page view.

## Checkpoint

Checkpoint is the pre-activation interstitial for actionable notices or requirements. A DB-backed
sign-in cycle at `CHECKPOINT_PENDING` is the preferred authority. The legacy sign-in checkpoint
session carrier can still be read as compatibility fallback for flows that have not yet issued a
DB-backed cycle locator.

If the checkpoint stack has items, the actor is routed to the checkpoint page. If the checkpoint
stack is empty and the current state machine position is the checkpoint participant, the sequence
advances to the next step instead of returning an error.

## Selector

Selector is the activation boundary after checkpoint and before active session issuance. It
determines which region/persona/account binding becomes active for the session. Current app/com/org
flows have one activation candidate, so selector auto-commits through the same service path that
future manual selection must use.

No active token or active actor exists while the DB-backed sign-in cycle is at `SELECTOR_PENDING`.
Private routes must therefore fail as unauthenticated/forbidden rather than deriving access from the
pending cycle. Selector commit must be server-derived and row-locked. Client params are not
authoritative activation candidates. A stale, expired, mismatched, or already advanced cycle must
fail closed.

## Welcome And Dashboard

Welcome is available only after authentication. It follows selector-triggered session issuance in
the sign-in sequence.

Current sign routes expose these authenticated top-level routes:

- `GET /welcome`: post-auth sequence participant for `app`, `com`, and `org`.
- `GET /dashboard`: ordinary authenticated home for `app`, `com`, and `org`.

In `config/routes/sign.rb`, `welcome` belongs beside `dashboard` in every sign surface:

```ruby
root to: "roots#index"
resource :welcome, only: :show
resource :dashboard, only: :show
```

Only the welcome participant consumes the preserved `rt` return path. Ordinary dashboard access must
not treat a query parameter as a post-auth handoff.

If `/welcome` receives a safe `rt`, it consumes that return path and redirects there. If `rt` is
missing, blank, invalid, unsafe, expired, or points back to `/welcome`, the actor is redirected to
`/dashboard`. `/dashboard` is a normal authenticated landing page and can be opened directly or
refreshed repeatedly without consuming `rt`.

`/welcome` is not a permanent page. Before redirecting to `/welcome`, the server clears any previous
welcome gate for the surface and issues a new session gate with `remaining = 5`, `issued_at`, and
`expires_at`. Each `/welcome` request decrements `remaining`. When `remaining <= 0`, or when the
current time is at or after `expires_at`, the welcome gate is cleared and the actor is redirected to
`/dashboard`. The expiry is absolute and is not extended by refresh.

Guardrail, checkpoint, selector, and welcome are sequence participants whose content can grow or
disappear over time. The sequence should decide whether each participant has required content before
it routes the actor forward.

## Sequence Participants

Guardrail, checkpoint, selector, and welcome should be implemented as sequence participants, not as
fixed single-purpose pages. Each participant evaluates a list of requirement items for the current
actor, surface, and flow.

The participant contract is:

- `stack`: ordered requirement items that may be empty.
- `blocking?`: whether any stack item prevents advancing.
- `cleared?`: whether every required stack item has passed.
- `response`: the participant-specific rendering or stop behavior.
- `next`: the next sequence participant when all required items are cleared.

The all-pass rule is simple: the sequence advances only when the current participant's stack is
empty or every required stack item is cleared. Optional items can be displayed without blocking, but
blocking items must explicitly clear before the actor can advance.

Expected behavior by participant:

- Guardrail: if the stack is empty, advance without displaying a page. If the stack has any blocking
  item, render plain text and do not redirect or advance.
- Checkpoint: if the stack is empty, advance without displaying a page. If the stack has any
  blocking item, render the checkpoint and keep the actor at checkpoint until all blocking items
  clear.
- Selector: if exactly one server-derived candidate exists, auto-commit it and continue to welcome.
  Future multi-candidate selection must commit through the same selector service.
- Welcome: if the sequence welcome stack is empty, continue to the safe return path or dashboard. If
  the stack has items, display them within the welcome gate, but do not treat welcome as an
  incomplete login state.

Adding or removing a requirement must not require changing the route order. New behavior should be
added by registering a new item evaluator for the participant.

## Return Path

Return-path values are preserved only when they resolve to safe same-origin paths. Unsafe external
return targets are discarded before they are carried into guardrail, checkpoint, selector, or
welcome URLs. The return path never skips guardrail, checkpoint, selector, or welcome.

For DB-backed cycles, the return target is stored as cycle intent before `reset_session`; after
selector-triggered session issuance, welcome/final redirect revalidates that target against the
active actor, region, persona, and surface. Ordinary dashboard access must not consume `rt`.

## Relying-Party Entry

The acme and core relying-party surfaces expose one browser entry point for authentication:
`GET /sso/authorize`. Private RP endpoints use the same OIDC initiator when authentication is
required. The RP starts OIDC Authorization Code + PKCE from that route without a sign-up screen
hint. Sign-in and sign-up selection belongs to the IdP (`id.*`) sign surface.

RP entry redirects are sent through Jump with a signed `rt`; the OIDC `redirect_uri` remains an OIDC
protocol field inside the signed target URL only when it exactly matches the client registry. Do not
treat OIDC `state`, Jump `rt`, or the RP local post-auth path as interchangeable values.

The sign IdP exposes protocol endpoints under protocol namespaces:

- `GET /oauth/authorize`
- `POST /oauth/token`
- `GET /oauth/jwks`
- `GET /oidc/logout`

RP-initiated logout requests to `/oidc/logout` must include a short-lived signed `logout_request`
issued by the RP. The IdP does not accept `post_logout_redirect_uri`; logout completion stays on the
sign surface.
