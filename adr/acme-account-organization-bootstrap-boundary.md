# Acme Account / Organization Bootstrap Boundary

Status: accepted

## Context

Acme is the identity and account-control plane for Project Umaxica. It owns identity,
preference, account, organization, and avatar infrastructure, but it does not own SNS product
domain behavior such as feeds, posts, follows, blocks, or mutes.

The repository currently models account and organization behavior with a mix of concrete surface
models and existing bootstrap code. That code already provisions the initial Acme graph during sign
up, but the current implementation shape is not yet aligned with the intended long-term model where
an Identity can support multiple Accounts and every Account belongs to an Organization.

Preference authority may also be in conflict with older ADRs. That conflict is out of scope for
this decision and must be updated in a separate ADR.

## Decision

1. Acme owns the Account and Organization control plane.
2. Identity is the login principal and login-scoped configuration boundary.
3. Account is the user-facing operating subject associated with an Identity.
4. Organization is the membership container or collective that every Account must belong to.
5. Sign up bootstrap must create exactly one initial Account and exactly one initial
   natural-person Organization atomically, together with the membership/link records required to
   connect them.
6. Identity-only, Account-only, or dangling membership states are not the intended steady state
   for the bootstrap path.
7. Acme handles app, org, and com surfaces together for this model. Surface-specific behavior must
   remain explicit.
8. Enterprise, Bureau, and Company are concrete models, not STI variants.
9. `kind` or `type` enums are not used to represent surface or organization class.
10. Public lookup is supported through `public_id`, but Rails routes do not use
    `param: :public_id`.
11. Controllers resolve `params[:id]` as the public identifier.
12. `to_param` should return `public_id` for the public lookup models.
13. Account and Organization should both move toward a `title` attribute as the initial short
    name.
14. Account title validation and Organization title validation must stay separate, even if they
    temporarily share the same character and length constraints.
15. Initial quota targets are 10 Accounts per Identity and 2 Organizations per Identity, but quota
    enforcement must live in policy, quota, or service layers rather than model validations.
16. OrganizationUnit is not part of this decision and must remain untouched for now.
17. Existing bootstrap structure, including `AcmeSelectorBootstrapAuthority`, remains the source of
    truth for current provisioning behavior until a later implementation PR changes it.
18. Preference authority changes remain a separate ADR topic if current documentation conflicts with
    the intended Acme RW / other-surface RO boundary.

## Consequences

- Sign up can be documented as a single atomic bootstrap that produces a usable initial identity
  graph.
- Future work can move from the current 1:1 account binding shape toward the intended 1:n model
  without pretending the current implementation already matches it.
- Routes and controllers can continue using Rails standard plural resources and `params[:id]`
  resolution.
- `title` can be introduced additively before any later rename or cleanup of older fields.
- Quota enforcement stays out of model validation, which keeps future overrides and policy changes
  flexible.

## Alternatives Considered

- Keep Account 1:1 with Identity permanently. Rejected because it conflicts with the intended
  product direction.
- Use STI or `kind` / `type` enums for organization surfaces. Rejected because the three surfaces
  are intended to remain concrete and independently evolvable.
- Use `param: :public_id` in routes. Rejected because standard Rails routes with `params[:id]`
  already fit the intended lookup pattern.
- Share one validation and constant set for Account title and Organization title. Rejected because
  future divergence is expected and we want the validation paths to evolve independently.
- Make OrganizationUnit part of this bootstrap decision. Rejected because Unit is a separate
  long-term design topic.

## Follow-up Tasks

- Document the current repository state and the near-term PR split in a plan and memo.
- Add the additive `title` migration and bootstrap updates in a later implementation PR.
- Add quota policy/service enforcement in a later implementation PR.
- Reconcile preference authority with the older ADRs in a separate ADR.
- Revisit the current 1:1 account binding shape before any migration that introduces 1:n.
