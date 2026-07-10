# selector の配置コメント修正

## Context(なぜやるか)

`config/routes/acme.rb` の app surface に、selector
endpoint の配置に対する未解決の迷いコメントが残っている:

```ruby
# TODO: I have a question. I set this entrypoint at sign subdomain.
# Current actor/context selector.
resource :selector, only: %i(show update)
```

この「Sign
subdomain に置くべきか?」という問いは既に決着している。理由は ADR ではなく、設計の軸そのものから導ける:

- **真の surface 境界は「ログイン状態」ではなく「責務の種類」**:
  - Sign = **credential ceremony**(鍵 /
    authenticator を操作して所持を証明する)。logged-out のログインでも、logged-in の step-up でも起きる。
  - Acme = **identity / session /
    context の権威と発行**(誰として・どの文脈で・何を持つかを決めて発行する)。
- 証拠: step-up は Sign と Acme に割れている。`sign.rb` の `/verification/{passkey,totp,emails}`
  が authenticator の操作(ログイン済みでしか起きない → Sign は非ログイン専用ではない)、`acme.rb` の
  `/verification#completion` がその結果を session/token に grant する側。
- selector は credential を一切触らず、確立済み identity に対して「どの account /
  organization 文脈で actor を成立させるか」を選ぶだけ。これは context 解決 = **Acme の仕事**。
- 「selector は full
  access ほど認証を要らない」は別軸(認証 tier)の話で、surface 選択(Sign/Acme)とは直交する。コードは既に正しく
  `Acme::*::SelectorsController < PreAccessController` +
  `declare_authentication_mode! :private`(identity 認証済みだが context 未確定の中間状態)で実装済み。

結論: **コードの挙動・継承・配置は既に正しい**。直すべきは陳腐化したコメントだけ。実装(controller /
service / 継承 / 認証 tier)には一切手を入れない。

## 変更内容(コメントのみ)

対象は `config/routes/acme.rb` の 3 箇所。stale TODO を削除し、`# Current actor/context selector.`
を「identity 認証済み・context 選択前の pre-context
endpoint」と分かる表現に置換する。文言は英語(リポジトリ言語ポリシー)。

### app(44-46 行付近、`current_client`)

```ruby
# Context selector for the authenticated client: resolves which
# account/organization context the principal acts in. This is identity/session
# context resolution (Acme authority), not a credential ceremony (Sign), and it
# runs on the :private tier — identity-authenticated but context not yet selected.
resource :selector, only: %i(show update)
```

`# TODO: I have a question. I set this entrypoint at sign subdomain.` の行は削除する。

### com(250-251 行付近、`current_visitor`)

```ruby
# Context selector for the authenticated visitor: resolves which
# account/organization context the principal acts in. Identity/session context
# resolution (Acme authority), not a credential ceremony (Sign); runs on :private.
resource :selector, only: %i(show update)
```

### org(433-434 行付近、`current_operator`)

```ruby
# Context selector for the authenticated operator: resolves which
# account/organization context the principal acts in. Identity/session context
# resolution (Acme authority), not a credential ceremony (Sign); runs on :private.
resource :selector, only: %i(show update)
```

注: org の `selector_params` は現状 region(国)を permit していないため、コメントに `country-scoped`
とは書かない(コードと矛盾するコメントになる)。「国で account が変わる」構想は将来 selector_params に region を足す段階で、コメントもその時に更新する。本プランの範囲外。

## やらないこと

- controller の継承・`AUTHENTICATION_MODE`・before_action の変更(既に正しい)。
- selector を Sign へ移す(誤り。理由は上記 Context)。
- `PreContextController` のような新基底クラスの追加(等価物 `PreAccessController` + `:private`
  が既存。新規基底は shallow-nesting / structural-over-flags 方針にも反する)。
- step-up / verification の再配置。

## 検証

コメントのみの変更だが、routes が壊れていないことだけ確認する:

```bash
bin/rails routes -g selector
```

3 surface(acme_app / acme_com / acme_org)の `selector#show` と `selector#update`
が従来通り出力されれば OK。挙動・テスト結果に影響は無い。
