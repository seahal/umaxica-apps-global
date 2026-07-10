# 2026-05-31 Rails harness 劣化防止スイープ（検出結果）

低予算・最小変更の方針で実施。実装変更は test 1ファイルのみ。

## やったこと

`test/controllers/controller_base_inheritance_test.rb` に「`BARE_CONTROLLERS` 配列が
`app/controllers/**/bare_controller.rb`
の実ファイルと同期しているか」を検証するテストを1件追加した。新 surface の BareController 追加時に配列登録漏れで継承チェックをすり抜けるデグレを防ぐのが目的。5
runs / 91 assertions / 0 failures。

## 1. include するだけで副作用を出す concern / module（検出のみ・未修正）

コントローラ concern は総じてクリーン。`included do` での callback 自動登録は
**app/controllers/concerns に0件**。多くは「明示 opt-in」設計になっている：

- `restricted_session_guard.rb` … 「自動 before_action は足さない。利用側が明示的に
  `before_action :enforce_restricted_session_guard!` を書くこと」とコメントで明記。良い設計。
- `verification/step_up_guard.rb` … `step_up` マクロを**呼んだ時だけ**
  before_action を登録（opt-in）。include だけでは副作用なし。

唯一の「include で副作用」型：

- `app/controllers/concerns/sign/com/route_alias_helper.rb` `self.included(base)` / `self.extended`
  で `define_route_aliases` を実行し、include したクラスへ `sign_app_*` → `sign_com_*`
  等のルートヘルパ別名メソッドを動的定義する。正当なパターンだが「include
  = メソッド生成の副作用」なので将来の挙動デバッグ時に留意。起動時に
  `Rails.application.routes.url_helpers` を走査する依存もある。**今回は未修正。**

参考：`included do` を多用しているのは **model
concern**（108 個が ActiveSupport::Concern）。ただし中身は validation / association / scope /
callback で、Rails 的に idiomatic。harness 劣化ではないため対象外。

## 2. BareController が ApplicationController を継承するデグレ（既に対策済み）

`test/controllers/controller_base_inheritance_test.rb` が**既に網羅的にカバー済み**だった：

- 全 BareController（11個）の `superclass == ActionController::Base` を実行時 assert
- `RateLimit` 祖先の存在も確認
- `bare_controller.rb` を全 glob し `class BareController < ApplicationController`
  の文字列混入をソーススキャンで検出
- surface 別 ApplicationController も ActionController::Base 直継承を assert
- legacy OpenController 互換ベースが撤去済みであることを assert

bare_controller.rb は現在ちょうど 11 個で、配列も 11 個で一致。→ 新規テスト追加は不要と判断し、代わりに上記「同期チェック」だけ補強した。

**例外・要注意リスト（勝手に直していない）：**

- ソーススキャンテストはリテラル `class BareController < ApplicationController`
  の完全一致のみ検出。`< Acme::App::ApplicationController`
  のような surface 修飾名やスペース違いは取りこぼす。実行時テスト（superclass 比較）が本命の保証。surface 修飾名で書く新規 BareController が現れたら正規表現を緩める検討余地あり。

## 3. 例外を if/case 代用にしている箇所（検出のみ・未修正）

- `rescue nil` は **0 件**（クリーン）。
- `rescue StandardError`（=> e 含む）は多数あるが、確認した範囲では大半が
  **正当な防御的エラーハンドリング**であって if/case 代用ではない：
  - `concerns/authentication/audit_writer.rb`, `concerns/authorization_audit.rb`
    …監査ログ書き込み失敗を握って本処理を止めない（意図的）。
  - `concerns/health.rb` … ヘルスチェックの可用性確保。
  - `concerns/preference/*`, `concerns/actor_support.rb` … 認証/認可/preference/token周辺 ＝
    **本タスクで変更禁止ゾーン**。
- if/case 代用に近い疑いがあり、かつ安全に直せる候補は**認証/認可/token/preference の禁止ゾーン外に見当たらなかった**ため、今回の 1 件修正は task
  #3 ではなく task #2 の同期テスト補強に充てた。

### 次回もし #3 に着手するなら

- まず `app/controllers/sign/app/configuration/activities_controller.rb:75,140` と
  `sign/org/configuration/activities_controller.rb:43,93` の `rescue StandardError` （`=> e`
  を取らない握り潰し）が分岐代用か防御かを精査する。configuration 系なので認証コアよりは触りやすい可能性。ただし step-up/OIDC 連動を要確認。
- `lib/jit/security/turnstile_verifier.rb:78` も verifier 単体テストを足しやすい候補。

## 制約遵守

- 大規模リファクタなし。認証/認可/Step-Up/OIDC/token refresh/cookie/session 無変更。
- Service Object 新設なし。Minitest のみ。migration なし。変更は test 1 ファイル。
