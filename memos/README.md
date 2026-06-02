# Memos

This directory holds exploratory notes, rough analysis, and provisional observations that do not
affect implementation.

Write memos in English. Do not add Japanese or other non-English prose unless the memo explicitly
covers localization, translation fixtures, or a quoted source whose original language matters.

Use it for material that is useful to keep around but is not yet stable enough for:

- `docs/` for current, stable documentation
- `plans/` for active work, proposals, and backlog items
- `adr/` for accepted architectural decisions
- `notes/` for ADR-adjacent notes and implementation handoff notes

Guidelines:

- Keep notes lightweight and readable.
- Prefer direct observations over polished narratives.
- Promote content out of `memos/` once it becomes stable or actionable.
- Do not treat files here as source of truth.
- Do not commit secrets, tokens, cookies, authorization headers, full request parameters, private
  keys, real credentials, or sensitive local environment details. Keep sensitive scratch context in
  ephemeral working memory, write only masked/redacted summaries, or use ignored `memos/local/`,
  `memos/private/`, or `memos/tmp/`.
