# Sign Settings 詳細監査計画

## Context

Sign 領域へ settings 機能を移植する作業が進行中だが、完全には整理されていない可能性がある。ADR
`adr/acme-sign-core-base-port-boundary.md`（2026-06-12 承認）により、Sign は OIDC
RP（証明儀式のみ）、Acme は IdP/AS（セッション・アイデンティティ・認可の権威）と確定した。この監査は、Sign
settings の現状を把握し、次フェーズの修正担当者が判断できる証拠付き監査レポートを
`memos/2026-06-23-sign-settings-audit.md` として作成することを目的とする。

**アプリケーションコードは一切変更しない。** 作成するのは監査レポート1ファイルのみ。

---

## 事前探索で判明した重要事項

### コントローラー数

| surface   | controllers |
| --------- | ----------- |
| Sign::App | ~24         |
| Sign::Com | ~22         |
| Sign::Org | ~20         |

### 既知の疑念点（監査で確認が必要）

1. **P0 候補**: `Sign::Org::Settings::RemovalsController` が `authenticate_operator!` ではなく
   `authenticate_client!` を使用（`app/controllers/sign/org/settings/removals_controller.rb`）。Org
   surface で Client 認証を要求するのは authentication bypass の可能性。
2. **Acme 境界 — 命名負債か実害か**: Activities controllers（app/com/org）が
   `AcmeAppSettingsActivityLog` / `AcmeComSettingsActivityLog` / `AcmeOrgSettingsActivityLog`
   を参照。サービスのアクター引数・テーブル・イベント名を確認し、命名負債か authority 越境かを判定する。
3. **Acme authority 懸案**: バックログ文書 `plans/backlog/sign-acme-boundary-remediation.md`
   により、`settings/sessions`・`settings/activities`・`settings/withdrawal`
   は Sign から Acme に移管すべき可能性があると判定済み（Stage 2 で human-review-gated）。
4. **テストファイル数**: Sign settings controller tests が 40 ファイル存在（app:16, com:11,
   org:13）。

---

## 実装アプローチ

### 出力先

```
memos/2026-06-23-sign-settings-audit.md
```

### 監査フェーズと実行戦略

**大規模な並列 Agent ワークフロー**で実施する。以下の作業を分担する。

#### Phase 1: 環境・ルート・surface マッピング（1 Agent）

- `git status --short` で未コミット変更を記録
- Ruby/Rails バージョン確認
- `config/routes/sign.rb` を全文読み込み
- `RAILS_ENV=test bin/rails routes -g` でルート全量取得（sign, setting, passkey, webauthn, totp,
  email, telephone, session, withdraw, revoc, apple, google, secret, lifecycle）
- TLD/surface/namespace/actor/host constraint の対応表を作成

#### Phase 2: コントローラー詳細監査（3 Agents 並列）

**Agent A — Sign::App settings コントローラー全読み**

- `app/controllers/sign/app/settings/` 以下を全ファイル読み込み
- 各コントローラーの: 継承・before_action・認証フィルター・認可・ownership scope を記録
- `authenticate_client!` の一貫性を確認
- Acme 参照を抽出・分類

**Agent B — Sign::Com settings コントローラー全読み**

- `app/controllers/sign/com/settings/` 以下を全ファイル読み込み
- 同上の確認項目
- `authenticate_visitor!` の一貫性

**Agent C — Sign::Org settings コントローラー全読み**

- `app/controllers/sign/org/settings/` 以下を全ファイル読み込み
- `removals_controller.rb` の `authenticate_client!` 問題を詳細確認
- Org 固有の `operator_lifecycle_requests` 系を確認

#### Phase 3: Service・Model・View 境界監査（2 Agents 並列）

**Agent D — Service/Model/Helper 境界監査**

- `app/services/acme_app_settings_activity_log.rb` 等を全読み（引数・テーブル・イベント名）
- `rg` で Sign controllers から Acme 参照をすべて抽出
- `app/views/sign/` で `acme_.*_path|acme_.*_url|/acme/` を探索
- Settings root 3ファイル（show.html.erb）のリンク網羅確認

**Agent E — Acme settings との比較**

- `app/controllers/acme/*/settings/emails/**` と `app/controllers/sign/*/settings/emails/**` を比較
- `app/controllers/acme/*/settings/telephones/**` と `app/controllers/sign/*/settings/telephones/**`
  を比較
- route が両方に存在するか確認
- `plans/backlog/sign-acme-boundary-remediation.md` 各項目のコード照合

#### Phase 4: テスト実行・棚卸し（2 Agents 並列）

**Agent F — テスト実行（app）**

```
RAILS_ENV=test bin/rails test test/controllers/sign/app/settings
```

結果を defect/stale test/environment failure に分類

**Agent G — テスト実行（com + org）**

```
RAILS_ENV=test bin/rails test test/controllers/sign/com/settings
RAILS_ENV=test bin/rails test test/controllers/sign/org/settings
```

#### Phase 5: WebAuthn・TOTP・Session 詳細監査（1 Agent）

- RP ID / expected origin の surface 別設定確認
- Session revoke の ownership 確認（他ユーザーのセッションを revoke できないか）
- Passkey destroy の last-credential 防護
- TOTP の last-credential 防護

#### Phase 6: 統合・レポート執筆（1 Agent）

Phase 1–5 の全結果を受け取り、指定フォーマットで `memos/2026-06-23-sign-settings-audit.md` を作成。

---

## 監査レポート構成（指定フォーマット）

1. Executive summary（全体判定 / P0〜P3 件数 / 最優先3項目）
2. Repository and environment
3. TLD / Surface mapping 表
4. Feature coverage matrix
5. Complete route inventory
6. Route–Controller–View matrix
7. Settings navigation inventory
8. Confirmed breakages（severity / confidence / evidence）
9. Security boundary risks
10. Migration debt
11. Acme/Sign duplication
12. Backlog remediation status（plans/backlog/sign-acme-boundary-remediation.md の各項目）
13. Authentication and authorization matrix
14. Existing test inventory
15. Test failures
16. Missing verification
17. Proposed tests（実装可能な粒度）
18. Executed commands（exit status / classification）
19. Recommended implementation order
20. Unknowns
21. Final assessment

---

## 禁止事項（再確認）

- アプリケーションコード・テスト・migration・設定ファイルの変更禁止
- `git reset` / `git checkout` / `git stash` による変更退避禁止
- 外部ネットワーク通信禁止
- `RAILS_ENV=test` 以外でのテスト実行禁止
- failing test の skip・書き換え禁止

## 変更ファイル

作成するのは以下の 1 ファイルのみ:

```
memos/2026-06-23-sign-settings-audit.md
```

## Verification

実行後に `git status --short` を実行し、変更が監査レポート1ファイルのみであることを確認する。
