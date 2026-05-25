# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::Mfa::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    @user.update_columns(purged_at: Retainable::SENTINEL) if @user.purged_at.blank?
    @headers = as_user_headers(@user, host: host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_mfa")
  end

  test "should get show" do
    get sign_app_configuration_mfa_challenge_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_select "h1", I18n.t("sign.app.configuration.mfa.show.title")
    assert_select "p", text: I18n.t("sign.app.configuration.mfa.show.reset_unavailable")
    assert_equal "/configuration/mfa/challenge", URI.parse(sign_app_configuration_mfa_challenge_url(ri: "jp")).path
  end

  test "show redirects to verification when step-up is not satisfied" do
    cookies.delete(ClientVerification.cookie_name)
    @token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)

    get sign_app_configuration_mfa_challenge_url(ri: "jp"), headers: authenticated_headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_mfa", query["scope"]
    assert_equal "jp", query["ri"]
    assert_predicate query["rt"], :present?
  end

  test "update route is not exposed" do
    @user.update!(multi_factor_id: ClientMultiFactor::NOTHING, multi_factor_enabled: false)

    patch sign_app_configuration_mfa_challenge_url(ri: "jp"),
          params: { user: { multi_factor_id: ClientMultiFactor::FULL.to_s } },
          headers: authenticated_headers

    assert_response :not_found
    assert_equal ClientMultiFactor::NOTHING, @user.reload.multi_factor_id
    assert_not_predicate @user, :multi_factor_enabled?
  end

  private

  def authenticated_headers = @headers
end
