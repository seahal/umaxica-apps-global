# Flash / トースト撤去計画

## Context（背景）

UI/UX の潮流として、Flash
/ トースト型の一過性通知パターンが嫌われつつある。本リポジトリでもこれを廃止する。なお現状の実装は自動消滅する JS トーストではなく、各レイアウト上部にサーバレンダリングされる
`app/views/layouts/shared/_flash_messages.html.erb`（`flash.each`
で border 付きボックスを描画）だが、撤去対象としての意図は同じ — Rails の `flash`
機構そのものをアプリから取り除き、今後の利用を harness ルールで禁止する。

加えて、複数の ADR が `flash`
を前提にした記述を含むため、撤去に合わせて該当 ADR も改訂し、リポジトリ全体の整合を保つ。

### 確定済みの方針（ユーザ確認済み）

- harness 禁止ルールは **新規ファイル** `.agents/harnesses/rules/generic/no-flash-messages.mdc`
  に置く。
- flash を前提にしている **ADR も更新する**。
- 代替フィードバックの方針は本計画では確定せず、実装フェーズ着手時に確定する（下記「代替方針」参照）。

## 現状インベントリ（撤去対象）

| 区分                     | 箇所                                                                                       | 代表ファイル                                                                                                                                                                                                                                                             |
| ------------------------ | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 中心抽象（concern）      | `flash[]` / リダイレクトヘルパ群                                                           | `app/controllers/concerns/authentication_redirects.rb`（`redirect_with_notice` / `redirect_with_alert` / `build_notice_params` / `build_alert_params` / `redirect_with_pt_handling`）                                                                                    |
| concern（その他）        | `flash[:notice]` / `flash[:alert]`                                                         | `acme_step_up_completion.rb`, `authorization_audit.rb`, `session_limit_gate.rb`, `sign_email_registrable.rb`, `sign_email_registration_flow.rb`, `sign_error_responses.rb`, `sign_out_notice.rb`, `social_auth.rb`, `verification_base.rb`, `sign_verification_entry.rb` |
| コントローラ             | `flash[]`（66）/ `flash.now[]`（28）/ `redirect_to ..., notice:`（26）/ `..., alert:`（8） | `sign/**`, `acme/**/settings/**`（合計 ~27 ファイル）                                                                                                                                                                                                                    |
| ビュー（描画本体）       | flash パーシャル                                                                           | `app/views/layouts/shared/_flash_messages.html.erb`                                                                                                                                                                                                                      |
| ビュー（レイアウト参照） | `render "layouts/shared/flash_messages"`                                                   | `app/views/layouts/{acme,sign}/{app,com,org}/application.html.erb`（6 ファイル）                                                                                                                                                                                         |
| ビュー（直接参照）       | `flash[:alert]` 条件分岐                                                                   | `sign/app/in/sessions/edit.html.erb`, `sign/app/verifications/show.html.erb`, `sign/org/in/sessions/show.html.erb`, `sign/org/verifications/show.html.erb`                                                                                                               |
| フロントエンド型         | `FlashData` 型 / Inertia 設定                                                              | `app/javascript/types/index.ts`, `app/javascript/types/globals.d.ts`                                                                                                                                                                                                     |
| テスト                   | flash アサーション                                                                         | test/ 配下 ~66 ファイル                                                                                                                                                                                                                                                  |
| i18n                     | notice/alert 用文言キー                                                                    | `config/locales/{us,jp}/{en,ja}.yml`（flash 専用構造ではなく `t(...)` キー）                                                                                                                                                                                             |

> 注: `flash.keep` / `flash.discard` は未使用。

## 代替方針（実装着手時に確定する推奨案）

flash が運んでいるフィードバックは性質が異なるため、撤去時に同一には扱えない。推奨デフォルト:

- **エラー（`flash.now[:alert]`
  等のフォーム/Turnstile/検証エラー）→ ページ内インライン表示へ変換。**
  これらは本質的にフォームエラーであり、単純削除はフィードバック喪失になる。再描画されるビューにインラインのエラー領域を持たせ、コントローラはインスタンス変数（例
  `@form_error`）等で渡す。
- **成功（`flash[:notice]`、サインイン完了など）→ 原則そのまま破棄。**
  遷移先ページ自体が成功を表現できる場合が多く、トースト撤去の主目的に合致。
- **リダイレクト時の `alert:`（認証エラーで弾かれた理由）→ 遷移先での扱いを個別判断。**
  多くは遷移先のページ文言やステータスで代替可能。代替不能な少数はインライン化対象に格上げ。

この振り分けは実装フェーズ冒頭で最終確定する。本計画は「どの flash がどの区分か」を上表で特定済みなので、確定後はカテゴリ単位で機械的に処理できる。

## 撤去ステップ

ADR 由来の制約（reset_session 順序、bootstrap 復帰、logout 境界）に触れるため、surface 境界を跨がない単位で段階的に進める。各ステップ後に該当テストを実行する。

1. **中心抽象の除去 / 置換**
   - `authentication_redirects.rb` の flash 依存ヘルパ（`redirect_with_notice` /
     `redirect_with_alert` / `redirect_with_pt_handling` の `flash[message_key] =` /
     `build_*_params`）を整理。pt（path
     target）リダイレクト機構自体は flash と独立なので残し、message を載せる経路だけ外す。
   - flash をラップする concern（`sign_out_notice.rb` の `issue_sign_out_notice!`,
     `session_limit_gate.rb`, `sign_error_responses.rb`, `authorization_audit.rb`
     等）を、確定した代替方針に従ってインライン化 or 単純除去。`no-compatibility-layer.mdc`
     に従いエイリアス/シムを残さず呼び出し側も同時更新。

2. **コントローラの除去 / 置換**
   - `flash[...]` / `flash.now[...]` / `redirect_to(..., notice:/alert:)`
     を区分（エラー=インライン化、成功=破棄）に沿って置換。surface（app/org/com）単位でまとめて処理し境界を跨がない。

3. **ビューの除去**
   - `_flash_messages.html.erb` を削除。
   - 6 レイアウトから `render "layouts/shared/flash_messages"` を削除。
   - flash を直接参照する 4 ビューを、インライン化したエラー変数を読む形へ置換。

4. **フロントエンド型の除去**
   - `app/javascript/types/index.ts` の `FlashData` 型と `globals.d.ts` の Inertia `flashDataType`
     参照を除去（未使用化したら削除。Inertia 共有プロップに flash を流していないか確認）。

5. **i18n の整理**
   - flash 専用に存在する文言キーがあれば削除。インライン化で引き続き使うキーは残す（破壊しない）。

6. **テストの更新**
   - flash アサーション（`assert_equal ... flash[...]` 等）を、インライン化したエラーの
     `assert_select` / レスポンス本文アサーションへ置換、または成功破棄に合わせて削除。
   - プレースホルダ/`assert true` 化は禁止（testing.mdc）。代替の観測点で実挙動を検証する。

## Harness 禁止ルール（新規ファイル）

`.agents/harnesses/rules/generic/no-flash-messages.mdc` を新設。`absolute-rules.mdc` /
`no-silent-fallback.mdc` のフォーマット（frontmatter → `#` 見出し → 短い導入文 → `Do not:`
箇条書き）に合わせる。内容の骨子:

- Rails の `flash` / `flash.now` 機構、および `redirect_to(..., notice:/alert:)`
  ショートカットの新規利用を禁止。
- 理由: 一過性トースト/Flash 通知は UX 上忌避されつつあり、本アプリでは撤去済み。
- 代替: エラーはページ内インライン表示、成功は遷移先ページ自体で表現する（確定方針に合わせて記述）。
- 例外があるなら ADR で明示的に許可された経路のみ、と明記（`logout-completion-boundary.md`
  の既存禁止と整合）。

参照を `AGENTS.md` に追加:

- 「Required Harness Context」に flash/通知に触れる作業で本ルールを読むよう 1 行追加。
- 「Non-Negotiable Rules」の `Do not use` リストに `flash` を 1 項目追加（任意だが整合的）。
- `docs/reference/forbidden-rails-methods.md`（absolute-rules が source of
  truth と指定）にも flash を追記すると一貫する。

## ADR 更新

flash を前提にした記述を撤去方針に合わせて改訂する（英語で記述 — リポジトリ言語ポリシー）:

- `adr/step-up-authentication-redesign.md` — bootstrap 登録完了後の `flash[:notice]`（option
  X'）の記述を、確定した代替（インライン or 破棄）に置き換え、「X' = auto-bounce with
  flash」の根拠節を更新。
- `adr/session-reset-on-privilege-transition.md` — 「`reset_session` を `flash[:notice]`
  代入前に呼ぶ」制約は flash 撤去で前提が消えるため、reset_session の必要性自体（DB 永続セッション破棄）を維持しつつ flash 文言を除去。
- `adr/logout-completion-boundary.md` —
  flash 禁止を既に明記済み。新 harness ルールと矛盾しないことを確認、必要なら相互参照を一行追加。
- `adr/outbound-message-delivery-interface.md` — 直接の flash 制約ではないため変更不要（確認のみ）。

ADR 改訂が当初想定よりアプリ挙動へ波及する場合は、`adr/README.md`
の運用に従い該当 ADR の Status/Consequences を更新し、関連 `docs/` への波及も点検する。

## 検証

- 影響が狭いものから順に: `bin/rails test test/controllers/concerns/...` → surface 単位の
  `bin/rails test test/controllers/{sign,acme}/...` → 認証フロー統合テスト。
- フロント型変更後に Vitest（`vp test`）と型チェックを実行し、`FlashData`
  撤去で参照切れが無いか確認。
- リポジトリ全体に `flash` 残存が無いか最終 grep（`flash[`, `flash.now`, `notice:`, `alert:`,
  `_flash_messages`, `FlashData`）。`regression-guards.mdc`
  の forbidden-pattern ガードに flash を追加できれば再混入を機械的に防げる。
- 手動: 主要 surface でフォームエラー（Turnstile/検証失敗）とサインイン/サインアウトを実行し、代替のインライン表示が出る / トーストが出ないことを目視確認。

## 留意点

- pt（path
  target）リダイレクト機構は flash と独立。message 経路のみ外し、リダイレクト先解決は壊さない。
- `BareController`
  系・surface 境界・認証/認可パイプライン順序は変更しない（AGENTS.md 非交渉ルール）。
- エイリアス/互換シムを残さず、呼び出し側を同一変更で更新（no-compatibility-layer.mdc）。
