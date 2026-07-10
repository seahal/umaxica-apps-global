# OIDC RP ブラウザフロー テスト崩壊の調査と修正

## Context

`OidcRpBrowserFlowTest` が単体再実行でも広く失敗している（7 failures / 7
errors）。症状は 2 種類だが、いずれも単一の根本原因に帰着する:

- `/oidc/authorization` へのリクエストが `400 Bad Request`
- `ActiveRecord::RecordInvalid: リダイレクトURIを入力してください`（`redirect_uri` presence 失敗）

## 根本原因: base サーフェスのホストファミリ不整合（PRIVATE vs PUBLIC）

test 環境（`.env` 経由）の実測値:

| ENV                        | 値                   |
| -------------------------- | -------------------- |
| `PUBLIC_BASE_SERVICE_URL`  | `www.umaxica.app`    |
| `PRIVATE_BASE_SERVICE_URL` | `base.app.localhost` |
| `BASE_SERVICE_URL`         | 未設定               |

- アプリ側は一貫して **PUBLIC 系**:
  - `OidcClientStoresStaticClientStore#build_redirect_uris("BASE_SERVICE_URL", ...)` →
    `boot_host_for` → `boot_config.base_service`。`ConfigValues::HostFamilyValues.base_key` は
    `BASE_SERVICE_URL` 未設定時に
    `PUBLIC_BASE_SERVICE_URL`（=`www.umaxica.app`）へフォールバック。結果 `base-rails-rp`
    の redirect_uris は `https://www.umaxica.app/oidc/callback` 等。
  - `Base::App::ApplicationController#oidc_base_authority_host` / `oidc_sign_host` も
    `PUBLIC_BASE_SERVICE_URL`（`app/controllers/base/app/application_controller.rb:106-116`）。
- テスト側は **PRIVATE 系**:
  - `SURFACES` の host / acme_host は `ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost")` =
    `base.app.localhost`（`test/integration/oidc_rp_browser_flow_test.rb:10-27`）。
  - `config/routes/base.rb:16` の制約は `[www.umaxica.app, base.app.localhost]`
    両対応なのでリクエスト自体は base app サーフェスにルーティングされ、コントローラまで到達する。
- 破綻点: `OidcSsoInitiator#oidc_callback_url`
  （`app/controllers/concerns/oidc_sso_initiator.rb:140-146`）は
  `registry.redirect_uris.find { URI.parse(uri).host == request.host }`
  を行う。request.host=`base.app.localhost` はレジストリの `www.umaxica.app` 系に一致せず→
  `ActionController::BadRequest`（400）。テストの `redirect_uri_for`
  （同 test:782-786）も同ロジックで nil → `redirect_uri` presence バリデーション失敗。

`acme_host`
の assertion（`uri.host == surface[:acme_host]`）も、コントローラが PUBLIC を emit しテストが PRIVATE を期待するため同様に不一致になる。よって報告された全 failures/errors はこの単一原因。

## 修正方針: 案A（テストを PUBLIC 系に整合）を採用

アプリ本体・レジストリ・ルート・他の統合テストはすべて `PUBLIC_BASE_SERVICE_URL`
（=`www.umaxica.app`）を正典として使用済み。特に姉妹テスト
`test/integration/base_rp_browser_flow_test.rb:10` は
`ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")` で駆動し、OIDC
RP フロー（authorize→callback→session 確立→`/dashboard` redirect）が正常動作することを確認済み。
`oidc_rp_browser_flow_test.rb` だけが `PRIVATE_BASE_*`
を使う唯一の逸脱なので、この 1 ファイルを姉妹テストと同じ PUBLIC 正典に揃える。

案B（test 環境の host を `*.localhost` に統一）は不採用。`PUBLIC_BASE_*` を test 環境で変更すると
`www.umaxica.app` を assert する既存多数テストが連鎖崩壊し、影響範囲が過大。

### 編集対象: `test/integration/oidc_rp_browser_flow_test.rb` のみ

1. `SURFACES`（test:10-27）の host / acme_host を
   `ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")` /
   `PUBLIC_BASE_STAFF_URL`（`base.org.localhost`）/ `PUBLIC_BASE_CORPORATE_URL`
   （`base.com.localhost`）へ変更。姉妹テストの SURFACES 定義に合わせる。
2. 本文中の全
   `ENV.fetch("PRIVATE_BASE_SERVICE_URL", ...)`（計 ~25 箇所、test:63,143,194,264,332,436,463,501,519,550,558,581,647,680,689,739,746 等）を対応する
   `PUBLIC_BASE_*` へ一括置換。`PRIVATE_AUTH_SERVICE_URL`（test:64,333）は `PUBLIC_AUTH_SERVICE_URL`
   へ（コントローラ `oidc_sign_host` と一致）。
3. スキーム決め打ちの期待値を scheme-aware 化。PUBLIC ホストは `https`（localhost は
   `http`）になるため、ハードコードされた `http://#{acme_host}/`（test:709）や
   `http://#{surface[:host]}/dashboard|/`（test:739-742）を、既存ヘルパ（test:1439 の
   `host.include?("localhost") ? "http" : "https"`）で組み立てるよう修正。
4. `/logout` not-found 判定（test:763-767）の `"Host" => "www.app.localhost"`
   は 404 のみ検証でホスト非依存。PUBLIC ホスト（`base.app.localhost`
   既定）へ揃えるか、そのまま残置可。
5. 実行して残差の assertion 差分（姉妹テストで見られた `/` vs `/dashboard`
   等の landing 期待）を実挙動に合わせて補正する。

アプリ本体（コントローラ・concern・レジストリ・ルート・env）は無変更。

## 検証

- `bin/rails test test/integration/oidc_rp_browser_flow_test.rb`（全 green 化が目標）
- 回帰: `bin/rails test test/integration/base_rp_browser_flow_test.rb` と git
  status の OIDC 併走変更分（`social_auth_link_test.rb`, `social_auth_link_completion`
  系など）を確認。
