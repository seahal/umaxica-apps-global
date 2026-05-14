# Reauth / Step-Up Mechanism Rebuild Plan

**Status:** Active (2026-05-11)
— 本ファイルは別 AI が実装するための前提となる仕様書である。実装は本ファイルではおこなわない。

## 背景

`adr/reauth-step-up-redesign.md`
で決まった再設計を実装に落とす作業計画。設計上の決定はすべて ADR 側に固定されているので、本プランは
**どの順番で、どのファイルを、どう触るか**
だけを扱う。設計に疑問が出た場合は ADR の該当節を参照し、必要なら ADR を更新してから実装に進むこと。

## 関連 ADR / プラン

- `adr/reauth-step-up-redesign.md` — 本プランの根拠 ADR(必読)
- `adr/sign-configuration-sprint-spec.md` — `AuthMethodGuard.last_method?`(unlink 側のガード)
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md` — refresh トークン経路の AAL 保証
- `plans/backlog/restoration-a2-refresh-revoke-aal-hardening.md` — 上記 ADR の実装プラン

## 現状の故障一覧(参考)

実装に入る前に、これらが「現在壊れている挙動」であり、本プランの完了で解消されるものとして全体像を把握しておくこと:

- `StepUp::AvailableMethods` と `StepUp::ConfiguredMethods` が同一実装。
- `Verification::SetupsController#new`
  が 3 行スタブ、サーフェス差異も登録済み method の差異も反映されない。
- 登録系 controller(`Configuration::PasskeysController#new/create` 等)が `params[:rt]`
  を読まない。setup → 登録 → 元の機微操作への bounce が切れている。
- `UserReauthSession` / `CustomerReauthSession` / `OperatorReauthSession`
  モデルは存在するが、どの controller も使っていない(cookie session に reauth 状態が寝ている)。
- `app/views/sign/{app,org}/reauth/*.html.erb`(計 8 枚)がコントローラなしの orphan。
- `ALLOWED_SCOPES` に `session_revoke_all` が無く、`session#destroy` から
  `/verification?scope=session_revoke_all` に来ると `ActionController::BadRequest`。
- `ALLOWED_SCOPES` の `configuration_mfa` regex が `/configuration/mfa` を要求するが、実 route は
  `/configuration/challenge`。
- `Sign::App::Configuration::GooglesController#destroy`
  が未実装、routes にも無い(本プラン対象外。別タスクで対応)。

## PR の切り方

下記フェーズを **基本的には番号順に独立 PR**
として切る。各フェーズの「依存」欄に書かれた前フェーズが merge されていれば、後続は前後反転しても良い。テストはフェーズ内で完結させる。

---

## Phase 1: DB 配置移設と schema 簡素化

**依存:** なし

**目的:** `*_reauth_sessions` テーブルを token
DB 側の一時ログイン/セッション状態として維持し、current token に紐づける。`method`
を nullable にし、`UNIQUE(<token>_id)` を追加、 `STATUSES` を縮める。

**作業:**

1. token DB 側 schema を更新:
   - `db/mark_migrate/...` / `db/mark_schema.rb` — `user_reauth_sessions.user_token_id`
   - `db/symbol_migrate/...` / `db/symbol_schema.rb` — `customer_reauth_sessions.customer_token_id`
   - `db/token_migrate/...` / `db/token_schema.rb` — `staff_reauth_sessions.staff_token_id`
   - カラムは現行 schema と同形だが以下の差分:
     - `method` を `null: true` に。
     - `STATUSES` 制約は DB ではなくモデル側 inclusion で表現するため、`status` は string のまま。
     - `attempt_count` default 0、`lapses_at` default `Float::INFINITY` 相当、`purge_at` 同様。
     - `UNIQUE(user_token_id)` / `UNIQUE(customer_token_id)` / `UNIQUE(staff_token_id)`
       を追加(部分インデックスではなく完全 UNIQUE)。
   - 既存の `(<actor>_id, status)` 非 unique インデックスは作らない。
2. モデル関連変更:
   - `UserReauthSession < MarkRecord`, `belongs_to :user_token`
   - `CustomerReauthSession < SymbolRecord`, `belongs_to :customer_token`
   - `OperatorReauthSession < TokenRecord`, `belongs_to :staff_token`
   - actor 側の `has_one :reauth_session` は削除し、token 側に `has_one :reauth_session` を置く。
   - `STATUSES = %w(PENDING VERIFIED CANCELLED EXPIRED)` を `%w(PENDING VERIFIED)` に変更。
   - `validates :method, ..., inclusion: { in: METHODS }` を
     `validates :method, inclusion: { in: METHODS }, allow_nil: true` に変更。
3. 未デプロイ前提なので、actor DB 側に追加された reauth-session
   migration は積み増しせず削除/置換する。
4. `RetentionPurgeJob` の bind 先確認: `Retainable`
   経由で purge 対象に入る配置は変わらないのでコード変更不要のはずだが、ジョブの DB
   connection 切替が token DB を見るよう確認する。
5. schema dump 更新: `bin/rails db:schema:dump` を 3 DB ぶん回し、`db/principal_schema.rb`、
   `db/guest_schema.rb`、`db/operator_schema.rb`、`db/mark_schema.rb`、`db/symbol_schema.rb`、
   `db/token_schema.rb` を全部更新する。

**テスト:**

- `test/models/user_reauth_session_test.rb` / `customer_reauth_session_test.rb` /
  `staff_reauth_session_test.rb` を新 DB に向けて修正。
- `UNIQUE(<token>_id)` 違反で `ActiveRecord::RecordNotUnique` が出ることをアサート。
- `method = nil` で `validates` 通過、`method = "passkey"` も通過、`method = "invalid"`
  で弾かれることを確認。
- `STATUSES` の inclusion が `PENDING` / `VERIFIED` のみで通過、`CANCELLED` / `EXPIRED`
  で弾かれることを確認。

**ロールバック:** 各 migration の `down` で旧 schema を復元できることを `bin/rails db:rollback`
で手動確認。CI には載せない(時間がかかる)。

---

## Phase 2: Service 層の `StepUp::ConfiguredMethods` / `AvailableMethods` 分離

**依存:** なし(Phase 1 と並行可)

**目的:** byte-for-byte 同一になっている 2 サービスを意味分けする。

**作業:**

1. `app/services/step_up/configured_methods.rb`:
   - 内容は現状維持(`email VERIFIED|VERIFIED_WITH_SIGN_UP`, `passkey ACTIVE`, `totp ACTIVE`)。
   - **後で外から見たときに「永続状態のみ」を表すと一目で分かるよう**
     module コメントを 1〜2 行入れる。
2. `app/services/step_up/available_methods.rb`:
   - シグネチャを `call(subject, ticket: nil)` に変更。
   - `Configured` を呼び出し、そこから以下を差し引く:
     - `methods_in_cooldown(subject)`: Solid Cache の
       `step_up_cooldown:{actor_type}:{actor_id}:{method}` キーが存在する method を除外。
     - `ticket && ticket.attempt_count >= 5` なら空集合を返す。
   - cooldown 値の定数を `StepUp::Cooldowns = { email_otp: 60, passkey: 5, totp: 5 }.freeze`
     で定義。
   - cooldown の書き込みは別 module(`StepUp::CooldownStamp.call(actor, method)`
     等)で行う想定。書き込み箇所は Phase 4 の reauth 試行記録時に呼ぶ。
3. サーフェス別の `step_up_supported_methods` を `Verification::Base`
   側ですでに分けているのを前提に、 `ConfiguredMethods` / `AvailableMethods`
   自体はサーフェス区別なく全 method を見る。サーフェスフィルタは呼び出し側(`Verification::Base#step_up_supported_methods`)で交差を取る。
4. `app/services/step_up/cooldowns.rb` 等の補助 module を `step_up/` 配下に追加。

**テスト:**

- `test/services/step_up/configured_methods_test.rb`: 3 種 method の有無で正しい集合を返すこと。
- `test/services/step_up/available_methods_test.rb`:
  - Configured と一致する基本ケース。
  - cooldown キー入りで該当 method が剥がれること。
  - `ticket.attempt_count >= 5` で空集合になること(method cooldown は無関係)。
  - Customer / Staff 各 actor で同様に動くこと。

---

## Phase 3: Scope カタログのバグ修正

**依存:** Phase 2(`Verification::Base` を触る前提を共有)

**目的:** `ALLOWED_SCOPES` の 2 件のバグを修正、`manage_totp` → `configuration_totp` rename。

**作業:**

1. `ALLOWED_SCOPES`(`app/controllers/concerns/sign/app_verification_base.rb` および同 com /
   org 相当の concern)を以下の 9 件に揃える(ADR § D 参照):

   ```ruby
   ALLOWED_SCOPES = {
     "social_unlink"           => %r{\A/social/},
     "session_revoke_all"      => %r{\A/configuration/sessions},
     "withdrawal"              => %r{\A/configuration/withdrawal},
     "configuration_email"     => %r{\A/configuration/emails},
     "configuration_telephone" => %r{\A/configuration/telephones},
     "configuration_passkey"   => %r{\A/configuration/passkeys},
     "configuration_mfa"       => %r{\A/configuration/challenge},
     "configuration_secret"    => %r{\A/configuration/secrets},
     "configuration_totp"      => %r{\A/configuration/totps},
   }.freeze
   ```

2. `app/controllers/sign/app/configuration/totps_controller.rb` の `verification_scope` を
   `"manage_totp"` → `"configuration_totp"` に変更。
3. 全 controller の `verification_scope`
   文字列を grep して、上の 9 種から外れたものが残っていないか確認。
4. surface 別の concern(`app_verification_base` / `com_verification_base` /
   `org_verification_base`)で `ALLOWED_SCOPES`
   が同じ内容になるよう、共有可能なら 1 箇所に切り出して include で取り込む(設計判断は実装側に任せる、無理に共通化しなくてよい)。

**テスト:**

- 各 surface の `VerificationsController` integration test で 9 scope すべてが
  `/verification?scope=X&rt=...` に対して `BadRequest`
  を出さず、ちゃんと reauth セッションを start することを確認。
- `session_revoke_all` を含むセッション破棄経路の integration test を 1 件追加。

---

## Phase 4: `Verification::Base` の DB-backed 化と bootstrap ヘルパー

**依存:** Phase 1, Phase 2, Phase 3

**目的:** cookie 経路から DB 経路に切替、`require_step_up_unless_bootstrap!` を追加、
`enforce_step_up_prereqs!` の分岐を ADR § F に合わせる。

**作業:**

1. `app/controllers/concerns/verification/base.rb`:
   - `verification_satisfied?` の cookie ベース判定は **撤去**。
   - 機微操作ゲート発火時に current token の `reauth_session` を upsert する処理を
     `require_step_up!` の中に追加(具体的なメソッド名は実装者裁量、ただし `find_or_initialize_by`
     ベース)。
   - `start_reauth_session!`(現 `VerificationReauthSessionStore` 内)を DB upsert に書き換え。
     `session[REAUTH_SESSION_KEY]` への書き込みは削除。
   - `require_step_up_unless_bootstrap!(scope:)` を追加。現在の accepted ADR では
     `ConfiguredMethods.empty?` ではなく、actor の `multi_factor_status_id = 5`
     (`UNCONFIGURED`) を bootstrap 判定に使う:
     ```ruby
     def require_step_up_unless_bootstrap!(scope:)
       return true if step_up_bootstrap_unconfigured?
       require_step_up!(scope: scope)
     end
     ```
   - `enforce_step_up_prereqs!` の分岐は `multi_factor_status_id = 5`
     のときのみ setup へ。ACTIVE + Available 空(全部 cooldown / lockout)なら通常 `/verification` へ。
   - `step_up_satisfied?` は引き続き `actor_token.last_step_up_at`
     を見る(成功事実はトークン側に持たせる)。reauth_session 行の VERIFIED は補助レコード。
   - TTL 定数を `STEP_UP_TTL = REAUTH_TTL = 15.minutes` で統一。`VERIFICATION_GET_TTL` /
     `VERIFICATION_POST_TTL` は削除。
2. `app/controllers/concerns/sign/verification_reauth_session_store.rb`:
   - cookie 操作を DB upsert に書き換え。
   - `current_reauth_session` は current token の `reauth_session` を返す。
   - 旧 `session[REAUTH_SESSION_KEY]` への参照を全削除。`session[EMAIL_OTP_SESSION_KEY]` はSolid
     Cache 経由に移す(Phase 5)。
3. `app/controllers/concerns/sign/{app,com,org}_verification_base.rb`:
   - `REAUTH_TTL = 15.minutes` を残す(または 1 箇所に統合)。
   - `EMAIL_OTP_SESSION_KEY` 参照を撤去。
4. `consume_reauth_session!`(`VerificationReauthLifecycle`)の中:
   - `actor_token.update!(last_step_up_at: Time.current, last_step_up_scope: scope)`
   - pending `reauth_session` row を削除する。
   - `clear_reauth_state!` の意味を「Solid Cache の challenge state を削除する」に変更。
5. `attempt_count` を増分する処理を各 method の検証失敗パス(`verify_email_otp!` / `verify_totp!` /
   passkey verify)に仕込む。`attempt_count >= 5` で `AvailableMethods.call(actor, ticket:)`
   が空集合を返すので、上位の表示制御は自然に閉じる。

**テスト:**

- DB 上の `reauth_session`
  が gate-entry で正しく upsert されること(別 scope での再入場で既存行が上書きされること)。
- `require_step_up_unless_bootstrap!` が `multi_factor_status_id = 5` のとき通り抜け、`1` のとき
  `require_step_up!` 経路に入ることを controller test で確認。
- `attempt_count >= 5` で `AvailableMethods` が空、`/verification`
  画面で「再認証一時停止中」メッセージが出ること(integration test)。

---

## Phase 5: Challenge state の Solid Cache 移行(B-2)

**依存:** Phase 4

**目的:** email OTP の secret/counter、WebAuthn challenge を session cookie から Solid Cache へ。

**作業:**

1. キー名規約: `reauth_session:#{reauth_session.id}:#{method}`、TTL は `STEP_UP_TTL` 以下。
2. `Sign::AppVerificationBase#send_email_otp!` / `verify_email_otp!` を Solid
   Cache 経由に書き換え。`session[EMAIL_OTP_SESSION_KEY]` 参照を完全撤去。
3. passkey の challenge issuance も同様に Solid Cache に移す。
4. サーバー再起動で in-flight
   challenge が無効化されることを許容(reauth_session 行は残るのでユーザーは方式選び直しから再開可能)。

**テスト:**

- email OTP 送信 → 60 秒以内の再送信が cooldown で弾かれること。
- email OTP secret が Solid Cache から消えた状態で `verify_email_otp!`
  が「再送信が必要」エラーを返すこと。
- passkey の challenge も同様に Cache TTL 後失効すること。

---

## Phase 6: 登録系 controller の bootstrap 免除と `rt` 復元

**依存:** Phase 4

**目的:** ADR § E のテーブルに従って `before_action` を張り直し、create 完了で `params[:rt]`
に従って X' redirect する。

**作業(app 例。com / org も同型に展開):**

1. `app/controllers/sign/app/configuration/passkeys_controller.rb`:
   - `before_action -> { require_step_up_unless_bootstrap!(scope: "configuration_passkey") }, only: %i(new create)`
   - `before_action -> { require_step_up!(scope: "configuration_passkey") }, only: %i(edit update destroy)`
   - `create` 成功時の redirect で `rt` を尊重する分岐を追加(下記 `bootstrap_return_path` 参照)。
2. `app/controllers/sign/app/configuration/totps_controller.rb`:
   - 同様。`configuration_totp` scope を使う。
3. `app/controllers/sign/app/configuration/emails/registrations_controller.rb`:
   - 4 アクションすべて `require_step_up_unless_bootstrap!` を before_action に。
   - 最終確認(`update`)成功時に `rt` を尊重。
4. `app/controllers/sign/com/configuration/{passkeys,emails/registrations}_controller.rb`:
   - app と同型(com には TOTP 無し、Phase 7 で削除済み)。
5. `app/controllers/sign/org/configuration/passkeys_controller.rb`:
   - bootstrap 免除は passkey のみ。
   - org の email registration controllers は **bootstrap 免除しない**(`require_step_up!` のみ)。
6. 共通ヘルパーを `Verification::Base` か新規 concern に置く:

   ```ruby
   def bootstrap_return_path(default_path)
     rt = params[:rt].to_s
     return default_path if rt.blank?

     decoded = Base64.urlsafe_decode64(rt) rescue nil
     safe = safe_internal_path(decoded.to_s)
     safe.presence || default_path
   end
   ```

7. 各 create / update 成功時:
   ```ruby
   safe_redirect_to(
     bootstrap_return_path(sign_app_configuration_path(ri: params[:ri])),
     fallback: sign_app_configuration_path(ri: params[:ri]),
     notice: I18n.t("sign.app.configuration.bootstrap.proceed_to_action"),
   )
   ```
   (i18n キーは実装者が新設する。com / org も同型のキーを設ける)

**テスト:**

- bootstrap = true(`multi_factor_status_id = 5`)で `/configuration/passkeys/new` に入れることを controller
  test で確認。
- 同状況で create 成功後、`rt` で指定した URL に redirect されること、flash[:notice] が立つこと。
- bootstrap = false(`multi_factor_status_id = 1`)で同じ URL に入ろうとすると step-up ゲートが発火することを確認。
- TOCTOU シミュレーション:
  GET でフォームを取得し、別経路で credential を作成してから POST すると step-up 経路に入ることを確認(integration
  test)。

---

## Phase 7: `SetupsController` の刷新

**依存:** Phase 2, Phase 6

**目的:** サーフェス別に「未登録の method だけ」リンク表示。すべて登録済みなら `/verification`
へ即 bounce。

**作業:**

1. `app/controllers/sign/{app,com,org}/verification/setups_controller.rb`:
   - `new` アクションで `configured_step_up_methods` と `step_up_supported_methods` を計算。
   - `step_up_supported_methods - configured_step_up_methods` が空なら、`/verification`
     へ即redirect(`safe_redirect_to verification_redirect_path(...)`)。
   - 空でなければ、その差集合だけを `@missing_methods` に詰める。
   - `@rt = params[:rt]` のロジックは現状維持。
2. view `app/views/sign/{app,com,org}/verification/setups/new.html.erb`:
   - `@missing_methods` をループしてリンクのみ表示。telephone リンクは削除(ADR §
     E に従い bootstrap 対象外)。
   - org 用 view は passkey 1 リンクのみ。
   - 各リンクに `ri: params[:ri], rt: @rt` を渡す。
3. com setup view から TOTP リンクを除去(Phase
   8 で controller も routes も消えるので、view 側の修正だけここで)。

**テスト:**

- credential 0 件で `/verification/setup/new` が 200 を返し、3 種(app)/ 2 種(com)/
  1 種(org) のリンクを描画すること。
- 1 件登録済みの状態で同 URL に入ると、登録済み method のリンクが消えていること。
- 全種登録済みの状態で同 URL に入ると `/verification` に redirect されること(302)。

---

## Phase 8: com TOTP 削除と orphan view 撤去

**依存:** Phase 7(setup view の TOTP リンクが先に消えていないと 404 リンクが残る)

**目的:** com で TOTP を扱わない方針(ADR § E)に従ってコードを物理削除、orphan view を片付け。

**作業:**

1. `config/routes/sign.rb` の com 側ブロック:
   - `namespace :verification` 内の `resource :totp, only: %i(new create)` 行を削除。
   - `namespace :configuration` 内の `resources :totps, ...` 行を削除。
2. ファイル削除:
   - `app/controllers/sign/com/verification/totps_controller.rb`
   - `app/views/sign/com/verification/totps/`(ディレクトリごと、存在すれば)
   - `app/views/sign/app/reauth/{index,new,show,edit}.html.erb`
   - `app/views/sign/org/reauth/{index,new,show,edit}.html.erb`
3. i18n キー:
   - `sign.app.reauth.*` / `sign.org.reauth.*` が他で参照されていないことを確認したうえで
     `config/locales/` から削除。
   - com の TOTP 関連 i18n キーも未参照なら削除。

**テスト:**

- com の `/configuration/totps` が 404 を返すこと(routing test)。
- 削除ファイルへの require / render 参照が他に無いこと(grep + CI)。

---

## Phase 9: 整合性とドキュメント

**依存:** Phase 1〜8

**目的:** 全フェーズ完了後の最終チェック。

**作業:**

1. `adr/sign-configuration-sprint-spec.md` の「Implementation
   Status」表に、本 ADR で実装された仕様(step-up
   DB 移行、bootstrap 復活)が反映されているか確認。必要なら追記。
2. `docs/spec/authentication-authorization-requirements-phase-1.md`
   の step-up 関連記述を ADR 整合に。
3. 本プランを `plans/active/` から `plans/archive/` に移す(全フェーズ完了後)。

**テスト:**

- 主要ユーザーフロー 3 シナリオの end-to-end integration test:
  - **Bob シナリオ**: social-login のみで作ったアカウントで `/configuration/apple#destroy`
    を踏み、setup → passkey 登録 → 自動 bounce → reauth → Apple unlink 完了。
  - **Frank シナリオ**: passkey + email 既登録で `/configuration/withdrawal` → reauth →
    withdrawal 開始。
  - **Eve シナリオ**: passkey 1 件のみで 5 回連続失敗 → ticket lockout → `/verification`
    で「再認証一時停止中」表示。

---

## 実装に入る前のチェックリスト(別 AI 向け)

- [ ] `adr/reauth-step-up-redesign.md` 全文を読み、決定事項と理由を理解した
- [ ] 既存の `app/services/step_up/*.rb`、`app/controllers/concerns/verification/base.rb`、
      `app/controllers/concerns/sign/{app,com,org}_verification_base.rb` を読んだ
- [ ] 3 DB(`principal`, `guest`, `operator`)それぞれの schema dump 生成手順を把握した
- [ ] テスト DB の用意ができている(`bin/rails db:test:prepare`)
- [ ] PR は Phase 単位で切る方針を理解した
- [ ] AGENTS.md の禁止事項(`permit!`, `skip_before_action`, `html_safe`, etc.)を遵守する
