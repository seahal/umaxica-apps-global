# Sign Settings 詳細監査計画

## Context

Sign 領域への設定機能移植が完全には整理されていない可能性がある。 `AcmeAppSettingsActivityLog`
のような Acme namespace のサービスが Sign settings に使われており、
`plans/backlog/sign-acme-boundary-remediation.md`
が境界問題として認識されている。この監査は「何が動いており、何が壊れており、何が曖昧か」を根拠付きで整理し、次の修正フェーズの担当者が優先順位を判断できる報告書を生成することが目的。

コードは変更しない。

---

## 現時点で判明している構造

### TLD / Surface 対応

| logical surface | host (dev)                                                 | Rails namespace | actor type |
| --------------- | ---------------------------------------------------------- | --------------- | ---------- |
| app             | `id.app.localhost` (boot_config.hosts.acme_service.host)   | `Sign::App::`   | Client     |
| com             | `id.com.localhost` (boot_config.hosts.acme_corporate.host) | `Sign::Com::`   | Visitor    |
| org             | `id.org.localhost` (boot_config.hosts.acme_staff.host)     | `Sign::Org::`   | Operator   |

Host 制約は `config/routes/sign.rb` に boot_config 経由で定義。

### Sign Settings コントローラ構成（探索済み）

- 3 surface × 約 24 controllers = 72 settings controllers
- 各 surface に `SettingsController` (show のみ) + 機能別サブコントローラ
- App 専用: `TotpsController`, `ApplesController`, `GooglesController`, `SecretsController`,
  `Mfa::ResetsController`
- Org 専用: `OperatorLifecycleRequestsController` 系

### Acme Settings との重複疑惑

- `app/controllers/acme/[surface]/settings/emails/`, `telephones/` が存在
- Sign settings にも `emails/`, `telephones/` が存在
- 同一機能が両方に存在している可能性

### 既知の境界問題

- `AcmeAppSettingsActivityLog` / `AcmeComSettingsActivityLog` / `AcmeOrgSettingsActivityLog` → Acme
  namespace だが Sign settings の activity を扱う
- `plans/backlog/sign-acme-boundary-remediation.md` (13.5KB) に既知の境界問題が記載

---

## 監査実行計画

### フェーズ 1: 環境確認 (読み取り専用)

```bash
pwd && git branch --show-current && git status --short
ruby --version && bundle exec rails --version
```

```bash
# Test framework 確認
ls test/ spec/ 2>&1
```

### フェーズ 2: ルート全量取得

```bash
RAILS_ENV=test bin/rails routes -g sign 2>&1 | head -300
RAILS_ENV=test bin/rails routes -g setting 2>&1 | head -200
RAILS_ENV=test bin/rails routes -g passkey 2>&1
RAILS_ENV=test bin/rails routes -g totp 2>&1
RAILS_ENV=test bin/rails routes -g email 2>&1 | grep -i sign
RAILS_ENV=test bin/rails routes -g session 2>&1 | grep -i sign
RAILS_ENV=test bin/rails routes -g withdraw 2>&1
RAILS_ENV=test bin/rails routes -g revoc 2>&1
RAILS_ENV=test bin/rails routes -g apple 2>&1
RAILS_ENV=test bin/rails routes -g google 2>&1
RAILS_ENV=test bin/rails routes -g secret_credential 2>&1
RAILS_ENV=test bin/rails routes -g telephone 2>&1 | grep -i sign
```

### フェーズ 3: Zeitwerk チェック

```bash
RAILS_ENV=test bin/rails zeitwerk:check 2>&1
```

失敗した constant と file path を記録する。

### フェーズ 4: Route–Controller 対応確認

読み取り対象:

- `config/routes/sign.rb` (全文)
- `app/controllers/sign/app/settings/**/*.rb`
- `app/controllers/sign/com/settings/**/*.rb`
- `app/controllers/sign/org/settings/**/*.rb`
- `app/controllers/sign/app/application_controller.rb`
- `app/controllers/sign/com/application_controller.rb`
- `app/controllers/sign/org/application_controller.rb`

確認事項:

- route 上の controller#action に対応するクラス・メソッドが存在するか
- 逆に controller が存在するが route がないケース
- `before_action :authenticate_*!` が全 action に適用されているか
- `authorize!` が存在するか

### フェーズ 5: View・ナビゲーション監査

読み取り対象:

- `app/views/sign/app/settings/show.html.erb`
- `app/views/sign/com/settings/show.html.erb`
- `app/views/sign/org/settings/show.html.erb`
- 各 settings サブ view (passkeys, emails, telephones, sessions, totps, withdrawals)

確認事項:

- settings root の各リンクが現存する route helper を参照しているか
- `*_path` / `*_url` が `bin/rails routes` 出力と一致するか
- Acme namespace の helper (`acme_*_path`) が残っていないか
- cross-surface URL が混入していないか

```bash
grep -rn "acme_.*_path\|acme_.*_url" app/views/sign/ 2>&1
grep -rn "link_to\|button_to\|form_with" app/views/sign/*/settings/show.html.erb 2>&1
```

### フェーズ 6: Acme 残骸スキャン

```bash
grep -rn "Acme::" app/controllers/sign/ app/views/sign/ 2>&1
grep -rn "acme_" app/controllers/sign/ app/views/sign/ 2>&1
grep -rn "AcmeAppSettingsActivityLog\|AcmeComSettingsActivityLog\|AcmeOrgSettingsActivityLog" \
  app/controllers/ app/services/ 2>&1
```

`plans/backlog/sign-acme-boundary-remediation.md` を全文読む。

### フェーズ 7: 認証・認可確認

```bash
grep -rn "skip_before_action\|skip_authorization\|skip_forgery" \
  app/controllers/sign/ 2>&1
grep -rn "authenticate_client\|authenticate_visitor\|authenticate_operator" \
  app/controllers/sign/*/settings/ 2>&1
```

各 destructive action (delete, destroy, withdrawal, revoke) について:

- HTTP method が GET でないことを route で確認
- ownership check が controller に存在するか

### フェーズ 8: WebAuthn / TOTP 固有確認

```bash
grep -rn "rp_id\|rp_name\|relying_party\|expected_origin\|origin" \
  app/ config/ lib/ 2>&1 | grep -v test | head -40
grep -rn "totp\|TotpCeremony\|totp_credential" \
  app/controllers/sign/com/ app/controllers/sign/org/ 2>&1
```

App 専用 TOTP が com/org に route / controller / view が存在しないことを確認。

### フェーズ 9: Email / Callback URL

```bash
grep -rn "default_url_options\|url_options\|host:" config/ app/mailers/ 2>&1 | head -40
grep -rn "acme_.*callback\|sign_.*callback" config/routes/ 2>&1
```

Email verification callback が Sign route を向いているか確認。

### フェーズ 10: 既存テスト棚卸し

```bash
find test/controllers/sign -name "*.rb" | sort
find test/integration -name "*sign*" -o -name "*setting*" | sort
find test/services -name "*activity_log*" | sort
```

各テストファイルについて:

- 対象 surface / feature
- host 指定があるか
- 認証 setup があるか
- failure / ownership assertion があるか

### フェーズ 11: テスト実行（限定）

```bash
# Sign settings controller tests
RAILS_ENV=test bin/rails test test/controllers/sign/app/settings/ 2>&1
RAILS_ENV=test bin/rails test test/controllers/sign/com/settings/ 2>&1
RAILS_ENV=test bin/rails test test/controllers/sign/org/settings/ 2>&1

# Integration
RAILS_ENV=test bin/rails test test/integration/sign/ 2>&1

# Route contract
RAILS_ENV=test bin/rails test test/integration/routes/ 2>&1

# Activity log services
RAILS_ENV=test bin/rails test test/services/acme_app_settings_activity_log_test.rb \
  test/services/acme_com_settings_activity_log_test.rb \
  test/services/acme_org_settings_activity_log_test.rb 2>&1
```

失敗は application defect か stale test かを分類して記録。

### フェーズ 12: Git 履歴による移植追跡

```bash
git log --oneline --all -- app/controllers/sign app/views/sign test | head -30
git log -S"Acme::" --oneline --all -- app/controllers/sign app/views/sign | head -20
git log --name-status --find-renames -- app/controllers/acme/*/settings \
  app/controllers/sign/*/settings | head -60
```

---

## 報告書の出力先

`memos/` に日付付きファイルで保存する:

```
memos/YYYY-MM-DD-sign-settings-audit.md
```

フォーマットは監査プロンプト §32 の構成に従う。

---

## 重点確認項目（優先度順）

1. **P0候補**: `AcmeAppSettingsActivityLog` が Sign settings に参照されている箇所 —
   Acme 境界問題の核心
2. **P0候補**: `acme/*/settings/emails/`, `acme/*/settings/telephones/` と Sign 側の重複
3. **P1候補**: App 専用機能 (TOTP, Apple, Google) が com/org に意図的不在か route 欠落か
4. **P1候補**: settings root の view から各機能への link が現存 route helper を参照しているか
5. **P2候補**: `sign-acme-boundary-remediation.md` に記載の未解決問題の現状
6. **P2候補**: 各機能の unauthorized / ownership テストが存在するか

---

## 制約・注意事項

- コードを変更しない
- production/development DB にアクセスしない
- 外部通信を発生させない (OAuth, SMS, Email)
- テストは `RAILS_ENV=test` のみ
- 実行できないコマンドも記録して「不明」として残す
- 架空の route helper / model 名を報告に混入させない
