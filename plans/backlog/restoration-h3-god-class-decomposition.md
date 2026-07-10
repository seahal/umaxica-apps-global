# Restoration H3: God-Class Decomposition (Audit High)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `../../adr/audit-findings-2026-03-30.md` (High severity)

## Goal

Decompose the god classes the audit names (typically the auth / session orchestrators) into smaller
services with clear responsibilities (SOLID, per AGENTS.md "Design Principles").

## Key surface

The specific classes the audit lists.

## Verification

Each new class has a focused test. Old call sites still pass.
