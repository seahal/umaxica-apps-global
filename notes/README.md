# Notes

This directory holds non-authoritative notes that are useful for implementation handoff and later
promotion.

Use it for:

- ADR-adjacent notes that are not accepted architecture decisions.
- Implementation notes that record decisions made while carrying out a plan.
- Handoff notes, gap notes, and follow-up observations that may later become `adr/`, `plans/`, or
  `docs/` material.

Do not use it for:

- Accepted architecture decisions; use `adr/`.
- Implementation plans or future work proposals; use `plans/`.
- Current stable product, architecture, or operations documentation; use `docs/`.
- Exploratory notes that do not affect implementation; use `memos/`.

Implementation notes belong under `notes/implementation/` and should record only durable context:

- decisions not written in the original spec or plan
- changes, compromises, or deferrals made during implementation
- alternatives rejected and why
- constraints reviewers or future agents need to know
- follow-up items that should be promoted to `plans/`

Do not record chain-of-thought, raw command history, secrets, tokens, cookies, authorization
headers, full request parameters, or other sensitive payloads.

When a note becomes stable or actionable, promote it:

- `adr/` for accepted decisions
- `plans/` for future work or implementation plans
- `docs/` for current behavior and operational documentation
