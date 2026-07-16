# 2026-07-16 Publishing DB 移行に伴う decision drift の解消記録

## 背景

コンテンツ永続化が二重化していた。

1. **Lean read model**(2026-06-13): `docs/news/help_content_entries` × app/com/org zenith
   3DB(計9テーブル)。公開 API `GET /api/v0/entries(/:slug)` が参照。
2. **Legacy CMS model**(2026-07-11): app/com/org × info/docs/news/help = 12 family × 13 テーブル =
   156 テーブル。Revision/Version/Publication/Taxonomy/Media を含むが delivery 未接続。

さらに文書上は「taxonomy 廃止」「revision/version は future
work」「docs/news/help は regional」という古い判断が残ったまま、main には revision/version/taxonomy/media を含む CMS が追加されており、decision
drift が発生していた。

## 解消内容(本日)

- 新 ADR `adr/publishing-db-content-authority.md` を作成(Accepted)。
  - 中央 `publishing` DB を唯一の content authority とする
  - info/docs/news/help はすべて global content surface(app/com/org は audience)
  - locale 当面スコープ: info=global→ja、docs/news/help=jp→ja。将来拡張は破壊的変更で改修
  - API noun `entries` 維持、dual-write 不採用
  - taxonomy は今回実装しない(別 ADR・別計画)
  - storage DB は publishing に使わず温存、`{app,com,org}_principal` dead 接続は削除
- Superseded 化:
  - `adr/read-only-content-surfaces-in-rails.md`
  - `adr/regional-docs-news-content-model.md`
  - `adr/regional-help-surface-direction.md`
  - `plans/backlog/post-publication-implementation-plan.md`
- 更新:
  - `docs/architecture/regional-content.md`(boundary map: docs/news/help を Regional →
    Global に変更、info 行を追加)
  - `docs/architecture/docs-help-news-content-boundary.md`(Persistence Direction を superseded /
    migration reference 扱いに。frontend/routing/controller 境界は現行維持)

## database.yml ドリフト(記録のみ、今回は未修正)

- `search` 接続が参照する `db/searches_migrate/` が存在しない。
- `db/audits_migrate/`, `db/documents_migrate/`, `db/tokens_migrate/`
  には migration があるが、参照する接続が database.yml にない。
- `storage` 接続が参照する `db/storages_migrate/` が存在しない(接続自体は温存する)。
- CI の `POSTGRESQL_PUBLICATION_PUB/SUB`(integration.yml)は過去の publication
  DB 構想の残骸。CI は現在壊れており、既存挙動の根拠として扱わない。

## 次のステップ

`plans/publishing-db-valiant-moore.md` の Phase 1 以降: read-only 監査 task
`publishing:migration:audit` → publishing DB 基盤 + `*_principal`
dead 接続削除 → 新スキーマ(taxonomy 除外 8 テーブル)→ importer → Info vertical slice →
Docs/News/Help cutover → 旧構造削除(要明示承認)。
