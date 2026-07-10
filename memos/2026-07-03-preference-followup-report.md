# 2026-07-03 Preference Follow-up Remediation Report

## 1. Summary

このパスでは、2026-07-02 Preference audit 後の残件だけを扱った。Preference は UX
state のみであり、認証・認可・user presence・step-up・operator 判定・account/org/avatar
authority には使わない方針を維持した。新しい route namespace は追加していない。`/web/v1/cookie`
も追加していない。

実装した主な変更は次の通り。

- `Base::Com::ApplicationController` と `Core::Com::ApplicationController` に `PreferenceAdoption`
  を追加した。
- dead code の `PreferenceBase#show_cookie_banner?` を削除した。
- cookie consent の boolean 入力を strict にし、任意の非空文字列が consent になる問題を修正した。
- CSRF、cross-surface preference token、option tampering、invalid cookie consent の regression
  tests を追加した。
- `db:verify_no_schema_drift` rake task を追加した。
- `docs/architecture/preference-behavior-contract.md` を最小更新した。

## 2. Baseline Failures Before Editing

編集前に実行した baseline command:

```sh
bin/rails test test/controllers/concerns/preference/adoption_test.rb test/controllers/concerns/preference/jwt_and_color_theme_test.rb test/controllers/concerns/preference/no_implicit_callbacks_test.rb
bin/rails test test/controllers/concerns/preference/adoption_test.rb
bin/rails test test/controllers/concerns/preference/no_implicit_callbacks_test.rb
bin/rails test test/integration/com_visitor_preference_current_behavior_test.rb
```

再現した baseline failure:

- `PreferenceTokenTest#test_token_issued_on_id_host_decodes_on_same_TLD_sibling_when_audience_is_configured`
- `PreferenceTokenTest#test_token_issued_on_id_host_can_decode_for_the_same_host_without_ENV_audience_config`

ユーザー指定の既知 5 failures のうち、今回の編集前実行で再現したのは `jwt_and_color_theme_test`
の 2 件のみだった。`adoption_test` 2 件と `no_implicit_callbacks_test`
1 件は、この作業時点では単独実行でも同時指定でも再現しなかった。

## 3. Final Failures After Editing

対象範囲の broader command:

```sh
bin/rails test test/controllers/concerns/preference test/integration/preference_*_test.rb test/integration/cross_surface_token_test.rb
```

結果:

- 342 runs, 1420 assertions
- 2 failures, 0 errors

残った 2 failures は baseline と同じ `jwt_and_color_theme_test` の 2 件。

Full suite command:

```sh
bin/rails test
```

結果:

- 8828 runs, 41205 assertions
- 105 failures, 0 errors

full suite の failures は auth、OIDC、withdrawal、social、JWT、controller inheritance、security
invariant など広範囲に散っており、この Preference follow-up の affected
set で増えた failure ではない。

## 4. Failure Delta

Preference affected set の failure delta は 0。編集前から再現していた `jwt_and_color_theme_test`
2 件が残っている。

full suite は 105 failures だが、今回のスコープ外の既存 dirty worktree / develop baseline
failure として扱う。

## 5. WI-1 Result

Severity: High.

include 漏れと判断した根拠:

- `Base::Com::ApplicationController` と `Core::Com::ApplicationController` は
  `AuthenticationVisitor` と `PreferenceGlobal` を持ち、signed-in visitor request が preference
  bootstrap/recreation path に到達できる。
- app/org sibling controller には同じ位置に `PreferenceAdoption` が含まれていた。
- `PreferenceTransport#restore_preference_from_resource!` は `adopt_preference_for!`
  がない場合に mirror synchronization を実行できない。
- RED test で `Base::Com::ApplicationController` / `Core::Com::ApplicationController` の include
  parity が落ち、base/com signed-in visitor request で `VisitorPreference`
  mirror が作られないことを確認した。

Added tests:

- `test/integration/com_visitor_preference_current_behavior_test.rb`
  - base/com include parity
  - core/com include parity
  - base/com signed-in visitor + missing preference refresh cookie + ComPreference recreation +
    VisitorPreference mirror synchronization

Changed files:

- `app/controllers/base/com/application_controller.rb`
- `app/controllers/core/com/application_controller.rb`
- `test/integration/com_visitor_preference_current_behavior_test.rb`
- `docs/architecture/preference-behavior-contract.md`

Existing adoption failures:

- 編集前・編集後とも `adoption_test` はこの環境では green。ユーザー指定の既知 adoption
  failures は再現しなかったため、WI-1 で fixed とは記録しない。

core/com end-to-end test:

- core/com は include parity の structural
  test を追加した。base/com で実バグ経路をカバーした。core/com の同等 e2e は追加していない。理由は、今回の residual
  gap は include parity の欠落であり、core/com は Preference HTML
  authority ではないため、追加 fixture/route setup の重さに対して structural
  coverage の方がこの pass のスコープに合っていたため。

## 6. WI-2 Result

Dead code 削除根拠:

- `PreferenceBase#show_cookie_banner?` は常に false を返すだけだった。
- canonical banner decision は `PreferenceWebCookieEndpoint#show_banner?` と `GET /web/v0/cookie` の
  `{ show_banner: bool }` response。

Removed/updated tests:

- `test/controllers/concerns/preference/base_included_do_test.rb` の existence-only
  assertion を削除。
- `test/controllers/concerns/preference/base_test.rb` の return-only assertion を削除。
- `test/controllers/concerns/preference/web_cookie_endpoint_test.rb` は canonical `show_banner?`
  behaviorを維持している。

## 7. WI-3 Result

Added negative tests:

- `test/integration/preference_web_csrf_test.rb`
  - app/com/org の `PATCH /web/v0/theme`
  - app/com/org の `PATCH /web/v0/cookie`
  - CSRF token なしで normal Rails CSRF behavior により reject されることを確認。
- `test/integration/cross_surface_token_test.rb`
  - app preference token が com cookie endpoint で banner suppression にならないこと。
  - com preference token が org cookie endpoint で banner suppression にならないこと。
  - org preference token が com cookie endpoint で banner suppression にならないこと。
- `test/integration/preference_option_tampering_test.rb`
  - invalid theme option id を送っても canonical DB preference が変わらないこと。
  - invalid timezone value `Mars/Olympus` を送っても canonical DB preference が変わらないこと。
- `test/integration/preference_cookie_invalid_values_test.rb`
  - `consented: "banana"`、array、nested hash、nil が 400 で reject され、DB state を変えないこと。

Bugs found and fixed:

- `PATCH /web/v0/cookie` が `ActiveModel::Type::Boolean` により任意の非空文字列を truthy
  consent として扱っていた。`PreferenceWebCookieEndpoint#cast_cookie_boolean` を strict boolean
  parsing に変更し、invalid value は `ActionController::BadRequest` で reject するようにした。

Bugs found but deferred:

- `PreferenceAdoption#sync_preferences!` の conflict winner integration test を一度追加したが、test
  body 実行前に既存 fixture FK violation で停止した。
  - Reproduction: `bin/rails test test/integration/preference_adoption_conflict_winner_test.rb`
  - Actual: `org_preference_adult_content_gates.preference_id` が `org_preferences`
    に存在しないという fixture foreign key violation。
  - Expected: test body が実行され、updated_at winner behavior を検証できること。
  - Follow-up: fixture/schema
    baseline を直した後で、AppPreference と ClientPreference の双方向 winner test を再追加する。
  - Final state: 新規 red test は残していない。

Tests intentionally not added:

- `/edge/v0` timezone JSON update
  path は現行 routes で見つからなかった。`bin/rails routes -g 'timezone|edge/v0'` では timezone
  update は HTML preference route のみで、edge は cookie/token/dbsc 系だったため、edge timezone
  test は追加していない。

## 8. WI-4 Result

Rake task:

- `lib/tasks/db_verify_no_schema_drift.rake` を追加。
- task name: `db:verify_no_schema_drift`
- Rails の existing `db:schema:dump` task を使って schema dump を生成し、`config/database.yml` の
  `schema_dump` から検出した dump files を `git diff --name-only` で検査する。
- migrations、database create/drop、data mutation は行わない。
- drift がある場合は drifted files を表示して non-zero exit する。

Verification:

```sh
bin/rails --tasks | rg 'db:verify_no_schema_drift'
bin/rails db:verify_no_schema_drift
```

task は load された。`bin/rails db:verify_no_schema_drift` は non-zero で終了し、22 個の schema dump
files の drift を検出した。task 実行により生成された範囲外の schema
dump 差分は戻した。編集前から dirty だった `db/avatar_structure.sql` は触らず保持した。

Contract doc update:

- `docs/architecture/preference-behavior-contract.md` に、visitor authentication と preference
  recreation path を持つ com-tier `ApplicationController` は `PreferenceAdoption` include
  parity を保つ必要があることを追記。
- cookie banner canonical behavior は `GET /web/v0/cookie` の `{ show_banner: bool }` と
  `PreferenceWebCookieEndpoint#show_banner?` であり、削除済み `PreferenceBase#show_cookie_banner?`
  は contract ではないことを追記。

## 9. Language Policy Handling

`AGENTS.md` は code、test names、comments、docs、repository
documentation は English とする方針を要求している。一方、ユーザーは planning と final
report は日本語可と指定した。

今回の解決:

- code、test names、English architecture doc、rake task は English。
- この memo/final report はユーザー指定に従い日本語。

## 10. Residual Risks

- `jwt_and_color_theme_test` の 2 baseline failures は残っている。
- full suite は 105 failures で、今回の Preference affected set 以外に広い既存失敗がある。
- PreferenceAdoption conflict winner の integration test は fixture FK
  baseline が直るまで再追加できない。
- `db:verify_no_schema_drift` は現在の DB/schema
  state に drift があるため non-zero になる。task 自体は drift 検出として機能しているが、clean
  baseline での成功確認は未完了。

## 11. Next Recommended Checks

- `jwt_and_color_theme_test` の 2 baseline failures を別 task で修正する。
- fixture FK violation を直し、PreferenceAdoption updated_at winner test を再追加する。
- schema dump drift を clean DB workflow で整理し、`bin/rails db:verify_no_schema_drift`
  が成功する状態を作る。
- full suite の 105 failures は Preference follow-up とは分離し、auth/OIDC/withdrawal/social/JWT
  clusters ごとに triage する。
