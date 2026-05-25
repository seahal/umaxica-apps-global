# Identity / Persona / Organization / Membership / Profile / Avatar / Attribution 設計レビュー

## Context

ユーザは Rails アプリの認証 / アカウント / 組織 / 表示 / 帰属を整理するドメインモデルを提案中。本レビューはクリーンスレート概念レビュー(既存
`Persona` / `Avatar` などの実装は一旦無視) だが、最終実装は本リポジトリの ADR どおり
**3 サーフェス(app/org/com)並列**を維持する前提。つまり「`Identity` や `Persona`
を一つのテーブルにまとめる」案は採用不可。概念名は議論し、実装名はサーフェスごとに具体化する。

ゴール:設計の穴を全部潰したうえで、最小実装と最終形・移行路を1ファイルで提示する。

---

## 1. 致命的批判(Brutal Critique)

### 1.1 「Persona」は概念名として失敗している

- `Persona` という語は「外見/役柄」のニュアンスが強い。読者は **`Profile` や `Avatar`
  と同類**だと誤解する。設計の中核(=サービスを実際に使う主体)を、表示概念と語感が衝突する単語に置くのは事故設計。
- さらに本リポジトリでは `Persona`
  は app サーフェス専用ユーザモデルとして既に固有名詞化済み。クリーンスレート議論であっても、この語を「汎用主体」と「app の具体主体」の二重定義で扱うことは絶対に避ける。**汎用層には
  `Persona` を使わない**こと。
- 代替候補:`Account`(意味的に最も近いが、ユーザは billing 衝突を理由に避けたい意向),
  `Subject`(OIDC の sub と整合)、`Principal`(authorization 文脈で過負荷)、
  `Actor`(現リポジトリでは「リクエスト時のファサード名」として予約済みなので不可)。→ 推奨は「サーフェス固有の自然な具体名」(`Persona`
  / `Agent` /
  `Individual`)で済ませ、汎用層に名前をつけない。**ドメイン名は具象、議論の概念は別語彙**で分ける。

### 1.2 Identity ↔ Persona 分離は条件付きでしか正当化されない

- 「1
  Identity が多 Persona を持つ」モデルが**実際の業務要件にあるか**を先に決めよ。なければ過剰モデリング。
  - 「個人/仕事の使い分け」「同じ人が複数のテナントで別人格」は本当に来るのか?
  - 来ないなら 1:1 で固定し、`Identity` と `Persona` を分ける唯一の理由は
    **「認証属性とサービス属性のライフサイクル分離」(=退会時に Identity 側のみ削除して Persona 履歴は残す等)**になる。これは正当な分離理由なので OK。
- 1:N にする場合、必ず答える必要があるもの:
  1. ログイン直後にどの Persona を選ぶか(デフォルト Persona の概念)
  2. Persona 切替時にセッションは継続するか(切替=再認証相当か)
  3. Persona ごとに `Membership`
     を独立に持つか(=同じ Identity が同じ Organization に複数 Persona で属せるか — 99% No だが明示)
- これらの答えが曖昧なまま 1:N にすると、`Actor.persona`
  の選択ロジックがどんどん controller に染み出して破綻する。

### 1.3 `Avatar` を「視覚表現のみ」に狭めるのは語彙の自殺

- 一般的な ChatOps/SaaS では `Avatar`
  は「ユーザを代表する小さな画像」を意味し、定義は揺れない。しかし**狭めると、開発者は無意識に「avatar
  = ユーザ表象」と読み戻す**ため、毎回「`Avatar`
  はあくまで画像です」と教育が必要になる(=設計が言語と戦っている状態)。
- 「画像/アイコン/サムネ/色」を保持する型なら、名前は意味どおり `DisplayImage` / `ProfileImage` /
  `Icon` などにせよ。あるいは `Profile.image_url` の単一属性で十分ならテーブルすら不要。
- 本リポジトリの既存 `Avatar` は組織資産で role を持つリソース。クリーンスレートでも、 `Avatar`
  という語をドメインから完全に追放するか、既存セマンティクスを尊重するかの二者択一にせよ。**中間(=「画像だけ」)が一番危険**。

### 1.4 Profile を polymorphic にする案は罠

- `profileable_type` + `profileable_id` の polymorphic
  FK は PostgreSQL の参照整合性を失わせる。本リポジトリは既に `setting_preference` の polymorphic
  owner を ADR で却下済み。方針を踏襲して polymorphic を採用しないこと。
- 解決策:
  - **`PersonaProfile`** / **`OrganizationProfile`** / **`MembershipProfile`**
    を別テーブルに分ける(列構造が大きく重複しないなら推奨)。
  - 列構造が本当に同一なら、`profiles` 一本にして `persona_id` / `organization_id` / `membership_id`
    をすべて nullable FK にし、CHECK で「ちょうど 1 つだけ非 NULL」を強制 (FK +
    CHECK の組合せで RI を失わない)。

### 1.5 Attribution を「グローバル一表」にする発想は反パターン

- 「post / comment / audit_event / approval」それぞれが**異なる帰属粒度**を持つ。
  - post: persona_id + display_name スナップショット
  - audit_event: identity_id + persona_id + membership_id + role + ip
  - approval: membership_id + role + organization_id + display_name スナップショット
- 一表に押し込もうとすると、結局すべての列が nullable になり、`attribution_kind`
  判別列が生え、index が破綻する。
- **正しい設計:`Attribution` は「概念」であって「テーブル」ではない**。
  - コンテンツ系(post, comment, article):テーブル列に `*_snapshot` を直接持つ。
  - 監査系(audit_event):append-only の `audit_events` テーブルが既に帰属レコード本体。
  - 承認系(approval):承認時点の `membership_id` + `role_snapshot` + `display_name_snapshot`
    を承認レコードに持つ。
- 共通したいのは「**スナップショット採取の関数**(`Attribution.snapshot_for(actor:)` →
  Hash)」であって、テーブルではない。

### 1.6 「現在の Profile を JOIN して表示する」は監査破壊

- 投稿一覧で `posts JOIN profiles ON profiles.persona_id = posts.persona_id`
  を行うと、ユーザが表示名を変えた瞬間に**全過去履歴が遡って書き換わる**。
- 規制業種(医療/金融)では「投稿時の表示名」を不変保持することがコンプラ要件。
- 解決策:**投稿時点の display_name / handle /
  avatar_url を posts に列で書き込む**。ライブ更新が必要な箇所(プロフィールカード等)だけ join、履歴系は snapshot を表示。

### 1.7 ライフサイクル設計が抜けている

提案は「削除/停止/退会/解約/シュレッディング」を
**同一視している**ように読める。これらは別物。整理しないと controller / policy / audit でバグる。

| 名称                      | Identity            | Persona       | Membership | Attribution snapshot                            |
| ------------------------- | ------------------- | ------------- | ---------- | ----------------------------------------------- |
| 停止 (suspension)         | active, can't login | active        | active     | unchanged                                       |
| 退会 (withdrawal)         | revoked             | tombstoned    | terminated | unchanged (immutable)                           |
| 解約 (termination, org側) | unchanged           | unchanged     | terminated | unchanged                                       |
| 削除 (deletion, soft)     | revoked             | soft_deleted  | terminated | unchanged                                       |
| シュレッディング (GDPR)   | purged              | pseudonymized | terminated | **display_name のみ "[redacted]" に上書き許容** |

- **Attribution は原則 immutable**。例外は法令対応のシュレッディングのみで、その場合も「上書き」ではなく「shred_at +
  redacted_reason を別列に記録」が望ましい。

---

## 2. Q1–Q15 への直接回答

1. **Identity と Persona は別か?** —
   1:1 のままなら分けない方が良い。1:N の業務要件が**確証される**まで 1 テーブルに統合し、列を「auth*\*」「service*\*」のプレフィクスで命名分離する暫定が安全。
2. **Persona は良い名前か?** — 悪い。1.1 参照。
3. **Profile はどこに属するか?** — polymorphic 不可(1.4)。`Persona` 必須、`Organization`
   必須、`Membership` は遅延(必要が生じた時点で `MembershipProfile` を追加)。
4. **`MembershipProfile` にすべきか?**
   — 「組織別に表示名/役職を変えたい」要件が出た時点で作る。最初から作らない。
5. **`Avatar` は狭すぎるか?** — 名前と意味のミスマッチがあるので、**狭めるなら改名**(1.3)。
6. **`Attribution` は first-class モデルか?** —
   No。**概念**として扱い、各テーブルに snapshot列で実装(1.5)。
7. **Profile / Avatar 変更時の履歴表示は?** —
   snapshot 列で固定。ライブ表示は join、履歴系は snapshot(1.6)。
8. **削除/停止/退会/解約/シュレッディング** — 状態テーブルで明示分離(1.7)。
9. **Profile/Avatar/Attribution を authn/authz と混同するリスク** —
   - Profile.slug を login identifier にする → なりすまし
   - Avatar URL を identity 検証に使う → spoof
   - Attribution を後編集可能にする → 監査改ざん
   - Profile の role 列で authorization 判定 → 権限昇格(role は Membership にのみ置く)
10. **現在 Profile を join するリスク** — 1.6 のとおり、retroactive
    rewrite、GDPR と監査保持要件の衝突、現名/当時名の混同。
11. **小さく始めた場合の罠** —
    - User 一本で始めて後から Identity + Persona に割ると、コンテンツ FK の付け替えが必要
    - Membership を後で導入すると、Persona に直接ぶら下げた role 列の駆除が必要
    - snapshot 列を後付けすると、過去データの display_name を遡及推定不可
    - → 最初から **snapshot 列だけは入れておく**。これだけは後付け不可。
12. **命名の代替** — 第 4 節参照。
13. **今正規化すべきもの / 後でよいもの** — 第 5 / 6 節参照。
14. **DB 不変条件** — 第 7 節参照。
15. **Actor の current-context** —
    - `Actor.identity` — 必要(token validation 用、controller では基本使わない)
    - `Actor.persona` (具体名 `Actor.client` 等) — 主使用
    - `Actor.organization` — 現スコープ、nil 可
    - `Actor.membership` — `current_membership`(scope 依存)
    - `Actor.profile` / `Actor.display` — 派生キャッシュ、表示専用、authorization に使うな
    - `Actor.avatar` を独立公開する必要なし。`Actor.display.image_url` で十分

---

## 3. 命名問題リスト

| 提案名       | 判定                | 理由 / 代替                                                           |
| ------------ | ------------------- | --------------------------------------------------------------------- |
| Identity     | keep                | OIDC と整合。サーフェス具体名は `ClientIdentity` 等                   |
| Persona      | **rename**          | Profile/Avatar と語感衝突。汎用層では使わず、サーフェス自然名で具体化 |
| Organization | keep                | サーフェス具体名は `Company`(com)、`Bureau`(org)等                    |
| Membership   | keep                | 標準語彙                                                              |
| Profile      | keep (注意付)       | Persona と意味が近いので、必ず「**表示専用**」を docstring で明記     |
| Avatar       | **rename or merge** | `DisplayImage` / `Icon` に改名 or `Profile.image_url` に統合          |
| Attribution  | keep (概念のみ)     | テーブル化禁止。snapshot 列で実装                                     |
| Actor        | keep                | リクエスト時の current ファサード名。永続化しない                     |

---

## 4. 不足している不変条件リスト

DB-level に強制すべきもの:

- `identity.id` UNIQUE(自明)
- `identity_credential.identity_id` FK NOT NULL、credential 種別ごとの partial UNIQUE
  (TOTP は 1 件、passkey は複数可、recovery code は複数可)
- `persona.identity_id` FK NOT NULL、1:1 なら UNIQUE
- `membership.(persona_id, organization_id)` 上の partial UNIQUE
  `WHERE state IN ('invited','active','suspended')`(終了済 membership は重複可)
- `membership.role_id` FK to `roles` 表(string enum 禁止、状態テーブル方針と一致)
- `membership.state_id` FK to `membership_states` 表(同上)
- `profile.(persona_id)` UNIQUE (1:1 開始)。1:N にする場合は `is_primary boolean` + partial UNIQUE
  `WHERE is_primary`
- `organization.parent_id` を許す場合、cycle 検出を **ltree / closure_table**
  で物理的に阻止 (アプリ層 callback では穴が空く)
- すべての `*_snapshot_display_name` 列 NOT NULL(空文字 OK だが NULL は禁止 —
  snapshot は採取時に必ず存在するため)
- audit_events は append-only:`REVOKE UPDATE, DELETE` を migration で実行
- shred 時の display_name 上書きは別列(`shredded_display_name`)で実現し、原列は触らない

---

## 5. 最小実用モデル(MVP)

3 サーフェス並列前提。app サーフェスで例示(org/com も同型コピー):

```
ClientIdentity
  - id, login_public_id, status_id (FK -> client_identity_statuses)
  - timestamps
Persona (= app サーフェス用主体。汎用名ではない)
  - id, client_identity_id (UNIQUE FK NOT NULL)
  - display_name, handle (UNIQUE)
  - image_url (= avatar 統合)
  - timestamps
Company (= app サーフェスの組織)
  - id, parent_id (nullable), display_name
PersonaMembership
  - id, persona_id (FK), company_id (FK)
  - role_id, state_id
  - joined_at, left_at
  - UNIQUE (persona_id, company_id) WHERE state in (active, invited, suspended)
```

各コンテンツテーブル(`posts`, `comments`, `audit_events`)に snapshot 列:

```
attributed_persona_id           bigint  NULL  REFERENCES persona(id)
attributed_membership_id        bigint  NULL  REFERENCES persona_memberships(id)
attributed_company_id           bigint  NULL  REFERENCES companies(id)
attributed_display_name         text    NOT NULL
attributed_handle               text    NOT NULL
attributed_image_url            text    NULL
attributed_role_at_time         text    NULL
attributed_at                   timestamptz NOT NULL
```

これだけ持っておけば、後で Profile/Avatar/Membership を独立させても **過去データは安全**。

---

## 6. 完全正規化モデル

```
ClientIdentity                  -- auth root
ClientIdentityCredential        -- passkey, TOTP, recovery, oauth_subject (kind 列)
ClientIdentityStatus            -- 状態テーブル(enum 不使用)
ClientIdentitySignIn            -- 認証履歴

Persona                         -- service usage subject
PersonaStatus

Company                         -- organization (hierarchy: ltree)
CompanyStatus

PersonaMembership               -- belonging
PersonaMembershipRole           -- role 表
PersonaMembershipState          -- state 表

PersonaProfile                  -- persona の表示属性(1:1 開始)
CompanyProfile                  -- company の表示属性
PersonaMembershipProfile        -- org-scoped 表示属性(必要時のみ追加)

# Attribution は概念。テーブルなし。各コンテンツ表が snapshot 列を持つ。
```

`PersonaProfile` を分ける利点:

- `Persona` の認証連携情報(handle 等のシステム識別)と、純粋な表示メタ(bio, pronouns,
  links) を保守の単位として分離できる。
- 1:N 化したくなった時に `is_primary` を入れやすい。

org / com サーフェスは同型で `Operator` / `Visitor` 系として複製。

---

## 7. 移行パス(最小 → 正規化)

Stage 1 (MVP):

- `client_identities`, `personas`, `companies`, `persona_memberships`
- 各 personas に `display_name` / `handle` / `image_url` を直に持つ
- 各コンテンツ表に snapshot 列を追加(**ここを省くと後で取り返せない**)

Stage 2 (display を分離):

- `persona_profiles` 表を作り、`personas` から display_name / handle / image_url を移す
- 既存コードは `persona.profile.display_name` を参照するよう更新
- snapshot 列は無変更(過去データ保護)

Stage 3 (組織別表示):

- `persona_membership_profiles` 表を、要件発生時に追加
- Stage 2 の `persona_profiles` は維持(global default として残る)

Stage 4 (1:N persona):

- `personas.client_identity_id` の UNIQUE を外す
- `personas.is_primary` を追加、partial UNIQUE `WHERE is_primary`
- ログインフロー / `Actor.persona` 選択ロジックを追加(別 ADR 必須)

各 stage は独立に倒せるよう、snapshot 列を初日から入れることが最重要。

---

## 8. Rails モデル名・関連の例(app サーフェス)

```ruby
class ClientIdentity < ApplicationRecord
  has_many :client_identity_credentials, dependent: :restrict_with_exception
  has_one  :persona, dependent: :restrict_with_exception
  belongs_to :status, class_name: "ClientIdentityStatus"
end

class Persona < ApplicationRecord
  belongs_to :client_identity
  has_one  :profile, class_name: "PersonaProfile", dependent: :restrict_with_exception
  has_many :memberships, class_name: "PersonaMembership", dependent: :restrict_with_exception
  belongs_to :status, class_name: "PersonaStatus"
end

class PersonaProfile < ApplicationRecord
  belongs_to :persona
  # display_name, handle, bio, image_url, pronouns, ...
end

class Company < ApplicationRecord
  belongs_to :parent, class_name: "Company", optional: true
  has_many :persona_memberships
  has_one  :profile, class_name: "CompanyProfile"
end

class PersonaMembership < ApplicationRecord
  belongs_to :persona
  belongs_to :company
  belongs_to :role,  class_name: "PersonaMembershipRole"
  belongs_to :state, class_name: "PersonaMembershipState"
  has_one :profile, class_name: "PersonaMembershipProfile", dependent: :restrict_with_exception
end
```

org / com 用には `Operator*` / `Visitor*` プリフィクスで同型を複製。

---

## 9. DB 制約例(抜粋)

```sql
-- 1 Identity に 1 Persona (Stage 1)
ALTER TABLE personas
  ADD CONSTRAINT personas_client_identity_id_key UNIQUE (client_identity_id);

-- 重複 Membership 防止(active 系のみ)
CREATE UNIQUE INDEX persona_memberships_active_uniq
  ON persona_memberships (persona_id, company_id)
  WHERE state_id IN (
    SELECT id FROM persona_membership_states
    WHERE code IN ('invited','active','suspended')
  );
-- 注: 上記サブクエリは partial index には書けない。実際は state_id を直値で
-- WHERE state_id IN (1,2,3) として、状態追加時 reindex する運用を取るか、
-- application-side service で一意性を保証する。

-- audit append-only
REVOKE UPDATE, DELETE ON audit_events FROM app_role;

-- snapshot 列必須
ALTER TABLE posts
  ALTER COLUMN attributed_display_name SET NOT NULL,
  ALTER COLUMN attributed_at SET NOT NULL;
```

---

## 10. 監査・帰属スナップショット列(標準セット)

```
attributed_persona_id        FK   nullable -- 後追い参照用、本体ではない
attributed_membership_id     FK   nullable
attributed_organization_id   FK   nullable
attributed_display_name      text NOT NULL
attributed_handle            text NOT NULL
attributed_image_url         text NULL
attributed_role_code         text NULL      -- 当時の役職
attributed_organization_name text NULL      -- 当時の組織名
attributed_at                timestamptz NOT NULL
attributed_via               text NULL      -- "web" | "api" | "system"
attributed_ip                inet NULL      -- 監査用、コンテンツ表では省略可
```

サービス層 `Attribution::Snapshot.for(actor:)` で1箇所に集約し、各コンテンツの `before_create`
で書き込み、以降は **immutable** 扱い。

---

## 11. Actor ファサードの公開 API(推奨)

サーフェス具象を直露出する方針(本リポジトリの 3 系統並列方針と整合):

```ruby
# app surface
Actor.client                 # = Persona (app サーフェス具体)
Actor.client_identity        # token validation 用、controller では原則使わない
Actor.company                # 現スコープの組織
Actor.client_membership      # 現スコープの membership
Actor.client.profile         # 表示属性(authorization に使うな)

# org / com も同型
Actor.operator, Actor.operator_identity, Actor.bureau, Actor.operator_membership
Actor.visitor,  Actor.visitor_identity,  ...
```

- `Actor.profile` のような汎用名を controller に露出させない(サーフェス取り違えの源)。
- `Actor.avatar` は独立公開しない。`Actor.client.profile.image_url` で十分。

---

## 12. 最終勧告(各概念 keep / rename / merge / split)

| 概念         | 勧告                                                          | 補足                                                             |
| ------------ | ------------------------------------------------------------- | ---------------------------------------------------------------- |
| Identity     | **keep + per-surface split**                                  | `ClientIdentity` / `OperatorIdentity` / `VisitorIdentity`        |
| Persona      | **rename(汎用層では使わない) + per-surface split**            | サーフェス具体名 `Persona` / `Agent` / `Individual` を維持       |
| Organization | **keep + per-surface split**                                  | `Company` / `Bureau` / (app は不要なら持たない)                  |
| Membership   | **keep + per-surface split**                                  | `PersonaMembership` / `AgentMembership` / `IndividualMembership` |
| Profile      | **keep**(`*Profile` 表として分離)                             | `Persona.has_one :profile`                                       |
| Avatar       | **merge into Profile** or **rename to `Icon`/`DisplayImage`** | 「画像のみ」なら独立表は不要                                     |
| Attribution  | **keep as concept, NOT a table**                              | snapshot 列方式で実装                                            |
| Actor        | **keep**(request facade)                                      | 永続化しない                                                     |

最大の落とし穴は (a) `Persona` 命名の重複と (b) `Attribution` を表にしてしまうこと、(c)
snapshot 列を後付けにしてしまうこと。この 3 つだけは初日に避ければ後悔は最小。

---

## 13. 検証方法(本計画を採用した場合の確認手順)

1. 1:N persona の業務要件が**今ない**ことを ADR で明文化する(将来再開可能)。
2. `personas` テーブルに snapshot 列を最初から書く migration を試作し、`rename_table_strict`
   等の既存規約と整合するか確認。
3. controller で `Actor.profile` を返さないことを RuboCop カスタム cop か grep で機械検査。
4. `audit_events` への UPDATE/DELETE が DB レベルで拒否されるか migration テストで確認。
5. snapshot 採取サービス `Attribution::Snapshot.for(actor:)`
   を1箇所だけに置き、重複実装が出ないようテストで pin する。

---

## 14. 補遺:本リポジトリ既存実装との整合(参考)

クリーンスレートとはいえ、最終的に既存 3 系統(`Client`/`Operator`/`Visitor` × `Identity` ×
`Persona`/`Agent`/`Individual`)へ落とし込む際は以下を尊重:

- 命名衝突する `Persona` / `Avatar` は本提案でも具体名のままにし、汎用層を持ち込まない。
- `Actor.context` ファサード(`notes/implementation/2026-05-21-actor-session-token-removal.md`
  に最新方針あり)に新規ゲッタ(`profile` 等)を増やさず、サーフェス固有ゲッタ経由で公開。
- `SettingPreference` で polymorphic owner を却下した ADR と整合させ、`Profile` も polymorphic
  FK を使わない。
