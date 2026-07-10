---
title: Vendor Questions
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

Provide screening questions for SIer, security, and implementation vendors.

# Scope

These questions test whether a vendor understands the current identity boundary and review criteria.

# Non-scope

These are not interview scripts for end users.

# Source Evidence

- `docs/vendor/identity/00_readme.md`
- `docs/vendor/identity/02_responsibility-boundary.md`
- `docs/vendor/identity/03_route-endpoint-inventory.md`
- `docs/vendor/identity/04_cookie-session-token-matrix.md`
- `docs/vendor/identity/05_authentication-flow-inventory.md`
- `docs/vendor/identity/06_failure-taxonomy.md`
- `docs/vendor/identity/07_social-linking-policy.md`
- `docs/vendor/identity/08_threat-model.md`

# Current Decisions

- Questions should test Acme as sole IdP/AS.
- Questions should test Sign as RP gateway / ceremony UI.
- Questions should distinguish `/oauth/*`, `/oidc/*`, and `/social/*`.

## SIer Questions

| Question                                                              | Expected Strong Answer                                                                                            | Red Flag Answer                              | Why It Matters                                              |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ----------------------------------------------------------- |
| Who is the only Authorization Server in the current repository truth? | Acme.                                                                                                             | Sign or a shared RP surface.                 | Prevents authority drift.                                   |
| What does Sign own in the current model?                              | RP gateway and ceremony UI, not session/token authority.                                                          | Sign owns login authority or token issuance. | Prevents mixing UI hosting with authority.                  |
| How should `/oauth/*`, `/oidc/*`, and `/social/*` be interpreted?     | `/oauth/*` is Acme-only, `/oidc/*` is RP client flow, `/social/*` is social provider callback / ceremony surface. | They are interchangeable auth routes.        | Prevents route confusion and unsafe implementation changes. |
| What is the correct social linking key?                               | Provider + subject.                                                                                               | Email address.                               | Prevents takeover by email collision.                       |
| Can Sign automatically link accounts based on email match?            | No; explicit user-confirmed linking is required.                                                                  | Yes, if verified email matches.              | Prevents account takeover.                                  |

## Security Vendor Questions

| Question                                                     | Expected Strong Answer                                                           | Red Flag Answer                       | Why It Matters                |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------- | ------------------------------------- | ----------------------------- |
| What should happen when a failure state is ambiguous?        | Fail closed or require safe confirmation.                                        | Guess or continue with partial proof. | Prevents attacker advantage.  |
| Which layer owns durable session/token authority?            | Acme.                                                                            | The UI host that rendered the page.   | Prevents authority confusion. |
| How should token values be handled in logs?                  | Do not log raw values.                                                           | Log them for debugging.               | Prevents secret leakage.      |
| What is the response to replay of refresh or ceremony state? | Revoke, quarantine, or reissue according to policy, with durable audit evidence. | Ignore replay or just warn.           | Prevents silent compromise.   |
| What is the threat-model priority for social linking?        | Treat it as a takeover vector and require explicit confirmation.                 | Treat it as a convenience feature.    | Prevents account merge abuse. |

## OAuth/OIDC Specialist Questions

| Question                                          | Expected Strong Answer                                                  | Red Flag Answer                        | Why It Matters                                 |
| ------------------------------------------------- | ----------------------------------------------------------------------- | -------------------------------------- | ---------------------------------------------- |
| What does discovery evidence prove here?          | Only that protocol endpoints exist and resolve for the configured host. | That the UI host is the authority.     | Prevents overclaiming route presence.          |
| Why is RP callback distinct from social callback? | They validate different protocol boundaries and authorities.            | They are the same thing.               | Prevents mix-up and incorrect trust decisions. |
| What should happen on redirect URI abuse?         | Reject the request and restart from a safe entry point.                 | Accept if the user appears legitimate. | Prevents code exfiltration.                    |

## Operations/SRE Questions

| Question                                                         | Expected Strong Answer                                               | Red Flag Answer                  | Why It Matters            |
| ---------------------------------------------------------------- | -------------------------------------------------------------------- | -------------------------------- | ------------------------- |
| Where should identity security events be recorded?               | In durable audit/security records, not only application logs.        | Only in app logs.                | Preserves accountability. |
| What must happen on signing key compromise?                      | Rotate keys, reject impacted trust, and follow an incident playbook. | Wait for normal expiry.          | Limits blast radius.      |
| What does the package say about vendor docs and source evidence? | They must stay evidence-based and English-only.                      | They can be inferred informally. | Keeps handoff reviewable. |

## QA/Test Questions

| Question                                          | Expected Strong Answer                   | Red Flag Answer                      | Why It Matters             |
| ------------------------------------------------- | ---------------------------------------- | ------------------------------------ | -------------------------- |
| What proves route ownership?                      | Route files plus route contract tests.   | View rendering or manual navigation. | Prevents false confidence. |
| What should be reported when coverage is missing? | A gap, not a silent pass.                | Assume the behavior exists.          | Keeps reviews honest.      |
| What does the package require for failure states? | Explicit taxonomy and safe next actions. | Generic error pages only.            | Preserves user safety.     |

## Product/UX Questions

| Question                                               | Expected Strong Answer                                       | Red Flag Answer                                | Why It Matters                     |
| ------------------------------------------------------ | ------------------------------------------------------------ | ---------------------------------------------- | ---------------------------------- |
| How should legitimate users be treated on failure?     | Give safe next actions without leaking sensitive detail.     | Use a dead-end error screen.                   | Reduces abandonment and confusion. |
| How should internal and external UX differ?            | Internal control is strict; external UX remains lightweight. | Make everything equally verbose and technical. | Balances security and usability.   |
| What should happen on ambiguous social identity state? | Require confirmation or fail closed.                         | Auto-link to reduce friction.                  | Prevents takeover.                 |

# Open Questions

- Whether the vendor interview set should later be split by implementation phase.

# Related Documents

- `docs/vendor/identity/11_decision-register.md`
- `docs/vendor/identity/12_gap-risk-register.md`
