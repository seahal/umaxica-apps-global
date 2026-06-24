# OIDC SSO Callback Return-To リスク確認レポート

## 目的

read-only 調査として、OIDC SSO / callback return-to 周辺の未確認リスク2点を確認する。

---

## 調査1: Jump redirect 実装

### Jump コントローラの実体

| コンポーネント                     | ファイル                                                  | 状態                                 |
| ---------------------------------- | --------------------------------------------------------- | ------------------------------------ |
| `JumpToRedirector` concern         | `app/controllers/concerns/jump_to_redirector.rb`          | **routes に未マウント**              |
| `JumpRtReturnVerification` concern | `app/controllers/concerns/jump_rt_return_verification.rb` | `Acme::App` / `Core::App` に include |
| `CommonRedirect` concern           | `app/controllers/concerns/common_redirect.rb`             | jump 発行メソッド群を提供            |

### Jump endpoint の authentication guard 有無

**`JumpToRedirector` は routes に一切マウントされていない。**

- `config/routes/{acme,sign,core,base,palm,help,docs,news}.rb` のどこにも `JumpToRedirector`
  を使うルートは存在しない。
- 「jump ページへのリクエスト」自体が現時点では不可能。

**`JumpRtReturnVerification` (`verify_jump_return_rt!`) の before_action 順序:**

- `Core::App::ApplicationController` line 44 — rate limiting より前
- `Acme::App::ApplicationController` line 52 — rate limiting より前
- **Sign サーフェスには include されていない**（`test/integration/jump_rt_return_verification_test.rb`
  line 85-89 で明示的に確認済み）

### Jump 経路で `authenticate!` が二重実行される可能性

**低リスク（現時点では不可能）。**

`verify_jump_return_rt!` は `rt` パラメータを検証後にリダイレクトするだけで、`authenticate!`
を呼ばない。  
`JumpToRedirector` 自体は routes 未マウントなのでアクセスできない。

ただし、将来 routes にマウントする場合の懸念:

- `authentication_base.rb` line 671-684 の `authenticate!` が呼ばれると `session[:oidc_pt]` を
  **新しい `request.original_url`（jump ページの URL）で上書きする**。
- `oidc_sso_initiator.rb` line 43 が `session[:oidc_pt] = safe_oidc_pt(pt)`
  で再設定するため、元の destination が失われる。

### Jump 経路で `oidc_pt` が上書きされる可能性

**現状: 不可（routes 未マウントのためアクセス不能）。**  
将来マウント時: `authenticate!` が走れば `oidc_pt` が上書きされる構造的リスクあり。

### Same-site Acme authorize の経路

`oidc_sso_initiator.rb` line 75 の `oidc_redirect_decision(url)` が `:direct` / `:jump`
を切り替える。

- **Same-site**: `:direct` → `redirect_to(url, allow_other_host: true)` — jump を経由しない。
- **Cross-site**: `:jump` → `redirect_to_jump_url(url, ...)` — jump gateway 経由。

---

## 調査2: OIDC callback controller 一覧

### controller 一覧（12本）

| Service | Surface | ファイル                                                |
| ------- | ------- | ------------------------------------------------------- |
| Sign    | app     | `app/controllers/sign/app/oidc/callbacks_controller.rb` |
| Sign    | org     | `app/controllers/sign/org/oidc/callbacks_controller.rb` |
| Sign    | com     | `app/controllers/sign/com/oidc/callbacks_controller.rb` |
| Acme    | app     | `app/controllers/acme/app/auth/callbacks_controller.rb` |
| Acme    | org     | `app/controllers/acme/org/auth/callbacks_controller.rb` |
| Acme    | com     | `app/controllers/acme/com/auth/callbacks_controller.rb` |
| Base    | app     | `app/controllers/base/app/auth/callbacks_controller.rb` |
| Base    | org     | `app/controllers/base/org/auth/callbacks_controller.rb` |
| Base    | com     | `app/controllers/base/com/auth/callbacks_controller.rb` |
| Core    | app     | `app/controllers/core/app/auth/callbacks_controller.rb` |
| Core    | org     | `app/controllers/core/org/auth/callbacks_controller.rb` |
| Core    | com     | `app/controllers/core/com/auth/callbacks_controller.rb` |

### 共通 concern

**全12本が `OidcCallback` concern を include し、`show` をオーバーライドしていない。**

```ruby
# oidc_callback.rb line 30（成功パス）
redirect_to(consume_oidc_pt, allow_other_host: false)

# oidc_callback.rb line 77-79
def consume_oidc_pt
  session.delete(:oidc_pt).presence || "/"
end
```

### surface ごとの callback override

**なし。** サービス・サーフェス間の差異は `oidc_client_id` の設定値と actor
provisioning クラス名のみ。redirect logic は全サーフェス同一。

### failure path の差異

失敗時 `sign_in_url_with_pt(nil)` は surface ごとに異なる URL を返す:

- **com (Visitor)**: `sign_com_sign_in_url`
- **org (Operator)**: `sign_org_sign_in_url`
- **app (Client)**: `sign_app_sign_in_url`

これは正常な設計（各サーフェスのサインイン起点へ戻す）。

### `consume_oidc_pt` 以外の redirect logic

**成功パスには存在しない。**  
`OidcCallback#show` の redirect は line 30 の `consume_oidc_pt` のみ。

---

## 調査3: 既存テストの固定状況

| シナリオ                                                 | テスト有無                        | ファイル                                                            |
| -------------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------- |
| Sign settings → Authorize → Callback → settings 往復     | **あり**                          | `test/integration/sign_app_oidc_browser_flow_test.rb` line 23-102   |
| callback 後のセッションクリーンアップ                    | あり                              | 同上 + `test/controllers/concerns/oidc/callback_test.rb`            |
| `oidc_pt` fallback "/"                                   | あり                              | `test/controllers/concerns/oidc/callback_test.rb`                   |
| return-to の sanitization (外部ホスト/スキーム/制御文字) | あり                              | `test/controllers/concerns/oidc/sso_initiator_test.rb` line 119-158 |
| **Acme authorize URL が final return-to にならない**     | **なし（ギャップ）**              | —                                                                   |
| **jump ページで auth guard が走らない**                  | **なし（OIDC 文脈では未テスト）** | —                                                                   |
| callback URL への `pt` パラメータ注入防止                | なし                              | —                                                                   |

---

## 結論

### 各リスク評価

| 確認項目                                           | 結論                                                                  |
| -------------------------------------------------- | --------------------------------------------------------------------- |
| Jump redirect 実装の場所                           | `app/controllers/concerns/jump_to_redirector.rb`（routes 未マウント） |
| Jump endpoint の authentication guard              | **guard なし、ただし routes 未マウントのためアクセス不能**            |
| Jump 経路で `authenticate!` が二重実行される可能性 | **現状ゼロ**（routes 未マウント）。将来マウント時は要注意             |
| Jump 経路で `oidc_pt` が上書きされる可能性         | **現状ゼロ**。将来マウント時は構造的リスクあり                        |
| OIDC callback controller 一覧                      | 12本、全サーフェス共通 `OidcCallback` concern                         |
| surface ごとの callback override 有無              | **なし**                                                              |
| `consume_oidc_pt` 以外の redirect logic 有無       | **なし**                                                              |
| Sign settings 起点の return-to test の有無         | **あり**（`sign_app_oidc_browser_flow_test.rb`）                      |
| Acme authorize URL 汚染が現コードで起き得るか      | **起き得ない**（現コード構造上）。ただし regression test なし         |

### `/session-limit-resolution` → `/sign/in/limitation` rename を始めてよいか

**始めてよい。** 今回の調査で、rename を阻害するリスクは発見されなかった。

### rename 前に追加すべき invariant test

必須ではないが、推奨:

1. **Acme authorize URL が `session[:oidc_pt]` に入らないことのテスト**  
   `safe_oidc_pt` に Acme authorize URL（`/oauth/authorize?...`）を渡したとき、reject または `/`
   に fallback することを assert。  
   対象: `test/controllers/concerns/oidc/sso_initiator_test.rb` に追加。

2. **`session-limit-resolution` の旧パスへのリクエストが 404 または redirect を返すルートテスト**  
   rename 後に旧パスが残っていないことを固定するため。

3. **`consume_oidc_pt` がデフォルト `/` を返すことのテスト**（既存で一部カバー済み、確認のみ）

---

## 参照ファイル

- `app/controllers/concerns/oidc_callback.rb`
- `app/controllers/concerns/oidc_sso_initiator.rb`
- `app/controllers/concerns/jump_to_redirector.rb`
- `app/controllers/concerns/jump_rt_return_verification.rb`
- `app/controllers/concerns/common_redirect.rb`
- `app/controllers/concerns/authentication_base.rb`
- `test/integration/sign_app_oidc_browser_flow_test.rb`
- `test/controllers/concerns/oidc/callback_test.rb`
- `test/controllers/concerns/oidc/sso_initiator_test.rb`
- `test/integration/jump_rt_return_verification_test.rb`
