# サインアップ問題点レポート（telephone / email / google / apple）

調査対象: `log/development.log`（約60MB, 2026-06-19）方法: `Processing by` → `Completed <status>`
の突合、構造化 JSON イベント、例外トレースの抽出。

---

## 結論（最重要から）

### A. 共通基盤の障害（4経路すべてに影響）

**A-1. OIDC トークン交換が CSRF で 100% 失敗 — 最重要**

- `Acme::App::Oauth::TokensController#create` … **10 / 10 が 422**
- ログ: `Falling back to CSRF token verification ... Can't verify CSRF token authenticity` →
  `{"event":"oidc.rp.callback.failed","data":{"error":"token_exchange_failed"}}`
- 根本原因: `app/controllers/acme/app/bare_controller.rb:14`
  `protect_from_forgery using: :header_or_legacy_token, with: :exception`
  が、authorization_code 交換用のトークンエンドポイント（`TokensController < BareController`）にも掛かっている。OAuth トークンエンドポイントは CSRF トークンを持たない server-to-server 呼び出しのため必ず例外化する。
- 連鎖被害: RP コールバック `Acme::App::Auth::CallbacksController#show` が
  **46 件中 28 件（61%）で 422** → `/oauth/authorize` に戻されるループ。Google / Apple / Email /
  Telephone は全てこの交換を通るため、 **どの経路もサインアップを完了できない。**

**A-2. authorize のレート制限 429 多発**

- `Acme::App::Oauth::AuthorizationsController#show` … **429 が 33 件**
- 直近の `ClientToken.created_at`
  に基づくトークン発行レート上限。A-1 の失敗で再試行が多発し 429 を誘発する悪循環。

**A-3. 同時セッション上限 (3) で 422**

- `ActiveRecord::RecordInvalid (exceeds maximum concurrent sessions per user (3))`
- 既存3セッションがあると新規サインアップ完了が弾かれる。テスト反復で頻発。

### B. Email サインアップ

- `Check::Email::OtpsController#update` …
  **422 が 13 件**（成功 302 は 6 件）。OTP 検証失敗が支配的。
- `Up::EmailsController#create` …
  422 が 5 件。`sign.signup.email.validation_failed`:「セキュリティ検証に失敗しました」（Turnstile/CSRF）×4、「メールアドレスはすでに存在します」。
- `path_target.rejected: invalid_signed_pt_param` が `/sign/up/check/email/birthdate`
  で多発 → 署名付き `pt` パラメータ検証に失敗し、誕生日ステップへの遷移が壊れる。
- `auth.open.invalid_credentials: token_session_not_found`（birthdate ステップでセッション喪失）。
- `Check::Email::BirthdatesController#update` … 422 が 7 件。

### C. Telephone サインアップ — 経路として最も機能していない

- `TelephonesController#new` は 22 件あるのに `#create` は
  **1 件のみ、しかも 422**。実質、電話番号フォームの送信がほぼ成立していない。
- `ActionController::InvalidCrossOriginRequest (The browser returned a 'null' origin ...)` が出現。
- 電話固有の検証失敗イベントは未出力（構造化ログが薄く、原因追跡が困難）。

### D. Google サインアップ

- `Social::Google::ConnectionsController#create`(12) /
  `Guard::GooglesController#show`(6) は全て 302 でフローは進む。
- ただし `social_auth.error`:
  - `SocialAuth::ProviderError`「プロバイダーとの通信中にエラーが発生しました」（google_app,
    intent=login, `/auth/google_app/callback`）
  - `SocialAuth::UnauthorizedError`「無効な認証インテントです」
- 最終完了は A-1 のトークン交換失敗でブロックされる。

### E. Apple サインアップ

- `Social::Apple::ConnectionsController#create`(9) / Guard / Birthdate /
  Confirmation は概ね 200/302/303 で 4経路中もっとも健全に進行。
- 完了は同じく A-1 でブロック。Apple は `form_post` 応答モードで `null`
  origin の CSRF リスクを内包。

---

## 影響度の優先順位

1. **A-1（トークン交換 CSRF）** — 全経路の完了を阻害する単一根本原因。最優先。
2. **A-2 / A-3（429・セッション上限）** — A-1 解消後も再試行・反復で完了を阻害。
3. **B（Email: OTP 422・signed pt 失効・token_session_not_found）** — Email 単独経路の主障害。
4. **C（Telephone: create がほぼ 0 件）** — フォーム送信段階の障害。再現とログ補強が必要。
5. **D（Google: provider error / invalid intent）** — A-1 と切り分けて要確認。
6. **E（Apple）** — 経路は健全、完了は A-1 待ち。

---

## 推奨フォローアップ（修正は別タスク）

- A-1: トークンエンドポイント（`Acme::{App,Org,Com}::Oauth::TokensController`）を CSRF 保護対象から外す（OAuth トークンエンドポイントは CSRF 非対象が正。`protect_from_forgery`
  を BareController 一律で掛けずブラウザフォーム系に限定するか、トークン系で明示的に除外）。境界は
  `BareController` の契約に合わせて慎重に。
- A-2: テスト/開発でのレート上限と、A-1 解消後の再試行収束を確認。
- B: `invalid_signed_pt_param` と `token_session_not_found`
  の発生条件（TTL・host=id.umaxica.app 跨ぎ）を特定。
- C: Telephone `#create` の検証失敗理由を構造化ログに追加し、`null` origin CSRF を切り分け。
- D: `SocialAuth::UnauthorizedError「無効な認証インテント」` の intent 受け渡しを確認。

## 検証方法

- 再集計: `awk` で `Processing by ... → Completed <code>` を経路別に突合（本調査と同手順）。
- 修正後は `Acme::App::Oauth::TokensController#create` が 200 を返し、 `oidc.rp.callback.failed`
  が消えること、`CallbacksController#show` の 422 が解消することを確認。
