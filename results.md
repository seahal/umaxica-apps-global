# プロジェクト問題点レビュー (results.md)

作成日: 2026-06-05 / 自動スキャンによる速報版。明日の精査用チェックリスト。スキャン対象: `app/`
`lib/` `config/` `test/`
`Gemfile`。網羅ではなく目視+grepベース。各項目は「明日、実際にファイルを開いて裏取りする」前提のメモ。遠慮なく問題を列挙している。

---

## 🔴 CRITICAL (本番稼働・セキュリティに直結。最優先)

- [ ] **Rails を edge (main ブランチ) で本番運用している** `Gemfile`:
      `gem "rails", github: "rails/rails", branch: "main"`。未リリースの開発版。任意のタイミングで破壊的変更・退行・未修正脆弱性が混入する。
      `bundle update`
      のたびに本番挙動が変わりうる。セキュリティパッチの保証も無い。→ 安定版 (8.x のリリースタグ) へピン留めすべき。少なくとも commit
      SHA 固定。

- [ ] **`Gemfile` の Ruby バージョン指定が `ruby "4.0.5"`** Ruby
      4.0.5 は現時点で存在しないバージョン。`.ruby-version`
      ファイルも無い (空)。CI/本番でどの Ruby が実際に使われているか不明。再現性が崩壊している可能性。→ 実際に動いている Ruby を確認し、`.ruby-version`
      と Gemfile を一致させる。

- [ ] **`skip_before_action` が全体で 186 箇所** AGENTS.md の Non-Negotiable
      Rules で明確に禁止されている `skip_before_action` が大量。特に `core/{app,org,com}/edge/v0/*`
      `web/v0/{cookies,themes}` で `:enforce_verification_if_required` `:enforce_withdrawal_gate!`
      `:transparent_refresh_access_token` 等の**認証・検証・退会ゲートを skip** している。さらに
      `raise: false`
      付き = 対象コールバックが存在しなくてもエラーにならず**黙って素通り**。リファクタでコールバック名が変わっても気付けず、保護が外れたまま放置されるリスク。→ 各 skip が意図的かを1件ずつ監査。BareController で吸収できるものは構造で解決。
      `raise: false` は原則外す (タイポ・改名を検出できるように)。

---

## 🟠 HIGH (品質・保守性・潜在バグ。早めに対処)

- [ ] **`rescue StandardError` / 広域 rescue が 490 箇所** `app/services/security/jwt/*`
      `concerns/chronicle/capturable.rb`
      (5連発) など、セキュリティ/監査系で広い rescue が多数。例外を握り潰すと「認証失敗・トークン改竄・監査記録失敗」がサイレントに無視される危険。特に監査 (chronicle/risk
      emitter) で rescue して握り潰すと**証跡が欠落**しても誰も気付かない。→ 各 rescue が「何の例外を、なぜ握るか」を確認。ログだけして再 raise すべき箇所を洗う。

- [ ] **God object: `app/controllers/concerns/authentication/base.rb` が 2579 行**
      単一 concern に認証ロジックが集中。テスト困難・変更影響範囲が読めない・レビュー不能。続いて
      `preference/base.rb` 1105行、`sign/up/sequence_controller_support.rb` 665行、
      `preference/core.rb` 653行、`authentication/sequence_gate.rb`
      634行。→ 責務分割。認証パイプライン順序は変えずに、関心ごとにモジュール抽出。

- [ ] **コントローラに業務ロジックが混入している疑い**
      `acme/{com,org,app}/settings/activities_controller.rb` がコントローラ内で
      `rescue StandardError` を持つ = HTTP 以外の処理を抱えている兆候。AGENTS.md「Put business logic
      in models/services」違反の可能性。 `sign/app/up/telephones_controller.rb`
      469行 等、肥大コントローラ多数。→ サービス/モデルへ抽出。

- [ ] **本番コードに FIXME/TODO が 48 件、しかも中核モデル** `application_record.rb`:
      `# TODO: Find out why needs this code` / `# FIXME: i want to remove these lines.`
      `app_preference.rb`: `# TODO: what is this relation?`
      が複数 (関連の意味を作者自身が把握していない)、 `# FIXME: this is a hack.` /
      `# FIXME: too nasty name is this.` `member_status.rb`: enum 値の設計が暫定 (`NOTHING = 5`
      を 0 にしたい)。 `actor.rb:208`:
      subdomain 設定の掃除が未完。→ 「関連の意味が不明」は設計が固まっていない証拠。ドメインモデルの再確認が必要。

- [ ] **テストの健全性が疑わしい** テストファイル 1013、しかし `test/`
      内に TODO/FIXME/pending マーカーが 264 件、skip が 17 件。AGENTS.md「placeholder/skip/TODO テスト禁止」に抵触する可能性。→
      pending/skip の中身を確認。実装未完を隠していないか、モックで本質を回避していないか監査。

---

## 🟡 MEDIUM (設計の歪み・Rails Way からの乖離)

- [ ] **`public_send` による動的ディスパッチが concern 全体に多用** `collective_membership.rb`
      `chain_sealable.rb` `token_status_management.rb` `telephone_normalization.rb`
      など。柔軟だが、静的解析が効かず・タイポが実行時まで出ず・参照grepで追えない。メタプログラミング前提の抽象が増えると新規参加者の理解コストが激増。→ 本当に動的である必要があるか再検討。多くは明示メソッドで足りるはず。

- [ ] **生 SQL 文字列フラグメントが scope に散在** `where("discarded_at > ?", Time.current)`
      等が各モデルに重複コピペ (`*_verification.rb` `*_authorization_code.rb`
      で同一パターン)。プレースホルダ使用なので即SQLiではないが、**共通 scope 化されていない重複**が保守負債。
      `where("valid_to = 'infinity'::timestamp...")` 等 PG 依存の生文字列も点在。→ `scope :active`
      等を concern に集約。

- [ ] **`config/environments/production.rb` の SameSite 変更が作業途中 (未コミット)**
      `cookies_same_site_protection` を `:lax` → `:strict` に変更中。コメントは「session
      cookie は session_store.rb 側で Lax を維持」と主張するが、この前提が実際に正しいか (OIDC/email クロスサイト inbound フローが壊れないか) の検証が必要。間違うとログイン/SSO が本番で壊れる。→ 該当フローの結合テストで裏取りしてからコミット。

- [ ] **未コミットの作業が広範囲に散らばっている**
      認証・preference・dbsc・r18gate・verification・production 設定と横断的に手が入った状態で放置 (git
      status
      M 多数)。作業の意図が1コミットに収まっておらず、中断するとコンテキスト喪失リスク大。直近コミットが全部
      `[CheckPoint] ...`
      で**コミットメッセージが情報量ゼロ**。→ 論理単位でコミット分割し、意味のあるメッセージを付ける。

- [ ] **N+1 対策の `includes/preload/eager_load` が全体で 21 箇所のみ**
      モデル 543・関連多数の規模に対して eager
      loading が極端に少ない。一覧系エンドポイントで N+1 が潜在している可能性が高い。→
      bullet 等 or ログで主要一覧画面のクエリ数を計測。

---

## 🟢 LOW (整理整頓・cruft)

- [ ] **リポジトリルートにタイポしたゴミファイル `resutls.md` が存在 (untracked)** 本来 `results.md`
      のはずが `resutls.md` で空ファイルが残っている。削除推奨。(このレビューは正しい綴りの
      `results.md` に書いた。)

- [ ] **`inertia_example_controller.rb` が残存**
      scaffold/サンプルのコントローラが本番コードツリーに残っている疑い。削除確認。

- [ ] **`com_ticket_record.rb:8` `# FIXME: Is this needed?`** 使われているか不明なモデル。dead
      code の可能性。

- [ ] **`acme/org/application_controller.rb` に `# FIXME: I hate this line.` が3連発**
      `Preference::Adoption` `ActionPolicy::Controller` `Oidc::SsoInitiator`
      の include を作者が不本意としている = 設計が整理されていないサイン。include の責務を再設計。

---

## 明日やること (推奨順)

1. CRITICAL 3件 (Rails edge / Ruby版数 / skip_before_action 監査) を最優先で潰す。
2. `rescue StandardError` のうち**監査・セキュリティ系**だけ先に握り潰し有無を確認。
3. `authentication/base.rb` 2579行の分割計画を立てる (順序不変を厳守)。
4. SameSite=strict 変更を結合テストで裏取りしてからコミット分割。
5. テストの pending/skip 264+17 件の棚卸し。

---

### 注記 (スキャンの限界)

- Brakeman / bundler-audit は時間制約で未実行。明日 `bin/brakeman` `bundle audit` を回すこと。
- RuboCop も未実行 (`bin/rubocop`)。設定は揃っている (`rubocop-rails-omakase` 他)。
- 各 `skip_before_action` が「設計上正当な BareController 系か / 事故か」は1件ずつ要目視。
- grep ベースなので誤検知あり。必ず該当ファイルを開いて確認すること。
