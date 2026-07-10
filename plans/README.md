# Plans

This directory stores future-facing material.

- Write plans in English. Do not add Japanese or other non-English prose unless the plan explicitly
  covers localization, translation fixtures, or a quoted source whose original language matters.
- `active/` holds current implementation work and near-term plans.
- `backlog/` holds proposals, ideas, and follow-up items that are not active yet.
- `archive/` holds older planning and work-log material kept for traceability.

Return-target rule:

- Do not introduce or preserve `safe_path_from_encoded_rt` in new plans. It is deprecated; if this
  term appears while updating a plan, replace the direction with signed `ReturnTargetToken`
  issuance/verification or explicitly schedule deletion of the stale helper use.

Current identity authority implementation plan:

- `plans/active/umaxica-v1-architecture-implementation-plan.md` sequences the Umaxica v1
  architecture implementation after the architecture lock and guard rails.
- `adr/acme-sign-core-base-port-boundary.md` is the current accepted boundary for Acme as the only
  IdP / Authorization Server, Sign as a special RP, Core as the Next.js web RP/BFF, Base as the
  Rails foundation/control-plane subdomain, and Palm as the native bearer-token API Resource Server
  formerly tracked as Port.
- `plans/active/acme-sign-core-base-port-implementation.md` tracks current implementation follow-up.
- `adr/sign-residual-idp-surface-retirement.md`,
  `plans/identity-authority-inversion-implementation.md`, and
  `plans/active/identity-authority-inversion-first-slice.md` are superseded where they conflict with
  the Acme / Sign / Core / Base / Palm boundary.
