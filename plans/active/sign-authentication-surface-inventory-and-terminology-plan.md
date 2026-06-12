# Sign Authentication Surface Inventory And Terminology Plan

> **Supersession (2026-06-12):** Use `adr/acme-sign-core-base-port-boundary.md` for the target
> component model. Sign is a special RP, not an IdP, token issuer, or credential-gateway authority.
> This plan remains historical inventory where it describes current Rails sign-in/sign-up code.

> **Updated by the current Identity Authority boundary:** `sign/id` owns Identity, Credential,
> Refresh, Logout, Step-up, browser/request Preference, and app social link/unlink authority.
> `acme/www` owns Account, Organization, Avatar, Selector, Dashboard, RP Authorization, and SNS-body
> authority. Do not use older wording in this plan to restore the Acme aggregation model.

## Status

Active. This plan records the post-cleanup sign-in/sign-up inventory and terminology alignment for
`app`, `com`, and `org`. It is intentionally documentation and test focused; it does not authorize
large authentication implementation changes.

## Production Target

| Surface | Sign-up term                                   | Sign-in term                    | Social login target                                    | Local sign-in target                                                   |
| ------- | ---------------------------------------------- | ------------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------- |
| `app`   | User/client registration                       | Client authentication           | Existing Google and Apple social login remain in scope | Email OTP, passkey, passcode/secret credential, TOTP where implemented |
| `com`   | Public/corporate visitor entry or inquiry flow | Visitor/corporate session entry | Unsupported                                            | Email OTP, passkey, passcode/secret credential                         |
| `org`   | Operator acquisition / staff onboarding        | Operator authentication         | Unsupported                                            | Passkey and passcode/secret credential in the current implementation   |

Org TOTP is not an implemented production sign-in method in the current route/controller/view/test
inventory. Treat it as a gap or future plan until explicit org TOTP routes, controllers, views, and
tests exist.

## Inventory

| Surface       | Actor/resource                                         | Identifier                                                                           | Credential factor                                                                                             | Challenge                                                  | Verification                                                        | Session/token                                                           | Chronicle/audit                        | Route/controller/view/test evidence                                                                                  |
| ------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `app` sign-up | `Client`, contact identifiers, social identities       | Email, telephone, Google provider assertion, Apple provider assertion                | Email/telephone OTP plus checkpoint birthdate, passkey, passcode; social identity binding for app providers   | Sign-up checkpoint; app provider callback state validation | Contact OTP and checkpoint completion                               | App sign-in sequence handoff and `ClientToken` issuance after selector  | Client sign-up chronicle/audit events  | `config/routes/sign.rb` app `sign/up`, `social`, `auth`; `app/controllers/sign/app/up/**`; app social callback tests |
| `app` sign-in | `Client`, client credentials                           | Email, passkey credential ID, secret credential input, app social provider assertion | Email OTP, passkey, passcode/secret credential, Google social, Apple social, TOTP challenge where implemented | Passkey and TOTP sign-in MFA challenge routes              | Passkey, TOTP, and scoped email OTP verification routes             | `ClientToken` and app sign-in cycle/session carriers                    | Client chronicle/audit events          | `config/routes/sign.rb` app `sign/in`, `social`, `auth`, `verification`; app sign-in/social tests                    |
| `com` sign-up | `Visitor`, visitor contact identifiers                 | Email, telephone                                                                     | Email/telephone OTP plus checkpoint birthdate, passkey, passcode                                              | Sign-up checkpoint                                         | Contact OTP and checkpoint completion                               | Com sign-in sequence handoff and `VisitorToken` issuance after selector | Visitor sign-up chronicle/audit events | `config/routes/sign.rb` com `sign/up`; `app/controllers/sign/com/up/**`; com sign-up/no-social tests                 |
| `com` sign-in | `Visitor`, visitor credentials                         | Email, passkey credential ID, secret credential input                                | Email OTP, passkey, passcode/secret credential                                                                | Passkey sign-in MFA challenge route                        | Passkey and scoped email OTP verification routes                    | `VisitorToken` and com sign-in cycle/session carriers                   | Visitor chronicle/audit events         | `config/routes/sign.rb` com `sign/in`, `verification`; com sign-in/no-social tests                                   |
| `org` sign-up | `Operator`, invitation and lifecycle request resources | Invitation token or lifecycle request context                                        | Local staff onboarding credentials where implemented                                                          | No public social sign-up challenge                         | Invitation/lifecycle approval and local credential setup boundaries | Operator session only after org sign-in                                 | Operator chronicle/audit events        | `config/routes/sign.rb` org `sign/up/invitations` and settings lifecycle routes; org onboarding tests                |
| `org` sign-in | `Operator`, operator credentials                       | Passkey credential ID or secret credential input                                     | Passkey, passcode/secret credential                                                                           | Passkey sign-in MFA challenge route                        | Passkey verification route                                          | `OperatorToken` and org sign-in cycle/session carriers                  | Operator chronicle/audit events        | `config/routes/sign.rb` org `sign/in`, `verification`; org sign-in/no-social tests                                   |

## Terminology

| Concept                                  | Term                                           |
| ---------------------------------------- | ---------------------------------------------- |
| `app` sign-up                            | User/client registration                       |
| `app` sign-in                            | Client authentication                          |
| `com` sign-up                            | Public/corporate visitor entry or inquiry flow |
| `com` sign-in                            | Visitor/corporate session entry                |
| `org` sign-up                            | Operator acquisition / staff onboarding        |
| `org` sign-in                            | Operator authentication                        |
| Additional authentication during sign-in | Challenge                                      |
| Sensitive-action proof after sign-in     | Verification                                   |
| `org`/`com` social provider              | Unsupported and not a production target        |

## Static Invariants

- `app` keeps the existing Google and Apple social login routes, provider registration, views, and
  tests.
- `com` and `org` have no social provider callback routes and no social login buttons.
- `SocialIdentifiable` maps only the app provider scope.
- Legacy org/com Google gateway flags, provider IDs, runtime code, and retirement tags must remain
  absent.
- Microsoft provider normalization must not be added.

## Gaps

- Org TOTP sign-in is documentation/planning only until a future slice adds the actual route,
  controller, view, model/service wiring, and tests.
- Org account linking/unlinking for social providers is outside the production target and should
  remain unavailable.
