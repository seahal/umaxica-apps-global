# omniauth_callbacks はオブジェクトレベル認可の対象外（2026-05-30）

## 結論

`Sign::App::Auth::OmniauthCallbacksController` および `Sign::Org::Auth::OmniauthCallbacksController`
には ActionPolicy の
`authorize!`/`authorized_scope`（オブジェクトレベル認可）を**追加しない**。これは認可レイヤではなく認証 /
state 検証主体のエンドポイントであり、object-level
authorize の対象が存在しない、もしくは追加すると誤って正規フローを壊すため。

## 確認したこと

- 両コントローラとも `AUTHENTICATION_MODE = :deny_all` +
  `declare_authentication_mode! :open, only: %i(omniauth failure)`。コールバックは未認証ログインを許可するために
  `:open`。
- 3 つの intent:
  - **login**: この時点で認証済み actor は存在しない（このエンドポイントの目的がセッション確立）。authorize 対象の actor がない。identity レコードはサービスが解決済み user に紐づけて生成/参照する。
  - **sign_up**: 同上。フローは state machine と advisory lock で保護。
  - **link**: `SocialAuthConcern#prepare_social_auth_intent!` が `intent == "link" && !logged_in?`
    を弾く（social_auth_concern.rb:60）。連携先は常に
    `current_resource`（ログイン中の本人）に固定され、他ユーザの identity を作る経路がない＝本質的に owner-self。
- 既存の防御層: 認証モード強制（`enforce_access_policy!`）、`validate_social_auth_state!`（CSRF/replay）、
  `SocialAuth::VerifiedProviderAssertion`（provider 検証）、`SocialCallbackGuard`、intent のセッション束縛。これらが本来の保護レイヤ。

## なぜ authorize! を入れないか

- login/sign_up: 認可すべき record も actor も無い（authorize! は記述不能 or 無意味）。
- link: 連携は current_resource 限定で他者レコードへの到達経路が無いため、object
  authz が閉じる攻撃面が state 検証 + intent 束縛で既に閉じている。`authorize!`
  を足しても重複で、かつ未認証 login 経路に誤って適用すると 403 回帰のリスク。

## フォローアップ

- 連携解除（unlink）側はオブジェクト認可済み（OIDC connection destroy = owner、別 PR）。
- 将来、operator が他 staff の連携を管理する管理画面が増える場合は、その新コントローラで改めて object-level 認可を設計すること（このエンドポイントとは別物）。
