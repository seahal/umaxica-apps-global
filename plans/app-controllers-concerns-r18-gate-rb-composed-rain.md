# R18Gate 削除計画

## Context

`R18Gate`
concern はアダルトコンテンツ年齢確認ゲートの実装だが、本番の app/org/com いずれのコントローラにも include されていない。唯一の利用箇所は dev 用スモークテストコントローラ（`Base::App::Dev::R18::OpenSmokesController`）のみ。ルートも既に退役済み（route
contract
test で「解決しないこと」を検証中）。コードを外したという記憶と一致しており、削除して整理する。

## 削除対象ファイル

1. `app/controllers/concerns/r18_gate.rb` — concern 本体
2. `app/controllers/base/app/dev/r18/open_smokes_controller.rb`
   — 唯一の include 先（dev スモークテスト用）
3. `test/controllers/concerns/r18_gate_test.rb` — concern のテスト

## 修正対象ファイル

### `test/unit/security/redirect_target_usage_test.rb`

lines 27–29 の `RAW_PT_ALLOWLIST_PATTERNS` から R18 パターン 2 件を削除：

```ruby
# 削除
%r{\Aapp/controllers/.*/r18/},
%r{\Aapp/controllers/acme/app/dev/r18/},
```

### `test/integration/routes/acme_route_contract_test.rb`

line 915–922 の `"acme retired routes do not resolve"` テスト内の `/__dev/r18/gate` ブロックを削除：

```ruby
assert_raises(ActionController::RoutingError) do
  Rails.application.routes.recognize_path(
    "http://#{BASE_APP_HOST}/__dev/r18/gate",
    method: :get,
  )
end
```

## 非対象

- `app/controllers/concerns/preference_adoption.rb` の `force_underage_r18_stopper!` /
  `r18_stopper_association_name`
  等 — これらは preference モデル層のアダルトコンテンツ設定強制ロジックであり、`R18Gate`
  concern とは独立している。今回はスコープ外。
- `test/unit/actor/preference_test.rb` の `r18s`
  payload テスト — 同上、preference 層のテスト。スコープ外。
- `test/controllers/concerns/preference/core_test.rb` の `r18s` キー確認 — 同上。

## 検証

```bash
bin/rails test test/unit/security/redirect_target_usage_test.rb
bin/rails test test/integration/routes/acme_route_contract_test.rb
bin/rails test test/controllers/concerns/
```

削除後に `R18Gate` を参照するファイルがないことを確認：

```bash
grep -r "R18Gate\|r18_gate\|r18_required\|require_r18_viewing" app/ test/ --include="*.rb"
```
