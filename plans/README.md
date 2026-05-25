# Plans

This directory stores future-facing material.

- `active/` holds current implementation work and near-term plans.
- `backlog/` holds proposals, ideas, and follow-up items that are not active yet.
- `archive/` holds older planning and work-log material kept for traceability.

Return-target rule:

- Do not introduce or preserve `safe_path_from_encoded_rt` in new plans. It is deprecated; if this
  term appears while updating a plan, replace the direction with signed `ReturnTargetToken`
  issuance/verification or explicitly schedule deletion of the stale helper use.
