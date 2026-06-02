# Identity Authority Regression Checklist

## Purpose

Use this checklist when implementing or reviewing Identity Authority inversion work.

## Negative Checks

- `sign/id` does not issue, refresh, rotate, revoke, list, or display user sessions.
- `sign/id` does not issue access tokens, refresh tokens, downstream tokens, or step-up freshness.
- `sign/id` does not store `recent_auth`, `sudo`, `last_step_up_at`, or equivalent freshness.
- `sign/id` does not own preference writes, settings, dashboards, withdrawal, account lifecycle, or
  session-management UI.
- `/sign/out`, if retained, redirects to acme logout and does not mutate session/token state.
- `core` and `line` reject sign-issued session/access/downstream tokens.
- Social provider callbacks on `sign/id` return evidence only; acme owns account linking.
- WebAuthn/passkey ceremonies on `sign/id` return evidence only; acme owns session/account effects.
- Redirect targets and OAuth/OIDC `state` do not carry authentication result facts.
- Existing sign-side physical tables/models are not treated as sign-side authority.

## Positive Checks

- `acme/www` commits session, account, preference, token, authorization, and freshness state.
- Delegated ceremonies use acme-issued grants and signed sign-issued results.
- Ceremony results are short-lived, audience-bound, purpose-bound, one-shot, and transaction/session
  bound where applicable.
- Downstream services trust acme-issued downstream tokens only.
