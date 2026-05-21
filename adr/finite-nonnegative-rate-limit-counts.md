# Finite Non-Negative Rate Limit Counts

## Status

Accepted.

## Context

Credential abuse controls need to express counts for request rates, outbound delivery, credential
inventory, and long-running cumulative limits. Some rules are intentionally very loose, but using an
implicit "infinite" value would create ambiguous behavior across PostgreSQL, Ruby, JSON, cache
stores, documentation, and policy tables.

PostgreSQL `bigint` supports values up to `9,223,372,036,854,775,807`. The application should leave
implementation headroom instead of defining policy limits at the database maximum.

## Decision

All rate-limit, cumulative-limit, and credential-inventory counts are finite non-negative integers.

```text
0 <= count <= 1e18
```

In this ADR and related rate-limit policy documents, `1e18` is exact notation for:

```text
1,000,000,000,000,000,000
```

It is not a rounded physical quantity, floating-point value, or approximation. The upper bound is
the largest count value allowed by policy, not a synonym for infinity.

The same domain applies to configured limit values:

```text
0 <= limit <= 1e18
```

For checked windows in the same event / subject rule, limits must be monotonic across increasing
window sizes:

```text
1 sec <= 1 min <= 1 hour <= 1 day <= 1 week <= 1 month <= 1 year <= all time
```

`-` cells are skipped for this comparison because they mean the window is not checked.

`nil`, negative numbers, floating-point values, decimal values, and sentinel values such as `-1`
must not be used to represent a count or a count limit.

Policy tables may use `-` in a limit cell to mean "no check for this window". `-` is documentation
syntax and configuration syntax for rule absence; it is not a count value and must not be persisted
as a counter.

Application enforcement code must not branch directly on raw `-` values. Raw policy input must be
normalized once at the policy-loading boundary. After normalization, evaluators receive either a
finite non-negative integer limit or no rule for that window.

## Consequences

- Policy tables can use one numeric domain for short-window rates, long-window cumulative counts,
  and all-time inventory caps.
- "Unbounded" is not part of the count model. A very loose checked rule must still use a finite
  limit no greater than `1e18`.
- `-` means the rule is not checked for that window. Implementations should normalize `-` into rule
  absence before evaluating limits, so controllers and callers do not need per-window branching.
- Controllers, services, and evaluators must not contain checks such as `value == "-"`,
  `value.nil?`, or `value.blank?` to decide whether a limit applies. Applicability is determined by
  the normalized policy rule set.
- PostgreSQL columns storing durable counters should use `bigint` and validate the same domain at
  the model or service boundary.
- JSON clients can lose precision for very large integers, so external APIs should avoid exposing
  these internal count values unless a representation contract is defined.
- `limit = 0` means the operation is blocked for that rule.
- A longer checked window must not have a lower limit than a shorter checked window for the same
  event and subject. Otherwise, the policy is internally conflicting.
- `count < limit` is the ordinary allow check for a limit that counts events before allowing the
  next event. Implementations must document if they intentionally use a different comparison order.

## Related

- `docs/security/credential-abuse-rate-limits.md`
- `plans/backlog/credential-abuse-rate-limit-policy.md`
