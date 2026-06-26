# Plan: Acme Account / Organization Documentation Freeze

## Context

アプリケーションコードの実装前に、Acme surface の Account /
Organization 実装方針・未決定論点・PR 分割計画を ADR・memo・plan に書き込む。既存の
`adr/acme-account-organization-bootstrap-boundary.md` と
`plans/active/acme-account-organization-bootstrap-implementation-plan.md`
は骨格のみで、以下が不足している:

- Identity 1:n Account の 3 選択肢（A/B/C）の詳細記録
- title 導入の 3 選択肢（A/B/C）の詳細記録
- quota 方針の詳細（class 名、定数名、未決定論点）
- natural-person only / 除外スコープの明示
- preference ADR 衝突の記録
- OrganizationUnit を触らない旨の明示

## Action Plan

アプリケーションコード・migration・model・controller・route・test は一切変更しない。

### 1. 新規 ADR を作成

**ファイル**: `adr/acme-account-organization-resource-boundary.md`

既存の bootstrap-boundary ADR とは別ファイルとして新規作成。セクション構成:

- Context
- Decision（18 項目、既存 ADR を継承・拡張）
- Current implementation facts（モデル名、カラム名、concern 名）
- Account / Organization model mapping（surface × concrete model 対応表）
- Signup bootstrap
- Public lookup and routing
- Title naming decision（Option A/B/C、推奨 B）
- Quota policy direction（class 名、定数、未決定論点）
- Known conflicts（preference ADR 衝突）
- Deferred decisions（Identity 1:n 選択肢 A/B/C、OrganizationUnit スコープ）
- Consequences

### 2. 既存 memo を更新

**ファイル**: `memos/2026-06-26-codex-acme-account-organization-implementation-plan.md`

既存ファイルを拡張して以下を追記:

- natural-person only スコープの明示
- 除外リスト（STI、enum kind/type、corporate org 等）
- 3 surface 同時対応の原則
- legacy `Organization` モデルとの命名衝突注意
- title の 3 選択肢詳細と推奨 Option B の理由
- Identity 1:n の 3 選択肢詳細と現状 1:1 制約の技術的根拠
- quota 方針詳細

### 3. 既存 plan を更新

**ファイル**: `plans/active/acme-account-organization-bootstrap-implementation-plan.md`

既存ファイルを拡張して以下を追記:

- PR 1〜6 の詳細（test strategy、rollback、risks を各 PR に）
- quota class 名の方向性
- Open questions セクション
- Risks / Rollback セクション

## Verification

- `git diff --stat` でアプリケーションコードに変更がないことを確認
- 変更対象: `adr/`, `memos/`, `plans/active/` のみ

## Non-Goals

- migration・model・controller・route・service・test の変更
- rails generate の実行
- formatter のみの変更
