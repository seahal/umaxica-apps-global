# sign ceremony: ビュー/コントローラを `namespace :sign` ルートへ一致させる

## Context

ユーザーが「`app/views` と `config/routes/*.rb`
が不一致でへん」と指摘した。調査の結果、原因と経緯が確定した。

`config/routes/sign.rb` は sign-in / sign-up を **`namespace :sign do namespace :up / :in`**
で宣言している（`sign.rb:79`, `:123`、com/org も同形）。`namespace` はパス・モジュール・ヘルパー名の
**3つすべて** にプレフィックスを付けるため、ルートが解決するコントローラは:

- モジュール: `Sign::App::Sign::Up::*` /
  `Sign::App::Sign::In::*`（`app/controllers/sign/app/sign/{up,in}/`）
- ヘルパー: `sign_app_sign_up_*` / `sign_app_sign_in_*`（`emails_controller.rb:206` 等で実使用）
- URL: `/sign/up/...`, `/sign/in/...`

一方 **ビューは旧来の `app/views/sign/app/{up,in}/...` にしか無い**（canonical な
`sign/app/sign/...` には birthdate 2 枚だけ）。動作している理由は次の間接参照:

- route 直結の `Sign::App::Sign::Up::*` は、ロジック本体を持つ `Sign::App::Up::*`（基底）を継承した
  **薄いサブクラス**（計 31 個）。
- 各サブクラスが `self.local_prefixes = ["sign/app/up/emails"] + super` のように
  **ビュー探索を旧ディレクトリへ付け替え**（`local_prefixes` 上書き 30 個）。

経緯: ADR `adr/sign-prefix-routing.md`（Accepted 2026-05-05）は「`/sign/` プレフィックスは
**`scope path: "sign"` でパスのみ**
付け、モジュール・ヘルパー名・ビュー配置は変えない」と決めていた。実装はこれを `namespace :sign`
でやってしまい ADR から逸脱。その差を既存ビューに橋渡しするため薄いサブクラス＋`local_prefixes`
シムが追加され、ルートとビューがズレた。

**決定（ユーザー、2026-06-15）:**
現行 URL とヘルパー名（`sign_app_sign_*`）を維持したいので、**ビュー/コントローラをルート側へ寄せる**。すなわち薄いサブクラスの間接参照を解消し、単一のコントローラツリーを canonical な
`sign/app/sign/{up,in}`
に置く。ADR は実装に合わせて改訂する。期待結果: ルート・コントローラ・ビューの 3 つが同じ
`sign/app/sign/{up,in}` 構造で一致し、`local_prefixes` シムが消える。

対象は app / com / org の 3 サーフェス全部（同一構造）。`config/routes/sign.rb` 自体は
**変更しない**。

## 変換パターン（コア）

route 直結の薄いサブクラスと基底クラスを、canonical パスの **単一クラス** に畳み込む。1 ペアあたり:

1. **基底クラス本体を canonical モジュール/パスへ移設** 例:
   `app/controllers/sign/app/up/emails_controller.rb`（`Sign::App::Up::EmailsController`）の本体ロジックを
   `app/controllers/sign/app/sign/up/emails_controller.rb`（`Sign::App::Sign::Up::EmailsController`）へ移し、モジュールを
   `Sign::App::Sign::Up` に書き換える。
2. **薄いサブクラスの上書き宣言を畳み込む**
   サブクラスは単なる場所替えではなく、`AUTHENTICATION_MODE` / `declare_authentication_mode!`
   を上書きしているものがある（例: `sign/up/emails` は `no_redirect: true`、`sign/in/sessions` は
   `:deny_all`/`:open`）。これらの宣言は **サブクラス側を採用** して移設後クラスに反映する。
3. **`local_prefixes` 上書きを削除**（移設でビューが規約解決されるため不要）。
4. 旧基底ファイル（`sign/app/up/...`, `sign/app/in/...`）を削除。

`local_prefixes`
を持つサブクラス（ビュー差し替えのみ）と、宣言を持つサブクラスの両方を、上記 1 手順で吸収する。

代表パス（app の例。com/org も同形で実施）:

- `sign/app/sign/up/emails_controller.rb` ← `sign/app/up/emails_controller.rb` ＋ サブクラス宣言
- `sign/app/sign/in/sessions_controller.rb` ← `sign/app/in/sessions_controller.rb` ＋ サブクラス宣言
- `sign/app/sign/in/check/cancellations_controller.rb`, `.../in/checks_controller.rb`,
  `.../in/challenges_controller.rb` ほか（`local_prefixes` 一覧は
  `grep -rl local_prefixes app/controllers/sign` の 30 件）

## ビュー移動

- `app/views/sign/app/up/**` → `app/views/sign/app/sign/up/**`
- `app/views/sign/app/in/**` → `app/views/sign/app/sign/in/**`
- com / org も同様（`sign/com/up`→`sign/com/sign/up` 等）。
- 既に canonical 側にある 2 枚（`sign/app/sign/up/check/{apple,google}/birthdates/show.html.erb`）は移動先と重複するので、旧
  `up/` 側の同名と内容を突き合わせて 1 本化する（差分があれば旧 `up/`
  側を正とする。理由: 旧側が実際に描画されてきた実体）。

`git mv` でディレクトリごと移し、履歴を保つ。

## 横断スイープ（移動・改名に伴う参照修正）

1. **明示 render の view パス更新**: 基底コントローラ内の `render "sign/app/up/check/..."`
   等（`sign/app/up/check/{apple/confirmations,email/birthdates,email/otps,telephone/otps,telephone/passcodes,telephone/passkeys}`
   と com 対応、`concerns/sign_up_social_check_birthdate_controller_support.rb`）を新パス
   `sign/app/sign/up/...` へ。ビュー内 partial 参照（`sign/app/up/check/email/otps/edit.html.erb`
   等）も同様。
2. **基底モジュール参照の更新**: `Sign::*::Up::` / `Sign::*::In::` を外部から参照している箇所:
   - `app/controllers/concerns/sign_{app,com,org}_in_check_controller_support.rb`
   - `app/views/sign/org/in/sessions/update.html.erb`
   - `test/controllers/controller_inheritance_invariant_test.rb`,
     `test/controllers/sign/app/application_controller_test.rb` を新モジュール名
     `Sign::*::Sign::Up/In::` に追従。
3. **テスト**: 旧 view ディレクトリ／クラス名を直接参照するテスト（`grep -rl 'sign/app/up/\|sign/app/in/\|Sign::App::Up\|Sign::App::In' test`、現状 5 ファイル）を更新。ヘルパー名（`sign_app_sign_*`）は不変なのでパスアサーションの大半は無傷のはず。

## 孤立（orphan）コントローラの triAGE

route 直結サブクラスを持たない基底コントローラがある（現行ルートに対応 resource 無し）:

- app/com: `up/checkpoint/{birthdates,passcodes,passkeys}`, `up/checkpoints`, `up/guards`,
  `up/guard/base`
- org: `up/base`

これらは現行 `config/routes/sign.rb` の `namespace :up` に対応ルートが無い。実行前に各々について
**(a) 他コントローラ/concern からの明示 render・include で生きているか、(b) 完全な dead code か**
を確認する（`grep -rn "Checkpoint\|guards#\|checkpoints#" app config test`）。

- 生きている（明示 render 等）→ canonical `sign/app/sign/up/...` へ一緒に移設。
- dead → 別スライスで削除提案（本タスクでは移設対象から外し、移動だけ行い削除はユーザー確認後）。

`up/guard/base_controller.rb` は `guard/{apples,emails,googles,telephones}`
の親なので移設必須（dead ではない）。

## ADR 改訂

`adr/sign-prefix-routing.md` を改訂し、実装が `scope path: "sign"`（パスのみ）ではなく
**`namespace :sign`（パス＋モジュール＋ヘルパー）** を採用した事実と理由（URL/ヘルパー
`sign_app_sign_*` を canonical とし、コントローラ/ビューを `sign/app/sign/{up,in}`
に統一、`local_prefixes` シムを廃止）を記述する。「helper names unchanged
(`sign_app_in_*`)」の旧記述は現状（`sign_app_sign_in_*`）に合わせて訂正。Status は Accepted のまま「Amended
2026-06-15」を追記。

## 実施順序（サーフェス単位で段階化）

差分をレビュー可能に保つため **app → com → org**
の順で 1 サーフェスずつ完結させる（各サーフェスでコントローラ移設＋ビュー移動＋当該サーフェスのスイープ＋テストまで）。各段で
`bin/rails test` の該当範囲を緑にしてから次へ。最後に ADR 改訂と全体テスト。

## Verification

各サーフェス完了ごと、および最終に:

1. **ルート解決とテンプレート探索**
   - `RAILS_ENV=test bin/rails runner 'pp Rails.application.routes.named_routes.names.grep(/sign_app_sign_(up|in)/)'`
     でヘルパー名が不変であることを確認。
   - 主要 GET 画面（`sign/up/email#new`, `sign/up/check/email/otp#show`, `sign/in/email#new`,
     `sign/in/session#show`, `sign/in/challenge/passkey#new` 等）をリクエストして
     **テンプレート欠落（MissingTemplate）が出ないこと**
     を確認。これが本タスクの核心リグレッション。
2. **`local_prefixes` 残存ゼロ**: `grep -rl local_prefixes app/controllers/sign` が空。
3. **旧ツリー消滅**: `app/controllers/sign/*/{up,in}` と `app/views/sign/*/{up,in}`
   が存在しない（org の `up/invitations` は
   `namespace :up`（staff）配下なので別扱い—org ルートを確認し、必要なら canonical 側へ）。
4. **テスト**
   - 狭域:
     `bin/rails test test/controllers/sign`、`test/controllers/controller_inheritance_invariant_test.rb`、`test/controllers/sign/app/application_controller_test.rb`。
   - 広域: 共有挙動に触れるため最後に `bin/rails test`。
   - JS 変更は無し。
5. **手動**: `bin/rails server` 起動相当で `id.app.localhost/sign/up`, `/sign/in`
   の画面が描画されること（`docs/operations/db-workflow.md` のローカル手順）。

## 注意 / 非対象

- `config/routes/sign.rb` は変更しない（URL・ヘルパーを維持するため）。
- `app/views/sign/app/sign_ups`, `sign_ins`, `sign_outs`（共有エントリ画面、`EntrancesController` が
  `render "sign/app/sign_ups/new"`）は本タスク対象外。
- org の
  `sign/org/up/invitations`（staff 招待）は別ルート（`namespace :sign do namespace :up do resources :invitations`、`sign.rb:540`）。canonical は
  `Sign::Org::Sign::Up::InvitationsController` なので、同じ変換パターンで扱う。
- 破壊的 DB 操作・flash 追加は無し。AGENTS.md の禁止事項（`skip_*`, `html_safe`
  等）を新規追加しない。
