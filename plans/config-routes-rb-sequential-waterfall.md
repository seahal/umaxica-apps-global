# config/routes/\*.rb コメント棚卸し — 問題分類と対処方針

## Context

`config/routes/*.rb`
全ファイルのコメント（`# TODO`、`# FIXME`）を読み、何が不満として残されているかを整理する。コメントは大きく 4 カテゴリに分類できる。実装はこの計画から別スライスで行う。

**設計前提の確認（ユーザーによる 2026-06-13 訂正）：**

- `sign/app`・`sign/com`・`sign/org` の `settings` は **sign に残す**。passkey/totp/social
  login の WebAuthn URL バインディング制約により、ceremony の origin が `id.*`
  ドメインに固定されるため Acme への移行は不適切と判断した。 `sign.rb:493` の
  `# TODO: move settings to acme's identity entrypoints.`
  コメントはこの判断により廃止（コメント削除が必要）。
- D-2（`web/v0` / `edge/v0` → `api/v0`）は実施する。

---

## 発見した問題の分類

### カテゴリ A: 今すぐ削除すべきルート（最優先）

#### A-1: r18 ゲートが `sign.rb` に本番公開されている

`sign.rb` の `sign/com`（line 256）と `sign/org`（line 433）に `namespace :r18` ルートがある。

```ruby
# FIXME: REMOVE THIS!!!
namespace :r18 do
  resource :gate, only: %i(show create) do ...
```

**問題点：** `acme.rb` の同種のルートは `if Rails.env.local?` でガードされているが、 `sign.rb`
の 2 箇所はガードなし。本番に公開されたまま。

**対処：** コントローラの実装を確認してから `sign.rb` の `r18` ブロック 2 つを削除する。

#### A-2: `acme.rb` の一時 R18 smoke-test ルート — **実施済み（2026-06-13）**

`Rails.env.local?`
でガードされていたが、R18 ゲートのロールアウト完了を確認し、即時削除。検証不要として実施した。

---

### カテゴリ B: コメントの訂正・確認が必要なルート

#### B-1: `get :welcome` を `resource :welcome` に変えたい（acme.rb）

```ruby
# TODO: I think following two lines of routing are same meaing.
get :welcome, to: "welcomes#show", as: :welcome_entry
resource :dashboard, only: :show
```

`resource :dashboard` は必要。コメントの「same meaning」は誤解で、2 つは別の画面。本当の問題は
`get :welcome` が bare get として宣言されており、`resource :welcome` に整理できないか、という疑問。

**確認事項：** `welcomes_controller` が `show` のみなら `resource :welcome, only: :show`
に変更可能。ルートヘルパー名が `welcome_entry_path` から `acme_app_welcome_path`
に変わるため、参照箇所の一括置換が必要。`sign-acme-boundary-remediation.md` § 3 で `welcome`
は保持対象。

#### B-2: `settings/sessions` collection delete はまだ必要か（acme.rb line 142）

```ruby
# FIXME: Check these entrypoints are still needed.
collection do
  delete :others
  delete :revoke_all
end
```

**調査結果：** `app/controllers/acme/app/settings/sessions_controller.rb` に `def others = super` と
`def revoke_all = super` が実装済みで、`AcmeSettingsSessionManagement`
concern を通じて動作中。ルートは生きている。

**結論：** FIXME コメントを削除するだけでよい。ルートとコントローラはそのまま残す。

#### B-3: `verification/setup` の目的が不明（sign.rb line 158）

```ruby
# TODO: what is the following line? check it out!
resource :setup, only: %i(new)
```

**調査結果：** `app/controllers/sign/app/verification/setups_controller.rb`
は生きている。ユーザーが step-up
verification に必要な MFA メソッドを未設定の場合にこの画面に誘導され、passkey や TOTP を追加登録させるフロー。`sign/com`
にも同様の実装が存在する（メソッドリストは com では `%i(email_otp passkey)` に絞られている）。

**結論：** TODO コメントを削除するだけでよい。ルートは必要。

---

### カテゴリ C: 命名改善（FIXME: I want to rename...）

`sign.rb` 全体に `_attempt` / `_cancellation`
サフィックスのルートが散在している。これらは名前が気に入らないだけで機能上の問題はない。

| パターン                                       | 代表例                                          | 出現面          |
| ---------------------------------------------- | ----------------------------------------------- | --------------- |
| `session_cancellation`                         | `sign/in/session_cancellation`                  | app / com / org |
| `check_cancellation`                           | `sign/in/check_cancellation`                    | app / com / org |
| `removal_attempt`                              | `settings/passkeys/removal_attempt`             | app / com / org |
| `rotation_attempt`                             | `settings/secret_credentials/rotation_attempt`  | app / com       |
| `revocation_attempt`                           | `settings/sessions/revocation_attempt`          | app / com / org |
| `connection_attempt` / `disconnection_attempt` | `social/apple/connection_attempt`               | app のみ        |
| `redelivery`                                   | `verification/emails/redelivery`                | app / com       |
| `telephones` scope workaround                  | `scope path: "telephones", module: :telephones` | app / com / org |

命名変更はルートヘルパー名の全参照置換（ビュー・コントローラ・テスト）を伴うため、横断的な変更になる。それぞれを個別スライスとして進める。

#### C-特別: `emergency_key` → `secrets` リネーム

`# FIXME: rename this to "secrets"` が明示的に書かれている（sign.rb line 198）。

**変更対象ファイル（調査済み）：**

| 対象                                                                   | 変更内容                                                                                     |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `config/routes/sign.rb`                                                | `resource :emergency_key` → `resource :secrets, controller: "secrets"`                       |
| `app/controllers/sign/app/settings/emergency_keys_controller.rb`       | ファイルをリネーム → `secrets_controller.rb`、モジュール名を `Secrets` に変更                |
| `app/views/sign/app/settings/emergency_keys/show.html.erb`             | ディレクトリを `secrets/` にリネーム                                                         |
| `config/locales/*/en.yml` と `*/ja.yml`                                | `sign.app.settings.emergency_key.*` キーを `sign.app.settings.secrets.*` に変更（4ファイル） |
| `test/controllers/sign/app/settings/emergency_keys_controller_test.rb` | ファイルをリネームしてヘルパー参照を更新                                                     |

これが「何がだめ？」かというと、**機能的な問題はない**。単純にファイルリネームとルートヘルパー参照の横断置換。`sign_app_settings_emergency_key_path`
→ `sign_app_settings_secrets_path` の変更が最も広範囲。

---

### カテゴリ D: アーキテクチャ上の移行作業

#### D-1: sign の settings コメント削除（訂正）

`sign.rb:493` の `# TODO: move settings to acme's identity entrypoints.` は廃止。passkey/totp/social
login の WebAuthn origin 制約により sign 側に残すことを決定した。コメントを削除する。

#### D-2: `web/v0` / `edge/v0` → `api/v0` への統合（実施予定）

`adr/api-route-vocabulary-consolidation.md`（2026-06-13
Accepted）で方向性は決定済み。ADR の分類ルールに従い、各エンドポイントを「実際の API」か「ceremony/operational」かを判定してから移行する。

**対象ファイル：**

- `config/routes/acme.rb`（`web/v0`、`edge/v0` ブロック × 3 面）
- `config/routes/sign.rb`（`web/v0`、`edge/v0` ブロック × 3 面）
- `config/routes/core.rb`（`web/v0`、`edge/v0` ブロック × 3 面）
- `config/routes/docs.rb`・`help.rb`・`news.rb`（`edge/v0` の `entries` ブロック × 各 3 面）

ADR の non-scope（`/auth/...`、`/sso/...`、`/.well-known/...`、`/health/...`、ceremony ルート、HTML ルート）は
`/api/v0` に移さない。

---

## 実施優先順序

```
~~A-2 (r18 dev 削除: acme.rb) — 実施済み~~
A-1 (r18 本番削除: sign.rb)
B コメント訂正 (B-1 get→resource 検討、B-2/B-3 FIXME/TODO コメント削除、D-1 TODO削除)
D-2 (web/v0・edge/v0 → api/v0 移行)
C (naming — emergency_key→secrets を先行、残りは個別スライス)
```

---

## 検証方法

```bash
bin/rails routes | grep <route_name>
bin/rails test test/controllers/sign/...
bin/rails test test/controllers/acme/...
bin/rails test test/controllers/public_robots_routing_test.rb
```

emergency_key → secrets リネーム後：

```bash
bin/rails test test/controllers/sign/app/settings/secrets_controller_test.rb
bin/rails routes | grep secrets
```
