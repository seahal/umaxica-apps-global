# config/routes 整理 — 記事思想（resource CRUD 化 + コメント事実化）

## Context（なぜやるか）

`config/routes/` には `FIXME` / `TODO` / `wtf` が散在する。これはバグ報告ではなく、作者自身の
**「まだ素直に書けていない」という自己ツッコミ**である。作者は techracho「Railsのルーティングを極める（後編）」(https://techracho.bpsinc.jp/baba/2020_11_20/15619) に影響を受けている。記事の核は2つ:

1. **素直・統一**: アドホックなカスタムルーティングを避け、`resources`/`resource` + `only`/`except`
   の標準CRUDで宣言的に書く。
2. **頑張り過ぎない**: RESTful に固執しない。プロトコル/プロバイダ都合の逸脱は事実として許容する。

本計画のゴールは、**手書きの
`get`/`post`/member/collection ルートを可能な限り resource(s) の CRUD 表現へ寄せ**、残る逸脱は感情コメントでなく事実コメント（`# keep protocol path`
型）へ書き換えること。

**重要な発見: CRUD化の理想形はこのリポジトリ内に既に存在する。**

- `config/routes/auth.rb:188-190` …
  `namespace :verification do resource :cancellation, only: :create end` ＝ base.rb の
  `post :cancellation`（手書き member）が目指すべき姿。
- `config/routes/info.rb` … `namespace :api do namespace :v0`
  ＝ 手書きAPIの理想形。既存の正解パターンを他所へ横展開するのが本計画の骨子。

## スコープ（ユーザー確定）

- **含む**: (1) 非CRUDルートの resource(s)
  CRUD 化、(2) 感情コメント→事実コメント化、(3) ホスト解決 lambda の宣言的ヘルパ抽出（A）。
- **保留（C は今回やらない）**: `web`/`edge` → `api`
  統合は作者が方針検討中のため触れない。コメントも現状維持（不用意に書き換えない）。
- **据え置き（頑張り過ぎない）**: プロトコル/プロバイダ固定パスは CRUD 化しない。対象例:
  `openid-configuration`(OIDC Discovery), `authorize`/`revoke`(OAuth), `jwks.json`, `robots.txt`,
  `sitemap.xml`, social の `google/callback`/`apple/callback` (プロバイダ側に登録された固定 redirect
  URI, `omniauth`)。これらは事実コメントで肯定する。

### 挙動の扱い（URL 不変・helper 改名は追従修正）

CRUD 化は URL を変えずに実施することを原則とする（例: `post :completion` on `resource :verification`
と `namespace :verification { resource :completion, only: :create }` は同一 URL
`POST /verification/completion`）。その代わり **path
helper 名は変わりうる**。helper 改名は参照側（views/controllers/mailers/テスト、cross-service
URL 構築）を同一変更内で追従修正する。URL を変えざるを得ない候補（下記★）は個別に是非を判断し、必要なら別チケットへ退避する。

## 作業1: 非CRUD → resource CRUD 化（今回の主作業）

grep で洗い出した手書きルートを、既存の CRUD 理想形へ寄せる。

### 1-a. verification の member post（base.rb:117-120, 306-309, 517-520 の app/com/org）

現状 `resource :verification, only: :show do; post :completion; post :cancellation; end` を、
`auth.rb:188-190` と同型の `resource :verification, only: :show` +
`namespace :verification do resource :completion, only: :create; resource :cancellation, only: :create end`
へ。URL 不変、helper が `*_completion` 系へ変わる。

### 1-b. sign/out の collection get（base/core/side/auth の各サーフェス）

`get :complete, on: :collection` を、singular 子リソース
`resource :out, only: %i(new edit create) do; resource :completion, only: :show; end`（path で URL 維持）等へ寄せる。※
`scope path: :sign, module: :sign` ラッパ（base.rb:184,394,605）は
`as:`/module 目的の手続き。namespace 化できるか検証（作者の `# FIXME: Remove :sign and :as`
に対応）。★URL/helper 影響あり、差分をレビューして確定。

### 1-c. social authentications の member post（base.rb:153-158）

`post :continue, on: :member` / `post :completion, on: :member` を、
`resources :authentications do; resource :continuation, only: :create; resource :completion, only: :create; end`
形へ寄せられるか検証。★member param 構造が変わるため差分確認必須。

### 1-d. support session の delete member（base.rb:485-512, clients/visitors/operators ×3）

`resource :session do; delete :purge; delete :emergency_revoke; end` を、
`resource :session, only: :destroy`（purge）+ `resource :emergency_revocation, only: :destroy`
等の CRUD 表現へ寄せられるか検証。★HTTP 動詞/URL を保つ形を優先。

### 1-e. `post "emails/:id"`（base.rb:93, 342, 553 の preference/emails）

完全手書きの `post "emails/:id", to: "emails#create"`。★create に `:id` を取る変則形。
`resources :emails`
の CRUD に寄せられるか、無理なら「なぜ id 付き create か」を事実コメント化。挙動が微妙なので慎重に（URL 変更は別チケット候補）。

## 作業2: コメントの事実化（B/D/E, 挙動不変）

感情語（`wtf`, `I cannot agree`, `I want to`, `Check controller code`）を排除し、
`# keep protocol path` 型の事実 + 制約 + 理由コメントへ統一する。

- **D**: base.rb:436-438 `wtf discovery?` →
  `# OIDC discovery endpoint; spec-fixed path/name, do not rename.`
- **B（据え置く逸脱）**: `to:`/`as:`/`path:` のうち CRUD 化・改名しないものは、理由（コントローラが
  `auth/` サブモジュール / cross-service URL 都合 / 対外互換の旧名）を事実コメント化。対象:
  base.rb:108, 146-147, 162-163, 209-210, 404。
- **E（未監査）**: base.rb:216,221,231-235,482 /
  auth.rb:211,568 の TODO は、該当コントローラを実読し「何のためのルートか」を事実コメント化。`ceche`(auth.rb:211) は
  `cache` の typo 修正。削除が妥当なものは別チケット提案（今回は消さない）。

## 作業3: ホスト解決 lambda の宣言的ヘルパ抽出（A, 挙動不変）

`base.rb:6-24` の `base_route_host`/`base_route_hosts` lambda を `lib/routing_host_resolver.rb`
（既存 `lib/config_values_host_family_values.rb` / `lib/jit_host_origin_env.rb`
の型に合わせる）へ抽出。 `base.rb` は `RoutingHostResolver.hosts(...)` を呼ぶだけにし、lambda と
`FIXME` を削除。auth/palm/side/info/help の `boot_config`/`hosts`
ローカル束縛は、同ヘルパへ寄せるか最低限 `FIXME` を外して事実コメント化。抽出前後で
`constraints host:` の配列が完全一致することを担保。

## コメント文体の統一ルール（記事準拠）

- 1行・宣言的・事実ベース。感情語を排除。
- CRUD 化しない逸脱は必ず**理由**を書く（プロトコル固定 / プロバイダ固定 / 対外互換 / モジュール都合）。
- リポジトリ言語ポリシー: コメント・識別子は英語。本計画書は日本語（ユーザー方針）。

## 今回やらないこと

- C: `web`/`edge` → `api` 統合（作者が方針検討中）。コメントも据え置き。
- ★印の URL 変更を伴う変換のうち、参照側影響が大きいと判明したもの → `plans/backlog/` へ起票。
- 未監査ルートの削除。

## 検証（Verification）

1. **ルート差分レビュー**（今回は「差分ゼロ」ではなく「意図した差分のみ」を確認）:
   - 変更前後で `bin/rails routes` を採取し diff。
   - CRUD 化した行は **URL(verb+path) が不変**、helper 名のみ変化していることを1件ずつ確認。
   - コメント化・ヘルパ抽出（作業2,3）由来の行は差分ゼロであること。
2. `bin/rails runner 'Rails.application.reload_routes!'` がエラーなくロードできること。
3. helper 改名の参照追従漏れ検出: `grep -rn "<old_helper>_path\|<old_helper>_url" app test`
   で 0 件を確認してから確定。
4. テスト:
   - `bin/rails test test/integration/cross_surface_isolation_test.rb`
   - `bin/rails test test/integration/oidc_rp_browser_flow_test.rb`
   - 変換した各リソースのコントローラ/リクエストテストが緑であること。

## 主要参照（in-repo の理想形）

- verification CRUD 形: `config/routes/auth.rb:188-190`。
- api 形（C の将来参照のみ）: `config/routes/info.rb`。
- 正解コメント: base.rb の `# ... keep protocol path`（jwks.json/authorize/revoke 等）。
- ヘルパ命名の型: `lib/config_values_host_family_values.rb`, `lib/jit_host_origin_env.rb`。
- social 据え置き根拠: `config/routes/auth.rb:142-184`（プロバイダ固定 callback / omniauth）。
