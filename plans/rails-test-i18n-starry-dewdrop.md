# test 環境の i18n / N+1 fail-fast 動作確認

## Context

ユーザーから「`rails test`
で i18n や N+1 の問題が出たら異常終了するようにしているはずだが、ちゃんと動いているか確認してほしい」との依頼。実装変更ではなく、現状の設定とランタイム挙動の検証タスク。

## 結論

**両方とも適切に動作している。コード変更は不要。**

## 検証結果

### i18n（翻訳キー欠落で raise）

- `config/environments/test.rb:65` — `config.i18n.raise_on_missing_translations = :strict`
- `test/unit/fail_fast_environment_config_test.rb:8-13` が
  - 設定値が `:strict` であること
  - 欠落キーで `I18n::MissingTranslationData` が raise されること

  を実コード経由で検証 → **PASS**

### N+1（strict_loading で raise）

- `config/environments/test.rb:79-81`
  - `strict_loading_by_default = true`
  - `strict_loading_mode = :n_plus_one_only`
  - `action_on_strict_loading_violation = :raise`

- `test/integration/prosopite_smoke_test.rb` が
  - 上記3設定の値確認
  - `Prosopite.raise?` が真であること（`config/initializers/prosopite.rb:19` で `Rails.env.local?`
    時に有効）
  - 実 N+1 を発生させて `Prosopite::NPlusOneQueriesError` が raise されること

  を検証 → **PASS**

### 実行ログ

```
bin/rails test test/unit/fail_fast_environment_config_test.rb test/integration/prosopite_smoke_test.rb
10 runs, 26 assertions, 0 failures, 0 errors, 0 skips
```

## カバレッジの二段構え

- **strict_loading**（AR 標準）: model /
  unit テストでも全テストに自動適用される。preload なしで association を辿ると即 raise。
- **Prosopite**（Rack middleware 経由）:
  integration テストで HTTP リクエスト中の N+1 を補完的に検出。`config/initializers/prosopite.rb:31`
  で middleware 登録済み。

両者が直交して効くため、`Prosopite.pause`
ブロック（fixture 量産時など）でも strict_loading 側は生き続ける。

## アクション

なし。設定・テストとも所期どおり動作している。
