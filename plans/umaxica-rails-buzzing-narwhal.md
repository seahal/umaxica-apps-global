# Preference ドメイン総点検 — 完遂プラン (branch: develop)

## Context

Preference 系(App/Com/OrgPreference + Client/Operator/VisitorPreference の dual-store、preference
JWT transport、cookie consent banner、theme/language/timezone
cookie)の総点検。作業ツリーには進行中の監査(memo
`memos/2026-07-02-preference-audit.md`)が既にあり、**C1**(show_banner? が常に false)、**H1**(org
edge cookie の before_action parity)、**M1**(OrgPreferenceCookie の functional
default)は修正済み・未コミット。本プランはその続き: 契約ギャップの回帰テスト追加、残課題(M2 /
GET-edit 副作用 / L1)の修正、契約 doc とレポートの整備。

アーキテクチャ前提(調査で確認済み):

- Token 側 canonical: `AppPreference`/`ComPreference`/`OrgPreference`(`*_setting`
  DB)。anonymous でも refresh cookie → access JWT で運搬。
- Resource mirror: `ClientPreference`/`VisitorPreference`/`OperatorPreference`(`*_principal`
  DB)。書き込みは `PreferenceResourceSync#with_dual_write_transaction` の cross-DB dual write。
- Sign-in 同期:
  `PreferenceAdoption#adopt_preference_for!`(updated_at の新しい側勝ち、option 名で cross-DB コピー)。
- Logout: `PreferenceCore#delete_preference_cookie` は keep-values の no-op(設計意図)。
- 契約 doc: `docs/architecture/preference-behavior-contract.md`(git-modified、権威)。

## ユーザー決定(確定済み)

1. **Logout**:
   keep-values を現状維持し契約に明記。公開 cookie(ct/language/tz 等)は signed-in 有無に関わらず書かれる token 側テーブルの投影であり、そこから生成されるべき、という設計を doc に固定。downgrade 実装は backlog。
2. **GET-edit**: 「DB にないものを仮想的に扱わない」。child row は
   **preference 作成時(bootstrap)に全て永続化**し、GET は読み取り専用にする。既存レコードの欠損 row は正当な書き込みポイントで backfill。
3. **M2**: `change_column_default`(2→0) migration を実施 + `persist_self_replacement`
   は 3 モデルとも **update_column** に統一。
4. **スコープ**: L1(dead alias)削除実施、L2(非正規化カラム退役)は
   `plans/backlog/legacy-preference-models-retirement-plan.md` に委任。committed
   docs/memos/レポートは英語(チャット報告は日本語)。

## 事前作業

読むこと:
`.agents/harnesses/rules/generic/testing.mdc`、`generic/controllers.mdc`、`generic/no-silent-fallback.mdc`、`project/regression-guards.mdc`、`project/value-object-boundaries.mdc`、`docs/operations/db-workflow.md`、`docs/architecture/preference-behavior-contract.md`、`memos/2026-07-02-preference-audit.md`。

## Phase 1 — 回帰テスト先行 (Critical/High ギャップ)

既存パターンを踏襲:
`test/integration/preference_security_test.rb`、`test/controllers/base/edge_v0_cookies_controller_parity_test.rb`。代表 surface
= app、安価なら com/org parity も。

1. `test/integration/preference_corrupt_cookie_test.rb` — 壊れた/ガベージの preference refresh
   cookie・access JWT → raise せず fresh bootstrap、既存 DB 状態を上書きしない。
2. `test/integration/preference_signin_conflict_test.rb` — signed-in + 矛盾する anonymous
   cookie 値 → DB canonical(resource
   mirror)が勝つ(updated_at ルール含む)。anonymous 公開 cookie が DB
   preference を上書きできないこと。
3. `test/integration/preference_logout_downgrade_test.rb` — logout 後: auth transport
   cookie(`__Host-*`
   の session 系)はクリア、guest-safe 公開 cookie(ct/language/tz)は残存、resource 側の account/org/avatar
   context が UI/レスポンスに漏れない。決定 1(keep-values)を契約参照コメント付きで固定。
4. `preference_security_test.rb` 拡張 — cross-surface: app 発行の preference cookie/JWT を com/org
   host に提示 → 無視され fresh bootstrap(HTTP レベル、JWT audience unit test とは別)。
5. `test/integration/preference_concurrent_sync_test.rb` — login sync ×
   PATCH の invariant テスト(Minitest では逐次エミュレーション): unique
   jti/public_id、dual-write 後に canonical row が正確に 1 つ。限界はコメントに明記。
6. `test/integration/preference_read_symmetry_test.rb`
   — 同一 option(theme+language)が anonymous(token 側)/signed-in(resource 側)で期待ソースから読まれること。

各ファイル作成後すぐ実行。既存 5 failure(Phase 4)はここでは追わない。

## Phase 2 — 実装修正

### 2a. GET-edit 副作用撤去(bootstrap 全 child 永続化方式)

- 対象: `app/controllers/concerns/preference_core.rb` / `preference_transport.rb`(bootstrap パス)/
  `base_preference_screen_dispatch.rb` の find_or_create 系 edit ヘルパ。
- preference レコード作成時(`set_preferences_cookie` の bootstrap
  — 契約上許容された書き込みポイント)に全 child row をデフォルト option で作成する。作成は既存の
  `PreferenceClassRegistry` の default_option_id を利用。
- GET
  edit/show は既存 row の読み取り専用へ変更。row が無い場合は仮想表示せず、正当な書き込みポイント(update 時 or
  bootstrap 補修)で backfill — 実装時に既存レコードの欠損 row の扱い(初回 update
  backfill で足りるか)を確認し、GET では絶対に作らない。
- `test/integration/preference_get_edit_current_behavior_test.rb`
  を新契約(GET は row を作らない)のアサーションに書き換え。
- `test/integration/preference_bootstrap_idempotency_test.rb`
  が bootstrap の child 作成込みで冪等のままであること確認。
- リスク: view が persisted record 前提(form
  URL/dom_id)。共有 concern 側で変更し全 surface 同時に動かす。

### 2b. M2 — status_id default + persist_self_replacement 統一

- Migration: `db/app_settings_migrate/` に
  `change_column_default :app_preferences, :status_id, from: 2, to: 0`(reversible)。`docs/operations/db-workflow.md`
  の multi-DB 手順に従い schema 再生成、`bin/rails db:verify_no_schema_drift`
  相当の確認。データ backfill なし。
- `app/models/app_preference.rb:164` の `update!` を com/org と同じ `update_column`
  に統一(post-create の自己参照 backfill、validation 済み)。3 モデルでコメント揃える。
- 事前確認: `grep status_id test/fixtures db/seeds*` で default 2 依存が無いこと。

### 2c. L1 — dead alias 削除

- `app/models/client_preference.rb:59` の `user_preference_colortheme`
  alias を削除(app/test/views の使用ゼロを grep 確認済み・実施前に再確認)。

### 2d. 保守性スイープ(assess-only)

- `app/controllers/*/edge/v0/`・web preference
  controller 群で共有 concern に委譲されていないロジックの有無を確認。小さければ統合、大きければ memo に backlog 記録。PreferenceCore の投機的リファクタはしない。

## Phase 3 — ドキュメント(英語)

1. `docs/architecture/preference-behavior-contract.md`
   — 依頼された 10 状態(anonymous±cookie、invalid cookie、login±DB pref、conflict、signed-in
   update、logout、revisit、surface change)を state transition
   table で網羅しているか照合し、corrupt-cookie 回復・logout keep-values 決定・GET
   read-only 化・bootstrap 全 child 永続化の行を追記/更新。
2. `memos/2026-07-02-preference-audit.md` — M2/L1 resolved、GET-edit 修正、決定 1–4 の rationale、L2
   backlog 委任、既存 5 failure の扱いを追記。
3. 最終レポート: `memos/2026-07-02-preference-audit-report.md` — findings 表(C1/H1/M1/M2/L1/L2 +
   GET-edit + logout)、修正、追加テスト、残リスク、未確定事項、次に見る箇所。

## Phase 4 — 既存 5 failure の triage

`test/controllers/concerns/preference/adoption_test.rb`(2)、`jwt_and_color_theme_test.rb`(2)、`no_implicit_callbacks_test.rb`(1)。Phase
2 後に再実行し、(i) 今回修正で直った / (ii) 小さく直せる / (iii)
out-of-scope として failure 出力付きで memo 記録、に分類。監査成果物をブロックさせない。

## Phase 5 — 検証(狭い順)

```bash
bin/rails test test/controllers/concerns/preference/web_cookie_endpoint_test.rb
bin/rails test test/controllers/base/edge_v0_cookies_controller_parity_test.rb
bin/rails test test/integration/preference_get_edit_current_behavior_test.rb
bin/rails test test/integration/preference_corrupt_cookie_test.rb \
               test/integration/preference_signin_conflict_test.rb \
               test/integration/preference_logout_downgrade_test.rb \
               test/integration/preference_concurrent_sync_test.rb \
               test/integration/preference_read_symmetry_test.rb
bin/rails test test/integration/preference_security_test.rb \
               test/integration/preference_bootstrap_idempotency_test.rb
# migration round-trip (app_setting DB, db-workflow.md 準拠)
bin/rails db:migrate && bin/rails db:rollback STEP=1 && bin/rails db:migrate
# domain sweep → full suite (既存 failure の triage 結果のみ許容)
bin/rails test test/integration/ test/controllers/concerns/preference/
bin/rails test
```

## 主要ファイル

- `app/controllers/concerns/preference_core.rb`(GET-edit / bootstrap)
- `app/controllers/concerns/preference_transport.rb`(bootstrap 起点)
- `app/models/{app,com,org}_preference.rb`(M2)
- `db/app_settings_migrate/`(新 migration)
- `app/models/client_preference.rb`(L1)
- `docs/architecture/preference-behavior-contract.md`、`memos/2026-07-02-preference-audit*.md`
- 新規 test 6 ファイル(Phase 1 参照)

## 残リスク / 未確定

- bootstrap 全 child 永続化により anonymous 初訪問時の insert 数が増える(~12
  row/preference)。パフォーマンス影響は低いはずだが、bootstrap 頻度(bot 流入等)は実装時に確認。
- 既存レコードの欠損 child row の backfill 方式(初回 update 時 lazy
  backfill を想定)は実装時に確定し memo に記録。
- L2(denormalized column 退役)、logout downgrade 実装は backlog 委任のまま。
