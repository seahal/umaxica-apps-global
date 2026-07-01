# Rails layout reset prompt and reference ERB

## Purpose

Rails の `app/views/layouts/<surface>/<tld>/application.html.erb` を整理する。目的は、layout ごとの無駄な差異を減らし、controller の surface/tld と layout を 1:1 で対応させること。

この作業では、GitHub 上の状態は参照しない。未 push のローカル状態を正とする。

## Hard rules

- 新しい partial / 部分テンプレートを増やさない。
- `render "layouts/shared/surface_header"` や `render "layouts/shared/surface_footer"` のような新規 shared partial は作らない。
- 既存の shared partial は消さない。
  - `layouts/shared/flash_messages`
  - `layouts/shared/current_banner`
  - `layouts/shared/cloudflare_turnstile_api`
  - `layouts/shared/footer_cookie_controls`
  - `layouts/shared/footer_theme_controls`
  - `layouts/shared/copyright`
- `content_for` は使わない。
- 名前付き `yield` は使わない。
- 通常の `<%= yield %>` だけを使う。
- layout 冒頭で動的な変数を作らない。
- layout 冒頭に置いてよい Ruby 変数は `title_site` だけ。
- `surface = ...` は書かない。
- `tld = ...` は書かない。
- `vite_entrypoint = ...` は書かない。
- `home_path = ...` や `settings_path = ...` のような route helper の事前変数化はしない。
- `vite_typescript_tag` の entrypoint は literal で直書きする。
- route helper は使用箇所に直接書く。
- `t(..., default: ...)` は禁止。i18n key は locale file に必ず追加する。
- Tailwind CSS の class はいったん外す。
- Tailwind の package/config/dependency は消さない。
- `stylesheet_link_tag "tailwind"` は使わない。
- `stylesheet_link_tag` で CSS を読む形にはしない。
- `javascript_importmap_tags` は消さない。
- `turbo-refresh-method` と `turbo-refresh-scroll` は消さない。
- Cloudflare Turnstile API の常時読み込みは消さない。
- `<meta charset="utf-8">` を `<head>` の早い位置に入れる。

## Layout targets

基本の canonical layout は以下。

```text
auth/app
auth/com
auth/org

base/app
base/com
base/org

core/app
core/com
core/org

side/app
side/com
side/org

palm/app
```

`palm/com` と `palm/org` は存在しないので作らない。

旧 layout 参照が残っている場合は、意味を確認して新 layout へ移行する。特に、古い `base/acme` を参照している箇所が残っていれば、新しい `auth/base` 参照へ移行する。ただし、存在しない target layout を推測で増やさない。ローカルの controller namespace と route/helper の実態を優先する。

## Asset policy

CSS は Vite 側で扱う方針。ただし今回の reset では Tailwind をいったん外す。

やること:

- ERB layout から Tailwind utility class を外す。
- `stylesheet_link_tag` による CSS 読み込みを外す。
- Vite entrypoint は残す。
- Tailwind の config/package は消さない。
- 後日 Tailwind を再接続するときは `src/styles` に CSS を置く。

後日再接続する場合の想定構成:

```text
src/
  entrypoints/
    auth/
      app.ts
      com.ts
      org.ts
  styles/
    application.css
```

今回、entrypoint 側で CSS import を外す場合は、空ファイル lint 対策として以下程度にする。

```ts
export {};
```

後日 Tailwind を戻すときに、entrypoint 側で以下のように読み込む。

```ts
import "../../styles/application.css";
```

## Semantic HTML policy

- `header` を使う。
- `nav` を使う。
- 複数の `nav` には `aria-label` を付ける。
- リンク群は `ul` / `li` にする。
- ページ本文は `main id="main"` に置く。
- 共通下部領域は `footer` に置く。
- Cookie/theme controls は本文ではなく補助操作なので `aside` を使う。
- copyright は文書区分ではないので `section` ではなく `div` を使う。
- layout のブランド表示はページ本文の見出しではないので、`h1` ではなく `p` と `strong` にする。
- ページ固有の `h1` は view / React / Inertia 側に置く。

## Controller/layout contract

controller の surface/tld と layout を 1:1 対応させる。

動的 resolver は使わない。各 surface/tld の base controller で explicit に layout を指定する。

例:

```ruby
module Auth
  module App
    class ApplicationController < ::ApplicationController
      layout "auth/app/application"
    end
  end
end
```

`Auth::Com` なら `layout "auth/com/application"`、`Base::App` なら `layout "base/app/application"` のように、明示的に書く。

`Palm` は `Palm::App` だけ。`Palm::Com` / `Palm::Org` を作らない。

## Tests to add or update

既存の stylesheet presence test は、layout contract test に置き換える。

確認すること:

- canonical layout が存在する。
- `palm/app` は存在する。
- `palm/com` と `palm/org` は存在しない。
- layout に `<meta charset="utf-8">` がある。
- layout に `data-theme="<%= theme_cookie_value %>"` がある。
- layout に `class="<%= theme_html_class %>"` がある。
- layout に turbo refresh meta がある。
- layout に `javascript_importmap_tags` がある。
- layout に `vite_typescript_tag "entrypoints/..."` がある。
- layout に `cloudflare_turnstile_api` がある。
- layout に `current_banner` がある。
- layout に `footer_cookie_controls` がある。
- layout に `footer_theme_controls` がある。
- layout に `copyright` がある。
- layout に `content_for` がない。
- layout に `yield :head` / `yield :nav_links` / `yield :root_link` / `yield :footer_links` がない。
- layout に `t(..., default: ...)` がない。
- layout に Tailwind utility class がない。
- layout に `stylesheet_link_tag` がない。
- layout 冒頭に `surface =` / `tld =` / `vite_entrypoint =` / `*_path =` がない。

確認用 grep:

```bash
rg -n 'content_for|yield :|default:' app/views/layouts
rg -n 'stylesheet_link_tag|font-mono|bg-white|text-black|flex|border-|dark:' app/views/layouts
rg -n 'surface\s*=|tld\s*=|vite_entrypoint\s*=|_path\s*=' app/views/layouts
rg -n 'layouts/(acme|sign|apex)|layout\s+["'"'](acme|sign|apex)/|render\s+layout:\s*["'"'](acme|sign|apex)/' app test config
rg -n 'base/acme' app test config
```

## Implementation prompt

```text
Rails layout を reset してください。

GitHub 上の状態は見ないでください。未 push のローカル状態が正です。

対象は app/views/layouts/<surface>/<tld>/application.html.erb と、それを参照する controller/test/config です。

目的は、controller の surface/tld と layout を 1:1 対応させることです。layout は HTML5 の妥当な semantic tag を使い、Tailwind class はいったん全て外してください。ただし Tailwind の package/config/dependency は削除しないでください。後日再設定します。

新しい partial / 部分テンプレートは増やさないでください。既存の shared partial は残してください。

残す shared partial:
- layouts/shared/flash_messages
- layouts/shared/current_banner
- layouts/shared/cloudflare_turnstile_api
- layouts/shared/footer_cookie_controls
- layouts/shared/footer_theme_controls
- layouts/shared/copyright

content_for は使わないでください。名前付き yield も使わないでください。使ってよい yield は本文用の <%= yield %> だけです。

layout 冒頭で作ってよい変数は title_site だけです。
次は禁止です:
- surface = ...
- tld = ...
- vite_entrypoint = ...
- home_path = ...
- settings_path = ...
- route helper の事前変数化
- "entrypoints/#{...}" のような動的 entrypoint 生成

vite_typescript_tag は layout ごとに literal で書いてください。
例: <%= vite_typescript_tag "entrypoints/auth/app", nonce: true, "data-turbo-eval": "false" %>

i18n の default: は禁止です。t(..., default: ...) を使わず、必要な key は locale file に追加してください。

HTML head には以下を含めてください:
- <meta charset="utf-8">
- display_meta_tags
- viewport meta
- turbo-refresh-method
- turbo-refresh-scroll
- csrf_meta_tags
- csp_meta_tag
- inertia_ssr_head
- render "layouts/shared/cloudflare_turnstile_api"
- javascript_importmap_tags
- vite_client_tag
- vite_react_refresh_tag
- vite_typescript_tag

Tailwind を外すため、stylesheet_link_tag は layout から削除してください。CSS は今回は読み込まないか、既存 Vite entrypoint に必要最小限だけ残してください。後日 CSS を戻す場合は src/styles/application.css を使う想定です。

HTML body は以下の semantic structure にしてください:
- header
- nav aria-label=...
- ul/li for nav links
- p/strong for brand display, not h1
- main id="main" with <%= yield %>
- footer
- footer nav aria-label=...
- aside for cookie/theme preference controls
- div for copyright

canonical layout targets:
- auth/app
- auth/com
- auth/org
- base/app
- base/com
- base/org
- core/app
- core/com
- core/org
- side/app
- side/com
- side/org
- palm/app

Do not create:
- palm/com
- palm/org

旧 layout 参照を確認してください。古い base/acme を参照している箇所が残っていれば、新しい auth/base 参照へ移行してください。ただし、存在しない layout pair を推測で増やさないでください。ローカルの controller namespace と route/helper の実態を優先してください。

controller は動的 resolver ではなく、各 surface/tld の base controller で explicit に layout を指定してください。
例:
layout "auth/app/application"
layout "base/app/application"
layout "core/org/application"

テストを更新してください。
- canonical layouts の存在確認
- palm/com と palm/org が存在しないこと
- content_for がないこと
- 名前付き yield がないこと
- i18n default: がないこと
- Tailwind class がないこと
- stylesheet_link_tag がないこと
- javascript_importmap_tags が残っていること
- Vite tag が literal entrypoint で書かれていること
- semantic tags が使われていること
- controller が explicit layout を使っていること
```

## Reference ERB: `app/views/layouts/auth/app/application.html.erb`

この ERB をお手本にして、他の layout を作ってください。各 layout では、`title_site`、i18n key、route helper、`current_banner` の `tld` / `domain`、footer controls の `scope`、Vite entrypoint を必ず literal で書き換えてください。

```erb
<%
  title_site = "#{ENV.fetch('BRAND_NAME')} (app)"
%>
<!DOCTYPE html>
<html lang="<%= get_language %>" data-theme="<%= theme_cookie_value %>" class="<%= theme_html_class %>">
<head>
  <meta charset="utf-8">
  <%= display_meta_tags site: title_site, title: page_title %>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="turbo-refresh-method" content="morph">
  <meta name="turbo-refresh-scroll" content="preserve">
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= inertia_ssr_head %>
  <%= render "layouts/shared/cloudflare_turnstile_api" %>
  <%= javascript_importmap_tags %>
  <%= vite_client_tag nonce: true %>
  <%= vite_react_refresh_tag nonce: true %>
  <%= vite_typescript_tag "entrypoints/auth/app", nonce: true, "data-turbo-eval": "false" %>
</head>

<body>
  <header>
    <nav aria-label="<%= t('auth.app.layout.nav.primary') %>">
      <div>
        <%= render "layouts/shared/flash_messages" %>
        <%= render "layouts/shared/current_banner", tld: :app, domain: :auth, region: :global %>
      </div>

      <% unless @hide_auth_navigation %>
        <ul aria-label="<%= t('auth.app.layout.nav.account') %>">
          <% if logged_in? %>
            <li><%= link_to t("auth.app.layout.nav.logout"), new_auth_app_sign_out_path %></li>
          <% else %>
            <li><%= link_to t("auth.app.layout.nav.sign_up"), auth_app_sign_up_path %></li>
            <li><%= link_to t("auth.app.layout.nav.log_in"), auth_app_sign_in_path %></li>
          <% end %>
        </ul>
      <% end %>
    </nav>

    <div aria-label="<%= t('auth.app.layout.brand') %>">
      <p>
        <strong>AUTH</strong>
        <%= link_to ENV.fetch("BRAND_NAME"), auth_app_root_path %>
        <span>(app)</span>
      </p>
    </div>
  </header>

  <main id="main">
    <%= yield %>
  </main>

  <footer>
    <nav aria-label="<%= t('auth.app.layout.nav.footer') %>">
      <ul>
        <% if logged_in? %>
          <li><%= link_to t("auth.app.preferences.footer.dashboard"), base_app_dashboard_url(ri: current_region_identifier, host: base_authority_host) %></li>
        <% else %>
          <li><%= link_to t("auth.app.preferences.footer.home"), auth_app_root_path %></li>
        <% end %>

        <li><%= link_to t("auth.app.preferences.footer.preference"), auth_app_settings_path %></li>
        <li><%= link_to t("auth.app.preferences.footer.settings"), auth_app_settings_emails_path %></li>
      </ul>
    </nav>

    <aside aria-label="<%= t('auth.app.layout.preferences') %>">
      <%= render "layouts/shared/footer_cookie_controls", scope: :app, base_host: base_authority_host %>
      <%= render "layouts/shared/footer_theme_controls", scope: :app %>
    </aside>

    <div aria-label="<%= t('auth.app.layout.copyright') %>">
      <%= render "layouts/shared/copyright" %>
    </div>
  </footer>
</body>
</html>
```
