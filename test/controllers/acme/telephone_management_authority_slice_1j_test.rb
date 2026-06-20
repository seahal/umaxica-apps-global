# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeTelephoneManagementAuthoritySlice1JTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_telephone_statuses, :client_email_statuses, :client_chronicle_events,
           :client_chronicle_levels, :operators, :operator_statuses, :operator_telephone_statuses

  test "acme app settings telephones index renders only current client telephones" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    other_user = clients(:two)
    telephone = create_client_telephone!(user, "+10000000100")
    other_telephone = create_client_telephone!(other_user, "+10000000101")
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")

    get acme_app_settings_telephones_url(ri: "jp", host: host), headers: app_session_headers(host, token, user)

    assert_response :success
    assert_includes response.body, telephone.number
    assert_not_includes response.body, other_telephone.number
    assert_select "form[action=?][method=?]", acme_app_settings_telephones_registration_path(ri: "jp"), "post"
  end

  test "acme app telephone registration creates ceremony intent and redirects to sign ceremony" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")

    assert_difference("ClientTelephoneCeremonyTransaction.count", 1) do
      post acme_app_settings_telephones_registration_url(ri: "jp", host: host),
           headers: app_session_headers(host, token, user)
    end

    assert_response :see_other
    assert_match(
      %r{\Ahttp://#{Regexp.escape(
        ENV.fetch(
          "ID_SERVICE_URL",
          "id.app.localhost",
        ),
      )}/settings/telephones/registration/new}, response.location,
    )
    assert_includes response.location, "telephone_ceremony_grant="
  end

  test "acme app settings telephone destroy mutates account telephone under acme authority" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    telephone = create_client_telephone!(user, "+10000000102")
    create_client_telephone!(user, "+10000000103")
    create_verified_client_email!(user)
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")

    assert_difference("ClientTelephone.count", -1) do
      delete acme_app_settings_telephone_url(telephone.public_id, ri: "jp", host: host),
             headers: app_session_headers(host, token, user)
    end

    assert_redirected_to acme_app_settings_telephones_url(ri: "jp", host: host)
  end

  test "acme app settings telephone destroy enforces owner scope" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    other_user = clients(:two)
    telephone = create_client_telephone!(other_user, "+10000000104")
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")

    assert_no_difference("ClientTelephone.count") do
      delete acme_app_settings_telephone_url(telephone.public_id, ri: "jp", host: host),
             headers: app_session_headers(host, token, user)
    end

    assert_response :not_found
  end

  test "acme app settings telephone destroy preserves last auth method guard" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    telephone = create_client_telephone!(user, "+10000000105")
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")

    assert_no_difference("ClientTelephone.count") do
      delete acme_app_settings_telephone_url(telephone.public_id, ri: "jp", host: host),
             headers: app_session_headers(host, token, user)
    end

    assert_redirected_to acme_app_settings_telephones_url(ri: "jp", host: host)
    assert_equal I18n.t("sign.app.settings.telephone.destroy.last_method"), flash[:alert]
  end

  test "acme com settings telephone index and destroy are acme authority" do
    host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "acme-com-telephone-owner@example.com")
    telephone = create_visitor_telephone!(visitor, "+10000000106")
    create_visitor_telephone!(visitor, "+10000000107")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")
    headers = com_session_headers(host, token, visitor)

    get acme_com_settings_telephones_url(ri: "jp", host: host), headers: headers

    assert_response :success
    assert_includes response.body, telephone.number

    assert_difference("VisitorTelephone.count", -1) do
      delete acme_com_settings_telephone_url(telephone.public_id, ri: "jp", host: host), headers: headers
    end

    assert_redirected_to acme_com_settings_telephones_url(ri: "jp", host: host)
  end

  test "acme com telephone registration creates ceremony intent" do
    host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "acme-com-telephone-intent@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")

    assert_difference("VisitorTelephoneCeremonyTransaction.count", 1) do
      post acme_com_settings_telephones_registration_url(ri: "jp", host: host),
           headers: com_session_headers(host, token, visitor)
    end

    assert_response :see_other
    assert_match(
      %r{\Ahttp://#{Regexp.escape(
        ENV.fetch(
          "SIGN_CORPORATE_URL",
          "id.com.localhost",
        ),
      )}/settings/telephones/registration/new}, response.location,
    )
    assert_includes response.location, "telephone_ceremony_grant="
  end

  test "acme org settings telephone index and destroy are acme authority" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    staff = operators(:one)
    telephone = create_operator_telephone!(staff, "+10000000108")
    create_operator_telephone!(staff, "+10000000109")
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")
    headers = org_session_headers(host, token, staff)

    get acme_org_settings_telephones_url(ri: "jp", host: host), headers: headers

    assert_response :success
    assert_includes response.body, telephone.number

    assert_difference("OperatorTelephone.count", -1) do
      delete acme_org_settings_telephone_url(telephone.id, ri: "jp", host: host), headers: headers
    end

    assert_redirected_to acme_org_settings_telephones_url(ri: "jp", host: host)
  end

  test "acme org telephone registration creates ceremony intent" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_telephone")

    assert_difference("OperatorTelephoneCeremonyTransaction.count", 1) do
      post acme_org_settings_telephones_registration_url(ri: "jp", host: host),
           headers: org_session_headers(host, token, staff)
    end

    assert_response :see_other
    assert_match(
      %r{\Ahttp://#{Regexp.escape(
        ENV.fetch(
          "ID_STAFF_URL",
          "id.org.localhost",
        ),
      )}/settings/telephones/registration/new}, response.location,
    )
    assert_includes response.location, "telephone_ceremony_grant="
  end

  private

  def create_user_token!(user)
    token = ClientToken.new(
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end

  def app_session_headers(host, token, user)
    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def com_session_headers(host, token, visitor)
    {
      "Host" => host,
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def org_session_headers(host, token, staff)
    {
      "Host" => host,
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def create_client_telephone!(user, number)
    ClientTelephone.create!(
      user: user,
      number: number,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
  end

  def create_verified_client_email!(user)
    ClientEmail.create!(
      user: user,
      address: "telephone-guard-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
  end

  def create_visitor_telephone!(visitor, number)
    VisitorTelephone.create!(
      visitor: visitor,
      number: number,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  def create_operator_telephone!(staff, number)
    OperatorTelephone.create!(
      staff: staff,
      number: number,
      staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )
  end
end
