# デッドコード削除計画

## Context

`app/`
内に明らかに呼び出し元のないコードが3箇所確認された。これらを削除することで、将来の開発者が誤って参照・拡張するリスクを減らす。

## 削除対象

### 1. `ChainSealable` concern 全体

**ファイル:** `app/models/concerns/chain_sealable.rb`

- `include ChainSealable` はどのモデルにも存在しない（grep で確認済み）
- テストファイル `test/models/concerns/chain_sealable_test.rb` のみが参照
- テストも合わせて削除する

### 2. `Sign::CommonHelper` の2メソッド

**ファイル:** `app/helpers/sign/common_helper.rb`

- `to_localetime`（行 5–17）: view・controller・helper 全体で呼び出し元ゼロ
- `preference_language_selected`（行 46–50）: 同様に呼び出し元ゼロ

その他のメソッド（`get_timezone`, `get_language`, `get_region`, `get_theme`,
`preference_language_options`, `localized_session_timestamp`,
`sign_up_birthdate_*`）は使用中のため残す。

## 対応しないもの

- `app/presenters/`, `app/queries/` の空ディレクトリ — `.keep`
  ファイルで意図的に保持されている構造。削除は別途判断。
- FIXME コメント付きのコード（`operator_preference.rb`, `application_record.rb`,
  `sign/redirect_only_controller.rb`）— 現在も使用中のため対象外。

## 実装手順

1. `app/models/concerns/chain_sealable.rb` を削除
2. `test/models/concerns/chain_sealable_test.rb` を削除
3. `app/helpers/sign/common_helper.rb` の `to_localetime` メソッド（行 5–17）を削除
4. 同ファイルの `preference_language_selected` メソッド（行 46–50）を削除

## 検証

```bash
bin/rails test test/helpers/
bin/rails test test/models/concerns/
bin/rails test
```

削除後、テストが全パスすることを確認する。
