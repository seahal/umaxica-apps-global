# Publishing DB 集中管理への移行計画(v3・フィードバック反映版)

## Context

コンテンツ永続化が二重化している。(A) 2026-06 の簡易 read テーブル `docs/news/help_content_entries`
× app/com/org zenith 3DB(計9テーブル)を `/api/v0/entries` API が読んでいる。(B)
2026-07-11 追加の高機能 CMS (12 family × 13 テーブル =
156 テーブル)は delivery 未接続。これを単一の中央 `publishing` DB に統合し、Rails を唯一の content
authority にする。公開 API の URL 形状(`GET /api/v0/entries`,
`GET /api/v0/entries/:slug`)は変更しない。

## ユーザー決定事項(2026-07-16)

1. **info/docs/news/help はすべて global 側に置く。** 従来の「info=global /
   docs・news・help=regional」を廃止。palm/core/side とは違い、これらコンテンツ surface の authority は regional に置かない。app/com/org は DB 配置先ではなく audience 識別子。12 公開面はすべて維持。
2. **locale/region の当面スコープ**:
   - info = global → `ja` のみ
   - docs/news/help = `jp` → `ja` のみ
   - 将来: info は global → en/kr/ch…、docs/news/help は us →
     en/sp… と拡張予定。破壊的変更で改修していく方針のため、**過剰な open-closed 設計はしない**。editions は
     `audience × surface × locale` + nullable `region_code`
     (info=NULL、docs/news/help=当面 'jp')の最小構成とし、拡張は後日の改修で行う。
3. **taxonomy(category/tag)はまだ実装しない。**
   Category/Tag 以外にも拡張予定のため、旧 CMS の6テーブルをそのままコピーしない。ADR/docs の改変を先行し、実装計画は別途作成。初回スキーマから taxonomy
   4テーブルを除外(8テーブル構成)。
4. **storage DB は消さない。**
   別用途で後で使う予定。object アップロードの管理 (メタデータ)は publishing
   DB の media テーブル側で行う。
5. `{app,com,org}_principal(+replica)` の dead 接続は**削除確定**。
6. CI は現在壊れているため、orphan の `POSTGRESQL_PUBLICATION_PUB/SUB` (integration.yml 239–240,
   369–370行)は既存挙動の根拠とせず、触るついでに `POSTGRESQL_PUBLISHING_*` へ置換する程度でよい。
7. **命名の傾向**: concrete なモデル/ファイル名は
   `{app,com,org}_{docs,news,help,info}_xxx`(audience 先・surface 後)の順がわかりやすい。今回の Publishing::* は surface 別モデルを作らないが、docs/ADR 内の呼称や将来の命名はこの順に揃える。

### locale 解決(現行挙動の記録)

現行 `ReadOnlyContentRendering` は `params[:locale]` → region param `ri` (jp→ja, us→en)→
`I18n.locale`
の順で解決している。新実装の当面スコープは上記のとおり ja のみなので、解決順の詳細(`ri`
を残すか等)は Phase
0 の ADR で現行実装を監査して固定する。推測で新しい順序を追加しない。audience/surface は host で決まり、query
parameter では変更できない。

## リポジトリ監査結果(探索で確認済みの事実)

- Lean 側:
  - モデル: `app/models/{docs,news,help}_{app,com,org}_content_entry.rb`(9個)、 `AppRpRecord`
    等(zenith 接続)を継承、`include ReadOnlyContentEntry`。
  - concern: `app/models/concerns/read_only_content_entry.rb`、
    `app/controllers/concerns/read_only_content_rendering.rb` (Controller 名から
    `"#{ns}_#{surface}_content_entry".camelize.constantize`)。
  - controllers: `app/controllers/{docs,news,help}/{app,com,org}/api/v0/entries_controller.rb` (+
    nested `entries/revisions_controller.rb`)。routes: `config/routes/{docs,news,help}.rb`。
  - migration: 各 zenith に1本
    `db/{app,com,org}_zenith_migrate/20260613000001_create_read_only_content_entries.rb`。
- CMS 側:
  - migration:
    `db/{app,com,org}_zenith_migrate/202607110100{00,01,02}_create_*_cms_schema.rb`、DDL 本体
    `db/migration_support/cms_schema.rb`(13テーブル/family、composite `(id, locale)` FK、btree_gist
    publication window 排他、content_digest 不変)。
  - 156 concrete モデルは実ファイル(`app/models/app_docs_post.rb` 等)。継承元は
    `App/Com/OrgPrincipalRecord`(接続先は zenith)。
  - concerns: `app/models/concerns/cms.rb` shim + flat `cms_*.rb` 22ファイル。
  - contract tests: `test/models/cms/concrete_model_contract_test.rb`(156固定)、
    `schema_contract_test.rb`、`sample_seed_test.rb`。
  - seed: `db/seeds/support/cms_sample_builder.rb`(`Object.const_get`)。
- Info: `app/controllers/info/{app,com,org}/api/v0/entries_controller.rb`
  は固定サンプル JSON(`sample: true`)のスタブ。最初の vertical slice に最適。
- zenith DB は content 以外に identity/account/persona 等の本体テーブルを多数持つため、
  **zenith 接続自体は残る**。消えるのは content テーブルのみ。
- `db/*_zenith_structure.sql` は CREATE TABLE を含まない空 dump → 実 DB への適用状況は Phase
  0 監査で確認。

### DB 接続の整理(database.yml 精査結果)

- **削除確定**: `app_principal` / `com_principal` / `org_principal`(+ `_replica`、計6接続)。
  `db/{app,com,org}_principal_reserved_migrate/`
  は空ディレクトリ、どのモデルも connects_to していない。全環境から削除。対応する
  `*_principal_structure.sql` と空 reserved migrate dir も削除。
- **storage / storage_replica は残す**(ユーザー決定 #4)。`db/storages_migrate/`
  が存在しないドリフトは ADR/docs に記録のみ。publishing 側では利用しない。
- 付随ドリフト(記録のみ): `search` が参照する `db/searches_migrate/` 不存在。 `db/audits_migrate/`,
  `db/documents_migrate/`, `db/tokens_migrate/` は migration があるのに参照する接続がない。

## 目標アーキテクチャ

中央 `publishing` DB(publisher/replica)。初回スキーマは **8 テーブル**:

```
publishing_editions          ← audience × surface × locale (+ nullable region_code)
publishing_entries
publishing_entry_slugs
publishing_entry_revisions
publishing_entry_versions
publishing_publications
publishing_media_files
publishing_media_usages
```

editions の制約: `UNIQUE (audience, surface, locale)`、 `CHECK (audience IN ('app','com','org'))`、
`CHECK (surface IN ('info','docs','news','help'))`。region_code は nullable(info=NULL、docs/news/help=当面 'jp')。初期 seed
edition は 12 面 × ja のみ。

taxonomy 系 4 テーブルは**今回作らない**。Taxonomy ADR 承認後に別 migration で追加。

モデルは `PublishingRecord`(abstract, connects_to publishing/publishing_replica)配下の
`Publishing::Edition / Entry / EntrySlug / EntryRevision / EntryVersion / Publication / MediaFile / MediaUsage`
のみ。surface 別・audience 別クラス、`constantize` / `Object.const_get` によるモデル解決は禁止。既存
`CmsSchema` の設計資産(Revision=編集履歴 / Version=不変スナップショット /
Publication=公開期間+GiST 排他 / JSONB body + schema_version + content_digest /
current_revision_id)は新 DDL に移植する。

API 契約: host → `Publishing::EditionResolver` → audience/surface を決定。 `?audience=` `?surface=`
`?region=` は公開しない。

## 移行フェーズ

### Phase 0 — ADR・docs 先行改変(コードより先。最初の成果物は文書)

1. ADR 新規作成(日本語):
   - publishing DB / Rails を唯一の content authority とする決定
   - **info/docs/news/help = all global**(regional 廃止)、app/com/org=audience の定義
   - locale/region の当面スコープ(info: ja、docs/news/help:
     jp→ja)と将来拡張方針 (破壊的変更で改修していく)
   - taxonomy は今回実装しない(別 ADR・別計画。migration/model/service/API を作らない)
   - API noun=entries 維持、dual-write 不採用
   - storage DB は publishing に使わず温存する決定
2. 既存 ADR の Superseded 化(何が廃止され何に置き換わったかを明記):
   `adr/read-only-content-surfaces-in-rails.md`、`adr/regional-docs-news-content-model.md`、
   `adr/regional-help-surface-direction.md`、`adr/avatar-db-content-db-boundary.md`(該当部)。
3. architecture docs 更新: `docs/architecture/regional-content.md`、
   `docs/architecture/docs-help-news-content-boundary.md`。database.yml ドリフト(上記)も記録。
4. planning docs 整理: `plans/backlog/post-publication-implementation-plan.md`、 `plans/archive/`
   の CMS 系を Superseded / Historical / Still valid に分類。

**Phase 0 完了条件**: 新 ADR 存在、旧 ADR に Superseded
marker、境界定義が一意、taxonomy 未実装の明記、ユーザー承認。承認まで migration/model 実装に着手しない。

### Phase 1 — 実 DB 監査(read-only)

- `lib/tasks/publishing_migration.rake` に `publishing:migration:audit` を追加。
- 監査対象: 各 zenith の lean 3テーブル(存在・件数・published/draft・locale 分布・slug 重複・null
  body/title)、156 CMS テーブル(物理存在・件数・orphan
  FK・taxonomy 件数)、schema_migrations(`20260613000001` / `202607110100xx`)。
- 完全 read-only(INSERT/UPDATE/DELETE/DDL 禁止)。結果は `tmp/publishing_migration_audit.json`
  に出力可能にする。

### Phase 2 — Publishing DB 基盤 + dead 接続削除

- `config/database.yml`: `publishing` / `publishing_replica`
  を全環境追加 (`POSTGRESQL_PUBLISHING_PUB/SUB`、migrations_paths:
  `db/publishing_migrate`、schema_dump: `publishing_structure.sql`)。
- 同じ変更で `{app,com,org}_principal(+replica)` 6接続を削除 (structure.sql・空 reserved migrate
  dir も)。**storage は削除しない**。
- `app/models/publishing_record.rb`(abstract)。
- `compose.yaml` 更新。integration.yml は `POSTGRESQL_PUBLICATION_*` → `POSTGRESQL_PUBLISHING_*`
  置換のみ(壊れた CI の再建はスコープ外)。

### Phase 3 — 新スキーマとモデル

- `db/publishing_migrate/` 初回 migration で 8 テーブル作成。DDL helper は
  `db/migration_support/publishing_schema.rb` 新設 (`cms_schema.rb`
  を土台に editions 正規化・taxonomy 除外。旧ファイルは Phase 7 まで残置)。
- `Publishing::*` モデル 8 個 + contract/schema
  test(`test/models/publishing/`)。contract で禁止事項(surface/audience 別モデル・constantize・const_get)と EntryVersion
  immutable / publication overlap 禁止 / slug uniqueness を固定。モデル数を過剰に固定しない。

### Phase 4 — Importer と read query

- `app/services/publishing_migration/import_lean_entries.rb` (lean 9 テーブル →
  Entry/EntrySlug/EntryRevision/EntryVersion/Publication。draft は Version/Publication を作らない)。
- `import_legacy_cms_families.rb` は Phase
  1 監査で 156 テーブルに実データが確認された場合のみ。旧 Category/Tag データは新スキーマに書き込まず、監査出力に migration
  pending として記録(taxonomy 移行計画完了まで該当旧テーブルの drop を保留する選択肢を残す)。
- 要件: dry-run デフォルト・`APPLY=1`
  でのみ書込・冪等・再開可能・件数と digest 記録・変換不能 body 拒否・source table/id 記録・import
  manifest 生成。
- read 系: `Publishing::EditionResolver` / `Publishing::PublishedEntriesQuery` /
  `Publishing::EntrySerializer`(旧 `as_public_json` と JSON 互換)。

### Phase 5 — Info vertical slice

- `info/{app,com,org}/api/v0/entries_controller.rb` の固定 JSON を Publishing read 系へ置換(順:
  info.app → info.com → info.org)。既存データ移行なしのため最安全。Next.js から Workers
  VPC 経由で end-to-end 疎通確認。

### Phase 6 — Docs → News → Help cutover

- surface 単位 feature flag `PUBLISHING_READ_SURFACES`(ENV.fetch、silent
  fallback 禁止、未設定時挙動を明示)。各 surface で app/com/org を一括切替(host 単位の中途半端な切替禁止)。
- shadow
  read で status/slug/locale/title/summary/body/published_at/updated_at/ 一覧順序/件数/ETag/Last-Modified の差分ゼロ確認後、read
  authority 切替。dual-write は不採用。

### Phase 7 — 旧構造の削除

- 削除: lean 9 モデル、`ReadOnlyContentEntry`、`ReadOnlyContentRendering` の constantize、156
  concrete CMS モデル、`cms.rb` shim + `cms_*.rb` concerns、`CmsSchema`、 `CmsSampleBuilder` /
  `cms_samples.rb`、156 固定 contract tests(`test/models/cms/`)。
- migration の扱い(Phase 1 監査結果で分岐):
  - CMS migrations 未適用 → ファイルごと削除。適用済みでデータなし → cleanup
    migration で drop。適用済みで taxonomy データあり → taxonomy 移行計画完了まで drop 保留。
  - lean migrations は適用済みの可能性が高く、cutover 後に drop migration を各 zenith に追加。
- 全 zenith の structure.sql を再生成。
- **drop・大量削除は監査結果を提示し、明示承認後にのみ実行。**

### Phase 8 — 残ドキュメント整理

- decision drift の解消経緯を memos/ に日付付きで記録。
- taxonomy 拡張(type/階層/edition scope/legacy
  Category・Tag 移行等)の実装計画を別プランとして起こす(実装はそこから)。

## テスト戦略

実装前に現行 `/api/v0/entries` の挙動を characterization
test で固定 (`test/controllers/{docs,news,help,info}/`)。

必須: 全12 host の route contract / audience isolation / editions uniqueness
/ 不正 audience・surface 拒否 / locale isolation / draft 非公開 / publication window /
overlap 拒否 / canonical slug / EntryVersion immutable / content digest / media usage integrity /
ETag・Last-Modified / importer dry-run・冪等・resume / 旧新 JSON 互換 / silent fallback 禁止 /
dynamic constantize 不使用。taxonomy 系テストは今回のスコープ外(実装時に別 suite)。

実行順:

```
bin/rails db:prepare
bin/rails test test/models/publishing/
bin/rails test test/services/publishing_migration/
bin/rails test test/controllers/info/ test/controllers/{docs,news,help}/
bin/rails test
pnpm test
```

coverage はリポジトリ既存の起動方法に従う。

## 完了条件

- Documentation: 新 ADR 承認済み、all-global と audience 定義が文書上一意、taxonomy 未実装+別計画が明記。
- Infrastructure: `publishing`/`publishing_replica` 追加、`*_principal`
  接続削除、storage 温存、migration path と structure dump 整備。
- Delivery: 12 公開面が publishing DB を読む、API URL 不変、JSON 契約維持、Next.js から Workers
  VPC 経由で疎通。
- Cleanup: zenith に content
  authority が残らない、surface/audience 別 content モデル消滅、constantize/const_get 解決消滅、旧テーブル件数=import 件数(監査照合)。taxonomy の legacy
  table cleanup は別計画の完了条件に委ねる。
- `bin/rails test` と coverage gate を通過。

## PR 分割

- **PR 1**(実装なし): 新 ADR、旧 ADR Superseded 化、architecture docs 更新、planning
  docs 整理、taxonomy 延期の明文化。
- **PR 2**: read-only 監査 task、実 DB 監査結果、DB inventory と削除根拠の提示。
- **PR 3 以降**: ADR と監査結果の承認後、Phase 2〜8 を順に。

## 進め方の注意

- ユーザー指示どおり **docs/ADR 改変がすべての実装より先**。承認前にコードへ着手しない。
- Phase 2 の接続削除と Phase
  7 の drop は destructive のため、根拠と監査結果を提示し明示承認後に実行。
- worktree の未コミット変更(OAuth/OIDC 系)には触れない。
