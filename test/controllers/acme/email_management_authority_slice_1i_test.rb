# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeEmailManagementAuthoritySlice1ITest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_email_statuses, :client_telephone_statuses, :client_chronicle_events,
           :client_chronicle_levels, :operators, :operator_statuses, :operator_email_statuses

  setup do
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "acme app settings emails index renders only current client emails" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    other_user = clients(:two)
    user_email = create_client_email!(user, "acme-app-email-index@example.com")
    other_email = create_client_email!(other_user, "acme-app-email-other@example.com")
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    get acme_app_settings_emails_url(ri: "jp", host: host), headers: app_session_headers(host, token, user)

    assert_response :success
    assert_includes response.body, user_email.address
    assert_not_includes response.body, other_email.address
    assert_select "form[action=?][method=post]", acme_app_settings_emails_registration_path(ri: "jp")
  end

  test "acme app settings email registration intent redirects to sign ceremony with grant" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    sign_host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    user = clients(:one)
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    post acme_app_settings_emails_registration_url(ri: "jp", host: host),
         headers: app_session_headers(host, token, user)

    assert_response :see_other
    location = URI.parse(response.location)
    query = Rack::Utils.parse_query(location.query)

    assert_equal sign_host, location.host
    assert_equal new_sign_app_settings_emails_registration_path, location.path
    assert_equal "jp", query["ri"]
    assert_predicate query["email_ceremony_grant"], :present?
  end

  test "acme app settings email update mutates preference fields under acme authority" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    email = create_client_email!(
      user,
      "acme-app-email-update@example.com",
      promotional: true,
      notifiable: true,
      subscribable: true,
    )
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    patch acme_app_settings_email_url(email.public_id, ri: "jp", host: host),
          params: { user_email: { promotional: "0", notifiable: "0", subscribable: "0" } },
          headers: app_session_headers(host, token, user)

    assert_redirected_to edit_acme_app_settings_email_url(email.public_id, ri: "jp", host: host)
    email.reload

    assert_not email.promotional
    assert_not email.notifiable
    assert email.subscribable
  end

  test "acme app settings email update enforces owner scope" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    other_user = clients(:two)
    email = create_client_email!(other_user, "acme-app-email-owner-scope@example.com", promotional: true)
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    assert_no_changes -> { email.reload.promotional } do
      patch acme_app_settings_email_url(email.public_id, ri: "jp", host: host),
            params: { user_email: { promotional: "0" } },
            headers: app_session_headers(host, token, user)
    end

    assert_response :not_found
  end

  test "acme com and org settings email registration intents redirect to sign ceremony with grant" do
    com_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    com_sign_host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "acme-com-email-intent@example.com")
    visitor_token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(visitor_token, scope: "settings_email")

    post acme_com_settings_emails_registration_url(ri: "jp", host: com_host),
         headers: com_session_headers(com_host, visitor_token, visitor)

    com_location = URI.parse(response.location)
    com_query = Rack::Utils.parse_query(com_location.query)

    assert_response :see_other
    assert_equal com_sign_host, com_location.host
    assert_equal new_sign_com_settings_emails_registration_path, com_location.path
    assert_predicate com_query["email_ceremony_grant"], :present?

    org_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    org_sign_host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    staff = operators(:one)
    staff_token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(staff_token, scope: "settings_email")

    post acme_org_settings_emails_registration_url(ri: "jp", host: org_host),
         headers: org_session_headers(org_host, staff_token, staff)

    org_location = URI.parse(response.location)
    org_query = Rack::Utils.parse_query(org_location.query)

    assert_response :see_other
    assert_equal org_sign_host, org_location.host
    assert_equal new_sign_org_settings_emails_registration_path, org_location.path
    assert_predicate org_query["email_ceremony_grant"], :present?
  end

  test "acme app settings email destroy mutates account email under acme authority" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    email = create_client_email!(user, "acme-app-email-destroy@example.com")
    create_client_email!(user, "acme-app-email-destroy-spare@example.com")
    create_verified_client_telephone!(user)
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    assert_difference("ClientEmail.count", -1) do
      delete acme_app_settings_email_url(email.public_id, ri: "jp", host: host),
             headers: app_session_headers(host, token, user)
    end

    assert_redirected_to acme_app_settings_emails_url(ri: "jp", host: host)
  end

  test "acme app settings email destroy preserves last auth method guard" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    email = create_client_email!(user, "acme-app-email-last-method@example.com")
    token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    assert_no_difference("ClientEmail.count") do
      delete acme_app_settings_email_url(email.public_id, ri: "jp", host: host),
             headers: app_session_headers(host, token, user)
    end

    assert_redirected_to acme_app_settings_emails_url(ri: "jp", host: host)
    assert_equal I18n.t("sign.app.settings.email.destroy.last_method"), flash[:alert]
  end

  test "acme com settings email update and destroy are acme authority" do
    host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "acme-com-email-owner@example.com")
    email = create_visitor_email!(
      visitor,
      "acme-com-email-update@example.com",
      promotional: true,
      notifiable: true,
    )
    create_visitor_email!(visitor, "acme-com-email-spare@example.com")
    visitor.visitor_telephones.create!(
      number: "+1555#{SecureRandom.random_number(10 ** 7).to_s.rjust(7, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")
    headers = com_session_headers(host, token, visitor)

    patch acme_com_settings_email_url(email.public_id, ri: "jp", host: host),
          params: { visitor_email: { promotional: "0", notifiable: "0" } },
          headers: headers

    assert_redirected_to edit_acme_com_settings_email_url(email.public_id, ri: "jp", host: host)
    assert_not email.reload.promotional
    assert_not email.notifiable

    assert_difference("VisitorEmail.count", -1) do
      delete acme_com_settings_email_url(email.public_id, ri: "jp", host: host), headers: headers
    end

    assert_redirected_to acme_com_settings_emails_url(ri: "jp", host: host)
  end

  test "acme org settings email update and destroy are acme authority" do
    host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    staff = operators(:one)
    email = create_operator_email!(
      staff,
      "acme-org-email-update@example.com",
      promotional: true,
      notifiable: true,
    )
    create_operator_email!(staff, "acme-org-email-spare@example.com")
    token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")
    headers = org_session_headers(host, token, staff)

    patch acme_org_settings_email_url(email.public_id, ri: "jp", host: host),
          params: { staff_email: { promotional: "0", notifiable: "0" } },
          headers: headers

    assert_redirected_to edit_acme_org_settings_email_url(email.public_id, ri: "jp", host: host)
    assert_not email.reload.promotional
    assert_not email.notifiable

    assert_difference("OperatorEmail.count", -1) do
      delete acme_org_settings_email_url(email.public_id, ri: "jp", host: host), headers: headers
    end

    assert_redirected_to acme_org_settings_emails_url(ri: "jp", host: host)
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

  def create_client_email!(user, address, attrs = {})
    ClientEmail.create!(
      {
        user: user,
        address: address,
        user_email_status_id: ClientEmailStatus::VERIFIED,
      }.merge(attrs),
    )
  end

  def create_verified_client_telephone!(user)
    ClientTelephone.create!(
      user: user,
      number: "+1555#{SecureRandom.random_number(10 ** 7).to_s.rjust(7, "0")}",
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
  end

  def create_visitor_email!(visitor, address, attrs = {})
    VisitorEmail.create!(
      {
        visitor: visitor,
        address: address,
        visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        confirm_policy: true,
      }.merge(attrs),
    )
  end

  def create_operator_email!(staff, address, attrs = {})
    OperatorEmail.create!(
      {
        staff: staff,
        address: address,
        staff_email_status_id: OperatorEmailStatus::VERIFIED,
      }.merge(attrs),
    )
  end
end
