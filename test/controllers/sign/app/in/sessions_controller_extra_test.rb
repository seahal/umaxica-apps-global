# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::In::SessionsControllerExtraTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    ClientToken.where(user: @user).delete_all

    # Ensure necessary records exist
    Prosopite.pause do
      ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
      ClientTokenStatus::DEFAULTS.each do |id|
        ClientTokenStatus.find_or_create_by!(id: id)
      end
      ClientTokenBindingMethod.find_or_create_by!(id: 0) # NOTHING
      ClientTokenDbscStatus.find_or_create_by!(id: 0) # NOTHING
    end
  end

  test "update with single ref param revokes and stays on page if not promoted" do
    active1 = create_active_session(@user)
    create_active_session(@user)

    restricted = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted, host: @host)

    # Bypass validation to create 3rd active
    active3 = ClientToken.new(
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    active3.save!(validate: false)
    active3.rotate_refresh_token!

    patch sign_app_in_session_url(ri: "jp"),
          params: { ref: active1.signed_ref },
          headers: headers

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.session.session_revoked")

    restricted.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted.user_token_status_id
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

    assert_not_nil active.discarded_at
  end

  private

  def create_restricted_session(user)
    token = ClientToken.new(
      user: user,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    token.save!(validate: false)
    token.rotate_refresh_token!
    token
  end

  def create_active_session(user)
    token = ClientToken.new(
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
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
