# Umaxica 基幹ドメイン厳格レビューと v1 実装計画

日付: 2026-07-03 / 対象ブランチ: develop
/ 種別: アーキテクチャレビュー + 実装計画(実装はまだ行わない)

## Context

Umaxica の基幹モデル(Identity / Account / Organization / Unit / Avatar / Group)を「direct FK
ownership tree ではなく、独立 resource +
authority/lifecycle 中間テーブル」で設計する方針に対し、現行 docs・schema・models・controllers・services・policies・tests を調査し、差分・危険箇所・SNS 基盤としての不足を診断した。本ファイルはその診断結果と、target
v1 への実装計画。

---

## 1. Executive summary

**結論: 骨格(zenith 側)は方針にかなり近い。しかし「このまま進めてよい」とは言えない。先に直すべき構造矛盾が 3 つある。**

- **良い点**: `PersonaMembership`/`AgentMembership`/`IndividualMembership`
  は role/state/primary/granted_by/approved_by/revoked_by/starts_at/ends_at/metadata を持つ本物の authority/lifecycle テーブルで、active-primary の partial
  unique index と「unit は同一 collective 内」composite
  FK まで DB レベルで入っている。Unit は adjacency + closure table。cross-DB
  FK は張らない方針が守られている。docs(ADR/dictionary/decision
  record)は本レビューの前提方針とほぼ一致。
- **危険 1 — Identity が Account を直接所有している**: `personas.client_identity_id` が
  `belongs_to` + **UNIQUE
  index**(`idx_*_one_per_*_identity`)。つまり実装は Identity→Account の direct 1:1
  ownership であり、並存する
  `PersonaAssignment`(grant テーブル)は**飾り**になっている。二重の真実源。方針(grant 経由、Identity→N
  Accounts)と正面衝突。
- **危険 2 — Avatar が legacy Member/Client の direct child**: `avatars.client_id` →
  `belongs_to :member`(cross-DB integer 参照)。`AvatarPersonaBinding`
  は存在するが、実際の生成経路(`Base::App::AvatarsController#build_avatar`)は `client_id`
  直付け。bridge 方針が書き込み経路で使われていない。
- **危険 3 — 書き込み経路が service 化されていない**: `AvatarsController#create` が
  `avatar_assignments.create!(role: "owner")` と `Handle.create!`
  を controller 内で生実行。Membership 系 controller は全サーフェスでスタブ(create→422 固定)。grant/revoke/transfer/make_primary の use-case
  service は存在しない(存在するのは AvatarSocialGraph・OperatorLifecycle・WithdrawalLifecycle のみ)。
- **先に直す順**: (1) Identity↔Account を assignment 経由に一本化、(2) Avatar 生成を binding +
  service 経由に切替、(3)
  membership/assignment のライフサイクル service 群と controller 配線。Group は container 専用で新規追加(現状ゼロ)。投稿/コンテンツ系テーブルは avatar
  DB に存在せず、汚染はまだ起きていない(良い)。

## 2. Intended architecture recap(理解の確認)

依頼の方針を本リポジトリの語彙にマップすると:

| 依頼の概念                          | リポジトリの実体(surface: app/org/com)                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Identity                            | `ClientIdentity` / `OperatorIdentity` / `VisitorIdentity`(+ runtime actor `Client`/`Operator`/`Visitor`)     |
| Account                             | `Persona` / `Agent` / `Individual`(`Account` concern)                                                        |
| Organization                        | `Enterprise` / `Bureau` / `Company`(`Collective` concern)                                                    |
| Unit                                | `EnterpriseUnit` / `BureauUnit` / `CompanyUnit` + `*UnitClosure`                                             |
| IdentityAccountGrant                | `PersonaAssignment` / `AgentAssignment` / `IndividualAssignment`                                             |
| AccountOrganizationMembership       | `PersonaMembership` / `AgentMembership` / `IndividualMembership`(unit 所属も同テーブルの `*_unit_id` で兼務) |
| OrganizationUnitHierarchy           | `*Unit.parent_id` + `*UnitClosure`                                                                           |
| AvatarAccountBridge                 | `AvatarPersonaBinding` / `AvatarAgentBinding` / `AvatarIndividualBinding`                                    |
| AvatarAssignment / AvatarMembership | 同名で存在(avatar DB)                                                                                        |
| Group / GroupAvatarMembership       | **Missing**(docs 上は `ClientGroup` v1 = Avatar container のみ、と決定済み)                                  |

誤読の指摘(方針側とリポジトリの差):

- 「Identity 系は基幹 DB に統合済み」→ 正しい。2026-06-30 に `*_principal` の実体は `*_zenith`
  へ物理統合済み(`adr/principal-zenith-physical-consolidation.md`)。
- 依頼では「Unit への所属・管理権」を独立テーブル(UnitMembership)想定だが、現実装は Account の membership
  1 行に `*_unit_id` を同居させている。v1 ではこの同居で足りる(後述 §7)。
- 「OrganizationUnitHierarchy 中間テーブル」は closure table として既に実装済み。追加不要。

## 3. Current implementation inventory

DB 構成: surface × {principal(空・予約), zenith(権威), setting, signal, ticket} + 共有 {avatar,
chronicle, occurrence, cache, queue, search(migrate ディレクトリ欠落),
storage(同)}。cross-DB は integer id または public_id 文字列、DB FK なし。

| 層                                                                                                                                                    | 状態                                                                                                                                                                                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Identity (`*_identities`)                                                                                                                             | 存在。issuer/subject/audience UNIQUE、`source_record_id`(cross-DB bigint)、state FK、public_id                                                                                                                      |
| Account (`personas`/`agents`/`individuals`)                                                                                                           | 存在。ただし `<identity>_id` UNIQUE + belongs_to = **direct ownership**                                                                                                                                             |
| Assignment (`*_assignments`)                                                                                                                          | 存在。`assigned_at`/`revoked_at`/active partial unique。granted_by/reason は **なし**(Partial)                                                                                                                      |
| Membership (`*_memberships`)                                                                                                                          | 存在。フル装備(kind/state/primary/granted_by/approved_by/revoked_by/revoke_reason/starts_at/ends_at/metadata、active-primary partial unique、same-collective composite FK)                                          |
| Organization/Unit/Closure                                                                                                                             | 存在。`parent_id` immutable、closure rows 自動生成                                                                                                                                                                  |
| Avatar                                                                                                                                                | 存在(avatar DB)。ただし `client_id`(legacy Member 直結)、`owner_organization_id`/`representing_organization_id` は FK なし string(public_id)                                                                        |
| AvatarPersonaBinding                                                                                                                                  | 存在。assigned_at/revoked_at + 3 partial unique。**書き込み経路が未使用**                                                                                                                                           |
| AvatarAgentBinding / AvatarIndividualBinding                                                                                                          | 存在するが **bare join table**(revoked_at なし、非対称)                                                                                                                                                             |
| AvatarAssignment                                                                                                                                      | 存在。role string(owner/administrator/…)、owner/affiliation の partial unique、last-owner 保護は model 層のみ                                                                                                       |
| AvatarMembership                                                                                                                                      | 存在。temporal(valid_from/valid_to=Infinity)、`actor_id` の指す先が曖昧(docs でも未解決)                                                                                                                            |
| AvatarFollow/Block/Mute                                                                                                                               | 存在(avatar DB、有向エッジ、pair unique)。service あり(`AvatarSocialGraph::*`)、controller/policy 実体なし                                                                                                          |
| Group / GroupAvatarMembership                                                                                                                         | **Missing**                                                                                                                                                                                                         |
| Legacy 並走: `Member`(app)+`member_avatar_*` 7 テーブル、`Organization`/`Division`/`Department`(org)、`ClientMembership`, `OperatorWorkspaceAccount*` | 存在。zenith 系と二重権威。docs も「decomposition 未完」と明記                                                                                                                                                      |
| Controllers                                                                                                                                           | 読み取りは `BaseSwitcherAuthority` 経由で健全。Memberships controller 全スタブ。`Base::App::AvatarsController#create` のみ join table 生 CRUD。`Base::Org::AvatarsController` update/destroy は no-op               |
| Services                                                                                                                                              | `AvatarSocialGraph`(良)、`OrgOperatorLifecycle*`(良)、`WithdrawalLifecycle`(良)、`AccountSessionRevocation`。**grant/revoke/transfer/make_primary/attach/detach 系は Missing**                                      |
| Policies                                                                                                                                              | `OrganizationPolicy` のみ実質ロジック(active membership 判定)。Avatar 系 policy 多数が空クラス                                                                                                                      |
| Tests                                                                                                                                                 | `avatar_assignment_test.rb`(不変条件まで検証、良)、social graph service tests(良)、operator lifecycle(良)。`persona_membership_test.rb` 等は predicate のみ 26 行(弱)。membership controller テストはスタブ検証のみ |

## 4. Gap analysis

| Area                  | Intended                                                   | Current                                                                                                                                    | Status            | Evidence                                                        | Required action                                               |
| --------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------- | --------------------------------------------------------------- | ------------------------------------------------------------- |
| Identity↔Account      | grant 経由、非所有、将来 1→N                               | `belongs_to :client_identity` + UNIQUE index。Assignment は並存するが未権威                                                                | **Wrong**         | `app/models/persona.rb`, `idx_personas_one_per_client_identity` | assignment を唯一の接続に。カラムは deprecate→削除(§10)       |
| Account↔Organization  | membership、primary は制約付き                             | フル lifecycle membership + partial unique                                                                                                 | **OK**            | `*_memberships` schema, `CollectiveMembership` concern          | service 層と controller 配線のみ追加                          |
| Org/Unit 階層         | hierarchy 分離                                             | adjacency+closure、same-collective composite FK                                                                                            | **OK**            | `*_unit_closures`, `fk_*_memberships_unit_same_*`               | なし                                                          |
| Unit 管理権           | 所属と管理権の分離                                         | membership 行の `*_unit_id` + kind のみ                                                                                                    | Partial           | `CollectiveMembership`                                          | v1 は kind で表現、UnitAssignment 追加は defer                |
| Avatar↔Account        | bridge 経由、direct child 禁止                             | `avatars.client_id` → legacy `Member`。binding は未使用                                                                                    | **Wrong/Risky**   | `avatar.rb:47`, `avatars_controller.rb:82`                      | 生成経路を binding 化、client_id を backfill 後に凍結         |
| Avatar 権限           | AvatarAssignment=authority, AvatarMembership=participation | 両方存在するが役割重複・`actor_id` 曖昧・`user_id`→Client(cross-DB)                                                                        | Partial/Risky     | `avatar_assignment.rb`, `avatar_membership.rb`, docs grill      | v1 で責務を確定(§7)。assignment の主体を Account(public_id)へ |
| Group                 | Avatar container、GroupAvatarMembership                    | なし                                                                                                                                       | **Missing**       | —                                                               | 新規テーブル 2 枚(§7)                                         |
| 中間テーブルの質      | authority/lifecycle table                                  | membership=OK、assignment=Partial(granted*by/reason 欠落)、`avatar_agent/individual_bindings`・`member_avatar*\*`=bare join                | Partial           | 各 schema annotation                                            | 欠落カラム追加、bare join の是正 or 廃止                      |
| DB constraint         | unique/partial/check                                       | partial unique は充実。**check constraint(valid_from<=valid_to、role/state presence)はほぼ皆無**。`avatar_assignments.role` が free string | Partial           | structure.sql                                                   | §8                                                            |
| Controller            | use-case service 経由                                      | Avatar create が生 CRUD、membership はスタブ                                                                                               | **Wrong/Missing** | `avatars_controller.rb:46`                                      | §9                                                            |
| Service               | grant/revoke/transfer/…                                    | social graph と operator lifecycle のみ                                                                                                    | Missing           | `app/services/`                                                 | §9                                                            |
| DB/domain 境界        | app/org/com/avatar/content 分離                            | 分離は維持。ただし legacy `Member`/`Organization` 並走で権威二重化。~65 件の cross-DB AR association が残存                                | Risky             | `plans/backlog/cross-database-model-associations-audit.md`      | 段階的縮退(§10)                                               |
| avatar DB の UGC 汚染 | 投稿等を置かない                                           | 投稿系テーブルなし。`image_data`(jsonb)はプロフィール画像メタで許容範囲                                                                    | OK                | schema                                                          | content DB 新設時に境界テストを追加                           |
| cross-DB 参照方式     | 一貫                                                       | **不一貫**: `source_record_id`(bigint) / `client_id`(bigint) / `owner_organization_id`(public_id string) が混在                            | Risky             | avatar.rb schema                                                | public_id string に統一する ADR を先に切る                    |

## 5. Dangerous design smells(危険箇所)

1. **Identity direct ownership + 飾りの grant テーブル**(最重要)。`personas.client_identity_id`
   UNIQUE がある限り、`PersonaAssignment`
   を読むコードと column を読むコードで真実が分岐する。今どちらが権威か決めないままコードが増えるほど移行コストが増す。
2. **Avatar→Member(`client_id`)**。legacy 認証主体への cross-DB
   integer 依存。Member 解体(docs で決定済み)と同時に確実に壊れる。新規 Avatar が今日もこの経路で作られ続けている(`avatars_controller.rb:82`)。
3. **controller からの join
   table 生 CRUD**(`avatar_assignments.create!`)。last-owner 保護等の不変条件が model
   callback 頼み。`forbidden_rails_patterns` ガードもこれを検出しない。
4. **bare join tables の非対称**: `avatar_persona_bindings`
   だけ lifecycle 持ち、agent/individual は素の join。「app だけ先行」の副作用だが、org 展開時に必ず踏む。
5. **`avatar_assignments.role` が free string + user_id が Client(cross-DB bigint)**。role の check
   constraint も参照テーブルもない。主体も Account でなく認証 actor。
6. **`avatar_memberships.actor_id`
   の指す先が未定義**(docs 自身が ambiguous と明記)。temporal 設計は良いのに主体が不明では audit にならない。
7. **legacy 並走権威**: `Member`+`member_avatar_*`(7 枚の capability
   join)、`Organization`/`Division`/`Department`、`ClientMembership`。zenith 系と同じ意味の関係が二系統ある。
8. **check constraint 不在**:
   valid_from<=valid_to、starts_at<=ends_at、revoked_at と revoked_by の整合などが DB レベルで未保証。Rails
   validation のみ。
9. **membership controller スタブが REST full
   actions で routed 済み**。今のまま「とりあえず実装」されると raw CRUD 化する導線になっている。
10. **cross-DB 参照 3 方式混在**(bigint id / public_id string /
    source_record_id)。sharding・regional split(ADR 済み)の前提を崩す。

「Group が投稿 actor」「avatar
DB に投稿本文」の smell は**現状なし**(Group 自体がないため。docs の決定も container 限定で健全)。

## 6. SNS foundation gap review

前提: 投稿・メディア・リアクション・フィードは avatar DB とは別の content/media/interaction
DB。現状その DB は存在しない(docs の decision record も Post を明示的に out of scope としている)。

**Must have before implementation continues**(投稿 DB を作る前に確定しないと手戻り):

- **Actor 参照方式の確定**: content DB からは `avatar_public_id`(string, immutable)で参照。bigint
  id・cross-DB FK 禁止。ADR 化。
- **投稿時 actor snapshot 方針**: 投稿行に
  `avatar_public_id` + 表示用 snapshot(moniker/handle は投稿時点値をコピー)を持つ。権限変更・移管後も帰属は avatar に残り、削除権は「その時点の AvatarAssignment(owner/administrator)」で判定 — つまり snapshot は表示専用、権限は都度解決。この分離を先に文書化。
- **Avatar lifecycle state の DB 権威化**: suspended/archived/banned/deleted。現状
  `avatar_status_id` は string で参照整合なし。content 側の表示可否判定の入力になるため先に固める。
- **Identity↔Account の一本化(危険 1)**: 誰が Avatar を操作できるかの根本が二重権威のままでは、投稿削除権の判定チェーン(Identity→Account→AvatarAssignment)が信用できない。

**Needed soon**:

- Follow/Block/Mute の controller/policy 実体(service は既にある)。Block と Follow の相互作用(block 時に follow 双方向剥がし)を service に。
- `restrict` / `report`(avatar-to-avatar 通報)テーブル。follow らと同じ avatar
  DB で良いが、report の本文・証拠は content/moderation 側。
- content DB→avatar
  DB の参照解決: 同期 join は不可能なので、avatar の表示メタ(moniker/handle/status)の read-model/cache(occurrence でなく専用 projection)方針。eventing は Solid
  Queue ベースの outbox で十分。
- Organization/Unit→Avatar 操作権の traversal: 法人 Avatar は `AvatarOwnershipPeriod`(既存)+ owner
  org の membership 経由で操作権を導出する service。

**Can defer**:

- Feed generation / timeline / ranking source(投稿 DB 設計と同時に。event
  source は signal/occurrence でなく content 側)。
- Story/ShortVideo/Media asset 分離(media は storage DB + Shrine 前提で別設計)。
- Group の feed/visibility 関与(v1 Group は container のみ、と decision record 済み。守る)。
- sharding/partitioning(public_id 参照に統一されていれば後から可能)。
- GroupAssignment/GroupMembership(Group に管理権が要る要件が出てから)。

**Avoid for now**:

- avatar DB への post/comment/caption/DM 本文の追加(現状汚染ゼロ。境界テストで防御)。
- Group への handle/posting 主体付与。
- cross-DB の ActiveRecord association 新設(既存 65 件は縮退対象であって前例ではない)。

## 7. Recommended target model v1

**変えない(既に正しい)**: `*_memberships`(そのまま)、`*Unit` +
closure、`AvatarFollow/Block/Mute`、`AvatarOwnershipPeriod`、`AvatarMoniker`、`Handle`。UnitMembership/UnitAssignment の独立テーブルは
**作らない**(membership の `*_unit_id`+kind で v1 は十分)。

**直す**:

1. `*_assignments`(Identity→Account grant)に
   `granted_by_<identity>_id`・`revoked_by_<identity>_id`・`revoke_reason`
   を追加し、**唯一の接続**に昇格。`personas.client_identity_id`
   は移行期間 dual-read 後に削除(org/com も同型)。
2. `AvatarAgentBinding` / `AvatarIndividualBinding` に `assigned_at`/`revoked_at`/partial
   unique を追加し persona 版と対称化(org 展開前に)。
3. `AvatarAssignment` を authority 専任に確定: 主体を `account_public_id`(string)へ移行(v1 は
   `user_id` と dual-write)、`role` を check constraint
   or 参照テーブル化。**AvatarMembership は participation/履歴専任**とし、`actor_id` →
   `account_public_id` にリネームして意味を確定。
4. Avatar から `client_id` を新規書き込み禁止(生成は binding 経由)。

**追加**:

- `client_groups`(avatar DB): `public_id`, `name`,
  `owner_account_public_id`(v1 は単一 account 所有、decision record 通り), `state`, timestamps。
- `group_avatar_memberships`(avatar DB): `client_group_id` FK, `avatar_id` FK, `position`,
  `added_at`/`removed_at`, partial unique `(client_group_id, avatar_id) WHERE removed_at IS NULL`。
- ADR: cross-DB 参照は public_id string に統一(新規カラムは `*_public_id` 命名、bigint
  cross-DB 参照の新設禁止)。

## 8. Validation / DB constraints plan

共通(全 authority/lifecycle テーブル): Rails validation と**同内容の DB
constraint を必ず対にする**。

- public_id: `NOT NULL` + UNIQUE(既存)+ update guard(既存 `PublicId`
  concern)。新テーブルも同 concern。
- state/role presence: `NOT NULL` + FK(lookup テーブル型)or
  `CHECK (role IN (...))`(`avatar_assignments.role` は check 追加が最小)。
- 時間整合: `CHECK (valid_from <= valid_to)` を
  `avatar_memberships`/`avatar_ownership_periods`/`avatar_monikers`
  に、`CHECK (starts_at IS NULL OR ends_at IS NULL OR starts_at <= ends_at)` を `*_memberships` に。
- revoke 整合:
  `CHECK (revoked_at IS NULL OR revoke_reason_id IS NOT NULL)`(memberships)。assignment 側にも同型。
- active relation uniqueness: 既存 partial unique を踏襲。新規 `group_avatar_memberships`
  にも partial unique。
- primary uniqueness per scope: 既存 `idx_*_one_active_primary`
  で担保済み。**「primary は必ず active membership 上」**は既に WHERE 句が保証。追加不要。
- archived/suspended 資源への active relation 禁止: cross-table のため DB check 不可。**service
  guard で統一**(全 grant/attach service の先頭で対象 state を検査)+ invariant test。
- immutable 列: `parent_id`(既存)、`public_id`(既存)、binding の `avatar_id`/`persona_id`
  に readonly attribute。
- lifecycle transition guard: state 遷移表を service 内 `ALLOWED_TRANSITIONS`
  定数で保持し、違反は raise(silent fallback 禁止ルールに従い黙殺しない)。

## 9. Controller / service design plan

原則: **関係テーブルへの write は必ず use-case service 経由**。controller は params 解決 +
authorize! + service 呼び出し + 表示のみ。

新設 service(`app/services/` 配下、既存 `OrgOperatorLifecycle*` の命名・構造に倣う):

| Service                                                                          | 責務                                                                                          | 呼び出し元 controller                                                                        |
| -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `AccountAssignment::Grant` / `Revoke`                                            | Identity↔Account 接続の唯一の入口                                                             | bootstrap 系(既存 `IdentityGraphProvisioner` から委譲)                                       |
| `CollectiveMembership::Grant` / `Revoke` / `MakePrimary` / `Transfer(unit 移動)` | membership lifecycle。granted_by/approved_by を必須引数に                                     | `Base::{App,Org,Com}::Organizations::MembershipsController`(現行スタブを service 配線に置換) |
| `AvatarProvisioning::Create`                                                     | Avatar + Handle + AvatarPersonaBinding + AvatarAssignment(owner) をトランザクションで一括生成 | `Base::App::AvatarsController#create`(生 CRUD を置換)                                        |
| `AvatarAuthority::Grant` / `Revoke` / `TransferOwnership`                        | AvatarAssignment 操作 + last-owner 保護 + OwnershipPeriod 更新                                | 将来の avatar 管理画面                                                                       |
| `AvatarLifecycle::Suspend` / `Archive` / `Restore`                               | avatar_status 遷移                                                                            | org 側 moderation controller                                                                 |
| `GroupManagement::Create` / `AttachAvatar` / `DetachAvatar` / `Reorder`          | Group container 操作                                                                          | `Base::App::GroupsController`(現行 index スタブを拡張)                                       |
| `AvatarSocialGraph::*`(既存)                                                     | controller/policy を新設して配線                                                              | 新 `Base::App::Avatars::{Follows,Blocks,Mutes}Controller`                                    |

加えて `test/unit/security/forbidden_rails_patterns_test.rb` に「controller 内での関係テーブル
`create!`/`destroy`」検出パターンを追加し、再発を機械的に防ぐ。

## 10. Migration plan(既存データあり前提、段階実行)

各段階は独立 PR。破壊的操作なし。rename はしない(新カラム追加 + backfill + 制約 + 旧経路凍結の順)。

1. **[safe] 制約追加第一弾**: §8 の check constraint 群(`NOT VALID`→`VALIDATE CONSTRAINT`
   の 2 段)、`avatar_assignments.role` check。既存データ検証 rake を先に流す。
2. **[safe] binding 対称化**: `avatar_agent_bindings`/`avatar_individual_bindings`
   に assigned_at/revoked_at/partial unique 追加(行が少ない今のうち)。
3. **[safe] Group 新設**: `client_groups` + `group_avatar_memberships`(新規テーブルのみ)。
4. **[dual-write] Avatar 生成経路切替**: `AvatarProvisioning::Create`
   導入。binding を必ず作成、`client_id` は当面併記(dual write)。既存 Avatar への binding
   backfill(Member→Persona 対応表経由、`Member`
   解体 docs と整合させる)。backfill はデータ migration でなく rake task。
5. **[dual-write] AvatarAssignment 主体移行**: `account_public_id` カラム追加 → dual write →
   backfill → 読み取り切替。
6. **[dual-read] Identity↔Account 一本化**:
   assignment に granted*by 等を追加 → 読み取りを assignment 経由に統一(`Persona#client_identity`
   を assignment 経由の委譲に差替)→ UNIQUE index `idx*_*one_per*_\_identity` を「active
   assignment の partial unique」へ移管 → 最後に column 削除(**削除はユーザー承認を得る別 PR**)。
7. **[cleanup] legacy 縮退**: `avatars.client_id` の新規書き込み停止 → cross-DB association
   65 件の削減(backlog audit に従う)→ `member_avatar_*`
   の権限判定を AvatarAssignment へ statement 移行。`Member`/`Organization(legacy)`
   解体自体は既存 decomposition ADR の別トラック。
8. 全段階で `bin/rails db:verify_no_schema_drift` を PR 前に実行。rename が必要になった場合のみ
   `rename_table_strict`。

## 11. Test plan

- **Model**: `persona_membership_test.rb`
  等を lifecycle まで拡充(grant→approve→revoke、primary 排他、starts/ends 境界値、revoked 後の再 grant)。binding 対称化後の agent/individual
  binding テスト。check constraint は「Rails
  validation を bypass した insert が DB で落ちる」テストを各 1 本。
- **Service**: 新設 service 全部に success/failure/guard(suspended 資源への grant 拒否、last-owner 保護、self-transfer 拒否、遷移表違反)。既存
  `org/operator_lifecycle/*_test.rb` をテンプレに。
- **Controller/request**: membership
  controllers のスタブテストを実挙動テストに置換。AvatarsController#create が service 経由になったことの検証(トランザクション失敗時に Avatar/Handle/Binding が残らない)。
- **Policy**: 空クラス policy(`AvatarAssignmentPolicy`
  等)に実ロジックとテストを、service 導入と同時に。
- **Invariant/security**: `forbidden_rails_patterns` 拡張(controller 内 join-table
  write 検出)。「avatar DB に UGC テーブルを追加していない」境界テスト(avatar
  structure.sql のテーブル名 allowlist)。cross-DB 新規 bigint 参照の検出テスト。
- **Migration**: backfill rake の冪等性テスト、constraint `VALIDATE` 前のデータ検証 rake のテスト。

## 12. Final action list(実装順)

1. **ADR: cross-DB 参照は public_id string に統一** — 新規
   `adr/cross-db-reference-by-public-id.md`。完了条件: bigint
   cross-DB 参照の新設禁止と既存 3 方式の扱いが明文化。
2. **forbidden patterns 拡張** — `test/unit/security/forbidden_rails_patterns_test.rb`。完了条件:
   controller 内の関係テーブル write が CI で fail する(既存違反 1 件は allowlist で明示)。
3. **check constraint 第一弾** — `db/avatars_migrate/`, `db/*_zenith_migrate/`。完了条件:
   §8 の時間整合・role check が `VALIDATE` 済み、drift 検証 pass。
4. **binding 対称化** — `avatar_agent_bindings`/`avatar_individual_bindings` migration + model +
   test。完了条件: persona 版と同一のライフサイクル API。
5. **`AvatarProvisioning::Create` 導入** — `app/services/avatar_provisioning/create.rb`,
   `avatars_controller.rb` 置換。完了条件: controller から `create!`
   が消え、binding が生成され、既存 1195 行の controller test が green。
6. **既存 Avatar への binding backfill rake** — `lib/tasks/`。完了条件: 全 avatar に active
   binding、冪等。
7. **CollectiveMembership service 群 + membership controller 配線** —
   `app/services/collective_membership/*.rb`、3 サーフェスの memberships controller。完了条件:
   grant/revoke/make_primary が UI から可能、policy 実装、テスト。
8. **AccountAssignment 権威化(dual-read)** — assignment カラム追加 migration +
   `Persona`/`Agent`/`Individual` の読み取り差替。完了条件:
   identity 解決が assignment 経由、旧 column は書き込みのみ継続。
9. **Group v1** — migration + `ClientGroup`/`GroupAvatarMembership` model + `GroupManagement`
   service + GroupsController 拡張。完了条件:
   container として attach/detach/reorder 可能、投稿主体化する API が存在しない。
10. **AvatarSocialGraph の controller/policy 配線** — routes +
    `Base::App::Avatars::{Follows,Blocks,Mutes}Controller` + policy 実装。完了条件:
    follow/block/mute が HTTP から service 経由で操作でき、block 時 follow 剥がしがテスト済み。

(`personas.client_identity_id` の物理削除、legacy `Member`/`Organization` 解体、content
DB 新設は本リストの後続トラック。削除系はユーザー承認を個別に取る。)
