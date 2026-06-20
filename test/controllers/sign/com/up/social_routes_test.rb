# typed: false
# frozen_string_literal: true

require "test_helper"

# Verifies that com sign-up social routes (Google, Apple) do not exist.
# Per ADR sign-com-no-social-login.md, com supports only email and telephone sign-up.
class Sign::Com::Sign::Up::SocialRoutesTest < ActiveSupport::TestCase
  COM_HOST = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")

  test "com google sign-up guard route is unreachable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{COM_HOST}/sign/up/guard/google",
        method: :get,
      )
    end
  end

  test "com apple sign-up guard route is unreachable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{COM_HOST}/sign/up/guard/apple",
        method: :get,
      )
    end
  end

  test "com google sign-up check confirmation route is unreachable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{COM_HOST}/sign/up/check/google/confirmation",
        method: :get,
      )
    end
  end

  test "com apple sign-up check confirmation route is unreachable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{COM_HOST}/sign/up/check/apple/confirmation",
        method: :get,
      )
    end
  end

  test "com google callback route is unreachable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{COM_HOST}/auth/google_app/callback",
        method: :get,
      )
    end
  end

  test "com apple callback route is unreachable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{COM_HOST}/auth/apple/callback",
        method: :post,
      )
    end
  end
end
