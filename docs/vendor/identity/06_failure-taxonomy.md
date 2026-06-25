---
title: Failure Taxonomy
status: draft
audience:
  - SIer
  - security-vendor
  - internal-architecture
  - implementation-team
owner: TBD
last-reviewed: TBD
source-of-truth: current-repository-evidence
confidentiality: internal-vendor-shareable
---

# Purpose

Define the shared failure, dropout, retry, and timeout vocabulary.

# Scope

This taxonomy applies to identity ceremonies and related failure surfaces.

# Non-scope

It does not replace flow-specific error handling.

# Source Evidence

- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/logout-sequence.md`
- `docs/security/turnstile.md`
- `docs/security/refresh-token-rotation.md`
- `docs/security/session-token-authority.md`
- `docs/security/observability-boundary.md`

# Current Decisions

- Internal control is strict.
- External UX is lightweight.
- Legitimate users should receive safe next actions.
- Attackers must not receive useful information.
- Failure screens must avoid both dead ends and information leakage.

| State                 | Meaning                                                       | User-Facing Principle                                 | Security Principle                                       | Allowed Next Actions                                  | Forbidden Next Actions                                      | Evidence / Applies To                             |
| --------------------- | ------------------------------------------------------------- | ----------------------------------------------------- | -------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------- |
| started               | Flow has begun but no irreversible action has been taken.     | Show the next safe step.                              | Do not commit authority state yet.                       | Continue, cancel, timeout.                            | Commit authority state.                                     | All ceremony flows.                               |
| challenge_issued      | A one-time challenge or provider round trip has been created. | Explain the next challenge step.                      | Bind to the current flow and user agent context.         | Respond to challenge, cancel, timeout.                | Reuse challenge as authority.                               | OTP, passkey, social, OIDC.                       |
| challenge_verified    | Challenge or provider response has been accepted.             | Advance without exposing secrets.                     | Still do not assume durable authority until commit.      | Continue to commit or next step.                      | Replay the challenge as if fresh.                           | OTP, passkey, social, OIDC.                       |
| completed             | Flow ended successfully.                                      | Show a clear success or next navigation.              | Authority state should already be committed.             | Exit, revisit safe completion page.                   | Re-open the same one-shot result as fresh evidence.         | Sign-in, sign-up, logout, revocation.             |
| cancelled             | User intentionally stopped the flow.                          | Provide a safe restart point.                         | Cancel must not leak whether a secret was correct.       | Restart from safe entry, abandon.                     | Resume from a stale middle step as if nothing happened.     | Sign-in, sign-up, logout, verification.           |
| expired               | Flow lifetime ended.                                          | Tell the user the flow ended and offer restart.       | Do not keep old challenges valid.                        | Restart from safe entry.                              | Continue with stale state.                                  | OTP, passkey, social, OIDC, logout.               |
| timed_out             | No timely response was received.                              | Explain timeout without giving attacker help.         | Timeout should clear or quarantine flow state.           | Restart, reissue challenge if policy allows.          | Treat stale state as fresh.                                 | OTP, passkey, social, refresh.                    |
| retryable_failure     | A correctable failure occurred.                               | Give a safe retry path.                               | Failure should not reveal secret validity beyond policy. | Retry, restart, cancel.                               | Escalate to success without new proof.                      | OTP, passkey, social, Turnstile.                  |
| non_retryable_failure | The flow cannot continue safely.                              | Give a safe exit or support path.                     | Fail closed.                                             | Restart from a new entry, contact support if allowed. | Retry the same compromised state.                           | Mix-up, protocol mismatch, policy block.          |
| locked                | Too many failures or a policy lock is active.                 | Explain that the user must wait or use another path.  | Lockout should slow abuse.                               | Wait, alternate factor if allowed, support path.      | Unlimited brute force.                                      | OTP, credential abuse, session limit.             |
| forbidden             | Caller is not permitted to proceed.                           | State that the action is not available.               | Do not disclose why a protected resource exists.         | Use authorized path, sign in, seek support.           | Bypass authorization or enumerate.                          | Settings, revocation, social linking.             |
| limited               | Rate, session, or capacity guard triggered.                   | Explain there is a limit and give the next safe step. | Keep the limit enforceable.                              | Wait, retry within policy, alternate path.            | Flood the same endpoint.                                    | Session limit, OTP resend, Turnstile.             |
| recovered             | The flow resumed after a recoverable interruption.            | Continue from the latest safe point.                  | Recover only from preserved safe state.                  | Continue or restart per policy.                       | Restore stale sensitive state that should have been purged. | Sign-up checkpoint recovery, transparent refresh. |
| abandoned             | The user left without completing the flow.                    | Let the user start again later.                       | Unfinished state should age out.                         | Restart from safe entry.                              | Keep abandoned sensitive state forever.                     | Sign-up cancellation, logout abandonment.         |
| cleaned_up            | Temporary state has been purged.                              | Do not show stale state as current.                   | Remove residual challenge material.                      | Start a new flow.                                     | Rehydrate deleted challenge state.                          | Ceremony state purges.                            |

## Ceremony Mapping

| Ceremony                        | Applicable States                                                                                                                                                                               | Required Recovery Path                                      | Notes                                                                                                              |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Sign in                         | started, challenge_issued, challenge_verified, completed, cancelled, expired, timed_out, retryable_failure, non_retryable_failure, locked, forbidden, limited, recovered, abandoned, cleaned_up | Restart from `/sign/in` or the appropriate credential step. | Failure copy should not reveal whether the account exists or which credential was wrong beyond the current policy. |
| Sign up                         | started, challenge_issued, challenge_verified, completed, cancelled, expired, timed_out, retryable_failure, non_retryable_failure, locked, forbidden, limited, recovered, abandoned, cleaned_up | Restart from `/sign/up` or the appropriate checkpoint.      | Cancelled or abandoned artifacts should be cleaned up.                                                             |
| Sign out / logout               | started, completed, cancelled, expired, timed_out, retryable_failure, non_retryable_failure, forbidden, recovered, cleaned_up                                                                   | Return to completion or restart the logout ceremony.        | Unauthenticated logout entry is intentional.                                                                       |
| OIDC authorize/callback         | started, challenge_issued, challenge_verified, completed, cancelled, expired, timed_out, retryable_failure, non_retryable_failure, forbidden, recovered, cleaned_up                             | Start a new authorization request.                          | RP callback is not social provider callback.                                                                       |
| Social sign in / sign up        | started, challenge_issued, challenge_verified, completed, cancelled, expired, timed_out, retryable_failure, non_retryable_failure, forbidden, limited, recovered, abandoned, cleaned_up         | Restart from the social entry route.                        | Explicit linking policy must still hold.                                                                           |
| OTP                             | started, challenge_issued, challenge_verified, completed, cancelled, expired, timed_out, retryable_failure, non_retryable_failure, locked, limited, recovered, abandoned, cleaned_up            | Restart challenge issuance or go back to safe entry.        | OTP must not leak secret validity by error class.                                                                  |
| Passkey/WebAuthn                | started, challenge_issued, challenge_verified, completed, cancelled, expired, timed_out, retryable_failure, non_retryable_failure, forbidden, recovered, cleaned_up                             | Reissue challenge or restart flow.                          | Challenge replay must fail closed.                                                                                 |
| Session revocation / limitation | started, completed, cancelled, expired, timed_out, retryable_failure, non_retryable_failure, locked, forbidden, limited, recovered, cleaned_up                                                  | Return to session UI or start a new management action.      | Revocation authority remains Acme.                                                                                 |

# Open Questions

- Whether additional states are needed for provider-specific callback failures.

# Related Documents

- `docs/vendor/identity/05_authentication-flow-inventory.md`
- `docs/vendor/identity/08_threat-model.md`
