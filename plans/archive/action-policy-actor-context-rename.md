# Action Policy actor context name retention (`:user`)

**Status:** Archived as not planned (verified 2026-05-19).

This is a decision record, not an implementation backlog item. The accepted direction is to keep the
Action Policy authorization context key as `:user`.

## Why

The actor rename `User(App) -> Client`, `Staff(Org) -> Operator`, `Customer(com) -> Visitor` is
complete at the runtime model/constant boundary (see `adr/app-actor-client-naming.md`,
`adr/org-actor-operator-naming.md`, `adr/com-actor-visitor-naming.md`). One runtime leftover remains
and is intentionally retained because the accepted Actor current-context ADR keeps the Action Policy
context key as `:user`:

The single Action Policy authorization context is still keyed `:user`:

- `app/policies/application_policy.rb:7` — `authorize :user, optional: true`
- `app/controllers/sign/app/application_controller.rb` — `authorize :user, through: :current_client`
- `app/controllers/sign/com/application_controller.rb` —
  `authorize :user, through: :current_visitor`
- `app/controllers/sign/org/application_controller.rb` —
  `authorize :user, through: :current_operator`
- `app/controllers/acme/app/application_controller.rb` — `authorize :user, through: :current_client`
- `app/controllers/acme/com/application_controller.rb` —
  `authorize :user, through: :current_visitor`
- `app/controllers/acme/org/application_controller.rb` —
  `authorize :user, through: :current_operator`

This is an Action Policy naming overlap, but the accepted direction is to keep the Action Policy
context key as `:user`. The context is **not** the app `Client`: it holds the cross-surface
authenticated actor (`Client | Operator | Visitor`) and is read as `user` throughout
`ApplicationPolicy`, `ClientPolicy`, `OperatorPolicy`, and `VisitorPolicy` (e.g.
`user.is_a?(Operator)`).

The application-facing request context remains `Actor`; the Action Policy context name remains
`:user`.

## Scope

- Do not rename the Action Policy context `:user` to `:actor`.
- Do not add a new backlog task for that rename without a new ADR or explicit user instruction.
- Continue routing request context through `Actor` outside the policy context boundary.
- Keep `user_*` storage models/columns and policy filenames governed by
  `adr/actor-db-naming-policy.md`.

## Related

- `adr/pundit-to-action-policy-migration.md`
- `adr/actor-current-facade.md`
- `adr/actor-db-naming-policy.md`

## Out of scope (already done 2026-05-17)

- Removed `current_user` / `authenticate_user!` compat shims from
  `app/controllers/sign/com/application_controller.rb`.
- Renamed `SocialAuthService` actor param/ivar to `current_client` / `@current_client` (later
  softened to accept both `current_client:`/`current_user:` for backward compatibility).
