# Notes

This directory holds non-authoritative notes that are useful for implementation handoff and later
promotion.

Write notes in English. Do not add Japanese or other non-English prose unless the note explicitly
covers localization, translation fixtures, or a quoted source whose original language matters.

Use it for:

- ADR-adjacent notes that are not accepted architecture decisions.
- Implementation notes that record decisions made while carrying out a plan.
- Handoff notes, gap notes, and follow-up observations that may later become `adr/`, `plans/`, or
  `docs/` material.
- Contradictions found between comments, code, tests, ADRs, docs, plans, or existing notes.
- Compatibility constraints, lifecycle constraints, security boundaries, and implementation caveats
  that future agents are likely to miss.

Do not use it for:

- Accepted architecture decisions; use `adr/`.
- Implementation plans or future work proposals; use `plans/`.
- Current stable product, architecture, or operations documentation; use `docs/`.
- Exploratory notes that do not affect implementation; use `memos/`.

Implementation notes belong under `notes/implementation/` and should record only durable context:

- decisions not written in the original spec or plan
- changes, compromises, or deferrals made during implementation
- comments, code paths, or tests checked for consistency
- contradictions or stale guidance found during implementation
- alternatives rejected and why
- constraints reviewers or future agents need to know
- follow-up items that should be promoted to `plans/`

When in doubt, prefer a short implementation note over losing context that affects future work. Keep
scratch investigation in `memos/`, then promote the implementation-relevant part into `notes/`
before finishing.

Do not record chain-of-thought, raw command history, secrets, tokens, cookies, authorization
headers, full request parameters, or other sensitive payloads.

If sensitive implementation context is needed during local work, do not commit it here. Keep it in
ephemeral working memory, write only a masked/redacted summary, or place local scratch material
under ignored `notes/local/`, `notes/private/`, or `notes/tmp/`.

Return-target note hygiene:

- `safe_path_from_encoded_rt` is deprecated. If this term appears while updating notes, do not treat
  it as current guidance; remove it or annotate it as stale compatibility that must be replaced with
  signed `ReturnTargetToken` handling.

When a note becomes stable or actionable, promote it:

- `adr/` for accepted decisions
- `plans/` for future work or implementation plans
- `docs/` for current behavior and operational documentation
