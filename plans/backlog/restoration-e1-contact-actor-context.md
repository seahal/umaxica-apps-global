# Restoration E1: Contact::ActorContext Shared Contract

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/notes/contact-auth-shared-contract.md`
- `adr/notes/contact-auth-integration.md`

## Goal

A small typed value object representing the authenticated subject as far as Contact needs it. Used
by Contact services instead of reaching into Auth internals.

## Key surface

New value object; refactor of Contact services to consume it; the auth side exposes a builder.

## Verification

Contact tests do not import auth model classes directly; they receive an `ActorContext` instance.
