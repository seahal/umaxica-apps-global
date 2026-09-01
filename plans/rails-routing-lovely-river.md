# Rails routing DHH-ish レビュー & 移行プラン

## Context

`config/routes/*.rb` 9 ファイルを「routing は `resource` / `resources` のみ、controller
action は標準 7 action (index/show/new/edit/create/update/destroy) に限定、business verb は noun
resource へ、責務境界は nested resources でなく namespace、resource 名は one-word
noun」という方針で厳格レビューした。結論: **docs / help / news / info / side は PASS。core /
palm は WARN。auth は WARN〜FAIL。base が最大の違反源で FAIL。**
違反はほぼ全て base.rb と auth.rb の social / oauth / preference / identity 周りに集中している。

---

## ファイル別レビュー

### config/routes/auth.rb — Verdict: **FAIL**

resourceful 度は高い(9 割は resource/resources)が、social 連携と Entra に blocker がある。

#### Problems

1. **`scope :google` / `scope :apple` 内の `get "sign/in"` / `get "sign/up"` →
   `social/authentications#continue`**(auth.rb:163-183)
   - custom action `continue` が CRUD vocabulary 外。business verb が route に露出。GET + `defaults`
     で intent を運ぶのは「router を任意 URL→任意 method の表として使う」典型。
   - 原則違反: custom action 禁止 / noun resource 化。severity: **blocker**
2. **`get "google/callback"` / `match "apple/callback", via: %i(get post)` / `get "failure"` →
   `omniauth_callbacks#omniauth` `#failure`**(auth.rb:142-161)
   - custom action `omniauth` / `failure`。ただし OmniAuth middleware と Apple の form_post
     response_mode が path/verb を固定する**外部契約**。
   - severity: minor(例外候補)。ただし `failure` に `as:` がなく helper 不在なのは直す。
3. **org の Entra:
   `resource :entra, only: :new do post :authorization; get :callback end`**(auth.rb:472-475)
   - singleton resource に custom member action を 2 つ生やしている。`authorization` / `callback`
     は名詞なのに action として実装されており、controller action が CRUD から漏れる。
   - severity: **blocker**。かつ機械的に直せる(下記 rewrite は **path 不変**)。
4. **`namespace :sign { resource :up / :in / :out }`** —
   resource 名が前置詞であって名詞でない。`Sign::Ups`/`Sign::Ins`
   という controller 語彙は Rails 標準から外れる。URL `/sign/in` を守るなら
   `resource :registration, path: "up"` / `resource :session, path: "in"` が正道。severity:
   major(ただし URL は対外契約なので path 固定で改名可能)。
5. **`namespace :edge > :token > resource :check, only: :show`** — `check` は動詞。→
   `resource :status, only: :show`。severity: major(API client 側と同期必要)。`dbsc`
   はプロトコル名(DBSC)なので許容。
6. **`resources :iam / :system / :audit / :support / :billing, only: :index`**(org,
   auth.rb:399-403)— `iam` `system` は可算名詞でなく、`resources`
   の複数形前提と噛み合わない(helper が `iam_index_path` 形になる)。セクションのランディングなら
   `resource :xxx, only: :show` の singleton が正しい。severity: minor。
7. `namespace :verification`
   が連続 2 回宣言(auth.rb:188-199 ほか各サーフェス)— 統合すべき。severity: minor。
8. `resources :robots, only: :index, path: "robots.txt"` —
   robots.txt は単一文書なのに collection(`resources`+index)。singleton/collection の取り違え。ただし infra 例外ファイルなので severity:
   minor(全ファイル共通)。

#### Suggested rewrite(抜粋)

> **Status — item 1 is superseded. Do not apply it.** The app-surface social ceremony start is
> POST-only (`resource :session, only: :create`), because a GET entry can be triggered by a link and
> is login CSRF (CVE-2015-9284). Base reaches it through `POST /social/authentication/continuation`,
> which issues a grant and 307s to the Auth host. The stale `only: :new` copies of these routes on
> the Base host pointed at actions that no longer exist and have been deleted from
> `config/routes/base.rb`. The rest of this section still stands.

```ruby
# 1. social 開始点: verb 'continue' → 名詞 resource。provider は namespace で切る
namespace :social do
  namespace :google do
    resource :session,      only: :new, controller: "/auth/app/social/sessions"      # GET /social/google/session/new
    resource :registration, only: :new, controller: "/auth/app/social/registrations" # GET /social/google/registration/new
  end
  namespace :apple do
    resource :session,      only: :new, controller: "/auth/app/social/sessions"
    resource :registration, only: :new, controller: "/auth/app/social/registrations"
  end

  # 外部契約 (OmniAuth / Apple form_post) — 例外として残す
  get "google/callback", to: "omniauth/omniauth_callbacks#omniauth", as: :google_callback, defaults: { provider: "google" }
  match "apple/callback", to: "omniauth/omniauth_callbacks#omniauth", via: %i(get post), as: :apple_callback, defaults: { provider: "apple" }
  get "failure", to: "omniauth/omniauth_callbacks#failure", as: :failure
end
# controller: Social::SessionsController#new / Social::RegistrationsController#new
# helper: auth_app_social_google_session_path など。旧 /social/google/sign/in は breaking change。

# 3. Entra — path 完全互換、controller だけ分割
namespace :sign do
  namespace :in do
    namespace :entra do
      resource :authorization, only: :create  # POST /sign/in/entra/authorization
      resource :callback,      only: :show    # GET  /sign/in/entra/callback
    end
  end
end
# controller: Sign::In::Entra::AuthorizationsController#create / CallbacksController#show
# 現行の resource :entra, only: :new は resource :entra(new のみ)として併存可、
# もしくは namespace 内に resource :ceremony, only: :new を置く。

# 5. token check → status
namespace :edge do
  namespace :v0 do
    namespace :token do
      resource :status, only: :show   # GET /edge/v0/token/status — breaking change(client 同期要)
      resource :dbsc,   only: :create # プロトコル名。例外として維持
    end
  end
end

# 6. org 管理セクション: collection でないなら singleton
resource :iam,     only: :show  # IamsController は不自然なので controller: :iam 指定か、resource :access_control に改名
resource :system,  only: :show
resource :audit,   only: :show
```

#### Naming review

- `sign/up` `sign/in` `sign/out`: 前置詞 resource。path は据え置きで `registration` / `session` /
  `termination`(または
  `session#destroy`)へ寄せるのが理想だが、全サーフェス一斉変更になるため独立フェーズ化を推奨。
- `guard` / `check` / `challenge`: `challenge` は名詞で OK。`check` は動詞 — `verification` か
  `status` へ。`guard` は名詞だが意味曖昧 — `gate` か `interstitial` 等ドメイン名詞を検討。
- `secret_credential`: compound。`namespace :secret`
  は不自然なので compound 例外として明記可(credential だけでは種別が消える)。
- `redelivery` / `removal` / `cancellation` / `completion` / `rotation`:
  verb→noun 変換の好例。**この命名は正しい**。

#### Exception review(残してよい non-resourceful / 特殊 path)

- `root` / health / `robots.txt` / `sitemap.xml` / `.well-known/jwks.json`: infra・仕様固定。OK。
- `csp-violation-report`: ブラウザが report-uri を TTL キャッシュするため URL 不変が対外契約。OK。
- OmniAuth callback(get/match):
  middleware と Apple の仕様が path/verb を固定。OK(理由コメントを route に残すこと)。

---

### config/routes/base.rb — Verdict: **FAIL**

9 ファイル中もっとも違反が多い。custom get/post、重複 route、member URL への POST create、custom
member action が揃っている。

#### Problems

1. **`get :welcome, to: "welcomes#show", as: :welcome_entry`**(base.rb:14, 242, 393 — 3 サーフェス)
   - controller は既に `WelcomesController#show` と resourceful なのに route 側だけ custom get。
   - severity: **blocker**(修正コスト最小の純粋な違反)
2. **preference の emails: `resources :emails, only: :edit` + `delete "emails/:id"` +
   `post "emails/:id", to: "emails#create"`**(base.rb:33-35, 258-260, 409-411)
   - member route の手書き。しかも **POST /preference/emails/:id → create** は「member
     URL に collection 動詞」で REST 意味論が壊れている(create は collection への POST、member への意図なら update)。helper も
     `as: :email` を手で貼っている。
   - severity: **blocker**
3. **well_known の重複定義: `get "openid-configuration" (discoveries#show)` と
   `resource :openid_configuration, controller: :discoveries`
   が同一 path を二重定義**(base.rb:46-58 ほか)
   - route table に同一エンドポイントが 2 行並ぶ。oauth も同様: `get "authorize"` +
     `resource :authorize`、`post "revoke"` +
     `resource :revoke`(base.rb:84-91 ほか)。移行途中の残骸に見える。
   - severity: **major**(bare get/post 側を削除、helper 参照を差し替え)
4. **oauth の verb resource: `resource :authorize` / `resource :revoke`**
   - path `authorize`/`revoke` は RFC
     6749/7009/OIDC が固定する外部契約だが、**resource 名まで動詞にする必要はない**。`resource :authorization, path: "authorize"`
     / `resource :revocation, path: "revoke"` で path 据え置きのまま名詞化できる。severity: major。
5. **`namespace(:social) { resource :authentication, only: [] do post :continue; post :completion end }`**(base.rb:121-124)
   - `only: []` + custom member POST ×2。router が business verb 置き場になっている典型。severity:
     **blocker**
6. **social 配下の `get "sign/in"` 等が `/auth/app/...` controller へ dispatch**(base.rb:126-166)
   - auth.rb と同じ違反に加えて、base surface の route が auth module の controller を直接呼ぶ
     **surface 越境**。AGENTS.md の boundary 原則にも抵触。severity: **blocker**
7. **`resource :withdrawal do delete :session, action: :end_session end`**(base.rb:219-221, 370-372)
   - custom action `end_session`。しかも直後に
     `resource :withdrawal_session, path: "withdrawal/session", only: %i(new create)`
     があり、**同じ概念が 2 つの定義に割れている**。severity: **blocker**
8. **`resource :withdrawal_session, path: "withdrawal/session"`** — compound noun +
   path 手貼り。`namespace :withdrawal { resource :session }` で表現できる。severity: major。
9. **`resource :erasure do get :status end`**(base.rb:227-229, 377-380)— custom action `status` →
   nested singleton `resource :status, only: :show`。severity: major。
10. **session 一括削除が 3 通りに散乱**(base.rb:210-215, 365-367, 538-540)
    - `resource :session_set, path: "sessions", only: :destroy, controller: "revocations/alls"`(DELETE
      /identity/sessions — `resources :sessions` の collection path に singleton
      DELETE を重ねている)
    - `resource :other_sessions, only: :destroy, controller: "revocations/others"`(**singleton なのに複数形名**)
    - `namespace :sessions { resource :revocation, only: :create, controller: "/base/app/identity/revocations" }`(絶対パス controller 指定)
    - 同一ドメイン操作に 3 つの語彙・3 つの controller 規約。severity: **major**(統合対象)
11. **`resource :reset, only: %i(edit destroy)`(preference)** — `reset` は動詞。severity: major。
12. **edge token: `resource :check`(動詞)/ `resource :refresh`(動詞)** — `status` / `renewal`
    へ。severity: major(API client 同期要)。
13. `resources :avatar_memberships, controller: :group_avatar_memberships` — compound +
    controller 手貼り。`module: :groups` で `resources :memberships` に。severity: minor。
14. avatars の `resource :follow / :block / :mute, controller: "avatars/..."`
    — 英語としては名詞用法もある(a follow / a block / a mute)。1-level nest で親 avatar
    ID が必要なのは正当。controller 指定は `module:` で書ける。severity: minor。
15. `resource :other_sessions` の複数形 singleton(上記 10 に含む)。
16. `resource :secrets` の `resources :secrets, controller: :secrets`(app)と
    `controller: :secret_credentials`(com/org)— 同名 resource が surface 毎に別 controller。routing 違反ではないが語彙不統一。severity:
    minor。

#### Suggested rewrite(抜粋)

```ruby
# 1. welcome
resource :welcome, only: :show   # GET /welcome, welcome_path → WelcomesController#show
# helper 変更: welcome_entry_path → base_app_welcome_path (breaking: helper 名のみ)

# 2. preference emails — 手書き member route を撤去
namespace :preference do
  resources :emails, only: %i(edit update destroy)
  # 「この slot にこの email を設定」なら update (PATCH /preference/emails/:id)。
  # 本当に member への create が必要なら、それは選択行為なので
  #   resources :emails, only: %i(edit destroy) do
  #     resource :selection, only: :create, module: :emails   # POST /preference/emails/:id/selection
  #   end
end

# 3-4. well_known / oauth — 重複 get/post を削除し、verb resource を名詞化(path 不変)
namespace :well_known, path: ".well-known" do
  resource :openid_configuration, only: :show, path: "openid-configuration", controller: :discoveries, format: false
  resource :jwks, only: :show, path: "jwks.json", format: false
end
namespace :oauth do
  resource :authorization, only: :show,   path: "authorize", controller: :authorizations
  resource :token,         only: :create, controller: :tokens
  resource :userinfo,      only: :show,   controller: :userinfos   # path は OIDC 仕様固定 — compound 例外
  resource :revocation,    only: :create, path: "revoke", controller: :revocations
end

# 5. social authentication — verb POST を名詞 singleton に分解
namespace :social do
  namespace :authentication do
    resource :continuation, only: :create   # POST /social/authentication/continuation
    resource :completion,   only: :create   # POST /social/authentication/completion
  end
end
# controller: Social::Authentication::ContinuationsController#create / CompletionsController#create
# 旧 POST /social/authentication/continue|completion は breaking change。

# 7-8. withdrawal — custom action と別立て resource を統合
namespace :identity do
  resource :withdrawal, only: %i(new edit create update destroy)
  namespace :withdrawal do
    resource :session, only: %i(new create destroy)
    # DELETE /identity/withdrawal/session が旧 end_session。
    # 旧 DELETE /identity/withdrawal/session (delete :session) と path 互換。
  end
end

# 9. erasure status
namespace :privacy do
  resource :erasure, only: %i(new create)
  namespace :erasure do
    resource :status, only: :show   # GET /identity/privacy/erasure/status — path 互換
  end
end

# 10. session 削除 3 兄弟を revocation ひと家族に統合
namespace :identity do
  resources :sessions, only: %i(index show destroy)
  namespace :sessions do
    resource :revocation, only: :create   # POST /identity/sessions/revocation, params: scope=all|others
  end
end
# Revocations::AllsController / Revocations::OthersController / session_set / other_sessions を廃止し
# Sessions::RevocationsController#create 一本へ。breaking change(3 route 廃止)。

# 11. preference reset → 名詞
resource :customization, only: %i(edit destroy)   # DELETE = 全 preference を既定値へ
# もしくは resource :defaults の restore として resource :restoration, only: %i(new create)。
# 命名決定は要ユーザー確認。

# 13. group memberships
resources :groups, only: %i(index show create update destroy) do
  resources :memberships, only: %i(create update destroy), module: :groups
end
# Groups::MembershipsController。avatar 限定の membership であることは module 文脈で表現。
```

#### Naming review

- `welcome`(名詞・one-word)◎ / `selector` `switcher` は agent noun でやや実装臭 —
  `context`(表示中の作業文脈)等の domain noun を将来検討。minor。
- `session_set` `other_sessions` `withdrawal_session`: compound + 複数形 singleton。全廃し
  `sessions/revocation` と `withdrawal/session` へ。
- `check` `refresh` `reset` `revoke` `authorize`: 動詞群。→ `status` `renewal`
  `customization`(要検討) `revocation` `authorization`。
- `avatar_memberships` → `memberships` + `module: :groups`。

#### Exception review

- `.well-known/openid-configuration` / `jwks.json` / oauth の `authorize` `token` `userinfo`
  `revoke` path: RFC/OIDC Discovery 仕様固定。**path は例外、resource 名は名詞化する**。
- csp-violation-report: 対外契約(report-uri キャッシュ)。OK。
- net/dev host の health 系: infra。OK。

---

### config/routes/core.rb — Verdict: **WARN**

#### Problems

1. `resource :authorization, only: :show, to: "/core/app/auth/authorizations#show"`(core.rb:67-68 ほか)—
   resource に `to:` で絶対 controller path。`controller:` + `module:` で書くのが正道。severity:
   minor。
2. `namespace :token { resource :refresh, only: :create }`(core.rb:60 ほか)— `refresh` は動詞。→
   `resource :renewal, only: :create`(POST /api/v0/token/renewal)。severity:
   major(client 同期要、base/auth の edge API と同時に)。
3. `resource :sign_out, path: "sign/out"` — compound + verb 句。ceremony
   URL としてプロジェクト全体で固定済みなら例外(理由: 対外導線)。severity: minor。

#### Suggested rewrite

```ruby
namespace :oidc do
  scope module: :auth do
    resource :authorization, only: :show   # Core::App::Auth::AuthorizationsController#show
    resource :callback,      only: :show
  end
end
namespace :api do
  namespace :v0 do
    resource :session, only: :show
    namespace :token do
      resource :renewal, only: :create   # 旧 refresh。breaking change
    end
  end
end
```

#### Naming / Exception review

- `dbsc`: プロトコル固有名。例外 OK。
- health / robots / sitemap / csp: 例外 OK。
- それ以外は resource/resources のみで構成されており良好。

---

### config/routes/docs.rb — Verdict: **PASS**

- 全 route が `resource` / `resources` + namespace。custom get/post ゼロ。
- `resources :entries, param: :slug do resources :revisions, module: :entries end` — 1-level
  nest。revision は entry
  ID(slug)なしに列挙できないため親 ID 必須で nest 正当。module 指定で controller が
  `Entries::RevisionsController` になり shallow 相当の分離もできている。◎
- Naming: `entries` `revisions` — one-word 複数形名詞。◎
- Exception: health / csp のみ。妥当。
- 変更不要。

### config/routes/help.rb — Verdict: **PASS**

docs.rb と同型。指摘なし。ホストのリテラル列挙も本プロジェクトの宣言的 routes 方針どおり。

### config/routes/news.rb — Verdict: **PASS**

docs.rb と同型。「news の latest/popular を custom
action にしていない(index+query に寄せられる形)」点も方針適合。指摘なし。

### config/routes/info.rb — Verdict: **PASS**

- 全 route resourceful。`entries` のみで revisions なし(必要になったら docs 同型で)。
- 兄弟ファイルと違い robots/sitemap が無いが、routing 違反ではない(意図的なら OK。意図的でないなら別 issue)。

### config/routes/palm.rb — Verdict: **WARN**

#### Problems

1. **`namespace :oidc` が同一 scope 内に 2 回**(palm.rb:35-37 と 55-58)— 統合すべき。severity:
   minor。
2. `resource :sign_out, only: %i(show create)` — 兄弟サーフェス(core/side/base)は `new edit create`
   で、palm だけ
   `show create`。CRUD 語彙内ではあるが ceremony の action 語彙が surface 間で不統一。severity:
   minor。
3. resource への `to:` 指定(palm.rb:36, 57)— `controller:`/`module:` へ。severity: minor。

#### Suggested rewrite

```ruby
namespace :oidc do
  scope module: :auth do
    resource :authorization, only: :show
  end
  scope module: :oauth do
    resource :callback, only: :show
  end
end
```

### config/routes/side.rb — Verdict: **PASS**(minor 1 点)

- 全 route resourceful。custom get/post ゼロ。
- minor: oidc の `to:` 絶対 controller 指定 → `scope module: :auth` + `controller:`
  へ(palm と同じ)。挙動不変。

---

## 全体総評

### routing policy 違反一覧(重複除去後)

| #   | 違反                                                                                      | 場所                     | severity            |
| --- | ----------------------------------------------------------------------------------------- | ------------------------ | ------------------- |
| 1   | `get :welcome` custom route                                                               | base ×3 surfaces         | blocker             |
| 2   | preference emails の手書き member route(POST /:id → create)                               | base ×3                  | blocker             |
| 3   | social `authentications#continue` への custom get(sign/in, sign/up)                       | auth ×2, base ×1         | blocker             |
| 4   | social `resource :authentication do post :continue / :completion end`                     | base                     | blocker             |
| 5   | Entra `post :authorization; get :callback` custom member                                  | auth(org)                | blocker             |
| 6   | withdrawal `delete :session, action: :end_session`                                        | base ×2                  | blocker             |
| 7   | base routes → `/auth/app/...` controller の surface 越境                                  | base                     | blocker             |
| 8   | well_known / oauth の get+resource 二重定義                                               | base ×3                  | major               |
| 9   | verb resource: `authorize` `revoke` `check` `refresh` `reset`                             | base, auth, core         | major               |
| 10  | erasure `get :status` custom member                                                       | base ×2                  | major               |
| 11  | session 一括削除の 3 route 散乱(`session_set` / `other_sessions` / `sessions/revocation`) | base ×3                  | major               |
| 12  | compound noun: `withdrawal_session` `session_set` `avatar_memberships` `other_sessions`   | base                     | major/minor         |
| 13  | 前置詞 resource: `sign/up` `in` `out`                                                     | auth/base/core/palm/side | major(独立フェーズ) |
| 14  | `namespace :oidc` ×2 / `namespace :verification` ×2 の重複宣言                            | palm, auth               | minor               |
| 15  | `resources :iam/:system/:audit` 等の singleton 誤複数化                                   | auth(org), base(org)     | minor               |
| 16  | resource への `to:` 絶対 controller 指定                                                  | core, palm, side         | minor               |

### 置き換えるべき controller action 一覧

- `Social::AuthenticationsController#continue` → `Social::(Google|Apple)::SessionsController#new` /
  `RegistrationsController#new` + `Social::Authentication::ContinuationsController#create`
- `Social::AuthenticationsController#completion`(POST) →
  `Social::Authentication::CompletionsController#create`
- `Sign::In::EntrasController#authorization / #callback` →
  `Sign::In::Entra::AuthorizationsController#create` / `CallbacksController#show`
- `Identity::WithdrawalsController#end_session` → `Identity::Withdrawal::SessionsController#destroy`
- `Privacy::ErasuresController#status` → `Privacy::Erasure::StatusesController#show`
- `WelcomesController#show`(controller は現状のまま、route のみ resource 化)
- `Preference::EmailsController#create`(member POST) → `#update` または
  `Emails::SelectionsController#create`
- `Identity::Revocations::AllsController` / `OthersController` / `RevocationsController` →
  `Identity::Sessions::RevocationsController#create` に統合

### 新設すべき resource / controller

- `resource :welcome, only: :show`
- `namespace :social > namespace :(google|apple) > resource :session / :registration, only: :new`
- `namespace :authentication > resource :continuation / :completion, only: :create`
- `namespace :entra > resource :authorization, only: :create / resource :callback, only: :show`
- `namespace :withdrawal > resource :session`
- `namespace :erasure > resource :status, only: :show`
- `namespace :sessions > resource :revocation, only: :create`(scope param で all/others)
- `resource :status, only: :show`(edge token check の後継)/ `resource :renewal, only: :create`(token
  refresh の後継)
- `resource :authorization, path: "authorize"` / `resource :revocation, path: "revoke"`(oauth)

### 例外として残してよい route

- `root`、health 系(`/up` 相当の liveness/readiness/startup)、`robots.txt`、`sitemap.xml`
- `.well-known/openid-configuration`、`.well-known/jwks.json`(OIDC Discovery 仕様固定)
- `/oauth/authorize` `token` `userinfo` `revoke` の **path**(RFC 固定。resource 名だけ名詞化)
- `csp-violation-report`(report-uri は URL 不変の対外契約)
- OmniAuth `google/callback` / `apple/callback`(match get+post は Apple form_post 仕様)/ `failure`
- `dbsc`(プロトコル名)
- `sign/out` 等の ceremony path(対外導線として path 固定。resource 名の名詞化は Phase 7 扱い)

---

## Migration plan(実装フェーズ)

指定の順序に従う。**Phase 1-2 が本命、Phase 5 までで policy 違反ゼロ化、Phase 6 で検証。**

### Phase 1: 明らかな custom action を名詞 resource に分解

対象ファイル: `config/routes/base.rb`, `config/routes/auth.rb`

1. `get :welcome` → `resource :welcome, only: :show`(×3 surface)— **path 不変、helper 名のみ変更**
2. Entra custom member → `namespace :entra` + authorization/callback resource — **path 不変**
3. `resource :authentication { post :continue/:completion }` → continuation/completion resource —
   **URL 変更(breaking)**: フォーム/JS の POST 先を同時更新
4. withdrawal `delete :session` →
   `namespace :withdrawal > resource :session, only: %i(new create destroy)`、`resource :withdrawal_session`
   廃止 — **path 互換**
5. erasure `get :status` → `namespace :erasure > resource :status, only: :show` — **path 互換**
6. social `sign/in` `sign/up` custom get → provider namespace + session/registration resource —
   **URL 変更(breaking)**: メール/外部リンクに埋まっていないか要確認
7. well_known / oauth の重複 bare `get`/`post`
   を削除(resource 側へ一本化)し、旧 helper(`*_discovery_path`, `*_authorization_path`(get 版),
   `*_revocation_path`(post 版))の参照を全置換

### Phase 2: deep nested / 散乱 route を namespace に整理

対象: `config/routes/base.rb`

1. session 削除 3 route → `namespace :sessions > resource :revocation, only: :create`
   に統合(controller 統合含む)— **breaking**
2. `resources :avatar_memberships, controller: :group_avatar_memberships` →
   `resources :memberships, module: :groups`
3. avatars の follow/block/mute の `controller:` 手貼り → `module: :avatars`
4. palm の `namespace :oidc` ×2 統合、auth の `namespace :verification` ×2 統合

### Phase 3: singleton / collection の是正

1. org の `resources :iam/:system/:audit/:support/:billing, only: :index` →
   `resource :xxx, only: :show`(landing が単一画面である前提。collection 実体があるものは resources のまま index に統一)
2. `resource :other_sessions`(複数形 singleton)は Phase 2 の統合で消滅することを確認

### Phase 4: verb resource → noun resource(filter 系含む)

1. `edge > token > check` → `status`、`token > refresh` / api v0 `token > refresh` → `renewal` —
   **API breaking**: edge/client 側と同期リリース
2. oauth `resource :authorize` → `resource :authorization, path: "authorize"`、`resource :revoke` →
   `resource :revocation, path: "revoke"` — **path 不変**
3. preference `resource :reset` → 名詞化(候補: `customization` の destroy / `restoration`
   の create。**命名は実装前に確定**)
4. filter を custom
   action にしている route は今回ゼロ(docs/help/news が index+query 前提で既に正しい)

### Phase 5: external / infra route を例外として明文化

1. 例外 route(callback / well-known / csp / robots / sitemap / dbsc / oauth
   path)に「なぜ non-resourceful / path 固定か」の 1 行コメントを統一書式で付与
2. `sign/up|in|out` の前置詞 resource は今回スコープ外の独立 ADR 案件として `plans/backlog/`
   に切り出す(全 surface の URL・controller・view・テスト一斉変更のため)

### Phase 6: spec / helper 追随と検証

1. `bin/rails routes` の before/after diff を取り、削除・変更 route を一覧化
2. 変更 helper(`welcome_entry_path` ほか)を `grep` で全参照置換(view / controller / mailer / JS)
3. `bin/rails test test/routing` → 影響 surface の controller/integration test → `bin/rails test`
   全体
4. breaking URL(social continue、authentication continue/completion、token
   check/refresh、session 削除系)は対外 client・メール内リンク・OIDC
   RP 設定への影響を確認してからマージ

### 未確定事項(実装時に判断)

- preference emails の member POST の実際の意味(update 相当か selection 新設か)—
  controller 実装を読んで決定
- `resource :reset` の後継命名
- org 管理セクション(iam 等)が本当に単一画面か

## 検証方法

- `bin/rails routes | diff`
  で route 差分ゼロ確認(path 互換フェーズ)/意図した差分のみ確認(breaking フェーズ)
- ルーティング変更ごとに `.agents/harnesses/rules/generic/routing.mdc` / `project/surfaces.mdc`
  を再読
- `bin/rails db:verify_no_schema_drift` は不要(DB 変更なし)
