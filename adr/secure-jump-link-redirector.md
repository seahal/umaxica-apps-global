# Secure Jump-Link Redirector (2026-04-27)

## Status

Accepted implementation note.

## Context

限定公開 URL をそのまま共有・転送すると、URL 自体が認可情報のように扱われる。とくにジャンプページやリダイレクトインターセプターを挟む設計では、次の問題が起きる。

- `destination_url` を query
  parameter に含めると、ジャンプ URL を見た第三者やログ閲覧者に秘匿 URL が抜かれる。
- Teams などの「アクセス制御のない限定公開 URL」は、URL を知っていることが実質的な権限になり、転送・ログ・Referer・ブラウザ履歴で漏えいしやすい。
- ジャンプ先 URL をレスポンス本文や Rails の通常ログに出すと、秘匿 URL を公開 URL 側の運用面へ持ち出してしまう。
- Cookie が付くドメインでジャンプを処理すると、不要な認証・セッション情報をジャンプ要求に同伴させることになる。

このため、公開されるジャンプ URL は秘匿情報を含まないランダムトークンだけにし、対応する宛先 URL、状態、権限情報、利用回数、失効時刻、削除可能時刻はサーバ側で管理する。

## Decision

ジャンプ URL は次の形式に限定する。

```text
GET /to/:public_id
```

`public_id` は Nanoid 21 文字の opaque identifier とし、公開 URL には `destination_url`
や権限情報を含めない。

TLD ごとにモデルとテーブルを 1:1 で分ける。

- `jump.example.app` -> `AppJumpLink` -> `app_jump_links`
- `jump.example.com` -> `ComJumpLink` -> `com_jump_links`
- `jump.example.org` -> `OrgJumpLink` -> `org_jump_links`

単一の polymorphic table は使わない。各テーブルは専用の `redirector` database connection に置く。

各レコードは次の運用情報を持つ。

- `destination_url`: サーバ側だけで管理する実際の遷移先
- `status_id`: `active`, `disabled`, `revoked` を integer constant で表す
- `revoked_at`: 期限・失効判定に使う。未失効は far-future sentinel
- `deletable_at`: retention 後の削除可能時刻。未設定時は far-future sentinel
- `max_uses` / `uses_count`: 使用回数制限。`max_uses = 0` は無制限
- `policy`: 将来の認可条件用 hook

`revoked_at` と `deletable_at` は nullable にせず、未設定状態を `Time.utc(9999, 12, 31, 23, 59, 59)`
で表す。

## Implemented Behavior

今回の実装では、共有モデル concern `JumpLinkable` に以下を集約した。

- `public_id` の Nanoid 生成
- far-future sentinel の補完
- integer constant による状態管理。Rails enum は使わない
- `active?`
- `available_for?(user:)`
- `revoke!`
- row lock による race-safe な `uses_count` increment

リダイレクト処理は `Jump::ToRedirector` controller concern に集約し、各 TLD
controller が明示的にモデルを指定する。

- `Jump::App::ToController::JUMP_LINK_MODEL = AppJumpLink`
- `Jump::Com::ToController::JUMP_LINK_MODEL = ComJumpLink`
- `Jump::Org::ToController::JUMP_LINK_MODEL = OrgJumpLink`

controller は `public_id` だけでレコードを探し、利用可能性チェックと利用回数加算を同一の row
lock 内で行う。利用不可、存在しない、または上限到達の場合は `404` を返す。

リダイレクト時は次を守る。

- `redirect_to destination_url, allow_other_host: true`
- `Referrer-Policy: no-referrer`
- Cookie session を skip
- 通常の redirect log line へ `destination_url` を出しにくくするため、redirect 呼び出しを logger
  silence 内で実行
- レスポンス本文に `destination_url` を出さない

## Tradeoffs

DB にレコードを持たせる設計は、単純な署名付き URL より運用コストが高い。ただし、次の要件を満たすにはサーバ側状態が必要になる。

- 宛先 URL を公開 URL に含めない
- 後から revoke できる
- `max_uses` を並行アクセス下でも超過させない
- 将来の policy / 認可条件を追加できる
- retention と削除可能時刻を明示できる

`deletable_at`
は初期実装では削除ジョブまで実装しないが、レコードのライフサイクルを DB スキーマに明示するため最初から持たせる。

## Follow-up

- 実ドメインでは Cookie を同伴しないジャンプ専用ドメインを使う。
- `policy` の評価内容を決めるまでは、hook は明示したまま常に許可にしておく。
- retention job / purge job は別途実装する。
- 実運用前に redirector DB の migration と CI を通す。
