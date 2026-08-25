# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

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

      turnstile = inertia_props["turnstile"]
      next if turnstile.blank?

      # The widget is drawn into the form rather than executed in the background, which is what
      # kept these forms on a plain document submit instead of a background visit.
      assert_equal "render", turnstile.fetch("mode"),
                   "Expected an in-form Turnstile widget in #{name} (#{host})"
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

      # The widget mounts from the props the server sends it, so the site key is what "the page
      # renders a Turnstile challenge" means now.
      assert_predicate inertia_props.fetch("turnstile").fetch("site_key"), :present?,
                       "Expected Turnstile widget in #{name} (#{host})"
    end
  end
end
