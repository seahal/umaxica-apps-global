# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::IdentityAuthoritySlice1ATest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
  end

  test "acme_sign_out_destroy_is_session_mutation_and_redirects_to_sign_signed_out" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    delete acme_app_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_response :see_other
    assert_predicate token.reload, :revoked?
    location = URI.parse(response.location)

    assert_equal ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), location.host
    assert_equal "/sign/out", location.path
  end

  test "acme_session_destroy_revokes_other_session" do
    current_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    other_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete acme_app_sign_settings_session_url(other_token.public_id, ri: "jp"), headers: session_headers(current_token)

    assert_response :see_other
    assert_predicate other_token.reload, :lapsed?
    assert_predicate current_token.reload, :currently_usable?
  end

  test "acme_session_revoke_others_promotes_current_restricted_session" do
    active_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    restricted_token = ClientToken.new(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      discarded_at: 15.minutes.from_now,
    )
    restricted_token.send(:skip_session_limit_check=, true)
    restricted_token.save!

    delete others_acme_app_sign_settings_sessions_url(ri: "jp"), headers: session_headers(restricted_token)

    assert_response :see_other
    assert_redirected_to acme_app_dashboard_path(ri: "jp")
    assert_predicate active_token.reload, :lapsed?
    assert_predicate restricted_token.reload, :active_status?
  end

  test "acme_revoke_all_get_is_not_session_mutation" do
    current_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(current_token, scope: "session_revoke_all", at: 5.minutes.ago)

    get revoke_all_acme_app_sign_settings_sessions_url(ri: "jp"), headers: session_headers(current_token)

    assert_not_predicate current_token.reload, :lapsed?
  end

  test "acme_withdrawal_update_is_account_lifecycle_mutation" do
    user = create_verified_user_with_email(email_address: "acme-withdrawal-#{SecureRandom.hex(4)}@example.com")
    user.update_columns(created_at: 120.days.ago, updated_at: 120.days.ago)
    token = ClientToken.create!(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    mark_token_step_up_satisfied_for_test(token, scope: "withdrawal")

    patch sign_app_settings_withdrawal_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
          params: { ack_deactivate_today: "1" },
          headers: session_headers(
            token,
            user: user,
            host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
          )

    assert_response :see_other
    assert_not_nil user.reload.withdrawal_started_at
    assert_not_nil user.deactivated_at
  end

  private

  def session_headers(token, user: @user, host: @host)
    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
