# Preference 実装 総点検 — 監査・修正プラン

## Context

ユーザーから、Umaxica
Rails アプリの Preference（お好み）実装全体の監査依頼があった。対象は JWT 実装そのものではなく、Preference ドメインの挙動契約（未ログイン/ログイン済み/ログアウト後/
surface 差分/cookie
consent/language・timezone・theme などの UX 設定）が安全かつ保守しやすく動作しているかどうか。

Explore agent 3体（model/DB 層、controller/route/helper 層、test/docs/ADR 層）と、追加のverification
agent 1体による事実確認を経て判明した最大の前提:
**この監査で要求されている成果物 (`docs/architecture/preference-behavior-contract.md` —
Inventory 表、Merge Contract 表、Surface Matrix、State Transitions 表、Cookie Consent 契約、Security
Negative Cases 表、Maintainability
Rules）はすでにリポジトリに存在し、内容もユーザーの要求している契約とほぼ一致している。** 併設する
`docs/architecture/preference.md`（Sync Rules、Runtime Read Contract、Request Context
Parameters 等）、および `adr/preference-soft-bubble-doctrine.md`、
`adr/preference-relogin-reconciliation-record-recency.md` などの ADR 群も整合している。

したがって本タスクは「契約をゼロから設計する」のではなく、**既存の文書化された契約と実装の間に実際に乖離（バグ・非対称性）がないかを検証し、見つかった乖離を Critical/High/Medium/Low に分類し、Critical/High は再現テストを先に書いてから最小修正する**
という監査タスクである。

直接コード確認（agent 検証済み、file:line 引用あり）により、**2件の実際のバグ**と
**複数の Medium/Low な非対称性**
を確認した。これらは既存ドキュメントの契約に違反しているか、サーフェス間の実装非対称性であり、保守性・セキュリティ両面で監査報告に値する。

## 確認済みの重大な発見（Critical / High）

### C1. Cookie consent banner が常に非表示 [Critical]

`app/controllers/concerns/preference_web_cookie_endpoint.rb:35-37`

```ruby
def show_banner?
  false
end
```

`show_banner?` は同ファイル内で定義済みの `cookie_consent_state`（consent/functional/
performant/targetable を保持）を一切参照せず、常に `false` を返す。app/com/org の
`edge/v0/cookies_controller.rb` の `show`/`update`
は両方ともこれをそのまま JSON に返す (`show_banner: show_banner?`)。

`docs/architecture/preference-behavior-contract.md` の Cookie Consent 節は「`GET /web/v0/cookie` は
`show_banner: true` または `false` を返す」ことを前提としており、State Transitions 表の "Anonymous
without cookie" 行も `show_banner: true or false` という条件分岐を明示的に期待している。現状は常に
`false` であり、**未同意ユーザーに対してもバナーが一度も表示されない** — Cookie consent
UI フローが機能していない。法令遵守（GDPR 等の明示同意取得）に関わる可能性があるため Critical とする。

### H1. Org の cookie consent エンドポイントが app/com と非対称 [High]

`app/controllers/base/{app,com}/edge/v0/cookies_controller.rb` は:

```ruby
skip_before_action :set_color_theme, raise: false
skip_before_action :enforce_withdrawal_gate!
skip_before_action :transparent_refresh_access_token
skip_before_action :enforce_verification_if_required
```

`app/controllers/base/org/edge/v0/cookies_controller.rb` は **`enforce_withdrawal_gate!` と
`transparent_refresh_access_token` の skip 宣言が丸ごと欠落**している。

影響: この cookie consent JSON エンドポイントは
`AUTHENTICATION_MODE = :open`（匿名含む公開 API）だが、org だけ `transparent_refresh_access_token`
が動作し得る状態になっている —これは GET リクエストでアクセストークンの書き換え（cookie 副作用）が起きる経路になり得るため、「GET で状態変更しない」という監査の禁止事項に抵触するリスクがある。また
`enforce_withdrawal_gate!`
が働くことで、withdrawal 中の org アクターに対してこの本来オープンなはずのエンドポイントが意図せずブロックされる可能性がある。app/com/org で同一であるべき契約（`docs/architecture/preference-behavior-contract.md`
の Surface Matrix）に対する実装の非対称性であり、High とする。

## 確認済みの軽微な発見（Medium / Low — 本パスでは修正範囲を限定）

- **M1**: `app/models/org_preference_cookie.rb#set_defaults` に `functional`
  のデフォルト代入 (`self.functional = false if functional.nil?`) が欠落（app/com には存在）。DB 列は
  `NOT NULL default(false)`
  かつバリデーションもあるため実害は限定的だが、app/com との非対称性であり修正対象とする（軽微・安全な1行追加）。
- **M2（記録のみ、今回は修正しない）**: `AppPreference` の `status_id` DB デフォルトが `0`
  なのに対し `ComPreference`/`OrgPreference` は `2`。`ComPreference`/`OrgPreference` は
  `persist_self_replacement` に `update_column`（バリデーションskip）を使い `AppPreference` は
  `update!`
  を使う非対称性もある。これらは DB デフォルト変更やロジック変更を伴い、マイグレーション計画・承認が必要な範囲のため、今回は監査記録として明記するに留め、
  `plans/backlog/` へのフォローアップ起票を提案する（破壊的変更の事前承認ルールに従う）。
- **L1（記録のみ）**: `ClientPreference#user_preference_colortheme` は `colortheme→theme`
  リネーム後に残った死んだ has_one エイリアス（`user_preference_theme`
  と同一テーブルを指す）。実害なし、将来のクリーンアップ候補として記録。
- **L2（記録のみ）**:
  Client/Operator/Visitor 側は非正規化カラム（`language`/`region`等のstring列）と正規化子テーブル（`*_preference_languages`
  等）が並存しており、実行時の読み取り経路は非正規化カラム側（`Actor::Preference`/JWT 経由）のみを使っている可能性が高い —子テーブル側が実質不要な schema
  debt の疑い。`plans/backlog/legacy-preference-models-retirement-plan.md`
  が既にこの領域を扱っているため、新規プランは起票せず既存プランへの参照のみ記録する。

## 検証済み・問題なしと判断した項目

- **ログアウト時の Preference 状態保持は契約違反ではない**:
  `preference_core.rb#delete_preference_cookie`
  はコメント通り実際に何も削除しない no-op（`log_preference_reset` は監査ログのみ、
  `reset_preference_state`
  はコントローラのインスタンス変数クリアのみ）。実際のログアウト (`base/app/sign_outs_controller.rb`
  → `authentication_logoutable.rb#logout_current_session!` →
  `authentication_cookie_store.rb#clear_auth_cookies!`) は auth/session/DBSC
  cookie のみ削除し、Preference JWT cookie・JS可読 display cookie には一切触れない。
  `AppPreference`/`ComPreference`/`OrgPreference` はそもそもアカウント非依存の「shared surface
  preference」であり、ペイロードは language/region/timezone/theme/currency/date_format/
  time_format/motion/density/page_size という guest-safe フィールドのみ（アカウント・組織・security 情報は含まれない）。よって
  `docs/architecture/preference-behavior-contract.md` の Logout 行「Keep only guest-safe display
  state such as language, timezone, and theme」と整合しており、「Logged-out previous-user
  leakage」も発生していない。**この点は監査報告で「検証済み・準拠」として明記する（修正不要）**。
- **Anonymous→signed-in sync のレース/二重書き込み**:
  `notes/implementation/2026-06-21-preference-dual-write-cross-db-transaction.md`
  で既に対応済み（token側 source-of-truth、cross-DB nested transaction、silent
  rescue の除去）。新規バグは確認されなかった。監査報告で「既存対応済み」として引用する。
- **CSRF・mass assignment・GET mutation・cross-surface
  confusion**: 既存テストスイート (`preference_security_test.rb`、`preference_authority_slice_1f_test.rb`、各 surface/namespace の
  `web/v0/cookie_controller_test.rb`) が広くカバー済み。C1/H1 以外の新規リグレッションは確認されなかった。

## 実施内容

### 1. 再現テストを先に追加（Critical/High）

- `test/controllers/concerns/preference/web_cookie_endpoint_test.rb`（または既存の近い concern テストファイルに追記）に、`show_banner?`
  が同意状態に応じて変化することを検証する失敗テストを追加（consent 未取得時
  `true`、consent 取得済み時 `false` を期待）。
- `test/controllers/base/org/edge/v0/cookie_controller_test.rb`（既存があれば追記、なければ app/com の対応テストファイルをモデルに新規作成）に、org の cookie エンドポイントが
  `enforce_withdrawal_gate!`／`transparent_refresh_access_token`
  を app/com 同様に skip していることを検証するテスト（withdrawal 中アクターでも 200 で応答する、GET 単独でアクセストークンが書き換わらない、等）を追加。

### 2. 最小修正（Critical/High/M1）

- `app/controllers/concerns/preference_web_cookie_endpoint.rb#show_banner?` を
  `cookie_consent_state` を参照する実装に変更（未同意なら `true`、同意済みなら `false`）。既存の
  `cookie_consent_state` の実データ構造（`consented`
  フラグ等）をそのまま利用し、新規抽象化は追加しない。
- `app/controllers/base/org/edge/v0/cookies_controller.rb`
  に app/com と同じ2行 (`skip_before_action :enforce_withdrawal_gate!` /
  `skip_before_action :transparent_refresh_access_token`) を追加。
- `app/models/org_preference_cookie.rb#set_defaults` に `self.functional = false if functional.nil?`
  を追加（app/com と同順序で揃える）。

### 3. テスト実行

- 追加した回帰テストが green になることを確認。
- 関連する既存テストを実行して回帰がないことを確認:
  `bin/rails test test/controllers/concerns/preference/`
  `bin/rails test test/controllers/base/*/web/v0/cookie_controller_test.rb`（app/com/org 3surface）
  `bin/rails test test/controllers/base/*/edge/v0/cookie_controller_test.rb`（存在すれば、app/com/org）
  `bin/rails test test/models/org_preference_cookie_test.rb test/models/app_preference_cookie_test.rb test/models/com_preference_cookie_test.rb`
  `bin/rails test test/integration/preference_security_test.rb test/integration/preference_booster_test.rb`

### 4. ドキュメント更新（既存契約への追記、新規作成はしない）

- `docs/architecture/preference-behavior-contract.md`:
  - Cookie Consent 節に、`show_banner?`
    が実際に consent 状態を反映する旨を明記（修正後の振る舞いを反映）。
  - Security Negative Cases 表に「Cross-surface before_action parity（例:
    org の edge/v0/cookie が app/com と同じ skip_before_action 集合を持つこと）」を追加項目として明記し、H1 の再発防止を文書化する。
  - Maintainability
    Rules に「surface 間で before_action/skip_before_action の集合が意図的に異なる場合は理由をコメントで明示すること」という一文を追加。
- 新規ドキュメントファイルは作成しない（既存の `preference.md` / `preference-behavior-contract.md`
  で十分カバーされているため）。

### 5. 最終監査レポート

- `memos/2026-07-02-preference-audit.md`
  を新規作成（日本語、日付プレフィックス付き flat ファイル — 既存の運用メモリに従う）。内容:
  - Inventory 表（model/controller/route/test の一覧、既存3 explore agent の結果を要約）
  - App/Com/Org × read/write/sync/logout/cookie consent の対応表
  - As-Is state transition 表（既存 `preference-behavior-contract.md` の State
    Transitions 表を実装検証結果で裏書き）
  - Critical/High/Medium/Low の分類（本プランの「確認済みの発見」節をそのまま反映）
  - 変更ファイル一覧、追加テスト一覧
  - 残リスク:
    M2（status_id デフォルト不一致、update_column/update! 非対称）、L1/L2（死んだエイリアス、子テーブル schema
    debt）は本パス未修正であり、フォローアップが必要な旨
  - 未確定事項: `docs/architecture/preference.md` の Open Questions（"Should logout clear the local
    copy, or only stop writing to it?" 等）は本監査でも未解決のまま — 意思決定が必要な事項として明記

## 変更対象ファイル（想定）

- `app/controllers/concerns/preference_web_cookie_endpoint.rb`（`show_banner?` 修正）
- `app/controllers/base/org/edge/v0/cookies_controller.rb`（skip_before_action 追加）
- `app/models/org_preference_cookie.rb`（`set_defaults` 追加）
- `test/controllers/concerns/preference/web_cookie_endpoint_test.rb`（新規テスト追加）
- `test/controllers/base/org/edge/v0/cookie_controller_test.rb`（新規 or 追記）
- `docs/architecture/preference-behavior-contract.md`（追記）
- `memos/2026-07-02-preference-audit.md`（新規、最終報告）

## 検証方法

- 上記 `bin/rails test`
  コマンド群をすべて実行し、追加テストが green、既存テストに回帰がないことを確認する。
- `show_banner?` 修正後、`edge/v0/cookies` の `show`/`update` を手動確認する UI テストは対象外（JSON
  API のみでフロントエンド連携なし、既存テストスイートで十分）。
- Rubocop 等の静的解析は既存の CI 設定に従う（本監査で新設しない）。
