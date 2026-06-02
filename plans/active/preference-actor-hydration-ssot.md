# プラン: Actor.preferences を Preference JWT(=DB の署名付き射影) から hydrate する（B案で実装 → 長期 A案へ）

> **Deprecated by Identity Authority inversion where this plan assigns preference authority to
> `sign/id`:** `acme/www` now owns Session, Token, Account, Preference, Authorization, and
> downstream-token authority. `sign/id` is ceremony-only. Physical DB movement is out of scope.
> Implementation details in this plan must not be used to reintroduce sign-side authority. Existing
> sign-side tables/models do not imply sign-side authority.

Status: B案 実装完了（2026-05-30）。長期 A案は
`plans/backlog/preference-explicit-child-records-model-a.md` に残置。関連:
`plans/active/preference-jwt-runtime-cache-migration.md`、ADR `preference-soft-bubble-doctrine.md` /
`actor-current-facade.md` / `localization-preference-flow.md`

> **実装サマリ（2026-05-30）:**
>
> - B-1: `explicit_fields`(jsonb, default `[]`, not null) を `app/com/org_preferences`
>   に追加（`db/{app,com,org}_settings_migrate/20260530120000_*`）。dev/test
>   DB へ適用済み。マーキングは `Preference::ExplicitFields` concern（`mark_field_explicit!` /
>   `clear_explicit_fields!`）で、明示update（`core.rb`
>   `update_preference_child_with_resource_first!`）時に立て、reset（`reset_app_org_preference_to_defaults!`）時に消す。
> - B-2: `build_preferences_payload` に `explicit` リストを追加（`base.rb`）。
> - B-3: `Actor::Preference` に `explicit_fields` と `language_explicit?` / `explicit?` を追加、
>   `from_jwt` が `explicit` を読む。`==`/`hash`/`with_cookie` 更新。
> - B-4: `resolved_current_preference` は `preference_payload_preferences`
>   から hydrate（payload 不在は NULL+overlay）。`overlay_language` は `null?` ではなく
>   `language_explicit?` で判定。
> - B-6:
>   3面 hydration テスト（`.../region/language_payload_hydration_test.rb`）、overlay 単体、lifecycle/support 単体を更新。全グリーン。
> - B-7: 上記3 ADR と `docs/architecture/preference.md` を追補/更新。
>
> **注意（構造ダンプ）:** リポジトリの `db/*_structure.sql`
> は現状 18 行のスタブ（このブランチは migration 直実行で DB を構築している）。`bin/rails db:migrate`
> を回すと全 27 ダンプが環境依存フォーマットで全面書き換えされる（並行作業の migration も巻き込む）ため、構造ダンプはスタブのまま据え置いた。正規ダンプ再生成は
> `bin/rails db:migrate:reset` ワークフローで別途行うこと。`db:verify_no_schema_drift`
> はスタブ相手では意味を成さない。

## Context（なぜ）

`id.umaxica.*/preference/region/language/edit?ri=jp`
で英語を選んでも i18n が切り替わらない。ロケールは `apply_localization_preferences` →
`Actor.preferences.language`（`preference/localization.rb`）で決まるが、 `Actor.preferences` を作る
`resolved_current_preference`（`app/controllers/concerns/actor_support.rb:212`）が
**認証アクセストークンの `prf` クレーム**だけを読み、実測で次が判明している:

- `resolved_current_token` は preference 文脈で `nil`（`load_access_token_payload` が boolean を返し
  `is_a?(Hash)` ガードで捨てられる）。
- `prf` は `build_auth_preference_snapshot`（`authentication/jwt_tokens.rb:88`）が
  `resolved_current_preference`(=NULL+URLオーバーレイ)から作るため
  **DB(SSoT) を一度も写していない**。
- 真の DB 射影である **Preference JWT (`*_preference_access`)** は `@preference_payload`
  にデコード済みなのに Actor に使われていない。

結果、保存済み/選択済みの言語が無視され、`?ri=jp`
の region 由来言語が常に勝つ。ADR は「DB がSSoT、prf はその transport」を意図しているが、実装上 prf は transport として死んでいる。

決定：**Actor.preferences は Preference JWT payload（DB の署名付き射影）から hydrate する。**
auth トークンの `prf` 生成撤去は別タスク（当面 prf は unread データとして残置）。

## 重要な裏付け（調査結果・実コード確認済み）

- Preference JWT は全ブラウザリクエストで
  `set_preferences_cookie`（`preference/transport.rb`）によりゲスト含め発行され、
  **`set_current_actor` より前**にロード済み（sign/core/acme 全 application_controller、および
  `test/security/invariants/controller_lifecycle_order_invariant_test.rb` の `REQUIRED_ORDER`
  で順序固定済み）。→ payload からの hydration は
  **追加DB/再発行なしの read-only**（ADR の read 制約を満たす）。
- payload `preferences` のキー（`lx/ri/tz/ct/cu/df/tf/mo/dn/ipp/r18s`、`base.rb:618-657`）は
  `Actor::Preference.from_jwt`（`app/models/concerns/actor/preference.rb:186-210`）と**完全一致**。
- `preference_payload_preferences`（`base.rb:738`）が `@preference_payload["preferences"]`
  を返す既存入口。

## 構造的制約（B/A 共通の核心）

**現状、「ユーザーが明示的に選んだ」か「自動でデフォルトが入った」かを区別する信号が一切ない。**
`create_preference_option_records`（`base.rb:206`）がレコード生成時に全
`CHILD_RECORD_TYPES`(language 含む) を必ず `default_option_id`
で作る（`resolve_option_id_from_param`
は param 空なら default を返す、`base.rb:238`）。そのため B案で「永続状態を読む」と、どのレコードも常に
_明示的に ja を選んだ_ ように見え、ユーザールール（**未設定なら `?ri=jp`→ja /
`?ri=us`→en と動的に region シード、明示設定は勝つ**）を満たせない。→ 「明示 set」を表す信号の新設が必須。**今回は B（マーカー追加）で実装し、長期的に A（不在＝未設定モデル）へ移行する。**

## 確定ルール（テストに明記すること）

- 言語を **明示設定**したユーザー: その言語が `?ri` より勝つ（例: 保存 en は `?ri=jp` でも en）。
- **未設定（自動default のみ）**のユーザー: region が動的にシード。`?ri=jp`→ja、`?ri=us`→en。
- URL の `?lx=` 明示はすべてに優先（リクエストローカル overlay、DB/JWT は書かない）。

---

## 実装: B案（今回やる）

### B-1. 明示 set マーカーをスキーマに追加

- セッション側 `AppPreference` / `ComPreference` / `OrgPreference`（各 setting DB:
  `app_setting`/`com_setting`/`org_setting`）に `explicit_fields`(jsonb, default `[]`, not
  null) 等を追加。**3 DB それぞれにマイグレーション**（soft bubble は別個）。
  - 可逆・後方互換・スキーマ/データ分離。`bin/rails db:migrate:reset`
    ではなく通常マイグレで可（rename ではない）。
  - push 前に `bin/rails db:verify_no_schema_drift`。
- 明示 update 経路でフラグを立てる:
  `update_preference_child_with_resource_first!`（`preference/core.rb`）が走ったフィールドを
  `explicit_fields`
  に追加。reset（`reset_app_org_preference_to_defaults!`）では当該フィールドを除去。

### B-2. payload に明示情報を載せる

- `build_preferences_payload`（`base.rb:618`）に `explicit`（明示済みフィールドのリスト）を追加。
- 既存の値キーは従来どおり default 埋めのまま（他 consumer 非破壊）。

### B-3. Actor 値オブジェクトに明示情報を保持

- `Actor::Preference`（`app/models/concerns/actor/preference.rb`）に「明示済みフィールド集合」を持たせ、
  `language_explicit?` 等の述語を追加。`from_jwt` で payload の `explicit` を読む。
  `==`/`hash`/`to_h` の整合も更新。

### B-4. hydration とロケール解決

- `resolved_current_preference`（`actor_support.rb`）: `prf` ではなく
  `preference_payload_preferences` から `Actor::Preference.from_jwt`
  で構築（payload 不在時は従来どおり NULL+overlay）。read-only を厳守。
  - `respond_to?(:preference_payload_preferences, true)`
    ガードで preference 概念を含まない文脈は NULL に落とす。
- `overlay_language`（`actor_support.rb`、本セッションで追加済み）: 「言語が明示済みなら永続言語が勝つ／未設定なら
  `locale_from_request_region(ri)` が勝つ」へ調整（whole-record `null?` ではなく
  **language の明示性**で判定）。
  - 優先順位: `context[:lx]`（URL明示） → 言語が明示済みなら `preference.language` → `region 由来` →
    default。

### B-5. 受容するトレードオフ（明記）

- Bearer/OIDC API（`sign/*/oauth/user_info_controller.rb`）と `set_preferences_cookie`
  をスキップする約51エンドポイント（JWKS/cookie/theme/edge）は Preference JWT cookie を持たない →
  NULL+overlay。
  - userinfo は今も prf 無し（`oidc/token_exchange_service.rb`）なので回帰ほぼ無し。実装時にローカライズ依存が無いこと確認。

### B-6. テスト（確定ルールを明記）

- 明示 en ＋ `?ri=jp` → 英語描画（3面）。本セッション雛形:
  `test/controllers/sign/{com,org,app}/preference/region/language_payload_hydration_test.rb`。
- 言語更新フロー: redirect は `lx` を載せず（`language_preference_redirect_params` は `except: :lx`
  のまま）、follow_redirect 後に英語描画＋DB=EN。`languages_update_test.rb`。
- **未設定ユーザー**: `?ri=jp`→ja / `?ri=us`→en を 3面で（新規）。
- 明示日本語(=既定値)＋`?ri=us` → 日本語が勝つ（B の利点。C案の穴を踏まないことの回帰）。
- lifecycle 不変条件（`test/integration/actor_support_lifecycle_test.rb`）: 「未設定は NULL 相当（region シード可）/ 明示は非null」へ更新。
- `overlay_language` 単体:
  `test/controllers/concerns/actor_support_overlay_language_test.rb`（本セッション追加済み、明示性ベースへ更新）。

### B-7. ADR/ドキュメント（日本語）

- `preference-soft-bubble-doctrine.md` / `actor-current-facade.md` の「Actor は access-token
  prf から構築」を「Preference JWT
  payload から hydrate」に supersede 追補。`localization-preference-flow.md`
  を整合更新。「明示 vs 未設定」「未設定時 region シード」「Bearer/skip は NULL」を明記。auth
  prf は当面 unread で残置と明記。

### 検証

- `bin/rails test test/controllers/sign/{com,org,app}/preference/region/ test/controllers/concerns/actor_support_overlay_language_test.rb`
- `bin/rails test test/integration/actor_support_lifecycle_test.rb test/integration/sign_preference_test.rb test/integration/preference_global_param_context_test.rb`
- cookie-skip/Bearer を実リクor既存テストで NULL+overlay 200 確認。
- `bin/rails db:verify_no_schema_drift`（B-1 のため必須）。

---

## 長期方針: A案へ移行（フォローアップ／別プラン化）

B の `explicit_fields`
マーカーは「全子レコード常在＋別途明示フラグ」という二重表現で、本質的には冗長。長期的には
**A案: 子レコードを明示時のみ作成し、不在＝未設定とする**へ移行する。

- `create_preference_option_records`（`base.rb:206`）: param 不在の type の子を作らない。
- `load_or_create_preference_child`（`base.rb:980`）: 編集画面の表示は in-memory
  build（`load_or_build_selectable_preference_child` `core.rb:364`
  方式）に統一し、閲覧で永続化しない。
- 全 `CHILD_RECORD_TYPES` 反復箇所（`adoption.rb:86,117,270,279` / `resource_sync.rb:75,133,239,248`
  / `core.rb:241,537`）を nil 安全化。
- `build_preferences_payload` は未設定キーを **省略**（default 埋めをやめる）。
- 移行後 `explicit_fields`(B-1) は撤去。
- blast
  radius が大きいので、データ移行（既存レコードの「default のままの子」をどう扱うか）と段階リリースを別プランで設計する。→
  `plans/backlog/` に切り出すこと。

## 既存ツリー状態（本セッション終了時点）

- 探索で入れた未完成の payload hydration（`resolved_current_preference`）は **緑に戻す**（lifecycle
  3件赤を回避）。
- 残す: `overlay_language` と
  `actor_support_overlay_language_test.rb`（B で明示性ベースに更新予定）、 `core.rb` の
  `language_preference_redirect_params`(`except: :lx`)、ユーザー版 `languages_update_test.rb`。
- 雛形として残す/削除は実装着手時に判断（本プランに再現手順あり）。
