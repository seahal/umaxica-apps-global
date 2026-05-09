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

## 2026-05-07 現状差分と改善として残すこと

この restoration item は一部実装済み。

確認済み:

- `Account` / `Workspace` / `Avatar` 系のモデル、migration、テストは現行ツリーに存在する。
- `AccountPolicy` と policy test も存在する。
- Billing の実体は今回の確認範囲では未確認。

この文書は「Account / Workspace / Avatar / Billing を全部 land する」計画ではなく、Billing
gap と既存 model 関係の検証改善として残す。

残す改善:

- Billing をこのアプリで持つのか、外部サービス / 将来 ADR に委ねるのか決める。
- Account / Workspace / Avatar のモデル関係と policy coverage を ADR と照合する。
- Billing を実装する場合は、既存の Account / Workspace / Avatar migration とは別 migration
  / 別 plan にする。
