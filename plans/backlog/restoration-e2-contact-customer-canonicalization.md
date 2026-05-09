# Restoration E2: Contact / Auth Customer Canonicalization

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/notes/contact-auth-customer-canonicalization.md`

## Goal

Canonicalize how a Contact resolves to a customer / actor record so duplicate paths collapse.

## Key surface

Contact resolver service; the controller actions that take user-supplied contact identifiers.

## Verification

Tests covering each input shape (email, phone, etc.) resolving to the same canonical record.
