# typed: false
# frozen_string_literal: true

require "test_helper"

class StylesheetTagsTest < ActiveSupport::TestCase
  VITE_LAYOUT_PATHS = [
    "app/views/layouts/acme/app/application.html.erb",
    "app/views/layouts/acme/com/application.html.erb",
    "app/views/layouts/acme/org/application.html.erb",
    "app/views/layouts/sign/app/application.html.erb",
    "app/views/layouts/sign/com/application.html.erb",
    "app/views/layouts/sign/org/application.html.erb",
  ].freeze

  test "sign layouts include sign main stylesheet" do
    paths = [
      "app/views/layouts/sign/app/application.html.erb",
      "app/views/layouts/sign/com/application.html.erb",
      "app/views/layouts/sign/org/application.html.erb",
    ]

    paths.each do |path|
      contents = Rails.root.join(path).read

      assert_match(
        /(stylesheet_link_tag\s+\"sign\/main\")|(\"sign\/main\")/, contents,
        "missing sign/main in #{path}",
      )
    end
  end

  test "acme layouts include acme main stylesheet" do
    paths = [
      "app/views/layouts/acme/app/application.html.erb",
      "app/views/layouts/acme/com/application.html.erb",
      "app/views/layouts/acme/org/application.html.erb",
    ]

    paths.each do |path|
      contents = Rails.root.join(path).read

      assert_match(
        /(stylesheet_link_tag\s+\"acme\/main\")|(\"acme\/main\")/, contents,
        "missing acme/main in #{path}",
      )
    end
  end

  test "application layouts load javascript through external vite entrypoint" do
    VITE_LAYOUT_PATHS.each do |path|
      contents = Rails.root.join(path).read

      assert_includes contents, "csp_meta_tag", "missing csp_meta_tag in #{path}"
      assert_includes contents, 'vite_javascript_tag "application"', "missing Vite entrypoint in #{path}"
      assert_includes contents, "nonce: true", "Vite entrypoint must carry CSP nonce in #{path}"
      assert_includes(
        contents,
        '"data-turbo-eval": "false"',
        "Vite entrypoint must not be re-evaluated by Turbo with a response-local nonce in #{path}",
      )
      assert_not_includes(
        contents,
        'vite_javascript_tag "application", nonce: true, "data-turbo-track": "reload"',
        "Vite entrypoint nonce changes per response, so Turbo reload tracking would loop in #{path}",
      )
      assert_not_includes contents, "javascript_importmap_tags", "inline importmap must not be used in #{path}"
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

  test "step up passkey views use vite stimulus identifier" do
    paths = [
      "app/views/sign/app/verification/passkeys/new.html.erb",
      "app/views/sign/com/verification/passkeys/new.html.erb",
      "app/views/sign/org/verification/passkeys/new.html.erb",
      "app/views/sign/app/in/challenge/passkeys/new.html.erb",
      "app/views/sign/org/in/challenge/passkeys/new.html.erb",
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
