# Plan: ADR + Docs — org docs/help/info/news サーフェスへの Cloudflare Access 認証レイヤー

## Context

org サーフェスのうち **docs・help・info・news**
の 4 サブサーフェスは、将来 Next.js フロントエンドを被せる予定の読み取り専用コンテンツ配信エリアである。これらのエンドポイントに "スタッフのみアクセス可" という制約を設けたいが、Acme/Sign セレモニー +
Operator セッションという本格認証フローを組むのは過剰であり、自前 IdP や管理画面を持つコストも高い。

すでに Cloudflare Tunnel がエッジとして稼働しているため、Cloudflare Access (Zero
Trust) を edge レベルの認証ゲートとして被せることで実装・運用コストを抑える判断をした。IdP は Cloudflare
Access の連携機能（Google Workspace 等）を使い、自前でホストしない。

**その他の org サーフェス（auth・base・core）は対象外。**
これらは app/com と同様に Acme/Sign セレモニー +
Operator セッション認証が必要であり、引き続き既存の認証パイプライン（`authenticate_operator!`
等）を使用する。

既存 ADR `adr/internal-health-endpoint-edge-isolation.md`
で確立した「edge 設定は Cloudflare 側が source of
truth」「policy は docs に記録」パターンを踏襲する。

## What to create / update

### 1. `adr/org-cloudflare-access-authentication-layer.md` (新規)

ADR の構成：

- **Accepted**: 2026-06-29
- **Context**
  - org の docs/help/info/news は読み取り専用コンテンツ配信。Next.js フロントを被せる計画がある
  - これらのパスに "org スタッフのみ到達可能" という制約が必要
  - Acme/Sign セレモニー + Operator セッションは過剰。自前 IdP・管理画面を持つコストも高い
  - Cloudflare Tunnel はすでに全サーフェスのエッジとして稼働中
  - Cloudflare Access の IdP 連携（Google Workspace 等）で Identity Provider 調達も解決できる
- **Decision**
  1. **適用対象**: org サーフェスの docs・help・info・news パス（`/docs/*`, `/help/*`, `/info/*`,
     `/news/*`）に Cloudflare Access (Zero Trust) を edge 認証ゲートとして設定する
  2. Cloudflare Access の identity provider 連携を使う。IdP を自前でホストしない
  3. Cloudflare Access を通過したリクエストには `CF-Access-Jwt-Assertion`
     ヘッダーが付与される。Next.js / Rails origin では必要に応じてこの JWT を信頼検証する
  4. edge ルール設定は Cloudflare 側が source of truth。対象パスと意図を
     `docs/security/cloudflare-access-org-authentication.md` に記録する
  5. **適用外**: org の auth・base・core サーフェスは Cloudflare
     Access を適用しない。これらは app/com と同様に Acme/Sign セレモニー +
     Operator セッション認証を使用する
- **Consequences**
  - docs/help/info/news へのスタッフアクセス制御が PaaS に委ねられる。Cloudflare の SLA・障害がこれらサーフェスのアクセス可否に影響する
  - IdP 設定変更は Cloudflare ダッシュボードで行い、コードレビューを経ない。docs がポリシーのトレーサビリティ担保手段となる
  - Rails 層のコード変更は最小（CF
    JWT 検証ヘルパーの追加のみ。必要な場合）。Operator セッション発行ロジックは触らない
  - auth/base/core の認証パイプラインはこの決定で変更されない
- **Related**
  - `adr/internal-health-endpoint-edge-isolation.md`
  - `adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md`
  - `adr/read-only-content-surfaces-in-rails.md`
  - `docs/security/cloudflare-access-org-authentication.md`（新規）

### 2. `docs/security/cloudflare-access-org-authentication.md` (新規)

Docs の構成：

- 概要：Cloudflare Access が org docs/help/info/news の edge 認証ゲートであること
- 適用対象パス一覧（`/docs/*`, `/help/*`, `/info/*`, `/news/*` on org）
- 適用対象外の明示（auth/base/core は通常の Operator セッション認証を使用）
- 認証フロー：ブラウザ → Cloudflare Access → IdP 認証 → CF-Access-JWT 付与 → origin 到達
- Rails/Next.js 側での JWT 検証方法（`CF-Access-Jwt-Assertion` ヘッダー、公開鍵 certs endpoint）
- IdP 連携：使用する identity provider と設定場所（Cloudflare ダッシュボード）
- 運用注意事項：設定変更の場所、ローカル開発でのバイパス方法

### 3. `adr/README.md` の更新

"Current health / edge access decisions" セクションに追記：

```
- `adr/org-cloudflare-access-authentication-layer.md` — org の docs/help/info/news パスに
  Cloudflare Access (Zero Trust) を edge 認証ゲートとして採用する決定。
  auth/base/core は引き続き Acme/Sign セレモニー + Operator セッション認証を使用する。
```

### 4. `docs/index.md` の更新

security/ セクションに参照を追記。

## Sequence

1. `adr/org-cloudflare-access-authentication-layer.md` 新規作成
2. `docs/security/cloudflare-access-org-authentication.md` 新規作成
3. `adr/README.md` に 1-liner 追加
4. `docs/index.md` に参照追加

Rails コードの変更なし（CF JWT 検証ヘルパー実装は別途 plan / ADR で扱う）。

## 確認すること

特になし。ADR + Docs の文書化のみ。
