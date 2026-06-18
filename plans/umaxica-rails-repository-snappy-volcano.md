# Docs / Help / News 接続設計の ADR / memo 記録 — 既存ファイル確認

## Context

ユーザーは、Docs / Help / News surface に content-attached discussion, moderation,
notification を接続する設計方針を ADR と memo に記録するよう指示した。Rails は API contract / policy
/ event / state を担い、UI/UX は Next.js が担当するという責務分離を、Discourse (discussion attached
to content, trust level, moderation, flagging, notification granularity) と Forem / DEV.to
(tag-driven discovery, profile vs identity separation) からの参照ポイントとともに残す必要があった。

実装差分は不要 (model / migration / route / controller / view / Next.js を変更しない)。

## 調査結果

既存リポジトリには、本タスクの要件を完全に満たすドキュメントが昨日付 (2026-06-16) で既に存在している。

- ADR: `adr/docs-help-news-discussion-moderation-notification.md`
- memo: `memos/2026-06-16-claude-content-discussion-profile-feed-boundary.md`

ユーザー指示の各項目と既存ファイルの対応:

### ADR 側 (全項目カバー済)

- Context: Docs / Help / News の現状 (`adr/read-only-content-surfaces-in-rails.md`,
  `adr/news-is-timeline.md`, `docs/architecture/docs-help-news-content-boundary.md` 参照)、Discourse
  / Forem からの参照、Forem clone / full SNS は範囲外。
- Decision 1〜10: entry 後付け discussion / 新規 tag model を目的にせず /
  discussion・notification・permission・moderation が tag・entry・surface context を参照 / Rails
  UI 非実装 / Next.js の責務 / Rails の責務範囲 / Acme = identity authority / public
  profile を Acme と分離 / SNS・follow graph deferred / Discourse・Forem 互換目指さず、全て記載済。
- Rails API contract direction: `title`, `slug`, `summary`/`excerpt`, `tags`, `published_at`,
  `updated_at`, `discussion_ref`, `discussion_count`, `watch_state`, `tracking_state`,
  `muted_state`, `author_profile_ref`, `visibility`, `moderation_state`, `policy_context`
  全て候補として記録済。契約上の制約 (resource noun は `entries` のまま、`author_profile_ref`
  は Acme identity を漏らさない、`policy_context` / `moderation_state`
  は server-authoritative) も明記済。
- Consequences: Benefits / Tradeoffs / Rejected・Deferred の三節で網羅。

### memo 側 (全項目カバー済)

- Scope (In / Out): Discussion / trust level / moderation / flagging / notification / public profile
  reference / existing tags reuse / Next.js 向け read model を含む。Rails UI / article・card・list
  UI / Next.js 実装 / full SNS / follow・social graph / Forem clone / Discourse clone / Acme
  identity 変更 / model・migration・route の実装変更は範囲外として明示。
- Suggested Future Implementation Checkpoints: 指示の 10 項目を全て列挙 (entry → discussion 参照 /
  topic の surface 識別 / entry 識別 / tag 参照 / notification
  event の reply・mention・watch・tracking・muted 表現 / moderation
  state の visible・hidden・flagged・under_review・rejected 表現 / trust-level
  policy の actor・surface・action 評価 / public profile と Acme 分離 / Next.js が read
  model を取得可能か / security・workflow notification への拡張)。
- Boundary Notes: Acme = identity authority、public profile は表示用人格で credential / email /
  phone / passkey / TOTP / secret / OAuth subject を露出しない、UI = Next.js、Rails = authoritative
  data・policy・event・state・API contract、SNS / graph は別設計、明記済。
- Open Questions と Promotion Candidate も記録済。

## Decision

既存 ADR /
memo がユーザー指示を完全に満たしているため、ファイルの新規作成・更新は行わない。ユーザーも本セッションで「既存のまま完了とする」と確認済。

## 変更ファイル

- 実装ファイル: 変更なし
- ADR / memo: 変更なし
- 本プランファイル `plans/umaxica-rails-repository-snappy-volcano.md` のみ作成

## Verification

実装変更がないため、テスト実行は不要。

既存ドキュメントを再確認する場合:

```bash
cat adr/docs-help-news-discussion-moderation-notification.md
cat memos/2026-06-16-claude-content-discussion-profile-feed-boundary.md
```
