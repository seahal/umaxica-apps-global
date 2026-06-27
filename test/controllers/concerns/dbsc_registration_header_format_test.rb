# typed: false
# frozen_string_literal: true

require "test_helper"

class DbscRegistrationHeaderFormatTest < ActiveSupport::TestCase
  fixtures :clients

  test "authentication dbsc registration header uses structured-field tokens" do
    token = ClientToken.create!(
      user: clients(:one),
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_binding_method_id: ClientTokenBindingMethod::NOTHING,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )

    controller = Sign::App::Edge::V0::Token::ChecksController.new
    controller.instance_variable_set(:@_response, ActionDispatch::Response.new)
    controller.define_singleton_method(:token_dbsc_path) { "/edge/v0/token/dbsc" }

    controller.send(:issue_dbsc_registration_header_for, token)

    registration_header = controller.response.headers[AuthIoKeys::Headers::DBSC_REGISTRATION]
    secure_registration_header = controller.response.headers[AuthIoKeys::Headers::SECURE_DBSC_REGISTRATION]

    assert_predicate registration_header, :present?
    assert_equal registration_header, secure_registration_header
    assert_includes registration_header, "(ES256 RS256);"
    assert_not_includes registration_header, '"ES256"'
    assert_not_includes registration_header, '"RS256"'
  end

  test "preference dbsc registration header uses structured-field tokens" do
    preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)

    controller = Base::App::Edge::V0::CookiesController.new
    controller.instance_variable_set(:@_response, ActionDispatch::Response.new)
    controller.define_singleton_method(:preference_dbsc_path) { "/edge/v0/dbsc" }

    controller.send(:issue_preference_dbsc_registration_header_for, preference)

    registration_header = controller.response.headers[PreferenceIoKeys::Headers::DBSC_REGISTRATION]
    secure_registration_header = controller.response.headers[PreferenceIoKeys::Headers::DBSC_SECURE_REGISTRATION]

    assert_predicate registration_header, :present?
    assert_equal registration_header, secure_registration_header
    assert_includes registration_header, "(ES256 RS256);"
    assert_not_includes registration_header, '"ES256"'
    assert_not_includes registration_header, '"RS256"'
  end

  test "authentication dbsc cookie value does not fall back to public id" do
    token = ClientToken.create!(
      user: clients(:one),
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
      public_id: "public-session-id",
      dbsc_session_id: nil,
    )

    controller = Sign::App::Edge::V0::Token::ChecksController.new

    assert_nil controller.send(:dbsc_cookie_value_for, token)
  end
end
