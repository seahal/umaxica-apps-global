# Account / Workspace / Avatar / Billing (current notes)

This document summarizes the currently organized relationship between the authentication subject
(Account), tenant (Workspace), posting subject (Avatar), and future Billing (Stripe) in a form that
is easy to implement.

## Terms (assumptions)

- `Session`: Login state maintained through browser cookies (who is logged in)
- `Account`: The subject of authentication and authorization (a person). In this repository, this
  corresponds to `User` / `Staff` (the `Account` concern is included)
- `Workspace` (= corporate container): The place where organizations, contracts, and assets are
  managed (formerly `Organization`)
- `Membership`: The relationship between an Account and a Workspace (role/state/employment status,
  etc.)
- `Avatar`: The posting subject (similar to a poster/screen name on X). In a company setting, this
  can be an asset operated by multiple people
- `AvatarGrant` (or `AvatarAccess`): Permission granted by a Membership to operate an Avatar

## Why separate them (the problem we want to solve)

- Personal use may seem simple, but enterprise use requires multiple people to operate one Avatar,
  prevent former employees from accessing it, and preserve the Avatar asset even when ownership
  changes.
- For that reason, we separate the “person” (Account) from the “posting subject” (Avatar), and
  connect them through “membership” and “permissions.”

## Minimum recommended structure

Personal use (an extension of the world where S-A-M-A are connected by lines):

```text
Session -> Account -> Membership -> Workspace
                         |
                         v
                    AvatarGrant -> Avatar
```

Key points:

- `Session` refers to the logged-in Account (for example, `current_account`)
- `Membership` represents an Account's role inside the organization (role/state/employment status)
- `Avatar` should generally be treated as a Workspace asset, and `AvatarGrant` distributes operating
  permissions

## Current implementation approach (represent Account membership with `Membership`)

At present, the first step is to make it clear which Workspace a User belongs to, so we introduce
`user_memberships` instead of `user_organizations` to represent this. Staff is out of scope for now.

- Add: `UserMembership` (`app/models/user_membership.rb`)
- Add: `user_memberships` table (`db/identities_migrate/20251218150000_create_user_memberships.rb`)
  - Make `user_id` + `workspace_id` unique
  - Use `joined_at` / `left_at` to represent membership status (joined / left)
  - Migrate existing `user_organizations` data into `user_memberships` inside the migration

This makes it possible to determine whether a User is a sole proprietor or belongs to a company by
checking `UserMembership` and seeing which Workspace they belong to.

## When a Team (department hierarchy) becomes necessary

```text
Account -> Membership -> Workspace -> Team
                         |
                         v
                    AvatarGrant -> Avatar (with team_id)
```

- If you want to attach Avatars at the department level, add `Avatar.team_id`
- `AvatarGrant` still works as a permission grant from `Membership` to `Avatar`

## The “someone else’s Avatar” problem (separating ownership and permissions)

Since an Avatar may sometimes belong to someone else (transfer / migration), separate the Avatar’s
“owner” and “operating permissions.”

Recommended:

- Give `Avatar` an `owner` (usually the `Workspace`)
- Let `AvatarGrant` only distribute operating permissions (non-owners can still operate it)

If you really need transfer support, make it stronger:

- Create `AvatarOwnership` and record ownership history with `starts_at` / `ends_at` for
  auditability and dispute handling

## Billing

Billing foundation and future Stripe integration tracking moved to GitHub issue #577.

### Billing DB setup (local / CI)

```bash
bin/rails db:create:billing
bin/rails db:migrate:billing
bin/rails db:prepare
```

## Naming notes

- `Stakeholder` has already been renamed to `Account` (the concern included by `User` / `Staff`)
- The old `Organization` has already been renamed to `Workspace` (`Organization` remains as a shim
  for compatibility)
