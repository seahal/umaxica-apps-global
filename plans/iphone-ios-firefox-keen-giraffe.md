# iOS Firefox ページ再ロード問題の修正計画

## Context

iPhone の Firefox（FxiOS）でログインフロー（Google/Apple ソーシャル認証）を行うと、「再読み込みしないとページが動かない」症状が起きている。

ログ（`log/development.log:344419`）の再現確認で以下が確定した：

```json
{"event":"oidc.rp.callback.invalid_state","data":{"reason":"OIDC state mismatch",
"client_id":"base-rails-rp","host":"www.umaxica.app",
"grant_present":true,"csrf_present":true}}
Completed 422 Unprocessable Content in 13ms
```

---

## 確定した根本原因

**iOS Firefox の BFCache が OIDC コールバック URL を再リクエストし、消費済みの OIDC
state で 422 を引き起こしている。**

`app/controllers/concerns/oidc_callback.rb:40` の `validate_state!` は：

```ruby
def validate_state!
  expected = session.delete(:oidc_state).to_s   # ← 1 回目で session から消える
  actual = params[:state].to_s
  unless expected.present? && actual.present? && ...
    raise InvalidCallbackState, "OIDC state mismatch"
  end
end
```

1. ユーザーが Google/Apple 認証開始 → `session[:oidc_state]` に nonce 保存
2. IDP がコールバック URL（`/acme/app/auth/callbacks?code=XXX&state=YYY`）にリダイレクト
3. **1 回目**: `session.delete(:oidc_state)` で state 消費 → 認証成功 → ログイン完了
4. iOS Firefox が BFCache でコールバック URL をページ復元 or 再リクエスト
5. **2 回目**: session に `:oidc_state` がない → `expected.present?` が false → 422

ログの `grant_present: true, csrf_present: true` は「URL の `code` と `state`
パラメータはあるが session 側の state がもう存在しない」状態を示している。

**`Acme::App::Auth::CallbacksController` に `Cache-Control: no-store` が設定されていない**
ため、コールバックページが BFCache の対象になっている。（`acme_oauth_token_endpoint.rb`、`sign_up_sequence_controller_support.rb`
等は既に `no-store` を設定済みだが、OIDC コールバック concern は未対応）

---

## 修正方針

`OidcCallback` concern の `show` の冒頭、または `before_action` で `Cache-Control: no-store`
を設定する。

これにより：

- iOS Firefox（および全ブラウザ）が OIDC コールバックページを BFCache に保存しない
- `code` / `state` を含む URL がキャッシュ経由で再利用されない
- OAuth 2.0 のセキュリティベストプラクティス（RFC 6749 §10.3）にも準拠

---

## 実装

**ファイル**: `app/controllers/concerns/oidc_callback.rb`

```ruby
def show
  response.set_header("Cache-Control", "no-store")   # ← 追加
  validate_state!
  token_result = exchange_code!
  ...
end
```

または `before_action` として分離：

```ruby
included do
  before_action :set_no_store_for_oidc_callback, only: :show
end

def set_no_store_for_oidc_callback
  response.set_header("Cache-Control", "no-store")
end
```

既存パターン（`sign_dbsc_registration_endpoint.rb:11`、`acme_oauth_endpoint.rb:14` 等）と同じ
`response.set_header("Cache-Control", "no-store")` を使う。

---

## 対象ファイル

| ファイル                                    | 変更内容                                 |
| ------------------------------------------- | ---------------------------------------- |
| `app/controllers/concerns/oidc_callback.rb` | `show` に `Cache-Control: no-store` 追加 |

---

## 検証

1. `bin/rails test test/controllers/concerns/oidc/` で既存 OIDC callback テストが通ることを確認
2. iPhone Firefox で Google/Apple ログインフローを実行し、認証後に戻るボタンを押す
3. BFCache 復元が走っても 422 が出ず、ログイン済み状態のままであること（または sign-in にリダイレクト）を確認
4. レスポンスヘッダーに `Cache-Control: no-store` が付いていることを DevTools で確認
