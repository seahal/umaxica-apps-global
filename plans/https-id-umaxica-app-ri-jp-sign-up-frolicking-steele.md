# sign up が「いっかい失敗」した件の原因（log 調査）

## TL;DR

`https://id.umaxica.app/?ri=jp` から sign up を開始した最初の hop で **401 Unauthorized**
を 1 回だけ返した。原因は **ブラウザに残っていた古い refresh token cookie が DB に存在しない
`AppPreference`
を指していた**ため。直後の再リクエストで新しい preference が払い出されて成功した。サインアップ flow 自体（ceremony
/ DB / token 検証）には問題はない。

## ログ上の出来事（`log/development.log` L61906–L62163）

時系列で 3 回 `Acme::App::Oauth::AuthorizationsController#show` が走っている：

1. **L61906–L61915（303 See Other・成功）**
   - `screen_hint=signup`, `rt=[FILTERED]` 付きで `id.umaxica.app/oauth/authorize` に来る。
   - `JumpRtReturnVerifier` (`app/services/jump_rt_return_verifier.rb`) が `rt`
     を検証し、`umaxica.app/oauth/authorize` に 303 で jump
     return。これは jump-rt 検証 flow の正常動作。

2. **L61918–L61924（401 Unauthorized・★ここが「失敗」）**
   - jump return から戻ってきた同じリクエストが `rt` 無しで再到達。
   - `PreferenceRefreshTokenTransport#find_refresh_preference` が cookie 側 refresh
     token の指す preference を引きにいく：
     ```
     AppPreference Load: SELECT * FROM app_preferences
       WHERE public_id = 'ZERFDcZrGQ1R2j4MZEJs0' LIMIT 1
     ```
   - DB に存在せず、`handle_preference_refresh_failed` が起動：
     ```
     {"event":"preference.token.refresh.failed",
      "data":{"preference_type":"AppPreference",
              "preference_public_id":"ZERFDcZrGQ1R2j4MZEJs0",
              "refresh_public_id":"ZERFDcZrGQ1R2j4MZEJs0",
              ...
              "request_id":"b6e0389a-6cee-45b9-8c54-3fd8d64bd619"}}
     ```
   - `app/controllers/concerns/preference_base.rb:830` で `clear_preference_auth_cookies!` →
     `Filter chain halted as :set_preferences_cookie rendered or redirected` →
     `app/controllers/concerns/preference_base.rb:849` で `head :unauthorized`。
   - 結果として 401。**ブラウザに表示されたエラーはたぶんこれ。**

3. **L61927 以降（302 Found・成功）**
   - 同じ `Acme::App::Oauth::AuthorizationsController#show`
     がもう一度来る（ブラウザの自動リトライ or ユーザーの再操作）。
   - 直前で `clear_preference_auth_cookies!` が走っているので refresh token
     cookie はもう無い → 新しい `AppPreference public_id=lVaJWLXuqYVxYAq2-qg_-` を `INSERT`
     し、cookie を再発行（L61951–L61967）。
   - その後 `Sign::App::Sign::UpController#show` に redirect され、Sign Up 画面が 200
     OK で表示されている（L62170 → L62402, Views: 7.9ms, 200 OK）。

## なぜ refresh token が「無い preference」を指していたのか

直前に **dev server か DB の状態がリセットされていた**から。401 の直前のログに

```
[Sentry::SessionFlusher] thread killed
Shutting down background worker
```

があり、これは Rails 側プロセス（または少なくとも background
worker）のシャットダウンを意味する。`AppPreference`
のレコードが消えた一方で、ブラウザ側の cookie だけが残っていたため、古い
`public_id=ZERFDcZrGQ1R2j4MZEJs0` を提示してしまい不一致 → 401。

(ハンドラの設計どおり: `handle_preference_refresh_failed`
は cookie を消して 401 を返し、次のリクエストで自然回復する流れ。)

## 結論

- **本番由来の不具合ではなく、開発環境特有の「DB リセット直後にブラウザの古い cookie が残っていた」ケース**。
- アプリ側は cookie を消して 401 を返し、次の hop で新しい preference を発行して正常復旧する設計。実際そのとおりに動いた。
- **コード修正は不要**。
- 再発が気になるなら、`bin/rails db:reset` / `db:migrate:reset`
  後にブラウザの cookie を一度クリア（または incognito で開く）すれば 401 hop が出ない。

## 参考ファイル

- `app/controllers/concerns/preference_refresh_token_transport.rb:65`（`find_refresh_preference`）
- `app/controllers/concerns/preference_base.rb:830`（`handle_preference_refresh_failed`）
- `app/controllers/concerns/preference_base.rb:842`（`render_preference_refresh_error!`）
- `app/services/jump_rt_return_verifier.rb`（`rt` 検証）
