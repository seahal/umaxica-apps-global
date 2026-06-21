# Rails ログ調査レポート（development.log / prosopite.log）

## Context（なぜこの調査か）

ユーザー依頼: 現在の Rails ログを見て問題点を洗い出す。対象: `log/development.log`（約 24 万行 /
39MB、~2026-06-20 朝〜 2026-06-21 02:02）と
`log/prosopite.log`。ログ末尾の実トラフィックは 2026-06-20
20:31 が最後で、以降は SolidQueue のハートビートのみ。

重要な前提: **HEAD コミット `bf68dcdc9` の日時は 2026-06-21
08:34（本日）で、ログ中の主要 500 エラーより後**。つまりログに記録された致命的エラーの多くは、本日のコミットで既に修正済みの可能性が高い。本レポートは「①既に潰したもの（要・再発確認）」と「②まだ開いている可能性があるもの」を切り分ける。

---

## 検出した問題（深刻度順）

### 1. ActiveRecord::ReadOnlyError — GET 経路での書き込み（最多・最重要）★ほぼ修正済み

- 症状: GET リクエストの最中に `UPDATE` が走り `Write query attempted while in readonly mode`
  で 500。
- 発生箇所と件数:
  - `client_sign_up_flows.nonce_digest`
    更新 → ソーシャル新規登録フロー（`app/services/sign_up_cycle_locator.rb#issue!`
    経由、`Sign::App::Social::AuthenticationsController#continue`）。ログ: line 27164 / 27249 /
    98285（2026-06-20 08:18 と 20:31）。
  - `client_device_sessions.last_network_hmac` 更新 →
    transparent-refresh の副作用（`app/controllers/concerns/authentication_base.rb#detect_session_network_change!`）。ログ:
    `auth.transparent_refresh.side_effect_failed`（line 39039,
    08:25）。こちらは rescue され 500 にはならないが、ネットワーク指紋が永続化されず毎リクエストで
    `ip_change_detected` が再発火し続ける副作用。
- 根本原因: `config/initializers/multi_db.rb` の `database_selector`（GET/HEAD は
  `:reading`=replica ロール）。GET 経路で書き込む設計のエンドポイントが readonly コネクションに当たる。
- 現状: HEAD では両方とも `ActiveRecord::Base.connected_to(role: :writing) do ... end`
  でラップ済み（`sign_up_cycle_locator.rb:38-40`、`authentication_base.rb:1080-1083`、後者は説明コメント付き）。
  **ログのエラーは修正コミット前のもの。**
- 残作業: **同種の「GET 経路での書き込み」が他に残っていないかの横断確認**。 `git grep`
  で GET アクション内の `update`/`update_columns`/`save`/`create`/`increment!` を洗い出し、
  `connected_to(role: :writing)` で包まれているか確認する。新規 OAuth/DBSC/refresh 系が要注意。

### 2. NameError: undefined method `current_resource`（SignOut）★リファクタで解消済みと推定

- ログ: line 40373
  `NameError ... 'current_resource' for an instance of Sign::App::SignOutsController`（旧クラス）。
- 旧ファイル `app/controllers/sign/app/sign_outs_controller.rb` は削除（git status:
  `D`）、新ファイル
  `app/controllers/sign/app/sign/outs_controller.rb`（`OutsController`）に分割済み。
- 新 `OutsController` は `::Sign::App::ApplicationController` を継承し、`current_resource` は
  `app/controllers/concerns/authentication_base.rb:330` で定義されている →
  **現行ツリーでは解決済みと推定**。
- 残作業: sign-out（`create`）を実際に叩いて 500 が出ないことを確認（検証セクション参照）。

### 3. NoMethodError: undefined method `sign_routes`（ブート時ルーティング失敗）★要確認

- ログ: line 162431 / 165101、`config/routes/sign.rb:12` でルートマッパーマクロ未定義。
- マクロは現在 `config/initializers/sign_route_mapper.rb:13 (def sign_routes)`
  に存在。サーバは現在起動できている（末尾の SolidQueue ログ）ため、リファクタ途中のロード順序問題による一過性と推定。
- 関連: git status で `app/controllers/concerns/sign_route_alias_helper.rb` が削除されている。
- 残作業: クリーンブート（`bin/rails runner 'Rails.application.reload_routes!'`
  か再起動）でルートが例外なく描画されることを確認。initializer がルート描画前にロードされる順序を担保。

### 4. ActionController::Redirecting::OpenRedirectError ★開いている可能性あり

- ログ: line 29295、`Sign::App::Sign::Up::Check::Email::BirthdatesController#update` →
  `Unsafe redirect to "https://www.umaxica.app/dashboard?ri=jp"`（`allow_other_host: true` 不足）。
- サーフェス跨ぎ（id.umaxica.app → www.umaxica.app）のリダイレクト。許可リストは
  `app/services/jump_rt_return_policy.rb`（`https://www.umaxica.app`
  は許可オリジンに含まれる）に存在。
- 残作業: 戻り先解決の正規ヘルパ（`safe_redirect_to` / `jump_rt_return_policy`
  経由）を使い、サーフェス間遷移で `allow_other_host` 相当が通るよう整合させる。`raw な redirect_to`
  で直書きしていないか確認。

### 5. ルーティング 404（RoutingError ×26）★切り分け要

- スキャナ/プローブ起因（無視可）: `/.git/config`, `/.git/HEAD`, `/apple-touch-icon.png`。
- クライアント実装とのパス不一致の可能性: `/edge/v0/token/dbsc`, `/edge/v0/dbsc`(×3),
  `/edge/v0/token/check`, `/edge/v0/cookie`。ルートは `config/routes/core.rb` /
  `config/routes/sign.rb` に `namespace :edge { resource :dbsc, only: :create }`
  等で存在するが、`token/dbsc`・`token/check`・`cookie`(単数 GET) は未定義。ホスト制約 or パス設計のズレ。
- `/csp-violation-report` 404: 一方で `security.csp_violation.reported` イベント（line
  40369 付近）は正常記録されており、実働の CSP レポート受け口は別途存在。メモリの「CSP
  report-uri は対外契約で URL 不変」に留意し、
  **このパスを安易に改名/新設しない**。旧ポリシーの残骸 or プローブかを先に切り分ける。
- `/social/google`(×4), `/auth/google_app` の 404 はソーシャル動線のリンク切れ候補。
- 残作業:
  edge/social 系の 404 が「実クライアントが叩く想定パス」か「外部プローブ」かを UA/頻度で分類し、実需のものだけルート追加 or クライアント側パス修正。

### 6. 軽微・おそらく想定内

- `ActionController::InvalidCrossOriginRequest`（×2, `null`
  origin）: 一部ブラウザ/拡張由来の既知ノイズの可能性。頻度低。
- `ActionController::BadRequest (authorization transaction expired)`:
  OAuth トランザクション期限切れ＝期待される 4xx 相当。
- CSP 違反（line 40369）: dev の Vite が注入する turbo-rails inline script が `script-src-elem`
  でブロック。**開発環境特有**で本番ポリシーの問題ではない可能性が高いが、dev
  CSP に nonce/hash 追加を検討。

### 7. prosopite.log（N+1）— 低優先

- 大半は `test/integration/prosopite_smoke_test.rb` のテスト内検出（`client_emails`
  の user_id 別 SELECT）。
- アプリ実コード由来は
  `app/services/oidc_backchannel_logout_notifier.rb:17/21/22`（バックチャネルログアウト通知）。ループ内クエリの
  `includes`/まとめ取得余地。実害は通知時のみで低頻度。

---

## 推奨アクション（優先度順）

1. **(高) ReadOnlyError の横断監査**: GET 経路で書き込む全箇所を洗い出し
   `connected_to(role: :writing)`
   包囲を担保。既修正の 2 箇所をテンプレに、回帰テスト（GET アクション→DB 書き込み成功）を追加。
2. **(高) ブートの健全性確認**: `sign_route_mapper.rb`
   の initializer ロード順を確定し、クリーンブートで `sign_routes` 例外が出ないことを確認。
3. **(中) sign-out の動作確認**: `OutsController#create` を叩き `current_resource`
   NameError 再発なしを確認。
4. **(中) OpenRedirect 修正**: Birthdates の戻り先を `jump_rt_return_policy`
   経由の安全リダイレクトに統一。
5. **(低) 404 の切り分け**:
   edge/v0・social 系の実需 404 のみ対応。CSP レポート URL は不変契約として触らない。
6. **(低) N+1**: backchannel logout notifier の `includes` 化を検討。

> 注:
> 1〜6 はいずれもまず**現行ツリー（多数の未コミット変更あり）での再現確認**から着手する。ログのエラーの大半は本日 08:34 の HEAD より前であり、再現しなければ「修正済み」としてクローズする。

---

## 検証方法（end-to-end）

```bash
# A. クリーンブートでルート描画が通るか（sign_routes 確認）
bin/rails runner 'Rails.application.reload_routes!; puts "routes ok"'

# B. ReadOnlyError 横断監査（GET 経路書き込みの目視抽出）
git grep -nE "\.(update|update_columns|save|create|increment!|touch)\b" app/controllers | \
  grep -vi "connected_to" | less   # GET アクション内のものを精査

# C. 関連テスト（最狭→広）
bin/rails test test/controllers/sign/app/social/authentications_controller_test.rb
bin/rails test test/controllers/sign/app/sign/outs_controller_test.rb
bin/rails test test/integration/prosopite_smoke_test.rb
bin/rails test test/controllers   # サーフェス横断の回帰

# D. 手動: ソーシャル新規登録 continue と sign-out を実際に通し 500 が出ないこと
#    （tail -f log/development.log で ReadOnlyError / NameError が出ないことを確認）
```

実行できなかったテストがあればレポートに明記する。

---

## 検証結果（2026-06-21 実施）

現行ツリー（HEAD
`bf68dcdc9` + 未コミット変更）に対して各項目を検証した。**ログの主要エラーはいずれも本日のリファクタ/コミット前のもので、現行ツリーでは解消済みであることを確認した。**

- **項目3（`sign_routes` ブート）: 解消済み（確認）**
  `bin/rails runner 'Rails.application.reload_routes!'` → `ROUTES_OK`。ルートは例外なく描画される。
- **項目1（ReadOnlyError）: 解消済み（確認）** ログの 2 箇所は HEAD で
  `connected_to(role: :writing)` ラップ済み。さらに横断監査で最有力候補だった
  `authentication_current_resource_resolver.rb` の `last_used_at` 書き込みも
  `touch_session_activity!` 内で writing ロールにラップ済み（95-97 行）。ログに `last_used_at`
  の ReadOnlyError は 0 件。認証パスの GET 経路書き込みは網羅的にラップされている。
- **項目2（SignOut `current_resource`）: 解消済み（確認）** 旧 `SignOutsController` は削除、新
  `Sign::App::Sign::OutsController` が `current_resource` （`authentication_base.rb:330`
  定義）を正しく参照。
- **項目4（OpenRedirect）: 解消済み（確認）** 現行の sign-up gate は
  `gate.redirect_to = path_for(next_step)`（内部パス）のみを返す（`sign_up_step_gate.rb:193`）。サーフェス跨ぎ遷移は
  `redirect_to_sign_in_sequence!` （`authentication_sequence_gate.rb:51`）が担い、絶対 URL は
  `redirect_to_jump_url`（allowlist 経由）に振り分けられる。ログの dashboard への raw
  redirect 経路は現行コードに存在しない。

### 残課題（任意・低優先）

- **項目5（404 切り分け）**: `/edge/v0/token/dbsc` 等・`/social/google`
  等が実需かプローブか未分類。要トラフィック分析。
- **項目7（N+1）**: `oidc_backchannel_logout_notifier.rb:17/21/22` の `includes`
  化（低頻度・低影響）。

**結論: ログに記録された 500/ブートエラーは現行ツリーで再現しない見込み。新規の修正対応は不要。残るのは低優先の 404 分類と N+1 改善のみ。**
