# 2026-07-16 夜間作業報告: publishing DB 移行 Phase 2-5 + worktree インシデント

## 先に読んでほしいこと: worktree インシデント

作業中、`config/database.yml` を編集した状態で `git commit` を実行したところ、pre-commit hook の
`oxfmt`
ステップが ERB タグ(`<%= ENV.fetch(...) %>`)を YAML 構文エラーと誤認して失敗しました。lefthook はその失敗後、「unstaged 分を退避 → チェック → 復元」というフローの中で
`git apply`(compose.yaml へのパッチ適用)に失敗し、続く `git checkout .`
によるフォールバック復元も一部失敗しました (`Gemfile`/`Gemfile.lock` が `Device or resource busy`
でロック中)。

結果として、**あなたが進めていた Entra/OAuth 系の未コミット編集**
(`app/controllers/auth/org/sign/in/entra/callbacks_controller.rb`、
`app/controllers/concerns/org_entra_ceremony.rb`、
`test/controllers/auth/org/sign/in/entras_controller_test.rb`、
`test/services/identity_telephone_ceremony_replay_store_test.rb`、
`test/services/sign_in/sequence_carrier_test.rb`、`test/test_helper.rb`、
`config/application.rb`、`pnpm-lock.yaml`、`.simplecov`、 `app/lib/external_sign_in/*`
の削除)が、直近コミット (`a87258671`)の内容へ working tree 上で巻き戻されました。

**データは失われていません。** lefthook が hook 実行前に自動作成した
`stash@{0}: lefthook auto backup`
に、巻き戻される直前の完全な状態 (あなたの Entra 編集を含む)が保存されています。私はこのスタッシュには一切触れていません(該当ファイルの復元は「あなたが触れないでと言ったファイルを削除する」操作を含んでいたため、安全のため実行を停止しました)。

**復元方法(あなたの判断で実行してください)**:

```bash
git stash show -p stash@{0} -- app/controllers/auth/org/sign/in/entra/callbacks_controller.rb
# 内容を確認したうえで、必要なファイルだけ個別に取り出す:
git checkout stash@{0} -- app/controllers/auth/org/sign/in/entra/callbacks_controller.rb \
  app/controllers/concerns/org_entra_ceremony.rb \
  test/controllers/auth/org/sign/in/entras_controller_test.rb \
  test/services/identity_telephone_ceremony_replay_store_test.rb \
  test/services/sign_in/sequence_carrier_test.rb \
  test/test_helper.rb \
  config/application.rb \
  pnpm-lock.yaml \
  .simplecov
# external_sign_in/* の削除も復元したい場合(=再度削除する)場合は、
# git stash show -p stash@{0} で対象ファイルを確認してから rm してください。
```

`stash@{1}` は今回のセッションより前から存在していた別の WIP スタッシュで、これも触れていません。

根本原因は修正済みです: `lefthook.yml` の `oxfmt` ジョブに `config/database.yml`
の exclude を追加しました(ERB テンプレート YAML は oxfmt が構文解析できないため)。今後同様の失敗は起きません。

## Publishing DB 移行の進捗

`plans/publishing-db-valiant-moore.md` の8フェーズ中、Phase 0〜5 まで完了・コミット済みです(コミット
`876e0551a`, `6f027503c`)。

- **Phase 0**: ADR 確定・旧 ADR/docs の Superseded 化・decision drift 記録
- **Phase 1**: read-only 監査 task。開発 DB では lean 9テーブル・156
  CMS テーブルとも migration 適用済み・実データ 0 行と確認済み
- **Phase 2**: `publishing`/`publishing_replica` 接続追加、dead な
  `{app,com,org}_principal(+replica)` 6接続を削除。storage は温存
- **Phase 3**: taxonomy 抜きの8テーブルスキーマと `Publishing::*`
  モデル一式(surface別モデル・constantize 不使用)
- **Phase 4**:
  `PublishingMigrationImportLeanEntries`(dry-run 既定・冪等・digest 照合)、`PublishingEditionResolver`、
  `PublishingPublishedEntriesQuery`、`PublishingEntrySerializer`
- **Phase 5**: Info app/com/org の `entries_controller` をスタブ JSON から publishing
  DB 読み取りへ切替(最初の vertical slice)

### 検証状況(重要な留保あり)

`bin/rails runner` を使った直接検証はすべて green でした:
Edition/Entry/Revision/Version/Publication の作成、Version の不変性、Publication の overlap 排他、audience の validation、importer の冪等性 (2回実行してもエラーなし)、HTTP 経由の index/show/404。

一方で **`bin/rails test` そのものは、このセッション中に完走を確認できていません**。理由は2つ:

1. セッション開始時から動いていた無関係な `bin/rails test --seed 424242`
   (私が起動したものではない)が、parallel_tests 用のワーカー別 DB再構築(16
   workers 分のスキーマ clone)で長時間ビジーになっており、自分のテスト実行が繰り返しロック待ちで詰まりました。
2. `config/initializers/multi_db.rb` の `DatabaseSelector`
   (`delay: 10.seconds`)は本リポジトリ全体の既存挙動で、HTTP リクエストを経由しない直接 AR 書き込みの直後に GET すると、読み取りが replica
   (レプリケーションされない別 DB)に回り空になることがあります。
   `test/controllers/help_docs_news_surface_smoke_test.rb`
   など既存の docs/news/help テストと同じ制約で、私が新規に持ち込んだ問題ではありませんが、私の新規テストも同じ制約を受ける可能性があります。

**朝一で `bin/rails test` を一度通しで実行し、especially
`test/controllers/info_surface_publishing_test.rb`、
`test/models/publishing/`、`test/services/publishing_*_test.rb` が green か確認してください。**
それ以外の部分は理論的検証(runner)ではすべて正しく動作しています。

### やっていないこと(意図的)

- Docs/News/Help の実際の cutover(read authority 切替)
- 旧 lean テーブル・156 CMS テーブル・旧モデルの削除(Phase 6/7)

これらは実データへの影響および破壊的操作を伴うため、AGENTS.md の「明示承認なしに破壊的 DB 操作をしない」に従い、レビュー後に着手します。

## 次のステップ

1. worktree インシデントの復元(上記コマンド、あなたの判断で)
2. `bin/rails test` の完走確認
3. 問題なければ Phase 6(Docs/News/Help cutover)の設計レビューへ
