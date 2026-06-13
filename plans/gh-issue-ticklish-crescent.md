# GitHub Issue 棚卸し計画

## 背景 (Context)

open
issue が 126 件まで積み上がり、重複・古い stub・陳腐化した議論が混在している。棚卸しして、**重複は削除 (delete)・古い/解決済みは close**
で整理する。ユーザー方針: 全 126 件を精査 → 候補リストを提示 → 承認後に一括処理。

調査で判明した事実:

- `#699–#710` は本文が壊れたテンプレ（モデル名・対象ファイルが空欄）。`#712–#723`
  が同一モデルの正常な再作成版。`PostVersion` だけ `#711`(正常) と `#724`(正常) の二重。
- `app/models/concerns/treeable.rb` は**現在存在しない**（`adr/treeable-cte-refactor.md` と
  `plans/backlog/restoration-b4-treeable-cte-refactor.md` のみ）。`#694–#696`
  の参照対象が消えている。
- engine リネーム(#725–#730, #758, #759)・subject-scoped OIDC(#740, #742)・Pundit→Action
  Policy(#674)・Treeable CTE(#672)・Turnstile env toggle(#630)・localization/theme(#631,
  #632) は既に **closed**。

---

## 分類サマリ

| 区分                                          | 件数 | 操作         |
| --------------------------------------------- | ---- | ------------ |
| Tier 1: 確実な重複                            | 13   | **delete**   |
| Tier 2: 古い/無効な stub（確度高）            | 4    | **close**    |
| Tier 3: 要個別確認（陳腐化/解決済みの可能性） | 6    | 確認後 close |
| KEEP: 現行の前向き作業                        | 103  | 残す         |

---

## Tier 1 — 削除 (delete) : 13 件

`edited_by_type` リファクタの重複。各モデルで「壊れたテンプレ版」を削除し、正常版を残す。

| モデル              | 削除 (壊れ) | 残す (正常)       |
| ------------------- | ----------- | ----------------- |
| AppDocumentRevision | #699        | #712              |
| AppDocumentVersion  | #700        | #713              |
| AppTimelineRevision | #701        | #714              |
| AppTimelineVersion  | #702        | #715              |
| ComDocumentRevision | #703        | #716              |
| ComDocumentVersion  | #704        | #717              |
| ComTimelineRevision | #705        | #718              |
| ComTimelineVersion  | #706        | #719              |
| OrgDocumentRevision | #707        | #720              |
| OrgDocumentVersion  | #708        | #721              |
| OrgTimelineRevision | #709        | #722              |
| OrgTimelineVersion  | #710        | #723              |
| PostVersion         | **#724**    | #711 (先発・正常) |

**削除対象**: `#699 #700 #701 #702 #703 #704 #705 #706 #707 #708 #709 #710 #724`

> 注: `gh issue delete` は管理者権限が必要で**復元不可**。権限がない場合は close へフォールバック。

---

## Tier 2 — クローズ (close, 確度高) : 4 件

| #    | タイトル                                 | 理由                                                                         |
| ---- | ---------------------------------------- | ---------------------------------------------------------------------------- |
| #265 | How about Service State notification     | 既に `invalid` ラベル付き。本文は1行のアイデアメモ。                         |
| #413 | how about permanent banned user？        | 本文「🤔」のみの stub。アカウント停止は #643 (lockout/suspension) でカバー。 |
| #76  | OGP ... thoughts on implementing OGP?    | 2025-03 のソーシャル列挙のみ。コメント0・進展なしの陳腐化 stub。             |
| #79  | talk about how to implement contact page | 2025-03 の議論メモ。Contact 刷新エピック #547–#551 に置換済み (superseded)。 |

close コメント例: `Closing during issue triage (2026-06-13). <理由>. Reopen if still needed.`
（#79 は `Superseded by #547 Contact System Overhaul (#548-#551).`）

---

## Tier 3 — 要個別確認 : 6 件

機械的には判断しきれない。一括処理前に**1件ずつユーザー確認**する。

| #    | タイトル                                   | 確認ポイント                                                                                |
| ---- | ------------------------------------------ | ------------------------------------------------------------------------------------------- |
| #694 | audit model-layer SQL                      | 対象 `treeable.rb` が現存しない。#672(closed) で解決済みか、restoration B4 で再作成待ちか。 |
| #695 | harden Treeable shared tests               | 同上。Treeable 概念自体が現状ない。                                                         |
| #696 | replace ORM-safe raw SQL in Treeable       | 同上。`adr/treeable-cte-refactor.md` / backlog B4 と整合確認。                              |
| #155 | Some Mail Address are not registered       | `umaxica.com/.net/.org/.app` ブロックのコードが見当たらない。仕様化済み or 陳腐化か。       |
| #429 | Analyze behavior for table deletion (test) | 曖昧な依頼。現行テスト/方針でカバー済みか。                                                 |
| #560 | Investigate phantom &query= parameter      | 「investigated」と記載。調査完了で close 可能か、未解決バグか。                             |
| #790 | Turnstile visible widget fails to render   | bug ラベル。現在も再現するか要確認（#630 env toggle は別件で closed）。                     |

> 補足: #790 は bug のため、解決していなければ KEEP。再現しなければ close。

---

## KEEP (残す) — 方針

下記の前向き作業は ADR/plans/backlog に紐づくため**全て残す**（個別列挙は割愛）:

- 認証/セキュリティ強化: #532 #533 #534 #573 #584 #607 #609 #610 #611 #613 #625 #633 #634 #635 #739
  #802 #803 #810 #811
- 監査/コンプライアンス: #554 #555 #556 #637 #638 #639 #640 #641 #642 #643 #644 #646 #647 #648 #649
  #650–#657
- Contact/Messaging エピック: #547 #548 #549 #550 #551 #591
- preference/setting DB: #578 #628 #629 #691 #697 #698 #777
- engine/命名/ルーティング: #733 #741 #743 #748 #749 #751 #796 #812 #813
- 正常な edited_by_type 集合: #711 #712–#723
- その他機能/設計: #476 #513 #552 #559 #575 #576 #577 #579 #581 #592 #598 #606 #616 #617 #619 #621
  #627 #658 #659 #731 #732 #765 #791 #795

---

## 実行手順 (承認後)

承認を得てから、以下を実行する。

### 1. Tier 1 削除 (13 件)

```bash
for n in 699 700 701 702 703 704 705 706 707 708 709 710 724; do
  gh issue delete "$n" --yes
done
```

権限エラーになる場合は close にフォールバック:

```bash
for n in 699 700 701 702 703 704 705 706 707 708 709 710 724; do
  gh issue close "$n" -c "Duplicate of the clean edited_by_type set (#712-#723, #711). Closing during triage 2026-06-13."
done
```

### 2. Tier 2 クローズ (4 件)

```bash
gh issue close 265 -c "Closing during issue triage (2026-06-13). Already labeled invalid. Reopen if still needed."
gh issue close 413 -c "Closing during issue triage (2026-06-13). Stub; account suspension is tracked in #643. Reopen if still needed."
gh issue close 76  -c "Closing during issue triage (2026-06-13). Stale stub from 2025-03 with no progress. Reopen if still needed."
gh issue close 79  -c "Closing during issue triage (2026-06-13). Superseded by Contact System Overhaul #547 (#548-#551)."
```

### 3. Tier 3 (個別確認後) — 確定済み

ユーザー確認の結果:

- **close 済み**: #694 #695 #696 (Treeable superseded) / #560 (Cloudflare 由来) / #155 #429
  (古い曖昧)
- **KEEP**: #790 (Turnstile bug、実機再現未確認のため保留)

### 4. 追加棚卸し: #748 (意思決定 issue, 完了確認)

`Decide Regional model rename: behavior -> chronicle` は**決定確定済み**:

- `adr/activity-journal-chronicle-db-model-naming.md` で Regional=`Chronicle`・`behavior`
  不使用を決定（その後 `adr/chronicle-audit-db-consolidation.md` に superseded、`behavior`
  family は chronicle へ統合）。
- 後続 #749 (open) が制約「Keep `chronicle` as the Regional detail layer」を前提化。

→ 意思決定は完了。**close 予定**。

```bash
gh issue close 748 --repo seahal/umaxica-apps-jit-global \
  -c "Decision made and recorded: Regional standardizes on 'chronicle' (not 'behavior'). See adr/activity-journal-chronicle-db-model-naming.md (later superseded by adr/chronicle-audit-db-consolidation.md, which consolidated the former 'behavior' family into the chronicle domain). #749 already treats chronicle as the locked Regional naming. Closing as completed."
```

---

### 5. #533 (deterministic→非決定的暗号化 + blind index) — 実装確認 & doc 新設

**調査結果: #533 はクローズ相当（実装完了）**

- `concerns/email.rb:48 encrypts :address, downcase: true` /
  `concerns/telephone.rb:29 encrypts :number` — 非決定的暗号化。`deterministic: true`
  はコード全体で不在。
- blind index 検索: `address_digest`/`number_digest` + `IdentifierBlindIndex`(HMAC-SHA256)、
  `find_by_address`/`find_by_number`/`with_address`/`with_number`。
- #533 が指摘した staff(operator) の欠落は移行
  `db/org_principals_migrate/20260509120000_add_staff_identifier_blind_indexes.rb` で解消。
- visitor/client/operator × email/telephone の6モデルが concern を include、org/app/com
  structure.sql に digest UNIQUE index あり。`previous: deterministic`
  残骸なし＝再暗号化の最終状態。

**他の暗号化フィールド（同スタイル）**:

- `birthdate` — `concerns/has_birthdate.rb:8`、client/visitor/operator が include。非決定的・blind
  index 無し。
- `concerns/version.rb` — title/body/description（コンテンツ）。
- `client_chronicle.rb` / `operator_chronicle.rb` — previous_value（監査変更前値）。

**ドキュメント状況**: email/telephone は `docs/reference/active-record-encryption-rotation.md` と
`docs/security/identifier-hmac-emergency-rotation.md` (+
ADR) でカバー済み。**birthdate は未記載**、統合インベントリも不在。

#### アクション

1. **#533 を close**（実装完了コメント付き）:

```bash
gh issue close 533 --repo seahal/umaxica-apps-jit-global \
  -c "Closing as completed (2026-06-13). Email/telephone are now non-deterministically encrypted with HMAC blind-index lookup (address_digest/number_digest via IdentifierBlindIndex) across visitor/client/operator (app/com/org). No 'deterministic: true' remains. The staff/operator blind-index gap this issue flagged was filled by migration db/org_principals_migrate/20260509120000_add_staff_identifier_blind_indexes.rb. Search uses find_by_address/find_by_number; key rotation is documented in docs/reference/active-record-encryption-rotation.md and docs/security/identifier-hmac-emergency-rotation.md. Reopen if any deterministic encryption or direct encrypted-column query is reintroduced."
```

2. **新規 doc `docs/security/encrypted-fields-inventory.md` を作成**（英語、周辺 security
   docs と整合）。内容:
   - 目的: アプリ層 Active Record Encryption の暗号化列インベントリ（モード・blind
     index 有無・検索可否）。
   - 暗号化方針サマリ: 全列が非決定的。検索対象 identifier のみ HMAC
     digest（`IdentifierBlindIndex`）。
   - インベントリ表（fields × concern/model × mode × blind index × searchable × notes）: email
     address / telephone number（blind index あり・検索可）、birthdate（無し・非検索 PII）、version
     title/body/description、chronicle previous_value。
   - lookup 契約: `find_by(address:)` 禁止、`find_by_address`/digest 経由のみ。
   - 関連: `active-record-encryption-rotation.md`, `identifier-hmac-emergency-rotation.md`,
     `adr/identifier-hmac-emergency-rotation.md`。
   - 必要なら `docs/index.md` にインデックス行を追加。

> 言語: 既存 security docs が英語 +
> AGENTS.md のリポジトリ言語ポリシー（docs は英語）に合わせ英語で記述。

## 検証 (Verification)

- 実行後: `gh issue list --state open --limit 500 --json number --jq 'length'` で件数が 126 →
  109（Tier1+Tier2 処理時）程度に減ったことを確認。
- 削除した番号が `gh issue view <n>` で 404 / closed になっていることを確認。
- KEEP 対象が誤ってクローズされていないことを `gh issue list --state open` で目視確認。
- Tier 3 の判断結果を本ファイルに追記して記録する。
