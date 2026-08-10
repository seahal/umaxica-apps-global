# publishing DB 移行 完了報告(2026-07-16)

`plans/publishing-db-valiant-moore.md` の全フェーズ(Phase 0〜8)が完了した。

## 完了内容

- **Phase 0〜5**: ADR 制定、`publishing`/`publishing_replica` 接続追加、8 テーブルスキーマ、
  `Publishing::*` モデル、read-path サービス群、Info スライス切替(コミット済み)。
- **Phase 6**: Docs/News/Help の feature-flag 切替(コミット `efd2c4b96`)。
- **Phase 7**: 全面切替とレガシー削除(本コミット群)。
  - lean 9 テーブル + CMS 156 テーブルを app/com/org zenith から DROP
    (ユーザーの明示承認済み。**dev/test のみ適用。本番 DB へは別途承認と適用が必要**)。
  - 削除前の監査で全レガシーテーブル 0 行を確認済みのため、データ移行は不要だった。
  - lean/CMS のモデル 165 件・concern・seeds・contract テストを削除。
  - feature flag / shadow read / importer プラミングを撤去(段階ロールアウト不要のため)。
  - JSON 契約の namespace/surface 反転バグを修正 (namespace=コンテンツ種別、surface=audience。レガシー
    `as_public_json` 互換)。
- **Phase 8**: `docs/architecture/docs-help-news-content-boundary.md`
  の Persistence 節を現行の publishing DB 構成に書き換え。本メモを完了報告として作成。

## 検証

- `bin/rails test`(publishing 関連スイープ 7 対象): 22 runs, 355 assertions, 0 failures。
- rubocop: 修正ファイルすべて offense なし。
- structure.sql 再ダンプ済み、レガシーテーブルの CREATE TABLE 残存ゼロを確認。

## 残課題

- **本番 DB のレガシーテーブル削除は未実施**。本番適用時は行数監査 (`bin/rails publishing:migration:audit`)を先に実行し、別途承認を得ること。
- taxonomy(category/tag)は ADR 先行で保留のまま(スコープ外)。
- docs/news/help の locale 拡張(現状 jp→ja のみ)は将来スコープ。
