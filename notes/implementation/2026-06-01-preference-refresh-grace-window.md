# preference リフレッシュトークンの並行グレース窓 + ローカル鍵再生成警告

日付: 2026-06-01 対象:
B（preference リプレイ・デグレ）と A（auth ローカル鍵再生成の可視化）の同時修正。

## 背景

1 回のページ読込が同一 refresh Cookie を載せた複数リクエストを同時発火し、先発が
`SingleUseToken#rotate!`
で消費＋ローテーションした直後に、後発が**消費済みの親トークン**を提示する。旧実装は後発を replay
= 侵害(compromise)扱いして `clear_preference_auth_cookies!`
で Cookie を全削除し新規トークンを再発行していた。これがユーザ報告「拒否→Cookie 破棄→新規発行」と同型のデグレ。（旧ログには
`preference.token.refresh.replay_detected`
が通常 GET で多発していた。現在はログがローテートされ証拠は消失。コード上の根本原因は未修正のままだった。）

## 採用した設計（B = Slice 8）

短いグレース窓（`SingleUseToken::PREFERENCE_REFRESH_GRACE_WINDOW = 30.seconds`）内で、直前にローテーション済みの親トークンの再提示を**良性な兄弟リクエスト**として扱い、replacement を
**読み取り専用で採用**する。侵害扱い・Cookie 破棄は行わない。窓を超えた再利用は従来どおり compromise。

### 重要な制約（ここが非自明）

- **raw refresh token は回転実行リクエストしか持てない。** `create_rotated_record!`
  は replacement の生トークンを 1 度だけ返し、DB には `token_digest`
  しか残らない。よって後発リクエストでは replacement の Cookie を再発行**できない**。→ グレース経路は
  **Cookie を一切触らない**。勝者（先発）リクエストの `Set-Cookie`
  がブラウザの新 Cookie を確定させる。後発が Cookie を消すと勝者の更新を上書きしてしまうため、グレース経路では
  `clear_preference_auth_cookies!` も `set_refresh_token_cookie` も呼ばない。
- **`replaced_by_id` は作成時に self を指す**（`AppPreference#default_replaced_by_to_self` /
  `persist_self_replacement`）。したがって「replacement あり」を `replaced_by_id.present?`
  で判定すると常に真になり誤検出する。`rotated_within_grace?` は
  `replaced_by_id != id`（自己参照を除外）で実ローテーションのみを検出する。
- 提示者は親トークンの digest 一致を通過した正当な保持者なので、replacement をそのまま渡しても認可境界は弱まらない（その親の保持者＝replacement を受け取るべき主体）。

### 変更ファイル

- `app/models/concerns/single_use_token.rb`: 定数 `PREFERENCE_REFRESH_GRACE_WINDOW`、述語
  `rotated_within_grace?(window:, now:)` を追加。
- `app/controllers/concerns/preference/base.rb`: `handle_preference_refresh_replay!`
  をグレース対応化（`:grace` / `:compromised` を返す）。`preference_refresh_grace_replacement` と
  `adopt_preference_refresh_grace!` を追加。
- `app/controllers/concerns/preference/refresh_token_transport.rb`:
  2 つの呼び出し経路（`load_preference_record_from_refresh_token!` と
  `refresh_refresh_token_lifetime`）でグレース戻り値を尊重。後者には `@preference_refresh_grace`
  ガードを追加し二重ローテーションを防止。

グレースロジックは `SingleUseToken`（app/org/com 共通）と
`Preference::Base`（共有 concern）に置いたため、3 サーフェスへ自動的に波及する（surface 混在なし）。

## A = Slice 9（ローカル鍵再生成の可視化）

`tmp/local_jwt_keysets.json` が消える（`rails tmp:clear` / 新規 clone / CI
/ コンテナ再作成）と dev/test で鍵が再生成され、再起動前に発行したトークンが検証失敗する旧症状が一度だけ再現する。これを気付けるよう、
`LocalKeysetInstaller` が store ミスで鍵を**新規生成した時に `jwt.local_keyset.regenerated`
警告**を出す。本番は Secrets Manager 由来で影響なし。鍵の挙動自体は不変。

## テスト

- `test/models/app_preference_test.rb`: `rotated_within_grace?`
  の BVA（窓内/窓外/自己参照/未消費）とrotate! 後の親がグレース対象になること。
- `test/controllers/concerns/preference/base_extra_coverage_test.rb`: グレースで replacement を採用し Cookie を消さないこと、窓外・replacement 無しは compromise になること。
- `test/unit/jit/security/jwt/local_keyset_installer_test.rb`: 新規生成で警告、store 再利用で無警告。

## Preference::Token テストドリフト（解決済み）

`Preference::Token` に対する method-missing 群が**本変更前から**存在していた（`audience_matches?` /
`host_matches?` / `validate_payload` / `report_invalid_payload` / `report_invalid_header` /
`report_claim_error` / `report_decode_error` / `valid_header?` / `normalize_audiences`）。
`test/controllers/concerns/preference/jwt_and_color_theme_test.rb` と `base_test.rb` で発生。

原因: クレーム/ヘッダ検証ヘルパーは `Security::Jwt::PreferenceTokenCodec` の
**private メソッド**へ移設済みだが、`Preference::Token`（後方互換ファサード）の委譲が refactor 時に欠落していた。ファサードの doc コメントは「public
API と **test-facing helper methods**
を保持する」と明記しているのに、ヘルパー委譲が実体から落ちていた（コメントと実装の不整合）。

対応: `app/controllers/concerns/preference/token.rb` にヘルパーの
**private 委譲**（`codec.send(:...)`）を復活。ファサードの公開面は広げず、既存テストが各ヘルパーを
`send`
で個別に検証できる契約を回復。テストはロジックの実体（codec）を間接的に叩くため、振る舞いは不変。`jwt_and_color_theme_test.rb`
/ `base_test.rb` ともに緑化。
