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
5. Session issuance.
6. Checkpoint.
7. Dashboard.
8. Final return path or configuration page.

The DB-backed sign-in cycle uses these states for the authoritative lifecycle:

| State                      | Meaning                                                                         |
| -------------------------- | ------------------------------------------------------------------------------- |
| `PRIMARY_PENDING`          | Primary credential verification is in progress.                                 |
| `MFA_PENDING`              | Sign-in MFA must complete before the sequence can continue.                     |
| `SESSION_LIMIT_PENDING`    | Restricted session/session-limit handling must complete before normal issuance. |
| `GUARDRAIL_PENDING`        | Pre-issuance guardrail checks must stop or clear.                               |
| `SESSION_ISSUANCE_PENDING` | The sequence is authorized to issue the normal signed-in session.               |
| `CHECKPOINT_PENDING`       | Post-issuance checkpoint participants must stop or clear.                       |
| `DASHBOARD_PENDING`        | Dashboard sequence participant may render or advance.                           |
| `RETURN_PENDING`           | Safe return path or default destination is consumed.                            |
| `COMPLETED`                | The sign-in sequence has completed.                                             |
| `FAILED`                   | The sign-in sequence failed or was abandoned.                                   |

Session-limit handling can interrupt session issuance. If the active-session limit is full and no
restricted session exists, sign-in issues a restricted token and redirects to the session-management
gate. If a restricted session already exists, sign-in is rejected through the guardrail path.

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

Guardrail is the sign-in stop point for cases where the system must not issue a signed-in session.
Examples include login cooldown, sign-in ban or suspension notices, and hard session-limit
rejections.

Guardrail is different from checkpoint:

- Guardrail happens during the sign-in process before normal session issuance.
- Checkpoint happens after sign-in/session issuance, when the actor is allowed to continue but must
  pass interstitial content.

`/sign/in/guardrail` returns plain text. It must not redirect to dashboard, checkpoint, or a return
path. Direct access without a valid in-sequence guardrail state is rejected with plain text instead
of being treated as a normal page view.

## Checkpoint

Checkpoint is the post-login interstitial for actionable notices or requirements. A DB-backed
sign-in cycle at `CHECKPOINT_PENDING` is the preferred authority. The legacy sign-in checkpoint
session carrier can still be read as compatibility fallback for flows that have not yet issued a
DB-backed cycle locator.

If the checkpoint stack has items, the actor is routed to the checkpoint page. If the checkpoint
stack is empty and the current state machine position is the checkpoint participant, the sequence
advances to the next step instead of returning an error.

## Dashboard

Dashboard is available only after authentication. It follows checkpoint in the sign-in sequence.

Dashboard has two access modes:

- Ordinary dashboard access: a signed-in actor opens dashboard directly and sees the normal
  authenticated landing page.
- Sequence dashboard participant: the post-auth sequence reaches dashboard after guardrail, session
  issuance, and checkpoint handling.

Only the sequence dashboard participant consumes the preserved `rt` return path. Ordinary dashboard
access must not treat a query parameter as a post-auth handoff.

If the sequence dashboard stack is empty, the sequence can advance directly to the preserved return
path or the surface configuration page. If the stack has items, dashboard may display them, but
reaching dashboard means the actor has completed the normal `AAL1` sign-in boundary and may behave
as a signed-in actor.

Guardrail, checkpoint, and dashboard are sequence participants whose content can grow or disappear
over time. The sequence should decide whether each participant has required content before it routes
the actor forward.

## Sequence Participants

Guardrail, checkpoint, and dashboard should be implemented as sequence participants, not as fixed
single-purpose pages. Each participant evaluates a list of requirement items for the current actor,
surface, and flow.

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
- Dashboard: if the sequence dashboard stack is empty, continue to the safe return path or default
  destination. If the stack has items, display them, but do not treat dashboard as an incomplete
  login state.

Adding or removing a requirement must not require changing the route order. New behavior should be
added by registering a new item evaluator for the participant.

## Return Path

Return-path values are preserved only when they resolve to safe same-origin paths. Unsafe external
return targets are discarded before they are carried into guardrail, checkpoint, or dashboard URLs.
The return path never skips guardrail, checkpoint, or dashboard.

For DB-backed cycles, return consumption happens only at `RETURN_PENDING`. The return participant
clears the stored return path and completes the cycle. Ordinary dashboard access must not consume
`rt`.

## Relying-Party Entry

The apex relying-party surfaces (`www.*`) expose one browser entry point for authentication:
`GET /sso/authorize`. The RP starts OIDC Authorization Code + PKCE from that route without a sign-up
screen hint. Sign-in and sign-up selection belongs to the IdP (`id.*`) sign surface.

The sign IdP exposes protocol endpoints under protocol namespaces:

- `GET /oauth/authorize`
- `POST /oauth/token`
- `GET /oauth/jwks`
- `GET /oidc/logout`

RP-initiated logout requests to `/oidc/logout` must include a short-lived signed `logout_request`
issued by the RP. The IdP does not accept `post_logout_redirect_uri`; logout completion stays on the
sign surface.
