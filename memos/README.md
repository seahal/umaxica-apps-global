# Memos

This directory holds exploratory field notes, rough analysis, and provisional observations that do
not yet belong in implementation handoff, stable docs, an ADR, or a plan.

Write memos in English. Do not add Japanese or other non-English prose unless the memo explicitly
covers localization, translation fixtures, or a quoted source whose original language matters.

Use it for material that is useful for a future Codex or Claude Code agent to rediscover quickly but
is not yet stable enough for:

- `docs/` for current, stable documentation
- `plans/` for active work, proposals, and backlog items
- `adr/` for accepted architectural decisions
- `notes/` for ADR-adjacent notes and implementation handoff notes

Guidelines:

- Keep notes lightweight and readable.
- Prefer direct observations over polished narratives.
- Create a memo when an investigation, audit, plan, failed approach, surprising repository behavior,
  or unresolved question would otherwise need to be rediscovered.
- Name files `YYYY-MM-DD-<agent>-<short-slug>.md`, where `<agent>` is `codex`, `claude`, or `agent`
  if the authoring tool is unknown.
- Prefer these short sections: `Context`, `Observed`, `Why It Matters`, `Open Questions`, and
  `Promotion Candidate`.
- Promote content out of `memos/` once it becomes stable or actionable.
- Do not treat files here as source of truth.
- Do not record chain-of-thought, transcripts, raw command logs, secrets, or full request payloads.
- Do not commit secrets, tokens, cookies, authorization headers, full request parameters, private
  keys, real credentials, or sensitive local environment details. Keep sensitive scratch context in
  ephemeral working memory, write only masked/redacted summaries, or use ignored `memos/local/`,
  `memos/private/`, or `memos/tmp/`.
