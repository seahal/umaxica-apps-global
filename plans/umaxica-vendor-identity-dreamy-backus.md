# Vendor Identity Docs — RFI Package Remediation

## Context

Cross-document consistency audit (2026-06-25) identified 5 mandatory fixes before distributing the
`docs/vendor/identity/` package to SIers. The audit was performed read-only against the
rfi-draft/2026-06-24-r4 snapshot. This plan addresses all 5 mandatory fixes plus 3 supporting
changes required for consistency.

Key finding from exploration: `15_audit-log-integrity-requirement.md` already exists as rfi-draft
with comprehensive content (§3 NR-004, 15 event classes, 9 threat scenarios, 7 implementation
candidates, 15 acceptance criteria). The audit's M-5 concern is resolved — the document only needs
to be registered in `00_readme.md`.

---

## Changes Required

### 1. `docs/vendor/identity/00_readme.md` — Package Map and Warnings (M-1, CON-003, CON-005)

- Add `13_normative-baseline.md`, `14_account-recovery-procedure.md`, and
  `15_audit-log-integrity-requirement.md` to the **Related Documents** list and the **Package Map**
  table.
- In the Package Map row for `08_threat-model.md`, add a `[DRAFT — context only — not normative]`
  note.
- In the Package Map row for `12_gap-risk-register.md`, add a
  `[STALE — not for distribution until updated]` note.
- Add a brief **Distribution Warning** section near the top: `notes/oauth2-1-compliance-gap.md` is
  INTERNAL ONLY and must not be included in any vendor package.

### 2. `docs/vendor/identity/12_gap-risk-register.md` — Round 4/5 Blockers (M-2, CON-004)

Add the following missing entries from the pinwheel GAP register:

| ID          | Content                                                                 | Severity | Status |
| ----------- | ----------------------------------------------------------------------- | -------- | ------ |
| GAP-002     | Chronicle DB-level immutability absent; NR-004 requires it (DEC-013)    | CRITICAL | OPEN   |
| GAP-NEW-001 | Recovery passcode verification has no rate limit / lockout              | HIGH     | OPEN   |
| GAP-NEW-006 | MFA reset UI DISABLED; 5 prerequisite conditions required before enable | CRITICAL | OPEN   |
| GAP-NEW-007 | Catastrophic account recovery (all credentials lost) is undefined       | CRITICAL | OPEN   |

Also update existing stale entries:

- G-008: Mark CLOSED (superseded by `01_responsibility_matrix.md`)
- G-009: Mark CLOSED (superseded by `04_cookie-session-token-matrix.md`)

### 3. `docs/vendor/identity/11_decision-register.md` — DEC-012/013 and Namespace Note (M-3, CON-001, CON-002, CON-007)

- Add **DEC-012**: Token endpoint null_session fail-closed. Back-channel endpoint; null_session or
  missing protocol context must return a deterministic OAuth error and must not issue a token.
  Corresponds to pinwheel DEC-012 (GQ-05 CLOSED).
- Add **DEC-013**: Audit log integrity is a normative security requirement. Critical security events
  must be append-only at the application boundary. DB-level prevention or detection of update/delete
  is required. Application-level sanitization + `event_uuid` UNIQUE alone is insufficient.
  Corresponds to pinwheel DEC-013.
- Add a **Namespace Note** at the top: DEC numbers in this register are vendor-facing (`VDR-` scope)
  and do not map 1:1 to procurement-internal DEC numbers in `plans/umaxica-immutable-pinwheel.md`.
  Cross-reference: `VDR DEC-012` = pinwheel DEC-012, `VDR DEC-013` = pinwheel DEC-013.
- Add **DEC-014** (new): `notes/oauth2-1-compliance-gap.md` is non-authoritative, uses stale
  vocabulary (`sign.*` as AS), and must not be distributed in any vendor package. Corresponds to
  pinwheel DEC-001/002.

### 4. `docs/vendor/identity/08_threat-model.md` — DRAFT Label (M-4, CON-005)

- Insert a bold warning block immediately after the frontmatter (before `# Purpose`):
  ```
  > **DRAFT — CONTEXT ONLY — NOT NORMATIVE**
  > Owner: TBD. Review: not completed. This document must not be cited as a normative requirement.
  > Include in vendor packages only with an explicit "context only" cover note.
  ```

### 5. `notes/oauth2-1-compliance-gap.md` — Internal-Only Header (Action #5, CON-007)

- Insert at the very top of the file:
  ```
  > **INTERNAL ONLY — NOT FOR DISTRIBUTION**
  > This document uses stale vocabulary (`sign.*` as AS) and is non-authoritative.
  > Excluded from all vendor packages per decisions DEC-001/002 (pinwheel) and DEC-014 (vendor register).
  ```

### 6. `docs/security/mfa-reset-account-recovery.md` — Superseded Header (CON-006)

- Insert at the very top:
  ```
  > **SUPERSEDED BY `docs/vendor/identity/14_account-recovery-procedure.md`**
  > This document is an earlier version. For vendor-facing or normative reference, use 14_ instead.
  ```

---

## Files Not Requiring Changes

- `docs/vendor/identity/13_normative-baseline.md` — rfi-draft, content correct, no drift
- `docs/vendor/identity/14_account-recovery-procedure.md` — rfi-draft, OPEN BLOCKERs already
  explicit (S-005 catastrophic recovery, identity verification)
- `docs/vendor/identity/15_audit-log-integrity-requirement.md` — rfi-draft, comprehensive; only
  needs to be registered in `00_readme.md`
- `docs/vendor/identity/07_social-linking-policy.md` — content aligned with NR-001; no changes
  needed for RFI readiness

---

## Implementation Order

1. `11_decision-register.md` — add namespace note + DEC-012/013/014 (prerequisite for 00_readme
   cross-reference)
2. `12_gap-risk-register.md` — add Round 4/5 blockers + close G-008/G-009
3. `00_readme.md` — update package map (13/14/15), add 08* DRAFT note, add 12* stale note, add
   distribution warning
4. `08_threat-model.md` — add DRAFT warning block
5. `notes/oauth2-1-compliance-gap.md` — add INTERNAL ONLY header
6. `docs/security/mfa-reset-account-recovery.md` — add SUPERSEDED header

---

## Verification

After all changes:

1. Read `00_readme.md` package map — confirm 00~15 all listed with correct status notes.
2. Read `11_decision-register.md` — confirm DEC-012/013/014 present and namespace note at top.
3. Read `12_gap-risk-register.md` — confirm GAP-002/NEW-001/NEW-006/NEW-007 present; G-008/G-009
   marked CLOSED.
4. Read `08_threat-model.md` lines 1–20 — confirm DRAFT block visible before `# Purpose`.
5. Read first 5 lines of `notes/oauth2-1-compliance-gap.md` — confirm INTERNAL ONLY header.
6. Read first 5 lines of `docs/security/mfa-reset-account-recovery.md` — confirm SUPERSEDED header.

No tests to run — all changes are documentation-only Markdown files.
