# Sign-In Sequence

This document records the current sign-in routing sequence after primary credential
verification.

## Sequence

Successful sign-in proceeds through these gates in order:

1. Primary credential verification.
2. MFA challenge when the actor requires MFA and the primary method does not bypass MFA.
3. Session issuance.
4. Checkpoint.
5. Dashboard.
6. Final return path or configuration page.

Session-limit handling can interrupt session issuance. If the active-session limit is full
and no restricted session exists, sign-in issues a restricted token and redirects to the
session-management gate. If a restricted session already exists, sign-in is rejected.

## Checkpoint

Checkpoint is the post-login interstitial for actionable notices or requirements. The
current implementation stores the state in the existing sign-in checkpoint session key and
can still read existing bulletin-backed notices.

If there is checkpoint content, the actor is routed to the checkpoint page. If there is no
checkpoint content, the checkpoint controller advances to the next sequence step instead of
returning an error.

## Dashboard

Dashboard is available only after authentication. It follows checkpoint in the sign-in
sequence.

Dashboard is also guarded by a sequence method. If a surface later has no dashboard content
to display, that method can advance directly to the preserved return path or the surface
configuration page.

## Return Path

Return-path values are preserved only when they resolve to safe same-origin paths. Unsafe
external return targets are discarded before they are carried into checkpoint or dashboard
URLs.
