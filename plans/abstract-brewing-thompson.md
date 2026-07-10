# step-up / verification クラスタの `rails test` 失敗 — 原因特定と修正方針

## Context（なぜこの調査をしたか）

`bin/rails test` の残存失敗のうち、ユーザーが挙げた「step-up /
verification クラスタ」（settings/passkeys, settings/totps, verification/\*, withdrawal,
telephone/email registration など）が「Step-up authentication required」や
`422 Invalid request`（`無効なリクエストです。`）に寄っている。ハーネス（テスト側）の step-up 満たし方を直せば広く減りそう、という仮説の検証を依頼された。

本ファイルは **原因特定と修正方針の記録**。実装はまだ行っていない。

## 判明した事実（実行して確認済み）

`bin/rails test test/integration/step_up_authentication_test.rb` を実行した結果: **31 runs / 22
failures / 3 errors**。失敗の大半が期待する `redirect` の代わりに `422 Unprocessable Content` /
`無効なリクエストです。` を返していた。

ログ（テストの `config.logger` を一時的に STDOUT 化して取得）を追ったところ、
**422 は step-up ガードではなく `authenticate_client!`（認証 before_action）の失敗が原因**だった:

```
oidc.sso.redirect_policy.jump  surface=Auth::App::Settings::Emails::RegistrationsController
    request_host=auth.app.localhost target_host=www.umaxica.app target_path=/oauth/authorize
    decision=jump reason_code=site_mismatch
redirect_target.rejected  kind=external source=jump_rt_issue reason=invalid_jump_rt_url
Filter chain halted as :authenticate_client! rendered or redirected
Completed 422 Unprocessable Content
```

つまり流れは:

1. テストは `X-TEST-CURRENT-USER` / `X-TEST-SESSION-PUBLIC-ID` ヘッダーで認証したつもりでいる。
2. しかし **このヘッダーを読むコードは `app/` `lib/` に存在しない**（`grep` で全滅を確認。
   `AuthenticationBase#load_from_token` → `AuthenticationCurrentResourceResolver` はaccess cookie /
   `Authorization: Bearer` の実 JWT だけを見る）。
3. よって未認証。`authenticate_client!` が未認証ユーザーをサインイン（OIDC
   SSO）へ jump しようとするが、jump RT 発行に失敗（`invalid_jump_rt_url`）して
   `422 無効なリクエストです。` を返す。
4. step-up ガード（`VerificationBase#require_step_up!`）には **到達すらしていない**。

したがって「step-up の満たし方」の問題ではなく、**テストが実際には未認証のままリクエストしている**のが真因。step-up テストが検証したい redirect ロジックに到達させるには、まず本物の認証を通す必要がある。

### 既存プランとの関係

この根本原因は既存プラン `plans/rails-test-hazy-teacup.md` が全体像として診断済み（死んだ
`X-TEST-CURRENT-*` ヘッダー依存 → 実 JWT `Authorization: Bearer`
へ移行、約280ファイル規模）。本クラスタはその部分集合。ユーザー確認済みの「正しいパターン」もそこに記載されている。

### 対象ファイル（このクラスタ、いずれも死んだヘッダー依存を確認済み）

- `test/integration/step_up_authentication_test.rb`（setup の `@headers` が手組み。要 Bearer 化）
- `test/integration/app_step_up_verification_enforcer_test.rb`
- `test/integration/org_step_up_verification_enforcer_test.rb`
- `test/integration/verification_flow_test.rb`
- `test/integration/withdrawal_gate_test.rb`
- `test/controllers/auth/app/settings/passkeys_controller_test.rb`
- `test/controllers/auth/app/settings/totps_controller_test.rb`
- `test/controllers/auth/app/settings/emails_controller_test.rb`
- `test/controllers/auth/app/settings/emails/registrations_controller_test.rb`
- `test/controllers/auth/app/settings/telephones_controller_test.rb`
- `test/controllers/auth/app/settings/telephones/registrations_controller_test.rb`
- `test/controllers/auth/app/settings/withdrawals_controller_test.rb`
- （`verification_sessions_test.rb` は別の認証経路の可能性あり。着手時に個別確認）

## 修正方針

`plans/rails-test-hazy-teacup.md`
の確立済みパターンに従う。各ファイルのローカルヘルパー（DAMP 複製された `as_user_headers` /
`as_staff_headers` / `as_visitor_headers`）を、死んだ `X-TEST-CURRENT-*`
に加えて（または代えて）**実 JWT を `Authorization: Bearer` で載せる**よう拡張する。

step_up_authentication_test.rb は setup の `@headers`
を手組みしている点が特殊なので、そこを個別対応:

```ruby
# setup 内、@token 作成後
@headers = bearer_headers(
  jwt_access_token_for(@user, host: @host, session_public_id: @token.public_id, resource_type: "client"),
  host: @host,
).merge("X-TEST-SESSION-PUBLIC-ID" => @token.public_id) # 死んだヘッダーは残しても無害
```

再利用する既存ヘルパー（**このファイルに既に定義済み**、`step_up_authentication_test.rb:304-322,300-302`）:

- `jwt_access_token_for(resource, host:, session_public_id:, resource_type:)`
- `jwt_issuer_id_for_test_host(host, resource_type)`
- `bearer_headers(token, host:, headers:)`

トークン状態の補足: `ClientToken` の `currently_usable_at`
スコープ（`app/models/concerns/oidc_token_usage.rb:13`）は `revoked_at` と
`refresh_token_expires_at` だけを見る。status_id は見ないので、setup の
`user_token_status_id: ClientTokenStatus::NOTHING`
は認証解決の障害にならない（Bearer 化すれば認証は通る）。

認証が通れば `require_step_up!` に到達し、step-up 未充足時は `actor_verification_path`
への redirect を返すため、各テストの `assert_response :redirect` 等が満たされる想定。

### 進め方

1. まず `step_up_authentication_test.rb` 1 ファイルを Bearer 化し、`bin/rails test <file>`
   で 422 群が redirect に変わることを確認（パイロット）。
2. 残りのクラスタ各ファイルを、各自の `as_*_headers`
   に合わせて同様に拡張。ファイルごとに実行して確認。
3. 認証が直った後に残る失敗が「認証以外の既存バグ」なら、`hazy-teacup`
   プランの基準（独立検証可能・小さい・他テストを壊さない）を満たすものだけその場で直し、それ以外は記録して次へ。
4. `app/` `lib/` には手を入れない。ガードテスト（`test/unit/security/app_test_bypass_guard_test.rb`,
   `test/unit/security/forbidden_rails_patterns_test.rb`）が引き続き pass することを確認。

## 実装前の必須クリーンアップ

調査中に `config/environments/test.rb`
の logger 設定を一時変更している（プランモードのため未 revert）:

```ruby
# 現状（調査用に変更済み・要 revert）
config.logger = Logger.new(STDOUT)
config.log_level = :debug
# 本来（元に戻す）
config.logger = Logger.new(nil)
config.log_level = :fatal
```

実装の最初にこれを元へ戻す（`git checkout config/environments/test.rb` で可）。

## 検証

- パイロット: `bin/rails test test/integration/step_up_authentication_test.rb` →
  422 由来の failure が消え、step-up の redirect assertion が通ることを確認。
- クラスタ各ファイルを個別実行。
- 数ファイルごとにガードテスト2件を実行して pass を確認。
- クラスタ完了後、`bin/rails test` フルスイートで合計失敗数の減少を確認。
