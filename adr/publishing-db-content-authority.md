# ADR: Publishing DB をコンテンツの唯一の authority とする

## Status

Accepted (2026-07-16)

## Date

2026-07-16

## Context

コンテンツ永続化が二重化している。

1. **Lean read model**(2026-06-13): `docs_content_entries` / `news_content_entries` /
   `help_content_entries` が app/com/org の各 zenith DB に存在し(計9テーブル)、公開 API
   `GET /api/v0/entries(/:slug)` が参照している。
2. **Legacy CMS model**(2026-07-11): app/com/org × info/docs/news/help の 12 family × 13 テーブル =
   156 テーブル。Revision / Version / Publication / Taxonomy /
   Media を含む高機能スキーマだが、delivery 経路には接続されていない。

さらに、従来の判断(`adr/read-only-content-surfaces-in-rails.md`、
`adr/regional-docs-news-content-model.md`、`docs/architecture/regional-content.md`)は「info は global、docs/news/help は regional」という配置境界と、「taxonomy は廃止」「revision/version は future
work」という制約を記録していたが、main にはすでに revision/version/taxonomy/media を含む CMS が追加されており、decision
drift が発生している。

## Decision

### 1. Publishing DB を唯一の content authority とする

中央の `publishing` DB(publisher /
replica)を新設し、コンテンツの正規データをそこだけに置く。Rails が唯一の content
authority であり、コンテンツの管理・編集・公開・配信判断はこの Rails リポジトリ内で完結する。

app/com/org の zenith
DB には、コンテンツ本体・Revision・Version・Publication・Taxonomy・Media の authority を残さない(lean
9 テーブルと 156 CMS テーブルは cutover 後に削除する)。

### 2. info / docs / news / help はすべて global content surface とする

従来の「info=global /
docs・news・help=regional」の配置区分を廃止する。palm/core/side のような regional
surface とは異なり、これら 4 surface の content authority は中央 `publishing` DB に置く。

app/com/org は DB の配置先ではなく、公開対象を識別する **audience**
として扱う。公開面としては引き続き 12 組み合わせ(info/docs/news/help × app/com/org)を持つ。

### 3. Edition モデル

公開対象は `Publishing::Edition` で正規化する。edition は
`audience(app/com/org)× surface(info/docs/news/help)× locale` を識別し、nullable な `region_code`
を持つ。

当面のスコープ:

- info: global → `ja` のみ(`region_code` は NULL)
- docs/news/help: `jp` → `ja` のみ

将来、info は global → en/kr/ch…、docs/news/help は us → en/sp… と拡張する予定だが、
**破壊的変更で改修していく方針**とし、現段階で過剰な open-closed 設計はしない。

旧案の global/regional CHECK 制約(`surface='info' AND placement='global' …`)は採用しない。制約は
`UNIQUE (audience, surface, locale)` と audience/surface の値域 CHECK に留める。

### 4. API noun は entries を維持する

公開 API の URL 形状は変更しない。

```text
GET /api/v0/entries
GET /api/v0/entries/:slug
```

`posts` / `documents` / `publications` 等への改名は行わない。audience / surface / placement /
region は query parameter として公開せず、host と route boundary から `Publishing::EditionResolver`
が解決する。

### 5. dual-write は採用しない

正式な書込み経路は現在未接続のため、旧 DB と新 DB への dual-write は実装しない。既存データを一度だけ import し(dry-run デフォルト・冪等・監査記録付き)、read
authority を切り替えた後、旧構造を削除する。

### 6. Taxonomy は今回実装しない

Taxonomy は今後 Category / Tag に限らず拡張する予定があるため、旧 CMS の taxonomy
6 テーブルをそのまま新 DB へコピーしない。今回行うのは方針の文書化のみで、migration / model /
service /
API は作成しない。新しい Taxonomy 設計は別 ADR と別実装計画で扱う。旧 CMS に taxonomy 実データが存在する場合、該当旧テーブルの drop は taxonomy 移行計画の完了まで保留できる。

### 7. 実装よりドキュメントを先行する

本移行の最初の成果物はコードではなく設計判断の文書化である。本 ADR と architecture
docs の確定・承認までは、publishing DB の migration や model 実装に着手しない。

### 8. DB 接続の整理

- `publishing` / `publishing_replica` を追加する (`POSTGRESQL_PUBLISHING_PUB` /
  `POSTGRESQL_PUBLISHING_SUB`、migrations_paths: `db/publishing_migrate`、schema_dump:
  `publishing_structure.sql`)。
- dead 接続 `app_principal` / `com_principal` / `org_principal`(+ `_replica`)は削除する。reserved
  migrate dir は空で、どのモデルも connects_to していない。
- **`storage` / `storage_replica` は削除しない。**
  別用途で利用する予定がある。object アップロードのメタデータ管理は publishing
  DB の media テーブル側で行い、storage DB は publishing に使わない。
- CI の `POSTGRESQL_PUBLICATION_PUB/SUB` は過去の publication
  DB 構想の残骸であり、既存挙動の根拠として扱わない(CI は現在壊れている)。

### 9. モデルと命名

`PublishingRecord`(abstract)配下に
`Publishing::Edition / Entry / EntrySlug / EntryRevision / EntryVersion / Publication / MediaFile / MediaUsage`
のみを置く。surface 別・audience 別の concrete モデル、および `constantize` / `Object.const_get`
によるモデル解決は禁止する。

concrete なファイル/モデル命名が必要な場面では
`{app,com,org}_{docs,news,help,info}_xxx`(audience 先・surface 後)の順に揃える。

## Consequences

- 本 ADR は以下を supersede する:
  - `adr/read-only-content-surfaces-in-rails.md`(zenith への lean 配置、taxonomy 廃止、revision/version
    future の判断)
  - `adr/regional-docs-news-content-model.md`(Document/Timeline model family と regional 配置)
  - `adr/regional-help-surface-direction.md`(help の Regional content DB group 帰属)
  - `docs/architecture/regional-content.md` の docs/news/help = Regional の境界記述
- `adr/avatar-db-content-db-boundary.md` の「コンテンツは avatar
  DB の外」という境界は維持される。コンテンツの帰属先が zenith から publishing に変わるのみ。
- Next.js が公開 HTML / SEO / sitemap / UI を担当し、Rails が content authority と read
  API を担当する責務分担(`docs/architecture/docs-help-news-content-boundary.md`) は変更しない。
- Revision(編集履歴)/ Version(不変スナップショット)/ Publication(公開期間、GiST overlap 排他)/ JSONB
  body + schema_version + content_digest というLegacy
  CMS の設計資産は publishing スキーマへ移植する。
- 削除・drop は read-only 監査(`publishing:migration:audit`)の結果を提示し、明示承認を得てからのみ実行する。

## Related

- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/regional-content.md`
- `adr/read-only-content-surfaces-in-rails.md`
- `adr/regional-docs-news-content-model.md`
- `adr/regional-help-surface-direction.md`
- `adr/avatar-db-content-db-boundary.md`
- `plans/publishing-db-valiant-moore.md`
