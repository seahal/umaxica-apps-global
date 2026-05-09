# Feature Notes

## Status

Resolved (2026-05-07). Archived as the open question recorded below has been settled by
implementation.

> **Resolution notes (2026-05-07):**
>
> - `customer` is treated as a **peer authenticated subject**, not a subordinate inquiry-only
>   subject. The shared `CurrentActor` concern (`app/models/concerns/current_actor.rb`) enumerates
>   the authenticated actor types as `:user`, `:staff`, `:customer` — all three at the same level,
>   with `authenticated?` returning true for any of them.
> - Customer-side auth models are at parity with user/staff: `customer_passkey`, `customer_email`,
>   `customer_telephone`, `customer_token`, `customer_token_kind`, `customer_token_status`, and
>   related status / binding-method tables exist under `app/models/`.
> - Recent ADRs treat `customer` as an actor by default — `adr/jumper-current-boundary.md`,
>   `adr/oidc-claims-decision.md`, `adr/preference-soft-bubble-doctrine.md` (which assigns the `com`
>   TLD bubble specifically to the customer surface).
> - The "keep customer auth integration to a minimum" guidance is therefore obsolete; passkey and
>   token-binding integration has already shipped on the customer side.
>
> The original note (preserved below) is kept for historical context only.

## Customer / Identity

- How much `customer` should be included in the `Identity` contract is still under discussion.
- At present, it can share the same `status_id` and `withdrawable` concepts as `user` and `staff`.
- However, whether `customer` should be treated as a peer auth subject or as a subordinate
  inquiry-only subject is still undecided.
- Until that is settled, keep `customer` auth integration to a minimum.
