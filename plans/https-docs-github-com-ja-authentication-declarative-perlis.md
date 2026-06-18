# Step-Up MFA Status ドキュメントに GitHub Sudo モード参照を追加

## Context

`docs/security/step-up-mfa-status.md`
は本プロダクトの step-up 認証境界（AAL2）を定義しているが、初見の読者にとって「なぜセンシティブなページで再認証を要求するのか」「業界一般でこれは何と呼ばれているのか」が掴みづらい。GitHub の Sudo モードは、Web アプリケーションにおける step-up 認証のよく知られた実装であり、目的・対象アクション・短いタイムアウトという構造が本プロダクトの step-up ゲートとほぼ同型である。

GitHub Docs（日本語版）の Sudo モード解説ページへの外部参照を追加することで、

- 用語のすり合わせ（step-up = GitHub の Sudo モード相当）
- 「センシティブな操作の直前に再認証する」というメンタルモデルの即時提供
- 設計レビューや新メンバーへの説明時に共通の足場となる外部リファレンスの提供

を実現する。仕様変更ではなく、既存ドキュメントへの参照リンクの追記のみ。

## Scope

- 追記のみ。既存の規範的記述（authority 境界、`multi_factor_status_id`
  の値、surface 別判定、bootstrap-exempt のリスト、MFA reset の扱い）には一切手を入れない。
- 参照リンクは「類似実装の業界例」として扱う。GitHub の挙動を本プロダクトの仕様に同期させる意図はない（タイムアウト 2 時間など数値は引用しない）。

## Target File

- `docs/security/step-up-mfa-status.md`

## Change

`## Purpose` セクション末尾に、業界類似例を示す段落（日本語）を追記する。

追記する文面（案）:

```markdown
## 関連実装の参考

step-up は業界一般には「sudo モード」「再認証」「elevated
session」などとも呼ばれる、機密操作の直前に近時の本人性確認を要求するパターンである。GitHub の Sudo モードは Web アプリにおける代表的な実装例で、対象アクション（メールアドレス変更、SSH キー登録、PAT 発行など）と短いセッションタイムアウトを組み合わせる点で本プロダクトの step-up ゲートとほぼ同型である。

- 参考: GitHub Docs「Sudo モード」
  https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/sudo-mode

ただし本プロダクトの step-up は GitHub 仕様に追従するものではなく、対象ページ・有効期間・判定対象クレデンシャルは本ドキュメントおよび
`docs/security/authentication-assurance-levels.md` の規定に従う。
```

ポイント:

- 「業界類似例」として位置付け、規範ではないことを明示
- GitHub 側の具体値（2 時間など）を本プロダクト規範として持ち込まない
- 既存の `docs/security/authentication-assurance-levels.md` 参照と並列で AAL 文脈に置く
- AGENTS.md の Repository Language
  Policy に従い日本語追記を許可される範疇か確認: 本ファイル自体が既に英語で記述されている stable
  docs であるため、追記も英語で揃える方が policy 整合的。下記「言語の選択」を参照。

## 言語の選択

`AGENTS.md` の Repository Language Policy は「リポジトリファイルは原則英語」であり、
`docs/security/step-up-mfa-status.md`
は既に英語で書かれている。本追記も英語で書くのが policy 整合的。

最終文面（英語版）案:

```markdown
## Related Industry Implementation

Step-up is commonly known in the industry as "sudo mode", "reauthentication", or "elevated session":
a pattern that requires a recent proof-of-presence immediately before a sensitive action. GitHub's
Sudo mode is a representative web-app implementation that combines a list of sensitive actions
(email change, SSH key registration, PAT creation, etc.) with a short session timeout, structurally
similar to this product's step-up gate.

- Reference: GitHub Docs "Sudo mode" —
  https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/sudo-mode

This product's step-up does not track GitHub's specifics. Protected pages, freshness window, and
counted credentials follow this document and `docs/security/authentication-assurance-levels.md`.
```

## Verification

- `docs/security/step-up-mfa-status.md` を開き、`## Purpose`
  の直後に新セクションが入っていることを確認
- 既存の表（`Columns` / `Surface Criteria` / `Page Classes`）・記述に変更が無いことを diff で確認
- リンクが
  `https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/sudo-mode`
  であることを確認
- Markdown lint（プロジェクトに lint がある場合）/ プレビューで見出し階層が崩れていないこと

## Out of Scope

- 仕様変更（タイムアウト導入、対象アクション拡張など）
- 他ドキュメント（`authentication-assurance-levels.md`, `step-up-ceremony-delegation.md`
  ほか）への波及追記
- AGENTS.md / ADR の更新
