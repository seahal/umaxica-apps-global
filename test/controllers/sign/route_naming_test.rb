# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::RouteNamingTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
    com: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
    org: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
  }.freeze

  test "top-level sign entry route helpers keep the public sign paths" do
    assert_equal "/sign/in/new", new_sign_app_sign_in_path
    assert_equal "/sign/up/new", new_sign_app_sign_up_path
    assert_equal "/sign/out", sign_app_sign_out_path
    assert_equal "/sign/out/edit", edit_sign_app_sign_out_path
  end

  test "sign state route helpers use guard check and challenge terminology" do
    assert_equal "/sign/up/guard/apple", sign_app_up_guard_apple_path
    assert_equal "/sign/up/guard/google", sign_app_up_guard_google_path
    assert_equal "/sign/up/guard/email", sign_app_up_guard_email_path
    assert_equal "/sign/up/guard/telephone", sign_app_up_guard_telephone_path
    assert_equal "/sign/up/check/apple/confirmation", sign_app_up_check_apple_confirmation_path
    assert_equal "/sign/up/check/google/confirmation", sign_app_up_check_google_confirmation_path
    assert_equal "/sign/up/check/email/otp", sign_app_up_check_email_otp_path
    assert_equal "/sign/up/check/email/birthdate", sign_app_up_check_email_birthdate_path
    assert_equal "/sign/up/check/telephone/otp", sign_app_up_check_telephone_otp_path
    assert_equal "/sign/up/check/telephone/passkey", sign_app_up_check_telephone_passkey_path
    assert_equal "/sign/up/check/telephone/passcode", sign_app_up_check_telephone_passcode_path
    assert_equal "/sign/up/check/telephone/birthdate", sign_app_up_check_telephone_birthdate_path
    assert_equal "/sign/in/guard", sign_app_in_guard_path
    assert_equal "/sign/in/check", sign_app_in_check_path
    assert_equal "/sign/in/challenge", sign_app_in_challenge_path
    assert_equal "/sign/in/challenge/totp/new", new_sign_app_in_challenge_totp_path
    assert_equal "/sign/in/challenge/passkey/new", new_sign_app_in_challenge_passkey_path
  end

  test "top-level sign routes use natural controller names on every sign surface" do
    SURFACES.each do |surface, host|
      assert_recognizes_top_level_sign_route(surface, host, "/sign/in/new", "sign_ins", "new")
      assert_recognizes_top_level_sign_route(surface, host, "/sign/up/new", "sign_ups", "new")
      assert_recognizes_top_level_sign_route(surface, host, "/sign/out", "sign_outs", "show")
      assert_recognizes_top_level_sign_route(surface, host, "/sign/out/edit", "sign_outs", "edit")
    end
  end

  test "canonical app sign state routes resolve to existing controllers" do
    assert_recognizes_sign_route(:app, "/sign/up/guard/apple", :get, "up/guard/apples", "show")
    assert_recognizes_sign_route(:app, "/sign/up/guard/google", :get, "up/guard/googles", "show")
    assert_recognizes_sign_route(:app, "/sign/up/guard/email", :get, "up/guard/emails", "show")
    assert_recognizes_sign_route(:app, "/sign/up/guard/telephone", :get, "up/guard/telephones", "show")
    assert_recognizes_sign_route(
      :app, "/sign/up/check/apple/confirmation", :get, "up/check/apple/confirmations",
      "show",
    )
    assert_recognizes_sign_route(
      :app, "/sign/up/check/apple/confirmation", :patch, "up/check/apple/confirmations",
      "update",
    )
    assert_recognizes_sign_route(
      :app, "/sign/up/check/google/confirmation", :get, "up/check/google/confirmations",
      "show",
    )
    assert_recognizes_sign_route(:app, "/sign/up/check/email/otp", :get, "up/check/email/otps", "show")
    assert_recognizes_sign_route(:app, "/sign/up/check/email/otp", :post, "up/check/email/otps", "create")
    assert_recognizes_sign_route(:app, "/sign/up/check/email/otp", :patch, "up/check/email/otps", "update")
    assert_recognizes_sign_route(:app, "/sign/up/check/email/birthdate", :patch, "up/check/email/birthdates", "update")
    assert_recognizes_sign_route(
      :app, "/sign/up/check/telephone/passkey", :post, "up/check/telephone/passkeys",
      "create",
    )
    assert_recognizes_sign_route(
      :app, "/sign/up/check/telephone/passkey", :patch, "up/check/telephone/passkeys",
      "update",
    )
    assert_recognizes_sign_route(
      :app, "/sign/up/check/telephone/passcode", :patch, "up/check/telephone/passcodes",
      "update",
    )
    assert_recognizes_sign_route(:app, "/sign/in/guard", :get, "in/guards", "show")
    assert_recognizes_sign_route(:app, "/sign/in/check", :get, "in/checkpoints", "show")
    assert_recognizes_sign_route(:app, "/sign/in/check", :patch, "in/checkpoints", "update")
    assert_recognizes_sign_route(:app, "/sign/in/check", :delete, "in/checkpoints", "destroy")
    assert_recognizes_sign_route(:app, "/sign/in/challenge", :get, "in/challenges", "show")
    assert_recognizes_sign_route(:app, "/sign/in/challenge/totp/new", :get, "in/challenge/totps", "new")
    assert_recognizes_sign_route(:app, "/sign/in/challenge/passkey/new", :get, "in/challenge/passkeys", "new")
  end

  test "canonical com and org sign check routes resolve on their surfaces" do
    assert_recognizes_sign_route(:com, "/sign/up/guard/email", :get, "up/guard/emails", "show")
    assert_recognizes_sign_route(:com, "/sign/up/guard/telephone", :get, "up/guard/telephones", "show")
    assert_recognizes_sign_route(:com, "/sign/up/check/email/otp", :get, "up/check/email/otps", "show")
    assert_recognizes_sign_route(
      :com, "/sign/up/check/telephone/passkey", :patch, "up/check/telephone/passkeys",
      "update",
    )
    assert_recognizes_sign_route(:com, "/sign/in/guard", :get, "in/guards", "show")
    assert_recognizes_sign_route(:com, "/sign/in/check", :get, "in/checkpoints", "show")
    assert_recognizes_sign_route(:org, "/sign/in/guard", :get, "in/guards", "show")
    assert_recognizes_sign_route(:org, "/sign/in/check", :get, "in/checkpoints", "show")
  end

  test "org signup stays invitation only without normal guard or check routes" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{SURFACES.fetch(:org)}/sign/up/guard", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{SURFACES.fetch(:org)}/sign/up/check", method: :get)
    end
  end

  test "old app sign state paths are not recognized" do
    assert_unrecognized(:app, "/sign/up/guard", :get)
    assert_unrecognized(:app, "/sign/up/guardrail", :get)
    assert_unrecognized(:app, "/sign/up/check", :get)
    assert_unrecognized(:app, "/sign/up/check", :delete)
    assert_unrecognized(:app, "/sign/up/checkpoint", :get)
    assert_unrecognized(:app, "/sign/up/checkpoint", :delete)
  end

  test "old app nested check paths are not recognized" do
    assert_unrecognized(:app, "/sign/up/check/birthdate", :patch)
    assert_unrecognized(:app, "/sign/up/check/passkey", :get)
    assert_unrecognized(:app, "/sign/up/check/passkey/begin", :post)
    assert_unrecognized(:app, "/sign/up/check/passcode", :post)
    assert_unrecognized(:app, "/sign/up/check/social/confirmation", :get)
  end

  test "old sign in checkpoint path redirects to check while challenge remains canonical" do
    get "/sign/in/checkpoint?ri=jp&pt=signed&secret=raw",
        headers: { "Host" => SURFACES.fetch(:app) }

    assert_response :temporary_redirect
    assert_redirect_location_path("/sign/in/check", "pt" => "signed", "ri" => "jp")

    get sign_app_in_challenge_path(ri: "jp"), headers: { "Host" => SURFACES.fetch(:app) }

    assert_response :redirect
  end

  private

  def assert_recognizes_top_level_sign_route(surface, host, path, controller_name, action)
    route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)

    assert_equal "sign/#{surface}/#{controller_name}", route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end

  def assert_recognizes_sign_route(surface, path, method, controller_name, action)
    route = Rails.application.routes.recognize_path("https://#{SURFACES.fetch(surface)}#{path}", method: method)

    assert_equal "sign/#{surface}/#{controller_name}", route.fetch(:controller)
    assert_equal action, route.fetch(:action)
  end

  def assert_unrecognized(surface, path, method)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{SURFACES.fetch(surface)}#{path}", method: method)
    end
  end

  def assert_redirect_location_path(expected_path, expected_query)
    location = URI.parse(response.location)

    assert_equal expected_path, location.path
    assert_equal expected_query, Rack::Utils.parse_nested_query(location.query)
  end
end
