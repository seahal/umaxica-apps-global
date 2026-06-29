# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class TurnstileFormsTest < ActionDispatch::IntegrationTest
  def setup
    # Map of paths that contain Turnstile forms with turbo disabled
    # Format: [Host ENV Name, Path, Description]
    @turnstile_form_paths = [
      { name: "Sign::App registration email", env_key: "PRIVATE_AUTH_SERVICE_URL", path: "/sign/up/email/new" },
      { name: "Sign::App authentication email", env_key: "PRIVATE_AUTH_SERVICE_URL", path: "/sign/in/email/new" },
      # { name: "Sign::Org registration emails", env_key: "PRIVATE_AUTH_STAFF_URL", path: "/registration/emails/new" },
      # { name: "Sign::Org registration passkeys",
      #   env_key: "PRIVATE_AUTH_STAFF_URL", path: "/registration/passkeys/new" },
    ]
  end

  test "all Turnstile forms have turbo disabled" do
    @turnstile_form_paths.each do |form_config|
      name = form_config[:name]
      env_key = form_config[:env_key]
      path = form_config[:path]

      host = ENV[env_key]
      next if host.blank?

      host! host
      get path, headers: form_config[:headers] || {}

      if response.redirect?
        follow_redirect!
      end

      assert_response :success, "Failed to access #{path} for #{name} (#{host})"

      # Check for Turnstile widget
      has_turnstile = response.body.include?("cf-turnstile") || response.body.include?("cloudflare_turnstile")
      next unless has_turnstile

      # Check for turbo disabled on forms
      assert_select "form[data-turbo='false']", { minimum: 1 },
                    "Expected at least one form with data-turbo='false' in #{name} (#{host})"
    end
  end

  test "Turnstile widget is rendered" do
    @turnstile_form_paths.each do |form_config|
      name = form_config[:name]
      env_key = form_config[:env_key]
      path = form_config[:path]

      host = ENV[env_key]
      next if host.blank?

      host! host
      get path, headers: form_config[:headers] || {}

      if response.redirect?
        follow_redirect!
      end

      assert_response :success, "Failed to access #{path} for #{name} (#{host})"

      # Check for Turnstile widget presence
      assert response.body.include?("cf-turnstile") || response.body.include?("cloudflare_turnstile"),
             "Expected Turnstile widget in #{name} (#{host})"
    end
  end
end
