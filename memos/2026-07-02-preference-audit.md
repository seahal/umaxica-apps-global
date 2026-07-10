# Preference 実装 総点検（2026-07-02）

## 前提

要求された成果物（Inventory 表、Merge Contract 表、Surface Matrix、State Transitions 表、Cookie
Consent 契約、Security Negative Cases 表、Maintainability Rules）は、監査開始時点ですでに
`docs/architecture/preference-behavior-contract.md` に存在し、内容もほぼ要求と一致していた。併設する
`docs/architecture/preference.md`（Sync Rules、Runtime Read Contract）や
`adr/preference-soft-bubble-doctrine.md`、`adr/preference-relogin-reconciliation-record-recency.md`
も整合している。本監査は「契約の新規設計」ではなく「既存契約と実装の乖離検証」として実施した。

## Inventory（要約）

- **Model**: App/Com/Org Preference（トークン/セッション形の shared surface preference、
  `app_setting`/`com_setting`/`org_setting` DB）と、Client/Operator/Visitor
  Preference（実際のユーザー個人設定、`app_principal`/`org_principal`/`com_principal`
  DB）の2系統。共有の STI/base
  class は存在せず、`PreferenceResettable`/`PreferenceExplicitFields`/`DbscBindable` concern と
  `Actor::Preference` value object のみが横断的に共通化されている。
- **Controller**: base(OP/identity authority)/auth(credential ceremony)/core(BFF) ×
  app/com/orgの3×3構成。HTML編集画面は base のみに存在(`base/{app,com,org}/preference/*_controller.rb`、14画面×3surface)。Cookie
  consent JSON API (`web/v0/cookie`, `edge/v0/cookie`) は base/auth/core すべてに存在。ロジックは
  `preference_core.rb`/`preference_adoption.rb`/
  `preference_resource_sync.rb`/`preference_web_cookie_endpoint.rb`
  等の concern に集約済みで、controller は薄い HTTP アダプタに留まっている（Maintainability
  Rules 準拠）。
- **Test**: `preference_security_test.rb`、`preference_authority_slice_1f_test.rb`、
  `acme_preference_test.rb`（旧 sign_preference_test.rb）、各 surface × namespace の
  `web/v0`・`edge/v0` cookie controller test など広くカバー済み。

## State Transitions — 検証結果

`docs/architecture/preference-behavior-contract.md` の State
Transitions 表に対し、以下を直接コード確認した。

| 状態                            | 検証結果                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| ログアウト                      | **準拠**。`preference_core.rb#delete_preference_cookie` は監査ログのみ書き込む no-op で、実際のログアウト(`sign_outs_controller.rb` → `authentication_logoutable.rb` → `authentication_cookie_store.rb#clear_auth_cookies!`)は auth/session/DBSC cookie のみ削除し、Preference JWT・表示系 cookie には触れない。App/Com/Org Preference のペイロードは language/timezone/theme 等 guest-safe フィールドのみで account/org/security 情報を含まないため、契約の「Keep only guest-safe display state」を満たす。 |
| ログイン時 merge                | **既存対応済み**。`notes/implementation/2026-06-21-preference-dual-write-cross-db-transaction.md` により token側 source-of-truth・cross-DB transaction・silent rescue 除去が実施済み。新規バグなし。                                                                                                                                                                                                                                                                                                         |
| Cookie consent banner           | **バグ確認 → 修正済み（本監査で実施、下記 C1）**。                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Surface 間 before_action 整合性 | **バグ確認 → 修正済み（本監査で実施、下記 H1）**。                                                                                                                                                                                                                                                                                                                                                                                                                                                           |

## 発見事項

### C1. Cookie consent banner が常に非表示だった [Critical → 修正済み]

`app/controllers/concerns/preference_web_cookie_endpoint.rb#show_banner?`
が同ファイル内で既に定義済みの `cookie_consent_state`（consented フラグ保持）を一切参照せず、常に
`false` を返していた。app/com/org すべての `edge/v0/cookies_controller#show`/`#update`
がこの値をそのまま JSON で返すため、**同意未取得の訪問者に対しても Cookie consent
banner が一度も表示されない**状態だった。

修正: `show_banner?` を `!cookie_consent_state.fetch(:consented)` に変更（未同意なら
`true`、同意済みなら `false`）。

### H1. Org の cookie consent エンドポイントが `transparent_refresh_access_token` を skip していなかった [High → 修正済み]

`app/controllers/base/{app,com}/edge/v0/cookies_controller.rb` は
`skip_before_action :transparent_refresh_access_token`
を明示しているが、org版のみこれを欠いていた。org の `Base::Org::ApplicationController` は
`transparent_refresh_access_token` を `unless: -> { request.format.json? }`
付きで定義しているため、真の JSON リクエストでは実害はないが、この JSON-only エンドポイントに非JSON
Accept で到達した場合、org だけアクセストークン refresh の副作用が走り得る非対称性があった。

修正: `app/controllers/base/org/edge/v0/cookies_controller.rb` に
`skip_before_action :transparent_refresh_access_token` を追加。

**訂正**: 当初 `enforce_withdrawal_gate!` の skip も欠落していると判定したが、これは誤り。
`Base::Org::ApplicationController` はそもそも `enforce_withdrawal_gate!`
を before_action として定義していない（staff/operator には customer 相当の withdrawal 概念が存在しない）。
`skip_before_action` を未定義コールバックに対して呼ぶと `ArgumentError`
で起動時にクラッシュするため、実際に `skip_before_action :enforce_withdrawal_gate!`
を org に追加してテストを実行したところ boot エラーで即座に判明した。この訂正を
`docs/architecture/preference-behavior-contract.md` の Maintainability
Rules に明記した（「surface 間の before_action 差分は、親 controller に実際にそのコールバックが定義されているかを確認してから判断すること」）。

### M1. `OrgPreferenceCookie#set_defaults` に `functional` のデフォルト代入が欠落していた [Medium → 修正済み]

app/com の `*PreferenceCookie#set_defaults`
は targetable/performant/functional/consented の 4フラグすべてに `nil`
フォールバックを持つが、org のみ `functional` が抜けていた。DB列は `NOT NULL default(false)`
かつバリデーションもあるため実害は限定的だが、app/com との非対称性として修正した。

### M2（記録のみ・未修正）: AppPreference/ComPreference/OrgPreference の実装非対称性

- `status_id` の DB デフォルトが `AppPreference` は `0`、`ComPreference`/`OrgPreference` は `2`。
- `persist_self_replacement` が `AppPreference` は `update!`、`ComPreference`/`OrgPreference` は
  `update_column`（バリデーションskip）を使用。

いずれも DB デフォルト変更・書き込みロジック変更を伴い、マイグレーション計画と事前承認が必要な範囲のため本パスでは未修正。`plans/backlog/`
へのフォローアップ起票を推奨する。

### L1/L2（記録のみ・未修正）

- `ClientPreference#user_preference_colortheme` は `colortheme→theme` リネーム後に残った死んだ
  `has_one` エイリアス（`user_preference_theme` と同一テーブルを指す）。実害なし。
- Client/Operator/Visitor 側で非正規化カラムと正規化子テーブルが並存しており、実行時読み取り経路は非正規化カラム側のみを使っている可能性が高い（子テーブル側が schema
  debt の疑い）。 `plans/backlog/legacy-preference-models-retirement-plan.md`
  が既にこの領域を扱っているため、新規プランは起票せず既存プランへの参照のみ記録する。

## 変更ファイル

- `app/controllers/concerns/preference_web_cookie_endpoint.rb` — `show_banner?` を
  `cookie_consent_state` ベースの判定に変更（C1）。
- `app/controllers/base/org/edge/v0/cookies_controller.rb` — `transparent_refresh_access_token`
  の skip を追加（H1）。
- `app/models/org_preference_cookie.rb` — `set_defaults` に `functional`
  のデフォルト代入を追加（M1）。
- `docs/architecture/preference-behavior-contract.md` — Cookie Consent 節、Security Negative
  Cases 表、Maintainability Rules に本監査の知見を追記。

## 追加した回帰テスト

- `test/controllers/concerns/preference/web_cookie_endpoint_test.rb` — `show_banner?`
  が consent 状態に応じて変化することを検証（C1 の再現・回帰防止）。
- `test/controllers/base/edge_v0_cookies_controller_parity_test.rb` — app/com/org edge/v0/cookies
  controller の before_action skip 集合の parity を検証（H1 の再現・回帰防止）。
  `enforce_withdrawal_gate!` は org のApplicationControllerに存在しないため対象から明示的に除外。

## 実行したテスト

- `test/controllers/concerns/preference/`（新規2件含む）
- `test/controllers/base/{app,com,org}/{web,edge}/v0/cookie_controller_test.rb`
- `test/models/{app,com,org}_preference_cookie_test.rb`
- `test/integration/preference_security_test.rb`
- `test/integration/preference_booster_test.rb`

新規テスト2件は green。既存テストのうち5件（`adoption_test.rb` 2件、 `jwt_and_color_theme_test.rb`
2件、`no_implicit_callbacks_test.rb` 1件）が失敗しているが、 `git stash`
で本監査の変更を退避した未修正の `develop`
ブランチでも同じ5件が同じ理由で失敗することを確認済み — 本監査の変更とは無関係な既存の失敗であり、回帰ではない。

## 残リスク・未確定事項（2026-07-02 時点、下記 Update で一部解消）

- L2（正規化子テーブルの schema debt）は `plans/backlog/legacy-preference-models-retirement-plan.md`
  に委任済み、本監査ではスコープ外。
- `docs/architecture/preference.md` の Open Questions（"Should logout clear the local copy, or only
  stop writing to
  it?"）は、下記 Update でユーザー承認のうえ「keep-values」で確定した（downgrade 実装は backlog）。
- 既存の5件のテスト失敗（`adoption_test.rb`/`jwt_and_color_theme_test.rb`/
  `no_implicit_callbacks_test.rb`）は本監査スコープ外。develop 上の pre-existing
  failure であることを確認済み（下記 Update でも再確認）。

## Update (2026-07-02): Follow-up fixes and additional regression coverage

Per-repo policy, new findings and fixes below are recorded in English.

### M2 — resolved

`app_preferences.status_id` column default (was `2`, i.e. `AppPreferenceStatus::LEGACY_NOTHING`) is
now aligned with the model's Ruby-level
`attribute :status_id, default: AppPreferenceStatus::NOTHING` (`0`), via a reversible migration:
`db/app_settings_migrate/20260702000000_change_app_preferences_status_id_default_to_nothing.rb`
(`change_column_default`, `from: 2, to: 0`). `Com`/`OrgPreference` already default to their own
`NOTHING` (`2`), so no change was needed there. `AppPreference#persist_self_replacement` was unified
to `update_column` (matching Com/Org) since it only backfills a self-reference immediately after a
validated create.

### L1 — resolved

Removed the dead `has_one :user_preference_colortheme` alias from `app/models/client_preference.rb`
(left over from the `colortheme` → `theme` rename; pointed at the same table as
`user_preference_theme`). Confirmed zero references outside the model definition and historical
migration files before removing.

### GET-edit side effect — found and fixed

`*_preferences_edit` actions for region/language/timezone/theme (`preference_core.rb`) previously
called the persisting `load_or_create_preference_child`, which creates a missing child row as a side
effect of a `GET`. This violated the contract's "no GET mutation" rule whenever a child row was
missing (normally impossible after bootstrap, but reachable for legacy rows or after manual repair).

Fix: added a GET-safe reader, `PreferenceBase#load_or_build_preference_child` (returns an
unpersisted default `.new` record when the row is missing, mirroring the existing
`load_or_build_selectable_preference_child` pattern already used for the "selectable" family) and a
matching `PreferenceCore#load_or_refresh_preference_child_for_edit`. All four `*_preferences_edit`
actions now use it; the corresponding `*_preferences_update` actions keep using the persisting
loader, since a `PATCH` is a legitimate write point.
`test/integration/preference_get_edit_current_behavior_test.rb` was rewritten to assert the new
contract (row is not created on GET) instead of documenting the old side effect.

### Corrupt/cross-surface refresh token — clarified, no code change needed

Regression tests (`test/integration/preference_corrupt_cookie_test.rb`,
`test/integration/preference_security_test.rb`) confirmed the existing behavior is already
contract-safe: a _presented but invalid_ refresh token (garbage value, or a token belonging to a
different surface's preference table) fails closed with `401` and clears the stale cookie — it never
resolves to, adopts, or mutates an unrelated preference row. A refresh cookie that was simply never
presented still bootstraps a fresh guest preference normally. No raise, no DB corruption either way.

### Logout keep-values — decision confirmed, documented

Per explicit user decision, logout keeps the guest-safe display preference (language/timezone/theme/
cookie-banner suppression) as-is; only auth/session transport cookies are cleared. This was already
the implemented behavior (`PreferenceCore#delete_preference_cookie` is an intentional keep-values
no-op); `docs/architecture/preference-behavior-contract.md`'s State Transitions table was updated to
state this as the accepted contract rather than describe it as an unresolved "downgrade" TODO.
`test/integration/preference_logout_downgrade_test.rb` pins this behavior.

### Additional regression tests

- `test/integration/preference_corrupt_cookie_test.rb`
- `test/integration/preference_signin_conflict_test.rb` (verified the verified access token wins
  over a conflicting public display cookie for both theme and cookie-consent reads)
- `test/integration/preference_logout_downgrade_test.rb`
- `test/integration/preference_concurrent_sync_test.rb` (jti/public_id uniqueness and
  single-canonical-row invariants across a burst of sequential writes; true thread concurrency is
  impractical in Minitest)
- `test/integration/preference_read_symmetry_test.rb` (anonymous vs. signed-in theme read agreement,
  including the resource-mirror's denormalized `theme` column)
- Extended `test/integration/preference_security_test.rb` with the two cross-surface inertness cases

### Test run

All new/updated tests pass. Re-ran `test/controllers/concerns/preference/`,
`test/integration/preference_security_test.rb`, `test/integration/acme_preference_test.rb`,
`test/integration/preference_booster_test.rb`, and model tests
(`test/models/{app,com,org}_preference_test.rb`,
`test/models/{app,com,org}_preference_cookie_test.rb`) after the M2/GET-edit changes: the same 5
pre-existing failures noted above reproduce unchanged (`adoption_test.rb` ×2,
`jwt_and_color_theme_test.rb` ×2, `no_implicit_callbacks_test.rb` ×1) — confirmed pre-existing on
`develop`, unrelated to this pass's changes, and left untouched per the approved plan (out of scope
for this audit).
