# WEBAUTHN_ORIGIN / WEBAUTHN_APP_ORIGIN / WEBAUTHN_APP_RP_ID テスト ENV 問題の修正

## Context

`SignWebauthn#configured_webauthn_value` が
`ENV.fetch(key)`（引数1つ）を使っており、ENV に存在しないキーは `KeyError` を raise する。

WEBAUTHN_APP_RP_ID / WEBAUTHN_APP_ORIGIN /
WEBAUTHN_ORG_RP_ID 等はいずれも**任意**設定であり、設定がない場合は
`webauthn_rp_id → request.host`、`webauthn_origin → request.base_url`
にフォールバックする設計になっている。

しかし `ENV.fetch(key)`
が先に KeyError を raise するため、フォールバックに到達せずテスト環境でこれらの ENV を設定していない場合に多くのテストが失敗する。

`test/test_helper.rb` は `PUBLIC_AUTH_*_URL` を設定するが、 `WEBAUTHN_APP_RP_ID` /
`WEBAUTHN_APP_ORIGIN` は設定しておらず、それが原因でテスト失敗が多数発生している。

## 根本原因

```ruby
# app/controllers/concerns/sign_webauthn.rb:79
value = ENV.fetch(key).to_s.strip   # ← optional var に1引数 fetch → KeyError
```

AGENTS.md のルール「`ENV.fetch("NAME")` は**必須**設定に使う」を optional 設定に誤適用している。

## 修正方針

### 推奨: `ENV[key]` に変更（1行修正）

`configured_webauthn_value` の `ENV.fetch(key)` を `ENV[key]` に変更する。

- `ENV[key]` はキー不在で `nil` を返す（KeyError を raise しない）
- `nil.to_s.strip` は `""` → `blank?` 判定で次のキーへ進む
- フォールバック（`request.host` / `request.base_url`）が正常に機能する

```ruby
# before
value = ENV.fetch(key).to_s.strip

# after
value = ENV[key].to_s.strip
```

### Rails 8.2 credentials への移行は不要

`config/credentials/test.yml.enc`
に WEBAUTHN_APP_RP_ID 等を入れることもできるが、それはコードの bug を設定で補う回避策にすぎない。
`ENV.fetch`
の誤用を直す方が正しい。credentials は production の機密値（API キー等）向けの仕組みであり、テスト用の任意オーバーライドに使うのは設計上の誤り。

## 修正ファイル

- `app/controllers/concerns/sign_webauthn.rb` (line 79)

## 関連テスト

修正後、以下のテストが ENV を明示設定なしで正常動作するはず：

- `test/controllers/concerns/sign/webauthn/config_test.rb`
  - `webauthn_rp_id returns request host`
  - `webauthn_origin returns request base_url`
  - `validate_webauthn_origin! raises error for untrusted origin`
- `test/unit/webauthn_config_test.rb`（既存テストはすべて通る）
- `test/controllers/auth/app/settings/passkeys_controller_test.rb`（ENV 未設定時の動作）

## Verification

```bash
# 単体
bin/rails test test/controllers/concerns/sign/webauthn/config_test.rb
bin/rails test test/unit/webauthn_config_test.rb

# パスキー関連まとめて
bin/rails test test/controllers/auth/app/settings/passkeys_controller_test.rb
bin/rails test test/controllers/auth/org/in/challenge/passkeys_controller_test.rb

# フル
bin/rails test
```
