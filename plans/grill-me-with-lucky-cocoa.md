# Rails Controller 層の問題点 再調査計画 — grill-me-with-lucky-cocoa

## Context

当初の「controller lifecycle の一部を Rack Middleware へ移す」計画は**ユーザー判断で全面破棄**(Rack::Attack 不採用、rate limit は edge + Rails-native `rate_limit` の 2-way を維持、設定箇所も現状維持)。ただし監査の過程で controller 層そのものの問題が多数可視化されたため、方向を転換し、**出揃った情報を使って Rails controller 層の問題点を体系的に再調査し、優先度付きの問題レポートを作る**。実装は行わない。最終レポートは `memos/` に日付付きで保存する(日本語)。

## 前提(破棄した計画から引き継ぐ確定事実)

- HEAD `07ce89e3`(develop、dirty worktree)。基準 commit 69d7e3b = origin/main は develop の ancestor ではない。
- 実 middleware stack は実測済み(dev/test。production は ENV 必須で未実測)。middleware 層は今回**変更しない**。
- rate limit: edge(AWS WAF 系 ADR)+ Rails `rate_limit` DSL の 2-way を維持。

## 調査で既に可視化されている問題候補(再調査の起点)

1. **authentication_base.rb が 2909 行の god concern** — 10 の sub-concern を include し、session / cookie / JWT / DPoP / DBSC / withdrawal / redirect を一体で保持。
2. **12 の surface ApplicationController に同一 scaffold が重複** — `default_web` rate_limit 宣言、before_action chain(約 20 段)がコピーされ、surface ごとの差分(com/org に `set_locale` なし、org に `enforce_withdrawal_gate!` なし、auth/com のみ `enforce_required_telephone_registration!`)が意図か drift か判別不能。
3. **callback 順序が構造でなく invariant test で保持されている** — controller_lifecycle_order_invariant_test.rb:27-40 の REQUIRED_ORDER(12 filter)が唯一の防波堤。
4. **request.env 直読が 8 箇所**(authentication_base.rb:639,2632 / minimum_response_budget.rb:12,18 / social_callback_guard.rb ほか omniauth 系)。
5. **Actor.install_context! の呼び出しが 6 箇所に分散**(actor_support.rb:29,55,428 / authentication_base.rb:1680 / authentication_jwt_tokens.rb:110 / base_step_up_completion.rb:35 / core_browser_api_boundary.rb:193 / verification_base.rb:86)— current_context.md:42 の「reviewed boundary 限定」との整合要確認。
6. **controller metadata への結合** — authentication_jwt_tokens.rb:124-133 が `controller_path` 文字列分解で JWT namespace を導出。
7. **format 分岐の散在** — `request.format.json?` が authentication_base.rb 内 5 箇所以上 + `transparent_refresh_access_token, unless: -> { request.format.json? }`。
8. **dead seam** — config/application.rb:12-13 が存在しない `app/middleware/core/surface_middleware.rb` を条件 require、`CoreSurface::ENV_KEY = "jit.surface"`(core_surface.rb:5)は定義のみ未使用。
9. **legacy 経路の残存** — `Finisher#purge_current`(finisher.rb:7-9、current_context.md:73-75 が legacy と明記)。
10. **cookie 書き込み経路の分散** — AuthenticationCookieStore / AuthenticationJwtTokens / logout 系が各々 cookies を操作。
11. **docs との乖離** — controller-lifecycle.md:177-191 の migration gaps(preference concern の callback 登録禁止など)が未消化のまま残っている可能性。

## 調査計画

### Phase 1: 事実の確定(読むだけ)

対象ごとに担当を分けて深掘りし、上記 11 候補を「確定した問題 / 意図された設計 / 誤認」に仕分ける。

- **A. authentication_base.rb 解体調査**: 2909 行の責務マップ(メソッド群 → 所属すべき境界)。sub-concern 10 個との依存方向。value-object-boundaries.mdc 違反箇所の列挙。
- **B. surface 重複と差分調査**: 12 ApplicationController の chain を表にし、差分ごとに「commit 履歴・docs・ADR に意図の記録があるか」を確認(`git log -S`、memos/notes/adr 横断)。意図不明差分 = drift 候補。
- **C. lifecycle 契約調査**: controller-lifecycle.md / current_context.md の invariant と実装の突合(migration gaps :177-191 の消化状況、Finisher legacy、install_context! 6 箇所の boundary 認定状況)。
- **D. 境界違反調査**: request.env 直読 8 箇所、controller_path 結合、format 分岐の全量 grep + 各箇所の是正難易度。

### Phase 2: 問題レポート作成

- `memos/2026-07-17-controller-layer-problem-audit.md`(日本語)に、問題ごとに **file:line 根拠 / 影響(security・drift・保守) / 是正方針の選択肢 / 優先度** を記載。
- 分類軸: (i) security boundary 違反、(ii) 重複による drift リスク、(iii) god concern の凝集度、(iv) docs/実装乖離、(v) dead code。
- 是正は提案のみ(実装しない)。重複問題は memory 済みの設計嗜好(shallow nesting、structural inheritance over flags、Rails-native 優先)に沿った選択肢を提示。

### Phase 3: 後続タスク切り出し

- レポートの優先度上位から、独立して着手できる単位(例: dead seam 削除、Finisher 削除、request.env 直読の是正)を候補リスト化。GH issue 起票はユーザー確認後。

## 検証

- 調査のみのため test 実行は不要。ただしレポート内の file:line 引用は全件その場で開いて確認する(explore 結果の転記を鵜呑みにしない)。
- 差分の「意図 or drift」判定は git 履歴・ADR・memos の一次資料を根拠にし、見つからなければ UNKNOWN と明記。

## やらないこと

- Rack middleware 化(全面破棄)。Rack::Attack 導入。rate limit 構成の変更。コード変更・commit・PR。
