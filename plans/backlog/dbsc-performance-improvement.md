# DBSC Performance Improvement Plan

## Problem

DBSC 自体の計算は重くないが、現状は `set_preferences_cookie` 経由でページ表示時にも
DBSC の challenge 発行や preference 更新が走るため、`show` や root で余計な write が発生
している。

## Goal

- 公開ページ表示では DBSC の write を発生させない。
- DBSC の発行・更新は専用 endpoint のみに寄せる。
- 1 リクエストあたりの SQL 件数とレイテンシを下げる。

## Proposed Steps

1. `show` と root の before_action を整理し、`set_preferences_cookie` が不要な画面を固定する。
2. DBSC challenge 発行は registration / verification endpoint のみに限定する。
3. 余計な `update!` が走らない経路を探し、必要なら cache や条件分岐を追加する。
4. `App/Org/Com` の各 surface に回帰テストを置いて、公開ページで preference を更新しないことを保証する。

## Verification

- `bin/rails test` の対象 controller test を追加・更新する。
- 可能なら `/?ri=jp` と `PreferencesController#show` の SQL 件数を再測定する。

## Notes

- これは DBSC のプロトコル自体の問題というより、controller pipeline の使い方の問題。
- まずは write を止めるのが最優先で、暗号処理の最適化は二次対応にする。
