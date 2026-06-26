# typed: false
# frozen_string_literal: true

require "test_helper"

class StylesheetTagsTest < ActiveSupport::TestCase
  VITE_LAYOUT_PATHS = [
    ["app/views/layouts/application.html.erb", "application"],
    ["app/views/layouts/acme/app/application.html.erb", "entrypoints/acme/app"],
    ["app/views/layouts/acme/com/application.html.erb", "entrypoints/acme/com"],
    ["app/views/layouts/acme/org/application.html.erb", "entrypoints/acme/org"],
    ["app/views/layouts/sign/app/application.html.erb", "entrypoints/sign/app"],
    ["app/views/layouts/sign/com/application.html.erb", "entrypoints/sign/com"],
    ["app/views/layouts/sign/org/application.html.erb", "entrypoints/sign/org"],
    ["app/views/core/dev/roots/index.html.erb", "entrypoints/core/dev"],
  ].freeze
  TURNSTILE_LAYOUT_PATHS = [
    "app/views/layouts/acme/app/application.html.erb",
    "app/views/layouts/acme/com/application.html.erb",
    "app/views/layouts/acme/org/application.html.erb",
    "app/views/layouts/sign/app/application.html.erb",
    "app/views/layouts/sign/com/application.html.erb",
    "app/views/layouts/sign/org/application.html.erb",
  ].freeze

  test "layouts do not use stylesheet_link_tag for web ui css" do
    VITE_LAYOUT_PATHS.each do |path, entrypoint|
      contents = Rails.root.join(path).read

      assert_not_includes contents, "stylesheet_link_tag", "web UI CSS must come from Vite in #{path}"
      assert_includes contents, "csp_meta_tag", "missing CSP nonce meta tag in #{path}"
      assert_includes contents, "vite_client_tag nonce: true", "Vite client must carry a CSP nonce in #{path}"
      assert_includes contents, "vite_react_refresh_tag nonce: true",
                      "React refresh preamble must carry a CSP nonce in #{path}"
      assert_includes contents, %(vite_typescript_tag "#{entrypoint}"),
                      "missing Vite entrypoint in #{path}"
    end
  end

  test "application-owned importmap entrypoints are retired" do
    assert_not Rails.root.join("config/importmap.rb").exist?, "config/importmap.rb must not be restored"
    assert_not Rails.root.join("bin/importmap").exist?, "bin/importmap must not be restored"

    gemfile = Rails.root.join("Gemfile").read

    assert_no_match(/^\s*gem\s+["']importmap-rails["']/, gemfile)
  end

  test "sign and acme layouts own turnstile api loading" do
    TURNSTILE_LAYOUT_PATHS.each do |path|
      contents = Rails.root.join(path).read

      assert_includes contents, 'render "layouts/shared/cloudflare_turnstile_api"',
                      "Turnstile API loading must be layout-owned in #{path}"
    end
  end

  test "turnstile widget partials do not load the api script" do
    paths = [
      "app/views/shared/_cloudflare_turnstile_visible.html.erb",
      "app/views/shared/_cloudflare_turnstile_stealth.html.erb",
    ]

    paths.each do |path|
      contents = Rails.root.join(path).read

      assert_not_includes contents, "cloudflare_turnstile_api",
                          "Turnstile widget partials must not own API script loading in #{path}"
      assert_not_includes contents, "challenges.cloudflare.com/turnstile/v0/api.js",
                          "Turnstile widget partials must not load external scripts in #{path}"
    end
  end

  test "development can serve vite auto-build output" do
    development_config = Rails.root.join("config/environments/development.rb").read

    assert_includes(
      development_config,
      "config.public_file_server.enabled = true",
      "development must serve public/vite-dev assets when Vite autoBuild emits static files",
    )
  end

  test "vite css entrypoints exist under src/styles" do
    paths = [
      "src/styles/application.css",
      "src/styles/base.css",
      "src/styles/acme.css",
      "src/styles/sign.css",
    ]

    paths.each do |path|
      assert_predicate Rails.root.join(path), :exist?, "#{path} must exist"
    end
  end

  test "application entrypoint imports the vite stylesheet graph" do
    contents = Rails.root.join("src/entrypoints/application.ts").read

    assert_includes contents, 'import "@styles/application.css";'
  end

  test "surface entrypoints proxy to the shared application entrypoint" do
    paths = [
      "src/entrypoints/acme/app.ts",
      "src/entrypoints/acme/com.ts",
      "src/entrypoints/acme/org.ts",
      "src/entrypoints/core/dev.ts",
      "src/entrypoints/sign/app.ts",
      "src/entrypoints/sign/com.ts",
      "src/entrypoints/sign/org.ts",
    ]

    paths.each do |path|
      contents = Rails.root.join(path).read

      assert_includes contents, 'import "../application";', "#{path} must proxy to shared application entrypoint"
    end
  end

  test "web ui css is no longer sourced from app/assets/stylesheets" do
    paths = [
      "app/assets/stylesheets/application.css",
      "app/assets/stylesheets/acme/main.css",
      "app/assets/stylesheets/acme/app/main.css",
      "app/assets/stylesheets/acme/com/main.css",
      "app/assets/stylesheets/acme/org/main.css",
      "app/assets/stylesheets/sign/main.css",
      "app/assets/stylesheets/sign/app/main.css",
      "app/assets/stylesheets/sign/org/main.css",
      "app/assets/stylesheets/tailwind.css",
      "app/assets/builds/tailwind.css",
    ]

    paths.each do |path|
      assert_not Rails.root.join(path).exist?, "#{path} must be removed from app/assets"
    end
  end

  test "step up passkey views use vite stimulus identifier" do
    paths = [
      "app/views/sign/app/verification/passkeys/new.html.erb",
      "app/views/sign/com/verification/passkeys/new.html.erb",
      "app/views/sign/org/verification/passkeys/new.html.erb",
      "app/views/sign/app/sign/in/challenge/passkeys/new.html.erb",
      "app/views/sign/org/sign/in/challenge/passkeys/new.html.erb",
    ]

    paths.each do |path|
      contents = Rails.root.join(path).read

      assert_includes contents, 'data-controller="step-up-passkey"', "missing Vite Stimulus identifier in #{path}"
      assert_not_includes contents, "step_up-passkey", "legacy importmap-style identifier must not be used in #{path}"
      assert_not_includes contents, "step_up_passkey",
                          "source filename must not be used as a Stimulus identifier in #{path}"
    end
  end
end
