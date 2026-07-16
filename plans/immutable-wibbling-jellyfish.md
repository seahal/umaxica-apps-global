# publishing DB 移行 Phase 7 完了までの残作業

## Context

Phase 7(レガシー lean/CMS 構造の削除と docs/news/help の publishing
DB 完全切替)の実装はほぼ完了しているが、中断前の最後のテスト実行で 1 件だけ失敗が残っていた(22 runs,
259 assertions, 1
failure)。静的チェックの結果、その原因は実装コードではなくテスト側のアサーション反転であることを確認済み。

## 静的チェック結果(2026-07-16)

完了している:

- 実装コード(`app/controllers/concerns/publishing_content_rendering.rb`、9
  controllers、serializer/query/resolver)はnamespace=コンテンツ種別 /
  surface=audience の正しい契約で整合している。
- 9 controllers の `PUBLISHING_AUDIENCE` / `PUBLISHING_SURFACE` 定数は全て正しい。
- レガシー参照の grep 残存はコメント 3 件のみ(意図的な出典記述)。実コード参照ゼロ。
- DROP マイグレーション 3 本は dev/test で適用済み、structure.sql 再ダンプ済み。

未完了(唯一のバグ):

- `test/integration/read_only_surfaces_test.rb:156-157, 175-176` —
  namespace/surface のアサーションが旧(逆)契約のまま。 `audience`↔`surface`
  を入れ替えるだけの 4 行修正。

## 残作業手順

1. `test/integration/read_only_surfaces_test.rb` の 4 アサーションを swap:
   - `assert_equal surface, entry.fetch("namespace")` /
     `assert_equal audience, entry.fetch("surface")`(show 側 156-157 行、index 側 175-176 行)
2. テスト再実行(前回と同じスイープ)→ 0 failures を確認
3. rubocop(修正ファイルのみ)
4. Phase 7 一式をコミット(日本語コミットメッセージ + Co-Authored-By)
5. Phase 8: `docs/architecture/docs-help-news-content-boundary.md`
   等のドキュメント最終更新と完了メモ(`memos/`)を書いてコミット

## Verification

- `bin/rails test test/integration/read_only_surfaces_test.rb test/controllers/help_docs_news_surface_smoke_test.rb test/controllers/info_surface_publishing_test.rb test/models/publishing/ test/services/publishing_migration_audit_test.rb test/services/publishing_published_entries_query_test.rb test/models/model_table_fixture_consistency_test.rb`
- 期待: 0 failures / 0 errors
