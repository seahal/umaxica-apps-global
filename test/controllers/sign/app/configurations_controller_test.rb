# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    @user.update!(status_id: ClientStatus::ACTIVE)
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @token = ClientToken.create!(user_id: @user.id)
    @refresh_plain = @token.rotate_refresh_token!
    satisfy_user_verification(@token)
  end

  def seed_refresh_session(token: @token, refresh_plain: @refresh_plain)
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    token
  end

  test "should get show when logged in" do
    seed_refresh_session
    get sign_app_configuration_url(ri: "jp")

    assert_response :success
    assert_select "a[href^=?]", sign_app_configuration_emails_path(ri: "jp")
    assert_select "a[href^=?]", sign_app_configuration_telephones_path(ri: "jp")
    assert_select "a[href^=?]", sign_app_configuration_birthdate_path(ri: "jp")
    assert_select "a[href^=?]", sign_app_configuration_mfa_challenge_path(ri: "jp")
    assert_select "a[href^=?]", sign_app_mfa_reset_path(ri: "jp")
    assert_select "a[href^=?]", sign_app_configuration_google_path(ri: "jp")
    assert_select "a[href^=?]", sign_app_configuration_apple_path(ri: "jp")
    assert_select "a[href^=?]", sign_app_configuration_sessions_path(ri: "jp")
    assert_select "a[href^=?]", new_sign_app_configuration_withdrawal_path(ri: "jp")
    assert_select "a[href*=?]", edit_sign_app_out_path(ri: "jp"),
                  text: /#{Regexp.escape(I18n.t("sign.app.configuration.show.logout"))}/
    assert_select "a[href*=?]", sign_app_root_path(ri: "jp")
  end

  test "should redirect show when not logged in" do
    get sign_app_configuration_url(ri: "jp")

    assert_response :redirect
    target_path = new_sign_app_in_path

    assert_match %r{#{Regexp.escape(target_path)}\?.*ri=jp}, response.headers["Location"]
  end

  test "edit route is not available" do
    get "/configuration/edit"

    assert_response :not_found
  end

  test "restricted session is blocked on configuration with locked plain response" do
    token = ClientToken.create!(
      user: @user,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
    )
    token.rotate_refresh_token!(discarded_at: 15.minutes.from_now)
    access_token = jwt_access_token_for(@user, host: @host, session_public_id: token.public_id)
    headers = browser_headers.merge(
      "Host" => @host,
      "Authorization" => "Bearer #{access_token}",
      "Cookie" => "#{Authentication::Base::ACCESS_COOKIE_KEY}=#{access_token}",
    )

    get sign_app_configuration_url(ri: "jp"), headers: headers

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
    assert_not response.redirect?
  end

  test "active session can access configuration normally" do
    token = ClientToken.create!(
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    refresh_plain = token.rotate_refresh_token!
    seed_refresh_session(token: token, refresh_plain: refresh_plain)

    get sign_app_configuration_url(ri: "jp")

    assert_response :success
  end

  test "should succeed with valid refresh cookie (transparent refresh)" do
    token = ClientToken.create!(user_id: @user.id)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    get sign_app_configuration_url(ri: "jp")

    # Should succeed (200) after transparent refresh, not redirect to /in/new
    assert_response :success
    assert_select "a[href^=?]", sign_app_configuration_emails_path(ri: "jp")
  end

  test "should not raise ReadOnlyError during transparent refresh" do
    token = ClientToken.create!(user_id: @user.id)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    # Should not raise any ReadOnlyError
    assert_nothing_raised do
      get sign_app_configuration_url(ri: "jp")

      assert_response :success
    end

    assert_response :success
  end

  test "should succeed even when audit fails during transparent refresh" do
    token = ClientToken.create!(user_id: @user.id)
    refresh_plain = token.rotate_refresh_token!

    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    # Simulate audit failure by overriding record_audit to raise an error
    @controller.define_singleton_method(:record_audit) do |*_args|
      raise StandardError, "Simulated audit failure"
    end

    get sign_app_configuration_url(ri: "jp")

    # Should still succeed (200) - audit failure should not fail refresh
    assert_response :success
    assert_select "a[href^=?]", sign_app_configuration_emails_path(ri: "jp")
  end
end
