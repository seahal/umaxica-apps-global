# Sign Up/In Email フロー バグ調査

## Context

`https://id.umaxica.app/sign/in/session?ri=jp`
を起点として、現在 develop ブランチで未コミットの変更（working
tree 差分）に複数のバグが確認された。ログでは OIDC コールバック失敗（`token_exchange_failed` →
`rate_limited`）のパターンが観測されており、変更の組み合わせが原因と考えられる。

---

## 確認されたバグ

### Bug 1 【Critical】`sign/org/settings/emails_controller.rb:37-38`

**update アクションが常に失敗する**

```ruby
# 現在のコード（バグ）
@staff_email.errors.add(:base, t("sign.org.settings.email.update.failure"))
render(:edit, status: :unprocessable_content)
```

Turnstile 検証通過後、メール設定を保存する成功パスが丸ごと削除された。削除されたコード：

- `@staff_email.update(email_preference_params)` の呼び出し
- 成功時の `redirect_to`
- `email_preference_params` private メソッド（パラメータ許可リスト）

**影響**:
org オペレーターはメール設定（promotional/notifiable）を変更できない。常にエラー画面が表示される。

---

### Bug 2 【OIDCコールバックループ】`app/controllers/concerns/oidc_callback.rb:91`

**エラー時に再認可フローを開始してしまう**

```ruby
# 変更前
redirect_to(sign_in_url_with_pt(nil), alert: I18n.t("errors.messages.login_required"), allow_other_host: true)

# 変更後（バグ）
redirect_to_oidc_authorization_url(sign_in_url_with_pt(nil))
```

`token_exchange_failed`
等でコールバックが失敗すると、サインイン画面に戻る代わりに新しい OIDC 認可フローを開始する。その認可フローも同じコールバックに戻ってきて再失敗する無限ループが発生する。

**ログエビデンス（log/development.log）**:

```
# 繰り返し token_exchange_failed
142277: {"event":"oidc.rp.callback.failed","data":{"error":"token_exchange_failed","client_id":"sign-rp",...}}
... (6 回繰り返し)
# その後 rate_limited
143180: {"event":"oidc.rp.callback.failed","data":{"error":"rate_limited","client_id":"sign-rp",...}}
... (8 回繰り返し)
```

ループで連打されてレートリミットに当たっているパターンが明確。

---

### Bug 3 【認証不一致】`sign/org/settings/removals_controller.rb`（修正で解消済み）

```ruby
# 変更前（HEAD の状態 = バグ）
before_action :authenticate_client!   # app サーフェスのメソッド

# 変更後（working tree = 修正）
before_action :authenticate_operator! # org サーフェスの正しいメソッド
```

org サーフェスのコントローラが
`authenticate_client!`（app ユーザー用）を使っていた既存バグ。現在の working
tree 差分がこれを修正している。

---

### Bug 4 【after_login_path の宛先変更】アプリケーションコントローラ 3 サーフェス

```ruby
# 変更前
acme_app_dashboard_url(ri: params[:ri], host: acme_authority_host)

# 変更後
sign_app_dashboard_path(ri: params[:ri])
```

ログイン後のリダイレクト先が `acme`（www.umaxica.app）から
`sign`（id.umaxica.app）のダッシュボードに変わった。対象：

- `app/controllers/sign/app/application_controller.rb`
- `app/controllers/sign/com/application_controller.rb`
- `app/controllers/sign/org/application_controller.rb`

ルート（`sign_app_dashboard_path` 等）は `config/routes/sign.rb` の
`resource :dashboard, only: :show`
で存在するが、このダッシュボードページが実装されているかは別途確認が必要。

---

## 意図的な変更（確認済み・keep）

### after_login_path（3サーフェス） — keep

`sign_*_dashboard_path` は実装済み。通常の OIDC サインインフローは `oidc_pt`
セッション経由でリダイレクトするため `after_login_path` は使われない。ログイン済みユーザーが Sign
root に来たときのみ適用。`?rt=` パラメータは sign フローに存在せず、変更は意図的で正しい。

### セレモニーグラント要件の撤廃（全サーフェス・全セレモニー種別） — keep

`finish_*_ceremony!`
のフォールバック（`commit_settings_*_registration!`）はロック取得・オーナーチェック・ステータスチェックを備えており、Acme グラントなしでも安全。OTP 検証は Sign 側で完結するため、グラント必須は過剰制約との判断。

### テレフォンコントローラの認証モード変更 — keep

`declare_authentication_mode! :open` 削除 → 全アクションに `authenticate_client!/visitor!`
を適用。電話番号設定リスト（index）が未認証ユーザーから見えていた問題を解消するセキュリティ改善。

---

## 修正方針

### Bug 1 修正（`sign/org/settings/emails_controller.rb`）

```ruby
def update
  @staff_email = current_operator.staff_emails.find_by!(public_id: params(:id))
  authorize!(@staff_email)

  unless cloudflare_turnstile_stealth_validation["success"]
    @staff_email.errors.add(:base, t("turnstile_error"))
    render(:edit, status: :unprocessable_content)
    return
  end

  if @staff_email.update(email_preference_params)
    redirect_to(
      edit_sign_org_settings_email_path(@staff_email.public_id, ri: params[:ri]),
      status: :see_other,
    )
  else
    @staff_email.errors.add(:base, t("sign.org.settings.email.update.failure"))
    render(:edit, status: :unprocessable_content)
  end
end

private

def email_preference_params
  params.fetch(:staff_email, {}).permit(:promotional, :notifiable)
end
```

注：元コードにあった `redirect_to notice:` と `flash.now[:alert]`
は no-flash-messages ルール違反のため除外。

### Bug 2 修正（`app/controllers/concerns/oidc_callback.rb`）

```ruby
def render_callback_failure(reason)
  # ...
  redirect_to(sign_in_url_with_pt(nil), allow_other_host: true)
end
```

ループを避けるため、直接サインイン URL にリダイレクトする形に戻す（`alert:`
は no-flash-messages ルール違反のため除外）。エラーは inline にページ内で表示するか、サインインページ側で対応。

---

## 検証方法

1. `bin/rails test test/controllers/sign/org/settings/emails_controller_test.rb` -
   update アクションのテスト
2. 開発環境で org ユーザーとしてメール設定の更新が成功することを確認
3. OIDC コールバック失敗時に無限ループが発生しないことをログで確認
4. `bin/rails test test/controllers/concerns/oidc_callback_test.rb`（存在する場合）

## 関連ファイル

- `app/controllers/sign/org/settings/emails_controller.rb` — Bug 1
- `app/controllers/concerns/oidc_callback.rb` — Bug 2
- `app/controllers/sign/org/settings/removals_controller.rb` — Bug 3（修正済み）
- `app/controllers/sign/app/application_controller.rb` — after_login_path
- `app/controllers/sign/com/application_controller.rb` — after_login_path
- `app/controllers/sign/org/application_controller.rb` — after_login_path
- `app/controllers/concerns/sign_email_ceremony_delegation.rb` — セレモニーフォールバック追加
- `app/controllers/concerns/sign_email_registration_flow.rb` — new アクションのリダイレクト削除
