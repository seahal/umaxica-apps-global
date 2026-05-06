# Remove redundant acme configuration routes

## Context

`acme.rb` の app / org スコープに `TODO: consider this. we did move this to sign routing.`
というコメントがある。configuration ルートと関連コントローラ・ビューが sign 側に完全移行済みにもかかわらず acme 側にスタブとして残っている。com スコープにも同じ構造が TODO なしで残っている。

sign 側は emails, totps, passkeys, secrets, sessions, activities,
withdrawal 等を含む完全版。acme 側は show + emails
(new/create/edit/update) のみのスタブ。レイアウトのヘッダーは既に `sign_*_configuration_url`
にリンクしているが、フッターと roots/index は acme 側を参照している。

acme/com/configuration/emails/edit.html.erb にコピペバグあり（`acme_app_*` を使っていて `acme_com_*`
であるべき）。

## Approach

### Step 1: Route deletion — `config/routes/acme.rb`

以下のブロックを削除:

- **com scope** (L35-39): `resource :configuration` + `namespace :configuration { emails }`
- **app scope** (L71-76): TODO comment + `resource :configuration` +
  `namespace :configuration { emails }`
- **org scope** (L129-134): TODO comment + `resource :configuration` +
  `namespace :configuration { emails }`

### Step 2: Controller deletion

- `app/controllers/acme/app/configurations_controller.rb`
- `app/controllers/acme/com/configurations_controller.rb`
- `app/controllers/acme/org/configurations_controller.rb`
- `app/controllers/acme/app/configuration/emails_controller.rb`
- `app/controllers/acme/org/configuration/emails_controller.rb`

（acme/com/configuration/emails_controller.rb は存在しない）

### Step 3: View deletion

- `app/views/acme/app/configurations/` (show.html.erb)
- `app/views/acme/com/configurations/` (show.html.erb)
- `app/views/acme/org/configurations/` (show.html.erb)
- `app/views/acme/app/configuration/emails/` (edit.html.erb 等)
- `app/views/acme/com/configuration/emails/` (edit.html.erb 等)
- `app/views/acme/org/configuration/emails/` (edit.html.erb 等)

### Step 4: Link re-pointing

acme のレイアウト・ルートページで `acme_*_configuration_path` を使っている箇所を
`sign_*_configuration_url`
に変更する。ヘッダーは既に sign を向いているので、フッターと roots/index のみ:

| File                                                  | Change                                                       |
| ----------------------------------------------------- | ------------------------------------------------------------ |
| `app/views/layouts/acme/app/application.html.erb` L50 | `acme_app_configuration_path` → `sign_app_configuration_url` |
| `app/views/layouts/acme/org/application.html.erb` L50 | `acme_org_configuration_path` → `sign_org_configuration_url` |
| `app/views/acme/app/roots/index.html.erb` L20         | `acme_app_configuration_path` → `sign_app_configuration_url` |
| `app/views/acme/org/roots/index.html.erb` L19         | `acme_org_configuration_path` → `sign_org_configuration_url` |

### Step 5: Test deletion and update

- `test/controllers/acme/com/configurations_controller_test.rb` — delete file
- `test/controllers/acme/coverage_test.rb` — delete configuration test cases (around L15, L24)

### Step 6: Empty directory cleanup

削除後に空になるディレクトリを確認し削除:

- `app/controllers/acme/app/configuration/`
- `app/controllers/acme/com/configuration/` (if exists)
- `app/controllers/acme/org/configuration/`
- `app/views/acme/*/configurations/`
- `app/views/acme/*/configuration/`

## Verification

1. `bundle exec rails routes | grep acme.*configuration` — routes are gone
2. `grep -r "acme.*configuration" app/ test/ config/routes/` — no remaining references
3. `bundle exec rubocop`
4. `bundle exec erb_lint .`
5. `bundle exec rails test test/controllers/acme/` — acme tests pass
