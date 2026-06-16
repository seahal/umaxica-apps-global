# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_email_statuses, :operator_token_kinds

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    host! @host
  end

  test "sign settings emails index redirects to acme authority" do
    get sign_org_settings_emails_url(ri: "jp"), headers: session_headers

    assert_redirected_to acme_org_settings_emails_url(ri: "jp", host: @acme_host)
  end

  test "sign settings email edit redirects without loading email" do
    get edit_sign_org_settings_email_url("missing", ri: "jp"), headers: session_headers

    assert_redirected_to edit_acme_org_settings_email_url("missing", ri: "jp", host: @acme_host)
  end

  test "sign settings email update redirects without local preference mutation" do
    email = OperatorEmail.create!(
      address: "sign-org-email-update-redirect@example.com",
      staff: operators(:one),
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )

    assert_no_changes -> { email.reload.attributes.slice("promotional", "notifiable") } do
      patch sign_org_settings_email_url(email.public_id, ri: "jp"),
            params: { staff_email: { promotional: "0", notifiable: "0" } },
            headers: session_headers
    end

    assert_redirected_to acme_org_settings_email_url(email.public_id, ri: "jp", host: @acme_host)
  end

  test "sign settings email destroy redirects without local account mutation" do
    email = OperatorEmail.create!(
      address: "sign-org-email-destroy-redirect@example.com",
      staff: operators(:one),
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )

    assert_no_difference("OperatorEmail.count") do
      delete sign_org_settings_email_url(email.public_id, ri: "jp"), headers: session_headers
    end

    assert_redirected_to acme_org_settings_email_url(email.public_id, ri: "jp", host: @acme_host)
    assert_not_predicate email.reload, :destroyed?
  end

  test "sign email registration route remains on sign ceremony surface" do
    get new_sign_org_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_equal "sign/org/settings/emails/registrations", @request.path_parameters[:controller]
    assert_equal "new", @request.path_parameters[:action]
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
