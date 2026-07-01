# Base RP テストに認証コンテキスト(JWT cookie)を注入する

## Context (背景)

`bin/rails test` で、`base/app`・`base/org`・`base/com` の Base RP 系コントローラテスト (accounts /
organizations / avatars / switchers(switcher) / organizations/memberships /
full_access_gate など)が失敗している。

原因は、これらのテストが「ログイン済み」のつもりで `as_user_headers` / `as_staff_headers` /
`as_visitor_headers` を使っているが、実際には **JWT access cookie を発行していない**
ため、コントローラの認証パイプラインが未認証と判断し `/oauth/authorize`
にリダイレクトしてしまう点にある。各ヘルパは `X-TEST-CURRENT-*` と `X-TEST-SESSION-PUBLIC-ID`
しかセットしておらず、実際の access token cookie が無い。

既に `Base::App::SelectorControllerTest`(`test/controllers/base/app/selector_controller_test.rb`) と
`Base::App::FullAccessGateTest`(`test/controllers/base/app/full_access_gate_test.rb`)は同じ問題を修正済みで、これらと同じパターンを他の Base
RP テストに横展開するのがゴール。

## 修正パターン

修正済みの selector テストで確立された 3 つの private ヘルパを各対象ファイルへ移植し、各
`as_*_headers` から JWT access cookie を発行・添付する。

対象アクターと `resource_type` の対応:

- Client → `"client"`
- Operator(staff)→ `"operator"`
- Visitor → `"visitor"`

issuer
id は host から自動導出する(`jwt_issuer_id_for_test_host`)ため、surface ごとに値を書き分ける必要はない(`surface:BASE_APP`
/ `BASE_ORG` / `BASE_COM` が自動選択される)。

### 1. 各ファイルに移植する共通ヘルパ

`test/controllers/base/app/selector_controller_test.rb` からそのまま移植:

- `jwt_access_token_for(resource, host:, session_id:, session_public_id:, resource_type:, dpop_jkt:)`
  (L389-407) — resource クラスから resource_type を自動判定し `AuthenticationToken.encode` を呼ぶ。
- `jwt_issuer_id_for_test_host(host, resource_type)` (L409-433) — host から `surface:BASE_*`
  を導出。
- `set_access_cookie(token)` (L760-762) — `cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token`。

対象ファイルに既存の同名ヘルパがある場合は重複定義しない。

### 2. 各 `as_*_headers` の修正

`X-TEST-SESSION-PUBLIC-ID` をセットしている箇所を、selector と同じ形に置き換える:

```ruby
token_public_id = session_public_id.presence || token.public_id
access_token = jwt_access_token_for(
  <resource>,
  host: host,
  session_public_id: token_public_id,
  resource_type: <"client" | "operator" | "visitor">,
)
set_access_cookie(access_token)
base["Cookie"] = [base["Cookie"], "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}"].compact.join("; ")
base["X-TEST-SESSION-PUBLIC-ID"] = token_public_id
```

- `as_user_headers` → resource は Client、resource_type `"client"`
- `as_staff_headers` → resource は Operator(staff)、resource_type `"operator"`
- `as_visitor_headers` → resource は Visitor、resource_type `"visitor"`

参照ヘルパの状態列(`user_token_status_id` / `binding_method` /
`dbsc_status`)は既存コードで既にセットされているものはそのまま利用。不足していて token 作成が失敗する場合は full_access_gate テストの
`ensure_user_token_reference_records!` (`test/controllers/base/app/full_access_gate_test.rb`
L108-113)と同じ `find_or_create_by!` パターンで参照レコードを補う。

### 注意: クラス再オープンの重複

対象ファイルは同名テストクラスを 3〜4 回再オープンし、同一の private ヘルパを重複定義している (DAMP 由来)。Ruby では最後の定義のみが有効になるため、動作上は最後のコピーだけ直せば足りるが、可読性・一貫性のため
**全コピーを同一に修正する**。共通ヘルパ(手順 1)は 1 ファイルにつき 1 回だけ定義されていれば良い。

## 対象ファイル

すべて `test/controllers/base/` 配下。app の selector / full_access_gate は修正済みなので除外。

- **base/app**: `accounts_controller_test.rb`, `avatars_controller_test.rb`,
  `organizations_controller_test.rb`, `organizations/memberships_controller_test.rb`,
  `switchers_controller_test.rb`
- **base/org**: `accounts_controller_test.rb`, `avatars_controller_test.rb`,
  `organizations_controller_test.rb`, `organizations/memberships_controller_test.rb`,
  `switcher_controller_test.rb`, `full_access_gate_test.rb` (`selector_controller_test.rb`
  は既に JWT 対応済みのため要確認のみ)
- **base/com**: `accounts_controller_test.rb`, `organizations_controller_test.rb`,
  `organizations/memberships_controller_test.rb`, `switcher_controller_test.rb`,
  `full_access_gate_test.rb`, `selector_controller_test.rb` (com には avatars テストは存在しない)

各 surface で「ログイン成功」を期待する主アクターは app=Client、org=Operator、com は混在。負のケース(誤ったアクターでアクセス→拒否を期待)のヘルパ呼び出しは cookie が付いても拒否されるため挙動は変わらないが、対称性のため全
`as_*_headers` を同じパターンで修正する。

## 検証

1. まず個別に対象ファイルを実行して緑を確認:
   ```bash
   bin/rails test test/controllers/base/app/accounts_controller_test.rb
   bin/rails test test/controllers/base/org/full_access_gate_test.rb
   # ... 各対象ファイル
   ```
2. Base RP テスト群をまとめて実行:
   ```bash
   bin/rails test test/controllers/base
   ```
3. 修正済みの selector / full_access_gate を含め回帰が無いことを確認。
4. `/oauth/authorize` へのリダイレクト(HTTP 302 で authorize へ飛ぶ失敗)が解消され、期待どおり 200
   / 期待ステータスになることを確認。

## メモ

- 実装は `AGENTS.md` の英語ポリシー対象(テスト名・コメント)に従う。新規コメントは英語で。
- 本タスクはテストのみの変更でアプリコードには触れない。
