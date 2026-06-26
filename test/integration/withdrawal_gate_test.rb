# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawalGateTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host

    @deactivated_user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
      withdrawal_started_at: 1.day.ago,
      deactivated_at: Time.current,
      discarded_at: Time.current,
      purged_at: 31.days.from_now,
    )

    @token = ClientToken.create!(
      user: @deactivated_user,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "deactivated_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    satisfy_user_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
    AcmeSelectorBootstrapAuthority.call(surface: :app, principal: @deactivated_user)
    AcmeSelectorAuthority.prepare(surface: :app, principal: @deactivated_user, session: @token)

    @headers = {
      "Host" => ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      "X-TEST-CURRENT-USER" => @deactivated_user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "deactivated user accessing normal page redirects to withdrawal status" do
    get acme_app_identity_sessions_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
        headers: @headers

    assert_response :redirect
    assert_redirected_to edit_acme_app_identity_withdrawal_path(ri: "jp")
  end

  test "deactivated user can access allowlisted pages" do
    get new_acme_app_identity_withdrawal_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
        headers: @headers

    assert_response :success

    get edit_acme_app_identity_withdrawal_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
        headers: @headers

    assert_response :success
  end

  test "deactivated user accessing API returns 403" do
    get acme_app_identity_sessions_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
        headers: @headers.merge("Accept" => "application/json")

    assert_response :forbidden
    json_response = response.parsed_body

    assert_equal "WITHDRAWAL_REQUIRED", json_response["error"]
  end

  test "normal user can access pages without withdrawal gate" do
    normal_user = Client.create!(
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    normal_token = ClientToken.create!(
      user: normal_user,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "normal_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    satisfy_user_verification(normal_token)
    AcmeSelectorBootstrapAuthority.call(surface: :app, principal: normal_user)
    AcmeSelectorAuthority.prepare(surface: :app, principal: normal_user, session: normal_token)

    headers = {
      "Host" => ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      "X-TEST-CURRENT-USER" => normal_user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => normal_token.public_id,
    }

    get acme_app_identity_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")), headers: headers

    assert_response :success
  end
end
