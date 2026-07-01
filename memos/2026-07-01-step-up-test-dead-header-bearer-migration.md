# step-up / verification テストの死んだヘッダー移行で判明した2つの落とし穴

`X-TEST-CURRENT-*` 依存テストを実 JWT
(`Authorization: Bearer`) 認証へ移す作業（`plans/rails-test-hazy-teacup.md` /
`plans/abstract-brewing-thompson.md`）中に確認したフィールドノート。チェーンオブソートではなく、再発見を避けるための観測記録。

## 1. 死んだヘッダー由来の失敗は「422 無効なリクエストです」として現れる（401/302 ではない）

`X-TEST-CURRENT-USER` 等は `app/` `lib/` のどこからも読まれない（過去に意図的削除、
`test/unit/security/app_test_bypass_guard_test.rb`
がガード）。よってこれらのテストは実際には未認証。

未認証で `Auth::App::*` の保護エンドポイントに入ると、`authenticate_client!`
が未認証ユーザーをサインイン（OIDC
SSO）へ jump しようとするが、**`JumpRtSurface.namespace_for_controller`
（`app/services/jump_rt_surface.rb`）が `Sign::/Acme::/Core::/Base::` エンジンしか認識せず、
`Auth::` コントローラでは nil を返す** → `JumpRtIssuer` が `ArgumentError` → `CommonRedirect` が
`422 errors.messages.invalid_request`（"無効なリクエストです。"）を描画する。

含意:

- step-up テストの 422 は「step-up ガードの不具合」ではなく「そもそも認証が通っていない」サイン。ハーネス側の認証を Bearer 化すれば
  `require_step_up!` に到達し、期待の redirect が返る。
- 破棄/失効セッション（`discarded_at <= now`）は `ClientToken.currently_usable_at`
  （`app/models/concerns/token_status_management.rb`）で除外され認証自体に失敗するため、 `Auth::`
  配下では 302 ではなく 422 で弾かれる。テストでこのケースを検証するなら 302 を期待できない。（`load_jump_rt_env!`
  を呼んでも `Auth::` は namespace nil のままなので 422 は変わらない。）

## 2. DAMP 複製ヘルパーは「最後に定義された class 再オープンの版」が有効

これらのテストファイルは `class XxxTest ... end` を複数回再オープンし、`as_user_headers` /
`as_staff_headers` / `as_visitor_headers` / `host_headers` / `bearer_headers` /
`jwt_access_token_for`
を DAMP でそれぞれ複数回定義している。Ruby では**最後に定義されたメソッドが勝つ**。

`test/integration/verification_flow_test.rb` では `as_user_headers`
が4回定義され、先頭側（133行）は Bearer を付与する正しい版だったが、**末尾（849行）の版は死んだヘッダーだけを設定してBearer を付けない**ため、そちらが有効になり未認証 →
422 になっていた。

含意:

- ファイルを Bearer 化するときは、`grep -n "def as_user_headers"`
  で**全定義を列挙し、最後の版**を直す（または最後の版が既に Bearer なら OK）。先頭の版だけ直しても効かない。
- setup が `@headers = as_user_headers(...)` を使わず手組みしている場合は、そこを直接
  `bearer_headers(jwt_access_token_for(...))` にする（`step_up_authentication_test.rb`
  はこの形で解決）。
- `session_public_id:` を渡さないと `as_user_headers`
  は別トークンを新規作成して JWT をそれに束縛するため、テストが別途 `@token`
  を変異させても認証セッションに反映されない。テストが操作する `@token` に束縛したいときは
  `session_public_id: @token.public_id` を渡す。
- `host! @host`
  を setup で呼ぶこと。呼ばないとリクエストホストと JWT の発行ホスト/issuer が食い違い認証失敗する。

## 進捗（このクラスタ）

- 済:
  `step_up_authentication_test.rb`（setup 手組みを Bearer 化。revoked ケースは 422 拒否を期待に変更）
- 済: `verification_flow_test.rb`（有効な末尾 `as_*_headers` を Bearer 化 + `host!` +
  `session_public_id` 束縛）
- 未（認証以外の別要因が主）:
  - `app_step_up_verification_enforcer_test.rb` … リダイレクト先パスの期待ズレ（テスト期待
    `/verification`・`/verification/setup/new` vs 実挙動
    `/identity/emails/.../edit`）。step-up の redirect 先が仕様変更された可能性。要仕様確認。
  - `org_step_up_verification_enforcer_test.rb` … DAMP ヘルパー `response_has_cookie?`
    未定義（要ローカル定義）。
  - `withdrawal_gate_test.rb`
    … 一部は認証成功後の 302（`/oauth/authorize`）を success 期待していて食い違い。
