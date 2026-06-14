# palm エンドポイントを app サーフェスのみに限定する

## 現況（2026-06-14 実装確認）

本タスクの実装は**すでに作業ツリーに適用済み**であることを確認した。残作業は検証（テスト実行）とルートファイルの軽微な整形のみ。静的検証結果:

- ルート `config/routes/palm.rb`:
  com/org ブロック削除済み、app ブロックのみ残存（21 行目に余分な空行が1つ残る → 整形対象）。
- コントローラ/ビュー: `app/controllers/palm/{com,org}/` と `app/views/palm/{com,org}/` は git 上
  `D`（削除済み）。`palm/app` は維持。
- テスト: 4ファイルとも `palm_com_*` / `palm_org_*` 参照は消え、`palm_app_*`
  のみ残存（grep 確認済み）。
- `config/application.rb`: `PALM_SERVICE_URL` のみ、`PALM_CORPORATE_URL` / `PALM_STAFF_URL`
  は削除済み。
- `compose.yaml`: `palm.jp.umaxica.app` のみ、com/org エイリアス削除済み。
- locale 4ファイル: `palm.app` のみ、`palm.com` / `palm.org` キーなし。
- `Health::Profiles::Com` / `Health::Profiles::Org` は他サーフェス共有のため維持（正しい）。
- ハンドオフノート `notes/implementation/2026-06-14-palm-app-only.md` 作成済み。

リポジトリ全体で `palm_com|palm_org|palm/com|palm/org|PALM_CORPORATE_URL|PALM_STAFF_URL`
の参照は**ゼロ**。

### 残作業

1. `config/routes/palm.rb` 末尾（19–21 行）の余分な空行を1つ削除（`end` の直前）。任意・軽微。
2. テストスイートの実行（実装ノートでは DB ホスト `primary`
   未解決で未実行）。下記「検証」を実行し結果を報告する。

以降は当初プラン（実装手順）。実装済みのため参照用に残す。

---

## Context（背景・目的）

palm サーフェスはネイティブ / ハンドヘルドクライアント向けの bearer-token
API（ブラウザ向け UI ではない）。ネイティブアプリは `app` オーディエンスにしか作らないため、
`com`（コーポレート）と `org`（スタッフ）に palm を持つ意味がない。

現状、palm は `app` / `com` / `org`
の3サーフェスに**完全に同一実装**されている（ルート・コントローラ・ビュー・テスト・locale すべて triple）。本変更で
`com` / `org` を撤去し、 `app` のみ残す。

この方針は `plans/objective-grill-the-twinkly-pascal.md`（palm のスコープは app-audience
only、com/org native は out of scope）とも整合する。

### 既存決定との矛盾（要・明示）

`plans/active/surface-routing-controller-pass-base-palm-help-docs-news.md` は「Palm as app/com/org
triples … decision so far: yes, uniform
triples」と明示的に 3サーフェス均一を決定している。本変更はユーザーの明示指示によりこの決定を覆す。当該プランの記述を「palm は app-only」に更新する（下記参照）。

撤去の前例は `acme` の avatar（app/org のみ、com には存在しない）と同じパターン:
**ルートからリソースを省き、サーフェス固有のコントローラ/ビューのディレクトリを削除する**。

## 変更内容

### 1. ルート定義から com / org ブロックを削除

`config/routes/palm.rb`:

- `# Corporate native API surface`
  ブロック（`constraints host: ENV["PALM_CORPORATE_URL"]`、現 22–35 行）を削除
- `# Staff native API surface`
  ブロック（`constraints host: ENV["PALM_STAFF_URL"]`、現 37–51 行）を削除
- `app` ブロック（`PALM_SERVICE_URL`、5–19 行）のみ残す

### 2. コントローラ削除

ディレクトリごと削除:

- `app/controllers/palm/com/`（`bare_controller.rb`, `roots_controller.rb`, `healths_controller.rb`,
  `robots_controller.rb`, `sitemaps_controller.rb`, `csp_violation_reports_controller.rb`,
  `health/livenesses_controller.rb`, `health/readinesses_controller.rb`,
  `health/startups_controller.rb`）
- `app/controllers/palm/org/`（同一の9ファイル）

`app/controllers/palm/app/` は残す。

### 3. ビュー削除

- `app/views/palm/com/sitemaps/show.xml.builder`
- `app/views/palm/org/sitemaps/show.xml.builder`

`app/views/palm/app/sitemaps/show.xml.builder` は残す。

### 4. テスト更新（palm app のカバレッジは維持し、com/org エントリだけ除去）

- `test/integration/read_only_surfaces_test.rb` `STATIC_SURFACES` から `palm_com_root_url`
  行（12）と `palm_org_root_url` 行（13）を削除。 `palm_app_root_url`（11）は残す。
- `test/integration/health_endpoints_test.rb` `SURFACES` 配列から `palm/com/healths`
  ブロック（104–111）と `palm/org/healths` ブロック（112–119）を削除。 `palm/app/healths`
  ブロック（96–103）は残す。
- `test/controllers/public_robots_routing_test.rb`
  - `"base and palm surfaces define public file helpers"`（21–32）から `palm_com_robot_path` /
    `palm_org_robot_path` / `palm_com_sitemap_path` / `palm_org_sitemap_path` を除去、 `palm_app_*`
    は残す。
  - `"public file endpoints respond without redirect"`（44–85）の `endpoints` から
    `palm_com_robot_url` / `palm_org_robot_url`（50–51）と `palm_com_sitemap_url` /
    `palm_org_sitemap_url`（56–57）を削除。`palm_app_*`（49, 55）は残す。
- `test/controllers/csp_violation_reports_controller_test.rb` `csp_report_cases`（44–73）から
  `:palm_com_csp_violation_report_path`（61）と
  `:palm_org_csp_violation_report_path`（62）を削除。`:palm_app_csp_violation_report_path`（60）は残す。

### 5. 設定・locale クリーンアップ

- `config/application.rb`（138, 140 行）: `PALM_CORPORATE_URL` / `PALM_STAFF_URL`
  のデフォルトを削除。 `PALM_SERVICE_URL`（139）は残す。
- `compose.yaml`（54–55 行）: ホストエイリアス `palm.jp.umaxica.com` / `palm.jp.umaxica.org`
  を削除。 `palm.jp.umaxica.app`（53）は残す。
- locale: `palm.com.roots.message` / `palm.org.roots.message` を以下4ファイルから削除し、
  `palm.app.roots.message` のみ残す: `config/locales/jp/en.yml`, `config/locales/us/en.yml`,
  `config/locales/jp/ja.yml`, `config/locales/us/ja.yml`。

注意: `Health::Profiles::Com` / `Health::Profiles::Org`
は他サーフェス（base/help/docs/news 等）と共有のため**削除しない**。

### 6. ドキュメント更新

- `plans/active/surface-routing-controller-pass-base-palm-help-docs-news.md`:「Palm uniform
  triples（app/com/org）」の記述を「palm は app-only」に更新し、撤去の決定理由（ネイティブクライアントは app-audience のみ）を1行残す。
- `notes/implementation/2026-06-13-base-palm-sitemap-endpoints.md`:
  palm の sitemap は app のみになった旨を追記（base は3サーフェス維持）。
- 必要なら `notes/implementation/`
  に本変更のハンドオフノート（uniform-triples 決定を覆した経緯）を1本追加。

## 検証

```bash
# ルート確認: palm_com_* / palm_org_* が消え、palm_app_* が残ること
bin/rails routes | grep palm

# 影響テスト（最も狭い順）
bin/rails test test/controllers/public_robots_routing_test.rb \
               test/controllers/csp_violation_reports_controller_test.rb \
               test/integration/read_only_surfaces_test.rb \
               test/integration/health_endpoints_test.rb

# サーフェス境界に触れるため広めに
bin/rails test
```

- `bin/rails routes | grep palm` の出力に `palm_com_*` / `palm_org_*` が現れず、 `palm_app_root` /
  `palm_app_health` / `palm_app_robot` / `palm_app_sitemap` / `palm_app_csp_violation_report`
  が残ること。
- 削除した com/org コントローラへの未解決参照が
  `grep -rn "palm/com\|palm/org\|palm_com\|palm_org" app test config` で検出されないこと。
- 全テストグリーン。実行できなかったテストがあれば報告する。
