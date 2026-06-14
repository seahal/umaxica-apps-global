# /health 系エントリーポイントのエッジ遮断と内部専用化(決定の明文化)

## Context(背景)

`/health` 系エンドポイント(`/health`, `/health/liveness`, `/health/readiness`,
`/health/startup`)は現在、全サーフェス(acme/base/core/sign/docs/help/news/palm ×
app/com/org、計98ルート)で `BareController`
継承・認証なしで公開されている。`docs/operations/health-check.md` はこれらを "public health
endpoints" と記述している。

しかしこれらは本来、オーケストレータ/監視プローブ向けの内部チェックポイントであり、エンドユーザーが直接見るものではない。生のプローブ JSON や HTML スナップショットを利用者に晒すと、(1)
SSoT が曖昧になり、(2) 部分的な内部状態を見たユーザーが混乱する、(3) 内部トポロジの偵察面が増える。

決定: `/health`
とその配下すべてを「エッジ(CDN/LB)で公開遮断する内部専用チェックポイント」と位置づける。エッジは Cloudflare
Tunnel(`compose.yaml`)であり、liveness/readiness/startup などの内部プローブはオーケストレータがオリジン内部から直接叩くため、エッジ遮断の影響を受けない。利用者向けの可用性情報は、単一の「統合ステータスページ」(外部サービス。本リポジトリのスコープ外)を SSoT として案内する。

本タスクのスコープ(ユーザー確認済み): **コード変更は行わず、ADR と docs による決定の明文化のみ。**
統合ステータスページの実装と、Cloudflare 側の実設定(ダッシュボード/IaC)はリポジトリ外で別途行う。Rails 側の多層防御ガードは今回は対象外(将来の検討事項として記録のみ)。

> 言語(確定): コミット対象である ADR・docs はすべて**英語**で記述する(`AGENTS.md` Repository
> Language Policy および `adr/README.md`「Write ADRs in
> English」に準拠。ユーザー確認済み)。本計画ファイル(`plans/`)のみ作業用に日本語のまま残す。

## 関連調査結果(根拠)

- エッジ = Cloudflare Tunnel(`compose.yaml` の `cloudflare-tunnel`
  サービス)。リポジトリ内に nginx/Caddy/Workers/WAF/Ingress 等のエッジ設定ファイルは存在しない → 実設定は Cloudflare 側。
- ヘルスコントローラは全て `BareController` 継承・IP 制限/認証なし。
- 内部プローブ(liveness/readiness/startup)はオリジン直通で消費されるため、エッジ遮断で壊れない。
- ユーザー向けステータスページは未実装・未計画(新規の設計判断)。
- 既存の関連ドキュメント: `docs/operations/health-check.md`, `docs/reference/health-endpoints.md`,
  `docs/security/observability-boundary.md`。
- 既存の関連 ADR: `adr/application-logging-boundary.md`,
  `adr/traces-and-metrics-routing-via-alloy.md`(オブザーバビリティ境界)。

## 成果物

### 1. 新規 ADR: `adr/internal-health-endpoint-edge-isolation.md`

体裁は既存 ADR(例: `adr/application-logging-boundary.md`)に合わせ、`Accepted: 2026-06-14` /
`## Context` / `## Decision` / `## Consequences` / `## Related` 構成とする。記述内容:

- **Context**: 現状 `/health*`
  は全サーフェスで認証なし公開。内部プローブと利用者向け可用性情報が未分離で、SSoT 不在・ユーザー混乱・偵察面増のリスク。
- **Decision**:
  - `/health` および配下すべて(`/health/liveness`, `/health/readiness`,
    `/health/startup`)を全サーフェスで「内部専用チェックポイント」と定義する。
  - これらは Cloudflare エッジ(CDN/LB 相当)で公開トラフィックに対して遮断する。内部プローブはオリジン内部から到達するため遮断対象外。
  - 利用者向けの可用性・障害情報は、単一の統合ステータスページ(外部サービス。リポジトリ外)をSSoT として案内する。アプリ内に利用者向けステータス表示は設けない。
  - エッジの実設定は Cloudflare 側で管理する(本リポジトリでは設定ファイルを持たない)。
- **Consequences / Tradeoffs**:
  - エッジ設定がリポジトリ外にあるため、遮断ルールはコードレビュー対象外。docs に手順と対象パスを明記して追跡可能にする。
  - アプリ層での強制(多層防御ガード)は今回入れない。オリジンが Tunnel 背後で公開到達不能であることを前提に、エッジ遮断のみで十分とする。将来オリジン直接到達経路が増える場合は Rails 層ガードを再検討する(notes へ記録)。
  - `docs/operations/health-check.md` の "public health endpoints" 表現は内部専用へ更新が必要。
- **Related**: 上記 docs / observability-boundary / health-check。

`adr/README.md` の「Current logging / observability
decisions」付近(または新設の運用/エッジ節)に新 ADR への参照行を1行追加する。

### 2. `docs/operations/health-check.md` の更新

- 冒頭の "current public health endpoints" を「内部専用(エッジで公開遮断)」の趣旨へ書き換える。
- 新セクション「Edge Access Policy(エッジアクセス方針)」を追加:
  - `/health` 配下すべてが Cloudflare エッジで公開遮断対象であること。
  - 内部プローブ(liveness/readiness/startup)はオリジン内部から到達し遮断の影響を受けないこと。
  - エッジ遮断の対象パス一覧と、Cloudflare 側で設定すべきルールの説明(設定自体はリポジトリ外)。
  - 利用者向け可用性情報は統合ステータスページ(外部サービス)を参照する旨と、新 ADR へのリンク。

### 3. `docs/reference/health-endpoints.md` の更新

- これらが内部専用契約であり、利用者向けではない旨の注記を追加。利用者向けは統合ステータスページ。

## 検証(コード変更なしのため)

- `bin/rails routes | grep health` などで既存ルートに変更がない(削除/追加なし)ことを確認。
- ドキュメント内のクロスリンク(ADR ↔ docs)が双方向に正しいことを目視確認。
- `adr/README.md` の参照行追加が他項目の体裁と一致していることを確認。
- 既存テスト(`test/integration/health_endpoints_test.rb`,
  `test/integration/edge_health_routes_test.rb`)が引き続き green であること(挙動不変の確認)。

## スコープ外(別タスク)

- 統合ステータスページ(外部サービス)の実装。
- Cloudflare 側の実遮断設定(ダッシュボード/IaC)。
- Rails 層の多層防御ガード(将来検討。必要なら `notes/` へ前提を記録)。
