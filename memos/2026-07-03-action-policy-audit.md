# Action Policy 認可監査レポート(2026-07-03)

対象: Umaxica monolith(Rails 8 / action_policy 0.7.6)。実装変更なしの読み取り専用監査。手法:
`bin/rails routes`(1,165
route-action)と controller 継承チェーン・concern・before_action・1 段ヘルパー展開の静的解析、policy
381 ファイルの参照クロス照合、代表箇所の目視精読。静的解析の限界(polymorphic な record 型は追えない)は各判定に confidence として明記。

## 0. 前提の訂正

- **Hono は存在しない**(全 package.json / src / config で 0
  hit)。別 JS バックエンドがなく、「Hono 経由の policy bypass」という攻撃面自体がない。
- **React Router も存在しない**。フロントは Inertia.js + React
  19 のスタブ (`src/pages/base/app/groups/index.tsx`
  1 枚)。fetch/loader/permission フラグ 0。認可は 100% Rails サーバサイド。

## 1. 総合判定

**「大量に存在するだけ」ではない。ただし 381 という数字は誇張で、実体は三層構造。**

1. **実効 policy(~65)**: 静的到達 33 + runtime 到達(preference/token 系 polymorphic)~10 +
   sign_in/sign_up ceremony 系。identity・credential・account・organization・avatar
   graph という危険度最上位の mutation 経路には `authorize!` が実際に効いている。
2. **空シェル policy(316)**: `class XPolicy < ApplicationPolicy; end`
   のみ。ApplicationPolicy のデフォルトが **全 rule false + `relation_scope { relation.none }`
   のdeny-all** なので、これらは「形だけだが fail-closed」。過剰許可ではなく無害な placeholder。
3. **rule ありだが未参照(21)**: 下記 §8。

二層防御: Layer 1 = `AUTHENTICATION_MODE`(:deny_all デフォルト、未宣言 action は
`MissingPolicyError`
で fail-closed。`app/controllers/concerns/authentication_base.rb:1774,1907`)、Layer 2 = record 単位
`authorize!`。Layer 1 は網羅的・機械強制、Layer 2 は人力(verify_authorized 不在)。

## 2. 利用状況サマリ

| 種別                                                                               | 件数                                                            | 代表                                             | コメント                                                                                                   |
| ---------------------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| policy class                                                                       | 381(空シェル 316 / rule あり 60 / base 系)                      | `app/policies/`                                  | 単一 `ApplicationPolicy`、context = `authorize :actor, optional: true` + `authorize :user, optional: true` |
| rule method(独自定義)                                                              | 60 ファイルに分布                                               | `sign_up/ticket_policy.rb`(11 rule)等            | base デフォルトは deny-all                                                                                 |
| relation_scope                                                                     | 10 + base                                                       | `avatar_policy.rb` 等                            | **呼び出し側 `authorized_scope` が 0 のため全件未到達**                                                    |
| scope_for / params_filter / pre_check / default_rule / cache                       | 各 0                                                            | —                                                |                                                                                                            |
| alias_rule                                                                         | base のみ 2                                                     | `application_policy.rb:11-12`                    | edit?→update?, new?→create?                                                                                |
| authorize!                                                                         | 162 呼び出し(80 controller、継承展開後 368 route-action に到達) | `base/app/avatars_controller.rb:16-57`           |                                                                                                            |
| allowed_to?                                                                        | 18                                                              | `authentication_sequence_gate.rb:70` 等          | ceremony gate 主体                                                                                         |
| allowance_to / authorized_scope / ActionPolicy::Behaviour 明示 / verify_authorized | 各 0                                                            | —                                                | ※`authorized_scope` の grep hit 2 件は OAuth scope の別物(`oidc_token_exchange_coordinator.rb`)            |
| rescue_from ActionPolicy::Unauthorized                                             | 全 surface ApplicationController(~13)+ API base                 | handler `concerns/authorization_audit.rb:13`     | chronicle 監査記録つき。握りつぶしなし                                                                     |
| policy test                                                                        | 52+ ファイル、51 に deny ケース                                 | `test/policies/account_policy_test.rb`           | 直接 predicate assert 方式、AP matcher 0                                                                   |
| 配線 regression guard                                                              | 1                                                               | `test/unit/security/action_policy_usage_test.rb` | include + context をピン留め                                                                               |

補足(誤検知の解消): `params(:id)` は typo ではなく、`authentication_base.rb:118`
のプロジェクト共通 override(`params.expect(*filters)` ラッパー)。正常動作。

## 3. Policy 到達可能性

`policy_reach.tsv`(scratchpad、非コミット)による全数照合の要約:

| 判定                                   | 件数    | 内訳                                                                                                                                                                              |
| -------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| active(静的到達)                       | 33      | account/organization/avatar graph/passkey/totp/secret/email/telephone/withdrawal/sign_in/sign_up/Authentication::AccessPolicy 等                                                  |
| active(runtime 到達、静的には見えない) | ~10     | preference root 6(`authorize!(resource_pref)` の polymorphic、`preference_resource_sync.rb:22,89`)、token 3(sessions の `allowed_to?(:destroy?, token)`)、group_avatar_membership |
| base-only(継承親)                      | 2       | `SignIn::CyclePolicy`, `SignUp::BasePolicy`                                                                                                                                       |
| unreferenced・空シェル(deny-all)       | ~315    | `*_status_policy` / `*_option_policy` / `*_occurrence_policy` / preference option 系。モデルスキャフォールドの機械的ミラーと推定                                                  |
| unreferenced・rule あり                | ~11(§8) | 要確認                                                                                                                                                                            |

## 4. Endpoint × Authorization Matrix(全数は matrix.tsv、要約)

1,165 route-action。mode: bare 269 / open 408 / guest 105 / private 329 / deny_all 8。Layer 2 検出:
authorize! 368 / allowed_to? 9 / なし 742。risk: critical 77 / high 406 / medium 396 / low 240。

「Layer 2 なし 742」の分解:

- 公開コンテンツ(docs/help/news/info entries API、root、health、robots、sitemap、CSP report、OIDC
  discovery): 妥当。
- ceremony(sign-in/up/out、withdrawal 再入、verification): `allowed_to?` gate /
  session 由来 state で防御。妥当。
- OAuth `/oauth/revoke`(3 surface): RFC 7009。`OidcTokenRevoker`
  が client_id/client_secret 検証。妥当。
- avatar follows/blocks/mutes:
  `authorize_edge!`(`base/app/avatars/social_graph_controller.rb:27-31`)の手動 policy 生成で実質認可済み(標準 API 迂回は §6)。
- **残る実ギャップは §5 の org staff 系と memberships、session/revocation 系のみ。**

## 5. 認可漏れ候補(優先度順)

1. **[high] organizations/memberships CRUD(3 surface)に record-level policy なし**
   `base/org/organizations/memberships_controller.rb:6-38`(index〜destroy 全 action)、
   `base/app/...`, `base/com/...` 同型。routes は公開済み、`:private` + `authenticate_*!`
   のみ。現状スタブ応答で実害なしだが、実装が入ると `:organization_id` 越境 CRUD が可能になる。→
   `OrganizationMembershipPolicy` + scope 限定を実装前に配置(P1)。
2. **[high] org staff 6 controller が :private 止まり**
   `base/org/{iam,audit,system,billing,support,configurations}`(例
   `iam_controller.rb:10-12`)。operator でありさえすれば到達。operator 内 role 差(oversight)を効かせる class-level
   `authorize!`
   が未接続。auth/org 側同名は redirect-only(`Auth::RedirectOnlyController`)で低リスク。
3. **[medium] verify_authorized 相当の網羅性保証がない** :private の mutation で Layer
   2 なしは create 46 / update 40 / delete 23 action (大半は association
   scoping で守られているが機械保証なし)。
4. **[medium] authorized_scope 全面不使用・relation_scope 10 件が死んでいる** 一覧は
   `current_*.assoc` 手書き。scope ロジックの二重定義・乖離リスク。
5. **[low-medium] ActionPolicy::Unauthorized の丸め** `preference_core.rb:310,342,552,615,640`
   で PreferenceOperationError に変換。ログには残るが 403 として観測できなくなる。
6. **[low] authorize_edge! の標準 API 迂回** actor
   context 不使用・instrumentation 対象外・grep 監査から漏れる。

service 層(207 ファイル)は「controller で認可済み」前提が暗黙。job
14 件は system-context の retention/purge 系で妥当。

## 6. Policy 品質

- base デフォルト deny-all + `relation_scope { none }`
  は allowlist 設計として優秀。actor/user 両 optional でも nil 時は false に落ちる(fail-closed)。
- rule 名は controller action と整合(dynamic `to: :"#{action_name}?"` 併用)。
- params_filter 0: 属性単位認可は strong parameters 頼み。memberships 実装時に要検討。
- suspension/block/private
  visibility を rule 条件に織り込む段階には未到達 (該当 policy の多くが空シェル:
  `client_member_suspension_policy.rb` 等)。

## 7. テストギャップ

- policy 層 deny は良好(51/52)。不足: blocked/suspended actor、両 context nil。
- controller 層: other-actor(他人の session id / 他 org の membership id)deny の request
  test が薄い。
- `assert_authorized_to` 0: policy が正しくても **controller の呼び忘れ**は検出不能。→
  §5-3 の静的 guard か matcher 導入。

## 8. 未使用 policy / rule 候補

- **high confidence dead**: relation_scope 10 件(avatar/client/credential 系)。呼び出し 0。消す前に:
  authorized_scope 導入予定の有無を確認。
- **high
  confidence(無害)**: 空シェル ~315。deny-all なので放置しても安全だが、「policy がある」という誤安心のノイズ源。生成規約の明文化推奨。
- **medium confidence**: rule ありで未参照の 11 — `client_apple_identity_policy`,
  `client_google_identity_policy`, `*_oidc_connection_policy` ×3,
  `client_webauthn_credential_policy`(6 rule), `operator_lifecycle_request_policy`(9 rule),
  `org_registration_policy`, `sign_up/social_callback_policy`, `visitor_policy`(4 rule)。convention
  lookup の可能性が残るため、削除前に record 型からの逆引き確認が必要。

## 9. 改善ロードマップ(提案のみ)

- P0: 両 context nil で fail-open する独自 rule がないか、rule あり 60 policy をサンプリング精読。
- P1: memberships(3 surface)+ org staff 6 controller に実装先行で `authorize!` 配置。
- P2: relation_scope 削除 or
  authorized_scope 導入で一本化。authorize_edge! の標準化。preference 系 Unauthorized の応答コード見直し。
- P3: 「:private の create/update/destroy は authorize! 必須」regression テスト (`action_policy_usage_test.rb`
  拡張、matrix 抽出ロジック流用可)。assert_authorized_to 導入。
- P4: service 層の認可前提契約の明文化。空シェル policy の生成・維持規約。

## 10. 追加 docs 提案

- `docs/security/authorization-map.md` — 二層モデルの正式仕様と matrix 維持手順
- `docs/security/action-policy-conventions.md` — 上記 P1〜P3 の規約化

## 未解決の観察

- `operator_lifecycle_request_policy`(9 rule)と `client_webauthn_credential_policy`(6
  rule)が未参照なのは、機能が routes 未接続なのか、動的 lookup を見落としているのか未確定。
- policy 空シェル 316 の生成元(scaffold? 手動?)は未調査。
