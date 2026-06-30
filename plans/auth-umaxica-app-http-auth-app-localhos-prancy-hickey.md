# compose.yaml: frontend ネットワークエイリアスにプライベートホスト名を追加

## Context

Cloudflare トンネルは各パブリックホスト名をプライベートホスト名（`auth.app.localhost:3000`
など）へルーティングしている。 `cloudflare-tunnel` コンテナと `core` コンテナは同じ `frontend`
ネットワークに属しているが、 `core` サービスのネットワークエイリアスに `auth.app.localhost` /
`base.app.localhost` / `core.app.localhost`
等が存在しないため、トンネルコンテナが名前解決に失敗して接続できない。

`info.app.localhost` / `info.com.localhost` / `info.org.localhost`
だけはエイリアスに登録されており、これが `info.umaxica.*` だけ繋がる理由。

## 変更ファイル

`compose.yaml` — `core` サービスの `networks.frontend.aliases`
に不足しているプライベートホスト名を追加。

## 追加するエイリアス

トンネル設定と `PRIVATE_*` 環境変数（compose.yaml 内に既に定義済み）に合わせて以下を追加する：

| サービス   | 追加するエイリアス                                               |
| ---------- | ---------------------------------------------------------------- |
| auth       | `auth.app.localhost`, `auth.com.localhost`, `auth.org.localhost` |
| base (www) | `base.app.localhost`, `base.com.localhost`, `base.org.localhost` |
| core (jpx) | `core.app.localhost`, `core.com.localhost`, `core.org.localhost` |
| side       | `side.app.localhost`, `side.com.localhost`, `side.org.localhost` |
| palm       | `palm.app.localhost`                                             |

追加場所は既存の `- info.app.localhost` などと並べて `aliases:` ブロックに追記する。

## Rails ルーティングへの影響

なし。Cloudflare トンネルはプライベートホストへ接続する際も `Host: auth.umaxica.app`
など元のパブリックホスト名をそのまま転送するため、Rails の
`constraints host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL")` は変更不要。

## 確認方法

1. `docker compose up -d` でコンテナを再起動
2. ブラウザで `https://auth.umaxica.app` にアクセスして疎通確認
3. 同様に `https://jpx.umaxica.app`（core）/ `https://www.umaxica.app`（base）を確認
