# GH-579: Refactor Side-Effectful Concerns to Explicit Opt-In

GitHub: #579

## Summary

Refactor concerns that perform implicit work through `included do` blocks, automatic callbacks,
implicit exception handling, or hidden per-request side effects.

## Target Concerns

- `RateLimit`
- `MinimumResponseBudget`
- `Preference::Base` and related preference concerns
- `RestrictedSessionGuard`
- Concern-provided exception handling (authorization/social-auth handlers)
- Any concern where inclusion causes surprising callbacks or writes

## Goals

- Make controller behavior explicit.
- Reduce hidden request-time side effects.
- Prefer explicit activation, dedicated base classes, or clearly named opt-in APIs.
- Avoid concerns silently registering callbacks or rescue handlers unless the caller opts in.

## Acceptance Criteria

- Targeted concerns no longer surprise callers by auto-applying critical behavior on inclusion.
- Activation points are explicit in controllers/base classes.
- Request-time DB writes/cookie writes are reduced where they were previously implicit.
- Tests cover the intended activation behavior.
- The refactor does not regress the protected flows.

## Source

- `docs/todo/concern_side_effects_refactor.md`

## Implementation Status (2026-04-07)

**Status: COMPLETE**

All targeted concerns have been refactored to explicit opt-in:

- `RateLimit`: controllers explicitly call `rate_limit` DSL. Uses `has_custom_rate_limit!`.
- `MinimumResponseBudget`: controllers explicitly call `activate_minimum_response_budget`.
- `RestrictedSessionGuard`: documented as no automatic callbacks. Controllers call
  `before_action :enforce_restricted_session_guard!` explicitly.
- `Preference::Base`: no implicit `included do` blocks.

This issue can be closed.

## Improvement Points (2026-04-07 Review)

- Start with a concern activation inventory. The hard part is proving where implicit writes or
  cookie mutations still happen today.
- Add before/after controller integration tests around activation points so the refactor can remove
  side effects without silently dropping required setup.
