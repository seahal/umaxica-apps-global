# Preference フォローアップ監査・是正計画（2026-07-03）

## Context

Preference ドメイン(language/timezone/theme/cookie consent の UX 設定)の総点検依頼。調査の結果、
**2026-07-02 に同スコープの監査が既に完了しており**(`memos/2026-07-02-preference-audit-report.md`)、Critical/High の主要項目(show_banner?
hardcode C1、org edge cookie H1、OrgPreferenceCookie default M1、status_id default drift
M2、GET-edit 副作用、dead colortheme alias L1)は修正・回帰テスト済み。
`docs/architecture/preference-behavior-contract.md` も Surface Matrix と State
Transitions 表を既に持つ。

本パスは前回監査の**残存ギャップのみ**を対象とする。今回の再探索で新規に確認した事実:

- **A(High)**: `::PreferenceAdoption` が `base/com` と `core/com`
  の ApplicationController だけ未 include。app/org は base/core/auth/side 全 tier で include 済み、com は auth のみ。両コントローラは
  `AuthenticationVisitor` を include しており visitor サインイン状態で到達しうる面。preference
  refresh cookie 喪失→再作成時に
  `PreferenceTransport#restore_preference_from_resource!`(preference_transport.rb:53-55) が
  `respond_to?` ガードで silent no-op になり、VisitorPreference ミラー同期が走らない。ADR・contract
  doc・テストのどこにも意図的省略の記述なし → include 漏れと判断。
- **B(Low)**:
  `PreferenceBase#show_cookie_banner?`(preference_base.rb:65-67)は常に false を返す死にコード。runtime 呼出ゼロ(参照は存在性アサートのテスト 2 件のみ)。banner 判定の正は
  `PreferenceWebCookieEndpoint#show_banner?`(JWT 由来、前回 C1 で修正済み)。
- **C(Medium)**: テストギャップ 6 件(下記 WI-3)。
- **D(Low)**: `db:verify_no_schema_drift`
  が docs/operations/db-workflow.md から参照されるが rake タスク不在。
- **E(記録のみ)**: develop 上の既存失敗テスト 5 件(adoption_test ×2、jwt_and_color_theme_test
  ×2、no_implicit_callbacks_test ×1)。

なお `GET /web/v1/cookie` は存在せず、実パスは `GET /web/v0/cookie`(v1
namespace はリポジトリに無い)。show は `{ show_banner: bool }` JSON、update は `head :no_content`
で契約どおり(前回監査で検証済み)。

## 作業項目

### WI-1: base/core com への PreferenceAdoption include(High)— tests-first

1. 先に red テスト:
   - include-parity テスト: `Base::Com::ApplicationController` / `Core::Com::ApplicationController`
     が `PreferenceAdoption` を include していることをアサート。
   - 統合テスト: サインイン済み visitor + preference refresh cookie 無しで base/com GET →
     ComPreference 新規作成時に VisitorPreference ミラーが作成/同期されること (`test/integration/com_visitor_preference_current_behavior_test.rb`
     拡張)。
2. 実装:
   `app/controllers/base/com/application_controller.rb`・`app/controllers/core/com/application_controller.rb`
   に `include ::PreferenceAdoption` を app/org 兄弟ファイルと同位置に追加。
3. com 固有の副作用が出た場合のみ「意図的省略」として contract doc 記録に切替(fallback)。

編集前に `.agents/harnesses/rules/generic/controllers.mdc`・`testing.mdc`・
`project/controller-inheritance.mdc` を読む。

### WI-2: dead `show_cookie_banner?` 削除(Low)

- `app/controllers/concerns/preference_base.rb:65-67` を削除。
- 存在性テスト削除: `test/controllers/concerns/preference/base_included_do_test.rb:12-13`、
  `base_test.rb:1066` の該当アサート。

### WI-3: テストギャップ充填(Medium)— テスト追加のみ、red になれば個別にバグとして報告

1. CSRF: app/com/org 各面の `PATCH /web/v0/theme`・`PATCH /web/v0/cookie`
   をトークン無しで叩き拒否確認 (既存 `/edge/v0/cookie` CSRF テストのパターン踏襲)。新規
   `test/integration/preference_web_csrf_test.rb`。
2. cross-surface: `test/integration/cross_surface_token_test.rb` に com↔app / com↔org の preference
   token 拒否ケースを追加(現状 app↔org のみ)。
3. option_id tampering: region/language/timezone/theme update へ `option_id: 99999` や他面の option
   id を送信し拒否/DB 不変を確認。新規 `test/integration/preference_option_tampering_test.rb`。
4. consent 不正値: `PATCH /web/v0/cookie` に `consented: "banana"`・配列・ネスト hash
   → 拒否/正規化。
5. 不正 timezone: `/web/v0`・`/edge/v0` JSON 経由の `"Mars/Olympus"` 等 → 拒否/フォールバック。
6. merge 勝者判定: `PreferenceAdoption#sync_preferences!`
   の updated_at 勝者を両方向で end-to-end 検証。新規
   `test/integration/preference_adoption_conflict_winner_test.rb`(app 面、WI-1 後に com ケース追加)。

### WI-4: docs / rake(Low)

- `lib/tasks/db_verify_no_schema_drift.rake` を新設(schema dump 後の git
  diff 検査の薄い実装)。コストが合わなければ docs/operations/db-workflow.md の 3 箇所(11, 35,
  94 行)を実在コマンドへ修正。
- `docs/architecture/preference-behavior-contract.md` へ 2 行追記のみ: (a) com tier adoption
  include-parity を Maintainability Rules へ、(b) show_cookie_banner? 削除を Cookie
  Consent 節へ反映。
- `docs/architecture/preference.md` の logout 設問は解決済み記載あり → 変更不要。

### WI-5: 既存 failing 5 件(E)— 明示 defer

着手前後で develop 上の失敗リストが同一であることを取得・記録。WI-1 が `adoption_test.rb`
の失敗と同根の可能性があるため実施時に一読し、include/fixture 起因で即修可能なら同時修正、それ以外は defer。

## 検証

- 各新規テストをファイル単位で実行: `bin/rails test test/integration/<file>`
- 影響範囲:
  `bin/rails test test/controllers/concerns/preference test/integration/preference_*_test.rb test/integration/cross_surface_token_test.rb`
- 最終: `bin/rails test` — 着手前 baseline との失敗差分ゼロ(既存 5 件を除く)を確認。

## 最終成果物

- 実装修正(WI-1, WI-2)+ 回帰テスト(WI-1, WI-3)
- contract doc 追記(WI-4)
- 最終監査レポート:
  `memos/2026-07-03-preference-followup-report.md`(日本語)。含める内容: 各項目の Severity と判断根拠、WI-1 の include 漏れ判定根拠、E の defer 判断、AGENTS.md 英語ポリシーとユーザー日本語設定の矛盾と採った解決(コード・docs は英語、計画・レポートは日本語)、追加テスト一覧、残リスク、次に見る箇所。

## 禁止事項(遵守)

Preference を認証・認可判定に使わない / GET で状態変更しない / GET params で DB
preference 上書きしない / JS-readable
cookie を canonical にしない / 互換 shim を追加しない / 旧 Acme/Sign namespace 前提で評価しない。
