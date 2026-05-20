# Restoration B1: Account / Workspace / Avatar / Billing Structure

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/account-workspace-avatar-billing.md`

## Goal

Land the account/workspace/avatar/billing model the ADR specifies as Rails models under
`app/models/`.

## Key surface

Account, Workspace, Avatar, Billing models and their migrations; policies that scope operations on
workspaces.

## Verification

Model tests for each entity; system test that creates an account, joins a workspace, sets an avatar,
and views billing.

## 2026-05-07 What to leave as current differences and improvements

This restoration item has been partially implemented.

Confirmed:

- `Account` / `Workspace` / `Avatar` models, migrations, and tests exist in the current tree.
- `AccountPolicy` and policy test also exist.
- The actual billing has not been confirmed at this time.

This document is not a plan to "land all Account / Workspace / Avatar / Billing", but This will be
left as a validation and improvement of the gap and existing model relationship.

Improvements to leave:

- Decide whether to have billing with this app or leave it to an external service/ADR in the future.
- Check the model relationship and policy coverage of Account / Workspace / Avatar with ADR.
- When implementing Billing migration, separate from existing Account / Workspace / Avatar
  migration. / Make a separate plan.
