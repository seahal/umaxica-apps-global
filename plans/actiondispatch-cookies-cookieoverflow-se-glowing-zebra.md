# CookieOverflow 調査レポート (session cookie 4111 bytes)

## Context

- 観測されたエラー:
  `ActionDispatch::Cookies::CookieOverflow (session cookie overflowed with size 4111 bytes)`
- 発生スタック: `actionpack/middleware/cookies.rb:616 check_for_overflow!` →
  `EncryptedKeyRotatingCookieJar#commit` → `Session::CookieStore#set_cookie` →
  `Rack::Session::Persisted#commit_session`
- log の場所: `log/development.log:67520` 周辺
- 発生タイミング: `Sign::App::Social::Apple::ConnectionsController#create`
  (`/social/auth/apple/continue`) が `/auth/apple?state=...` へ redirect した直後、OmniAuth Apple の
  **request phase** 終了時 (Rack が session を cookie に書き戻す瞬間)。

## ログから読める発生フロー

`development.log` の連番（直前のリクエスト処理）:

1. L67437 `Processing by Sign::App::Social::Apple::ConnectionsController#create as HTML`
2. L67440〜67475 で以下が DB に書き込まれる（これらは原因ではないが、副作用として session も同時に大量に膨らむ）
   - `ClientOauthCallbackState` 発行
   - `ClientSocialCeremonyTransaction` 発行（grant_jti, transaction_id 生成）
   - `ClientSignUpFlow` 発行 + state machine 遷移
3. L67504 `Redirected to https://id.umaxica.app/auth/apple?state=[FILTERED]`
4. L67509〜67518 別リクエスト（`/auth/apple`）に入って OmniAuth Apple strategy がさらに
   `ClientOauthCallbackState`（state_digest 違い）を発行
5. L67520 で **コミット時に CookieOverflow**（4111 bytes = 上限 4096 を 15 bytes 超過）

つまり cookie が膨らみ切るのは「Apple へリダイレクトする直前」もしくは「OmniAuth request
phase で omniauth.\* キーが追加されたとき」。15 bytes 超過なので「あと一押し」で吹いている。

## session に積まれているキー（推定累積量）

実コードを `grep "session\[" app/controllers/**` から抽出。Apple
sign-up エントリ通過時に高確率で同居しているもの:

| 由来                                                                                                          | キー                                                     | サイズ目安                                                            |
| ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------- |
| `OidcSsoInitiator#initiate_oidc_session!`                                                                     | `:oidc_code_verifier`                                    | 64 chars (urlsafe_base64 48)                                          |
|                                                                                                               | `:oidc_state`                                            | 43 chars                                                              |
|                                                                                                               | `:oidc_nonce`                                            | 43 chars                                                              |
|                                                                                                               | `:oidc_pt`                                               | **可変・最悪 数百 bytes**（URL or 署名トークン）                      |
| `Sign::*::Up/InController`                                                                                    | `:oidc_authorization_login_challenge`                    | 43 chars                                                              |
| `AuthenticationRedirects`                                                                                     | `:authentication_pt_nonce`                               | 33 chars                                                              |
|                                                                                                               | `:authentication_return_target_nonce`                    | 33 chars                                                              |
| `SocialAuth#store_social_auth_intent_context`                                                                 | `:social_auth_intent`                                    | 数 bytes                                                              |
|                                                                                                               | `:social_auth_started_at`                                | 10 bytes                                                              |
|                                                                                                               | `:social_auth_flow_id`                                   | 32 chars (`SecureRandom.hex(16)`)                                     |
|                                                                                                               | `:social_auth_provider`                                  | "apple" 等                                                            |
|                                                                                                               | `:social_auth_entry`                                     | "sign_up" 等                                                          |
|                                                                                                               | `:social_auth_ri`                                        | "jp" 等                                                               |
|                                                                                                               | `:social_auth_pt`                                        | **可変・最悪 数百 bytes**（`signed_pt_token` の戻り値が JWT のとき）  |
| `SocialAuth#store_oauth_callback_state`                                                                       | `:social_auth_state`                                     | 48 chars (`SecureRandom.hex(24)`)                                     |
|                                                                                                               | `:social_auth_state_started_at`                          | 10 bytes                                                              |
|                                                                                                               | `:social_auth_state_used_at`                             | nil                                                                   |
|                                                                                                               | `:social_auth_state_provider`                            | "apple"                                                               |
| `SocialAuth#store_social_ceremony_grant!`                                                                     | `:social_ceremony_grant`                                 | 36 chars (UUID, JWT ではない。既に対策済み)                           |
| `SignSocialAuthenticationEndpoint#issue_sign_up_flow!`                                                        | `:sign_app_up_sequence_id`                               | 22 chars (public_id)                                                  |
| Lifecycle / language / TZ                                                                                     | `:language`, `:timezone`, `:public_id`, `:visitor_id` 系 | 各 10〜30 bytes                                                       |
| OmniAuth (`omniauth-2.1.4/strategy.rb:238,323,330,332`)                                                       | `omniauth.state`                                         | 43+ chars                                                             |
|                                                                                                               | `omniauth.nonce`                                         | 24 chars (`SecureRandom.urlsafe_base64(16)`)                          |
|                                                                                                               | `omniauth.params`                                        | **`request.GET` 全部**（`state` クエリを含むので 50〜100 bytes 追加） |
|                                                                                                               | `omniauth.origin`                                        | referer 全体 (URL)                                                    |
| `SocialCallbackGuard.capture_request_state!` (`config/initializers/omniauth.rb:162` で `after_request_phase`) | 上の `SOCIAL_STATE_*` 4 つを **二重に**書き直す          | 同上                                                                  |

cookie に乗るのは MessagePack エンコード後にさらに暗号化 + base64 されたもの。raw
bytes が ~2.5KB あれば最終的に 4KB を超える。

## 真因の絞り込み

すべてのキーを足して 4111 bytes ジャストにしているのは以下のどれか（複数の可能性大）:

1. **`session[:social_auth_pt]` に長い signed pt（JWT）が入っている**
   - `signed_pt_token`（`app/controllers/concerns/authentication_redirects.rb:207`）は内部パスでなければ
     `issue_authentication_path_target_token` で JWT を発行して返す。JWT は claims（flow, surface,
     session_nonce, pt, iat, exp, jti...）入りで 400〜600 bytes は容易に出る。
   - `store_social_auth_intent_context` が `session[SOCIAL_PT_SESSION_KEY] = pt`
     で丸ごと格納（`app/controllers/concerns/social_auth.rb:78`）。
2. **`session[:oidc_pt]` も同じパターンで JWT を格納している可能性**（`oidc_sso_initiator.rb:43`）。
3. **`omniauth.origin` が長い URL** — `omniauth_authorize_path` で `?state=...`
   を付けて redirect しているが、referer は元の sign-in/sign-up URL を全部書き込む。
4. `SocialCallbackGuard.capture_request_state!` の **二重書き込み**（`store_oauth_callback_state`
   直後に再代入）。データは同じだが Marshal キー数を増やす。

確度の高い順は **1 > 2 > 3 > 4**。L67504 の `?state=[FILTERED]`
がフィルター後でも極端に長くなければ、最大の単一キーは `:social_auth_pt`。

## 推奨対応（実装方針）

短期（cookie store のまま 4KB に戻す）

- A) **`session[:social_auth_pt]` を廃止し、`return_to` の path 文字列だけ session に保持する**
  - 現在 `signed_pt_token` の戻り値（JWT 可能）を保存しているが、内部ではすでに
    `path_from_signed_pt` で検証して使う。Apple callback の時点で `params[:pt]`
    を再検証できるなら、session に置く必要は本質的にない。
  - 代替: `ClientSocialCeremonyTransaction.return_to`
    カラムに保存しているので、session には transaction_id だけ（既に :social_ceremony_grant にある）持ち、callback 側で transaction から
    `return_to` を取り出す。
- B) **`omniauth.origin` を抑制**: `OmniAuth.config.before_request_phase` で `env["HTTP_REFERER"]`
  を消す、もしくは `request_phase` 直前に short path に置き換える。
- C) **`SocialCallbackGuard.capture_request_state!` の二重書き込みを止める**:
  `store_oauth_callback_state` が既に同じキーを書いているので、`after_request_phase`
  での再代入は冗長。`omniauth.state` が `store_oauth_callback_state`
  の state と一致することを assert して、session 側は触らない。

中期

- D) **session backend を `cache_store` (Solid Cache 経由) に切り替える**: `:social_auth_pt` /
  `:oidc_pt` のような可変長 token は cookie に乗せたくない。`config/initializers/session_store.rb`
  で `Rails.application.config.session_store :cache_store, key: "_jit_session", expire_after: ...`
  等。
- E) **複数の `social_auth_*`
  キーを 1 つの hash にまとめ、不要なフィールド (`social_auth_state_used_at`
  の nil 等) は格納しない**。

短期の (A) と (C) だけで通常 800〜1000 bytes 削れるはずなので、まず A→C の順で適用するのが最小修正。

## 変更対象（最小修正の場合）

- `app/controllers/concerns/social_auth.rb`
  - `store_social_auth_intent_context` の `SOCIAL_PT_SESSION_KEY`
    書き込み撤廃（または「path 文字列のみで JWT は保存しない」分岐）
  - `current_social_auth_pt` の参照箇所をすべて `ClientSocialCeremonyTransaction` 経由に置き換える
- `app/controllers/concerns/social_callback_guard.rb`
  - `capture_request_state!` の `SOCIAL_STATE_*` 再代入を撤廃（または「未設定のときだけ書く」へ）
- `config/initializers/omniauth.rb`
  - 必要なら `OmniAuth.config.before_request_phase = ->(env) { env.delete("HTTP_REFERER") }`
    を追加して `omniauth.origin` の肥大化を防ぐ（Cookie store を残すなら）
- 影響テスト
  - `test/integration/sign/route_host_test.rb`（既に M）
  - `test/services/identity/social_ceremony_contract_test.rb`（既に M）
  - `test/controllers/acme/oauth_oidc_authority_test.rb`

## Verify

```bash
# 1. cookie 容量が抑えられているか確認するための回帰テスト
bin/rails test test/integration/sign/route_host_test.rb

# 2. Apple sign_up の request phase を local dev で再現してログを確認
#    /sign/up から Apple をクリックして /auth/apple へ遷移、CookieOverflow が出ないこと
tail -f log/development.log

# 3. 中期 D を取る場合は session_store の変更後、ログイン～OAuth/OIDC～Apple の往復で
#    session が cache_store 側に保存されることを確認（rails console で
#    Rails.cache.read("session:...")）
```

## Open Questions

1. `:oidc_pt` / `:social_auth_pt`
   を「path のみ」に縮められない (= 必ず JWT で保持しなければならない) 業務制約があるか？ ある場合は中期 D の cache_store 化が事実上必須。
2. 直前の commit (`1c5fcd525` 〜) で `oidc_client_assertion_jwt.rb` や
   `identity_social_ceremony_candidate_store.rb`
   が変わっており、grant 発行のペイロードが太った可能性。ここを確認すれば「最近の回帰」と「もとから際どかった」の切り分けが付く。
