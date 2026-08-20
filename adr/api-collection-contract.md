# API Collection Contract: Envelope and Cursor Pagination

**Status:** Accepted (2026-08-16)

> This ADR records a target contract and the compatibility work required to reach it. It changes no
> controller, serializer, or route. Implementation is deferred to separately reviewed work, because
> the change is externally breaking — see [Migration constraint](#migration-constraint).

## Status

Accepted (2026-08-16).

**No standard governs this area.** HTTP defines no pagination mechanism and no response-envelope
convention. This record therefore states a repository decision and names the de facto practice it
follows, rather than citing a specification. It is kept out of
`docs/reference/api-design-standards.md` for exactly that reason.

## Context

Collection endpoints today return every matching row with no bound. `render_publishing_entries_index`
(`app/controllers/concerns/publishing_content_rendering.rb:13-14`) renders
`{"entries": [...]}` from `publishing_entries_query.call.filter_map { … }` — the complete set of
published entries for the edition, with no limit, no cursor, and no `Link` header. The response grows
without bound as content is published.

Envelope keys are chosen per endpoint with no shared convention. Observed:
`{"entries": [...]}` and `{"entry": {...}}` (`publishing_content_rendering.rb:14,21`),
`{"refreshed": true}` (`app/controllers/concerns/core_browser_api_boundary.rb:135`),
`{"authenticated", "csrf_token", "actor"}` (`app/controllers/core/app/api/v0/sessions_controller.rb:15-21`).

Two options were considered:

- **Offset pagination** (`?page=&per_page=`). Simple and familiar, but it skips and duplicates rows
  when the underlying set changes between requests, and its cost grows with depth because the
  database must still traverse the skipped rows. Rejected.
- **Cursor pagination**, as implemented by GitHub and Stripe. Stable under concurrent writes and
  constant-cost at any depth, at the price of losing random access to an arbitrary page. Accepted;
  the content endpoints here are read-forward feeds, not random-access tables.

## Decision

**Every collection endpoint is paginated. An unbounded collection response is a defect.** The page
size is a server-side guarantee, not a client courtesy — a client that omits `limit` must still
receive a bounded response.

Request parameters: `?limit=<1..100>&cursor=<opaque>`. `limit` defaults to 20. A `limit` above the
maximum is clamped, not rejected, so a client cannot turn a tuning mistake into an error.

Response envelope:

```json
{
  "data": [ … ],
  "page": { "next_cursor": "…", "has_more": true }
}
```

- `has_more` is authoritative. `next_cursor` is `null` when `has_more` is `false`.
- **The cursor is opaque.** It is never a raw offset, a primary key, or any value a client can
  construct or interpret. Because it is opaque, its encoding may change without a version bump; that
  is the point of making it opaque.
- Single-resource responses return the resource object at the top level, with no wrapper key.

Offset pagination must not be added to any public collection.

## Migration constraint

This contract cannot be applied to the existing entries API without an externally coordinated
breaking change.

- `test/contracts/publishing_entry_api_contract_test.rb:29` asserts
  `assert_equal ENTRY_KEYS, entry.keys` — an exact key-set match. The file's opening comment states it
  "Pins the public read contract consumed by the edge applications", and that adding, removing, or
  retyping a field there is a deliberate API change.
- Those edge applications live outside this repository
  (`docs/operations/core-nextjs-zero-cookie-edge-contract.md`). No code under `src/` consumes the
  entries API.

Consequently:

1. Changing `{"entries": [...]}` to `{"data": [...], "page": {...}}` requires `Deprecation` and
   `Sunset` headers and an announced window, per `docs/reference/api-design-standards.md`. Neither
   header is implemented anywhere in the repository today.
2. Introducing a default `limit` is itself breaking for any consumer that currently relies on
   receiving the complete set in one response. It cannot be shipped as a silent change.
3. The contract test is the coordination point: it must be updated in the same change that ships the
   new shape, never loosened in advance to make room for it.

Conditional-request support (`ETag` / `Last-Modified` / `304`) for these endpoints is separate from
pagination and is not blocked by it; it is governed by `docs/reference/api-design-standards.md` and
adds no breaking change.

## Scope

- The success-response envelope for collections and single resources.
- The pagination mechanism, its parameters, defaults, and bounds.
- The requirement that the cursor be opaque.

## Non-scope

- Error responses — `adr/api-error-format-problem-details.md`.
- Caching and conditional requests — governed by RFC 9110 and recorded in
  `docs/reference/api-design-standards.md`.
- Any implementation in this change. No controller, serializer, query, or test is modified by
  recording this decision.
- Sorting and filtering parameters, which are not decided here.

## Consequences

- Collection responses gain a bound, removing an unbounded-growth path in both response size and
  database work.
- One envelope convention replaces per-endpoint key invention, so a client can process any collection
  without per-endpoint code.
- The entries API migration is externally breaking and cannot proceed until the edge applications are
  coordinated and a sunset window has elapsed. Recording this decision does not authorize that
  change.
- Losing random access to page N is accepted. If a future endpoint genuinely needs it, that endpoint
  requires its own decision rather than a quiet exception here.
