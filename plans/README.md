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

- `adr/sign-residual-idp-surface-retirement.md` is the current operational decision for retiring
  residual Sign IdP surfaces while keeping the `id.*` credential-gateway host boundary.
- `plans/identity-authority-inversion-implementation.md` and
  `plans/active/identity-authority-inversion-first-slice.md` are superseded where they assign
  Identity, Refresh, Logout, Step-up freshness, Preference, or app social link/unlink authority to
  `sign/id`.
