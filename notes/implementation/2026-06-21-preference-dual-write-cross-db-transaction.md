# Preference dual-write のクロスDBトランザクション化

## 背景

サインイン状態で `app`(Acme)の preference を更新すると、token 側 (`AppPreference` /
`app_setting`)と actor 側(`ClientPreference` /
`app_principal`)へdual-write している。調査の結果、以下3点の弱点が判明したため修正した。

1. **非アトミック**: token 側と actor 側は別データベース。別々の `connected_to(:writing)`
   ブロックで逐次書き込みしており、片方成功・片方失敗で両DBがズレうる。
2. **失敗の握りつぶし**: `PreferenceResourceSync#sync_to_resource_preference!` が
   `rescue StandardError` で actor 側失敗を `Rails.logger.info` し、成功扱いで握りつぶしていた。
3. **書き込み順序の不統一**: ライブ経路(`update_preference_child_with_resource_first!`)はresource→token の順、休眠経路(`sync_to_resource_preference!`)は token→resource の順で、失敗時の不整合の向きが経路ごとに違った。

## 対応

### 共通方針: token = source of truth, resource = mirror

`PreferenceResourceSync` のコメント(「resource は token の完全なミラー」)に従い、全経路で
**token(source)→ resource(mirror)** の順に統一。

### クロスDB best-effort トランザクション

`PreferenceResourceSync#with_dual_write_transaction(resource_pref)` を新設。
**token(source)を外側、resource(mirror)を内側**にネストする:

```
token_owner.transaction do
  resource_owner.connected_to(role: :writing) do
    resource_owner.transaction do
      yield   # token 書き込み → resource 書き込み
    end
  end
end
```

- 真の 2PC は別DB間で不可能なので「best-effort」。
- **ブロック内で raise されれば両側がロールバック**する。バリデーション/FK/認可などリクエスト内で起きる現実的な失敗はこれで全て all-or-nothing になる。
- 残る非アトミック窓は「inner(resource)コミット後〜outer(token)コミット前のプロセスクラッシュ」のみ。この稀な窓では mirror が先行コミットされ source が失われるが、次回ログイン時の sync で source 基準に再整合される(`Preference::Adoption`
  経由)。

  - トレードオフ: 「外=token
    / 内=resource」を選んだのは、**よくある in-block 失敗の完全アトミック性**を優先したため。逆ネスト(外=resource
    / 内=token)にすると稀なクラッシュ窓でsource が生き残る代わりに、in-block 失敗で token だけ確定する部分書き込みが起きる。前者を採用。

### メソッド改名(順序統一の明示)

`update_preference_child_with_resource_first!` → `update_preference_child_dual_write!`、
`update_preference_cookie_with_resource_first!` →
`update_preference_cookie_dual_write!`。"resource_first" の名前が新しい token-first 契約と矛盾するため。本体は
`with_dual_write_transaction` でラップし、token→resource 順に書く。

### reset 経路も同契約に統一

`reset_preference_to_defaults!` も resource-first・非トランザクションだったため、token→resource 順 +
`with_dual_write_transaction` でラップ。専用だった `reset_resource_preference_to_defaults!`
はインライン化して削除。

### 握りつぶし解消

`sync_to_resource_preference!` の `rescue StandardError` を `Rails.logger.warn` +
`raise PreferenceOperationError` に変更。なお同メソッドはアプリ実経路では
`reload_preferences_and_reissue_token!(sync_resource: false)`
固定のため**現状休眠**で、ライブな dual-write は `write_resource_preference_option!` /
`write_resource_preference_cookie!` 経由。これらは `with_dual_write_transaction`
内で実行されるため失敗時は `update_preference_*_dual_write!` の既存 rescue が
`PreferenceOperationError` を送出して表面化する。

## 検証

- `test/controllers/concerns/preference/core_test.rb`
  にクロスDBの実DBテストを2件追加 (ComPreference=`com_setting` / VisitorPreference=`com_principal`
  のペアでオーナーが別なことを利用):
  - ブロックが raise したとき token(jti)と resource(language)の**両方がロールバック**する。
  - 成功時は**両方コミット**される。
- `core_test.rb`(22 runs)、`preference_booster_test.rb` + `adoption_test.rb`(29 runs)が pass。
- 統合テスト `test/integration/acme_preference_test.rb`
  は本環境で Vite アセットがビルドできず(`pnpm install`
  がオフラインで失敗、ビュー描画段階のエラー)未実行。ロジック変更とは無関係。アセットがビルドできる環境で要再実行。

## 触ったファイル

- `app/controllers/concerns/preference_resource_sync.rb`
- `app/controllers/concerns/preference_core.rb`
- `test/controllers/concerns/preference/core_test.rb` </content> </invoke>
