# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    Prosopite.pause do
      VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
      VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
      VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
      VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
      VisitorTokenStatus.ensure_defaults!
      VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    end
    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor: @visitor,
      address: "com-sessions-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @visitor.visitor_telephones.create!(
      number: "+819000000003",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::NOTHING,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    satisfy_visitor_verification(@token)
    @other_session = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::NOTHING,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
  end

  def request_headers(token = @token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  test "index returns html and json" do
    get sign_com_settings_sessions_url(ri: "jp", format: :json), headers: request_headers

    assert_response :success
    assert_includes response.parsed_body["sessions"].pluck("public_id"), @token.public_id
  end

  test "destroy rejects current session and missing session returns not found" do
    delete sign_com_settings_session_url(@token.public_id, ri: "jp"), headers: request_headers

    assert_redirected_to sign_com_settings_sessions_url(ri: "jp")
    assert_equal I18n.t("sign.app.settings.sessions.revoke.failure"), flash[:alert]

    delete sign_com_settings_session_url("missing", ri: "jp"), headers: request_headers

    assert_response :not_found
  end

  test "destroy revokes another session and others revokes all others" do
    delete sign_com_settings_session_url(@other_session.public_id, ri: "jp"), headers: request_headers

    assert_redirected_to sign_com_settings_sessions_url(ri: "jp")

    @other_session.reload

    assert_predicate @other_session, :revoked?

    other_two = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    delete others_sign_com_settings_sessions_url(ri: "jp"), headers: request_headers

    assert_redirected_to sign_com_settings_sessions_url(ri: "jp")

    assert_predicate other_two.reload, :revoked?
  end

  test "destroy does not revoke session belonging to another visitor" do
    other_visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    other_visitor_token = VisitorToken.create!(
      visitor: other_visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::NOTHING,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )

    delete sign_com_settings_session_url(other_visitor_token.public_id, ri: "jp"), headers: request_headers

    assert_response :not_found
    assert_predicate other_visitor_token.reload, :currently_usable?
  end

  # ===================================================================
  # revoke_all
  # ===================================================================

  test "revoke_all revokes all sessions including current and clears cookies" do
    mark_token_step_up_satisfied_for_test(@token, scope: "session_revoke_all", at: 5.minutes.ago)

    delete revoke_all_sign_com_settings_sessions_url(ri: "jp"), headers: request_headers

    assert_response :see_other
    @token.reload
    @other_session.reload

    assert_predicate @token, :lapsed?
    assert_predicate @other_session, :lapsed?
    assert_not response_has_cookie?(::Authentication::Base::ACCESS_COOKIE_KEY)
    assert_not response_has_cookie?(::Authentication::Base::REFRESH_COOKIE_KEY)
  end

  test "revoke_all requires step_up" do
    @token.update!(created_at: 20.minutes.ago)
    delete revoke_all_sign_com_settings_sessions_url(ri: "jp"), headers: request_headers

    assert_response :unauthorized
  end

  test "revoke_all requires authentication" do
    delete revoke_all_sign_com_settings_sessions_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
  end

  test "revoke_all records audit event" do
    mark_token_step_up_satisfied_for_test(@token, scope: "session_revoke_all", at: 5.minutes.ago)

    logs = []
    Rails.logger.stub(:info, ->(message = nil, &) { logs << JSON.parse(message, symbolize_names: true) if message }) do
      delete(revoke_all_sign_com_settings_sessions_url(ri: "jp"), headers: request_headers)
    end

    assert_response :see_other
    revoke_events = logs.select { |entry| entry[:event] == "security.session_revoke_all" }

    assert_operator revoke_events.length, :>=, 1
    event = revoke_events.last

    assert_equal "security.session_revoke_all", event[:event]
    assert_equal "Visitor", event[:data][:actor_type]
    assert_predicate event[:data][:actor_id], :present?
  end
end
