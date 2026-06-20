# typed: false
# frozen_string_literal: true

require "test_helper"

class StylesheetTagsTest < ActiveSupport::TestCase
  VITE_LAYOUT_PATHS = [
    "app/views/layouts/application.html.erb",
    "app/views/layouts/acme/app/application.html.erb",
    "app/views/layouts/acme/com/application.html.erb",
    "app/views/layouts/acme/org/application.html.erb",
    "app/views/layouts/sign/app/application.html.erb",
    "app/views/layouts/sign/com/application.html.erb",
    "app/views/layouts/sign/org/application.html.erb",
  ].freeze

  test "layouts do not use stylesheet_link_tag for web ui css" do
    paths = VITE_LAYOUT_PATHS

    paths.each do |path|
      contents = Rails.root.join(path).read

      assert_not_includes contents, "stylesheet_link_tag", "web UI CSS must come from Vite in #{path}"
      assert_includes contents, "vite_client_tag", "missing Vite client in #{path}"
      assert_includes contents, 'vite_typescript_tag "application"', "missing Vite entrypoint in #{path}"
    end
  end

  test "application-owned importmap entrypoints are retired" do
    assert_not Rails.root.join("config/importmap.rb").exist?, "config/importmap.rb must not be restored"
    assert_not Rails.root.join("bin/importmap").exist?, "bin/importmap must not be restored"

    gemfile = Rails.root.join("Gemfile").read

    assert_no_match(/^\s*gem\s+["']importmap-rails["']/, gemfile)
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
