# 監査報告: Sign `/settings` → Acme `/identity` 移植完了確認

調査日: 2026-06-26

---

## Context

Project Umaxica の方針として、Sign `/settings` の汎用 settings
surface を廃止し、identity 管理系を Acme `/identity` に移植する。Sign に残存するのは passkeys / TOTP
/ Google / Apple の4系統のみ。本報告は移植が設計方針どおりに完了しているかを調査した結果である。

---

## 1. Verdict

**Mostly complete, blocked by migration-related test failures (withdrawal) and harness issues
(telephone)**

主要な移植アーキテクチャは正しく実装されているが、withdrawal の shim
route がテスト環境で解決できておらず（404 を返す）、migration-related な test failure が存在する。

---

## 2. Evidence

### 確認済み route・controller

- `config/routes/sign.rb` — Sign 残存・shim 両方定義を確認
- `config/routes/acme.rb` — Acme `/identity` route 群を確認
- `app/controllers/acme/app/identity/` — 21 ファイル、全実装済みを確認
- `app/controllers/sign/app/settings/` — shim 化されたコントローラを確認
- `app/controllers/concerns/authentication_withdrawal_gate.rb` — 確認済み
- `test/controllers/identity_settings_migration_test.rb` — 存在・PASS を確認
- `test/controllers/acme/app/identity_authority_slice_1a_test.rb` — 確認済み
- `docs/architecture/sign-settings-to-acme-identity.md` — 確認済み
- `adr/identity-authority-boundary.md` — 確認済み（Proposed status）
- `docs/identity/authority-boundary.md` — 確認済み
- `docs/security/preference-settings-authority.md` — 確認済み
- `docs/index.md` — 確認済み

---

## 3. Sign に残っているもの

設計方針どおりに Sign 側に残存：

| Resource | Routes                                                                                                                                              | Controller                                           |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Passkeys | `GET/POST /settings/passkeys`, `GET/PATCH/DELETE /settings/passkeys/:id`, `POST /settings/passkeys/options`, `POST /settings/passkeys/verification` | `Sign::App::Settings::PasskeysController` — 完全実装 |
| TOTP     | `GET /settings/totps`, `GET /settings/totps/new`, `GET/PATCH/DELETE /settings/totps/:id`                                                            | `Sign::App::Settings::TotpsController` — 完全実装    |
| Apple    | `GET /settings/apple`, `GET /settings/apple/edit`, `POST /settings/apple`, `DELETE /settings/apple`                                                 | `Sign::App::Settings::ApplesController` — 完全実装   |
| Google   | `GET /settings/google`, `GET /settings/google/edit`, `POST /settings/google`, `DELETE /settings/google`                                             | `Sign::App::Settings::GooglesController` — 完全実装  |

---

## 4. Acme `/identity` に移ったもの

以下が Acme `/identity` で実装済み：

- Emails（index, edit, update, destroy）+ emails/registrations（new, create, edit, update）+
  emails/redeliveries
- Telephones（index, new, create, edit, destroy）+ telephones/registrations（new, create, edit,
  update）
- Birthdate（show）
- Secrets / secret credentials（index, show, new, edit, create, update, destroy）
- Secrets/rotations（create → 501 Not Implemented）
- Secrets/removals（create → 501 Not Implemented）
- Sessions（index, show, destroy）
- Revocations + revocations/others + revocations/alls
- Activities（index）
- Withdrawals（new, edit, create, update, destroy）
- Recovery secret（show）
- MFA/challenges（show, update）
- MFA/resets（show, create — unavailable message）

---

## 5. 302 redirect shim（moved GET routes）

Sign 側の全 moved GET route が `status: :see_other`（303）で redirect：

| Sign route                                   | Redirect 先                                           |
| -------------------------------------------- | ----------------------------------------------------- |
| `GET /settings`                              | `acme_app_identity_url`                               |
| `GET /settings/birthdate`                    | `acme_app_identity_birthdate_path`                    |
| `GET /settings/emails`                       | `acme_app_identity_emails_path`                       |
| `GET /settings/emails/:id/edit`              | `edit_acme_app_identity_email_path`                   |
| `GET /settings/emails/registration/new`      | `new_acme_app_identity_emails_registration_path`      |
| `GET /settings/emails/registration/edit`     | `edit_acme_app_identity_emails_registration_path`     |
| `GET /settings/telephones`                   | `acme_app_identity_telephones_path`                   |
| `GET /settings/telephones/new`               | `new_acme_app_identity_telephone_path`                |
| `GET /settings/telephones/:id/edit`          | `edit_acme_app_identity_telephone_path`               |
| `GET /settings/telephones/registration/new`  | `new_acme_app_identity_telephones_registration_path`  |
| `GET /settings/telephones/registration/edit` | `edit_acme_app_identity_telephones_registration_path` |
| `GET /settings/secrets`                      | `acme_app_identity_recovery_secret_path`              |
| `GET /settings/secret_credentials`           | `acme_app_identity_secrets_path`                      |
| `GET /settings/secret_credentials/new`       | `new_acme_app_identity_secret_path`                   |
| `GET /settings/secret_credentials/:id`       | `acme_app_identity_secret_path`                       |
| `GET /settings/secret_credentials/:id/edit`  | `edit_acme_app_identity_secret_path`                  |
| `GET /settings/sessions`                     | `acme_app_identity_sessions_path`                     |
| `GET /settings/sessions/:id`                 | `acme_app_identity_session_path`                      |
| `GET /settings/activities`                   | `acme_app_identity_activities_path`                   |
| `GET /settings/withdrawal/new`               | `new_acme_app_identity_withdrawal_path`               |
| `GET /settings/withdrawal/edit`              | `edit_acme_app_identity_withdrawal_path`              |
| `GET /settings/mfa/reset`                    | `acme_app_identity_mfa_reset_path`                    |
| `GET /settings/mfa/challenge`                | `acme_app_identity_mfa_challenge_path`                |

全 redirect で `ri:` パラメータを透過的に引き継いでいる。

---

## 6. 410 Gone shim（moved mutation routes）

Sign 側の全 moved mutation route が `head(:gone)` を返す：

- `POST/PATCH/DELETE /settings/emails/:id`
- `POST/PATCH /settings/emails/registration`
- `POST /settings/emails/:id/resend`（email redelivery）
- `POST/PATCH/DELETE /settings/telephones`
- `PATCH /settings/telephones/registration`
- `POST/PATCH/DELETE /settings/secret_credentials` および rotation/removal
- `DELETE /settings/sessions/:id`
- `POST /settings/sessions/:id/revocation`
- `POST /settings/revocations/others`
- `POST /settings/revocations/all`
- `POST/PATCH/DELETE /settings/withdrawal`
- `POST /settings/mfa/reset`
- `PATCH /settings/mfa/challenge`

> **注意**: `secrets/rotations_controller` と `secrets/removals_controller`（Acme 側）は現在
> `501 Not Implemented` を返す。Sign 側の対応 route は 410
> Gone が正しく設定済み。Acme 側 501 は実装未完了の可能性があるが、今回 scope の外（secrets
> rotation/removal の full implementation）である可能性が高い。要確認。

---

## 7. 残っている旧挙動

### View coupling（既知・設計上の暫定措置）

Acme identity controllers が Sign views を直接 render している：

```ruby
# app/controllers/acme/app/identity/emails_controller.rb
render "sign/app/settings/emails/index"

# app/controllers/acme/app/identity/sessions_controller.rb
render "sign/app/settings/sessions/show"

# app/controllers/acme/app/identity/withdrawals_controller.rb
render "sign/app/settings/withdrawals/edit"
```

`app/views/acme/app/identity/`
以下のディレクトリは存在するが、view ファイルは空。Acme 専用 view の実装は scope 外（または今後の作業）。

### Sign settings root view（passkeys/TOTP/Apple/Google 用）

`app/views/sign/app/settings/show.html.erb` は `sign_app_settings_*_path`
を指すリンクを多数含んでいる。これは passkeys / TOTP / Apple / Google への navigation として
**正当**。ただし、moved リソースへのリンクが残存していないかの細部確認は view audit では未完了。

---

## 8. Test result

### 個別テスト結果

| Test file                                     | 結果                                     | 分類                                                         |
| --------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------ |
| `identity_settings_migration_test.rb`         | ✅ 6 runs, 0 failures                    | Migration tests — PASS                                       |
| `emails/registrations_controller_test.rb`     | ✅ 5 runs, 0 failures                    | Shim tests — PASS                                            |
| `telephones/registrations_controller_test.rb` | ❌ 2 errors                              | Fixture FK violation — **Fixture/DB initialization related** |
| `withdrawals_controller_test.rb`              | ❌ 5 failures（404 instead of 302/410）  | Route not found in test env — **Migration-related**          |
| `withdrawal_gate_test.rb`                     | ❌ 2 errors（deadlock, RecordNotUnique） | Test setup — **Fixture/DB initialization related**           |
| `verification_flow_test.rb`                   | ✅ 3 runs, 0 failures                    | Integration — PASS                                           |
| `controller_base_inheritance_test.rb`         | ✅ 7 runs, 0 failures                    | Inheritance — PASS                                           |
| `sessions_controller_test.rb`                 | —                                        | 未実行（個別）                                               |
| `emails_controller_test.rb`                   | —                                        | 未実行（個別）                                               |
| `birthdates_controller_test.rb`               | —                                        | 未実行（個別）                                               |

### Full test suite

`PARALLEL_WORKERS=1 bin/rails test`
の完全実行結果は未取得。（セキュリティ調査エージェントが試みたが、出力キャプチャが不完全だった。）

### Failure 分類

#### Migration-related（要対応）

**`test/controllers/sign/app/settings/withdrawals_controller_test.rb`**

- 全 5 テストが 404 を返す（302/410 を期待）
- コントローラ実装（`new`, `edit` → 303 redirect, `create`, `update`, `destroy` →
  410）は正しく実装済み
- **根拠**: コントローラコードは shim として正しいが、テスト環境でルートが解決できていない
- 可能性: test 用 route の draw 漏れ、または sign_app_settings_withdrawal_path 系の named
  route が変更された

#### Fixture/DB initialization related

**`test/controllers/sign/app/settings/telephones/registrations_controller_test.rb`**

- `ActiveRecord::InvalidForeignKey`（PG ForeignKeyViolation）
- migration logic ではなく fixture setup の問題

**`test/integration/withdrawal_gate_test.rb`**

- Deadlock detected（avatar creation）
- `RecordNotUnique`（client_tokens）
- fixture / parallel setup 起因

---

## 9. Docs result

| ドキュメント                                          | 存在           | 内容一致                                                    |
| ----------------------------------------------------- | -------------- | ----------------------------------------------------------- |
| `docs/architecture/sign-settings-to-acme-identity.md` | ✅             | ✅ 全要件を明記                                             |
| `adr/identity-authority-boundary.md`                  | ✅（Proposed） | ✅ 302/410/RP=Core/Base/Palm 明記                           |
| `docs/identity/authority-boundary.md`                 | ✅             | ⚠ Superseded note あり。新 ADR を参照するよう案内されている |
| `docs/security/preference-settings-authority.md`      | ✅             | ✅ Acme 権威の範囲を明記                                    |
| `docs/index.md`                                       | ✅             | ✅ migration doc を参照                                     |

以下が `docs/architecture/sign-settings-to-acme-identity.md` および ADR で明記済み：

- ✅ Sign `/settings` は汎用 settings surface として廃止
- ✅ Sign に残すのは passkeys / TOTP / Google / Apple のみ
- ✅ その他の identity/settings は Acme `/identity` に移す
- ✅ moved GET は 302 redirect shim
- ✅ moved mutation は 410 Gone
- ✅ unsafe method は redirect しない
- ✅ RP は今後 Core / Base / Palm として扱う
- ✅ Sign temporary-session 化は将来方針だが今回 scope 外
- ✅ Sign-out / OIDC / callback / token handling は今回 scope 外

`adr/identity-authority-boundary.md` が **Proposed**
ステータスのままである点は注意。Accepted への昇格が必要かどうかは判断が必要（Needs decision）。

---

## 10. Remaining work

### 実装必須

1. **Withdrawal shim route のテスト環境 404 問題**
   - `test/controllers/sign/app/settings/withdrawals_controller_test.rb` が全5テスト 404
   - コントローラは正しく実装されているため、route 定義の draw 漏れまたは named
     route の不整合が原因と考えられる。`config/routes/sign.rb` の withdrawal section を精査すること

2. **Secrets rotation/removal の Acme 実装**
   - `Acme::App::Identity::Secrets::RotationsController#create` と
     `Acme::App::Identity::Secrets::RemovalsController#create` が `501 Not Implemented`
   - これが今回 scope 外であれば docs に明記する必要がある

### Fixture / DB initialization

3. **Telephone registrations テストの FK violation**
   - fixture または DB setup を修正する
   - migration 完了判定はブロックしないが、CI を汚染する

4. **Withdrawal gate テストの deadlock / RecordNotUnique**
   - fixture の並列実行問題またはデータ競合
   - `PARALLEL_WORKERS=1` で green になるか確認が必要

### Docs

5. **`adr/identity-authority-boundary.md` を Proposed → Accepted に昇格**
   - 実装が完了していれば Proposed のままにする理由がない

6. **`docs/identity/authority-boundary.md` の Superseded note を整理**
   - 現行 ADR への参照を明確にするか、deprecated として明示する

7. **`app/views/acme/app/identity/` の view 実装**
   - 現在 Acme controllers が Sign views を render している
   - 技術的負債として docs または plans に記録する

8. **Full test suite の green 確認**
   - `PARALLEL_WORKERS=1 bin/rails test` を実行して全体結果を確認
   - withdrawal shim 修正後に再確認

### Needs decision

9. **Secrets rotation/removal の scope 確認**
   - 501 は "not yet implemented" か "out of scope" かを明示する

10. **Sign settings root view（`show.html.erb`）の moved リソースリンク残存確認**
    - passkeys/TOTP/Apple/Google 以外へのリンクが残存していないか細部を確認

11. **Acme identity 専用 view の実装計画**
    - 現行の Sign
      view 流用（coupling）を技術的負債として plans に登録するか、今回 scope 外として docs に明記するか

---

## セキュリティ境界サマリー

- ✅ CSRF 境界は崩れていない（skip_forgery 使用なし）
- ✅ mutation route は redirect されていない（全て 410 Gone）
- ✅ open redirect の危険なし（redirect 先は全て named route helper 経由）
- ✅ step-up が必要な操作（secrets new/create, emails registration, birthdate）は Acme 側で維持
- ✅ withdrawal / secrets / sessions / revocations / MFA reset は Acme 権威側に存在
- ✅ Sign が Acme の controller/API を authority として消費していない
- ✅ passkeys / TOTP / Google / Apple が Sign 例外として明示されている
- ⚠ Acme identity controllers が Sign views を render（view
  coupling）— 機能上の問題なし、保守上の懸念
