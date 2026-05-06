# GH-645: Implement CSP Violation Reporting Endpoint

GitHub: #645

## Summary

Add a browser-facing endpoint for CSP violation reports. The public path should remain
`/csp-violation-report`. Phase 1 records reports as structured logs only. Phase 2 can add storage
and aggregation after the rollout boundary is clear.

## Scope

- Add `POST /csp-violation-report` endpoints for the 3 x 4 host/surface combinations used by the
  app.
- Keep URL naming explicit with `-` in the path and `_` in Ruby identifiers.
- Move shared parsing and logging into `CspViolationReport` concern.
- Record violation payloads with `Rails.event.record("security.csp_violation", ...)`.
- Reuse the existing rate-limit layer for abuse control.
- Return `204 No Content` after successful report handling.

## Phase 1

- Accept standard CSP report payloads.
- Normalize the report body in a concern.
- Log the violation as a structured security event.
- Keep storage disabled.

## Phase 2

- Add persistence or aggregation if security operations needs it.
- Define deduplication or sampling rules if report volume is high.
- Add alerting thresholds only after the storage path is fixed.

## Related

- GH-231: Configure CSP in Rails.
- ADR: `adr/csp-and-permissions-policy.md`

## Notes

- The previous placeholder approach used an underspecified reporting path. The final design should
  use the explicit `/csp-violation-report` path instead.
- Do not move this plan into `docs/`. It is future-facing work and belongs in `plans/backlog/`.
