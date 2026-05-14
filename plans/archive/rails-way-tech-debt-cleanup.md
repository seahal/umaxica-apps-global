# Rails Way 技術的負債返済プラン

**Status:** Archived (2026-05-12)
— 調査のみの古い前提メモ。現在の実装方針とはずれているため backlog ではなく archive に置く。

## 背景

開発者から 6 つの観点が同時に提起された:

1. CSP violation report のルーティングが
   `post "/csp-violation-report", to: "/csp_violations#create"`
   の形で各サーフェスに重複しており、Rails の RESTful CRUD 規約から外れている。
2. Chronicle 系テーブル / `JwtAnomalyEvent` などに `occurred_at` カラムがあるが、Rails 標準の
   `created_at` と意味が重複しているため標準タイムスタンプに寄せたい。
3. `app/services/**` のクラスベース service object が `class`
   で書かれており、状態を持たないものは Rails Way に従って `module`
   化や正しい配置への再構成を行いたい。
4. 既存 ERB に WAI-ARIA 属性が不足しており、また意味のない `<div>` の入れ子が多い。
5. `dev`(`*.dev.localhost`) と `net`(`*.net.localhost`) サーフェスの `roots#index` ページの整備。
6. Rails の i18n キーが破壊されており、en と ja が 1:1 対応になっていない。`t()` へのinline
   `default:` リテラル指定も残っている。未使用キーが大量に紛れている可能性が高い。

本プランは 6 件をひとつのリポジトリ整理キャンペーンとして扱うが、各テーマは独立して進められる。実装担当 AI はテーマ単位で PR を切ること。

## 関連 ADR / プラン

- `adr/three-tier-controller-base.md` — `ApplicationController` / `OpenController` /
  `PublicController` の三層基底
- `adr/public-controller-base.md` — マシン向け公開エンドポイント基底
- `adr/csp-and-permissions-policy.md` — CSP ポリシー全体方針
- `adr/chronicle-audit-db-consolidation.md` — chronicle 系統合と監査契約
- `adr/rails-way-engine-architecture-restoration.md` — Rails Way への回帰方針
- `plans/backlog/gh645-csp-violation-reporting.md` — 既存の CSP report 計画 (本プランで上書き)
- `plans/backlog/gh231-configure-csp.md` — CSP 設定本体
- `plans/active/gh789-publish-at-column-rename.md` — 別カラム改名と同型のパターン

---

## 1. CSP violation report のサーフェス独立化 (URL は不変)

### 設計上の制約 (議論を経て確定)

- **URL は `/csp-violation-report` のまま** 一字一句変えない。
  - CSP `report-uri`
    ディレクティブの値はブラウザ側にポリシー TTL の長さでキャッシュされ、すでに配信済みのポリシーは期限切れになるまで旧 URL へ POST し続ける。サーバ側で URL を変えるとレポートが取りこぼされる期間が必ず発生する。
  - また `/csp-violation-report` (ハイフン区切り) は CSP Level 2/3 の `report-uri`
    エンドポイント慣用形であり、本リポジトリではこの綴りを「対外契約」として扱う。
- **13 箇所の個別ルート宣言もそのまま残す**。サーフェス ×
  TLD ごとに明示的に書くのが AGENTS.md の「サーフェス独立」原則と整合し、整理によって失われるものの方が大きい。

したがって本タスクのスコープは
**ルートの個数や URL を減らすこと「ではない」**。スコープは「コントローラ実装の Rails
Way 化」に限定する。

### 現状

- ルート定義:
  `config/routes/apex.rb:15,60,109,157,165`、`config/routes/sign.rb:16,185,312,461,473`、
  `config/routes/jump.rb:11,21,31` にすべて
  `post "/csp-violation-report", to: "/csp_violations#create"` が個別記述されている (= 13 箇所)。
- コントローラ: `app/controllers/csp_violations_controller.rb` (`ApplicationController`
  直下、ネームスペースを持たないトップレベル)。
- 共通ロジック: `app/controllers/concerns/csp_violation_report.rb` (`record_csp_violation!`)。
- 既存プラン `plans/backlog/gh645-csp-violation-reporting.md` の「URL は `/csp-violation-report`
  のまま保持する」方針を本プランは **そのまま継承** する。

### 問題 (= 残ったクリーンアップ対象)

1. コントローラ参照 `to: "/csp_violations#create"`
   は先頭スラッシュで apex/sign/jump スコープを貫通する書き方になっている。各サーフェスの内部にコントローラを置くだけでこの特殊ディスパッチを消せる。
2. `app/controllers/csp_violations_controller.rb` がどのサーフェスにも住まず、トップレベルの
   `ApplicationController` を継承している。これは AGENTS.md の「サーフェス独立」原則と、ADR
   `three-tier-controller-base.md` (公開エンドポイントは `PublicController`
   を継承する) から外れている。
3. `apex.rb:152-170` の `APEX_NETWORK_URL` / `APEX_DEVELOPER_URL` 制約は
   `constraints host: ENV["APEX_STAFF_URL"]`
   のブロック内に入れ子になっており、ホストは STAFF と DEV/NET の両方に同時マッチしない限り届かない (現状ほぼ死にルート)。これはタスク 5 で修正するため、本タスクからは除外。

### 決定

- **URL は変えない**。`POST /csp-violation-report` のまま。
- 各ルート行は **先頭スラッシュなしの相対形**
  に書き換え、サーフェス内のコントローラにディスパッチさせる。ハイフン区切り URL を保つため Rails の
  `resource` DSL の `path:` オプションを使う:

  ```ruby
  # 各 TLD ブロック内 (apex/sign/jump 共通)
  resource :csp_violation_report, only: :create, path: "csp-violation-report"
  ```

  これで:
  - URL: `POST /csp-violation-report` (一字一句不変)
  - コントローラ: スコープ解決により `Apex::Com::CspViolationReportsController` 等
  - パスヘルパ: `apex_com_csp_violation_report_path` (生成される)
  - 1 行で書け、Rails CRUD 規約 (`#create`) に乗る

  従来の `post "/csp-violation-report", to: "/csp_violations#create"`
  の形を維持してもよい。重要なのは「URL 不変」「先頭スラッシュ廃止」「サーフェス内コントローラに着地」の 3 点であり、DSL の選択は実装担当 AI に任せる。

- コントローラを **サーフェス単位 (= boundary 単位) で 1 つずつ** に集約し、ADR
  `public-controller-base.md` / `three-tier-controller-base.md`
  および「浅いネスト優先」原則 (`PublicController` 設計時の決定:
  11 個の per-TLD ベースを採らず 3 個の boundary ベースにした) に従う:
  - `Apex::CspViolationReportsController < Apex::PublicController`
  - `Sign::CspViolationReportsController < Sign::PublicController`
  - `Jump::CspViolationReportsController < Jump::PublicController`

  ルーティング側は各 TLD スコープ内で同じコントローラを参照する。Rails のスコープ解決は
  `scope module:` を **重ねた最後の名前空間** にコントローラを探しに行くが、コントローラ指定で
  `controller: "/apex/csp_violation_reports"` のようにスコープを 1 段戻して呼び出すか、あるいは
  `resource :csp_violation_report, only: :create, path: "csp-violation-report", module: nil`
  のように TLD 名前空間から外す書き方を使う:

  ```ruby
  # 例: apex.rb 内、各 TLD ブロック (com/app/org/dev/net) で
  resource :csp_violation_report, only: :create, path: "csp-violation-report",
           controller: "/apex/csp_violation_reports"
  ```

  > **代替案 (実装担当 AI が判断可)**: ADR `public-controller-base.md` の `HealthController` 等が
  > **per-TLD** で書かれていれば、現行設計に合わせて `Apex::Com::Csp...`
  > のように per-TLD で揃えてもよい。ただし新規にネストを増やす方向ではなく、既存の浅いほうに揃えることを優先する。実装前に
  > `app/controllers/apex/{com,app,org}/health_controller.rb`
  > の構造を確認し、per-boundary か per-TLD かの一貫性を保つ。

- 共通正規化ロジックは `app/controllers/concerns/csp_violation_report.rb`
  に残し、新コントローラ群から `include` する (現状の concern はそのまま流用)。
- 旧 `app/controllers/csp_violations_controller.rb` は削除する。

### 出力ディレクトリ構造 (実装後の例 — per-boundary 案)

```
app/controllers/
├── apex/
│   └── csp_violation_reports_controller.rb     (Apex::CspViolationReportsController)
├── sign/
│   └── csp_violation_reports_controller.rb     (Sign::CspViolationReportsController)
└── jump/
    └── csp_violation_reports_controller.rb     (Jump::CspViolationReportsController)
app/controllers/concerns/
└── csp_violation_report.rb                      (現状維持)
config/routes/
├── apex.rb                                      (各 TLD で resource :csp_violation_report ...
│                                                 controller: "/apex/csp_violation_reports")
├── sign.rb                                      (同上)
└── jump.rb                                      (同上)
```

合計 3 ファイル (per-boundary)。代替の per-TLD 案を採る場合は 13 ファイル (現行
`health_controller.rb` の構造に揃える)。

### 実装手順

1. サーフェスごとに 1 つずつコントローラを新規作成 (`Apex::CspViolationReportsController`、
   `Sign::CspViolationReportsController`、`Jump::CspViolationReportsController`)。それぞれ対応する
   `<Boundary>::PublicController` を継承し、`CspViolationReport` をinclude、`create` で
   `record_csp_violation!` を呼んで `head :no_content` を返す。
2. `config/routes/{apex,sign,jump}.rb` の
   `post "/csp-violation-report", to: "/csp_violations#create"`
   を、各 TLD スコープ内で下記に置換 (13 箇所すべて):

   ```ruby
   resource :csp_violation_report, only: :create, path: "csp-violation-report",
            controller: "/<boundary>/csp_violation_reports"
   ```

3. 旧 `app/controllers/csp_violations_controller.rb` を削除。
4. テスト: per-boundary 案の場合は
   `test/controllers/{apex,sign,jump}/csp_violation_reports_controller_test.rb`
   を 3 ファイル新設し、各 TLD ホストで POST した際に 204 が返ることをそれぞれカバーする。既存
   `test/controllers/csp_violations_controller_test.rb` を移行・統合する。
5. `config/initializers/content_security_policy.rb` の `report_uri` 値は **変更しない**
   (URL は不変)。
6. `bin/rails routes | grep csp-violation-report`
   で 13 行のままであることと、各行が per-boundary コントローラ (例:
   `apex/csp_violation_reports#create`) に解決されることを確認。

### 受け入れ条件

- `bin/rails routes | grep csp-violation-report` の出力で URL が **すべて `/csp-violation-report`**
  のまま (一字一句変わっていない)。
- 同じく出力で、各行のコントローラがサーフェス内 (per-boundary 案なら
  `apex/csp_violation_reports`、per-TLD 代替案なら
  `apex/com/csp_violation_reports`) に解決されている。先頭スラッシュ付きの `/csp_violations`
  表記は残っていない。
- 旧トップレベル `CspViolationsController` が削除されている。
- 既存ブラウザ (古い CSP ポリシーをキャッシュしているもの) が `POST /csp-violation-report`
  した際に引き続き 204 が返る (apex/sign/jump × com/app/org/dev/net の各組み合わせで)。
- `Rails.event.record("security.csp_violation", ...)` のイベント発火が引き続き動く。

---

## 2. `occurred_at` を Rails 標準の `created_at` に統一

### 現状

- `db/chronicle_schema.rb` 内の `*_chronicles`, `*_audits`, `*_histories`
  テーブル多数 (約 30 箇所) に `occurred_at` が存在し、`t.timestamps` も別途存在しているため
  `created_at` と二重持ちしている。
- `db/occurrence_schema.rb:304` の `jwt_anomaly_events.occurred_at` も同様。
- `app/models/concerns/behavior.rb:13` の `attribute :occurred_at, default: -> { Time.current }`
  がアプリ側のデフォルトを生成。
- `app/models/{user,staff}_chronicle.rb` の `alias_attribute :timestamp, :occurred_at` で
  `timestamp` API を提供している。
- 監査書き込み箇所で `occurred_at: Time.current` を渡している箇所が
  `app/services/**`、`app/controllers/concerns/**`、`app/controllers/sign/**`
  に多数 (約 25 箇所、`grep -rn "occurred_at: Time.current"` で確認可能)。
- 表示側は `app/controllers/sign/{app,com,org}/configuration/activities_controller.rb` の
  `COALESCE(occurred_at, created_at) DESC` と `activity.occurred_at || activity.created_at`
  で「occurred_at が無いレコードは created_at にフォールバック」というつぎはぎ実装になっている (= 既に
  `occurred_at` は意味的に created_at と一致していることが運用上前提)。

### 問題

- `occurred_at` と `created_at` は意味が重複しており、書き込みコードが冗長。
- インデックスも `(occurred_at)` と `(actor_id, occurred_at)` と
  `(subject_type, subject_id, occurred_at)` で多数張られているが、`created_at`
  に統一すれば Rails 標準の knowledge で運用可能。
- COALESCE を使う表示ロジックは負債そのものであり、`created_at` 単独で済めば消える。

### 決定

- 単純な「監査レコードの発生時刻」用途の `occurred_at` は `created_at` に統一する。
- ただし `JwtAnomalyEvent` は **検出時刻 (created_at)** と **イベント発生時刻 (occurred_at)**
  が論理的に異なる可能性がある (anomaly はバッチ後追記もあり得る) ため、当該テーブルは例外として残す。例外はモデル側の docstring と本プランで明示する。
- 例外候補: `JwtAnomalyEvent` のみ。`*Chronicle`, `*Audit`, `*History`, `*Behavior` 系は全て
  `created_at` に寄せる。

### 実装手順 (Phase 構成)

#### Phase 1: 書き込み側を `created_at` 任せにする

1. 全ての `audit/chronicle/...create!(occurred_at: Time.current, ...)` を `occurred_at`
   引数を削除する形で書き換える (Rails が `created_at` を自動付与するため)。対象:
   `app/services/{user,staff}_secrets/*.rb`, `app/services/auth/audit_writer.rb`,
   `app/services/social_auth_service.rb`,
   `app/controllers/concerns/sign/ verification_audit_and_cookie.rb`,
   `app/controllers/concerns/authorization_audit.rb`,
   `app/controllers/concerns/authentication/customer.rb`,
   `app/controllers/concerns/ preference/base.rb`,
   `app/controllers/sign/{com,app}/configuration/{telephones,emails}_ controller.rb`,
   `app/controllers/sign/app/in/secrets_controller.rb`。
2. `app/lib/sign/risk/event.rb` と `app/lib/sign/risk/emitter.rb` の `occurred_at`
   名前はドメインイベント (CloudEvents 風) のフィールド名として残す。これは DB 列ではない。
3. `app/models/concerns/behavior.rb` の `attribute :occurred_at, default: -> { Time.current }`
   を削除する。
4. `app/models/{user,staff}_chronicle.rb` の `alias_attribute :timestamp, :occurred_at` を
   `:created_at` 参照に書き換える (もしくは削除して全箇所 `created_at` に揃える)。
5. activities_controller の `Arel.sql("COALESCE(occurred_at, created_at) DESC")` を
   `created_at: :desc` に置換し、`activity_occurred_at` ヘルパーを `activity.created_at`
   一行に縮める。
6. テスト fixture (`test/fixtures/scavenger_*_chronicles.yml`) の `occurred_at:` を `created_at:`
   に書き換え。
7. 当該テスト一式が緑になることを確認。

#### Phase 2: スキーマ移行 (各 chronicle DB のマイグレーション)

各 DB (`chronicle`, `occurrence`
を除く各データソース) ごとに別々のマイグレーションファイルを切る。テーブル数が多いので、まずデュアルライト期間を経由する。

1. `(actor_id, created_at)`, `(subject_type, subject_id, created_at)`, `(created_at)`
   のインデックスを `created_at` 側に **追加** する (`add_index ... if_not_exists: true`)。
2. `occurred_at` 列を削除し、`(occurred_at)` 系インデックスを落とす。例外: `JwtAnomalyEvent`
   は対象外。
3. ロールバック手順を必ず記述 (`change_table` 使用、destructive
   operation のため AGENTS.md の規約に従いユーザー承認を仰ぐ運用フラグを立てる)。

#### Phase 3: モデル / docstring / ADR の追従

1. `app/models/*chronicle*.rb` の Schema
   Information コメントを再生成 (`bundle exec annotaterb models`)。
2. `adr/chronicle-audit-db-consolidation.md` に「タイムスタンプは `created_at` に統一」の節を追補。
3. `JwtAnomalyEvent` の `occurred_at` を残す根拠を `app/models/jwt_anomaly_event.rb`
   のコメント 1 行に明記する (= 観測時刻と発生時刻の差を残すため)。

### 受け入れ条件

- `grep -rn "occurred_at" app/ test/ db/` の出力が `JwtAnomalyEvent`
  関連のみになる (Schema コメント・モデル属性・テスト fixture)。
- chronicle 系一覧画面が `created_at` 単独でソートされ、表示が変わらない。
- 既存マイグレーションのロールバック (`bin/rails db:rollback`) が成功する。

---

## 3. Rails Way へ寄せたサービス層リファクタ

### 現状

- `app/services/` 配下にクラス約 20 種、内訳:
  - `ApplicationService` (`call` クラスメソッドの単一責務契約)。
  - `auth/`, `dbsc/`, `dpop/`, `oidc/`, `staff_secrets/`, `user_secrets/` などのドメイン別。
  - `social_auth_service.rb`、`taxonomy_builder.rb`、`identifier_blind_index.rb`、
    `cache_aside.rb`、`auth_method_guard.rb`、`analytics_consent_guard.rb`、 `aws_sms_service.rb`
    など単発クラス。
- 一部は実態が「状態を持たず、純粋な手続きを束ねるだけ」のもので、Ruby 的には module +
  module_function で十分なものが含まれる。
- `app/lib/` には `core/`, `auth/`, `sign/risk/`, `common/`
  がすでに存在し、純関数的なユーティリティの置き場として利用されている (`app/lib/core/surface.rb`
  など)。

### 問題

- 「Service」という命名が状態あり/なしで使い分けられず一律化されている。
- 例: `Auth::CookieName` のような純定数/関数クラスは `app/lib/auth/cookie_name.rb` にあるべき (実際
  `app/lib/auth/authorization_header.rb` は既にそうなっている)。
- 例: `UserSecrets::Create` 等は副作用 +
  DB トランザクション + 監査書き込みを行うため、サービスとして妥当 (このカテゴリは触らない)。
- `ApplicationService` の継承を強制していないクラスが混在している (`AwsSmsService`,
  `SocialAuthService` など) 。

### 決定 (細則は実装担当 AI が判断、本プランは原則のみ)

- 分類の判断軸:
  1. **副作用あり + DB 書き込み + トランザクション制御がある** → `app/services/` の `class`
     のまま、`ApplicationService` を継承する。命名は `<Domain>::<Verb>` (例:
     `UserSecrets::Create`)。
  2. **純関数 + 定数 + 書式変換** → `app/lib/<domain>/<noun>.rb` の `module` + 内部メソッド。
     `module_function` か `class << self` で外部公開。
  3. **設定オブジェクト・値オブジェクト** → `app/lib/core/<concept>.rb` の Value Object
     (`Data.define` 推奨)。
- `app/services/` は **副作用ありのサービス専用** にし、純関数は `app/lib/` に追い出す。
- `ApplicationService` を継承していないサービスは継承させるか、純関数なら `app/lib/` に移す。

### 移行候補リスト (実装担当 AI が個別に評価)

| ファイル                                 | 現在地   | 推奨                                         | 理由                    |
| ---------------------------------------- | -------- | -------------------------------------------- | ----------------------- |
| `app/services/auth/cookie_name.rb`       | services | `app/lib/auth/cookie_name.rb` (module)       | 純関数想定              |
| `app/services/auth/token_claims.rb`      | services | `app/lib/auth/token_claims.rb` (Data)        | 値オブジェクト想定      |
| `app/services/dbsc/header_parser.rb`     | services | `app/lib/dbsc/header_parser.rb` (module)     | パースのみ              |
| `app/services/dpop/header_parser` 系     | services | `app/lib/dpop/` 以下 (module)                | 同上                    |
| `app/services/preference/cookie_name.rb` | services | `app/lib/preference/cookie_name.rb`          | 同上                    |
| `app/services/identifier_blind_index.rb` | services | `app/lib/identifier_blind_index.rb` (module) | crypto 純関数           |
| `app/services/cache_aside.rb`            | services | `app/lib/cache_aside.rb` (module)            | キャッシュ Read-through |
| `app/services/aws_sms_service.rb`        | services | services のまま (副作用あり)                 | SDK 呼び出し            |
| `app/services/social_auth_service.rb`    | services | services のまま (DB + 監査書き込み)          | 副作用あり              |
| `app/services/staff_secrets/*`           | services | services のまま                              | DB 書き込みあり         |
| `app/services/user_secrets/*`            | services | services のまま                              | DB 書き込みあり         |
| `app/services/auth/audit_writer.rb`      | services | services のまま                              | DB 書き込み             |
| `app/services/auth/session_revoker.rb`   | services | services のまま                              | DB 書き込み             |

> **注:** 上記の「推奨」は外形評価のみ。実装担当 AI は実際にコードを読み、内部状態 /
> DB アクセス / トランザクション境界 / テストの形を確認した上で最終判断すること。妥当な判断であれば「推奨と異なる」結論も許容する。

### 実装手順

- 1 PR = 1 ドメイン (例: 「auth 系の純関数を lib に移す」、「dbsc 系の純関数を lib に移す」)。
- `require_relative` ではなく Zeitwerk autoload に任せる。
- 移動した側に `# frozen_string_literal: true` と `# typed: false` を維持。
- 呼び出し側 (`app/controllers/**`, `app/models/**`, `test/**`) の参照を修正。

### 受け入れ条件

- `app/services/` 配下のすべてのトップレベルクラスが `ApplicationService`
  を継承するか、またはこのプランの「services のまま」リストに記載されている。
- `bin/rails test` が全緑。
- `app/lib/` 配下に新規追加したモジュールが `class` ではなく `module` で書かれている。

---

## 4. ERB の WAI-ARIA 対応とタグ整理

### 現状

- `app/views/` 以下に 256 ERB ファイル。`grep -l "aria-\|role=\""`
  で ARIA 属性を持つファイルは 21 件のみ (約 8%)。
- 例: `app/views/sign/app/in/emails/new.html.erb` は `<div>` を 4 段ネストした上に空 `<div>`
  (38 行目) があり、フォームエラー領域に `role="alert"` が無い。
- 例: `app/views/sign/app/configurations/show.html.erb` は構造的には妥当 (`<section>` + `<h2>` +
  `<ul>`) だが、`<section>` に `aria-labelledby` が無い。
- 例: `app/views/sign/app/in/sessions/show.html.erb`
  (105 行) はリスト構造は正しいが、「現在のセッション」の表現が視覚的フラグ (`<span>(current)</span>`) のみで、スクリーンリーダ向けの
  `aria-current="true"` が無い。
- レイアウトのほうは
  `<header><nav>...</nav></header><main>...</main><footer><nav>...</nav></footer>`
  と一定のセマンティックは保たれている (`app/views/layouts/sign/app/application.html.erb`)。
- 一方 `app/views/layouts/application.html.erb` (Inertia デモ用) は
  `<title>Inertia Rails Example</title>`
  のままで、本番ルートで使用される可能性があるなら整理対象 (本プランのスコープ外でもよいが、`config/routes.rb:13`
  の FIXME と一緒に消す)。

### 問題

- フォーム検証エラーが `role="alert"` も `aria-live` も持たないため、AT で読み上げられない。
- `aria-describedby`/`aria-invalid`
  が未付与で、フォームフィールドのエラー対応が IDなどで繋がっていない。
- 意味のない `<div>` の入れ子が存在。
- `<style>` がビュー内にインラインで置かれるケース (`emails/new.html.erb:59-75`) があり、CSP
  nonce の手当てとも食い合うため整理が必要。

### 決定

- ARIA 対応は **3 つのレベル** に分けて段階対応する:
  - **Level A (必須):** フォームエラー領域に `role="alert"`、入力フィールドに
    `aria-invalid="true"` + `aria-describedby` でエラーメッセージ ID を結ぶ。ボタンに `aria-busy`
    (送信中) を付ける。`<section>` に `aria-labelledby` を付ける。
  - **Level B (構造):** `<nav>` に `aria-label`、リスト性質を持つ `<div>` を `<ul>/<li>`
    に。パンくず・タブのような UI が出てきたタイミングで対応 (現状はほぼ未使用なので保留)。
  - **Level C (応用):** ライブリージョン (`aria-live="polite"`) によるトースト通知、
    `aria-current="page"` のナビゲーション付与。
- 不要 `<div>` のフラット化は、AGENTS.md の「変更スコープを絞る」原則に従い、Level A を入れる
  **同じ PR 内に限り** 触ってよい。それ以外は触らない。
- `<style>` インラインは Level
  A 対応時に CSS ファイル (`app/assets/stylesheets/sign/...`) に外出しする。

### 対応対象 (優先順)

1. ログイン・サインアップ系 (高頻度): `app/views/sign/{app,com,org}/in/**`,
   `app/views/sign/{app,com,org}/up/**`, `app/views/sign/{app,com,org}/ins/new.html.erb`。
2. 設定系 (中頻度): `app/views/sign/{app,com,org}/configuration/**`。
3. プリファレンス系: `app/views/sign/{app,com,org}/preference/**`。
4. ルートビュー: `app/views/sign/{app,com,org}/roots/**`,
   `app/views/apex/{app,com,org}/roots/**`、`app/views/sign/{dev,net}/roots/**` (タスク 5 と統合)。

### ERB ヘルパー (新設)

- `app/helpers/aria_helper.rb` を新設し、フォームエラー結合用ヘルパーを 1 つ提供する:

```ruby
module AriaHelper
  # 例: aria_invalid_attrs(@user_email, :address) ⇒
  #   { "aria-invalid": "true", "aria-describedby": "user_email_address_errors" }
  def aria_invalid_attrs(model, attr)
    return {} unless model && model.errors[attr].any?

    { "aria-invalid": "true", "aria-describedby": "#{model.model_name.param_key}_#{attr}_errors" }
  end
end
```

> **注:**
> ヘルパーの最終 API は実装担当 AI に委ねる。共通化したい・しないも判断可。本プランは「フォーム入力にエラー時 aria-\* が付与される」 outcome のみを契約とする。

### 受け入れ条件

- 対応対象 1 (ログイン・サインアップ系) のすべてのフォームでエラー領域に `role="alert"`
  が付与される。
- 入力フィールドにエラー時 `aria-invalid="true"` と `aria-describedby` が付く。
- フォーム送信ボタンが `aria-busy` または `data-turbo-submits-with` 経由で busy 状態を ATに伝える。
- 不要 `<div>` ネスト (空 `<div>` を含む) を削除しても表示が変わらない。
- ERB に直接 `<style>` を書かない。

---

## 5. `dev` / `net` サーフェスの `roots#index` 整備

### 現状

- `sign` サーフェスでは `Sign::Dev::RootsController` / `Sign::Net::RootsController`
  とビュー (`app/views/sign/{dev,net}/roots/index.html.erb`) が **既にある**
  が、プレースホルダ (`<h1>Sign::Dev::Roots#index</h1>`) でしかない。
- `apex` サーフェスでは:
  - `app/controllers/apex/{dev,net}/roots_controller.rb` が **存在しない**。
  - `app/views/apex/{dev,net}/roots/` が **存在しない**。
  - `config/routes/apex.rb:152-170` の `APEX_NETWORK_URL` / `APEX_DEVELOPER_URL` 制約が
    `constraints host: ENV["APEX_STAFF_URL"]` の **入れ子の中に**
    書かれている (バグ)。これでは STAFF と DEV/NET の両方にホストが一致しないとマッチしないため、`root to: "roots#index", as: :network_root`
    などは事実上死にルートになっている。
  - 加えて `scope module: :dev` / `scope module: :net` が指定されていないため、コントローラ名は素の
    `RootsController` に解決される。
- `MissionControl::Jobs::Engine` と `RailsDb::Engine` が `apex.rb:167-169`
  の DEVELOPER ブロックにマウントされており、運用ツール群を dev サーフェスに集約する意図は読み取れる。

### 問題

- apex 側で dev/net root が機能しないため、`https://www.dev.localhost/` を叩いても routing
  error になる (エラー画面 / 静的ページ / 認証エラーのいずれかは要確認)。
- sign 側は動くがプレースホルダのまま。

### 決定

- **apex サーフェスに `dev` と `net` の roots 一式を新設する**:
  - `app/controllers/apex/dev/roots_controller.rb` (Apex::PublicController を継承)。
  - `app/controllers/apex/net/roots_controller.rb` (Apex::PublicController を継承)。
  - `app/views/apex/{dev,net}/roots/index.html.erb` を新設。
- **apex のルーティング入れ子バグを修正する** (タスク 1 で同時対応):
  - `constraints host: ENV["APEX_NETWORK_URL"]` と `constraints host: ENV["APEX_DEVELOPER_URL"]`
    を STAFF ブロックの **外側** に出し、それぞれ `scope module: :net, as: :net` /
    `scope module: :dev, as: :dev` で囲う。
  - `MissionControl::Jobs::Engine` / `RailsDb::Engine` のマウントは `apex.dev`
    の新しいスコープ内に再配置 (機能はそのまま)。
- **sign 側はプレースホルダ ERB を「目的のあるランディング」に置き換える**:
  - `dev`: 開発者向けポータル。リンク先は `dev` サーフェスで提供する開発支援ページ (`/jobs`, `/db`
    など apex 側でマウントされているもの) への外部リンク・ホストヘルプ。
  - `net`: 内部ネットワーク向けランディング。`adr/split-into-regional-and-global-repos.md`
    と整合する形で「機械向け API/health 中心であり、人間向けページは最小」という方針を明示する 1 ページ。
  - 両方とも `Apex::PublicController` / `Sign::PublicController`
    を継承し、認証 stack を通さない (ADR `three-tier-controller-base.md` に準拠)。

### 各ページの最低要件 (実装担当 AI への契約)

- HTTP 200 を返す。
- `<h1>` が 1 つだけ存在する。
- `<main>` 配下にコンテンツ全体が入る (`<main>` 自体はレイアウト側にあれば OK)。
- `lang` 属性が `<html>` にある (既存レイアウトで対応済み)。
- `aria-` 属性が必要な場所に付与される (タスク 4 の Level A 準拠)。
- ハードコードされた絶対 URL を含まない (AGENTS.md の規約)。

### 実装手順

1. `apex.rb` 内の `APEX_NETWORK_URL` / `APEX_DEVELOPER_URL` 制約を STAFF の入れ子から外に出して
   `scope module: :net` / `scope module: :dev` を追加。`MissionControl` / `RailsDb` のマウントは
   `apex.dev` 配下に維持する。
2. `app/controllers/apex/{dev,net}/roots_controller.rb` を新規作成 (`Apex::PublicController` 継承)。
3. `app/views/apex/{dev,net}/roots/index.html.erb` を新規作成。
4. `app/views/sign/{dev,net}/roots/index.html.erb` をプレースホルダから実コンテンツに置換。
5. ルーティングテストを追加 (`test/integration/apex/dev_routing_test.rb` 等)。
6. レイアウト共有で footer/header を持つ場合は、apex のレイアウトを `dev` / `net`
   でも共有可能か確認。footer のリンクが認証必須ページを含む場合、`PublicController`
   配下では呼び出せないので、レイアウトの分岐 or 専用レイアウトを検討。

### 受け入れ条件

- `https://www.dev.localhost/` (= `APEX_DEVELOPER_URL`) と `https://www.net.localhost/` (=
  `APEX_NETWORK_URL`) が 200 を返す (test 環境で integration test)。
- `https://id.dev.localhost/` (= `SIGN_DEVELOPER_URL`) と `https://id.net.localhost/` (=
  `SIGN_NETWORK_URL`) が 200 を返す。
- 各ページの `<h1>` テキストが翻訳ファイル (`config/locales/`) 経由で提供されている。
- WAI-ARIA Level A 準拠 (タスク 4 と整合)。

---

## 6. i18n キーの 1:1 化、inline `default:` 撲滅、未使用キーの削除

### 現状

- ロケールファイルは `config/locales/` 直下の `en.yml` / `ja.yml` と、
  `config/locales/jp/{en,ja}.yml` /
  `config/locales/us/{en,ja}.yml`。region-specific カタログが追加でロードされる構造 (`config/application.rb:71-73`
  の `load_path += ...`)。
- `config/application.rb:74` で `default_locale = :ja`。
- `raise_on_missing_translations = true` が dev / test /
  production で有効 (`config/environments/development.rb:77`, `test.rb:54`, `production.rb:163`)。→
  **キーが揃っていないと即座に例外が飛ぶ**。
- `production.rb:108` で `config.i18n.fallbacks = true` (=
  en と ja のフォールバックは本番のみ動く。dev/test では動かない)。
- `Gemfile` には `rubocop-i18n` がいるが、`i18n-tasks` gem は未導入で `.i18n-tasks.yml` も無い。
- ADR メモ `adr/notes/i18n-inline-default-literal-rule.md` で「inline `default: "..."`
  リテラル禁止」が **Accepted note (2026-04-17)** として既に存在。許可される例外:
  - `default: :fallback_key` (シンボルキー指定)
  - `default: nil` (呼び出し側で nil を扱う場合)
- 既存プラン `plans/backlog/restoration-f3-i18n-inline-default-ban.md`
  がこの ADR の実装計画として存在 (= 本タスクで `default:` 撲滅ぶんを実装する)。

### 実態 (2026-05-08 時点の調査結果)

**en と ja のキー差分:**

| 指標                                                             | 件数    |
| ---------------------------------------------------------------- | ------- |
| `en.yml` (ja.yml と region-specific を含めず) のキー総数         | 1,484   |
| `ja.yml` のキー総数                                              | 2,006   |
| en と ja で共通                                                  | 1,128   |
| **en にのみ存在** (= ja で missing → 例外発生候補)               | **356** |
| **ja にのみ存在** (= en で missing → 英語ユーザー向けに例外候補) | **878** |
| 全定義キー (en ∪ ja)                                             | 2,362   |

> en にしかないキー例: `actions.actions`, `actions.destroy`, `apex.com.configurations.title`,
> `controller.app.preferences.footer.privacy` 等。ja にしかないキー例: `actions.cancel`,
> `actions.delete`, `actions.submit`, `activerecord.attributes.customer_email.address` 等。

**inline `default: "<literal>"` 違反 (`grep -rEn 'default:\s*"[^"]+"' app/`):**

| ファイル                                                         | 行                                             | 修正方針                                                                                |
| ---------------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------------------------------- |
| `app/controllers/concerns/authentication/base.rb`                | `:57-60` (`SESSION_LIMIT_HARD_REJECT_MESSAGE`) | `errors.messages.session_limit_exceeded` を en/ja に追加し `default:` 削除              |
| `app/controllers/concerns/authentication/base.rb`                | `:61` (`LOGIN_COOLDOWN_MESSAGE`)               | `errors.messages.login_cooldown` を en/ja に追加し `default:` 削除                      |
| `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb` | `:161-165`, `:168-172`                         | `sign.app.social.sessions.link.{default,success}` を en/ja に追加し inline literal 削除 |

(他 2 件は YARD コメントの `default: "/"` であり t() の引数ではない → 対象外)

**ja.yml の YAML alias (`<<: *anchor`):**

- `ja.yml` は YAML アンカー / エイリアスを使っている (Psych が `aliases: true` 必須)。
- 翻訳ファイルでアンカーを使うと、翻訳の差分レビューが困難になる。 `i18n-tasks`
  などの一般的な i18n ツールも標準パーサーで読めない。
- 本タスクで **ja.yml のアンカー / エイリアスを展開して廃止** する。

**未使用キー候補 (簡易 grep ベースの推定):**

- `app/`, `config/`, `lib/` の `*.{rb,erb}` から `t("...")` / `I18n.t("...")`
  を抽出 → 約 958 キーが参照されている。
- en ∪ ja の定義キー 2,362 から、Rails 管理のネームスペース (`actions`, `activemodel`,
  `activerecord`, `errors`, `date`, `datetime`, `time`, `number`, `support`, `helpers`, `languages`,
  `themes`, `models`, `model`, `mail`, `meta`, `test`, `test_data`, `seed`, `seeds`, `scripts`,
  `tasks`, `common`) を除いた残りで参照されていないものは **約 1,264 キー**。
- ただし以下は false positive の可能性が高いので最終削除前に確認が必須:
  - 動的構築 (`t("foo.#{name}")`、`scope: ...`、`t(".#{action}")`) は静的 grep で捕まえられない。
  - フォーム自動補完 (`form.label :address` で `activerecord.attributes.<model>.<attr>`
    が暗黙参照される) は grep で捕まえられない。
  - `enum` の i18n (`activerecord.attributes.<model>.<enum_value>` 系) も同様。
- 上記理由により「実際の未使用キー」は 1,264 より少ない。**自動削除はせず、必ず `i18n-tasks unused`
  の出力を一次資料にする**。

### 決定

- 本タスクのスコープは 4 つ:
  1. **en と ja を 1:1 にする**。両方に同じキーが存在することを CI で強制する。
  2. **inline `default: "<literal>"` を撲滅する**。`adr/notes/i18n-inline-default-literal-rule.md`
     の方針を全面適用。
  3. **未使用キーを削除する**。
  4. **YAML アンカー / エイリアスを ja.yml から廃止する**。
- ツール採択: **`i18n-tasks` gem を導入する**。これは Rails コミュニティ標準で、 `health`
  (missing/unused/inconsistent interpolations を全部チェック)、`missing`、 `unused`、`normalize`
  などのコマンドを持つ。`rubocop-i18n` (既存) と併用する。

### 実装手順 (Phase 構成)

#### Phase 1: ツール導入とベースライン取得

1. `Gemfile` に `gem "i18n-tasks", "~> 1.0", group: %i(development test)` を追加して
   `bundle install`。
2. `config/i18n-tasks.yml` を新規作成。最低限の設定:

   ```yaml
   base_locale: ja
   locales: [ja, en]
   data:
     read:
       - config/locales/%{locale}.yml
       - config/locales/**/%{locale}.yml
     write:
       - ["{apex,sign,jump,common,actions,errors}.*", "config/locales/%{locale}.yml"]
       - config/locales/%{locale}.yml
   search:
     paths:
       - app/
       - lib/
       - config/
     strict: false
   ignore_unused:
     - "activerecord.*"
     - "activemodel.*"
     - "errors.*"
     - "date.*"
     - "datetime.*"
     - "time.*"
     - "number.*"
     - "support.*"
     - "helpers.*"
     - "languages.*"
     - "themes.*"
   ignore_missing:
     - "errors.messages.*"
   ```

3. `bundle exec i18n-tasks health`
   を実行し、実数値のベースラインを取得する (本プランの推定値はあくまで簡易 grep 基準なので、ツールの正確な数値で上書き)。

#### Phase 2: inline `default:` リテラルの撲滅

1. `app/controllers/concerns/authentication/base.rb:57-61`:
   - `errors.messages.session_limit_exceeded` のキーを en / ja の両方に追加。
   - `errors.messages.login_cooldown` のキーを en / ja の両方に追加。
   - 定数定義から `default: "..."` を削除。
2. `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb:161-172`:
   - `sign.app.social.sessions.link.default` と `sign.app.social.sessions.link.success` を en /
     ja に追加。
   - `default: "%{provider} linked"` と `default: default_notice` を削除。
3. `bundle exec rubocop --only I18n/RailsI18n/DecorateString`
   (もしくは類似の cop) を有効化し、CI で違反が増えないようにする。

#### Phase 3: en ↔ ja の 1:1 化

1. `bundle exec i18n-tasks missing` で両側欠損を一覧。356 件 (en 欠損) + 878 件 (ja 欠損) に対応:
   - **ja にのみ存在し en に無いキー**: 既存日本語訳から英訳を起こして en.yml に追加。翻訳が即時不可能なものは、最小限「英語キー名と同等の英語表現」を入れて TODO コメントを併置する (= キーは 1:1 にし、品質はあとから直す)。
   - **en にのみ存在し ja に無いキー**: 既存英訳から和訳を起こして ja.yml に追加。
   - 実装担当 AI は、対応する画面 (ERB) を読んだ上で文脈に沿った訳を書く。逐語訳は不可。
2. region-specific (`config/locales/jp/`, `config/locales/us/`) も同じ規約で 1:1 化。 `i18n-tasks`
   の `data.read` パターンで region 別カタログも検出される設定にする。
3. `config/environments/development.rb:77` の `raise_on_missing_translations = true`
   が既に有効なので、Phase
   3 中は dev サーバを起動して画面を一通り踏むことで missing 例外を実地検出する。

#### Phase 4: YAML アンカー / エイリアスの展開

1. `config/locales/ja.yml` 内の `<<: *anchor` / `&anchor` をすべて手で展開。
2. `ruby -ryaml -e 'YAML.load_file("config/locales/ja.yml")'` (= `aliases: true`
   なし) でロードできることを確認 (= プレーン YAML としてパース可能)。
3. region-specific ファイルも同様にチェック。

#### Phase 5: 未使用キーの削除

1. `bundle exec i18n-tasks unused` を実行し、未使用キー一覧を取得。
2. 出力を以下のカテゴリで分類:
   - **明確に不要** (画面が削除されたもの、リファクタで消えた controller の一覧キー等)
     → そのまま削除。
   - **動的構築の可能性** (`t("foo.#{name}")` 系) → grep で動的構築箇所を確認し、 `i18n-tasks.yml`
     の `ignore_unused` に正規表現で残す。
   - **判断不能** → 一旦 `ignore_unused` の `# TODO` セクションに残し、別タスクで再評価。
3. 削除した結果を再度 `bundle exec i18n-tasks health` でチェック。
4. テスト実行 (`bin/rails test`) で missing 例外が出ないことを確認。

#### Phase 6: CI ガード

1. `.github/workflows/` (or 該当 CI 設定) に `bundle exec i18n-tasks health` を追加し、PR で:
   - missing keys (en/ja 不揃い) が 0 件
   - inconsistent interpolations が 0 件
   - 新規の inline `default: "<literal>"` が 0 件 (rubocop ベース) を保証する。
2. `bundle exec i18n-tasks unused` も併走させる。ただし削除作業中は容認 (warn のみ) とし、Phase
   5 終了後に hard fail に切り替える。

### 受け入れ条件

- `bundle exec i18n-tasks missing` が 0 件 (en と ja が完全に 1:1)。
- `bundle exec i18n-tasks unused` が 0 件 (もしくは `ignore_unused` 経由で説明されている)。
- `grep -rEn 'default:\s*"[^"]+"' app/` で出てくる `t()` / `I18n.t()`
  系が 0 件 (YARD コメント等は対象外)。
- `ruby -ryaml -e 'YAML.load_file("config/locales/ja.yml")'` が `aliases: true` なしでパースできる。
- `bin/rails test` および `bin/rails server` の起動・主要画面踏破で `I18n::MissingTranslationData`
  が出ない。
- CI で i18n-tasks health が PR ブロック条件になっている。

### 注意事項

- `default_locale = :ja`
  なので、ja の翻訳が「ソース」で en は「派生」として扱う運用が自然。ただし英語が UI ソースで日本語が派生のキー (例: 一部のシステムメッセージ) も存在するので、画面ごとに判断する。
- `raise_on_missing_translations = true` が既に有効なため、production リリース前に必ず Phase
  3 終了済みであること (= ja → en の missing が残っていると本番で例外発生)。
- region-specific カタログ (`jp/`, `us/`) は `adr/regional-docs-news-content-model.md`
  などの region 規約と整合させる。本タスクでは「en と ja の 1:1 化」と「未使用削除」に限定し、region 別の翻訳粒度は変えない。

### 関連

- `adr/notes/i18n-inline-default-literal-rule.md` — inline `default:` 禁止 ADR
- `plans/backlog/restoration-f3-i18n-inline-default-ban.md` — 旧計画 (本タスクが包含)
- `plans/backlog/restoration-h5-japanese-hardcoded-string-sweep.md` — ハードコード和文の掃除

---

## 全体テスト方針

- 各タスクは **独立した PR** とする。タスク間に依存があるのは:
  - タスク 1 のうち `apex.dev` / `apex.net`
    ぶんのコントローラ追加は、タスク 5 で apex の DEV/NET ルーティング入れ子バグを直し
    `scope module: :dev` / `scope module: :net` を立てた **後で**
    行う。それ以外 (com/app/org の 11 箇所) はタスク 5 を待たず着手可。
  - タスク 6 (i18n) の Phase 2 (inline `default:` 撲滅) はタスク 4
    (WAI-ARIA) で新規にキーを参照する箇所が出る前に終わらせると衝突が少ない。
- 全テスト: `bin/rails test`、関連個別: `bin/rails test test/controllers/...`、
  `bin/rails test test/integration/...`、ルーティング: `bin/rails routes`、i18n:
  `bundle exec i18n-tasks health`。
- AGENTS.md の規約に従い、destructive な migration (タスク 2
  Phase 2) はユーザー承認を仰いだ上で実行する。

## マージ順 (推奨)

1. タスク 5 (`apex.dev` / `apex.net` の roots 整備 + apex.rb 入れ子バグ修正) — ベース整備
2. タスク 1 (CSP report のサーフェス独立化、URL は不変)
   — タスク 5 で立てた DEV/NET スコープにも乗せる
3. タスク 6 Phase 1-2 (i18n-tasks 導入 + inline `default:` 撲滅) — 早めに CI ガード
4. タスク 4 (WAI-ARIA Level A) — タスク 5 で新設した views も対象に含める
5. タスク 6 Phase 3-6 (en/ja 1:1 化 + 未使用削除 + YAML アンカー展開 + CI hard fail)
6. タスク 3 (services → lib リファクタ) — テストの依存が広いので慎重に
7. タスク 2 (`occurred_at` 削除) — 監査系の DB 移行を含むため最終段
