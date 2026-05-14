# 優先度 B - Controller `any_instance.stub` 移行計画

## 概要

Controllerの `any_instance.stub` を使用しているテストを古典学派（Classical/London
School）に移行します。

## 対象ファイルリスト

### グループ 1: `refresh_token_expires_at` パターン（時間操作系）

| #   | ファイルパス                                                           | 行数           | stub対象メソッド            |
| --- | ---------------------------------------------------------------------- | -------------- | --------------------------- |
| 1   | `test/controllers/sign/app/edge/v0/token/refreshes_controller_test.rb` | 58, 62, 91, 95 | `:refresh_token_expires_at` |
| 2   | `test/controllers/sign/org/edge/v0/token/refreshes_controller_test.rb` | 71, 75         | `:refresh_token_expires_at` |
| 3   | `test/controllers/apex/app/web/v0/cookie_controller_test.rb`           | 71             | `:refresh_token_expires_at` |
| 4   | `test/controllers/apex/com/web/v0/cookie_controller_test.rb`           | 52             | `:refresh_token_expires_at` |
| 5   | `test/controllers/apex/org/web/v0/cookie_controller_test.rb`           | 57             | `:refresh_token_expires_at` |

**変換方法**: TimeHelpersの `freeze_time` または `travel_to` を使用

### グループ 2: Verification 系（ステップアップ認証）

| #   | ファイルパス                                                         | 行数                | stub対象メソッド                                                                |
| --- | -------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------- |
| 1   | `test/controllers/sign/org/verification/passkeys_controller_test.rb` | 27-29               | `:available_step_up_methods`, `:prepare_passkey_challenge!`, `:verify_passkey!` |
| 2   | `test/controllers/sign/app/verification/passkeys_controller_test.rb` | 20-22, 42-43        | `:available_step_up_methods`, `:prepare_passkey_challenge!`, `:verify_passkey!` |
| 3   | `test/controllers/sign/app/verification/emails_controller_test.rb`   | 27-28, 44, 59-60... | `:available_step_up_methods`, `:send_email_otp!`, `:verify_email_otp!`          |
| 4   | `test/integration/org_verification_flow_test.rb`                     | 39, 55-57           | 同上                                                                            |
| 5   | `test/integration/org_step_up_verification_enforcer_test.rb`         | 94-96               | 同上                                                                            |
| 6   | `test/integration/verification_flow_test.rb`                         | 59-61               | 同上                                                                            |
| 7   | `test/integration/verification_sessions_test.rb`                     | 59                  | `:verify_totp!`                                                                 |

**変換方法**: Service層への依存注入または、実際のリクエストレスポンスでテスト

### グループ 3: ログイン・認証結果系

| #   | ファイルパス                                                           | 行数     | stub対象メソッド                                     |
| --- | ---------------------------------------------------------------------- | -------- | ---------------------------------------------------- |
| 1   | `test/controllers/sign/org/in/secrets_controller_test.rb`              | 160      | `:log_in`                                            |
| 2   | `test/controllers/sign/org/in/passkeys_controller_test.rb`             | 135, 262 | 複数メソッド                                         |
| 3   | `test/controllers/sign/app/in/passkeys_controller_test.rb`             | 351, 378 | `:complete_sign_in_or_start_mfa!`, `:with_challenge` |
| 4   | `test/controllers/sign/org/auth/omniauth_callbacks_controller_test.rb` | 99       | ログイン関連                                         |

**変換方法**: Service層のモック化または、データベース状態での検証

### グループ 4: 電話番号登録系

| #   | ファイルパス                                                                          | 行数                    | stub対象メソッド                                                            |
| --- | ------------------------------------------------------------------------------------- | ----------------------- | --------------------------------------------------------------------------- |
| 1   | `test/controllers/sign/org/configuration/telephones/registrations_controller_test.rb` | 63, 67                  | `:current_registration_telephone`, `:complete_staff_telephone_verification` |
| 2   | `test/controllers/sign/app/configuration/telephones/registrations_controller_test.rb` | 154, 178, 201, 224, 241 | 同上 + `set_registration_session`                                           |

**変換方法**: セッション操作の代替実装または、実際のフローでテスト

### グループ 5: 個別ケース

| #   | ファイルパス                                                          | 行数 | stub対象メソッド                          |
| --- | --------------------------------------------------------------------- | ---- | ----------------------------------------- |
| 1   | `test/controllers/sign/org/configuration/passkeys_controller_test.rb` | 103  | `OperatorPasskey.any_instance.stub(:valid?)` |
| 2   | `test/controllers/apex/app/web/v0/cookie_controller_test.rb`          | 141  | `:issue_access_token_from`                |

## 変換戦略

### 戦略 A: TimeHelpers による時間操作（グループ 1）

**現在のコード**:

```ruby
controller = Sign::App::Edge::V0::Token::RefreshesController
expires_at = Time.utc(2034, 4, 5, 6, 7, 8)

controller.any_instance.stub(:refresh_token_expires_at, expires_at) do
  post "/edge/v0/token/refresh", ...
end

assert_in_delta expires_at.to_i, response_cookie_expiry("preference_consented").to_i, 1
```

**変換後のコード**:

```ruby
freeze_time do
  expires_at = Time.utc(2034, 4, 5, 6, 7, 8)

  travel_to(expires_at) do
    post "/edge/v0/token/refresh", ...
  end

  assert_in_delta expires_at.to_i, response_cookie_expiry("preference_consented").to_i, 1
end
```

**手順**:

1. `test/test_helper.rb` で `ActiveSupport::Testing::TimeHelpers` を include しているか確認
2. `freeze_time` でテスト全体をラップ
3. stub化していた時間値を `travel_to` で設定
4. 期待値も同じ時間値を使用

### 戦略 B: Service層への切り出し（グループ 2, 3）

**現在のコード**:

```ruby
Sign::App::Verification::BaseController.any_instance.stub(:available_step_up_methods, [:passkey]) do
  Sign::App::Verification::PasskeysController.any_instance.stub(:prepare_passkey_challenge!, true) do
    Sign::App::Verification::PasskeysController.any_instance.stub(:verify_passkey!, true) do
      get sign_app_verification_url(...)
    end
  end
end
```

**変換後のアプローチ（選択肢）**:

**選択肢 B1: 統合テストとして実際のフローでテスト**

```ruby
test "creates verification on success via real flow" do
  return_to = Base64.urlsafe_encode64(sign_app_configuration_passkeys_path(ri: "jp"))

  # 実際のステップアップ認証フローを実行
  user = users_with_passkey(:one)  # passkeyを持つフィクスチャを準備

  get sign_app_verification_url(scope: "configuration_passkey", return_to: return_to), ...

  follow_redirect!
  assert_response :success

  post sign_app_verification_passkey_url, params: {
    credential: valid_passkey_credential_for(user)
  }

  assert_response :redirect
  assert_redirected_to sign_app_configuration_passkeys_url(ri: "jp")
end
```

**選択肢 B2: Service層のモック化**

```ruby
test "creates verification on success with service mock" do
  return_to = Base64.urlsafe_encode64(sign_app_configuration_passkeys_path(ri: "jp"))

  # Serviceメソッドをモック
  mock_service = Minitest::Mock.new
  mock_service.expect :call, true, [User, String, Hash]

  Sign::App::PasskeyVerificationService.stub :verify!, mock_service do
    get sign_app_verification_url(scope: "configuration_passkey", return_to: return_to), ...

    get new_sign_app_verification_passkey_url(ri: "jp"), ...

    post sign_app_verification_passkey_url(ri: "jp"), ...
  end

  mock_service.verify
end
```

### 戦略 C: データベース依存テスト（グループ 3, 4）

**パターン**: 認証結果をstubしているケース

**現在のコード**:

```ruby
Sign::Org::In::SecretsController.any_instance.stub(:log_in, { status: :unknown }) do
  post sign_org_in_secret_url(ri: "jp"), ...
end
```

**変換後のコード**:

```ruby
test "create renders invalid when login fails" do
  # 無効な認証情報を使用
  post sign_org_in_secret_url(ri: "jp"),
       params: { secret_login_form: {
         identifier: @staff.public_id,
         secret_value: "invalid-secret"
       } }

  assert_response :unprocessable_content
  assert_includes response.body, I18n.t("sign.org.authentication.secret.create.invalid")
end
```

### 戦略 D: セッション操作の代替（グループ 4）

**現在のコード**:

```ruby
def set_registration_session(id)
  Sign::App::Configuration::Telephones::RegistrationsController.any_instance.stub(
    :current_registration_telephone,
    UserTelephone.find(id),
  ) do
    yield if block_given?
  end
end
```

**変換後のコード**:

```ruby
def set_registration_session(telephone)
  # 実際のセッションに保存
  post sign_app_configuration_telephones_registrations_path(ri: "jp"),
       params: { user_telephone: { raw_number: telephone.raw_number } }
  assert_response :redirect  # 確認コード送信完了
end
```

## 実装手順

### Phase 1: 基盤整備（0.5日）

- [ ] `test/test_helper.rb` で `ActiveSupport::Testing::TimeHelpers` をinclude
- [ ] 必要なヘルパーメソッドを追加
- [ ] CI環境での動作確認

### Phase 2: グループ 1（時間操作系）の移行（1日）

- [ ] `sign/app/edge/v0/token/refreshes_controller_test.rb`
- [ ] `sign/org/edge/v0/token/refreshes_controller_test.rb`
- [ ] `apex/*/web/v0/cookie_controller_test.rb` (3ファイル)

**レビューポイント**:

- TimeHelpersを使用した時間固定が正しく機能しているか
- Cookieのexpires属性が期待通りに設定されるか

### Phase 3: グループ 5（個別ケース）（0.5日）

- [ ] `sign/org/configuration/passkeys_controller_test.rb` - `OperatorPasskey`へのstub
- [ ] `apex/app/web/v0/cookie_controller_test.rb` - 141行目

### Phase 4: グループ 4（電話番号登録）（1日）

- [ ] 実際のセッションフローでテストするよう書き換え
- [ ] `set_registration_session` ヘルパーの代替実装

**レビューポイント**:

- セッションベースのフローが正しく動作するか
- エラーケースも網羅されているか

### Phase 5: グループ 2（Verification系）（2日）

- [ ] Passkey verification
- [ ] Email OTP verification
- [ ] TOTP verification
- [ ] BaseControllerのメソッドstubの代替

**レビューポイント**:

- 外部サービス（WebAuthn）への依存を適切に分離
- 統合テストとして実際のフローが機能するか

### Phase 6: グループ 3（ログイン・認証）（1.5日）

- [ ] SecretsController
- [ ] PasskeysController (app/org両方)
- [ ] OmniauthCallbacksController

**レビューポイント**:

- Service層への抽出が適切か
- エラーケースの網羅

### Phase 7: 全体整合性とCI確認（1日）

- [ ] 全テストがパスすることを確認
- [ ] テスト実行時間が悪化していないか確認
- [ ] カバレッジレポート確認

## リスクと対策

| リスク                                   | 影響度 | 対策                                                   |
| ---------------------------------------- | ------ | ------------------------------------------------------ |
| TimeHelpers使用時のタイムゾーン問題      | 中     | 明示的にUTCを使用し、日本時間との変換は避ける          |
| Service層抽出による設計変更が必要        | 高     | 別タスクとして抽出計画を策定、本タスクではstub代替のみ |
| WebAuthn実際呼び出しによるテスト不安定化 | 高     | WebAuthnのmockは維持し、Controllerのstubのみ削除       |
| セッション操作テストの複雑化             | 中     | ヘルパーメソッドを充実させ、可読性を確保               |
| テスト実行時間増大                       | 中     | 実際のDB操作に変更による増大は許容範囲か確認           |

## 成功基準

1. 全 `any_instance.stub` が削除される
2. 既存のテストカバレッジが維持される
3. テスト実行時間が20%以上悪化しない
4. 全CIチェックがパスする

## 注意事項

- **決して行わないこと**: Controller privateメソッドに対する `send(:method_name)` 呼び出し
- **避けるべきパターン**: テスト内で複雑な条件分岐
- **優先するパターン**: 実際のリクエスト/レスポンスサイクルでの検証
