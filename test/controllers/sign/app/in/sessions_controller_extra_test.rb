# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::In::SessionsControllerExtraTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    UserToken.where(user: @user).delete_all

    # Ensure necessary records exist
    UserTokenKind.find_or_create_by!(id: UserTokenKind::BROWSER_WEB)
    [UserTokenStatus::NOTHING, UserTokenStatus::ACTIVE, UserTokenStatus::EXPIRED].each do |id|
      UserTokenStatus.find_or_create_by!(id: id)
    end
    UserTokenBindingMethod.find_or_create_by!(id: 0) # NOTHING
    UserTokenDbscStatus.find_or_create_by!(id: 0) # NOTHING
  end

  test "update with single ref param revokes and stays on page if not promoted" do
    active1 = create_active_session(@user)
    create_active_session(@user)

    restricted = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted, host: @host)

    # Bypass validation to create 3rd active
    active3 = UserToken.new(
      user: @user,
      status: UserToken::STATUS_ACTIVE,
      user_token_status_id: UserTokenStatus::ACTIVE,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      lapses_at: 1.month.from_now,
    )
    active3.save!(validate: false)
    active3.rotate_refresh_token!

    patch sign_app_in_session_url(ri: "jp"),
          params: { ref: active1.signed_ref },
          headers: headers

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.session.session_revoked")

    restricted.reload

    assert_equal UserToken::STATUS_RESTRICTED, restricted.status
  end

  test "destroy with ref param revokes and stays on page" do
    active = create_active_session(@user)
    restricted = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: active.signed_ref },
           headers: headers

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.session.session_revoked")
    active.reload

    assert_not_nil active.lapses_at
  end

  private

  def create_restricted_session(user)
    token = UserToken.new(
      user: user,
      status: UserToken::STATUS_RESTRICTED,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      lapses_at: 1.month.from_now,
    )
    token.save!(validate: false)
    token.rotate_refresh_token!
    token
  end

  def create_active_session(user)
    token = UserToken.new(
      user: user,
      status: UserToken::STATUS_ACTIVE,
      user_token_status_id: UserTokenStatus::ACTIVE,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      lapses_at: 1.month.from_now,
    )
    token.save!(validate: false)
    token.rotate_refresh_token!
    token
  end

  def as_user_headers_with_token(user, token, host:)
    access_token = Authentication::Base::Token.encode(user, host: host, session_public_id: token.public_id)
    {
      "Host" => host,
      "Authorization" => "Bearer #{access_token}",
      "Cookie" => "#{Authentication::Base::ACCESS_COOKIE_KEY}=#{access_token}",
    }
  end
end
