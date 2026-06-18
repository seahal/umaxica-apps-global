# id.umaxica.app ソーシャルログイン中断 — 原因調査と修正プラン

## 第 2 ラウンド（CSP 修正後、「ticket is required」で再停止）

### 観測

- 直前まで（CSP 二重スキーム修正後）社会ログインフローは進行するようになった。
- 直近ログ（`log/development.log` 末尾）では `Sign::App::Sign::In::ChecksController#show` が
  `state=DASHBOARD_PENDING / status_id=70 / token_id=2` まで進み
  `https://www.umaxica.app/welcome?ri=jp` に 302 → ここまで成功。
- その後、ブラウザは別経路で `Sign::App::Sign::Up::Check::Google::BirthdatesController#update`
  を POST し、Rails は **422 Unprocessable Content + 短い text/plain** を返した。画面に「ticket is
  required」（ユーザ表記「tocket is required」）が表示されて停止。
- 同じ時間帯に `security.csp_violation.reported` が依然として
  `form-action ... https://https://www.umaxica.app ...` を含む `original_policy`
  で発生している（document_uri=`/sign/up/check/google/birthdate`、blocked_uri 同上）。

### 文字列の出所（grep で確定）

メッセージ「ticket is required」の発生源は次の 4 か所のみ。

- `app/services/sign_up_step_gate.rb:93` `return failure("ticket is required") unless ticket`
- `app/services/sign_up_state_machine.rb:41`
- `app/services/sign_up_termination.rb:41`
- `app/services/sign_app_up_social_cancellation.rb:19`

レンダリングは `app/controllers/concerns/sign_up_explicit_step_controller_support.rb:57`：

```ruby
def render_step_gate_failure(gate)
  render plain: gate.errors.to_sentence.presence || "invalid_sign_up_step",
         status: :unprocessable_content
end
```

`SignUpStepGate#call` は `current_ticket = SignUpCycleLocator#current` が nil の場合に "ticket is
required" を `errors` に積んで失敗を返す。

### 根本原因の判定（2 系統あり、どちらも事実）

**(A) CSP 修正がまだサーバ側に反映されていない。** `config/initializers/content_security_policy.rb`
を変更したが Rails の initializer は development でも自動 reload されない。ログの最新 CSP 違反レポートが依然として
`https://https://www.umaxica.app` を含む `original_policy` を出していることが動かぬ証拠。
**dev サーバの再起動が必要**（コードの修正は正しい。プロセスに食わせていないだけ）。

**(B) Sign-up flow ticket がセッションから消えている／一致しない。**
`SignUpCycleLocator#current`（`app/services/sign_up_cycle_locator.rb:23-35`）は
`session[:app_sign_up_flow_locator]` の `{public_id, nonce}` を読み、

- `ClientSignUpFlow.current.find_by(public_id:)` がヒットすること、
- `cycle.nonce_matches?(nonce)`、
- terminal でない（COMPLETED/FAILED/EXPIRED/CANCELLED 以外）、

を全部満たさないと nil を返す。BirthdatesController#update の処理中ログには
**`ClientSignUpFlow Load`
クエリ自体が現れていない**。つまり locator の payload が session に無い（または辞書が壊れた）状態で POST を受けている。

考えられる経路：

1. 既存ユーザの再ログイン経路に分岐し、`Sign::App::Sign::In::ChecksController#show`
   で sign-in が完成・dashboard へ 302 した時に sign-up 側の session キー (`:app_sign_up_flow_locator`
   / `:sign_app_up_sequence_id` 他) が `sign_up_session_state.clear_all!`
   経由でクリアされた可能性。呼び出し箇所： `sign_up_sequence_controller_support.rb:34, 305`,
   `sign_up_explicit_step_controller_support.rb:71`,
   `sign/app/sign/up/checkpoints_controller.rb:27, 48`。
2. ブラウザ側の別タブ（前回 CSP ブロックで止まったタブ）から `BirthdatesController#update`
   を遅延 POST しており、現在のセッションでは sign-up cycle は既に消費済み or terminal。
3. `social_completion` の中継（`id.umaxica.app` → `www.umaxica.app`
   → 戻り）の間にセッション cookie が想定通りに維持できていない（cross-host を跨ぐので
   `id.umaxica.app` 側 cookie は維持されるはずだが、サブドメイン scope 設定次第）。

### 確定するための観測手順（次回フロー実施前）

1. **まず dev サーバを再起動**して CSP 修正を有効化する。
2. ブラウザ側で **すべてのタブを閉じてから** プライベートウィンドウで再試行。
3. 新しい `log/development.log` の中で `security.csp_violation.reported`
   が発生しないことを確認する。
4. `BirthdatesController#update` を打つ直前に
   `Sign::App::Sign::Up::Check::Google::ConfirmationsController` または同等で
   `ClientSignUpFlow Load`
   がログに現れているかを確認する。現れていれば cycle は session に居る → 別問題（nonce 不一致 /
   terminal）。現れていなければ「session に locator が無い」が確定。
5. 必要なら `SignUpStepGate#failure` の errors と `SignUpCycleLocator#current_payload`
   の戻り値を一時的にログ出力して nil なのか public_id mismatch なのか nonce
   mismatch なのかを切り分ける。

### 次の修正候補（観測 4・5 の結果で確定する）

- (A) CSP を確実に反映：dev サーバ再起動の徹底。これだけで再現しなくなる可能性が高い。
- (B) もし `Sign::App::Sign::In::ChecksController` の dashboard 遷移時に sign-up
  session が広範に削除されているなら、削除条件を **sign-up
  cycle が既に terminal の場合のみ**に絞る。 `sign_up_sequence_controller_support.rb:34/305` の
  `clear_all!` の前後で sign-up cycle の状態 guard を追加する案。
- (C) `social_completion` 経由のクロスホスト遷移で session が割れているなら、 `acme_service`
  側 (`www.umaxica.app`) の completion endpoint からの redirect 後に `id.umaxica.app` の sign-up
  locator を再 issue する handshake を入れる（現状コードは既にそうなっているはずだが要確認。
  `sign/app/auth/omniauth_callbacks_controller.rb:245, 346, 525` で
  `sign_up_flow_locator.issue!(cycle)` を都度 呼んでいる）。

### 推奨アクション

- **まず dev サーバ再起動 → 再現テスト**。ログ上 CSP は依然として旧ポリシーを出しているのでこれだけで第 2 ラウンドの停止が消える可能性は十分にある。
- それでも「ticket is
  required」が出るなら、ログを改めて取得して上の手順 4・5 を実行。結果を貼り付けてもらえれば B のどのパターンかを切り分けて修正に進む。

---

## Context（なぜこの変更が必要か）

ユーザーから「`id.umaxica.app` のソーシャルログインが途中で止まる」との報告。 `log/development.log`
を Google ログイン1往復ぶん解析した結果、ブラウザ側で **CSP `form-action`
ディレクティブが malformed なため、自動 POST がブロックされて止まっている**ことを特定した。本プランはその根本原因と最小修正、および同じ書き間違いに由来する隣接バグの整理を行う。

## 何が起きていたか（ログから再構成した実フロー）

1. `id.umaxica.app/sign/up` → Google にリダイレクト（OmniAuth）。
2. Google からコールバック `GET https://id.umaxica.app/auth/google_app/callback` を受信。
   - `Sign::App::Auth::OmniauthCallbacksController#omniauth` が動作（log L135249–L135280）。
   - state の consume、`ClientGoogleIdentity` 照会、`ClientSocialCeremonyTransaction` 確認、
     `IdentitySocialCeremonyCandidate` の保存 まで**サーバ側は全て成功**。
3. ビュー `sign/shared/social_completion.html.erb` を描画（L135281–L135282）。
   - これは `completion_url`（=
     `https://www.umaxica.app/social/auth/google_app/completion`）に対する hidden
     form を JS で即時 submit する「continuation 遷移」用ページ。
4. ブラウザが POST を発射しようとした瞬間に **CSP `form-action`
   違反**で submit がブロック。ログイン UI は遷移せず止まる（log L135296:
   `security.csp_violation.reported`）。

### CSP 違反レポート（決定的証拠）

```
document_uri:        https://id.umaxica.app/auth/google_app/callback
blocked_uri:         https://www.umaxica.app/social/auth/google_app/completion
violated_directive:  form-action
original_policy:     ... form-action 'self'
                       https://accounts.google.com
                       https://appleid.apple.com
                       https://https://www.umaxica.app  ← ★ scheme 二重
                       https://https://www.umaxica.com  ← ★ scheme 二重
                       https://https://www.umaxi...
```

`form-action` の allowlist が **`https://https://www.umaxica.app`**
という二重スキームの不正トークンで列挙されており、合法なオリジン `https://www.umaxica.app`
へマッチしない → ブラウザが form submit を `form-action` 違反として拒否し
**ソーシャルログインの「完了 POST」が必ず失敗する**状態だった。

## 根本原因（バグの実装）

`config/initializers/content_security_policy.rb` の host 組み立てが、 **「すでに `https://`
を含むオリジン文字列」にもう一度 `https://` を貼り付けている**。

```ruby
# config/initializers/content_security_policy.rb:13-25
acme_form_hosts =
  [
    boot_config.fetch(:hosts).acme_service.to_s,   # → "https://www.umaxica.app"
    boot_config.fetch(:hosts).acme_corporate.to_s, # → "https://www.umaxica.com"
    boot_config.fetch(:hosts).acme_staff.to_s,     # → "https://www.umaxica.org"
  ].map { |host| "https://#{host}" }               # ← ここで二重化 ★
sign_form_hosts =
  [
    boot_config.fetch(:hosts).sign_service.to_s,
    boot_config.fetch(:hosts).sign_corporate.to_s,
    boot_config.fetch(:hosts).sign_staff.to_s,
  ].uniq
sign_form_hosts.map! { |host| "https://#{host}" }  # ← 同上 ★
```

`boot_config.fetch(:hosts).X` は `ConfigValues::HostFamilyValues` の `OriginValue`。その `#to_s`
の実装が `"#{scheme}://#{host}#{port_part}"`（`lib/config_values_origin_value.rb:15-18`）で
**スキーム込みのオリジン文字列を返す**。

そこへ `"https://#{host}"` を被せた結果、CSP には `https://https://www.umaxica.app`
等が出力されていた。

## 修正方針（最小・型として正しい形）

`OriginValue`
を「scheme 付き origin が欲しい所」と「ホスト名だけ欲しい所」で明示的に呼び分ける。CSP の
`form_action` は**スキーム付き origin** を要求するので、 `to_s`
の戻り値をそのまま使い、`"https://#{host}"` の二重スキーム生成を**消す**だけで直る。

### 主修正

- ファイル: `config/initializers/content_security_policy.rb`
- 変更: `acme_form_hosts` / `sign_form_hosts` の構築から `"https://#{host}"` の `map`/`map!`
  を削除し、`OriginValue#to_s` の結果をそのまま使う。
- 期待される CSP（修正後）:
  ```
  form-action 'self'
    https://accounts.google.com
    https://appleid.apple.com
    https://www.umaxica.app
    https://www.umaxica.com
    https://www.umaxica.org
    https://id.umaxica.app
    https://id.umaxica.com
    https://id.umaxica.org
  ```
- 影響範囲は CSP ヘッダのみ。`OriginValue` API や他の呼び出し箇所（routes 等で `.host`
  を使っているもの）は変えない。

### 同根の追加バグ（同調査中に発見・別件として要修正）

ログ上は今回の中断とは別だが、**「`OriginValue` の `to_s`
がスキーム付き」という仕様の認識違いから派生した同種バグ**が他にもあるので、同 PR で直すか、別 backlog 化するか判断したい（本プランの主修正対象外）。

1. `config/environments/production.rb:127-140`
   `config.hosts = [boot_hosts.acme_service.to_s, ...]`。Rails の host
   authorization は**ホスト名（`www.umaxica.app`）**を期待するため、 `"https://www.umaxica.app"`
   を入れても照合できない。→ 各要素を `.host` に変更すべき。

2. `config/initializers/omniauth.rb:57-69, 95-102` `PUBLIC_SIGN_HOSTS` と
   `OmniAuthNonAppSocialGuard#blocked_hosts` が `request.host`（スキーム無し）と
   `"https://id.umaxica.app"` を比較しており、 **永久にマッチしない**。`public_sign_host?`
   は常に false、 `OmniAuthNonAppSocialGuard` は何もブロックしない。→ 各要素を `.host`
   に変更すべき。

## 重要な参照コード

- `config/initializers/content_security_policy.rb:13-37` — 主修正対象。
- `lib/config_values_origin_value.rb:15-18` — `OriginValue#to_s`
  がスキーム込みであることの根拠（仕様）。
- `lib/config_values_host_family_values.rb:36-71` — host 構成元データ。
- `app/views/sign/shared/social_completion.html.erb` — ブロックされていた form。 `completion_url`（=
  `acme_service` 上の `/social/auth/<provider>/completion`）に POST する自動送信フォーム。
- `app/controllers/concerns/social_auth.rb` — コールバック処理本体。
- 関連 ADR: `docs/security/observability-boundary.md`（CSP report 経路の運用方針）

## 検証手順（E2E）

1. **CSP ヘッダの直接確認**
   - dev サーバを起動し、`curl -sI https://id.app.localhost/sign/up`（または同等のルート）から
     `Content-Security-Policy` を取得し、`form-action` ディレクティブに `https://www.app.localhost`
     等が**1 個だけの `https://`** で並ぶことを目視確認。
   - `https://https://` が含まれていないこと。

2. **Google ログイン回し直し**
   - `id.app.localhost`（または
     `id.umaxica.app`）でソーシャルログイン（Google）を実行し、`/auth/google_app/callback` 後に
     `www.app.localhost/social/auth/google_app/completion`
     まで遷移してログインが完了することを確認。
   - 同時に `log/development.log` 末尾で `security.csp_violation.reported`
     が**発生しないこと**を確認。

3. **テスト**
   - `bin/rails test test/initializers` 配下に CSP 用の最小テストがあれば実行。
   - 無ければ `config/initializers/content_security_policy.rb` の評価結果として
     `Rails.application.config.content_security_policy.directives["form-action"]` を検査する request
     spec / integration test を追加することを検討（本プラン本体には含めず、テスト方針として記載）。

4. **回帰**
   - Apple ログインも同じ `social_completion.html.erb`
     経路を通るため、可能なら Apple 側も 1 周回しておく。
